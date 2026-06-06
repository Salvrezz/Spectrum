-- =============================================================
-- v_days_in_stock.sql
-- How long each product has been sitting in stock.
-- "First inbound date" to today = days on shelf.
-- Flags items sitting too long with an age_bucket label.
-- =============================================================

CREATE OR REPLACE VIEW v_days_in_stock AS
WITH first_inbound AS (
    SELECT
        product_no, product_name, category, brand, warehouse,
        MIN(movement_date) AS first_inbound_date,
        MAX(movement_date) AS last_movement_date,
        SUM(inbound_qty)   AS total_received,
        SUM(outbound_qty)  AS total_dispatched
    FROM stg_stocks
    WHERE inbound_qty > 0
    GROUP BY product_no, product_name, category, brand, warehouse
),
current_stock AS (
    SELECT product_no, warehouse, closing_qty, closing_cost
    FROM (
        SELECT product_no, warehouse, closing_qty, closing_cost,
        ROW_NUMBER() OVER (
            PARTITION BY product_no, warehouse
            ORDER BY movement_date DESC, id DESC
        ) AS rn
        FROM stg_stocks
    ) ranked
    WHERE rn = 1
),
rolling_sales AS (
    SELECT product_no, warehouse,
        SUM(net_sales_quantity)           AS qty_sold_30d,
        COUNT(DISTINCT sale_date)         AS selling_days_30d,
        ROUND(
            SUM(net_sales_quantity) /
            NULLIF(COUNT(DISTINCT sale_date), 0), 2
        )                                 AS avg_daily_qty
    FROM stg_sales
    WHERE sale_date >= DATE_SUB((SELECT MAX(sale_date) FROM stg_sales), INTERVAL 30 DAY)
    GROUP BY product_no, warehouse
)
SELECT
    fi.product_no,
    fi.product_name,
    fi.category,
    fi.brand,
    fi.warehouse,
    fi.first_inbound_date,
    fi.last_movement_date,
    DATEDIFF(CURDATE(), fi.first_inbound_date)                  AS days_in_stock,
    cs.closing_qty                                              AS current_qty,
    cs.closing_cost                                             AS current_cost,
    ROUND(cs.closing_qty * COALESCE(p.purchase_price, 0), 2)   AS capital_at_risk,
    COALESCE(rs.avg_daily_qty, 0)                               AS rolling_30d_daily_velocity,
    COALESCE(rs.qty_sold_30d, 0)                                AS qty_sold_last_30d,
    CASE
        WHEN rs.avg_daily_qty > 0
        THEN ROUND(cs.closing_qty / rs.avg_daily_qty, 0)
        ELSE NULL
    END                                                         AS days_of_stock_remaining,
    CASE
        WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) <= 30  THEN '0-30 days'
        WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) <= 60  THEN '31-60 days'
        WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) <= 90  THEN '61-90 days'
        WHEN DATEDIFF(CURDATE(), fi.first_inbound_date) <= 180 THEN '91-180 days'
        ELSE 'Over 180 days'
    END                                                         AS age_bucket,
    CASE
        WHEN cs.closing_qty > 0
         AND DATEDIFF(CURDATE(), fi.first_inbound_date) > 90   THEN 'Slow / Stuck'
        WHEN cs.closing_qty > 0
         AND DATEDIFF(CURDATE(), fi.first_inbound_date) <= 90  THEN 'Active'
        WHEN cs.closing_qty <= 0                               THEN 'Cleared'
        ELSE 'Unknown'
    END                                                         AS stock_status,
    CASE
        WHEN rs.avg_daily_qty > 0
         AND (cs.closing_qty / rs.avg_daily_qty) <= 7          THEN 'Critical'
        WHEN rs.avg_daily_qty > 0
         AND (cs.closing_qty / rs.avg_daily_qty) <= 14         THEN 'Warning'
        WHEN rs.avg_daily_qty > 0
         AND (cs.closing_qty / rs.avg_daily_qty) <= 30         THEN 'Low'
        WHEN cs.closing_qty <= 0                               THEN 'Out of stock'
        ELSE 'OK'
    END                                                         AS reorder_flag
FROM first_inbound fi
LEFT JOIN current_stock cs ON cs.product_no = fi.product_no AND cs.warehouse = fi.warehouse
LEFT JOIN rolling_sales rs  ON rs.product_no = fi.product_no AND rs.warehouse = fi.warehouse
LEFT JOIN stg_products  p   ON p.product_no  = fi.product_no;