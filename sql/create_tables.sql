-- =============================================================
-- create_tables.sql
-- Run this ONCE in MySQL Workbench (or via main.py --setup)
-- to create the spectrum_db schema and three staging tables.
-- =============================================================

-- 1. Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS spectrum_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE spectrum_db;


-- =============================================================
-- 2. STAGING: Products
-- =============================================================
DROP TABLE IF EXISTS stg_products;

CREATE TABLE stg_products (
    id                  INT             AUTO_INCREMENT PRIMARY KEY,
    product_no          VARCHAR(50)     NOT NULL,
    sku_no              VARCHAR(50),
    product_name        VARCHAR(255)    NOT NULL,
    category            VARCHAR(100),
    brand               VARCHAR(150),
    has_specifications  CHAR(1)         COMMENT 'Y or N',
    has_serial_no       CHAR(1)         COMMENT 'Y or N',
    unit_of_measure     VARCHAR(20),
    purchase_tax_rate   DECIMAL(6,2),
    sale_tax_rate       DECIMAL(6,2),
    purchase_price      DECIMAL(30,2),
    wholesale_price     DECIMAL(30,2),
    retail_price        DECIMAL(30,2),
    loaded_at           TIMESTAMP       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_product_no (product_no),
    INDEX idx_category   (category),
    INDEX idx_brand      (brand)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =============================================================
-- 3. STAGING: Sales
-- =============================================================
DROP TABLE IF EXISTS stg_sales;

CREATE TABLE stg_sales (
    id                  BIGINT          AUTO_INCREMENT PRIMARY KEY,
    sale_date           DATE            NOT NULL,
    product_no          VARCHAR(50)     NOT NULL,
    product_name        VARCHAR(255),
    category            VARCHAR(100),
    brand               VARCHAR(150),
    warehouse           VARCHAR(150),
    store               VARCHAR(150),
    sales_channel       VARCHAR(50)     COMMENT 'Retail or Wholesale',
    refund_quantity     INT             DEFAULT 0,
    refund_order_count  INT             DEFAULT 0,
    net_sales_amount    DECIMAL(30,2),
    net_sales_quantity  INT,
    net_sales_cost      DECIMAL(30,2),
    gross_profit        DECIMAL(30,2),
    gross_margin_pct    DECIMAL(30,2)    COMMENT 'Percentage, e.g. 37.15',
    loaded_at           TIMESTAMP       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_sale_date   (sale_date),
    INDEX idx_product_no  (product_no),
    INDEX idx_warehouse   (warehouse),
    INDEX idx_channel     (sales_channel)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =============================================================
-- 4. STAGING: Stocks (inventory ledger)
-- =============================================================
DROP TABLE IF EXISTS stg_stocks;

CREATE TABLE stg_stocks (
    id              BIGINT          AUTO_INCREMENT PRIMARY KEY,
    product_no      VARCHAR(50)     NOT NULL,
    product_name    VARCHAR(255),
    category        VARCHAR(100),
    brand           VARCHAR(150),
    movement_type   VARCHAR(50)     COMMENT 'Opening Stock | Stock In | Store Transfer Out | Transfer | Delivery Out | Sales Return | Stock Out | Purchase Return | Other',
    document_no     VARCHAR(100),
    movement_date   DATE            NOT NULL,
    warehouse       VARCHAR(150),
    inbound_qty     INT             DEFAULT 0,
    inbound_cost    DECIMAL(30,2)   DEFAULT 0.00,
    outbound_qty    INT             DEFAULT 0,
    outbound_cost   DECIMAL(30,2)   DEFAULT 0.00,
    closing_qty     INT,
    closing_cost    DECIMAL(30,2),
    loaded_at       TIMESTAMP       DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_product_no    (product_no),
    INDEX idx_movement_date (movement_date),
    INDEX idx_warehouse     (warehouse),
    INDEX idx_movement_type (movement_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
