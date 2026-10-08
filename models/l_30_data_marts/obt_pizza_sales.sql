{{ config(materialized='view') }}

-- The OBT is current-state enrichment: each Satellite contributes its latest row, not an as-of version.
WITH orders_cte AS (
    SELECT
        h.HUB_ORDER_KEY,
        h.order_id,
        s.order_date,
        s.order_time,
        CAST(s.order_date || ' ' || s.order_time AS TIMESTAMP) AS order_datetime,
        GREATEST(h.LOAD_DATETIME, s.LOAD_DATETIME) AS load_datetime
    FROM {{ ref('hub_order') }} h
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
        GREATEST(h.LOAD_DATETIME, s.LOAD_DATETIME) AS load_datetime
    FROM {{ ref('hub_pizza') }} h
    JOIN (
        SELECT *, ROW_NUMBER() OVER(PARTITION BY HUB_PIZZA_KEY ORDER BY LOAD_DATETIME DESC) as rn
        FROM {{ ref('sat_pizza') }}
    ) s ON h.HUB_PIZZA_KEY = s.HUB_PIZZA_KEY AND s.rn = 1
    -- Retain the sales row when the optional current reference match is absent.
    LEFT JOIN {{ ref('ref_pizza_type') }} r ON s.pizza_type_id = r.pizza_type_id
),

order_items_cte AS (
    SELECT
        l.LNK_ORDER_PIZZA_KEY,
        l.HUB_ORDER_KEY,
        l.HUB_PIZZA_KEY,
        s.order_details_id,
        s.quantity,
        GREATEST(l.LOAD_DATETIME, s.LOAD_DATETIME) AS load_datetime
    FROM {{ ref('lnk_order_pizza') }} l
    JOIN (
        SELECT *, ROW_NUMBER() OVER(PARTITION BY LNK_ORDER_PIZZA_KEY ORDER BY LOAD_DATETIME DESC) as rn
        FROM {{ ref('sat_order_pizza') }}
    ) s ON l.LNK_ORDER_PIZZA_KEY = s.LNK_ORDER_PIZZA_KEY AND s.rn = 1
)

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
    (oi.quantity * p.price) AS total_price,
    p.ingredients,
    -- A reference catalog rebuild must not mark every sales row as newly loaded.
    GREATEST(o.load_datetime, p.load_datetime, oi.load_datetime) AS record_load_datetime
FROM order_items_cte oi
JOIN orders_cte o ON oi.HUB_ORDER_KEY = o.HUB_ORDER_KEY
JOIN pizzas_cte p ON oi.HUB_PIZZA_KEY = p.HUB_PIZZA_KEY
