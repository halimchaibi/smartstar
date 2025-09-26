{{ config(
    materialized='table',
    tags=["marts", "weather", "trends"]
) }}

with city_hourly_trends as (
    select
        city,
        reading_hour,
        count(distinct device_id) as active_devices,
        avg(avg_temperature_celsius) as city_avg_temp,
        avg(avg_humidity) as city_avg_humidity,
        min(min_temperature_celsius) as city_min_temp,
        max(max_temperature_celsius) as city_max_temp
    from {{ ref('int_sensor_hourly_agg') }}
    group by 1, 2
),

city_daily_summary as (
    select
        city,
        date(reading_hour) as weather_date,
        avg(city_avg_temp) as daily_avg_temp,
        min(city_min_temp) as daily_min_temp,
        max(city_max_temp) as daily_max_temp,
        avg(city_avg_humidity) as daily_avg_humidity,
        avg(active_devices) as avg_active_devices
    from city_hourly_trends
    group by 1, 2
)

select
    city,
    weather_date,
    daily_avg_temp,
    daily_min_temp,
    daily_max_temp,
    daily_max_temp - daily_min_temp as daily_temp_range,
    daily_avg_humidity,
    avg_active_devices,
    -- Moving averages for trend analysis
    avg(daily_avg_temp) over (
        partition by city 
        order by weather_date 
        rows between 6 preceding and current row
    ) as temp_7day_avg,
    avg(daily_avg_humidity) over (
        partition by city 
        order by weather_date 
        rows between 6 preceding and current row
    ) as humidity_7day_avg
from city_daily_summary
order by city, weather_date