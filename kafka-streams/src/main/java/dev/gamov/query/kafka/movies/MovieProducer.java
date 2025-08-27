package dev.gamov.query.kafka.movies;

import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.CreateTopicsResult;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.KafkaFuture;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Arrays;
import java.util.Collections;
import java.util.Properties;
import java.util.concurrent.ExecutionException;

import dev.gamov.query.kafka.CloudConfig;

public class MovieProducer {

  private static final Logger logger = LoggerFactory.getLogger(MovieProducer.class);

  private static String envOrDefault(String key, String def) {
    String v = System.getenv(key);
    return (v == null || v.isBlank()) ? def : v;
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
    // Load configuration from cloud.properties with fallback to local defaults/env
    Properties cloud = CloudConfig.load();
    String bootstrapServers = cloud.getProperty("bootstrap.servers", envOrDefault("BOOTSTRAP_SERVERS", "localhost:29092"));
    String topic = "movies";

    boolean isCloud = bootstrapServers.contains("confluent.cloud")
        || cloud.getProperty("security.protocol") != null
        || cloud.getProperty("sasl.jaas.config") != null;

    Properties commonProps = new Properties();
    commonProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
    // Copy security-related properties from cloud.properties
    CloudConfig.copySecurity(cloud, commonProps);

    // Create topic before producing messages (best-effort)
    short rf = (short) (isCloud ? 3 : 1);
    try {
      createTopicsIfNotExist(commonProps, new String[]{topic}, 1, rf);
    } catch (Exception e) {
      logger.warn("Unable to create topic '{}': {}", topic, e.toString());
    }

    // Producer-specific properties
    Properties producerProps = new Properties();
    producerProps.putAll(commonProps);
    producerProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
    producerProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

    KafkaProducer<String, String> producer = new KafkaProducer<>(producerProps);

    try (InputStream inputStream = MovieProducer.class.getResourceAsStream("/movies.csv");
         BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {

      String line;
      reader.readLine(); // Skip header
      while ((line = reader.readLine()) != null) {
        ProducerRecord<String, String> record = new ProducerRecord<>(topic, line);
        producer.send(record, (metadata, exception) -> {
          if (exception == null) {
            logger.info("Sent record to {} partition {} with offset {}", metadata.topic(), metadata.partition(), metadata.offset());
          } else {
            logger.error("Error sending record", exception);
          }
        });
      }

    } catch (Exception e) {
      logger.error("Error reading movies file", e);
    } finally {
      producer.close();
    }
  }
}
