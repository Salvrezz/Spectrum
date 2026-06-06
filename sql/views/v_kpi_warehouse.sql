-- =============================================================
-- v_kpi_warehouse.sql
-- Revenue, stock, and velocity per warehouse location.
--
-- WHEN TO USE:
--   See which warehouses sell the most, which are overstocked,
--   which locations have dead stock tying up capital.
--
-- CHARTS TO BUILD:
--   1. Horizontal bar chart — warehouse (Y) vs total_revenue (X)
--      Sort descending
--      Shows:  top performing locations
--
--   2. Clustered bar chart — warehouse (X)
--                            total_revenue vs current_stock_value (Y)
--      Shows:  is stock proportional to sales at each location
--
--   3. Bar chart — warehouse (X) vs capital_at_risk (Y)
--      Color: red if capital_at_risk > total_revenue
--      Shows:  which warehouses are sitting on too much dead stock
--
--   4. Map visual (if lat/long added later) — warehouse locations
--      Size: total_revenue
-- =============================================================

CREATE OR REPLACE VIEW v_kpi_warehouse AS
WITH sales_by_wh AS (
    SELECT
        warehouse,
        ROUND(SUM(net_sales_amount), 2)     AS total_revenue,
        ROUND(SUM(gross_profit), 2)         AS total_profit,
        SUM(net_sales_quantity)             AS total_units_sold,
        ROUND(AVG(gross_margin_pct), 2)     AS avg_margin_pct,
        SUM(refund_quantity)                AS total_refunds,
        COUNT(DISTINCT product_no)          AS unique_products_sold,
        COUNT(DISTINCT sale_date)           AS selling_days
    FROM stg_sales
    GROUP BY warehouse
),
stock_by_wh AS (
    SELECT
        warehouse,
        SUM(closing_qty)                    AS current_stock_qty,
        ROUND(SUM(closing_cost), 2)         AS current_stock_value
    FROM (
        SELECT warehouse, closing_qty, closing_cost,
        ROW_NUMBER() OVER (
            PARTITION BY product_no, warehouse
            ORDER BY movement_date DESC, id DESC
        ) AS rn
        FROM stg_stocks
    ) t WHERE rn = 1
    GROUP BY warehouse
)
SELECT
    COALESCE(s.warehouse, st.warehouse)         AS warehouse,
    COALESCE(s.total_revenue, 0)                AS total_revenue,
    COALESCE(s.total_profit, 0)                 AS total_profit,
    COALESCE(s.avg_margin_pct, 0)               AS avg_margin_pct,
    COALESCE(s.total_units_sold, 0)             AS total_units_sold,
    COALESCE(s.total_refunds, 0)                AS total_refunds,
    COALESCE(s.unique_products_sold, 0)         AS unique_products_sold,
    COALESCE(s.selling_days, 0)                 AS selling_days,
    COALESCE(st.current_stock_qty, 0)           AS current_stock_qty,
    COALESCE(st.current_stock_value, 0)         AS current_stock_value,
    ROUND(
        COALESCE(st.current_stock_value, 0) /
        NULLIF(COALESCE(s.total_revenue, 0), 0) * 100,
    2)                                          AS stock_to_revenue_ratio_pct,
    CASE
        WHEN COALESCE(s.total_revenue, 0) = 0
         AND COALESCE(st.current_stock_value, 0) > 0 THEN 'No sales - review stock'
        WHEN COALESCE(st.current_stock_value, 0) >
             COALESCE(s.total_revenue, 0)            THEN 'Overstocked'
        WHEN COALESCE(st.current_stock_qty, 0) = 0  THEN 'No stock'
        ELSE 'Balanced'
    END                                         AS warehouse_status
FROM sales_by_wh s
LEFT JOIN stock_by_wh st ON st.warehouse = s.warehouse
UNION
SELECT
    st.warehouse,
    0, 0, 0, 0, 0, 0, 0,
    st.current_stock_qty,
    st.current_stock_value,
    NULL,
    'No sales - review stock'
FROM stock_by_wh st
WHERE st.warehouse NOT IN (SELECT warehouse FROM sales_by_wh)
ORDER BY total_revenue DESC;