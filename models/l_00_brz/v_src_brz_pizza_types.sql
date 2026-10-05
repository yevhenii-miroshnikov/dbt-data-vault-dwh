SELECT
    TRIM(LOWER(pizza_type_id)) AS pizza_type_id,
    name,
    category,
    ingredients
FROM {{ source('source_seed_db', 'pizza_types') }}
WHERE pizza_type_id IS NOT NULL