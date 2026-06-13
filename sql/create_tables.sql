-- sql/create_tables.sql
--
-- This file is for DOCUMENTATION / first-time setup only.
-- etl/load.py uses pandas to_sql(if_exists="replace"), which will create
-- (and recreate) these tables automatically on every run. You do NOT need
-- to run this file for the pipeline to work — it's here so you (and Power
-- BI users) can see the shape of each table at a glance, and so you can
-- run it once manually if you prefer to pre-create the schema with your
-- own data types/indexes.
 
CREATE DATABASE IF NOT EXISTS spectrum_db;
USE spectrum_db;
 
-- 1) Product master (from PRODUCT.xlsx)
-- Grain: 1 row per Product No.
-- Key columns for Power BI: Product No., Product Name, Tier 1 Category, Brand
CREATE TABLE IF NOT EXISTS stg_product (
    `Product Name`            VARCHAR(255),
    `Product No.`             VARCHAR(50),
    `Product Type`            VARCHAR(100),
    `Tier 1 Category`         VARCHAR(100),
    `Brand`                   VARCHAR(150),
    `Wholesale Price`         DECIMAL(15,2),
    `Retail Price`            DECIMAL(15,2),
    `Online Price`            DECIMAL(15,2),
    PRIMARY KEY (`Product No.`)
);
 
-- 2) Sales transactions (from SALES.xlsx)
-- Grain: 1 row per sales line item
-- Key columns: Date, Product NO., Tier 1 Category, Brand, Sales Channels,
--              Net Sales Amount, Net Sales Quantity, Net Sales Gross Profit
CREATE TABLE IF NOT EXISTS stg_sales (
    `Date`                    DATE NULL,
    `Product`                 VARCHAR(255),
    `Product NO.`             VARCHAR(50),
    `Product Type`            VARCHAR(100),
    `Tier 1 Category`         VARCHAR(100),
    `Brand`                   VARCHAR(150),
    `Warehouse`               VARCHAR(150),
    `Store`                   VARCHAR(150),
    `Sales Channels`          VARCHAR(50),
    `Refund Quantity`         DECIMAL(15,2),
    `Refund Order Count`      INT,
    `Net Sales Amount`        DECIMAL(15,2),
    `Net Sales Quantity`      DECIMAL(15,2),
    `Net Sales Cost`          DECIMAL(15,2),
    `Net Sales Unit Price`    DECIMAL(15,2),
    `Net Sales Unit Cost`     DECIMAL(15,2),
    `Net Sales Gross Profit`  DECIMAL(15,2),
    `Net Sales Gross Margin`  VARCHAR(20),
    INDEX idx_sales_date (`Date`),
    INDEX idx_sales_product (`Product NO.`),
    INDEX idx_sales_brand (`Brand`)
);
 
-- 3) Stock balance, unpivoted (from STOCK_BALANCE.xlsx)
-- Grain: 1 row per Product No. + Warehouse
CREATE TABLE IF NOT EXISTS stg_stock_balance (
    `Product No.`             VARCHAR(50),
    `Product Name`            VARCHAR(255),
    `SKU No.`                 VARCHAR(100),
    `Tier 1 Category`         VARCHAR(100),
    `Brand`                   VARCHAR(150),
    `Unit of Measurement`     VARCHAR(50),
    `Warehouse`               VARCHAR(150),
    `Stock on Hand`           DECIMAL(15,2),
    `Unit Cost`               DECIMAL(15,2),
    `Inventory Asset Value`   DECIMAL(18,2),
    INDEX idx_sb_product (`Product No.`),
    INDEX idx_sb_warehouse (`Warehouse`),
    INDEX idx_sb_brand (`Brand`)
);
 
-- 4) Stock movement log (from STOCK_BALANCE_DETAILS.xlsx)
-- Grain: 1 row per movement transaction
CREATE TABLE IF NOT EXISTS stg_stock_movement (
    `Product No.`             VARCHAR(50),
    `Product Name`            VARCHAR(255),
    `SKU No.`                 VARCHAR(100),
    `Tier 1 Category`         VARCHAR(100),
    `Brand`                   VARCHAR(150),
    `Unit of Measure`         VARCHAR(50),
    `Type`                    VARCHAR(50),
    `Document No.`            VARCHAR(100),
    `Date`                    DATE NULL,
    `Warehouse`               VARCHAR(150),
    `Inbound-Quantity`        DECIMAL(15,2),
    `Outbound-Quantity`       DECIMAL(15,2),
    `Closing-Quantity`        DECIMAL(15,2),
    `Closing-Cost`            DECIMAL(18,2),
    INDEX idx_sm_product_wh (`Product No.`, `Warehouse`),
    INDEX idx_sm_date (`Date`)
);
 
-- 5) Derived stock ageing (built by transform.build_stock_aging)
-- Grain: 1 row per Product No. + Warehouse (same as stg_stock_balance)
CREATE TABLE IF NOT EXISTS stg_stock_aging (
    `Product No.`             VARCHAR(50),
    `Product Name`            VARCHAR(255),
    `Tier 1 Category`         VARCHAR(100),
    `Brand`                   VARCHAR(150),
    `Warehouse`               VARCHAR(150),
    `Stock on Hand`           DECIMAL(15,2),
    `Inventory Asset Value`   DECIMAL(18,2),
    `Last Movement Date`      DATE NULL,
    `Inventory Age Days`      INT NULL,
    `Aging Bucket`            VARCHAR(30),
    `Is Aged 45 Plus`         TINYINT(1),
    INDEX idx_age_brand (`Brand`),
    INDEX idx_age_bucket (`Aging Bucket`)
);