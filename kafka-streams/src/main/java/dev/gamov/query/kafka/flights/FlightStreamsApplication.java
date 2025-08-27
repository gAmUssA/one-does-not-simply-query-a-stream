package dev.gamov.query.kafka.flights;

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.CreateTopicsResult;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.common.KafkaFuture;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Grouped;
import org.apache.kafka.streams.state.KeyValueStore;
import org.apache.kafka.common.utils.Bytes;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import dev.gamov.query.kafka.CloudConfig;
import io.confluent.kafka.streams.serdes.avro.SpecificAvroSerde;
import io.confluent.developer.models.flight.Flight;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

import static org.apache.kafka.streams.StreamsConfig.APPLICATION_ID_CONFIG;
import static org.apache.kafka.streams.StreamsConfig.BOOTSTRAP_SERVERS_CONFIG;

public class FlightStreamsApplication {

  private static final Logger logger = LoggerFactory.getLogger(FlightStreamsApplication.class);
  private static KafkaStreams streams;

  // --- util helpers reused from other app ---
  private static String envOrDefault(String key, String def) {
    String v = System.getenv(key);
    return (v == null || v.isBlank()) ? def : v;
  }

  private static void createTopicsIfNotExist(Properties adminProps, String[] topics, int partitions, short replicationFactor) {
    Properties props = new Properties();
    props.putAll(adminProps);

    try (AdminClient adminClient = AdminClient.create(props)) {
      logger.info("Creating topics if they don't exist: {}", Arrays.toString(topics));

      for (String topic : topics) {
        NewTopic newTopic = new NewTopic(topic, partitions, replicationFactor);
        CreateTopicsResult result = adminClient.createTopics(Collections.singleton(newTopic));
        KafkaFuture<Void> future = result.values().get(topic);

        try {
          future.get();
          logger.info("Topic {} created or already exists", topic);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          logger.error("Topic creation interrupted for topic: {}", topic, e);
        } catch (ExecutionException e) {
          if (e.getCause() != null && e.getCause().getMessage() != null && e.getCause().getMessage().contains("already exists")) {
            logger.info("Topic {} already exists", topic);
          } else {
            logger.error("Error creating topic: {}", topic, e);
          }
        }
      }
    }
  }

  public static Topology createTopology(String inputTopic, Map<String, Object> serdeConfig) {
    StreamsBuilder builder = new StreamsBuilder();

    // Specific Avro serde for Flight
    SpecificAvroSerde<Flight> valueSerde = new SpecificAvroSerde<>();
    valueSerde.configure(serdeConfig, false);

    // Read from topic
    KStream<String, Flight> flights = builder.stream(
        inputTopic,
        Consumed.with(Serdes.String(), valueSerde)
    );

    // Re-key by flightNumber field from Flight value
    KStream<String, Flight> rekeyed = flights.selectKey((key, value) -> {
      if (value == null) return null;
      return value.getFlightNumber();
    });

    // Materialize latest record per flightNumber in a state store
    final var flightsTable = rekeyed
        .groupByKey(Grouped.with(Serdes.String(), valueSerde))
        .reduce((agg, newVal) -> newVal,
            Materialized.<String, Flight, KeyValueStore<Bytes, byte[]>>as("flights-store")
                .withKeySerde(Serdes.String())
                .withValueSerde(valueSerde)
        );

    // Derive aggregation: number of delayed flights per origin airport
    flightsTable
        .groupBy((flightNumber, flight) -> {
          String origin = flight == null ? null : flight.getOrigin();
          long delayed = (flight != null && "DELAYED".equalsIgnoreCase(flight.getStatus())) ? 1L : 0L;
          return new org.apache.kafka.streams.KeyValue<>(origin, delayed);
        }, Grouped.with(Serdes.String(), Serdes.Long()))
        .aggregate(
            () -> 0L,
            (origin, newValue, aggregate) -> aggregate + (newValue == null ? 0L : newValue),
            (origin, oldValue, aggregate) -> aggregate - (oldValue == null ? 0L : oldValue),
            Materialized.<String, Long, KeyValueStore<Bytes, byte[]>>as("delayed-by-origin-store")
                .withKeySerde(Serdes.String())
                .withValueSerde(Serdes.Long())
        )
        .toStream()
        .peek((k, v) -> logger.debug("Delayed count origin {} -> {}", k, v));

    final Topology build = builder.build();
    System.out.println(build.describe());
    return build;
  }

  public static void main(String[] args) {
    // Load configuration from cloud.properties with fallback to local defaults/env
    Properties cloud = CloudConfig.load();

    String bootstrapServers = cloud.getProperty("bootstrap.servers", envOrDefault("BOOTSTRAP_SERVERS", "localhost:29092"));
    String applicationId = envOrDefault("APPLICATION_ID", "flights-streams");
    String inputTopic = envOrDefault("TOPIC_NAME", "flights");

    boolean isCloud = bootstrapServers.contains("confluent.cloud")
        || cloud.getProperty("security.protocol") != null
        || cloud.getProperty("sasl.jaas.config") != null;

    Properties props = new Properties();
    props.put(APPLICATION_ID_CONFIG, applicationId);
    props.put(BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
    props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());

    // Copy security from cloud.properties if present
    CloudConfig.copySecurity(cloud, props);
    if (isCloud) {
      props.put("replication.factor", "3");
    }

    // Serde configuration from cloud.properties (schema registry)
    Properties serdeProps = CloudConfig.schemaRegistrySerdeConfig(cloud);
    Map<String, Object> serdeConfig = new HashMap<>();
    for (String name : serdeProps.stringPropertyNames()) {
      serdeConfig.put(name, serdeProps.getProperty(name));
    }

    // Create topic best-effort
    Properties adminProps = new Properties();
    adminProps.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
    CloudConfig.copySecurity(cloud, adminProps);
    short rf = (short) (isCloud ? 3 : 1);
    try {
      createTopicsIfNotExist(adminProps, new String[]{inputTopic}, 1, rf);
    } catch (Exception e) {
      logger.warn("Unable to create topic '{}': {}", inputTopic, e.toString());
    }

    Topology topology = createTopology(inputTopic, serdeConfig);

    streams = new KafkaStreams(topology, props);
    streams.start();

    // Start interactive query service
    FlightsQueryService.start(streams);

    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
      logger.info("Shutting down FlightStreamsApplication");
      streams.close();
    }));
  }
}
