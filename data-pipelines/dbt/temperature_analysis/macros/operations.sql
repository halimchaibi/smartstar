{% macro discover_tables() %}
  {% set catalogs = ['sensors', 'smartstar', 'spark_catalog'] %}
  
  {% for catalog in catalogs %}
    {{ log("=== Checking catalog: " ~ catalog ~ " ===", info=True) }}
    
    {% set query %}
      SHOW TABLES IN {{ catalog }}
    {% endset %}
    
    {% if execute %}
      {% set results = run_query(query) %}
      {% if results %}
        {% for row in results %}
          {{ log("Found table: " ~ catalog ~ "." ~ row[1] ~ "." ~ row[0], info=True) }}
        {% endfor %}
      {% else %}
        {{ log("No tables found in " ~ catalog, info=True) }}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endmacro %}