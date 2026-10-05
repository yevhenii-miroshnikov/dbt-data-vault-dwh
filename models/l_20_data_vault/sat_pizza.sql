{%- set yaml_metadata -%}
source_model: 'v_stg_pizzas'
src_pk: 'HUB_PIZZA_KEY'
src_hashdiff:
  source_column: 'SAT_PIZZA_HASHDIFF'
  alias: 'SAT_PIZZA_HASHDIFF'
src_payload:
  - 'pizza_type_id'
  - 'size'
  - 'price'
src_ldts: 'LOAD_DATETIME'
src_source: 'RECORD_SOURCE'
{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{{ automate_dv.sat(src_pk=metadata_dict['src_pk'],
                   src_hashdiff=metadata_dict['src_hashdiff'],
                   src_payload=metadata_dict['src_payload'],
                   src_ldts=metadata_dict['src_ldts'],
                   src_source=metadata_dict['src_source'],
                   source_model=metadata_dict['source_model']) }}