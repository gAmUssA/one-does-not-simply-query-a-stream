CREATE TABLE IF NOT EXISTS flight_status (
    flight_number TEXT PRIMARY KEY,
    airline TEXT,
    departure_airport TEXT,
    arrival_airport TEXT,
    scheduled_departure TEXT,
    actual_departure TEXT,
    status TEXT,
    event_timestamp BIGINT
);
