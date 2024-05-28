package com.example;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Properties;

public class MovieProducer {

  private static final Logger logger = LoggerFactory.getLogger(MovieProducer.class);
  private static final String TOPIC = "input-topic";

  public static void main(String[] args) {
    Properties props = new Properties();
    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:29092");
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

    KafkaProducer<String, String> producer = new KafkaProducer<>(props);

    try (InputStream inputStream = MovieProducer.class.getResourceAsStream("/movies.csv");
         BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {

      String line;
      reader.readLine(); // Skip header
      while ((line = reader.readLine()) != null) {
        ProducerRecord<String, String> record = new ProducerRecord<>(TOPIC, line);
        producer.send(record, (metadata, exception) -> {
          if (exception == null) {
            logger.info("Sent record with offset: {}", metadata.offset());
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