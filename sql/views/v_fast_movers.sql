-- =============================================================
-- v_fast_movers.sql
-- Products selling quickly — candidates for restocking.
-- "Fast mover" = high sell-through rate in recent 30/60 days.
-- Includes a suggested reorder flag to avoid over-purchasing.
-- =============================================================

CREATE OR REPLACE VIEW v_fast_movers AS
WITH sales_velocity AS (
    SELECT
        product_no, product_name, category, brand,
        SUM(CASE WHEN sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
                 THEN net_sales_quantity ELSE 0 END)  AS qty_sold_30d,
        SUM(CASE WHEN sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
                 THEN net_sales_amount   ELSE 0 END)  AS revenue_30d,
        SUM(CASE WHEN sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
                 THEN gross_profit       ELSE 0 END)  AS profit_30d,
        SUM(CASE WHEN sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 60 DAY)
                 THEN net_sales_quantity ELSE 0 END)  AS qty_sold_60d,
        SUM(CASE WHEN sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 60 DAY)
                 THEN net_sales_amount   ELSE 0 END)  AS revenue_60d,
        COUNT(DISTINCT sale_date)                     AS active_selling_days,
        AVG(gross_margin_pct)                         AS avg_margin_pct,
        ROUND(
            SUM(CASE WHEN sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
                     THEN net_sales_quantity ELSE 0 END) /
            NULLIF(COUNT(DISTINCT CASE
                WHEN sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
                THEN sale_date END), 0),
        2)                                            AS rolling_30d_daily_velocity
    FROM stg_sales
    GROUP BY product_no, product_name, category, brand
),
current_stock AS (
    SELECT product_no, SUM(closing_qty) AS total_current_qty
    FROM (
        SELECT product_no, closing_qty,
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
    sv.product_no,
    sv.product_name,
    sv.category,
    sv.brand,
    sv.qty_sold_30d,
    sv.qty_sold_60d,
    sv.revenue_30d,
    sv.revenue_60d,
    sv.profit_30d,
    ROUND(sv.avg_margin_pct, 2)                                     AS avg_margin_pct,
    sv.rolling_30d_daily_velocity,
    cs.total_current_qty                                            AS current_stock_qty,
    CASE
        WHEN sv.rolling_30d_daily_velocity > 0
        THEN ROUND(cs.total_current_qty / sv.rolling_30d_daily_velocity, 0)
        ELSE NULL
    END                                                             AS days_of_stock_remaining,
    ROUND(
        sv.qty_sold_30d / NULLIF(cs.total_current_qty + sv.qty_sold_30d, 0) * 100,
    1)                                                              AS sell_through_rate_pct,
    ROUND(cs.total_current_qty * COALESCE(p.purchase_price, 0), 2) AS capital_at_risk,
    CASE
        WHEN sv.qty_sold_30d >= 50 THEN 'High velocity'
        WHEN sv.qty_sold_30d >= 20 THEN 'Medium velocity'
        WHEN sv.qty_sold_30d >= 5  THEN 'Low velocity'
        ELSE 'Slow'
    END                                                             AS velocity_tier,
    CASE
        WHEN sv.rolling_30d_daily_velocity > 0
         AND cs.total_current_qty < (sv.rolling_30d_daily_velocity * 14) THEN 'Reorder recommended'
        WHEN sv.rolling_30d_daily_velocity > 0
         AND cs.total_current_qty < (sv.rolling_30d_daily_velocity * 30) THEN 'Monitor closely'
        ELSE 'Stock sufficient'
    END                                                             AS reorder_flag,
    p.purchase_price,
    p.retail_price,
    CASE
        WHEN p.purchase_price > 0 AND p.retail_price > 0
        THEN ROUND(((p.retail_price - p.purchase_price) / p.retail_price) * 100, 2)
        ELSE NULL
    END                                                             AS gross_margin_pct
FROM sales_velocity sv
LEFT JOIN current_stock cs ON cs.product_no = sv.product_no
LEFT JOIN stg_products  p  ON p.product_no  = sv.product_no
WHERE sv.qty_sold_30d > 0
ORDER BY sv.qty_sold_30d DESC;