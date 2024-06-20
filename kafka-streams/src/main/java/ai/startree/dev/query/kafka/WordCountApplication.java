package ai.startree.dev.query.kafka;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Produced;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Arrays;
import java.util.Properties;

public class WordCountApplication {

  private static final Logger logger = LoggerFactory.getLogger(WordCountApplication.class);
  private static KafkaStreams streams;

  public static Topology createTopology(String inputTopic, String outputTopic) {
    StreamsBuilder builder = new StreamsBuilder();

    builder.<String, String>stream(inputTopic)
        .flatMapValues(value -> {
          logger.info("Processing value: {}", value);
          return Arrays.asList(((String) value).toLowerCase().split("\\W+"));
        })
        .groupBy((key, word) -> word)
        .count(Materialized.as("word-counts-store"))
        .toStream()
        .to(outputTopic, Produced.with(Serdes.String(), Serdes.Long()));

    return builder.build();
  }

  public static void main(String[] args) {
    //region populating properties
    Properties props = new Properties();
    props.put(StreamsConfig.APPLICATION_ID_CONFIG, "wordcount-application");
    props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:29092");
    props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
    props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
    props.put(StreamsConfig.APPLICATION_SERVER_CONFIG, "localhost:8080");

    String inputTopic = props.getProperty("input.topic.name", "input-topic");
    String outputTopic = props.getProperty("output.topic.name", "output-topic");
    //endregion

    Topology topology = createTopology(inputTopic, outputTopic);

    streams = new KafkaStreams(topology, props);
    streams.start();

    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
      logger.info("Shutting down stream application");
      streams.close();
    }));

    // Start the REST service
    WordCountService.startRestService(streams);
  }
}