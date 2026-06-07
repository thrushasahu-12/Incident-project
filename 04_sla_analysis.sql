-- ============================================================
-- PROJECT 1: Incident SLA Breach Analysis
-- Script 04: Analysis Queries (Run AFTER 03_data_cleaning.sql)
-- Techniques: CTEs, Window Functions, GROUP BY, HAVING, RANK()
-- All queries use incidents_clean table
-- ============================================================

-- ══════════════════════════════════════════════════════════════
-- QUERY 1: Overall SLA Breach Rate by Priority
-- Business question: Which priority level breaches SLA most?
-- ══════════════════════════════════════════════════════════════

WITH breach_summary AS (
    SELECT
        priority,
        sla_target_hrs,
        COUNT(*)                                                AS total_incidents,
        COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END) AS breached,
        COUNT(CASE WHEN sla_breached_recalc = 'No'  THEN 1 END) AS met
    FROM incidents_clean
    WHERE state IN ('Resolved','Closed')
      AND priority != 'Unknown'
    GROUP BY priority, sla_target_hrs
)
SELECT
    priority,
    sla_target_hrs          AS sla_limit_hrs,
    total_incidents,
    breached,
    met,
    ROUND(100.0 * breached / NULLIF(total_incidents,0), 1) AS breach_rate_pct
FROM breach_summary
ORDER BY breach_rate_pct DESC;


-- ══════════════════════════════════════════════════════════════
-- QUERY 2: SLA Breach Rate by Assignment Team
-- Business question: Which team has the worst SLA performance?
-- Technique: GROUP BY + HAVING to filter low-volume teams
-- ══════════════════════════════════════════════════════════════

SELECT
    assignment_group,
    COUNT(*)                                                   AS total_incidents,
    COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)   AS breached,
    ROUND(
        100.0 * COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)
        / NULLIF(COUNT(*), 0), 1
    )                                                          AS breach_rate_pct,
    ROUND(AVG(calc_resolution_hrs), 1)                        AS avg_resolution_hrs
FROM incidents_clean
WHERE state IN ('Resolved','Closed')
  AND assignment_group != 'Unknown'
GROUP BY assignment_group
HAVING COUNT(*) >= 20            -- exclude teams with too few tickets for meaningful stats
ORDER BY breach_rate_pct DESC;


-- ══════════════════════════════════════════════════════════════
-- QUERY 3: Monthly Breach Trend (2024)
-- Business question: Is SLA performance getting worse over time?
-- Technique: STRFTIME for date extraction, CTE + window function
-- ══════════════════════════════════════════════════════════════

WITH monthly AS (
    SELECT
        STRFTIME('%Y-%m', opened_at)                               AS month,
        COUNT(*)                                                   AS total,
        COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)   AS breached
    FROM incidents_clean
    WHERE state IN ('Resolved','Closed')
      AND opened_at IS NOT NULL
    GROUP BY 1
),
with_rolling AS (
    SELECT
        month,
        total,
        breached,
        ROUND(100.0 * breached / NULLIF(total,0), 1)   AS breach_rate_pct,
        -- 3-month rolling average breach rate using window function
        ROUND(
            AVG(100.0 * breached / NULLIF(total,0))
            OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        1)                                             AS rolling_3m_breach_pct
    FROM monthly
)
SELECT * FROM with_rolling
ORDER BY month;


-- ══════════════════════════════════════════════════════════════
-- QUERY 4: Top 10 Individuals with Highest Breach Count
-- Business question: Are specific assignees driving SLA failures?
-- Technique: RANK() window function, CTE
-- ══════════════════════════════════════════════════════════════

WITH agent_stats AS (
    SELECT
        assigned_to,
        assignment_group,
        COUNT(*)                                                   AS total_assigned,
        COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)   AS breached,
        ROUND(AVG(calc_resolution_hrs),1)                         AS avg_hrs,
        ROUND(
            100.0 * COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)
            / NULLIF(COUNT(*),0), 1
        )                                                          AS breach_rate_pct
    FROM incidents_clean
    WHERE state IN ('Resolved','Closed')
      AND assigned_to IS NOT NULL
    GROUP BY assigned_to, assignment_group
    HAVING COUNT(*) >= 10
),
ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY breach_rate_pct DESC) AS breach_rank
    FROM agent_stats
)
SELECT
    breach_rank,
    assigned_to,
    assignment_group,
    total_assigned,
    breached,
    avg_hrs,
    breach_rate_pct
FROM ranked
WHERE breach_rank <= 10
ORDER BY breach_rank;


-- ══════════════════════════════════════════════════════════════
-- QUERY 5: Category × Priority Breach Heatmap
-- Business question: Which category + priority combos are worst?
-- Technique: Multi-column GROUP BY, CASE for risk tiering
-- ══════════════════════════════════════════════════════════════

WITH heatmap AS (
    SELECT
        category,
        priority,
        COUNT(*)                                                   AS total,
        COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)   AS breached,
        ROUND(
            100.0 * COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)
            / NULLIF(COUNT(*),0), 1
        )                                                          AS breach_rate_pct
    FROM incidents_clean
    WHERE state IN ('Resolved','Closed')
      AND category != 'Unknown'
      AND priority != 'Unknown'
    GROUP BY category, priority
    HAVING COUNT(*) >= 5
)
SELECT
    category,
    priority,
    total,
    breached,
    breach_rate_pct,
    -- Risk tier label for executive summary
    CASE
        WHEN breach_rate_pct >= 60 THEN 'HIGH RISK'
        WHEN breach_rate_pct >= 35 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS risk_tier
FROM heatmap
ORDER BY breach_rate_pct DESC
LIMIT 20;


-- ══════════════════════════════════════════════════════════════
-- QUERY 6 (BONUS): Reopened Incidents — Hidden SLA Risk
-- Business question: Do reopened tickets hide actual breach rates?
-- Technique: CASE, aggregate filtering, derived columns
-- ══════════════════════════════════════════════════════════════

SELECT
    CASE
        WHEN reopen_count = 0 THEN 'Never reopened'
        WHEN reopen_count = 1 THEN 'Reopened once'
        ELSE 'Reopened 2+ times'
    END                                                        AS reopen_tier,
    COUNT(*)                                                   AS total_incidents,
    COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)   AS breached,
    ROUND(
        100.0 * COUNT(CASE WHEN sla_breached_recalc = 'Yes' THEN 1 END)
        / NULLIF(COUNT(*),0), 1
    )                                                          AS breach_rate_pct,
    ROUND(AVG(calc_resolution_hrs),1)                         AS avg_resolution_hrs
FROM incidents_clean
WHERE state IN ('Resolved','Closed')
GROUP BY 1
ORDER BY breach_rate_pct DESC;
