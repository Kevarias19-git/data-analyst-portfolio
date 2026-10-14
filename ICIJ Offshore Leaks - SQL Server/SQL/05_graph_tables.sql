USE ICIJ_OffshoreLeaks;
GO

-- Create the graph schema if it does not exist
IF SCHEMA_ID('gr') IS NULL
    EXEC('CREATE SCHEMA gr');
GO

-- Drop the edge table first, then the node tables, to allow reruns
IF OBJECT_ID('gr.Rel', 'U')          IS NOT NULL DROP TABLE gr.Rel;
IF OBJECT_ID('gr.Entity', 'U')       IS NOT NULL DROP TABLE gr.Entity;
IF OBJECT_ID('gr.Officer', 'U')      IS NOT NULL DROP TABLE gr.Officer;
IF OBJECT_ID('gr.Intermediary', 'U') IS NOT NULL DROP TABLE gr.Intermediary;
IF OBJECT_ID('gr.Address', 'U')      IS NOT NULL DROP TABLE gr.Address;
IF OBJECT_ID('gr.Other', 'U')        IS NOT NULL DROP TABLE gr.Other;
GO

-- Create node tables
CREATE TABLE gr.Entity (
    node_id            BIGINT         NOT NULL,
    name               NVARCHAR(4000) NULL,
    jurisdiction       NVARCHAR(4000) NULL,
    company_type       NVARCHAR(4000) NULL,
    status             NVARCHAR(4000) NULL,
    incorporation_date DATE           NULL,
    struck_off_date    DATE           NULL,
    country_codes      NVARCHAR(4000) NULL,
    source_id          NVARCHAR(4000) NULL
) AS NODE;

-- Officer also holds parties that act as intermediaries (same node_id in both source files)
CREATE TABLE gr.Officer (
    node_id              BIGINT         NOT NULL,
    name                 NVARCHAR(4000) NULL,
    country_codes        NVARCHAR(4000) NULL,
    source_id            NVARCHAR(4000) NULL,
    is_also_intermediary BIT            NOT NULL
) AS NODE;

CREATE TABLE gr.Intermediary (
    node_id       BIGINT         NOT NULL,
    name          NVARCHAR(4000) NULL,
    status        NVARCHAR(4000) NULL,
    country_codes NVARCHAR(4000) NULL,
    source_id     NVARCHAR(4000) NULL
) AS NODE;

CREATE TABLE gr.Address (
    node_id       BIGINT         NOT NULL,
    address       NVARCHAR(4000) NULL,
    country_codes NVARCHAR(4000) NULL,
    source_id     NVARCHAR(4000) NULL
) AS NODE;

CREATE TABLE gr.Other (
    node_id       BIGINT         NOT NULL,
    name          NVARCHAR(4000) NULL,
    type          NVARCHAR(4000) NULL,
    jurisdiction  NVARCHAR(4000) NULL,
    country_codes NVARCHAR(4000) NULL,
    source_id     NVARCHAR(4000) NULL
) AS NODE;

-- Create the single edge table for all relationship types
CREATE TABLE gr.Rel (
    rel_type   NVARCHAR(4000) NULL,
    link       NVARCHAR(4000) NULL,
    status     NVARCHAR(4000) NULL,
    start_date DATE           NULL,
    end_date   DATE           NULL,
    source_id  NVARCHAR(4000) NULL
) AS EDGE;
GO

-- Load nodes from the typed tables
INSERT INTO gr.Entity (node_id, name, jurisdiction, company_type, status,
                       incorporation_date, struck_off_date, country_codes, source_id)
SELECT node_id, name, jurisdiction, company_type, status,
       incorporation_date, struck_off_date, country_codes, source_id
FROM dbo.entities;

-- Flag officers that also appear as intermediaries
INSERT INTO gr.Officer (node_id, name, country_codes, source_id, is_also_intermediary)
SELECT o.node_id, o.name, o.country_codes, o.source_id,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.intermediaries i WHERE i.node_id = o.node_id)
            THEN 1 ELSE 0 END
FROM dbo.officers o;

-- Skip intermediaries already loaded as officers to keep one node per identity
INSERT INTO gr.Intermediary (node_id, name, status, country_codes, source_id)
SELECT i.node_id, i.name, i.status, i.country_codes, i.source_id
FROM dbo.intermediaries i
WHERE NOT EXISTS (SELECT 1 FROM dbo.officers o WHERE o.node_id = i.node_id);

INSERT INTO gr.Address (node_id, address, country_codes, source_id)
SELECT node_id, address, country_codes, source_id
FROM dbo.addresses;

INSERT INTO gr.Other (node_id, name, type, jurisdiction, country_codes, source_id)
SELECT node_id, name, type, jurisdiction, country_codes, source_id
FROM dbo.others;
GO

-- Drop a leftover map from a previous failed run
IF OBJECT_ID('tempdb..#node_map') IS NOT NULL DROP TABLE #node_map;

-- Map each original node_id to its internal graph $node_id (now one row per node_id)
SELECT node_id, graph_id INTO #node_map FROM (
    SELECT node_id, $node_id AS graph_id FROM gr.Entity
    UNION ALL SELECT node_id, $node_id FROM gr.Officer
    UNION ALL SELECT node_id, $node_id FROM gr.Intermediary
    UNION ALL SELECT node_id, $node_id FROM gr.Address
    UNION ALL SELECT node_id, $node_id FROM gr.Other
) m;
CREATE UNIQUE CLUSTERED INDEX ix_node_map ON #node_map (node_id);

-- Load edges, translating both endpoints through the map
INSERT INTO gr.Rel ($from_id, $to_id, rel_type, link, status, start_date, end_date, source_id)
SELECT s.graph_id, e.graph_id,
       r.rel_type, r.link, r.status, r.start_date, r.end_date, r.source_id
FROM dbo.relationships r
JOIN #node_map s ON s.node_id = r.node_id_start
JOIN #node_map e ON e.node_id = r.node_id_end;

DROP TABLE #node_map;
GO

-- Create indexes to speed up graph traversals
CREATE INDEX ix_rel_from_to ON gr.Rel ($from_id, $to_id);
CREATE INDEX ix_rel_to_from ON gr.Rel ($to_id, $from_id);
CREATE UNIQUE INDEX ux_entity_node_id       ON gr.Entity (node_id);
CREATE UNIQUE INDEX ux_officer_node_id      ON gr.Officer (node_id);
CREATE UNIQUE INDEX ux_intermediary_node_id ON gr.Intermediary (node_id);
CREATE UNIQUE INDEX ux_address_node_id      ON gr.Address (node_id);
CREATE UNIQUE INDEX ux_other_node_id        ON gr.Other (node_id);
GO

-- Validation 1: compare graph rows with the expected rows from the typed tables
SELECT 'Entity' AS graph_table, COUNT(*) AS graph_rows,
       (SELECT COUNT(*) FROM dbo.entities) AS expected_rows FROM gr.Entity
UNION ALL SELECT 'Officer', COUNT(*), (SELECT COUNT(*) FROM dbo.officers) FROM gr.Officer
UNION ALL SELECT 'Intermediary', COUNT(*),
       (SELECT COUNT(*) FROM dbo.intermediaries)
     - (SELECT COUNT(*) FROM dbo.intermediaries i
        WHERE EXISTS (SELECT 1 FROM dbo.officers o WHERE o.node_id = i.node_id))
FROM gr.Intermediary
UNION ALL SELECT 'Address', COUNT(*), (SELECT COUNT(*) FROM dbo.addresses) FROM gr.Address
UNION ALL SELECT 'Other', COUNT(*), (SELECT COUNT(*) FROM dbo.others) FROM gr.Other
UNION ALL SELECT 'Rel (edges)', COUNT(*), (SELECT COUNT(*) FROM dbo.relationships) FROM gr.Rel;

-- Validation 2: count officers flagged as also intermediaries
SELECT COUNT(*) AS officers_also_intermediaries
FROM gr.Officer
WHERE is_also_intermediary = 1;

-- Validation 3: smoke test of a graph pattern (officer -> entity)
SELECT TOP 10 o.name AS officer, r.link, e.name AS entity
FROM gr.Officer o, gr.Rel r, gr.Entity e
WHERE MATCH(o-(r)->e);

-- Validation 4: most frequent relationship links
SELECT TOP 10 link, COUNT(*) AS edges
FROM gr.Rel
GROUP BY link
ORDER BY edges DESC;

-- Validation 5: check database size
EXEC sp_spaceused;
GO
