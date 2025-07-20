{# Override dbt default ref macro #}
{% macro ref(reference) -%}
    {% set env = var('env', target.name) %}
    {{ env ~ '_' ~ reference }}
{%- endmacro %}