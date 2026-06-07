-- ============================================================
-- PROJECT 1: Incident SLA Breach Analysis
-- Script 01: Create Table & Initial Load
-- Tool: SQLite (run via DBeaver or sqlite3 CLI)
-- Author: Thrusha Sahu | ServiceNow ITSM Portfolio
-- ============================================================

-- Drop if re-running
DROP TABLE IF EXISTS incidents_raw;
DROP TABLE IF EXISTS incidents_clean;

-- Raw staging table (everything as TEXT to accept messy data)
CREATE TABLE incidents_raw (
    sys_id              TEXT,
    number              TEXT,
    opened_at           TEXT,
    resolved_at         TEXT,
    priority            TEXT,
    state               TEXT,
    category            TEXT,
    subcategory         TEXT,
    assigned_to         TEXT,
    assignment_group    TEXT,
    opened_by           TEXT,
    location            TEXT,
    impact              TEXT,
    urgency             TEXT,
    resolution_time_hrs TEXT,
    sla_breached        TEXT,
    short_description   TEXT,
    reopen_count        TEXT,
    close_notes         TEXT
);

-- NOTE: In SQLite CLI, load with:
--   .mode csv
--   .import incident_raw.csv incidents_raw
--   (skip header row: run `.import` after removing header OR use --skip 1 flag)
--
-- In DBeaver: right-click table → Import Data → CSV → map columns → run

-- Quick row count check after import
SELECT COUNT(*) AS total_rows_loaded FROM incidents_raw;
