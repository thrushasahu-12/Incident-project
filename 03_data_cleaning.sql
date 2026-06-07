-- ============================================================
-- PROJECT 1: Incident SLA Breach Analysis
-- Script 03: Data Cleaning → incidents_clean
-- Techniques: CASE normalization, NULLIF, dedup with ROW_NUMBER,
--             date standardization, derived SLA columns
-- ============================================================

-- ── STEP 1: Create cleaned table from raw ───────────────────
CREATE TABLE incidents_clean AS
WITH

-- A. Deduplicate: keep first occurrence of each sys_id
deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY sys_id ORDER BY rowid) AS rn
    FROM incidents_raw
    WHERE TRIM(COALESCE(sys_id,'')) != ''   -- remove rows with no sys_id
),

-- B. Normalize all messy text fields
normalized AS (
    SELECT
        sys_id,
        number,

        -- Standardize opened_at to YYYY-MM-DD HH:MM:SS
        CASE
            WHEN opened_at LIKE '____-__-__ __:__:__' THEN opened_at
            WHEN opened_at LIKE '__/__/____ __:__'
                 -- DD/MM/YYYY HH:MM → reformat
                 THEN SUBSTR(opened_at,7,4)||'-'||SUBSTR(opened_at,4,2)||'-'||SUBSTR(opened_at,1,2)
                      ||' '||SUBSTR(opened_at,12,5)||':00'
            WHEN opened_at LIKE '____/__/__'
                 THEN REPLACE(opened_at,'/','-')||' 00:00:00'
            ELSE NULL
        END AS opened_at,

        -- Clean resolved_at: nullify placeholder strings
        CASE
            WHEN TRIM(COALESCE(resolved_at,'')) IN ('','NULL','N/A','NA','null','n/a')
                 THEN NULL
            WHEN resolved_at LIKE '__-__-____ __:__'
                 THEN SUBSTR(resolved_at,7,4)||'-'||SUBSTR(resolved_at,4,2)||'-'||SUBSTR(resolved_at,1,2)
                      ||' '||SUBSTR(resolved_at,12,5)||':00'
            ELSE resolved_at
        END AS resolved_at,

        -- Normalize priority to canonical labels
        CASE UPPER(TRIM(COALESCE(priority,'')))
            WHEN '1 - CRITICAL' THEN '1 - Critical'
            WHEN 'CRITICAL'     THEN '1 - Critical'
            WHEN 'P1'           THEN '1 - Critical'
            WHEN '2 - HIGH'     THEN '2 - High'
            WHEN 'HIGH'         THEN '2 - High'
            WHEN 'P2'           THEN '2 - High'
            WHEN '3 - MODERATE' THEN '3 - Moderate'
            WHEN 'P3'           THEN '3 - Moderate'
            WHEN '4 - LOW'      THEN '4 - Low'
            WHEN 'LOW'          THEN '4 - Low'
            ELSE 'Unknown'
        END AS priority,

        -- Normalize state
        CASE LOWER(TRIM(COALESCE(state,'')))
            WHEN 'resolved'     THEN 'Resolved'
            WHEN 'closed'       THEN 'Closed'
            WHEN 'in progress'  THEN 'In Progress'
            WHEN 'new'          THEN 'New'
            WHEN 'on hold'      THEN 'On Hold'
            ELSE 'Unknown'
        END AS state,

        -- Normalize category
        CASE LOWER(TRIM(COALESCE(category,'')))
            WHEN 'network'      THEN 'Network'
            WHEN 'software'     THEN 'Software'
            WHEN 'hardware'     THEN 'Hardware'
            WHEN 'access'       THEN 'Access'
            WHEN 'database'     THEN 'Database'
            WHEN 'security'     THEN 'Security'
            ELSE 'Unknown'
        END AS category,

        -- Normalize assignment_group
        CASE LOWER(TRIM(COALESCE(assignment_group,'')))
            WHEN 'infrastructure'       THEN 'Infrastructure'
            WHEN 'infra'                THEN 'Infrastructure'
            WHEN 'application support'  THEN 'Application Support'
            WHEN 'app support'          THEN 'Application Support'
            WHEN 'service desk'         THEN 'Service Desk'
            WHEN 'servicedesk'          THEN 'Service Desk'
            WHEN 'database admin'       THEN 'Database Admin'
            WHEN 'security ops'         THEN 'Security Ops'
            ELSE 'Unknown'
        END AS assignment_group,

        NULLIF(TRIM(assigned_to),'')    AS assigned_to,
        NULLIF(TRIM(location),'')       AS location,
        NULLIF(TRIM(short_description),'') AS short_description,

        -- Clean numeric fields
        CASE WHEN TRIM(COALESCE(resolution_time_hrs,'')) = '' THEN NULL
             ELSE CAST(resolution_time_hrs AS REAL)
        END AS resolution_time_hrs,

        -- Normalize sla_breached flag
        CASE UPPER(TRIM(COALESCE(sla_breached,'')))
            WHEN 'YES' THEN 'Yes'
            WHEN 'NO'  THEN 'No'
            ELSE NULL
        END AS sla_breached,

        CASE WHEN TRIM(COALESCE(reopen_count,'')) = '' THEN 0
             ELSE CAST(reopen_count AS INTEGER)
        END AS reopen_count

    FROM deduped
    WHERE rn = 1   -- remove duplicates here
),

-- C. Derive SLA target hours from normalized priority
with_sla AS (
    SELECT *,
           CASE priority
               WHEN '1 - Critical' THEN 4
               WHEN '2 - High'     THEN 8
               WHEN '3 - Moderate' THEN 24
               WHEN '4 - Low'      THEN 72
               ELSE 24
           END AS sla_target_hrs
    FROM normalized
),

-- D. Recalculate resolution time and breach flag from clean dates
-- This catches tickets where sla_breached was missing/wrong in source
final AS (
    SELECT *,
           CASE
               WHEN opened_at IS NOT NULL AND resolved_at IS NOT NULL
               THEN ROUND(
                       (JULIANDAY(resolved_at) - JULIANDAY(opened_at)) * 24,
                       2)
               ELSE resolution_time_hrs   -- fall back to source value if dates missing
           END AS calc_resolution_hrs,

           CASE
               WHEN opened_at IS NOT NULL AND resolved_at IS NOT NULL
               THEN CASE
                       WHEN ((JULIANDAY(resolved_at) - JULIANDAY(opened_at)) * 24) > sla_target_hrs
                       THEN 'Yes'
                       ELSE 'No'
                    END
               ELSE sla_breached   -- preserve original if we can't recalculate
           END AS sla_breached_recalc
    FROM with_sla
)

SELECT * FROM final;

-- ── Verify clean table ───────────────────────────────────────
SELECT
    COUNT(*)                                            AS total_clean_rows,
    COUNT(CASE WHEN priority = 'Unknown' THEN 1 END)   AS unknown_priority,
    COUNT(CASE WHEN state    = 'Unknown' THEN 1 END)   AS unknown_state,
    COUNT(CASE WHEN category = 'Unknown' THEN 1 END)   AS unknown_category,
    COUNT(CASE WHEN resolved_at IS NULL
               AND state IN ('Resolved','Closed') THEN 1 END) AS resolved_missing_date
FROM incidents_clean;
