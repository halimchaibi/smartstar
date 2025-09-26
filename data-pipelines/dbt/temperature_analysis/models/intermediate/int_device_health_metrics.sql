{{ config(
    materialized='table',
    tags=["intermediate", "device_health"]
) }}

with device_daily_stats as (
    select
        device_id,
        city,
        date(device_ts) as reading_date,
        count(*) as daily_reading_count,
        min(device_ts) as first_reading_ts,
        max(device_ts) as last_reading_ts,
        count(distinct date_trunc('hour', device_ts)) as active_hours,
        avg(case when temperature is null then 1.0 else 0.0 end) as temp_null_rate,
        avg(case when humidity is null then 1.0 else 0.0 end) as humidity_null_rate
    from {{ ref('stg_temperature_sensors') }}
    group by 1, 2, 3
),

device_health as (
    select
        *,
        case 
            when daily_reading_count < 24 then 'low_frequency'
            when daily_reading_count > 1440 then 'high_frequency'
            else 'normal'
        end as reading_frequency_status,
        case 
            when temp_null_rate > 0.1 or humidity_null_rate > 0.1 then 'poor'
            when temp_null_rate > 0.05 or humidity_null_rate > 0.05 then 'fair'
            else 'good'
        end as data_quality_status,
        active_hours / 24.0 as activity_ratio
    from device_daily_stats
)

select * from device_health