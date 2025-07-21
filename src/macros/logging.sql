{% macro logging() %}
    {# Only run at execution time #}
    {% if execute %}
        {# Pull out each value #}
        {{ log("Target database: " ~ this.database, info=true) }}
        {{ log("Target schema: " ~ this.schema, info=true) }}
        {{ log("Target table: " ~ this.identifier, info=true) }}
        {{
            log(
                "full_refresh is " ~ (config.get("full_refresh", False) | string),
                info=true,
            )
        }}
    {% endif %}
{% endmacro %}
