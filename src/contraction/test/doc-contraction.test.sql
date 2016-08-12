\echo -- q1
ALTER TABLE edge_table ADD contracted_vertices BIGINT[];
ALTER TABLE edge_table_vertices_pgr ADD contracted_vertices BIGINT[];
ALTER TABLE edge_table ADD is_contracted BOOLEAN DEFAULT false;
ALTER TABLE edge_table_vertices_pgr ADD is_contracted BOOLEAN DEFAULT false;

\echo -- q2
-- showing original results
SELECT * FROM pgr_contractGraph(
    'SELECT id, source, target, cost, reverse_cost FROM edge_table',
    array[1,2], directed:=true);

\echo -- q3
-- saving into a temporary table
SELECT * INTO contraction_results
FROM pgr_contractGraph(
    'SELECT id, source, target, cost, reverse_cost FROM edge_table',
    array[1,2], directed:=true);

\echo -- q4
-- indicate the vertices that are contracted
UPDATE edge_table_vertices_pgr
SET is_contracted = true
WHERE id IN (SELECT  unnest(contracted_vertices) FROM  contraction_results);

\echo -- q5
-- verify visually the update
SELECT id, is_contracted
FROM edge_table_vertices_pgr
ORDER BY id;

\echo -- q6
-- add to the vertices table the contracted vertices
UPDATE edge_table_vertices_pgr
SET contracted_vertices = contraction_results.contracted_vertices
FROM contraction_results
WHERE type = 'v' AND edge_table_vertices_pgr.id = contraction_results.id;

\echo -- q7
-- verify visually the update
SELECT id, contracted_vertices, is_contracted 
FROM edge_table_vertices_pgr
ORDER BY id;

\echo -- q8
-- add to the edges table the contracted vertices
INSERT INTO edge_table(source, target, cost, reverse_cost, contracted_vertices, is_contracted)
SELECT source, target, cost, -1, contracted_vertices, true
FROM contraction_results
WHERE type = 'e';

\echo -- q9
-- verify visually the Insert
SELECT id, source, target, cost, reverse_cost, contracted_vertices, is_contracted 
FROM edge_table
ORDER BY id;

\echo -- q10
-- vertices that belong to the contracted graph are the non contracted vertices 
SELECT id  FROM edge_table_vertices_pgr
WHERE is_contracted = false
ORDER BY id;

\echo -- case1
-- Both source and target belong to the contracted graph.
SELECT * FROM pgr_dijkstra(
    $$
    WITH
    vertices_in_graph AS (
        SELECT id  FROM edge_table_vertices_pgr WHERE is_contracted = false)
    SELECT id, source, target, cost, reverse_cost 
    FROM edge_table 
    WHERE source IN (SELECT * FROM vertices_in_graph)
    AND target IN (SELECT * FROM vertices_in_graph)
    $$,
    3, 11, false);


\echo -- case2
-- Source belongs to a contracted graph, while target belongs to a vertex subgraph.
SELECT * FROM pgr_dijkstra(
    $$
    WITH
    expand_edges AS (SELECT id, unnest(contracted_vertices) AS vertex FROM edge_table),
    expand1 AS (SELECT contracted_vertices FROM edge_table
        WHERE id IN (SELECT id FROM expand_edges WHERE vertex = 1)),
    vertices_in_graph AS (
        SELECT id  FROM edge_table_vertices_pgr WHERE is_contracted = false
        UNION
        SELECT unnest(contracted_vertices) FROM expand1)
    SELECT id, source, target, cost, reverse_cost
    FROM edge_table
    WHERE source IN (SELECT * FROM vertices_in_graph)
    AND target IN (SELECT * FROM vertices_in_graph)
    $$,
    3, 1, false);

\echo -- case3
-- Source belongs to a contracted graph, while target belongs to an edge subgraph.
SELECT * FROM pgr_dijkstra(
    $$
    WITH

    expand_vertices AS (SELECT id, unnest(contracted_vertices) AS vertex FROM edge_table_vertices_pgr),
    expand7 AS (SELECT contracted_vertices FROM edge_table_vertices_pgr
        WHERE id IN (SELECT id FROM expand_vertices WHERE vertex = 7)),

    expand_edges AS (SELECT id, unnest(contracted_vertices) AS vertex FROM edge_table),
    expand13 AS (SELECT contracted_vertices FROM edge_table
        WHERE id IN (SELECT id FROM expand_edges WHERE vertex = 13)),

    vertices_in_graph AS (
        SELECT id  FROM edge_table_vertices_pgr WHERE is_contracted = false
        UNION
        SELECT unnest(contracted_vertices) FROM expand13
        UNION
        SELECT unnest(contracted_vertices) FROM expand7)

    SELECT id, source, target, cost, reverse_cost
    FROM edge_table
    WHERE source IN (SELECT * FROM vertices_in_graph)
    AND target IN (SELECT * FROM vertices_in_graph)
    $$,
    7, 13, false);

\echo -- case4
-- Source belongs to a vertex subgraph, while target belongs to an edge subgraph.

SELECT * FROM  pgr_dijkstra(
    $$
    WITH
    expand_vertices AS (SELECT id, unnest(contracted_vertices) AS vertex FROM edge_table_vertices_pgr),
    expand7 AS (SELECT contracted_vertices FROM edge_table_vertices_pgr
        WHERE id IN (SELECT id FROM expand_vertices WHERE vertex = 7)),
    vertices_in_graph AS (
        SELECT id  FROM edge_table_vertices_pgr WHERE is_contracted = false
        UNION
        SELECT unnest(contracted_vertices) FROM expand7)
    SELECT id, source, target, cost, reverse_cost
    FROM edge_table
    WHERE source IN (SELECT * FROM vertices_in_graph)
    AND target IN (SELECT * FROM vertices_in_graph)
    $$,
    3, 7, false);

-- case5 The path contains a new edge added by the contraction algorithm. (from case 4)

\echo -- case5q1
-- Edges that need expansion and the vertices to be expanded.
WITH
first_dijkstra AS (
    SELECT * FROM  pgr_dijkstra(
        $$
        WITH
        expand_vertices AS (SELECT id, unnest(contracted_vertices) AS vertex FROM edge_table_vertices_pgr),
        expand7 AS (SELECT contracted_vertices FROM edge_table_vertices_pgr
            WHERE id IN (SELECT id FROM expand_vertices WHERE vertex = 7)),
        vertices_in_graph AS (
            SELECT id  FROM edge_table_vertices_pgr WHERE is_contracted = false
            UNION
            SELECT unnest(contracted_vertices) FROM expand7)
        SELECT id, source, target, cost, reverse_cost
        FROM edge_table
        WHERE source IN (SELECT * FROM vertices_in_graph)
        AND target IN (SELECT * FROM vertices_in_graph)
        $$,
        3, 7, false))

SELECT edge, contracted_vertices
    FROM first_dijkstra JOIN edge_table
    ON (edge = id)
    WHERE is_contracted = true;

\echo -- case5q2 

SELECT * FROM pgr_dijkstra($$
    WITH
    -- This returns the results from case 2
    first_dijkstra AS (
        SELECT * FROM  pgr_dijkstra(
            '
            WITH
            expand_vertices AS (SELECT id, unnest(contracted_vertices) AS vertex FROM edge_table_vertices_pgr),
            expand7 AS (SELECT contracted_vertices FROM edge_table_vertices_pgr
                WHERE id IN (SELECT id FROM expand_vertices WHERE vertex = 7)),
            vertices_in_graph AS (
                SELECT id  FROM edge_table_vertices_pgr WHERE is_contracted = false
                UNION
                SELECT unnest(contracted_vertices) FROM expand7)
            SELECT id, source, target, cost, reverse_cost
            FROM edge_table
            WHERE source IN (SELECT * FROM vertices_in_graph)
            AND target IN (SELECT * FROM vertices_in_graph)
            ',
            3, 7, false)),

    -- edges that need expansion and the vertices to be expanded.
    edges_to_expand AS (
        SELECT edge, contracted_vertices
        FROM first_dijkstra JOIN edge_table
        ON (edge = id)
        WHERE is_contracted = true),

    vertices_in_graph AS (
        -- the nodes of the contracted solution
        SELECT node FROM first_dijkstra
        UNION
        -- the nodes of the expanding sections
        SELECT unnest(contracted_vertices) FROM edges_to_expand)

    SELECT id, source, target, cost, reverse_cost
    FROM edge_table
    WHERE source IN (SELECT * FROM vertices_in_graph)
    AND target IN (SELECT * FROM vertices_in_graph)
    -- not including the expanded edges
    AND id NOT IN (SELECT edge FROM edges_to_expand)
    $$,
    3, 7, false);

\echo -- end