USE ICIJ_OffshoreLeaks;
GO

-- Create the staging schema if it does not exist
IF SCHEMA_ID('stg') IS NULL
    EXEC('CREATE SCHEMA stg');
GO

-- Store all columns as text, assign real types in the typed model
IF OBJECT_ID('stg.nodes_addresses', 'U') IS NOT NULL DROP TABLE stg.nodes_addresses;
CREATE TABLE stg.nodes_addresses (
    node_id NVARCHAR(MAX), address NVARCHAR(MAX), name NVARCHAR(MAX),
    countries NVARCHAR(MAX), country_codes NVARCHAR(MAX), sourceID NVARCHAR(MAX),
    valid_until NVARCHAR(MAX), note NVARCHAR(MAX)
);

IF OBJECT_ID('stg.nodes_entities', 'U') IS NOT NULL DROP TABLE stg.nodes_entities;
CREATE TABLE stg.nodes_entities (
    node_id NVARCHAR(MAX), name NVARCHAR(MAX), original_name NVARCHAR(MAX),
    former_name NVARCHAR(MAX), jurisdiction NVARCHAR(MAX), jurisdiction_description NVARCHAR(MAX),
    company_type NVARCHAR(MAX), address NVARCHAR(MAX), internal_id NVARCHAR(MAX),
    incorporation_date NVARCHAR(MAX), inactivation_date NVARCHAR(MAX), struck_off_date NVARCHAR(MAX),
    dorm_date NVARCHAR(MAX), status NVARCHAR(MAX), service_provider NVARCHAR(MAX),
    ibcRUC NVARCHAR(MAX), country_codes NVARCHAR(MAX), countries NVARCHAR(MAX),
    sourceID NVARCHAR(MAX), valid_until NVARCHAR(MAX), note NVARCHAR(MAX)
);

IF OBJECT_ID('stg.nodes_intermediaries', 'U') IS NOT NULL DROP TABLE stg.nodes_intermediaries;
CREATE TABLE stg.nodes_intermediaries (
    node_id NVARCHAR(MAX), name NVARCHAR(MAX), status NVARCHAR(MAX),
    internal_id NVARCHAR(MAX), address NVARCHAR(MAX), countries NVARCHAR(MAX),
    country_codes NVARCHAR(MAX), sourceID NVARCHAR(MAX), valid_until NVARCHAR(MAX),
    note NVARCHAR(MAX)
);

IF OBJECT_ID('stg.nodes_officers', 'U') IS NOT NULL DROP TABLE stg.nodes_officers;
CREATE TABLE stg.nodes_officers (
    node_id NVARCHAR(MAX), name NVARCHAR(MAX), countries NVARCHAR(MAX),
    country_codes NVARCHAR(MAX), sourceID NVARCHAR(MAX), valid_until NVARCHAR(MAX),
    note NVARCHAR(MAX)
);

IF OBJECT_ID('stg.nodes_others', 'U') IS NOT NULL DROP TABLE stg.nodes_others;
CREATE TABLE stg.nodes_others (
    node_id NVARCHAR(MAX), name NVARCHAR(MAX), type NVARCHAR(MAX),
    incorporation_date NVARCHAR(MAX), struck_off_date NVARCHAR(MAX), closed_date NVARCHAR(MAX),
    jurisdiction NVARCHAR(MAX), jurisdiction_description NVARCHAR(MAX), countries NVARCHAR(MAX),
    country_codes NVARCHAR(MAX), sourceID NVARCHAR(MAX), valid_until NVARCHAR(MAX),
    note NVARCHAR(MAX)
);

IF OBJECT_ID('stg.relationships', 'U') IS NOT NULL DROP TABLE stg.relationships;
CREATE TABLE stg.relationships (
    node_id_start NVARCHAR(MAX), node_id_end NVARCHAR(MAX), rel_type NVARCHAR(MAX),
    link NVARCHAR(MAX), status NVARCHAR(MAX), start_date NVARCHAR(MAX),
    end_date NVARCHAR(MAX), sourceID NVARCHAR(MAX)
);
GO