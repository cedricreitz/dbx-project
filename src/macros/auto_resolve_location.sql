{# Override dbt default database macro #}
{% macro generate_database_name(custom_database_name, node) -%}
  {%- if custom_database_name -%}
    {{ custom_database_name }}y
  {%- else -%}
    {% set layer = node.path.split('/')[0] %}
    {% set env = var('env', target.name) %}
    {{ env ~ '_' ~ layer }}
  {%- endif -%}
{%- endmacro %}

{# Override dbt default schema macro #}
{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- if custom_schema_name -%}
    {{ custom_schema_name }}
  {%- else -%}
    {{ node.path.split('/')[1] }}
  {%- endif -%}
{%- endmacro %}