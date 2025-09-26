{{ config(
    materialized='view',
    tags=["staging", "sensors"]
) }}

with source_data as (
    select
        device_id,
        device_ts,
        sensor_type,
        latitude,
        longitude,
        city,
        temperature,
        humidity,
        unit,
        event_time,
        year,
        month,
        day
    from {{ source('sensors', 'temperature') }}
    where device_ts is not null
      and device_id is not null
),

cleaned_data as (
    select
        device_id,
        device_ts,
        lower(trim(sensor_type)) as sensor_type,
        round(latitude, 6) as latitude,
        round(longitude, 6) as longitude,
        upper(trim(city)) as city,
        temperature,
        humidity,
        upper(trim(unit)) as unit,
        event_time,
        year,
        month,
        day,
        -- Add derived fields
        case 
            when unit = 'F' then round((temperature - 32) * 5.0/9.0, 2)
            else temperature 
        end as temperature_celsius,
        current_timestamp() as dbt_loaded_at
    from source_data
)

select * from cleaned_data