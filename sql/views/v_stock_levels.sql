-- =============================================================
-- v_stock_levels.sql
-- Latest closing stock quantity per product per warehouse.
-- "Latest" = the most recent movement_date row for that product+warehouse.
-- Power BI uses this for current inventory cards and warehouse maps.
-- =============================================================

CREATE OR REPLACE VIEW v_stock_levels AS
WITH latest_movement AS (
    SELECT
        product_no, product_name, category, brand, warehouse,
        movement_date AS last_movement_date,
        closing_qty, closing_cost,
        ROW_NUMBER() OVER (
            PARTITION BY product_no, warehouse
            ORDER BY movement_date DESC, id DESC
        ) AS rn
    FROM stg_stocks
)
SELECT
    lm.product_no,
    lm.product_name,
    lm.category,
    lm.brand,
    lm.warehouse,
    lm.last_movement_date,
    lm.closing_qty                                              AS current_stock_qty,
    lm.closing_cost                                             AS current_stock_value,
    p.purchase_price,
    p.retail_price,
    ROUND(lm.closing_qty * COALESCE(p.purchase_price, 0), 2)   AS capital_at_risk,
    CASE
        WHEN p.retail_price IS NOT NULL AND p.retail_price > 0
        THEN ROUND(lm.closing_qty * p.retail_price, 2)
        ELSE NULL
    END                                                         AS estimated_retail_value,
    CASE
        WHEN p.purchase_price > 0 AND p.retail_price > 0
        THEN ROUND(((p.retail_price - p.purchase_price) / p.retail_price) * 100, 2)
        ELSE NULL
    END                                                         AS gross_margin_pct
FROM latest_movement lm
LEFT JOIN stg_products p ON p.product_no = lm.product_no
WHERE lm.rn = 1
AND lm.closing_qty > 0;