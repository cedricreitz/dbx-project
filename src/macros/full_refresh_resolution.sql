{% macro full_refresh_resolution() %}
  {# Read vars #}
  {% set global_full = var(
    'full_refresh',
    false
  ) %}
  {% set start_layer = var(
    'full_refresh_from',
    none
  ) %}
  {# Parse whitelist string into a list #}
  {% set wl_raw = var(
    'full_refresh_whitelist',
    ''
  ) %}
  {% if wl_raw %}
    {% set whitelist = wl_raw.split(',') | map('trim') | list %}
  {% else %}
    {% set whitelist = [] %}
  {% endif %}

  {# Parse blacklist string into a list #}
  {% set bl_raw = var(
    'full_refresh_blacklist',
    ''
  ) %}
  {% if bl_raw %}
    {% set blacklist = bl_raw.split(',') | map('trim') | list %}
  {% else %}
    {% set blacklist = [] %}
  {% endif %}

  {# Throw error if a model is in both lists #}
  {% if this.name in whitelist and this.name in blacklist %}
    {% do exceptions.raise_compiler_error(
      "Model '" ~ this.name ~ "' is listed in both full_refresh_whitelist and full_refresh_blacklist. Please choose one."
    ) %}
  {% endif %}

  {# Whitelist enables full_refresh #}
  {% if this.name in whitelist %}
    {{ return(True) }}
  {% endif %}

  {# Blacklist disables full_refresh #}
  {% if this.name in blacklist %}
    {{ return(False) }}
  {% endif %}

  {# Global full_refresh var enables full_refresh globally #}
  {% if global_full %}
    {{ return(True) }}
  {% endif %}

  {# Layer based logic: require explicit layer_order var in project config #}
  {% if not start_layer %}
    {{ return(False) }}
  {% endif %}

  {# Pull layer order from project vars, error if missing #}
  {% if not var(
      'layer_order',
      none
    ) %}
    {% do exceptions.raise_compiler_error(
      "`layer_order` variable is not set in dbt_project.yml. Please configure layer_order."
    ) %}
  {% endif %}

  {% set layers = var('layer_order') %}
  {% set model_layer = this.schema | lower %}
  {# or this.database if layers are in DB #}
  {# Ensure valid layers #}
  {% if model_layer not in layers or start_layer not in layers %}
    {{ return(False) }}
  {% endif %}

  {# Compare positions #}
  {% if layers.index(model_layer) >= layers.index(start_layer) %}
    {{ return(True) }}
  {% else %}
    {{ return(False) }}
  {% endif %}
{% endmacro %}
