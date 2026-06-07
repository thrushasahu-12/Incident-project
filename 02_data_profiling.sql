-- ============================================================
-- PROJECT 1: Incident SLA Breach Analysis
-- Script 02: Data Profiling & Audit (Run BEFORE cleaning)
-- Purpose: Understand exactly what's messy before touching data
-- ============================================================

-- ── 1. Row count overview ────────────────────────────────────
SELECT COUNT(*)                             AS total_rows,
       COUNT(DISTINCT sys_id)               AS unique_sys_ids,
       COUNT(*) - COUNT(DISTINCT sys_id)    AS duplicate_sys_ids
FROM incidents_raw;

-- ── 2. Null / blank audit per key column ─────────────────────
SELECT
    SUM(CASE WHEN TRIM(COALESCE(sys_id,''))         = '' THEN 1 ELSE 0 END) AS null_sys_id,
    SUM(CASE WHEN TRIM(COALESCE(priority,''))        = '' THEN 1 ELSE 0 END) AS null_priority,
    SUM(CASE WHEN TRIM(COALESCE(state,''))           = '' THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN TRIM(COALESCE(category,''))        = '' THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN TRIM(COALESCE(resolved_at,''))     = '' THEN 1 ELSE 0 END) AS null_resolved_at,
    SUM(CASE WHEN TRIM(COALESCE(sla_breached,''))    = '' THEN 1 ELSE 0 END) AS null_sla_breached,
    SUM(CASE WHEN TRIM(COALESCE(assignment_group,''))= '' THEN 1 ELSE 0 END) AS null_assignment_group,
    SUM(CASE WHEN TRIM(COALESCE(resolution_time_hrs,''))='' THEN 1 ELSE 0 END) AS null_resolution_hrs
FROM incidents_raw;

-- ── 3. Priority value variance (the mess) ────────────────────
SELECT priority,
       COUNT(*) AS count
FROM incidents_raw
GROUP BY priority
ORDER BY count DESC;

-- ── 4. State value variance ───────────────────────────────────
SELECT state,
       COUNT(*) AS count
FROM incidents_raw
GROUP BY state
ORDER BY count DESC;

-- ── 5. Category value variance ────────────────────────────────
SELECT category,
       COUNT(*) AS count
FROM incidents_raw
GROUP BY category
ORDER BY count DESC;

-- ── 6. Resolved tickets with missing resolved_at ─────────────
-- This is the KEY data quality issue the ops team missed
SELECT COUNT(*) AS resolved_missing_date
FROM incidents_raw
WHERE LOWER(TRIM(state)) IN ('resolved','closed')
  AND (TRIM(COALESCE(resolved_at,'')) = ''
       OR LOWER(TRIM(resolved_at)) IN ('null','n/a','na'));

-- ── 7. Date format variance ───────────────────────────────────
SELECT
    CASE
        WHEN opened_at LIKE '____-__-__ __:__:__' THEN 'YYYY-MM-DD HH:MM:SS'
        WHEN opened_at LIKE '__/__/____ __:__'     THEN 'DD/MM/YYYY HH:MM'
        WHEN opened_at LIKE '____/__ /__'          THEN 'YYYY/MM/DD'
        ELSE 'OTHER / UNKNOWN'
    END AS date_format,
    COUNT(*) AS count
FROM incidents_raw
GROUP BY 1
ORDER BY count DESC;

-- ── 8. SLA breached flag distribution ────────────────────────
SELECT sla_breached,
       COUNT(*) AS count
FROM incidents_raw
GROUP BY sla_breached
ORDER BY count DESC;
