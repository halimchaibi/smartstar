{{ config(
    materialized='table',
    tags=["intermediate", "aggregations"]
) }}

with hourly_readings as (
    select
        device_id,
        city,
        sensor_type,
        latitude,
        longitude,
        date_trunc('hour', device_ts) as reading_hour,
        count(*) as reading_count,
        avg(temperature_celsius) as avg_temperature_celsius,
        min(temperature_celsius) as min_temperature_celsius,
        max(temperature_celsius) as max_temperature_celsius,
        avg(humidity) as avg_humidity,
        min(humidity) as min_humidity,
        max(humidity) as max_humidity,
        stddev(temperature_celsius) as temp_stddev,
        stddev(humidity) as humidity_stddev
    from {{ ref('stg_temperature_sensors') }}
    group by 1, 2, 3, 4, 5, 6
),

enriched_readings as (
    select
        *,
        case 
            when avg_temperature_celsius < 0 then 'freezing'
            when avg_temperature_celsius < 10 then 'cold'
            when avg_temperature_celsius < 25 then 'moderate'
            when avg_temperature_celsius < 35 then 'warm'
            else 'hot'
        end as temperature_category,
        case 
            when avg_humidity < 30 then 'dry'
            when avg_humidity < 60 then 'comfortable'
            else 'humid'
        end as humidity_category
    from hourly_readings
)

select * from enriched_readings