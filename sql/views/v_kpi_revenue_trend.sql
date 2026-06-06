-- =============================================================
-- v_kpi_revenue_trend.sql
-- Daily and monthly revenue, profit, and units — for trend charts.
--
-- WHEN TO USE:
--   Plot revenue growth over time, compare Retail vs Wholesale,
--   spot best and worst months, track refund patterns.
--
-- CHARTS TO BUILD:
--   1. Line chart  — sale_date (X) vs net_sales_amount (Y)
--                    Legend: sales_channel (Retail / Wholesale)
--      Shows:  which channel drives revenue day by day
--
--   2. Clustered bar chart — yr_month (X) vs monthly_revenue (Y)
--                            Legend: sales_channel
--      Shows:  monthly revenue comparison Retail vs Wholesale
--
--   3. Line chart — yr_month (X) vs monthly_gross_margin_pct (Y)
--      Shows:  is margin improving or shrinking month on month
--
--   4. Bar chart  — yr_month (X) vs monthly_refunds (Y)
--      Shows:  refund spikes that need investigation
-- =============================================================

CREATE OR REPLACE VIEW v_kpi_revenue_trend AS
SELECT
    s.sale_date,
    YEAR(s.sale_date)                                               AS sale_year,
    MONTH(s.sale_date)                                              AS sale_month,
    DATE_FORMAT(s.sale_date, '%Y-%m')                               AS yr_month,
    s.sales_channel,
    s.category,
    s.brand,
    s.warehouse,
    SUM(s.net_sales_amount)                                         AS daily_revenue,
    SUM(s.gross_profit)                                             AS daily_profit,
    SUM(s.net_sales_quantity)                                       AS daily_units_sold,
    SUM(s.refund_quantity)                                          AS daily_refunds,
    ROUND(AVG(s.gross_margin_pct), 2)                               AS daily_gross_margin_pct,
    SUM(SUM(s.net_sales_amount)) OVER (
        PARTITION BY s.sales_channel
        ORDER BY s.sale_date
        ROWS UNBOUNDED PRECEDING
    )                                                               AS cumulative_revenue,
    SUM(SUM(s.gross_profit)) OVER (
        PARTITION BY s.sales_channel
        ORDER BY s.sale_date
        ROWS UNBOUNDED PRECEDING
    )                                                               AS cumulative_profit
FROM stg_sales s
GROUP BY
    s.sale_date, s.sales_channel, s.category, s.brand, s.warehouse;