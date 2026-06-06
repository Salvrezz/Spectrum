-- =============================================================
-- v_kpi_channel_split.sql
-- Retail vs Wholesale performance side by side.
--
-- WHEN TO USE:
--   Understand which channel drives more volume vs more margin.
--   Helps decide where to push stock — sell bulk wholesale
--   or hold for retail markup.
--
-- CHARTS TO BUILD:
--   1. Clustered bar chart — yr_month (X)
--                            Retail revenue vs Wholesale revenue (Y)
--      Shows:  which channel is growing faster month on month
--
--   2. Donut chart — sales_channel vs total_revenue
--      Shows:  overall revenue split between channels
--
--   3. Line chart — yr_month (X) vs avg_margin_pct (Y)
--      Legend: sales_channel
--      Shows:  retail typically has higher margin — confirm this
--
--   4. Clustered bar chart — category (X)
--                            retail_revenue vs wholesale_revenue (Y)
--      Shows:  which categories are bought retail vs bulk wholesale
-- =============================================================

CREATE OR REPLACE VIEW v_kpi_channel_split AS
SELECT
    DATE_FORMAT(sale_date, '%Y-%m')                                 AS yr_month,
    sales_channel,
    category,
    brand,
    SUM(net_sales_quantity)                                         AS total_units,
    ROUND(SUM(net_sales_amount), 2)                                 AS total_revenue,
    ROUND(SUM(gross_profit), 2)                                     AS total_profit,
    ROUND(AVG(gross_margin_pct), 2)                                 AS avg_margin_pct,
    SUM(refund_quantity)                                            AS total_refunds,
    COUNT(DISTINCT product_no)                                      AS unique_products,
    COUNT(DISTINCT warehouse)                                       AS active_warehouses,
    ROUND(SUM(net_sales_amount) / NULLIF(SUM(net_sales_quantity), 0), 2) AS avg_unit_price
FROM stg_sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m'), sales_channel, category, brand
ORDER BY yr_month, sales_channel;