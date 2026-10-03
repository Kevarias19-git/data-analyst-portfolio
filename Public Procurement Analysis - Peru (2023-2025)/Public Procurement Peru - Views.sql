-- Vistas de agregación para Power BI
-- Ejecutar una sola vez sobre contrataciones.db (o de nuevo si se recarga la base)

DROP VIEW IF EXISTS v_top_proveedores;
CREATE VIEW v_top_proveedores AS
SELECT
    s.supplier_name,
    COUNT(DISTINCT s.award_key)    AS adjudicaciones_ganadas,
    SUM(a.award_amount)            AS monto_total,
    AVG(a.award_amount)            AS monto_promedio
FROM awa_suppliers s
JOIN awards a ON s.award_key = a.award_key
WHERE s.supplier_name IS NOT NULL
GROUP BY s.supplier_name;

DROP VIEW IF EXISTS v_top_entidades;
CREATE VIEW v_top_entidades AS
SELECT
    r.anho,
    r.procuring_entity_name,
    COUNT(DISTINCT r.ocid)         AS procesos,
    SUM(a.award_amount)            AS monto_total
FROM records r
JOIN awards a ON r.ocid = a.ocid
WHERE r.procuring_entity_name IS NOT NULL
GROUP BY r.anho, r.procuring_entity_name;

DROP VIEW IF EXISTS v_procesos_poca_competencia;
CREATE VIEW v_procesos_poca_competencia AS
SELECT
    r.ocid, r.anho, r.tender_title, r.procuring_entity_name,
    COUNT(t.tenderer_id) AS num_postores
FROM records r
JOIN ten_tenderers t ON r.ocid = t.ocid
GROUP BY r.ocid, r.anho, r.tender_title, r.procuring_entity_name
HAVING COUNT(t.tenderer_id) = 1;

DROP VIEW IF EXISTS v_resumen_anual;
CREATE VIEW v_resumen_anual AS
SELECT
    r.anho,
    COUNT(DISTINCT r.ocid)          AS total_procesos,
    SUM(r.tender_value_amount)      AS monto_referencial_total,
    SUM(a.award_amount)             AS monto_adjudicado_total,
    AVG(r.number_of_tenderers)      AS promedio_postores
FROM records r
LEFT JOIN awards a ON r.ocid = a.ocid
GROUP BY r.anho;

DROP VIEW IF EXISTS v_contratos_con_variacion;
CREATE VIEW v_contratos_con_variacion AS
SELECT
    c.contract_key, r.procuring_entity_name,
    c.contract_amount, c.final_value_amount, c.variacion_monto,
    ROUND(100.0 * c.variacion_monto / NULLIF(c.contract_amount, 0), 1) AS variacion_pct,
    c.anho
FROM contracts c
JOIN records r ON c.ocid = r.ocid
WHERE c.variacion_monto IS NOT NULL;

DROP VIEW IF EXISTS v_contratos_huerfanos;
CREATE VIEW v_contratos_huerfanos AS
SELECT c.* FROM contracts c WHERE c.award_en_awards = 0;



-- 7. Ranking de proveedores POR AÑO (no solo total histórico) usando RANK()
DROP VIEW IF EXISTS v_ranking_proveedores_anual;
CREATE VIEW v_ranking_proveedores_anual AS
WITH monto_proveedor_anio AS (
    SELECT
        s.anho,
        s.supplier_name,
        SUM(a.award_amount)            AS monto_total,
        COUNT(DISTINCT s.award_key)    AS adjudicaciones
    FROM awa_suppliers s
    JOIN awards a ON s.award_key = a.award_key
    WHERE s.supplier_name IS NOT NULL
    GROUP BY s.anho, s.supplier_name
)
SELECT
    anho, supplier_name, monto_total, adjudicaciones,
    RANK() OVER (PARTITION BY anho ORDER BY monto_total DESC) AS ranking
FROM monto_proveedor_anio;
 
 
-- 8. Concentración de mercado: % que representa cada proveedor dentro de
-- su categoría de contratación (usa SUM() OVER para el total de la partición)
DROP VIEW IF EXISTS v_concentracion_categoria;
CREATE VIEW v_concentracion_categoria AS
WITH monto_categoria_proveedor AS (
    SELECT
        r.procurement_category,
        s.supplier_name,
        SUM(a.award_amount) AS monto_proveedor
    FROM records r
    JOIN awards a ON r.ocid = a.ocid
    JOIN awa_suppliers s ON s.award_key = a.award_key
    WHERE r.procurement_category IS NOT NULL AND s.supplier_name IS NOT NULL
    GROUP BY r.procurement_category, s.supplier_name
)
SELECT
    procurement_category, supplier_name, monto_proveedor,
    ROUND(100.0 * monto_proveedor / SUM(monto_proveedor)
        OVER (PARTITION BY procurement_category), 1)  AS participacion_pct
FROM monto_categoria_proveedor;
 
 
-- 9. Distribución geográfica (región/departamento) de la entidad compradora
-- — necesaria para un mapa en Power BI
DROP VIEW IF EXISTS v_detalle_geografico;
CREATE VIEW v_detalle_geografico AS
SELECT
    p.region,
    p.department,
    r.anho,
    COUNT(DISTINCT r.ocid)  AS procesos,
    SUM(a.award_amount)     AS monto_total
FROM records r
JOIN parties p ON p.ocid = r.ocid AND p.party_id = r.procuring_entity_id
LEFT JOIN awards a ON a.ocid = r.ocid
WHERE p.region IS NOT NULL
GROUP BY p.region, p.department, r.anho;
 
 
-- 10. Procesos por categoría y método de contratación — para un treemap
-- o gráfico de barras apiladas
DROP VIEW IF EXISTS v_categoria_metodo;
CREATE VIEW v_categoria_metodo AS
SELECT
    anho, procurement_category, procurement_method,
    COUNT(DISTINCT ocid)       AS procesos,
    SUM(tender_value_amount)   AS monto_referencial
FROM records
GROUP BY anho, procurement_category, procurement_method;
 
 
-- 11. Procesos SIN adjudicación — el espejo de v_contratos_huerfanos,
-- otro hallazgo de calidad/alcance de datos para documentar
DROP VIEW IF EXISTS v_procesos_sin_adjudicacion;
CREATE VIEW v_procesos_sin_adjudicacion AS
SELECT r.ocid, r.anho, r.tender_title, r.procuring_entity_name, r.tender_value_amount
FROM records r
LEFT JOIN awards a ON r.ocid = a.ocid
WHERE a.ocid IS NULL;
 
 
-- 12. Tabla de features lista para R (clustering / detección de outliers)
-- una fila por proceso, con las variables numéricas y categóricas clave
DROP VIEW IF EXISTS v_dataset_ml;
CREATE VIEW v_dataset_ml AS
SELECT
    r.ocid, r.anho, r.procurement_category, r.procurement_method,
    r.budget_amount, r.tender_value_amount, r.number_of_tenderers, r.tender_duration_days,
    a.award_amount,
    c.contract_amount, c.final_value_amount, c.variacion_monto,
    p.region, p.department
FROM records r
LEFT JOIN awards a ON r.ocid = a.ocid
LEFT JOIN contracts c ON c.award_key = a.award_key
LEFT JOIN parties p ON p.ocid = r.ocid AND p.party_id = r.procuring_entity_id;
