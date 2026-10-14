USE ICIJ_OffshoreLeaks;
GO

-- Force English month names to parse dates such as 02-NOV-2007
-- ISO dates such as 2007-07-20 parse correctly in any language
SET LANGUAGE English;
GO

-- Drop existing typed tables to allow reruns
IF OBJECT_ID('dbo.relationships', 'U')   IS NOT NULL DROP TABLE dbo.relationships;
IF OBJECT_ID('dbo.addresses', 'U')       IS NOT NULL DROP TABLE dbo.addresses;
IF OBJECT_ID('dbo.entities', 'U')        IS NOT NULL DROP TABLE dbo.entities;
IF OBJECT_ID('dbo.intermediaries', 'U')  IS NOT NULL DROP TABLE dbo.intermediaries;
IF OBJECT_ID('dbo.officers', 'U')        IS NOT NULL DROP TABLE dbo.officers;
IF OBJECT_ID('dbo.others', 'U')          IS NOT NULL DROP TABLE dbo.others;
GO

-- Create typed node tables with a primary key on node_id
CREATE TABLE dbo.addresses (
    node_id       BIGINT         NOT NULL PRIMARY KEY,
    address       NVARCHAR(4000) NULL,
    name          NVARCHAR(4000) NULL,
    countries     NVARCHAR(4000) NULL,
    country_codes NVARCHAR(4000) NULL,
    source_id     NVARCHAR(4000) NULL,
    valid_until   NVARCHAR(4000) NULL,
    note          NVARCHAR(4000) NULL
);

CREATE TABLE dbo.entities (
    node_id                  BIGINT         NOT NULL PRIMARY KEY,
    name                     NVARCHAR(4000) NULL,
    original_name            NVARCHAR(4000) NULL,
    former_name              NVARCHAR(4000) NULL,
    jurisdiction             NVARCHAR(4000) NULL,
    jurisdiction_description NVARCHAR(4000) NULL,
    company_type             NVARCHAR(4000) NULL,
    address                  NVARCHAR(4000) NULL,
    internal_id              NVARCHAR(4000) NULL,
    incorporation_date       DATE           NULL,
    inactivation_date        DATE           NULL,
    struck_off_date          DATE           NULL,
    dorm_date                DATE           NULL,
    status                   NVARCHAR(4000) NULL,
    service_provider         NVARCHAR(4000) NULL,
    ibc_ruc                  NVARCHAR(4000) NULL,
    country_codes            NVARCHAR(4000) NULL,
    countries                NVARCHAR(4000) NULL,
    source_id                NVARCHAR(4000) NULL,
    valid_until              NVARCHAR(4000) NULL,
    note                     NVARCHAR(4000) NULL
);

CREATE TABLE dbo.intermediaries (
    node_id       BIGINT         NOT NULL PRIMARY KEY,
    name          NVARCHAR(4000) NULL,
    status        NVARCHAR(4000) NULL,
    internal_id   NVARCHAR(4000) NULL,
    address       NVARCHAR(4000) NULL,
    countries     NVARCHAR(4000) NULL,
    country_codes NVARCHAR(4000) NULL,
    source_id     NVARCHAR(4000) NULL,
    valid_until   NVARCHAR(4000) NULL,
    note          NVARCHAR(4000) NULL
);

CREATE TABLE dbo.officers (
    node_id       BIGINT         NOT NULL PRIMARY KEY,
    name          NVARCHAR(4000) NULL,
    countries     NVARCHAR(4000) NULL,
    country_codes NVARCHAR(4000) NULL,
    source_id     NVARCHAR(4000) NULL,
    valid_until   NVARCHAR(4000) NULL,
    note          NVARCHAR(4000) NULL
);

CREATE TABLE dbo.others (
    node_id                  BIGINT         NOT NULL PRIMARY KEY,
    name                     NVARCHAR(4000) NULL,
    type                     NVARCHAR(4000) NULL,
    incorporation_date       DATE           NULL,
    struck_off_date          DATE           NULL,
    closed_date              DATE           NULL,
    jurisdiction             NVARCHAR(4000) NULL,
    jurisdiction_description NVARCHAR(4000) NULL,
    countries                NVARCHAR(4000) NULL,
    country_codes            NVARCHAR(4000) NULL,
    source_id                NVARCHAR(4000) NULL,
    valid_until              NVARCHAR(4000) NULL,
    note                     NVARCHAR(4000) NULL
);

CREATE TABLE dbo.relationships (
    node_id_start BIGINT         NOT NULL,
    node_id_end   BIGINT         NOT NULL,
    rel_type      NVARCHAR(4000) NULL,
    link          NVARCHAR(4000) NULL,
    status        NVARCHAR(4000) NULL,
    start_date    DATE           NULL,
    end_date      DATE           NULL,
    source_id     NVARCHAR(4000) NULL
);
GO

-- Load addresses, turning empty strings into NULL
INSERT INTO dbo.addresses
SELECT
    CAST(node_id AS BIGINT),
    NULLIF(LTRIM(RTRIM(address)), ''),
    NULLIF(LTRIM(RTRIM(name)), ''),
    NULLIF(LTRIM(RTRIM(countries)), ''),
    NULLIF(LTRIM(RTRIM(country_codes)), ''),
    NULLIF(LTRIM(RTRIM(sourceID)), ''),
    NULLIF(LTRIM(RTRIM(valid_until)), ''),
    NULLIF(LTRIM(RTRIM(note)), '')
FROM stg.nodes_addresses;

-- Load entities, converting date text to DATE
INSERT INTO dbo.entities
SELECT
    CAST(node_id AS BIGINT),
    NULLIF(LTRIM(RTRIM(name)), ''),
    NULLIF(LTRIM(RTRIM(original_name)), ''),
    NULLIF(LTRIM(RTRIM(former_name)), ''),
    NULLIF(LTRIM(RTRIM(jurisdiction)), ''),
    NULLIF(LTRIM(RTRIM(jurisdiction_description)), ''),
    NULLIF(LTRIM(RTRIM(company_type)), ''),
    NULLIF(LTRIM(RTRIM(address)), ''),
    NULLIF(LTRIM(RTRIM(internal_id)), ''),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(incorporation_date)), '')),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(inactivation_date)), '')),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(struck_off_date)), '')),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(dorm_date)), '')),
    NULLIF(LTRIM(RTRIM(status)), ''),
    NULLIF(LTRIM(RTRIM(service_provider)), ''),
    NULLIF(LTRIM(RTRIM(ibcRUC)), ''),
    NULLIF(LTRIM(RTRIM(country_codes)), ''),
    NULLIF(LTRIM(RTRIM(countries)), ''),
    NULLIF(LTRIM(RTRIM(sourceID)), ''),
    NULLIF(LTRIM(RTRIM(valid_until)), ''),
    NULLIF(LTRIM(RTRIM(note)), '')
FROM stg.nodes_entities;

-- Load intermediaries
INSERT INTO dbo.intermediaries
SELECT
    CAST(node_id AS BIGINT),
    NULLIF(LTRIM(RTRIM(name)), ''),
    NULLIF(LTRIM(RTRIM(status)), ''),
    NULLIF(LTRIM(RTRIM(internal_id)), ''),
    NULLIF(LTRIM(RTRIM(address)), ''),
    NULLIF(LTRIM(RTRIM(countries)), ''),
    NULLIF(LTRIM(RTRIM(country_codes)), ''),
    NULLIF(LTRIM(RTRIM(sourceID)), ''),
    NULLIF(LTRIM(RTRIM(valid_until)), ''),
    NULLIF(LTRIM(RTRIM(note)), '')
FROM stg.nodes_intermediaries;

-- Load officers
INSERT INTO dbo.officers
SELECT
    CAST(node_id AS BIGINT),
    NULLIF(LTRIM(RTRIM(name)), ''),
    NULLIF(LTRIM(RTRIM(countries)), ''),
    NULLIF(LTRIM(RTRIM(country_codes)), ''),
    NULLIF(LTRIM(RTRIM(sourceID)), ''),
    NULLIF(LTRIM(RTRIM(valid_until)), ''),
    NULLIF(LTRIM(RTRIM(note)), '')
FROM stg.nodes_officers;

-- Load others
INSERT INTO dbo.others
SELECT
    CAST(node_id AS BIGINT),
    NULLIF(LTRIM(RTRIM(name)), ''),
    NULLIF(LTRIM(RTRIM(type)), ''),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(incorporation_date)), '')),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(struck_off_date)), '')),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(closed_date)), '')),
    NULLIF(LTRIM(RTRIM(jurisdiction)), ''),
    NULLIF(LTRIM(RTRIM(jurisdiction_description)), ''),
    NULLIF(LTRIM(RTRIM(countries)), ''),
    NULLIF(LTRIM(RTRIM(country_codes)), ''),
    NULLIF(LTRIM(RTRIM(sourceID)), ''),
    NULLIF(LTRIM(RTRIM(valid_until)), ''),
    NULLIF(LTRIM(RTRIM(note)), '')
FROM stg.nodes_others;

-- Load relationships
INSERT INTO dbo.relationships
SELECT
    CAST(node_id_start AS BIGINT),
    CAST(node_id_end AS BIGINT),
    NULLIF(LTRIM(RTRIM(rel_type)), ''),
    NULLIF(LTRIM(RTRIM(link)), ''),
    NULLIF(LTRIM(RTRIM(status)), ''),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(start_date)), '')),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(end_date)), '')),
    NULLIF(LTRIM(RTRIM(sourceID)), '')
FROM stg.relationships;
GO

-- Validation 1: compare staging and typed row counts
SELECT 'addresses' AS table_name,
       (SELECT COUNT(*) FROM stg.nodes_addresses) AS staging_rows,
       (SELECT COUNT(*) FROM dbo.addresses) AS typed_rows
UNION ALL SELECT 'entities',
       (SELECT COUNT(*) FROM stg.nodes_entities), (SELECT COUNT(*) FROM dbo.entities)
UNION ALL SELECT 'intermediaries',
       (SELECT COUNT(*) FROM stg.nodes_intermediaries), (SELECT COUNT(*) FROM dbo.intermediaries)
UNION ALL SELECT 'officers',
       (SELECT COUNT(*) FROM stg.nodes_officers), (SELECT COUNT(*) FROM dbo.officers)
UNION ALL SELECT 'others',
       (SELECT COUNT(*) FROM stg.nodes_others), (SELECT COUNT(*) FROM dbo.others)
UNION ALL SELECT 'relationships',
       (SELECT COUNT(*) FROM stg.relationships), (SELECT COUNT(*) FROM dbo.relationships);

-- Validation 2: count dates that failed to convert (raw value present, typed value NULL)
SELECT 'entities.incorporation_date' AS date_column, COUNT(*) AS failed_conversions
FROM stg.nodes_entities s JOIN dbo.entities t ON t.node_id = CAST(s.node_id AS BIGINT)
WHERE NULLIF(LTRIM(RTRIM(s.incorporation_date)), '') IS NOT NULL AND t.incorporation_date IS NULL
UNION ALL
SELECT 'entities.inactivation_date', COUNT(*)
FROM stg.nodes_entities s JOIN dbo.entities t ON t.node_id = CAST(s.node_id AS BIGINT)
WHERE NULLIF(LTRIM(RTRIM(s.inactivation_date)), '') IS NOT NULL AND t.inactivation_date IS NULL
UNION ALL
SELECT 'entities.struck_off_date', COUNT(*)
FROM stg.nodes_entities s JOIN dbo.entities t ON t.node_id = CAST(s.node_id AS BIGINT)
WHERE NULLIF(LTRIM(RTRIM(s.struck_off_date)), '') IS NOT NULL AND t.struck_off_date IS NULL
UNION ALL
SELECT 'entities.dorm_date', COUNT(*)
FROM stg.nodes_entities s JOIN dbo.entities t ON t.node_id = CAST(s.node_id AS BIGINT)
WHERE NULLIF(LTRIM(RTRIM(s.dorm_date)), '') IS NOT NULL AND t.dorm_date IS NULL
UNION ALL
SELECT 'relationships.start_date', COUNT(*)
FROM stg.relationships s
WHERE NULLIF(LTRIM(RTRIM(s.start_date)), '') IS NOT NULL
  AND TRY_CONVERT(DATE, LTRIM(RTRIM(s.start_date))) IS NULL
UNION ALL
SELECT 'relationships.end_date', COUNT(*)
FROM stg.relationships s
WHERE NULLIF(LTRIM(RTRIM(s.end_date)), '') IS NOT NULL
  AND TRY_CONVERT(DATE, LTRIM(RTRIM(s.end_date))) IS NULL;

-- Validation 3: count relationship endpoints that do not exist in any node table
SELECT node_id INTO #all_nodes FROM (
    SELECT node_id FROM dbo.addresses
    UNION ALL SELECT node_id FROM dbo.entities
    UNION ALL SELECT node_id FROM dbo.intermediaries
    UNION ALL SELECT node_id FROM dbo.officers
    UNION ALL SELECT node_id FROM dbo.others
) n;
CREATE CLUSTERED INDEX ix_all_nodes ON #all_nodes (node_id);

SELECT
    SUM(CASE WHEN s.node_id IS NULL THEN 1 ELSE 0 END) AS orphan_start,
    SUM(CASE WHEN e.node_id IS NULL THEN 1 ELSE 0 END) AS orphan_end
FROM dbo.relationships r
LEFT JOIN #all_nodes s ON s.node_id = r.node_id_start
LEFT JOIN #all_nodes e ON e.node_id = r.node_id_end;

DROP TABLE #all_nodes;
GO