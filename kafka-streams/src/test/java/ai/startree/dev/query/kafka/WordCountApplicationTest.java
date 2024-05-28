package ai.startree.dev.query.kafka;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.TestInputTopic;
import org.apache.kafka.streams.TestOutputTopic;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.TopologyTestDriver;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.NoSuchElementException;
import java.util.Properties;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

public class WordCountApplicationTest {

  private TopologyTestDriver testDriver;
  private TestInputTopic<String, String> inputTopic;
  private TestOutputTopic<String, Long> outputTopic;

  @BeforeEach
  public void setup() {
    Properties props = new Properties();
    props.put(StreamsConfig.APPLICATION_ID_CONFIG, "test");
    props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "dummy:9092");
    props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
    props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());

    String inputTopicName = "input-topic";
    String outputTopicName = "output-topic";

    Topology topology = WordCountApplication.createTopology(inputTopicName, outputTopicName);
    testDriver = new TopologyTestDriver(topology, props);

    inputTopic = testDriver.createInputTopic(inputTopicName, Serdes.String().serializer(), Serdes.String().serializer());
    outputTopic = testDriver.createOutputTopic(outputTopicName, Serdes.String().deserializer(), Serdes.Long().deserializer());
  }

  @AfterEach
  public void tearDown() {
    testDriver.close();
  }

  @Test
  public void testWordCount() {
    inputTopic.pipeInput("Hello Kafka Streams");

    KeyValue<String, Long> result1 = outputTopic.readKeyValue();
    KeyValue<String, Long> result2 = outputTopic.readKeyValue();
    KeyValue<String, Long> result3 = outputTopic.readKeyValue();

    assertEquals(new KeyValue<>("hello", 1L), result1);
    assertEquals(new KeyValue<>("kafka", 1L), result2);
    assertEquals(new KeyValue<>("streams", 1L), result3);
    assertThrows(NoSuchElementException.class, () -> {
      outputTopic.readKeyValue();
    });
  }

  @Test
  public void testStateStore() {
    inputTopic.pipeInput("Hello Kafka Streams");
    inputTopic.pipeInput("Kafka Streams");

    ReadOnlyKeyValueStore<String, Long> keyValueStore =
        testDriver.getKeyValueStore("word-counts-store");

    assertEquals(1L, keyValueStore.get("hello"));
    assertEquals(2L, keyValueStore.get("kafka"));
    assertEquals(2L, keyValueStore.get("streams"));
  }
}
