-- =============================================================
-- v_kpi_summary.sql
-- One row per KPI — use this for Power BI card visuals only.
-- Every number here is a headline metric for the top of your dashboard.
--
-- WHEN TO USE: Drag each column onto a Card visual in Power BI.
-- CHARTS: Card visuals only. Not for bar/line charts.
-- =============================================================

CREATE OR REPLACE VIEW v_kpi_summary AS
WITH sales_base AS (
    SELECT
        SUM(net_sales_amount)           AS total_revenue,
        SUM(gross_profit)               AS total_gross_profit,
        SUM(net_sales_quantity)         AS total_units_sold,
        SUM(refund_quantity)            AS total_refunds,
        COUNT(DISTINCT product_no)      AS total_products_sold,
        COUNT(DISTINCT sale_date)       AS total_selling_days,
        COUNT(DISTINCT warehouse)       AS total_warehouses,
        AVG(gross_margin_pct)           AS avg_gross_margin_pct,
        MAX(sale_date)                  AS last_sale_date,
        MIN(sale_date)                  AS first_sale_date
    FROM stg_sales
),
stock_base AS (
    SELECT
        SUM(closing_qty)    AS total_stock_qty,
        SUM(closing_cost)   AS total_stock_value,
        COUNT(DISTINCT product_no) AS total_products_in_stock
    FROM (
        SELECT product_no, warehouse, closing_qty, closing_cost,
        ROW_NUMBER() OVER (
            PARTITION BY product_no, warehouse
            ORDER BY movement_date DESC, id DESC
        ) AS rn
        FROM stg_stocks
    ) t WHERE rn = 1 AND closing_qty > 0
),
low_stock_base AS (
    SELECT COUNT(DISTINCT product_no) AS products_critical
    FROM v_low_stock_alert
    WHERE stock_alert IN ('Critical', 'Out of stock')
),
slow_stock_base AS (
    SELECT
        COUNT(DISTINCT product_no)      AS dead_stock_products,
        SUM(capital_at_risk)            AS dead_stock_capital
    FROM v_slow_movers
    WHERE slow_mover_flag IN ('Dead stock', 'Never sold', 'No sales in 60 days')
)
SELECT
    -- Revenue KPIs
    ROUND(s.total_revenue, 2)                                       AS total_revenue,
    ROUND(s.total_gross_profit, 2)                                  AS total_gross_profit,
    ROUND(s.avg_gross_margin_pct, 2)                                AS avg_gross_margin_pct,
    s.total_units_sold,
    s.total_refunds,
    ROUND((s.total_refunds / NULLIF(s.total_units_sold, 0)) * 100, 2) AS refund_rate_pct,

    -- Stock KPIs
    st.total_stock_qty,
    ROUND(st.total_stock_value, 2)                                  AS total_stock_value,
    st.total_products_in_stock,

    -- Alert KPIs
    ls.products_critical                                            AS critical_stock_products,
    ss.dead_stock_products,
    ROUND(ss.dead_stock_capital, 2)                                 AS dead_stock_capital,

    -- Coverage
    s.total_products_sold,
    s.total_selling_days,
    s.total_warehouses,
    s.last_sale_date,
    s.first_sale_date,

    -- Revenue per day
    ROUND(s.total_revenue / NULLIF(s.total_selling_days, 0), 2)    AS avg_daily_revenue,

    -- Profit per unit
    ROUND(s.total_gross_profit / NULLIF(s.total_units_sold, 0), 2) AS avg_profit_per_unit

FROM sales_base s
CROSS JOIN stock_base     st
CROSS JOIN low_stock_base ls
CROSS JOIN slow_stock_base ss;