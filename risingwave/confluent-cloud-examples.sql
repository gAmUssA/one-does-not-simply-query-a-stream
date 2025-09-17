-- 🌊 RisingWave with Confluent Cloud + Schema Registry + Avro
-- ==========================================================
-- 
-- Complete example for connecting RisingWave to Confluent Cloud using:
-- - Kafka as the message broker
-- - Schema Registry for Avro schema management  
-- - Avro format for structured data
--
-- Prerequisites:
-- 1. Configure your .env file with Confluent Cloud credentials
-- 2. Start RisingWave: make start
-- 3. Run with variable substitution: envsubst < confluent-cloud-examples.sql | docker compose exec -i psql-client psql -h risingwave -p 4566 -d dev -U root

-- =====================================================
-- 1. CREATE AVRO SOURCE WITH SCHEMA REGISTRY
-- =====================================================

-- Main flights source using Avro format with Schema Registry
-- Schema exactly matches flight.avsc structure
CREATE SOURCE flights_stream (
    "flightNumber" VARCHAR,
    "airline" VARCHAR,
    "origin" VARCHAR,
    "destination" VARCHAR,
    "scheduledDeparture" BIGINT,  -- milliseconds since epoch
    "actualDeparture" BIGINT,     -- nullable union type ["null", "long"]
    "status" VARCHAR
) WITH (
    connector = 'kafka',
    topic = 'flights',
    properties.bootstrap.server = '${BOOTSTRAP_SERVERS}',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_API_KEY}',
    properties.sasl.password = '${KAFKA_API_SECRET}',
    scan.startup.mode = 'earliest'
) FORMAT PLAIN ENCODE AVRO (
    schema.registry = 'https://${SCHEMA_REGISTRY_URL}',
    schema.registry.username = '${SCHEMA_REGISTRY_API_KEY}',
    schema.registry.password = '${SCHEMA_REGISTRY_API_SECRET}'
);

-- =====================================================
-- 2. REAL-TIME STREAM PROCESSING VIEWS
-- =====================================================

-- Real-time delayed flights detection (>15 minutes late)
CREATE MATERIALIZED VIEW delayed_flights AS
SELECT 
    "flightNumber",
    "airline",
    "origin",
    "destination",
    "scheduledDeparture",
    "actualDeparture",
    ("actualDeparture" - "scheduledDeparture") / 60000.0 as delay_minutes,  -- convert ms to minutes
    "status"
FROM flights_stream
WHERE "actualDeparture" IS NOT NULL 
  AND "actualDeparture" > "scheduledDeparture" + 900000;  -- 15 minutes in milliseconds

-- Airline performance metrics
CREATE MATERIALIZED VIEW airline_performance AS
SELECT 
    airline,
    COUNT(*) as total_flights,
    COUNT(CASE WHEN status = 'DELAYED' THEN 1 END) as delayed_count,
    COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END) as cancelled_count,
    ROUND(
        COUNT(CASE WHEN status = 'DELAYED' THEN 1 END)::NUMERIC / 
        NULLIF(COUNT(*), 0)::NUMERIC * 100, 2
    ) as delay_percentage,
    AVG(
        CASE 
            WHEN "actualDeparture" IS NOT NULL AND "actualDeparture" > "scheduledDeparture" 
            THEN ("actualDeparture" - "scheduledDeparture") / 60000.0  -- convert ms to minutes
            ELSE 0 
        END
    ) as avg_delay_minutes
FROM flights_stream
GROUP BY airline;

-- Hourly flight statistics with tumbling window
CREATE MATERIALIZED VIEW hourly_flight_summary AS
WITH flights_ts AS (
    SELECT 
        *,
        TO_TIMESTAMP("scheduledDeparture" / 1000) AS scheduled_ts
    FROM flights_stream
)
SELECT 
    window_start,
    window_end,
    COUNT(*) as flights_scheduled,
    COUNT(CASE WHEN status = 'ON_TIME' THEN 1 END) as on_time_flights,
    COUNT(CASE WHEN status = 'DELAYED' THEN 1 END) as delayed_flights,
    COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END) as cancelled_flights,
    ROUND(
        COUNT(CASE WHEN status = 'ON_TIME' THEN 1 END)::NUMERIC / 
        NULLIF(COUNT(*), 0)::NUMERIC * 100, 2
    ) as on_time_percentage
FROM TUMBLE(flights_ts, scheduled_ts, INTERVAL '1 hour')
GROUP BY window_start, window_end;

-- Airport congestion analysis
CREATE MATERIALIZED VIEW airport_congestion AS
SELECT 
    origin as airport,
    COUNT(*) as departing_flights,
    COUNT(CASE WHEN status = 'DELAYED' THEN 1 END) as delayed_departures,
    ROUND(
        COUNT(CASE WHEN status = 'DELAYED' THEN 1 END)::NUMERIC / 
        NULLIF(COUNT(*), 0)::NUMERIC * 100, 2
    ) as delay_rate_percentage
FROM flights_stream
GROUP BY origin
HAVING COUNT(*) > 5  -- Only airports with significant traffic
ORDER BY delay_rate_percentage DESC;

-- =====================================================
-- 3. SINK BACK TO CONFLUENT CLOUD
-- =====================================================

-- Send critical flight alerts back to Confluent Cloud
CREATE SINK flight_alerts_sink AS
SELECT 
    "flightNumber",
    airline,
    origin,
    destination,
    delay_minutes,
    'CRITICAL_DELAY' as alert_type,
    TO_TIMESTAMP("actualDeparture" / 1000) as alert_timestamp
FROM delayed_flights 
WHERE delay_minutes > 60  -- Delays over 1 hour
WITH (
    connector = 'kafka',
    topic = 'flight-alerts',
    properties.bootstrap.server = '${BOOTSTRAP_SERVERS}',
    properties.security.protocol = 'SASL_SSL',
    properties.sasl.mechanism = 'PLAIN',
    properties.sasl.username = '${KAFKA_API_KEY}',
    properties.sasl.password = '${KAFKA_API_SECRET}',
    primary_key = 'flightNumber'
) FORMAT UPSERT ENCODE JSON;

-- =====================================================
-- 4. MONITORING AND VALIDATION QUERIES
-- =====================================================

-- Check system status
-- SELECT * FROM rw_sources;
-- SELECT * FROM rw_materialized_views;
-- SELECT * FROM rw_sinks;

-- View recent flight data
-- SELECT * FROM flights_stream ORDER BY "scheduledDeparture" DESC LIMIT 10;

-- Monitor delayed flights in real-time
-- SELECT * FROM delayed_flights ORDER BY delay_minutes DESC LIMIT 20;

-- Check airline performance
-- SELECT * FROM airline_performance ORDER BY delay_percentage DESC;

-- View hourly statistics
-- SELECT * FROM hourly_flight_summary ORDER BY window_start DESC LIMIT 24;

-- Check airport congestion
-- SELECT * FROM airport_congestion LIMIT 10;

-- =====================================================
-- 5. CLEANUP (UNCOMMENT TO USE)
-- =====================================================

-- DROP MATERIALIZED VIEW IF EXISTS delayed_flights;
-- DROP MATERIALIZED VIEW IF EXISTS airline_performance;
-- DROP MATERIALIZED VIEW IF EXISTS hourly_flight_summary;
-- DROP MATERIALIZED VIEW IF EXISTS airport_congestion;
-- DROP SINK IF EXISTS flight_alerts_sink;
-- DROP SOURCE IF EXISTS flights_stream;

-- =====================================================
-- NOTES:
-- =====================================================
-- 1. Replace ${VARIABLE} placeholders with actual values from your .env file
-- 2. Adjust schema fields based on your actual Kafka topic structure
-- 3. For Avro sources, ensure your Schema Registry contains the correct schema
-- 4. Monitor RisingWave logs for connection issues: make logs
-- 5. Use 'SHOW SOURCES;' to verify source creation
-- 6. Use 'DESCRIBE <source_name>;' to check source schema
