{%- set yaml_metadata -%}
source_model: 'v_src_brz_pizza_types'
derived_columns:
  RECORD_SOURCE: '!SEED_PIZZA_TYPES'
  {# Within one dbt invocation, run_started_at provides a shared batch LDTS across staging models. #}
  LOAD_DATETIME: "'{{ run_started_at.isoformat() }}'::timestamptz"
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata_dict['source_model'],
                     derived_columns=metadata_dict['derived_columns'],
                     hashed_columns=none,
                     ranked_columns=none) }}
