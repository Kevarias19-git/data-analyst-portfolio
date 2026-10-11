-- Aggregation views for Power BI
-- Run over contracts.db after loading the data (safe to rerun)

-- 1. Rank suppliers by awarded amount
DROP VIEW IF EXISTS v_top_suppliers;
CREATE VIEW v_top_suppliers AS
SELECT
    s.supplier_name,
    COUNT(DISTINCT s.award_key)    AS awards_won,
    SUM(a.award_amount)            AS total_amount,
    AVG(a.award_amount)            AS average_amount
FROM awa_suppliers s
JOIN awards a ON s.award_key = a.award_key
WHERE s.supplier_name IS NOT NULL
GROUP BY s.supplier_name;

-- 2. Rank procuring entities by year, processes and awarded amount
DROP VIEW IF EXISTS v_top_entities;
CREATE VIEW v_top_entities AS
SELECT
    r.year,
    r.procuring_entity_name,
    COUNT(DISTINCT r.ocid)         AS processes,
    SUM(a.award_amount)            AS total_amount
FROM records r
JOIN awards a ON r.ocid = a.ocid
WHERE r.procuring_entity_name IS NOT NULL
GROUP BY r.year, r.procuring_entity_name;

-- 3. List processes with a single tenderer
DROP VIEW IF EXISTS v_low_competition_processes;
CREATE VIEW v_low_competition_processes AS
SELECT
    r.ocid, r.year, r.tender_title, r.procuring_entity_name,
    COUNT(t.tenderer_id) AS num_tenderers
FROM records r
JOIN ten_tenderers t ON r.ocid = t.ocid
GROUP BY r.ocid, r.year, r.tender_title, r.procuring_entity_name
HAVING COUNT(t.tenderer_id) = 1;

-- 4. Summarize processes, amounts and tenderers per year
-- Aggregate awards per process before joining, to avoid repeating the
-- reference amount of processes with several awards
-- Include sum and count of tenderers to compute a weighted average in Power BI
DROP VIEW IF EXISTS v_annual_summary;
CREATE VIEW v_annual_summary AS
SELECT
    r.year,
    COUNT(DISTINCT r.ocid)                        AS total_processes,
    CAST(SUM(r.tender_value_amount) AS REAL)      AS total_reference_amount,
    CAST(SUM(a.award_total) AS REAL)              AS total_awarded_amount,
    CAST(AVG(r.number_of_tenderers) AS REAL)      AS average_tenderers,
    CAST(SUM(r.number_of_tenderers) AS REAL)      AS tenderers_sum,
    CAST(COUNT(r.number_of_tenderers) AS REAL)    AS processes_with_tenderers
FROM records r
LEFT JOIN (
    SELECT ocid, SUM(award_amount) AS award_total
    FROM awards
    GROUP BY ocid
) a ON r.ocid = a.ocid
GROUP BY r.year;

-- 5. Compare contract amount and final value
DROP VIEW IF EXISTS v_contracts_with_variance;
CREATE VIEW v_contracts_with_variance AS
SELECT
    c.contract_key, r.procuring_entity_name,
    c.contract_amount, c.final_value_amount, c.amount_variance,
    ROUND(100.0 * c.amount_variance / NULLIF(c.contract_amount, 0), 1) AS variance_pct,
    c.year
FROM contracts c
JOIN records r ON c.ocid = r.ocid
WHERE c.amount_variance IS NOT NULL;

-- 6. Flag contracts whose award is missing from the awards table
DROP VIEW IF EXISTS v_orphan_contracts;
CREATE VIEW v_orphan_contracts AS
SELECT c.* FROM contracts c WHERE c.award_in_awards = 0;


-- 7. Rank suppliers per year with RANK()
DROP VIEW IF EXISTS v_annual_supplier_ranking;
CREATE VIEW v_annual_supplier_ranking AS
WITH supplier_amount_year AS (
    SELECT
        s.year,
        s.supplier_name,
        SUM(a.award_amount)            AS total_amount,
        COUNT(DISTINCT s.award_key)    AS awards_won
    FROM awa_suppliers s
    JOIN awards a ON s.award_key = a.award_key
    WHERE s.supplier_name IS NOT NULL
    GROUP BY s.year, s.supplier_name
)
SELECT
    year, supplier_name, total_amount, awards_won,
    RANK() OVER (PARTITION BY year ORDER BY total_amount DESC) AS ranking
FROM supplier_amount_year;


-- 8. Measure market concentration: supplier share (%) within each
-- procurement category, using SUM() OVER for the category total
DROP VIEW IF EXISTS v_category_concentration;
CREATE VIEW v_category_concentration AS
WITH category_supplier_amount AS (
    SELECT
        r.procurement_category,
        s.supplier_name,
        SUM(a.award_amount) AS supplier_amount
    FROM records r
    JOIN awards a ON r.ocid = a.ocid
    JOIN awa_suppliers s ON s.award_key = a.award_key
    WHERE r.procurement_category IS NOT NULL AND s.supplier_name IS NOT NULL
    GROUP BY r.procurement_category, s.supplier_name
)
SELECT
    procurement_category, supplier_name, supplier_amount,
    ROUND(100.0 * supplier_amount / SUM(supplier_amount)
        OVER (PARTITION BY procurement_category), 1)  AS share_pct
FROM category_supplier_amount;


-- 9. Distribute processes and amounts by region and department of the
-- buying entity, for the map visual in Power BI
DROP VIEW IF EXISTS v_geographic_detail;
CREATE VIEW v_geographic_detail AS
SELECT
    p.region,
    p.department,
    r.year,
    COUNT(DISTINCT r.ocid)  AS processes,
    SUM(a.award_amount)     AS total_amount
FROM records r
JOIN parties p ON p.ocid = r.ocid AND p.party_id = r.procuring_entity_id
LEFT JOIN awards a ON a.ocid = r.ocid
WHERE p.region IS NOT NULL
GROUP BY p.region, p.department, r.year;


-- 10. Count processes by category and procurement method,
-- for the treemap and stacked bar chart
DROP VIEW IF EXISTS v_category_method;
CREATE VIEW v_category_method AS
SELECT
    year, procurement_category, procurement_method,
    COUNT(DISTINCT ocid)       AS processes,
    SUM(tender_value_amount)   AS reference_amount
FROM records
GROUP BY year, procurement_category, procurement_method;


-- 11. List processes without an award, the counterpart of v_orphan_contracts
DROP VIEW IF EXISTS v_processes_without_award;
CREATE VIEW v_processes_without_award AS
SELECT r.ocid, r.year, r.tender_title, r.procuring_entity_name, r.tender_value_amount
FROM records r
LEFT JOIN awards a ON r.ocid = a.ocid
WHERE a.ocid IS NULL;