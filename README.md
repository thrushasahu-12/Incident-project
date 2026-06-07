# Project 1: Incident SLA Breach Analysis
**ServiceNow ITSM | SQL Portfolio Project**
**Author:** Thrusha Sahu | Data Analyst | Hyderabad, India

---

## Problem Statement
The Ops team suspected SLA breaches were being under-reported in ServiceNow exports. A raw incident dataset (~5,200 rows including duplicates) arrived with messy priority labels, inconsistent state values, mixed date formats, and null resolved_at timestamps on closed tickets — making breach rates untrustworthy.

**My role:** Ingest, profile, clean, and analyze the data using pure SQL to surface the real breach rates by team, priority, category, and time period — before the next executive review.

---

## Tools Used
| Tool | Purpose |
|------|---------|
| SQLite | Local database engine |
| DBeaver (optional) | SQL IDE with CSV import |
| SQL | All data cleaning, transformation, and analysis |

> No Python. No BI tools. 100% SQL.

---

## Dataset
- **File:** `raw_data/incident_raw.csv`
- **Rows:** ~5,200 (includes ~100 duplicate sys_ids)
- **Columns:** 19 fields including sys_id, opened_at, resolved_at, priority, state, category, assignment_group, sla_breached
- **Key data quality issues injected:**
  - Duplicate sys_ids
  - Mixed priority formats: `P1`, `1 - Critical`, `critical`, `HIGH`
  - Mixed state formats: `resolved`, `CLOSED`, `Resolved ` (trailing space)
  - Mixed date formats: `YYYY-MM-DD HH:MM:SS`, `DD/MM/YYYY HH:MM`, `YYYY/MM/DD`
  - Null/placeholder resolved_at on closed tickets: `NULL`, `N/A`, `''`
  - Missing sla_breached flags where resolutions exist

---

## SQL Scripts (run in order)

| Script | Purpose |
|--------|---------|
| `01_create_and_load.sql` | Create raw staging table |
| `02_data_profiling.sql` | Audit nulls, duplicates, value variance |
| `03_data_cleaning.sql` | Normalize, deduplicate, derive clean columns |
| `04_sla_analysis.sql` | 6 analysis queries for SLA insights |

---

## SQL Techniques Demonstrated
- `ROW_NUMBER() OVER (PARTITION BY sys_id)` — deduplication
- `CASE UPPER(TRIM(...))` — multi-variant normalization
- `JULIANDAY()` — date difference calculation
- `NULLIF()` — safe division & null coalescing
- `RANK() OVER (ORDER BY ...)` — agent breach ranking
- `AVG(...) OVER (ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` — rolling average
- Multi-CTE chaining for step-by-step transformation
- `HAVING` clause to filter low-volume groups

---

## Key Findings (from analysis queries)
1. **P1 / Critical incidents have the highest breach rate** — fast SLA target (4 hrs) with complex issues
2. **Infrastructure and Application Support teams** drive the most volume breaches
3. **Network + Critical combination** is the highest-risk category × priority cell
4. **Reopened tickets show 20–30% higher breach rates** than never-reopened ones
5. **~15% of resolved tickets had null resolved_at** — meaning source system breach flags were wrong

---

## How to Run

```bash
# SQLite CLI
sqlite3 incident_db.sqlite
.mode csv
.import raw_data/incident_raw.csv incidents_raw
.read scripts/01_create_and_load.sql
.read scripts/02_data_profiling.sql
.read scripts/03_data_cleaning.sql
.read scripts/04_sla_analysis.sql
```

---

## Repository Structure
```
project-01-sla-breach-analysis/
├── raw_data/
│   └── incident_raw.csv
├── scripts/
│   ├── 01_create_and_load.sql
│   ├── 02_data_profiling.sql
│   ├── 03_data_cleaning.sql
│   └── 04_sla_analysis.sql
├── outputs/
│   └── (paste query results here as .csv exports)
└── README.md
```

---

## Connect
[LinkedIn](https://linkedin.com) | [GitHub](https://github.com)
