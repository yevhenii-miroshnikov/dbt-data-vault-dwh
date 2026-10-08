{{ config(materialized='view') }}

WITH orders_cte AS (
    SELECT
        h.HUB_ORDER_KEY,
        h.order_id,
        s.order_date,
        s.order_time,
        -- Resolve temporal split by casting concatenated date and time to TIMESTAMP
        CAST(s.order_date || ' ' || s.order_time AS TIMESTAMP) AS order_datetime,
        -- Track latest load timestamp across order entities
        GREATEST(h.LOAD_DATETIME, s.LOAD_DATETIME) AS load_datetime
    FROM {{ ref('hub_order') }} h
    -- Deduplicate satellite history to ensure the latest state is captured
    JOIN (
        SELECT *, ROW_NUMBER() OVER(PARTITION BY HUB_ORDER_KEY ORDER BY LOAD_DATETIME DESC) as rn
        FROM {{ ref('sat_order') }}
    ) s ON h.HUB_ORDER_KEY = s.HUB_ORDER_KEY AND s.rn = 1
),

pizzas_cte AS (
    SELECT
        h.HUB_PIZZA_KEY,
        h.pizza_id,
        s.pizza_type_id,
        s.size,
        s.price,
        r.name AS pizza_name,
        r.category,
        r.ingredients,
        -- Track latest load timestamp across sales-related pizza components
        GREATEST(h.LOAD_DATETIME, s.LOAD_DATETIME) AS load_datetime
    FROM {{ ref('hub_pizza') }} h
    -- Deduplicate satellite history to retain current pricing and attributes
    JOIN (
        SELECT *, ROW_NUMBER() OVER(PARTITION BY HUB_PIZZA_KEY ORDER BY LOAD_DATETIME DESC) as rn
        FROM {{ ref('sat_pizza') }}
    ) s ON h.HUB_PIZZA_KEY = s.HUB_PIZZA_KEY AND s.rn = 1
    LEFT JOIN {{ ref('ref_pizza_type') }} r ON s.pizza_type_id = r.pizza_type_id
),

order_items_cte AS (
    SELECT
        l.LNK_ORDER_PIZZA_KEY,
        l.HUB_ORDER_KEY,
        l.HUB_PIZZA_KEY,
        s.order_details_id,
        s.quantity,
        -- Track latest load timestamp for transactional link
        GREATEST(l.LOAD_DATETIME, s.LOAD_DATETIME) AS load_datetime
    FROM {{ ref('lnk_order_pizza') }} l
    -- Deduplicate transaction satellite records
    JOIN (
        SELECT *, ROW_NUMBER() OVER(PARTITION BY LNK_ORDER_PIZZA_KEY ORDER BY LOAD_DATETIME DESC) as rn
        FROM {{ ref('sat_order_pizza') }}
    ) s ON l.LNK_ORDER_PIZZA_KEY = s.LNK_ORDER_PIZZA_KEY AND s.rn = 1
)

-- Final assembly: One Big Table (Universal Relation)
SELECT
    oi.order_details_id,
    o.order_id,
    o.order_datetime,
    p.pizza_id,
    p.pizza_name,
    p.category,
    p.size,
    p.price,
    oi.quantity,
    -- Financial metric calculation: item revenue
    (oi.quantity * p.price) AS total_price,
    p.ingredients,
    -- Latest technical load timestamp across sales-related components
    GREATEST(o.load_datetime, p.load_datetime, oi.load_datetime) AS record_load_datetime
FROM order_items_cte oi
JOIN orders_cte o ON oi.HUB_ORDER_KEY = o.HUB_ORDER_KEY
JOIN pizzas_cte p ON oi.HUB_PIZZA_KEY = p.HUB_PIZZA_KEY
