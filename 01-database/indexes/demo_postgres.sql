-- INDEX DEMO ON POSTGRESQL (11 or later)
-- Scenario: a national population database. One table, `users`; each row is one citizen.
-- How to read EXPLAIN:
--   "Seq Scan"                    -> full table scan (no index used)
--   anything containing "Index"   -> an index is used (Index Scan, Index Only Scan, Bitmap Index Scan)
-- EXPLAIN only shows the PLANNED execution (estimates); it does NOT run the query.
-- EXPLAIN ANALYZE actually RUNS the query and adds real row counts and timings.
--   Careful: with INSERT / UPDATE / DELETE it really changes data (wrap it in BEGIN ... ROLLBACK).


-- ===================== SETUP =====================
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id                serial PRIMARY KEY,
    national_id       text NOT NULL,              -- national ID number
    full_name         text NOT NULL,
    gender            text NOT NULL,              -- 'M' or 'F'
    birth_date        date NOT NULL,
    status            text NOT NULL,              -- 'alive' or 'dead'
    death_date        date,                       -- NULL while the person is alive
    province          text NOT NULL,              -- province (63 provinces)
    household_head_id int REFERENCES users(id),   -- head of household (foreign key; PostgreSQL does NOT index it automatically)
    bio               text,                       -- free-text description of the citizen
    skills            text[],                     -- array of skills
    home_location     point                       -- home coordinates
);

-- Generate 100,000 citizens, 30% of them dead
INSERT INTO users (national_id, full_name, gender, birth_date, status, death_date, province, bio, skills, home_location)
SELECT lpad(g::text, 12, '0'),
       'Nguyen Van ' || g,
       CASE WHEN g % 2 = 0 THEN 'M' ELSE 'F' END,
       DATE '1950-01-01' + g % 27000,
       CASE WHEN g % 10 < 3 THEN 'dead' ELSE 'alive' END,
       CASE WHEN g % 10 < 3 THEN DATE '2023-01-01' + g % 365 END,
       'province_' || lpad((g % 63 + 1)::text, 2, '0'),
       CASE g % 4 WHEN 0 THEN 'Loves database design and clean code'
                  WHEN 1 THEN 'Design lead who also knows database tuning'
                  WHEN 2 THEN 'Enjoys cooking and travel'
                  ELSE        'Farmer and part-time driver' END,
       CASE WHEN g % 2 = 0 THEN ARRAY['sql','java'] ELSE ARRAY['farming','driving'] END,
       point(g % 100, g % 100)
FROM generate_series(1, 100000) g;

UPDATE users SET household_head_id = id / 10 WHERE id > 10;
ANALYZE users;   -- refresh table statistics so the planner makes good decisions


-- ===================== SLIDE 4: TYPES OF INDEX =====================

-- 1. B-tree (the default index type)
CREATE INDEX idx_users_province   ON users (province);
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';                                   -- equality: all citizens of one province (many duplicate values)
EXPLAIN SELECT * FROM users WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';   -- range: people born in 1990
EXPLAIN SELECT * FROM users ORDER BY birth_date LIMIT 10;                                     -- sort: the 10 oldest people; the index is already ordered, so no extra sorting is needed

CREATE INDEX idx_users_name ON users (full_name text_pattern_ops);   -- text_pattern_ops lets LIKE 'abc%' use a B-tree index when the database collation is not "C"
EXPLAIN SELECT * FROM users WHERE full_name LIKE 'Nguyen Van 500%';   -- prefix match: the index IS used
EXPLAIN SELECT * FROM users WHERE full_name LIKE '%500';              -- leading wildcard: the index cannot be used, so Seq Scan

-- 2. Unique (a B-tree that also rejects duplicate values)
CREATE UNIQUE INDEX idx_users_national_id ON users (national_id);     -- OK: no duplicate national IDs exist yet
INSERT INTO users (national_id, full_name, gender, birth_date, status, province)
VALUES ('000000000001', 'Test', 'M', '2000-01-01', 'alive', 'province_01');   -- ERROR (expected): duplicate national ID, the unique index blocks it
CREATE UNIQUE INDEX idx_users_province_unique ON users (province);            -- ERROR (expected): `province` already has duplicate values, so the index cannot be created

-- 3. Composite (several columns, leftmost-prefix rule)
CREATE INDEX idx_users_province_birth ON users (province, birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';                                   -- uses the index (leading column only)
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND birth_date >= '1990-01-01';    -- uses the index (both columns)
EXPLAIN SELECT * FROM users WHERE birth_date >= '1990-01-01' AND gender = 'F';                -- leading column `province` is missing: the composite index is NOT used

-- 3 columns: index (a, b, c) = (province, status, gender)
CREATE INDEX idx_users_abc ON users (province, status, gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- uses the index (a, b, c)
EXPLAIN SELECT * FROM users WHERE status = 'alive';                                                 -- `b` alone: usually NOT used; PostgreSQL 18+ may use a skip scan because `province` has few distinct values
EXPLAIN SELECT * FROM users WHERE gender = 'F';                                                     -- `c` alone: usually NOT used (PostgreSQL 18+ may also skip scan here)
DROP INDEX idx_users_abc;                                                                           -- drop it so the next sections start clean

-- 4. Partial: a working person must be alive, so index only the people who are alive
CREATE INDEX idx_users_alive ON users (province, birth_date) WHERE status = 'alive';
EXPLAIN SELECT * FROM users
WHERE status = 'alive' AND province = 'province_01' AND birth_date BETWEEN '1996-01-01' AND '2001-12-31';   -- the query repeats the index condition (status = 'alive'), so the partial index can be used
SELECT pg_size_pretty(pg_relation_size('idx_users_alive'))          AS partial_size,
       pg_size_pretty(pg_relation_size('idx_users_province_birth')) AS full_size;    -- the partial index is smaller

-- 5. Full-text: search inside `bio` (GIN)
CREATE INDEX idx_users_bio ON users USING gin (to_tsvector('english', bio));
SELECT count(*) FROM users WHERE to_tsvector('english', bio) @@ plainto_tsquery('english', 'database design');    -- case 1: both words must appear, but not necessarily next to each other
SELECT count(*) FROM users WHERE to_tsvector('english', bio) @@ phraseto_tsquery('english', 'database design');   -- case 2: the exact phrase, words next to each other

-- GIN for arrays and GiST for geometric data
CREATE INDEX idx_users_skills ON users USING gin (skills);
EXPLAIN SELECT * FROM users WHERE skills @> ARRAY['sql'];                  -- people whose skills array contains 'sql'

CREATE INDEX idx_users_location ON users USING gist (home_location);
EXPLAIN SELECT * FROM users WHERE home_location <@ box '((0,0),(5,5))';    -- people living inside a rectangular area

-- 6. Covering (INCLUDE)
CREATE INDEX idx_users_province_cover ON users (province) INCLUDE (full_name);
VACUUM ANALYZE users;   -- builds the visibility map, which Index Only Scan needs
EXPLAIN SELECT province, full_name FROM users WHERE province = 'province_01';   -- Index Only Scan: the table is not read

-- 7. Clustered / 8. Non-clustered
-- Every CREATE INDEX above creates a non-clustered index.
-- PostgreSQL has no self-maintaining clustered index; the CLUSTER command only reorders the table once.


-- ===================== SLIDE 5: 7 COMMON INDEXING MISTAKES =====================
-- Remove the indexes from the previous section so each mistake starts from a clean state.
DROP INDEX idx_users_province, idx_users_birth_date, idx_users_name, idx_users_national_id,
           idx_users_province_birth, idx_users_alive, idx_users_bio, idx_users_skills,
           idx_users_location, idx_users_province_cover;

-- Mistake 1: several single-column indexes instead of one composite index
CREATE INDEX idx_users_province ON users (province);
CREATE INDEX idx_users_status   ON users (status);
CREATE INDEX idx_users_gender   ON users (gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- PostgreSQL has to combine several indexes (BitmapAnd), which costs extra work

DROP INDEX idx_users_province, idx_users_status, idx_users_gender;
CREATE INDEX idx_users_province_status_gender ON users (province, status, gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- fix: a single composite index is enough

-- Mistake 2: wrong column order in a composite index
DROP INDEX idx_users_province_status_gender;
CREATE INDEX idx_users_birth_province ON users (birth_date, province);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';    -- leading column `birth_date` is missing: the index is not used effectively

CREATE INDEX idx_users_province_birth ON users (province, birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';    -- fix: `province` is now the leading column, so the index is used

-- Mistake 3: wrapping an indexed column in a function (count people born in 1990)
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT count(*) FROM users WHERE EXTRACT(YEAR FROM birth_date) = 1990;                       -- the function hides the column: Seq Scan

EXPLAIN SELECT count(*) FROM users WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';   -- fix 1: rewrite the condition as a range

CREATE INDEX idx_users_birth_year ON users ((EXTRACT(YEAR FROM birth_date)));                        -- fix 2: expression index
EXPLAIN SELECT count(*) FROM users WHERE EXTRACT(YEAR FROM birth_date) = 1990;                       -- the expression matches the index exactly, so it is used

-- Mistake 4: too many indexes slow down writes
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes WHERE relname = 'users';    -- every index takes extra disk space, and every INSERT / UPDATE / DELETE has to maintain ALL of them

-- Mistake 5: foreign key without an index (PostgreSQL does not create one automatically)
EXPLAIN SELECT * FROM users WHERE household_head_id = 5;    -- Seq Scan (find the members of one household)
CREATE INDEX idx_users_household_head ON users (household_head_id);
EXPLAIN SELECT * FROM users WHERE household_head_id = 5;    -- fix: the index is used

-- Mistake 6: ignoring NULLs, use a partial index instead (70% of people are alive, so death_date is NULL for most rows)
CREATE INDEX idx_users_death_full    ON users (death_date);                                  -- stores every row, including all the NULLs
CREATE INDEX idx_users_death_partial ON users (death_date) WHERE death_date IS NOT NULL;     -- skips the NULL rows
SELECT pg_size_pretty(pg_relation_size('idx_users_death_full'))    AS full_size,
       pg_size_pretty(pg_relation_size('idx_users_death_partial')) AS partial_size;          -- compare the sizes: the partial index is much smaller

-- Mistake 7: never checking whether an index is actually used
SELECT indexrelname, idx_scan AS times_used
FROM pg_stat_user_indexes WHERE relname = 'users' ORDER BY idx_scan;   -- idx_scan = 0 means the index has never been used (candidate to drop)


-- ===================== SLIDE 6: HOW DO I KNOW AN INDEX IS USED? =====================
-- Look up a citizen by national ID.
-- EXPLAIN ANALYZE is used here to show real timings; plain EXPLAIN is enough just to see whether an index is used.
EXPLAIN ANALYZE SELECT * FROM users WHERE national_id = '000000050000';
-- No index yet: Seq Scan, execution time of a few tens of milliseconds

CREATE INDEX idx_users_national_id ON users (national_id);
EXPLAIN ANALYZE SELECT * FROM users WHERE national_id = '000000050000';
-- With the index: Index Scan, execution time under 1 ms
