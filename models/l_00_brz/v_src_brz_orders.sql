SELECT
    order_id,
    date AS order_date,
    time AS order_time
FROM {{ source('source_seed_db', 'orders') }}
WHERE order_id IS NOT NULL