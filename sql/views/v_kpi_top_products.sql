-- =============================================================
-- v_kpi_top_products.sql
-- Product-level revenue, profit, velocity, and stock ranking.
-- Ranks every product so Power BI slicers work cleanly.
--
-- WHEN TO USE:
--   Find your top 10 revenue products, top 10 profit products,
--   top 10 fastest moving. Also find bottom 10 to cut or clear.
--
-- CHARTS TO BUILD:
--   1. Horizontal bar chart — product_name (Y) vs total_revenue (X)
--      Filter: TOP N = 10 by revenue_rank
--      Shows:  your 10 biggest revenue drivers
--
--   2. Horizontal bar chart — product_name (Y) vs total_gross_profit (X)
--      Filter: TOP N = 10 by profit_rank
--      Shows:  your 10 most profitable products (different from revenue)
--
--   3. Scatter chart — total_revenue (X) vs avg_gross_margin_pct (Y)
--      Size: total_units_sold   Label: product_name
--      Shows:  high revenue low margin vs low revenue high margin products
--
--   4. Bar chart — product_name (X) vs days_of_stock_remaining (Y)
--      Filter: stock_alert = Critical or Warning
--      Color: red for Critical, orange for Warning
--      Shows:  products about to run out sorted by urgency
--
--   5. Table visual — all columns
--      Filter: reorder_flag = Reorder recommended
--      Shows:  procurement list sorted by revenue rank
-- =============================================================

CREATE OR REPLACE VIEW v_kpi_top_products AS
WITH sales_agg AS (
    SELECT
        product_no, product_name, category, brand,
        SUM(net_sales_quantity)                                     AS total_units_sold,
        ROUND(SUM(net_sales_amount), 2)                             AS total_revenue,
        ROUND(SUM(gross_profit), 2)                                 AS total_gross_profit,
        ROUND(AVG(gross_margin_pct), 2)                             AS avg_gross_margin_pct,
        SUM(refund_quantity)                                        AS total_refunds,
        COUNT(DISTINCT sale_date)                                   AS selling_days,
        MAX(sale_date)                                              AS last_sale_date,
        SUM(CASE WHEN sale_date >= DATE_SUB(
                (SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
            THEN net_sales_quantity ELSE 0 END)                     AS qty_sold_30d,
        ROUND(
            SUM(CASE WHEN sale_date >= DATE_SUB(
                    (SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
                THEN net_sales_quantity ELSE 0 END) /
            NULLIF(COUNT(DISTINCT CASE WHEN sale_date >= DATE_SUB(
                    (SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
                THEN sale_date END), 0),
        2)                                                          AS rolling_30d_daily_velocity
    FROM stg_sales
    GROUP BY product_no, product_name, category, brand
),
current_stock AS (
    SELECT product_no, SUM(closing_qty) AS current_qty
    FROM (
        SELECT product_no, closing_qty,
        ROW_NUMBER() OVER (
            PARTITION BY product_no, warehouse
            ORDER BY movement_date DESC, id DESC
        ) AS rn FROM stg_stocks
    ) t WHERE rn = 1
    GROUP BY product_no
)
SELECT
    sa.product_no,
    sa.product_name,
    sa.category,
    sa.brand,
    sa.total_units_sold,
    sa.total_revenue,
    sa.total_gross_profit,
    sa.avg_gross_margin_pct,
    sa.total_refunds,
    sa.selling_days,
    sa.last_sale_date,
    sa.qty_sold_30d,
    sa.rolling_30d_daily_velocity,
    COALESCE(cs.current_qty, 0)                                     AS current_stock_qty,
    ROUND(COALESCE(cs.current_qty, 0) * COALESCE(p.purchase_price, 0), 2) AS capital_at_risk,
    CASE
        WHEN sa.rolling_30d_daily_velocity > 0
        THEN ROUND(COALESCE(cs.current_qty, 0) / sa.rolling_30d_daily_velocity, 0)
        ELSE NULL
    END                                                             AS days_of_stock_remaining,
    CASE
        WHEN sa.rolling_30d_daily_velocity > 0
         AND COALESCE(cs.current_qty, 0) / sa.rolling_30d_daily_velocity <= 7  THEN 'Critical'
        WHEN sa.rolling_30d_daily_velocity > 0
         AND COALESCE(cs.current_qty, 0) / sa.rolling_30d_daily_velocity <= 14 THEN 'Warning'
        WHEN sa.rolling_30d_daily_velocity > 0
         AND COALESCE(cs.current_qty, 0) / sa.rolling_30d_daily_velocity <= 30 THEN 'Low'
        WHEN COALESCE(cs.current_qty, 0) <= 0                      THEN 'Out of stock'
        ELSE 'OK'
    END                                                             AS stock_alert,
    CASE
        WHEN sa.rolling_30d_daily_velocity > 0
         AND COALESCE(cs.current_qty, 0) < (sa.rolling_30d_daily_velocity * 14) THEN 'Reorder recommended'
        WHEN sa.rolling_30d_daily_velocity > 0
         AND COALESCE(cs.current_qty, 0) < (sa.rolling_30d_daily_velocity * 30) THEN 'Monitor closely'
        ELSE 'Stock sufficient'
    END                                                             AS reorder_flag,
    DENSE_RANK() OVER (ORDER BY sa.total_revenue DESC)              AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY sa.total_gross_profit DESC)         AS profit_rank,
    DENSE_RANK() OVER (ORDER BY sa.qty_sold_30d DESC)               AS velocity_rank,
    p.purchase_price,
    p.retail_price,
    p.unit_of_measure
FROM sales_agg sa
LEFT JOIN current_stock cs ON cs.product_no = sa.product_no
LEFT JOIN stg_products  p  ON p.product_no  = sa.product_no;