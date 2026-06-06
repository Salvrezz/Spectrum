-- =============================================================
-- v_sales_performance.sql
-- Revenue, margin, and sell-through KPIs by product / brand /
-- category / channel / store — ready for Power BI slicing.
-- =============================================================

CREATE OR REPLACE VIEW v_sales_performance AS
WITH monthly_totals AS (
    SELECT
        DATE_FORMAT(sale_date, '%Y-%m')     AS mth,
        product_no,
        SUM(net_sales_amount)               AS monthly_revenue,
        SUM(gross_profit)                   AS monthly_profit,
        SUM(net_sales_quantity)             AS monthly_qty
    FROM stg_sales
    GROUP BY DATE_FORMAT(sale_date, '%Y-%m'), product_no
)
SELECT
    s.sale_date,
    YEAR(s.sale_date)                                               AS sale_year,
    MONTH(s.sale_date)                                              AS sale_month,
    DATE_FORMAT(s.sale_date, '%Y-%m')                               AS yr_month,
    s.product_no,
    s.product_name,
    s.category,
    s.brand,
    s.warehouse,
    s.store,
    s.sales_channel,
    s.net_sales_quantity,
    s.net_sales_amount,
    s.net_sales_cost,
    s.gross_profit,
    s.gross_margin_pct,
    s.refund_quantity,
    s.refund_order_count,
    (s.net_sales_quantity - s.refund_quantity)                      AS net_qty_after_refunds,
    CASE
        WHEN s.net_sales_quantity > 0
        THEN ROUND(s.net_sales_amount / s.net_sales_quantity, 2)
        ELSE NULL
    END                                                             AS avg_unit_price,
    CASE
        WHEN s.net_sales_quantity > 0
        THEN ROUND(s.net_sales_cost / s.net_sales_quantity, 2)
        ELSE NULL
    END                                                             AS avg_unit_cost,
    mt.monthly_revenue,
    mt.monthly_profit,
    mt.monthly_qty,
    CASE
        WHEN p.purchase_price > 0 AND p.retail_price > 0
        THEN ROUND(((p.retail_price - p.purchase_price) / p.retail_price) * 100, 2)
        ELSE NULL
    END                                                             AS product_gross_margin_pct,
    p.purchase_price,
    p.retail_price,
    p.unit_of_measure
FROM stg_sales s
LEFT JOIN stg_products  p  ON p.product_no = s.product_no
LEFT JOIN monthly_totals mt ON mt.product_no = s.product_no
                            AND mt.mth = DATE_FORMAT(s.sale_date, '%Y-%m');