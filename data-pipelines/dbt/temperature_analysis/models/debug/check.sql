{{ config(materialized='view') }}

{% set query %}
SELECT 
  current_catalog() as current_catalog,
  current_database() as current_database,
  'sensors' as expected_catalog
{% endset %}

{% if execute %}
  {% set results = run_query(query) %}
  {% for row in results %}
    {{ log("Current catalog: " ~ row[0], info=True) }}
    {{ log("Current database: " ~ row[1], info=True) }}
    {{ log("Expected catalog: " ~ row[2], info=True) }}
  {% endfor %}
{% endif %}

{{ query }}