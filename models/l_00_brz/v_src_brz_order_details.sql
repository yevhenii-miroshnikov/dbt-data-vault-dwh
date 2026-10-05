SELECT
    order_details_id,
    order_id,
    TRIM(LOWER(pizza_id)) AS pizza_id,
    quantity
FROM {{ source('source_seed_db', 'order_details') }}
WHERE order_details_id IS NOT NULL
  AND order_id IS NOT NULL
  AND pizza_id IS NOT NULL