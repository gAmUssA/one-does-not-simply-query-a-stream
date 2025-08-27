package dev.gamov.query.kafka;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Loads Confluent Cloud client and Schema Registry settings from
 * src/main/resources/cloud.properties on the classpath.
 * Falls back to empty Properties if file is not available.
 */
public final class CloudConfig {

  private static final Logger logger = LoggerFactory.getLogger(CloudConfig.class);

  private CloudConfig() {}

  /**
   * Load cloud.properties from the classpath.
   */
  public static Properties load() {
    Properties p = new Properties();
    try (InputStream in = CloudConfig.class.getResourceAsStream("/cloud.properties")) {
      if (in != null) {
        p.load(in);
        logger.info("Loaded cloud.properties with {} entries", p.size());
      } else {
        logger.warn("cloud.properties not found on classpath; using defaults/local settings");
      }
    } catch (IOException e) {
      logger.warn("Failed to load cloud.properties: {}", e.toString());
    }
    return p;
  }

  /**
   * Convenience: copy a known subset of security-related keys into target.
   */
  public static void copySecurity(Properties source, Properties target) {
    copyIfPresent(source, target, "security.protocol");
    copyIfPresent(source, target, "sasl.mechanism");
    copyIfPresent(source, target, "sasl.jaas.config");
    copyIfPresent(source, target, "client.dns.lookup");
    copyIfPresent(source, target, "ssl.endpoint.identification.algorithm");
  }

  /**
   * Convenience: derive schema registry serde config from cloud.properties.
   */
  public static Properties schemaRegistrySerdeConfig(Properties cloud) {
    Properties serde = new Properties();
    String srUrl = cloud.getProperty("schema.registry.url");
    if (srUrl != null && !srUrl.isBlank()) {
      serde.setProperty("schema.registry.url", srUrl);
    }
    // Accept both keys; map cloud's schema.registry.basic.auth.user.info to the standard key
    String userInfo = cloud.getProperty("schema.registry.basic.auth.user.info");
    if (userInfo == null || userInfo.isBlank()) {
      userInfo = cloud.getProperty("basic.auth.user.info");
    }
    if (userInfo != null && !userInfo.isBlank()) {
      serde.setProperty("basic.auth.credentials.source", "USER_INFO");
      serde.setProperty("basic.auth.user.info", userInfo);
    }
    return serde;
  }

  private static void copyIfPresent(Properties source, Properties target, String key) {
    String v = source.getProperty(key);
    if (v != null) target.setProperty(key, v);
  }
}
