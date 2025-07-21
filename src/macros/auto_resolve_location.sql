{# Override dbt default database macro #}
{% macro generate_database_name(
    custom_database_name,
    node
  ) -%}
  {%- if custom_database_name -%}
    {{ custom_database_name | trim }}
  {%- else -%}
    {% set folder_source = node.path.split("/")[0] %}
    {% set filename_source = node.name.split(".")[0] %}
    {% set env = var('env', target.name) %}
    {%- if folder_source == filename_source -%}
      {{ env ~ '_' ~ filename_source }}
    {%- else -%}
      {{ exceptions.raise_compiler_error("Filename and folder location do not match. \n Please make sure you name the file/folder according to its location following the database/schema and <datbase>.<schema>.<tablename>.sql format. Affected model: " ~ node.path) }}
    {%- endif -%}
  {%- endif -%}
{%- endmacro %}

{# Override dbt default schema macro #}
{% macro generate_schema_name(
    custom_schema_name,
    node
  ) -%}
  {%- if custom_schema_name -%}
    {{ custom_schema_name | trim }}
  {%- else -%}
    {% set folder_source = node.path.split("/")[1] %}
    {% set filename_source = node.name.split(".")[1] %}
    {% set env = var('env', target.name) %}
    {%- if folder_source == filename_source -%}
      {{ filename_source }}
    {%- else -%}
      {{ exceptions.raise_compiler_error("Filename and folder location do not match. \n Please make sure you name the file/folder according to its location following the database/schema and <datbase>.<schema>.<tablename>.sql format. Affected model: " ~ node.path) }}
    {%- endif -%}
  {%- endif -%}
{%- endmacro %}

{# Override dbt default alias macro #}
{% macro generate_alias_name(
    custom_alias_name,
    node
  ) -%}
  {%- if custom_alias_name -%}
    {{ custom_alias_name | trim }}

    {%- elif node.version -%}
    {{ return(node.name.split(".") [2] ~ "_v" ~ (node.version | replace(".", "_"))) }}
  {%- else -%}
    {{ node.name.split(".") [2] }}
  {%- endif -%}
{%- endmacro %}
