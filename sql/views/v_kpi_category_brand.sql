-- =============================================================
-- v_kpi_category_brand.sql
-- Revenue, profit, margin, and units by category and brand.
--
-- WHEN TO USE:
--   Find which categories and brands make the most money,
--   which have the best margins, and which are dragging profit down.
--
-- CHARTS TO BUILD:
--   1. Horizontal bar chart — category (Y) vs total_revenue (X)
--      Sort descending by revenue
--      Shows:  PHONES vs ACCESSORIES vs ELECTRONICS contribution
--
--   2. Horizontal bar chart — brand (Y) vs total_gross_profit (X)
--      Sort descending
--      Shows:  which brand is most profitable, not just highest revenue
--
--   3. Scatter chart — avg_gross_margin_pct (X) vs total_revenue (Y)
--      Size: total_units_sold   Legend: category
--      Shows:  high revenue but low margin brands that need attention
--
--   4. Treemap — category → brand → total_revenue
--      Shows:  full revenue breakdown in one visual
--
--   5. Bar chart — category (X) vs refund_rate_pct (Y)
--      Shows:  which categories get returned most
-- =============================================================

CREATE OR REPLACE VIEW v_kpi_category_brand AS
SELECT
    s.category,
    s.brand,
    s.sales_channel,
    COUNT(DISTINCT s.product_no)                                    AS unique_products,
    SUM(s.net_sales_quantity)                                       AS total_units_sold,
    ROUND(SUM(s.net_sales_amount), 2)                               AS total_revenue,
    ROUND(SUM(s.net_sales_cost), 2)                                 AS total_cost,
    ROUND(SUM(s.gross_profit), 2)                                   AS total_gross_profit,
    ROUND(AVG(s.gross_margin_pct), 2)                               AS avg_gross_margin_pct,
    SUM(s.refund_quantity)                                          AS total_refunds,
    ROUND(
        SUM(s.refund_quantity) / NULLIF(SUM(s.net_sales_quantity), 0) * 100,
    2)                                                              AS refund_rate_pct,
    ROUND(SUM(s.net_sales_amount) / NULLIF(SUM(s.net_sales_quantity), 0), 2) AS avg_selling_price,
    COUNT(DISTINCT s.sale_date)                                     AS active_selling_days,
    ROUND(SUM(s.net_sales_amount) / NULLIF(COUNT(DISTINCT s.sale_date), 0), 2) AS avg_daily_revenue
FROM stg_sales s
GROUP BY s.category, s.brand, s.sales_channel;