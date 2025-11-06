
select count(*) from flights;

DESCRIBE flights;


--  Flight Delay Analysis by Airline
SELECT 
    airline,
    COUNT(*) as total_flights,
    AVG((actualDeparture - scheduledDeparture) / 60.0) as avg_delay_minutes,
    COUNT(CASE WHEN actualDeparture > scheduledDeparture THEN 1 END) as delayed_flights,
    ROUND(COUNT(CASE WHEN actualDeparture > scheduledDeparture THEN 1 END) * 100.0 / COUNT(*), 2) as delay_percentage
FROM flights
WHERE actualDeparture IS NOT NULL
GROUP BY airline
ORDER BY avg_delay_minutes DESC
LIMIT 10;

-- Busiest Routes Analysis
SELECT 
    origin || ' → ' || destination as route,
    COUNT(*) as flight_count,
    COUNT(DISTINCT airline) as airlines_serving,
    AVG((actualDeparture - scheduledDeparture) / 60.0) as avg_delay_minutes,
    COUNT(CASE WHEN status = 'on_time' THEN 1 END) as on_time_count,
    COUNT(CASE WHEN status = 'delayed' THEN 1 END) as delayed_count,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_count
FROM flights
GROUP BY origin, destination
HAVING COUNT(*) >= 5
ORDER BY flight_count DESC
LIMIT 20;

SELECT 
    EXTRACT(hour FROM to_timestamp(scheduledDeparture)) as departure_hour,
    COUNT(*) as scheduled_flights,
    AVG(CASE 
        WHEN actualDeparture IS NOT NULL 
        THEN (actualDeparture - scheduledDeparture) / 60.0
        ELSE 0 
    END) as avg_delay_minutes,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancellations,
    ROUND(COUNT(CASE WHEN status = 'cancelled' THEN 1 END) * 100.0 / COUNT(*), 2) as cancellation_rate
FROM flights
GROUP BY EXTRACT(hour FROM to_timestamp(scheduledDeparture))
ORDER BY departure_hour;

-- Airport Performance Comparison
WITH airport_stats AS (
    SELECT 
        origin as airport,
        'departure' as operation_type,
        COUNT(*) as flight_count,
        AVG((actualDeparture - scheduledDeparture) / 60.0) as avg_delay
    FROM flights
    WHERE actualDeparture IS NOT NULL
    GROUP BY origin
    
    UNION ALL
    
    SELECT 
        destination as airport,
        'arrival' as operation_type,
        COUNT(*) as flight_count,
        AVG((actualDeparture - scheduledDeparture) / 60.0) as avg_delay
    FROM flights
    WHERE actualDeparture IS NOT NULL
    GROUP BY destination
)
SELECT 
    airport,
    SUM(flight_count) as total_flights,
    AVG(avg_delay) as overall_avg_delay,
    MAX(CASE WHEN operation_type = 'departure' THEN avg_delay END) as departure_delay,
    MAX(CASE WHEN operation_type = 'arrival' THEN avg_delay END) as arrival_delay
FROM airport_stats
GROUP BY airport
HAVING SUM(flight_count) >= 10
ORDER BY overall_avg_delay DESC
LIMIT 15;

SELECT 
    status,
    COUNT(*) as flight_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage,
    AVG(CASE 
        WHEN status = 'delayed' AND actualDeparture IS NOT NULL 
        THEN (actualDeparture - scheduledDeparture) / 60.0
        ELSE NULL 
    END) as avg_delay_for_delayed_flights
FROM flights
GROUP BY status
ORDER BY flight_count DESC;

SELECT 
    dayname(to_timestamp(scheduledDeparture)) as day_of_week,
    EXTRACT(dayofweek FROM to_timestamp(scheduledDeparture)) as day_num,
    COUNT(*) as total_flights,
    AVG((actualDeparture - scheduledDeparture) / 60.0) as avg_delay_minutes,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancellations,
    ROUND(COUNT(CASE WHEN status = 'cancelled' THEN 1 END) * 100.0 / COUNT(*), 2) as cancellation_rate
FROM flights
WHERE actualDeparture IS NOT NULL
GROUP BY dayname(to_timestamp(scheduledDeparture)), EXTRACT(dayofweek FROM to_timestamp(scheduledDeparture))
ORDER BY day_num;


SELECT 
    CASE 
        WHEN (actualDeparture - scheduledDeparture) / 60.0 < 15 THEN 'Short Delay (<15min)'
        WHEN (actualDeparture - scheduledDeparture) / 60.0 < 60 THEN 'Medium Delay (15-60min)'
        WHEN (actualDeparture - scheduledDeparture) / 60.0 < 180 THEN 'Long Delay (1-3hr)'
        ELSE 'Very Long Delay (>3hr)'
    END as delay_category,
    COUNT(*) as flight_count,
    AVG((actualDeparture - scheduledDeparture) / 60.0) as avg_delay_minutes,
    COUNT(DISTINCT airline) as airlines_affected
FROM flights
WHERE actualDeparture IS NOT NULL 
    AND actualDeparture > scheduledDeparture
GROUP BY delay_category
ORDER BY avg_delay_minutes;
