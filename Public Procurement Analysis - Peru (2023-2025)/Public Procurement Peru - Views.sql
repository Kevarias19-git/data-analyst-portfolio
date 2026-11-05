-- Views | Public Procurement Analysis - Peru (2023-2025)
-- Run the whole script to rebuild every view (safe to re-run)

-- Drop all views
DROP VIEW IF EXISTS v_data_quality_summary;
DROP VIEW IF EXISTS v_orphan_contracts;
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

-- 0. FX rates (derived from the data, no manual rates)
-- Implied rate = amount in PEN / original amount

-- v_fx_valid: valid implied rates of non-PEN processes
--   Exclude unconverted rows (PEN amount = 0 or equal to the original amount)
--   Exclude rates outside +-15% of the currency-year average
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

-- Average rate by currency and month
-- Rate priority: process rate > month > year > all years
CREATE VIEW v_fx_month AS
    SELECT currency, ym, AVG(rate) AS rate, COUNT(*) AS n
    FROM v_fx_valid
    WHERE ym IS NOT NULL
    GROUP BY currency, ym;

-- Average rate by currency and year
CREATE VIEW v_fx_year AS
    SELECT currency, year, AVG(rate) AS rate, COUNT(*) AS n
    FROM v_fx_valid
    GROUP BY currency, year;

-- Average rate by currency, all years
CREATE VIEW v_fx_all AS
    SELECT currency, AVG(rate) AS rate, COUNT(*) AS n
    FROM v_fx_valid
    GROUP BY currency;

-- 1. Fact views

-- One row per award, amount converted to PEN (award_pen)
--   year = process year; award_year = year of the award itself
--   has_contract = 1 if a contract exists
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
-- ref_pen = reference amount in PEN:
--   PEN currency or zero amount -> original amount
--   valid source rate -> source PEN amount
--   otherwise -> original amount x fallback rate
-- fx_method: not_needed | source | estimated | missing
-- is_ref_reported = 0 when ref_pen = 0 (excluded from difference metrics)
-- dup_status flags probable duplicates (no row is deleted), matched by dup_key:
--   keep / discard: both ocid families in the group, 0-1 awarded -> keep one, discard the rest
--   review_double_count: both families, 2+ awarded -> review manually
--   same_family_candidate: same family only (likely lots or re-tenders) -> flag only
CREATE VIEW v_fact_process AS
    WITH aw AS (
        -- aw: awards aggregated per process
        SELECT
            ocid,
            COUNT(*) AS n_awards,
            SUM(award_pen) AS award_pen,
            SUM(has_contract) AS n_awards_with_contract,
            MIN(award_date) AS first_award_date,
            COUNT(DISTINCT supplier_id) AS n_suppliers,
            MAX(CASE WHEN rk = 1 THEN supplier_id END) AS main_supplier_id
        FROM (
            -- rk = 1: main award (largest one that has a supplier)
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY ocid ORDER BY supplier_id IS NULL, award_pen DESC, award_key) AS rk
            FROM v_fact_award
        )
        GROUP BY ocid
    ),
    -- loc: department and region of the buying entity
    loc AS (
        SELECT ocid, party_id, MAX(department) AS department, MAX(region) AS region
        FROM parties
        GROUP BY ocid, party_id
    ),
    -- base: process data + converted amounts
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
            -- is_year_entity: ocid belongs to the 'year-entity' family
            aw.ocid IS NOT NULL AS is_awarded,
            r.ocid LIKE 'ocds-dgv273-seacev3-20__-%' AS is_year_entity,
            -- dup_key: duplicate matching key
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
    -- grp: size of each dup_key group (g_n), with its year-entity (g_ye) and awarded (g_aw) counts
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

-- One name per supplier_id (most frequent, quotes removed)
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

-- One name per procuring_entity_id (most frequent)
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

-- Read records directly (faster than v_fact_process)
CREATE VIEW v_dim_category AS
    SELECT DISTINCT COALESCE(procurement_category, 'Not reported') AS procurement_category
    FROM records;

CREATE VIEW v_dim_method AS
    SELECT DISTINCT COALESCE(procurement_method, 'Not reported') AS procurement_method
    FROM records;

-- One department per process (same logic as v_fact_process)
CREATE VIEW v_dim_department AS
    SELECT DISTINCT COALESCE(department, 'Not reported') AS department
    FROM (
        SELECT MAX(p.department) AS department
        FROM records r
        LEFT JOIN parties p ON p.ocid = r.ocid AND p.party_id = r.procuring_entity_id
        GROUP BY r.ocid
    );

-- 3. Contracts

-- Contracts whose award does not exist in awards
CREATE VIEW v_orphan_contracts AS
    SELECT c.*, r.procuring_entity_id, r.procuring_entity_name
    FROM contracts c
    LEFT JOIN records r ON r.ocid = c.ocid
    WHERE c.award_in_awards = 0;

-- 4. Data quality (one row per finding)

-- cnt = affected rows | amount_pen = amount in PEN (orphan contracts: contract currency) | base = denominator for %
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
            -- pen_unusable: source PEN column is zero or equal to the original amount
            r.tender_value_amount > 0 AND (
                r.tender_value_amount_pen = 0
                OR (r.tender_value_currency <> 'PEN' AND r.tender_value_amount_pen = r.tender_value_amount)
            ) AS pen_unusable,
            -- rate_outside_band: source rate was discarded (outside +-15%) and re-estimated
            r.tender_value_currency <> 'PEN'
                AND r.tender_value_amount > 0
                AND r.tender_value_amount_pen > 0
                AND r.tender_value_amount_pen <> r.tender_value_amount
                AND f.fx_method <> 'source' AS rate_outside_band
        FROM v_fact_process f
        JOIN records r ON r.ocid = f.ocid
        LEFT JOIN (SELECT ocid, COUNT(*) AS n FROM ten_tenderers GROUP BY ocid) t ON t.ocid = f.ocid
    ),
    -- p / a / c: one aggregate per source (processes, awards, contracts)
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
    -- Unpivot: one SELECT per finding
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
