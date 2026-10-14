USE ICIJ_OffshoreLeaks;
GO

-- Empty the staging tables to allow reruns
TRUNCATE TABLE stg.nodes_addresses;
TRUNCATE TABLE stg.nodes_entities;
TRUNCATE TABLE stg.nodes_intermediaries;
TRUNCATE TABLE stg.nodes_officers;
TRUNCATE TABLE stg.nodes_others;
TRUNCATE TABLE stg.relationships;
GO

-- Load each CSV, skip the header, read as UTF-8, rows end with LF
BULK INSERT stg.nodes_addresses
FROM 'F:\data-analyst-portfolio\ICIJ Offshore Leaks - SQL Server\Data\Raw\nodes-addresses.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.nodes_entities
FROM 'F:\data-analyst-portfolio\ICIJ Offshore Leaks - SQL Server\Data\Raw\nodes-entities.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.nodes_intermediaries
FROM 'F:\data-analyst-portfolio\ICIJ Offshore Leaks - SQL Server\Data\Raw\nodes-intermediaries.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.nodes_officers
FROM 'F:\data-analyst-portfolio\ICIJ Offshore Leaks - SQL Server\Data\Raw\nodes-officers.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.nodes_others
FROM 'F:\data-analyst-portfolio\ICIJ Offshore Leaks - SQL Server\Data\Raw\nodes-others.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT stg.relationships
FROM 'F:\data-analyst-portfolio\ICIJ Offshore Leaks - SQL Server\Data\Raw\relationships.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
GO

-- Check loaded row counts
SELECT 'nodes_addresses' AS table_name, COUNT(*) AS row_count FROM stg.nodes_addresses
UNION ALL SELECT 'nodes_entities', COUNT(*) FROM stg.nodes_entities
UNION ALL SELECT 'nodes_intermediaries', COUNT(*) FROM stg.nodes_intermediaries
UNION ALL SELECT 'nodes_officers', COUNT(*) FROM stg.nodes_officers
UNION ALL SELECT 'nodes_others', COUNT(*) FROM stg.nodes_others
UNION ALL SELECT 'relationships', COUNT(*) FROM stg.relationships;