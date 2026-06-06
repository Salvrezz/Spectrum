-- =============================================================
-- v_product_master.sql
-- Clean product dimension — one row per product.
-- Used by Power BI as the product lookup/slicer table.
-- =============================================================

CREATE OR REPLACE VIEW v_product_master AS
SELECT
    product_no,
    sku_no,
    product_name,
    category,
    brand,
    unit_of_measure,
    has_serial_no,
    purchase_tax_rate,
    sale_tax_rate,
    purchase_price,
    wholesale_price,
    retail_price,
    CASE
        WHEN purchase_price > 0 AND retail_price > 0
        THEN ROUND(((retail_price - purchase_price) / retail_price) * 100, 2)
        ELSE NULL
    END AS gross_margin_pct,
    CASE
        WHEN purchase_price > 0 AND wholesale_price > 0
        THEN ROUND(((wholesale_price - purchase_price) / wholesale_price) * 100, 2)
        ELSE NULL
    END AS wholesale_margin_pct
FROM stg_products;