-- Views | Public Procurement Analysis - Peru (2023-2025)
-- Run against contracts.db after loading the data (safe to rerun)
-- Require SQLite 3.25+ (window functions)

-- Load in Power BI:
--   Facts: v_fact_process, v_fact_award
--   Dimensions: v_dim_supplier, v_dim_entity, v_dim_category, v_dim_method, v_dim_department
--   Detail: v_contracts_with_variance, v_orphan_contracts, v_processes_without_award, v_data_quality_summary
-- Skip v_fx_* (helpers) and the [OPTIONAL] views (replaceable with DAX measures)


-- Drop every view (dependents first, v_fx_raw is a legacy helper)
DROP VIEW IF EXISTS v_data_quality_summary;
DROP VIEW IF EXISTS v_processes_without_award;
DROP VIEW IF EXISTS v_category_method;
DROP VIEW IF EXISTS v_geographic_detail;
DROP VIEW IF EXISTS v_orphan_contracts;
DROP VIEW IF EXISTS v_contracts_with_variance;
DROP VIEW IF EXISTS v_low_competition_processes;
DROP VIEW IF EXISTS v_annual_summary;
DROP VIEW IF EXISTS v_category_concentration;
DROP VIEW IF EXISTS v_annual_supplier_ranking;
DROP VIEW IF EXISTS v_top_suppliers;
DROP VIEW IF EXISTS v_top_entities;
DROP VIEW IF EXISTS v_dim_department;
DROP VIEW IF EXISTS v_dim_method;
DROP VIEW IF EXISTS v_dim_category;
DROP VIEW IF EXISTS v_dim_entity;
DROP VIEW IF EXISTS v_dim_supplier;
DROP VIEW IF EXISTS v_fact_process;
DROP VIEW IF EXISTS v_fact_award;
DROP VIEW IF EXISTS v_fx_all;
DROP VIEW IF EXISTS v_fx_year;
DROP VIEW IF EXISTS v_fx_month;
DROP VIEW IF EXISTS v_fx_valid;
DROP VIEW IF EXISTS v_fx_raw;


-- 0. FX rates derived from records (no manual rates)
-- Take the implied rate (PEN amount / original amount) of every non-PEN process
-- Discard unconverted rows (PEN amount equal to 0 or to the original amount)
-- Discard rates outside +-15% of the currency-year average (bad source data)
-- Resolve each rate by priority: same process, same currency and month, same currency and year, same currency overall
-- A NULL ref_pen or award_pen means no rate was found for that currency

CREATE VIEW v_fx_valid AS
    WITH raw_rates AS (
        SELECT
            ocid,
            tender_value_currency AS currency,
            year,
            strftime('%Y-%m', tender_published_date) AS ym,
            tender_value_amount_pen / tender_value_amount AS rate,
            AVG(tender_value_amount_pen / tender_value_amount) OVER (PARTITION BY tender_value_currency, year) AS avg_year_rate
        FROM records
        WHERE tender_value_currency <> 'PEN'
            AND tender_value_amount > 0
            AND tender_value_amount_pen > 0
            AND tender_value_amount_pen <> tender_value_amount
    )
    SELECT ocid, currency, year, ym, rate
    FROM raw_rates
    WHERE rate BETWEEN 0.85 * avg_year_rate AND 1.15 * avg_year_rate;

CREATE VIEW v_fx_month AS
    SELECT currency, ym, AVG(rate) AS rate, COUNT(*) AS n
    FROM v_fx_valid
    WHERE ym IS NOT NULL
    GROUP BY currency, ym;

CREATE VIEW v_fx_year AS
    SELECT currency, year, AVG(rate) AS rate, COUNT(*) AS n
    FROM v_fx_valid
    GROUP BY currency, year;

CREATE VIEW v_fx_all AS
    SELECT currency, AVG(rate) AS rate, COUNT(*) AS n
    FROM v_fx_valid
    GROUP BY currency;


-- 1. Fact views

-- One row per award
-- Use the process year to match v_fact_process and keep the award year apart
-- Reuse the process rate when the award and tender currencies match, else fall back to the averages
-- Join suppliers without multiplying rows since each award has at most one supplier
CREATE VIEW v_fact_award AS
    SELECT
        a.award_key,
        a.ocid,
        r.year,
        a.year AS award_year,
        a.award_date,
        a.award_amount,
        a.award_currency,
        a.award_amount * CASE
            WHEN a.award_currency = 'PEN' OR a.award_amount = 0 THEN 1.0
            ELSE COALESCE(
                CASE WHEN a.award_currency = r.tender_value_currency THEN vp.rate END,
                fm.rate, fy.rate, fl.rate)
        END AS award_pen,
        s.supplier_id,
        EXISTS (SELECT 1 FROM contracts c WHERE c.award_key = a.award_key) AS has_contract
    FROM awards a
    JOIN records r ON r.ocid = a.ocid
    LEFT JOIN v_fx_valid vp ON vp.ocid = a.ocid
    LEFT JOIN v_fx_month fm ON fm.currency = a.award_currency AND fm.ym = strftime('%Y-%m', r.tender_published_date)
    LEFT JOIN v_fx_year fy ON fy.currency = a.award_currency AND fy.year = r.year
    LEFT JOIN v_fx_all fl ON fl.currency = a.award_currency
    LEFT JOIN awa_suppliers s ON s.award_key = a.award_key;

-- One row per process (ocid)
-- Convert the reference amount to PEN:
--   PEN currency or zero amount -> original amount (the source PEN column is ignored)
--   valid source rate -> source PEN amount
--   zero or unconverted source -> original amount x fallback rate
-- Treat ref_pen = 0 as an unreported reference (is_ref_reported = 0) and exclude it from savings and over-reference metrics
-- Flag probable duplicates in dup_status without deleting rows, matching on title + entity + value + publication date + currency
--   keep / discard: both OCID families in the group and at most one awarded member, so keep one (awarded first, then numeric) and discard the rest
--   review_double_count: both families and 2+ awarded members, so discard nothing and review manually
--   same_family_candidate: candidate within one family (likely lots or re-tenders), so flag only
CREATE VIEW v_fact_process AS
    WITH aw AS (
        SELECT
            ocid,
            COUNT(*) AS n_awards,
            SUM(award_pen) AS award_pen,
            SUM(has_contract) AS n_awards_with_contract,
            MIN(award_date) AS first_award_date,
            COUNT(DISTINCT supplier_id) AS n_suppliers,
            MAX(CASE WHEN rk = 1 THEN supplier_id END) AS main_supplier_id
        FROM (
            -- Rank awards so the largest one with a supplier comes first
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY ocid ORDER BY supplier_id IS NULL, award_pen DESC, award_key) AS rk
            FROM v_fact_award
        )
        GROUP BY ocid
    ),
    loc AS (
        SELECT ocid, party_id, MAX(department) AS department, MAX(region) AS region
        FROM parties
        GROUP BY ocid, party_id
    ),
    base AS (
        SELECT
            r.ocid,
            r.year,
            COALESCE(r.procurement_category, 'Not reported') AS procurement_category,
            COALESCE(r.procurement_method, 'Not reported') AS procurement_method,
            r.procuring_entity_id,
            r.procuring_entity_name,
            COALESCE(loc.department, 'Not reported') AS department,
            loc.region,
            r.tender_title,
            r.tender_published_date,
            r.tender_duration_days,
            r.invalid_period,
            r.tender_value_currency,
            CASE
                WHEN r.tender_value_currency = 'PEN' OR r.tender_value_amount = 0 THEN 'not_needed'
                WHEN vp.rate IS NOT NULL THEN 'source'
                WHEN COALESCE(fm.rate, fy.rate, fl.rate) IS NOT NULL THEN 'estimated'
                ELSE 'missing'
            END AS fx_method,
            CASE
                WHEN r.tender_value_currency = 'PEN' OR r.tender_value_amount = 0 THEN r.tender_value_amount
                WHEN vp.rate IS NOT NULL THEN r.tender_value_amount_pen
                ELSE r.tender_value_amount * COALESCE(fm.rate, fy.rate, fl.rate)
            END AS ref_pen,
            r.number_of_tenderers AS n_tenderers,
            aw.n_awards,
            aw.award_pen,
            aw.n_awards_with_contract,
            aw.first_award_date,
            aw.n_suppliers,
            aw.main_supplier_id,
            aw.ocid IS NOT NULL AS is_awarded,
            r.ocid LIKE 'ocds-dgv273-seacev3-20__-%' AS is_year_entity,
            IFNULL(r.tender_title, '') || '|' ||
            IFNULL(r.procuring_entity_id, '') || '|' ||
            IFNULL(r.tender_value_amount, '') || '|' ||
            IFNULL(r.tender_published_date, '') || '|' ||
            IFNULL(r.tender_value_currency, '') AS dup_key
        FROM records r
        LEFT JOIN v_fx_valid vp ON vp.ocid = r.ocid
        LEFT JOIN v_fx_month fm ON fm.currency = r.tender_value_currency AND fm.ym = strftime('%Y-%m', r.tender_published_date)
        LEFT JOIN v_fx_year fy ON fy.currency = r.tender_value_currency AND fy.year = r.year
        LEFT JOIN v_fx_all fl ON fl.currency = r.tender_value_currency
        LEFT JOIN aw ON aw.ocid = r.ocid
        LEFT JOIN loc ON loc.ocid = r.ocid AND loc.party_id = r.procuring_entity_id
    ),
    grp AS (
        SELECT
            *,
            COUNT(*) OVER (PARTITION BY dup_key) AS g_n,
            SUM(is_year_entity) OVER (PARTITION BY dup_key) AS g_ye,
            SUM(is_awarded) OVER (PARTITION BY dup_key) AS g_aw,
            ROW_NUMBER() OVER (PARTITION BY dup_key ORDER BY is_awarded DESC, is_year_entity, ocid) AS rk
        FROM base
    )
    SELECT
        ocid,
        year,
        procurement_category,
        procurement_method,
        procuring_entity_id,
        procuring_entity_name,
        department,
        region,
        tender_title,
        tender_published_date,
        tender_duration_days,
        invalid_period,
        tender_value_currency,
        fx_method,
        ref_pen,
        award_pen,
        COALESCE(n_awards, 0) AS n_awards,
        n_suppliers,
        main_supplier_id,
        first_award_date,
        n_tenderers,
        is_awarded,
        COALESCE(n_awards_with_contract, 0) > 0 AS has_contract,
        COALESCE(ref_pen > 0, 0) AS is_ref_reported,
        CASE WHEN is_awarded AND ref_pen > 0 THEN award_pen - ref_pen END AS award_diff_pen,
        CASE WHEN is_awarded AND ref_pen > 0 THEN (award_pen - ref_pen) / ref_pen END AS award_diff_pct,
        COALESCE(is_awarded AND ref_pen > 0 AND award_pen > ref_pen, 0) AS is_over_ref,
        n_tenderers = 1 AS is_single_bidder,
        CASE WHEN is_year_entity THEN 'year-entity' ELSE 'numeric' END AS ocid_family,
        CASE
            WHEN g_n > 1 AND g_ye > 0 AND g_ye < g_n THEN
                CASE
                    WHEN g_aw >= 2 THEN 'review_double_count'
                    WHEN rk = 1 THEN 'keep'
                    ELSE 'discard'
                END
            WHEN g_n > 1 THEN 'same_family_candidate'
            ELSE 'none'
        END AS dup_status
    FROM grp;


-- 2. Dimensions

-- Pick the most frequent supplier name per supplier_id, without quotes
CREATE VIEW v_dim_supplier AS
    SELECT supplier_id, supplier_name
    FROM (
        SELECT
            supplier_id,
            REPLACE(supplier_name, '"', '') AS supplier_name,
            ROW_NUMBER() OVER (PARTITION BY supplier_id ORDER BY COUNT(*) DESC, REPLACE(supplier_name, '"', '')) AS rk
        FROM awa_suppliers
        WHERE supplier_id IS NOT NULL
        GROUP BY supplier_id, REPLACE(supplier_name, '"', '')
    )
    WHERE rk = 1;

-- Pick the most frequent entity name per procuring_entity_id
CREATE VIEW v_dim_entity AS
    SELECT procuring_entity_id, procuring_entity_name
    FROM (
        SELECT
            procuring_entity_id,
            procuring_entity_name,
            ROW_NUMBER() OVER (PARTITION BY procuring_entity_id ORDER BY COUNT(*) DESC, procuring_entity_name) AS rk
        FROM records
        WHERE procuring_entity_id IS NOT NULL
        GROUP BY procuring_entity_id, procuring_entity_name
    )
    WHERE rk = 1;

-- Read records directly to avoid evaluating v_fact_process
CREATE VIEW v_dim_category AS
    SELECT DISTINCT COALESCE(procurement_category, 'Not reported') AS procurement_category
    FROM records;

CREATE VIEW v_dim_method AS
    SELECT DISTINCT COALESCE(procurement_method, 'Not reported') AS procurement_method
    FROM records;

-- Match the department logic of v_fact_process: one value per process
CREATE VIEW v_dim_department AS
    SELECT DISTINCT COALESCE(department, 'Not reported') AS department
    FROM (
        SELECT MAX(p.department) AS department
        FROM records r
        LEFT JOIN parties p ON p.ocid = r.ocid AND p.party_id = r.procuring_entity_id
        GROUP BY r.ocid
    );


-- 3. Analysis views

-- [OPTIONAL] Rank suppliers by awarded amount (PEN) per year
CREATE VIEW v_top_suppliers AS
    SELECT
        fa.year,
        fa.supplier_id,
        ds.supplier_name,
        COUNT(DISTINCT fa.award_key) AS awards_won,
        SUM(fa.award_pen) AS total_amount,
        AVG(fa.award_pen) AS average_amount
    FROM v_fact_award fa
    JOIN v_dim_supplier ds ON ds.supplier_id = fa.supplier_id
    GROUP BY fa.year, fa.supplier_id, ds.supplier_name;

-- [OPTIONAL] Rank suppliers per year with RANK()
CREATE VIEW v_annual_supplier_ranking AS
    SELECT
        year,
        supplier_id,
        supplier_name,
        total_amount,
        awards_won,
        RANK() OVER (PARTITION BY year ORDER BY total_amount DESC) AS ranking
    FROM v_top_suppliers;

-- [OPTIONAL] Measure supplier share (%) within each category and year
-- Prefer a DAX measure for the share in Power BI
CREATE VIEW v_category_concentration AS
    WITH category_supplier_amount AS (
        SELECT
            fa.year,
            r.procurement_category,
            fa.supplier_id,
            ds.supplier_name,
            SUM(fa.award_pen) AS supplier_amount
        FROM v_fact_award fa
        JOIN records r ON r.ocid = fa.ocid
        JOIN v_dim_supplier ds ON ds.supplier_id = fa.supplier_id
        WHERE r.procurement_category IS NOT NULL
        GROUP BY fa.year, r.procurement_category, fa.supplier_id, ds.supplier_name
    )
    SELECT
        year,
        procurement_category,
        supplier_id,
        supplier_name,
        supplier_amount,
        ROUND(100.0 * supplier_amount / SUM(supplier_amount) OVER (PARTITION BY year, procurement_category), 1) AS share_pct
    FROM category_supplier_amount;

-- Rank procuring entities per year: total vs awarded processes and awarded PEN
CREATE VIEW v_top_entities AS
    SELECT
        year,
        procuring_entity_id,
        procuring_entity_name,
        COUNT(*) AS processes_total,
        SUM(is_awarded) AS processes_awarded,
        SUM(award_pen) AS total_amount
    FROM v_fact_process
    WHERE procuring_entity_name IS NOT NULL
    GROUP BY year, procuring_entity_id, procuring_entity_name;

-- List processes with a single tenderer (source: ten_tenderers)
-- Use v_fact_process.n_tenderers for an adjustable threshold
CREATE VIEW v_low_competition_processes AS
    SELECT
        r.ocid,
        r.year,
        r.tender_title,
        r.procuring_entity_name,
        COUNT(t.tenderer_id) AS num_tenderers
    FROM records r
    JOIN ten_tenderers t ON t.ocid = r.ocid
    GROUP BY r.ocid, r.year, r.tender_title, r.procuring_entity_name
    HAVING COUNT(t.tenderer_id) = 1;

-- [OPTIONAL] Summarize processes and amounts (PEN) per year
-- Compute the weighted tenderer average as tenderers_sum / processes_with_tenderers
-- Compute the median from v_fact_process
CREATE VIEW v_annual_summary AS
    SELECT
        year,
        COUNT(*) AS total_processes,
        SUM(is_awarded) AS processes_awarded,
        SUM(ref_pen) AS total_reference_amount,
        SUM(CASE WHEN is_awarded THEN ref_pen END) AS reference_awarded_amount,
        SUM(CASE WHEN NOT is_awarded THEN ref_pen END) AS reference_unawarded_amount,
        SUM(award_pen) AS total_awarded_amount,
        AVG(n_tenderers) AS average_tenderers,
        CAST(SUM(n_tenderers) AS REAL) AS tenderers_sum,
        CAST(COUNT(n_tenderers) AS REAL) AS processes_with_tenderers
    FROM v_fact_process
    GROUP BY year;

-- Compare contract amount and final value (original contract currency)
CREATE VIEW v_contracts_with_variance AS
    SELECT
        c.contract_key,
        r.procuring_entity_id,
        r.procuring_entity_name,
        c.contract_amount,
        c.final_value_amount,
        c.amount_variance,
        ROUND(100.0 * c.amount_variance / NULLIF(c.contract_amount, 0), 1) AS variance_pct,
        c.year
    FROM contracts c
    JOIN records r ON r.ocid = c.ocid
    WHERE c.amount_variance IS NOT NULL;

-- Flag contracts whose award is missing from the awards table
CREATE VIEW v_orphan_contracts AS
    SELECT c.*, r.procuring_entity_id, r.procuring_entity_name
    FROM contracts c
    LEFT JOIN records r ON r.ocid = c.ocid
    WHERE c.award_in_awards = 0;

-- Distribute processes and amounts by region and department of the buying entity
CREATE VIEW v_geographic_detail AS
    SELECT
        region,
        department,
        year,
        COUNT(*) AS processes_total,
        SUM(is_awarded) AS processes_awarded,
        SUM(award_pen) AS total_amount
    FROM v_fact_process
    WHERE region IS NOT NULL
    GROUP BY region, department, year;

-- Count processes by category and method with the reference amount (PEN)
CREATE VIEW v_category_method AS
    SELECT
        year,
        procurement_category,
        procurement_method,
        COUNT(*) AS processes,
        SUM(ref_pen) AS reference_amount
    FROM v_fact_process
    GROUP BY year, procurement_category, procurement_method;

-- List processes without an award, with the duplicate flag
CREATE VIEW v_processes_without_award AS
    SELECT
        ocid,
        year,
        procuring_entity_id,
        procuring_entity_name,
        procurement_category,
        procurement_method,
        ref_pen,
        dup_status
    FROM v_fact_process
    WHERE NOT is_awarded;


-- 4. Data quality summary, one row per finding
-- Read each source once and unpivot the aggregates
-- amount_pen is in PEN except for orphan contracts (contract currency)
-- base is the denominator for percentages
CREATE VIEW v_data_quality_summary AS
    WITH flags AS (
        SELECT
            f.is_awarded,
            f.ref_pen,
            f.award_pen,
            f.n_tenderers,
            f.dup_status,
            f.tender_value_currency,
            r.year <> r.tender_year AS year_mismatch,
            r.number_of_tenderers <> t.n AS tenderer_mismatch,
            r.tender_value_amount > 0 AND (
                r.tender_value_amount_pen = 0
                OR (r.tender_value_currency <> 'PEN' AND r.tender_value_amount_pen = r.tender_value_amount)
            ) AS pen_unusable,
            r.tender_value_currency <> 'PEN'
                AND r.tender_value_amount > 0
                AND r.tender_value_amount_pen > 0
                AND r.tender_value_amount_pen <> r.tender_value_amount
                AND f.fx_method <> 'source' AS rate_outside_band
        FROM v_fact_process f
        JOIN records r ON r.ocid = f.ocid
        LEFT JOIN (SELECT ocid, COUNT(*) AS n FROM ten_tenderers GROUP BY ocid) t ON t.ocid = f.ocid
    ),
    p AS (
        SELECT
            COUNT(*) AS n,
            SUM(NOT is_awarded) AS unawarded,
            SUM(CASE WHEN NOT is_awarded THEN ref_pen END) AS unawarded_ref,
            SUM(n_tenderers IS NULL) AS no_tenderers,
            COUNT(CASE WHEN tenderer_mismatch THEN 1 END) AS tenderer_mismatch,
            SUM(pen_unusable) AS pen_unusable,
            SUM(CASE WHEN pen_unusable THEN ref_pen END) AS pen_unusable_ref,
            SUM(rate_outside_band) AS rate_outside_band,
            SUM(ref_pen = 0) AS no_ref,
            SUM(is_awarded AND ref_pen = 0) AS awarded_no_ref,
            SUM(CASE WHEN is_awarded AND ref_pen = 0 THEN award_pen END) AS awarded_no_ref_amount,
            SUM(dup_status = 'discard') AS dup_discard,
            SUM(CASE WHEN dup_status = 'discard' THEN ref_pen END) AS dup_discard_ref,
            SUM(dup_status = 'review_double_count') AS dup_double,
            SUM(CASE WHEN dup_status = 'review_double_count' THEN award_pen END) AS dup_double_award,
            SUM(dup_status = 'same_family_candidate') AS dup_single,
            SUM(CASE WHEN dup_status = 'same_family_candidate' THEN ref_pen END) AS dup_single_ref,
            SUM(tender_value_currency <> 'PEN') AS non_pen,
            SUM(CASE WHEN tender_value_currency <> 'PEN' THEN ref_pen END) AS non_pen_ref,
            SUM(year_mismatch) AS year_mismatch
        FROM flags
    ),
    a AS (
        SELECT
            COUNT(*) AS n,
            SUM(NOT has_contract) AS no_contract,
            SUM(CASE WHEN NOT has_contract THEN award_pen END) AS no_contract_amount,
            SUM(supplier_id IS NULL) AS no_supplier,
            SUM(CASE WHEN supplier_id IS NULL THEN award_pen END) AS no_supplier_amount
        FROM v_fact_award
    ),
    c AS (
        SELECT
            COUNT(*) AS n,
            SUM(award_in_awards = 0) AS orphans,
            SUM(CASE WHEN award_in_awards = 0 THEN contract_amount END) AS orphans_amount
        FROM contracts
    )
    SELECT 'Processes without award' AS finding, 'Process outcome' AS type, unawarded AS cnt, unawarded_ref AS amount_pen, n AS base FROM p
    UNION ALL
    SELECT 'Awards without contract', 'Process outcome (to verify)', no_contract, no_contract_amount, n FROM a
    UNION ALL
    SELECT 'Orphan contracts', 'Data defect', orphans, orphans_amount, n FROM c
    UNION ALL
    SELECT 'Awards without supplier', 'Data defect', no_supplier, no_supplier_amount, n FROM a
    UNION ALL
    SELECT 'Processes without tenderer count', 'Data defect', no_tenderers, NULL, n FROM p
    UNION ALL
    SELECT 'Tenderer count mismatch between sources', 'Data defect', tenderer_mismatch, NULL, n FROM p
    UNION ALL
    SELECT 'Source PEN column zero or unconverted', 'Data defect', pen_unusable, pen_unusable_ref, n FROM p
    UNION ALL
    SELECT 'Source FX rate outside band (re-estimated)', 'Data defect', rate_outside_band, NULL, n FROM p
    UNION ALL
    SELECT 'Processes with unreported reference', 'Data limitation (to verify)', no_ref, NULL, n FROM p
    UNION ALL
    SELECT 'Awarded processes with unreported reference', 'Data limitation (to verify)', awarded_no_ref, awarded_no_ref_amount, n FROM p
    UNION ALL
    SELECT 'Probable duplicates to discard (both families)', 'To verify', dup_discard, dup_discard_ref, n FROM p
    UNION ALL
    SELECT 'Duplicates with double award (review)', 'To verify', dup_double, dup_double_award, n FROM p
    UNION ALL
    SELECT 'Candidates within a single family', 'To verify', dup_single, dup_single_ref, n FROM p
    UNION ALL
    SELECT 'Processes in non-PEN currency', 'Treatment', non_pen, non_pen_ref, n FROM p
    UNION ALL
    SELECT 'year different from tender_year', 'Minor defect', year_mismatch, NULL, n FROM p;
