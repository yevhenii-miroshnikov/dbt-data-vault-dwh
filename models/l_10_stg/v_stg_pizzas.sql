{%- set yaml_metadata -%}
source_model: 'v_src_brz_pizzas'
derived_columns:
  RECORD_SOURCE: '!SEED_PIZZAS'
  LOAD_DATETIME: 'CURRENT_TIMESTAMP'
hashed_columns:
  HUB_PIZZA_KEY: 'pizza_id'
  SAT_PIZZA_HASHDIFF:
    is_hashdiff: true
    columns:
      - 'pizza_type_id'
      - 'size'
      - 'price'
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.stage(include_source_columns=true,
                     source_model=metadata_dict['source_model'],
                     derived_columns=metadata_dict['derived_columns'],
                     hashed_columns=metadata_dict['hashed_columns'],
                     ranked_columns=none) }}