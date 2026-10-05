SELECT
    TRIM(LOWER(pizza_id)) AS pizza_id,
    TRIM(LOWER(pizza_type_id)) AS pizza_type_id,
    size,
    price
FROM {{ source('source_seed_db', 'pizzas') }}
WHERE pizza_id IS NOT NULL