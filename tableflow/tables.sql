-- Query: Recent canceled flights summary
SELECT 
  airline,
  origin,
  COUNT(*) AS total_canceled_flights,
  CURRENT_TIMESTAMP as calculation_time
FROM 
  "flights"
WHERE 
  status = 'CANCELLED' 
  AND "scheduledDeparture" >= (TO_UNIXTIME(NOW()) - 3600) * 1000
  AND "scheduledDeparture" <= TO_UNIXTIME(NOW()) * 1000
GROUP BY 
  airline, origin;


--

-- Query: Enriched flights data with status and timing analysis
SELECT
  flightNumber,
  CAST(FROM_UNIXTIME(scheduledDeparture/1000) AS TIMESTAMP(3)) AS scheduled_departure_time,
  airline,
  origin,
  destination,
  CAST(FROM_UNIXTIME(actualDeparture/1000) AS TIMESTAMP(3)) AS actual_departure_time,
  CASE
    WHEN status = 'CANCELLED' THEN 'CANCELLED'
    WHEN actualDeparture IS NULL THEN 'NOT_DEPARTED'
    WHEN actualDeparture <= scheduledDeparture THEN 'ON_TIME'
    WHEN actualDeparture > scheduledDeparture THEN 'DELAYED'
    ELSE 'UNKNOWN'
  END AS departure_status,
  CASE
    WHEN actualDeparture > scheduledDeparture 
    THEN (actualDeparture - scheduledDeparture)/60000
    ELSE 0
  END AS delay_minutes,
  CAST(HOUR(CAST(FROM_UNIXTIME(scheduledDeparture/1000) AS TIMESTAMP)) AS BIGINT) AS hour_of_day,
  CASE
    WHEN HOUR(CAST(FROM_UNIXTIME(scheduledDeparture/1000) AS TIMESTAMP)) BETWEEN 5 AND 9 THEN 'MORNING'
    WHEN HOUR(CAST(FROM_UNIXTIME(scheduledDeparture/1000) AS TIMESTAMP)) BETWEEN 10 AND 15 THEN 'MIDDAY'
    WHEN HOUR(CAST(FROM_UNIXTIME(scheduledDeparture/1000) AS TIMESTAMP)) BETWEEN 16 AND 19 THEN 'EVENING'
    ELSE 'NIGHT'
  END AS time_of_day,
  CURRENT_TIMESTAMP AS processing_time
FROM
  "flights"
WHERE
  scheduledDeparture >= (TO_UNIXTIME(NOW()) - 604800) * 1000
LIMIT 10;