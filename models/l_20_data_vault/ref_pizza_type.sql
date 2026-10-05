SELECT
    pizza_type_id,
    LOAD_DATETIME AS ldts,
    RECORD_SOURCE AS rscr,
    name,
    category,
    ingredients
FROM {{ ref('v_stg_pizza_types') }}