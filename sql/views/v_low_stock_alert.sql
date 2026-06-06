-- =============================================================
-- v_low_stock_alert.sql
-- Products approaching zero stock — need reorder soon.
-- Uses the average daily sales rate to estimate days of stock left.
-- =============================================================

CREATE OR REPLACE VIEW v_low_stock_alert AS
WITH current_stock AS (
    SELECT product_no, warehouse,
        closing_qty   AS current_stock_qty,
        closing_cost  AS current_stock_value,
        movement_date AS snapshot_date
    FROM (
        SELECT product_no, warehouse, closing_qty, closing_cost, movement_date,
        ROW_NUMBER() OVER (
            PARTITION BY product_no, warehouse
            ORDER BY movement_date DESC, id DESC
        ) AS rn
        FROM stg_stocks
    ) ranked
    WHERE rn = 1
),
avg_daily_sales AS (
    SELECT product_no, warehouse,
        SUM(net_sales_quantity)                                     AS total_sold_30d,
        COUNT(DISTINCT sale_date)                                   AS selling_days,
        ROUND(
            SUM(net_sales_quantity) / NULLIF(COUNT(DISTINCT sale_date), 0),
        2)                                                          AS avg_daily_qty
    FROM stg_sales
    WHERE sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
    GROUP BY product_no, warehouse
)
SELECT
    cs.product_no,
    p.product_name,
    p.category,
    p.brand,
    cs.warehouse,
    cs.current_stock_qty,
    cs.current_stock_value,
    cs.snapshot_date,
    COALESCE(ads.avg_daily_qty, 0)                                  AS rolling_30d_daily_velocity,
    COALESCE(ads.total_sold_30d, 0)                                 AS qty_sold_last_30d,
    CASE
        WHEN ads.avg_daily_qty > 0
        THEN ROUND(cs.current_stock_qty / ads.avg_daily_qty, 0)
        ELSE NULL
    END                                                             AS days_of_stock_remaining,
    CASE
        WHEN cs.current_stock_qty <= 0                             THEN 'Out of stock'
        WHEN ads.avg_daily_qty > 0
         AND (cs.current_stock_qty / ads.avg_daily_qty) <= 7      THEN 'Critical'
        WHEN ads.avg_daily_qty > 0
         AND (cs.current_stock_qty / ads.avg_daily_qty) <= 14     THEN 'Warning'
        WHEN ads.avg_daily_qty > 0
         AND (cs.current_stock_qty / ads.avg_daily_qty) <= 30     THEN 'Low'
        ELSE 'OK'
    END                                                             AS stock_alert,
    ROUND(cs.current_stock_qty * COALESCE(p.purchase_price, 0), 2) AS capital_at_risk,
    p.purchase_price,
    p.retail_price,
    CASE
        WHEN p.purchase_price > 0 AND p.retail_price > 0
        THEN ROUND(((p.retail_price - p.purchase_price) / p.retail_price) * 100, 2)
        ELSE NULL
    END                                                             AS gross_margin_pct
FROM current_stock cs
LEFT JOIN avg_daily_sales ads ON ads.product_no = cs.product_no AND ads.warehouse = cs.warehouse
LEFT JOIN stg_products    p   ON p.product_no   = cs.product_no
WHERE cs.current_stock_qty <= 0
   OR (ads.avg_daily_qty > 0 AND (cs.current_stock_qty / ads.avg_daily_qty) <= 30);