{{ config(
    materialized='table',
    tags=["marts", "analytics"],
) }}

with device_summary as (
    select
        device_id,
        city,
        latitude,
        longitude,
        count(distinct reading_hour) as total_active_hours,
        min(reading_hour) as first_seen,
        max(reading_hour) as last_seen,
        avg(avg_temperature_celsius) as overall_avg_temp,
        avg(avg_humidity) as overall_avg_humidity,
        sum(reading_count) as total_readings,
        avg(reading_count) as avg_readings_per_hour
    from {{ ref('int_sensor_hourly_agg') }}
    group by 1, 2, 3, 4
),

device_health_summary as (
    select
        device_id,
        avg(daily_reading_count) as avg_daily_readings,
        avg(activity_ratio) as avg_activity_ratio,
        -- Replace mode() with a Spark-compatible approach
        first(data_quality_status) as predominant_quality_status,
        count(distinct reading_date) as active_days
    from {{ ref('int_device_health_metrics') }}
    group by 1
)

select
    ds.device_id,
    ds.city,
    ds.latitude,
    ds.longitude,
    ds.total_active_hours,
    ds.first_seen,
    ds.last_seen,
    -- Use Spark's datediff function
    datediff(cast(ds.last_seen as date), cast(ds.first_seen as date)) as days_active,
    ds.overall_avg_temp,
    ds.overall_avg_humidity,
    ds.total_readings,
    ds.avg_readings_per_hour,
    dhs.avg_daily_readings,
    dhs.avg_activity_ratio,
    dhs.predominant_quality_status,
    dhs.active_days,
    current_timestamp() as last_updated
from device_summary ds
left join device_health_summary dhs 
    on ds.device_id = dhs.device_id