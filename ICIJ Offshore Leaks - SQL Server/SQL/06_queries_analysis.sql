USE ICIJ_OffshoreLeaks;
GO

-- 1) Entities with the most officer connections
SELECT TOP 10 e.name AS entity, e.jurisdiction, COUNT(*) AS officer_links
FROM gr.Officer o, gr.Rel r, gr.Entity e
WHERE MATCH(o-(r)->e)
GROUP BY e.node_id, e.name, e.jurisdiction
ORDER BY officer_links DESC;

-- 2) Intermediaries serving the most entities
-- Parties acting in both roles live in gr.Officer, so query both node tables
SELECT TOP 10 name, SUM(entities_served) AS entities_served
FROM (
    SELECT i.node_id, i.name, COUNT(*) AS entities_served
    FROM gr.Intermediary i, gr.Rel r, gr.Entity e
    WHERE MATCH(i-(r)->e) AND r.link = 'intermediary of'
    GROUP BY i.node_id, i.name
    UNION ALL
    SELECT o.node_id, o.name, COUNT(*)
    FROM gr.Officer o, gr.Rel r, gr.Entity e
    WHERE MATCH(o-(r)->e) AND r.link = 'intermediary of'
    GROUP BY o.node_id, o.name
) x
GROUP BY node_id, name
ORDER BY entities_served DESC;

-- 3) Addresses shared by the most entities (skip address nodes without text)
SELECT TOP 10 a.address, COUNT(*) AS entities_registered
FROM gr.Entity e, gr.Rel r, gr.Address a
WHERE MATCH(e-(r)->a) AND r.link = 'registered address'
  AND a.address IS NOT NULL
GROUP BY a.node_id, a.address
ORDER BY entities_registered DESC;

-- 4) Officers connected to entities in the most jurisdictions
SELECT TOP 10 o.name AS officer,
       COUNT(DISTINCT e.jurisdiction) AS jurisdictions,
       COUNT(*) AS entity_links
FROM gr.Officer o, gr.Rel r, gr.Entity e
WHERE MATCH(o-(r)->e)
GROUP BY o.node_id, o.name
ORDER BY jurisdictions DESC, entity_links DESC;

-- 5) Entities per jurisdiction and status
SELECT TOP 15 jurisdiction, status, COUNT(*) AS entities
FROM gr.Entity
GROUP BY jurisdiction, status
ORDER BY entities DESC;

-- 6) Two-hop pattern: officers sharing entities with the most connected officer
DECLARE @top_officer BIGINT = (
    SELECT TOP 1 o.node_id
    FROM gr.Officer o, gr.Rel r, gr.Entity e
    WHERE MATCH(o-(r)->e)
    GROUP BY o.node_id
    ORDER BY COUNT(*) DESC
);

SELECT TOP 20 o2.name AS co_officer, COUNT(DISTINCT e.node_id) AS shared_entities
FROM gr.Officer o1, gr.Rel r1, gr.Entity e, gr.Rel r2, gr.Officer o2
WHERE MATCH(o1-(r1)->e<-(r2)-o2)
  AND o1.node_id = @top_officer
  AND o2.node_id <> o1.node_id
GROUP BY o2.node_id, o2.name
ORDER BY shared_entities DESC;
GO