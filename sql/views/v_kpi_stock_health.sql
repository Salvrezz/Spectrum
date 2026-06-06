-- =============================================================
-- v_kpi_stock_health.sql
-- Aggregated stock health by category and age bucket.
-- Shows where capital is tied up and what needs action.
--
-- WHEN TO USE:
--   Procurement meetings, stock review sessions, buying decisions.
--   Answers: what do we have, how old is it, what is it worth.
--
-- CHARTS TO BUILD:
--   1. Stacked bar chart — category (X) vs capital_at_risk (Y)
--      Stack: age_bucket (0-30, 31-60, 61-90, 91-180, Over 180)
--      Shows:  how much money is stuck per category per age group
--
--   2. Donut chart — age_bucket (Legend) vs total_stock_qty (Values)
--      Shows:  overall age distribution of all stock
--
--   3. Bar chart — category (X) vs dead_stock_qty (Y)
--      Color: red
--      Shows:  which categories have the most dead stock to clear
--
--   4. KPI card — total_capital_at_risk (single number)
--      Shows:  total money tied up in slow/dead stock
--
--   5. Table visual — all columns, filtered to age_bucket = Over 180
--      Shows:  product-level list for procurement to act on
-- =============================================================

CREATE OR REPLACE VIEW v_kpi_stock_health AS
WITH stock_aged AS (
    SELECT
        fi.product_no,
        fi.product_name,
        fi.category,
        fi.brand,
        fi.warehouse,
        cs.closing_qty                                              AS current_qty,
        cs.closing_cost                                             AS current_cost,
        ROUND(cs.closing_qty * COALESCE(p.purchase_price, 0), 2)   AS capital_at_risk,
        DATEDIFF(CURDATE(), fi.first_inbound_date)                  AS days_in_stock,
        CASE
            WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) <= 30  THEN '0-30 days'
            WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) <= 60  THEN '31-60 days'
            WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) <= 90  THEN '61-90 days'
            WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) <= 180 THEN '91-180 days'
            ELSE 'Over 180 days'
        END                                                         AS age_bucket,
        CASE
            WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) > 180  THEN 1 ELSE 0
        END                                                         AS is_dead_stock
    FROM (
        SELECT product_no, product_name, category, brand, warehouse,
            MIN(movement_date) AS first_inbound_date
        FROM stg_stocks WHERE inbound_qty > 0
        GROUP BY product_no, product_name, category, brand, warehouse
    ) fi
    JOIN (
        SELECT product_no, warehouse, closing_qty, closing_cost
        FROM (
            SELECT product_no, warehouse, closing_qty, closing_cost,
            ROW_NUMBER() OVER (
                PARTITION BY product_no, warehouse
                ORDER BY movement_date DESC, id DESC
            ) AS rn FROM stg_stocks
        ) r WHERE rn = 1
    ) cs ON cs.product_no = fi.product_no AND cs.warehouse = fi.warehouse
    LEFT JOIN stg_products p ON p.product_no = fi.product_no
    WHERE cs.closing_qty > 0
)
SELECT
    category,
    brand,
    warehouse,
    age_bucket,
    COUNT(DISTINCT product_no)          AS unique_products,
    SUM(current_qty)                    AS total_stock_qty,
    ROUND(SUM(current_cost), 2)         AS total_stock_cost,
    ROUND(SUM(capital_at_risk), 2)      AS total_capital_at_risk,
    SUM(is_dead_stock)                  AS dead_stock_sku_count,
    ROUND(AVG(days_in_stock), 0)        AS avg_days_in_stock,
    MAX(days_in_stock)                  AS max_days_in_stock
FROM stock_aged
GROUP BY category, brand, warehouse, age_bucket
ORDER BY total_capital_at_risk DESC;