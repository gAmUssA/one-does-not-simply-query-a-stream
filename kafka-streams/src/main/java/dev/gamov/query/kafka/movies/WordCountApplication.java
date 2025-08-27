package dev.gamov.query.kafka.movies;

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.CreateTopicsResult;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.common.KafkaFuture;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Produced;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Arrays;
import java.util.Collections;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

import dev.gamov.query.kafka.CloudConfig;

import static org.apache.kafka.streams.StreamsConfig.APPLICATION_ID_CONFIG;
import static org.apache.kafka.streams.StreamsConfig.APPLICATION_SERVER_CONFIG;
import static org.apache.kafka.streams.StreamsConfig.BOOTSTRAP_SERVERS_CONFIG;
import static org.apache.kafka.streams.StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG;
import static org.apache.kafka.streams.StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG;

public class WordCountApplication {

  private static final Logger logger = LoggerFactory.getLogger(WordCountApplication.class);
  private static KafkaStreams streams;

  private static String envOrDefault(String key, String def) {
    String v = System.getenv(key);
    return (v == null || v.isBlank()) ? def : v;
  }

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

    final Topology build = builder.build();
    System.out.println(build.describe());
    return build;
  }

  /**
   * Creates Kafka topics if they don't exist
   * @param adminProps Properties used to create AdminClient (bootstrap + security)
   * @param topics List of topic names to create
   * @param partitions Number of partitions for each topic
   * @param replicationFactor Replication factor for each topic
   */
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
          future.get(); // Wait for topic creation to complete
          logger.info("Topic {} created or already exists", topic);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          logger.error("Topic creation interrupted for topic: {}", topic, e);
        } catch (ExecutionException e) {
          if (e.getCause().getMessage() != null && e.getCause().getMessage().contains("already exists")) {
            logger.info("Topic {} already exists", topic);
          } else {
            logger.error("Error creating topic: {}", topic, e);
          }
        }
      }
    }
  }

  public static void main(String[] args) {
    // Load configuration from cloud.properties with fallbacks to local defaults
    Properties cloud = CloudConfig.load();

    String bootstrapServers = cloud.getProperty("bootstrap.servers", envOrDefault("BOOTSTRAP_SERVERS", "localhost:29092"));
    String applicationId = envOrDefault("APPLICATION_ID", "wordcount-application");
    String applicationServer = envOrDefault("APPLICATION_SERVER", "localhost:8081");
    String inputTopic = "movies";
    String outputTopic = envOrDefault("OUTPUT_TOPIC_NAME", inputTopic + "-out");

    boolean isCloud = bootstrapServers.contains("confluent.cloud")
        || cloud.getProperty("security.protocol") != null
        || cloud.getProperty("sasl.jaas.config") != null;

    Properties props = new Properties();
    props.put(APPLICATION_ID_CONFIG, applicationId);
    props.put(BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
    props.put(DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
    props.put(DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
    props.put(APPLICATION_SERVER_CONFIG, applicationServer);

    // Copy security-related settings from cloud.properties if present
    CloudConfig.copySecurity(cloud, props);
    if (isCloud) {
      props.put("replication.factor", "3"); // internal topics replication factor
    }

    // Create topics before starting the streams application (best-effort)
    Properties adminProps = new Properties();
    adminProps.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
    CloudConfig.copySecurity(cloud, adminProps);
    short rf = (short) (isCloud ? 3 : 1);
    try {
      createTopicsIfNotExist(adminProps, new String[]{inputTopic, outputTopic}, 1, rf);
    } catch (Exception e) {
      logger.warn("Unable to create topics '{}', '{}': {}", inputTopic, outputTopic, e.toString());
    }

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
