package dev.gamov.query.kafka.flights;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.TestInputTopic;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.TopologyTestDriver;
import org.apache.kafka.streams.state.KeyValueStore;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

import io.confluent.developer.models.flight.Flight;
import io.confluent.kafka.streams.serdes.avro.SpecificAvroSerde;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

public class FlightStreamsApplicationTest {

  private TopologyTestDriver testDriver;
  private TestInputTopic<String, Flight> inputTopic;
  private KeyValueStore<String, Flight> store;

  @BeforeEach
  public void setup() {
    Properties props = new Properties();
    props.put(StreamsConfig.APPLICATION_ID_CONFIG, "flights-test");
    props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "dummy:9092");
    props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());

    // Configure mock schema registry for serdes
    Map<String, Object> serdeConfig = new HashMap<>();
    serdeConfig.put("schema.registry.url", "mock://flight-sr");

    Topology topology = FlightStreamsApplication.createTopology("flights", serdeConfig);
    testDriver = new TopologyTestDriver(topology, props);

    SpecificAvroSerde<Flight> valueSerde = new SpecificAvroSerde<>();
    valueSerde.configure(serdeConfig, false);

    inputTopic = testDriver.createInputTopic("flights", Serdes.String().serializer(), valueSerde.serializer());

    store = testDriver.getKeyValueStore("flights-store");
  }

  @AfterEach
  public void tearDown() {
    testDriver.close();
  }

  private Flight flight(
      String flightNumber,
      String airline,
      String origin,
      String destination,
      long scheduledDeparture,
      Long actualDeparture,
      String status
  ) {
    Flight.Builder b = Flight.newBuilder();
    b.setFlightNumber(flightNumber);
    b.setAirline(airline);
    b.setOrigin(origin);
    b.setDestination(destination);
    b.setScheduledDeparture(scheduledDeparture);
    b.setActualDeparture(actualDeparture);
    b.setStatus(status);
    return b.build();
  }

  @Test
  public void testFlightsStateStoreKeepsLatestPerFlight() {
    Flight r1 = flight("AA100", "AA", "SFO", "JFK", 1000L, null, "SCHEDULED");
    Flight r2 = flight("AA100", "AA", "SFO", "JFK", 1000L, 1200L, "DELAYED");
    Flight r3 = flight("BA200", "BA", "LHR", "ORD", 2000L, null, "BOARDING");

    inputTopic.pipeInput(null, r1);
    inputTopic.pipeInput(null, r2);
    inputTopic.pipeInput(null, r3);

    Flight vAA100 = store.get("AA100");
    Flight vBA200 = store.get("BA200");

    assertNotNull(vAA100);
    assertEquals("DELAYED", vAA100.getStatus());
    assertEquals(1200L, vAA100.getActualDeparture());

    assertNotNull(vBA200);
    assertEquals("BOARDING", vBA200.getStatus());
  }

  @Test
  public void testDelayedByOriginAggregation() {
    // Prepare some records
    Flight f1_scheduled = flight("AA100", "AA", "SFO", "JFK", 1000L, null, "SCHEDULED");
    Flight f1_delayed   = flight("AA100", "AA", "SFO", "JFK", 1000L, 1200L, "DELAYED");
    Flight f2_delayed   = flight("BA200", "BA", "SFO", "ORD", 2000L, 2100L, "DELAYED");
    Flight f1_boarding  = flight("AA100", "AA", "SFO", "JFK", 1000L, 1200L, "BOARDING");
    Flight f3_delayed   = flight("CA300", "CA", "LAX", "SEA", 3000L, 3100L, "DELAYED");
    Flight f2_on_time   = flight("BA200", "BA", "SFO", "ORD", 2000L, 2100L, "ON_TIME");

    // Pipe through topic (keys unused; topology re-keys by flightNumber)
    inputTopic.pipeInput(null, f1_scheduled); // SFO delayed 0
    inputTopic.pipeInput(null, f1_delayed);   // SFO delayed 1
    inputTopic.pipeInput(null, f2_delayed);   // SFO delayed 2
    inputTopic.pipeInput(null, f1_boarding);  // SFO delayed 1
    inputTopic.pipeInput(null, f3_delayed);   // LAX delayed 1; SFO delayed 1
    inputTopic.pipeInput(null, f2_on_time);   // SFO delayed 0; LAX delayed 1

    KeyValueStore<String, Long> delayedStore = testDriver.getKeyValueStore("delayed-by-origin-store");

    assertEquals(0L, delayedStore.get("SFO"));
    assertEquals(1L, delayedStore.get("LAX"));
  }
}
