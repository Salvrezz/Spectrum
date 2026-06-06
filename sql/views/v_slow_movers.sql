-- =============================================================
-- v_slow_movers.sql
-- Products with high stock but low/no sales.
-- These should NOT be purchased more — they are tying up cash.
-- =============================================================

CREATE OR REPLACE VIEW v_slow_movers AS
WITH sales_last60 AS (
    SELECT product_no,
        SUM(net_sales_quantity) AS qty_sold_60d,
        SUM(net_sales_amount)   AS revenue_60d,
        SUM(gross_profit)       AS profit_60d,
        MAX(sale_date)          AS last_sale_date
    FROM stg_sales
    WHERE sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 60 DAY)
    GROUP BY product_no
),
all_time_sales AS (
    SELECT product_no,
        SUM(net_sales_quantity) AS qty_sold_all_time,
        MAX(sale_date)          AS last_sale_ever
    FROM stg_sales
    GROUP BY product_no
),
current_stock AS (
    SELECT product_no,
        SUM(closing_qty)  AS total_current_qty,
        SUM(closing_cost) AS total_current_cost
    FROM (
        SELECT product_no, warehouse, closing_qty, closing_cost,
        ROW_NUMBER() OVER (
            PARTITION BY product_no, warehouse
            ORDER BY movement_date DESC, id DESC
        ) AS rn
        FROM stg_stocks
    ) ranked
    WHERE rn = 1
    GROUP BY product_no
)
SELECT
    cs.product_no,
    p.product_name,
    p.category,
    p.brand,
    cs.total_current_qty                                            AS current_stock_qty,
    cs.total_current_cost                                           AS current_stock_cost,
    COALESCE(s60.qty_sold_60d, 0)                                  AS qty_sold_last_60d,
    COALESCE(s60.revenue_60d, 0)                                   AS revenue_last_60d,
    COALESCE(s60.profit_60d, 0)                                    AS profit_last_60d,
    ats.last_sale_ever,
    DATEDIFF(CURDATE(), ats.last_sale_ever)                        AS days_since_last_sale,
    ROUND(cs.total_current_qty * COALESCE(p.purchase_price, 0), 2) AS capital_at_risk,
    CASE
        WHEN p.purchase_price > 0 AND p.retail_price > 0
        THEN ROUND(((p.retail_price - p.purchase_price) / p.retail_price) * 100, 2)
        ELSE NULL
    END                                                             AS gross_margin_pct,
    CASE
        WHEN ats.last_sale_ever IS NULL                            THEN 'Never sold'
        WHEN DATEDIFF(CURDATE(), ats.last_sale_ever) > 90
         AND cs.total_current_qty > 0                             THEN 'Dead stock'
        WHEN COALESCE(s60.qty_sold_60d, 0) = 0
         AND cs.total_current_qty > 0                             THEN 'No sales in 60 days'
        WHEN COALESCE(s60.qty_sold_60d, 0) < 5
         AND cs.total_current_qty > 20                            THEN 'Overstocked'
        ELSE 'Borderline'
    END                                                             AS slow_mover_flag,
    CASE
        WHEN cs.total_current_qty > COALESCE(s60.qty_sold_60d, 0) * 3
        THEN 'Do not purchase'
        WHEN COALESCE(s60.qty_sold_60d, 0) = 0
         AND cs.total_current_qty > 0
        THEN 'Do not purchase'
        ELSE 'Review before purchasing'
    END                                                             AS purchase_recommendation,
    p.purchase_price,
    p.retail_price
FROM current_stock cs
LEFT JOIN sales_last60   s60 ON s60.product_no = cs.product_no
LEFT JOIN all_time_sales ats ON ats.product_no  = cs.product_no
LEFT JOIN stg_products   p   ON p.product_no    = cs.product_no
WHERE cs.total_current_qty > 0
AND (
    COALESCE(s60.qty_sold_60d, 0) < 5
    OR ats.last_sale_ever IS NULL
    OR DATEDIFF(CURDATE(), ats.last_sale_ever) > 60
)
ORDER BY cs.total_current_cost DESC;