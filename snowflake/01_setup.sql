-- 01_setup.sql
-- Create database, warehouse and required schemas for the CSM prototype.
-- This script is idempotent (uses IF NOT EXISTS) and safe to re-run.

-- 1) Create warehouse for ETL and ad-hoc work
CREATE WAREHOUSE IF NOT EXISTS CSM_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- Use the warehouse so subsequent operations run with it
USE WAREHOUSE CSM_WH;

-- 2) Create the database for the security master project
CREATE DATABASE IF NOT EXISTS CREDIT_SECURITY_MASTER;

-- Use the database for the following schema creation
USE DATABASE CREDIT_SECURITY_MASTER;

-- 3) Create four schemas representing the logical layers
-- RAW: holds untouched source VARIANT payloads and file metadata
CREATE SCHEMA IF NOT EXISTS RAW;

-- STAGING: parsed, typed and standardized fields from sources
CREATE SCHEMA IF NOT EXISTS STAGING;

-- CORE: canonical, trusted security-master tables and normalized entities
CREATE SCHEMA IF NOT EXISTS CORE;

-- CONTROL: data-quality results, exception reports and reconciliation outputs
CREATE SCHEMA IF NOT EXISTS CONTROL;

-- Final confirmation context
-- Set the current context to the database and warehouse explicitly
USE WAREHOUSE CSM_WH;
USE DATABASE CREDIT_SECURITY_MASTER;

-- End of setup
