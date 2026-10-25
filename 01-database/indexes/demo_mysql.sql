-- INDEX DEMO ON MYSQL (8.0.18 or later)
-- Scenario: a national population database. One table, `users`; each row is one citizen.
-- How to read EXPLAIN:
--   type = ALL      -> full table scan (no index used)
--   type = ref/range-> an index is used
--   key             -> the index the optimizer chose
--   Extra = "Using index" -> covering index (the table itself is not read)
-- EXPLAIN only shows the PLANNED execution; it does NOT run the query.
-- EXPLAIN ANALYZE actually RUNS the query and adds real row counts and timings (MySQL 8.0.18+).
-- To start over, run the SETUP section again.


-- ===================== SETUP =====================
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    national_id       VARCHAR(12) NOT NULL,              -- national ID number
    full_name         VARCHAR(100) NOT NULL,
    gender            CHAR(1) NOT NULL,                  -- 'M' or 'F'
    birth_date        DATE NOT NULL,
    status            ENUM('alive', 'dead') NOT NULL,
    death_date        DATE NULL,                         -- NULL while the person is alive
    province          VARCHAR(20) NOT NULL,              -- province (63 provinces)
    household_head_id INT NULL,                          -- head of household (foreign key)
    bio               TEXT,                              -- free-text description of the citizen
    CONSTRAINT fk_users_head FOREIGN KEY (household_head_id) REFERENCES users(id)   -- InnoDB automatically creates an index for this column
);

SET SESSION cte_max_recursion_depth = 200000;

-- Generate 100,000 citizens, 30% of them dead
INSERT INTO users (national_id, full_name, gender, birth_date, status, death_date, province, bio)
WITH RECURSIVE seq AS (SELECT 1 AS g UNION ALL SELECT g + 1 FROM seq WHERE g < 100000)
SELECT LPAD(g, 12, '0'),
       CONCAT('Nguyen Van ', g),
       IF(g % 2 = 0, 'M', 'F'),
       DATE_ADD('1950-01-01', INTERVAL g % 27000 DAY),
       IF(g % 10 < 3, 'dead', 'alive'),
       IF(g % 10 < 3, DATE_ADD('2023-01-01', INTERVAL g % 365 DAY), NULL),
       CONCAT('province_', LPAD(g % 63 + 1, 2, '0')),
       ELT(g % 4 + 1, 'Design lead who also knows database tuning',
                      'Enjoys cooking and travel',
                      'Farmer and part-time driver',
                      'Loves database design and clean code')
FROM seq;

UPDATE users SET household_head_id = id DIV 10 WHERE id > 10;
ANALYZE TABLE users;   -- refresh table statistics so the optimizer makes good decisions


-- ===================== SLIDE 4: TYPES OF INDEX =====================

-- 1. B-tree (the default index type)
CREATE INDEX idx_users_province   ON users (province);
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';                                   -- equality: all citizens of one province (many duplicate values)
EXPLAIN SELECT * FROM users WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';   -- range: people born in 1990
EXPLAIN SELECT * FROM users ORDER BY birth_date LIMIT 10;                                     -- sort: the 10 oldest people; the index is already ordered, so no extra sorting is needed

CREATE INDEX idx_users_name ON users (full_name);
EXPLAIN SELECT * FROM users WHERE full_name LIKE 'Nguyen Van 500%';   -- prefix match: the index IS used
EXPLAIN SELECT * FROM users WHERE full_name LIKE '%500';              -- leading wildcard: the index cannot be used, so type = ALL

-- 2. Unique (a B-tree that also rejects duplicate values)
CREATE UNIQUE INDEX idx_users_national_id ON users (national_id);     -- OK: no duplicate national IDs exist yet
INSERT INTO users (national_id, full_name, gender, birth_date, status, province)
VALUES ('000000000001', 'Test', 'M', '2000-01-01', 'alive', 'province_01');   -- ERROR (expected): duplicate national ID, the unique index blocks it
CREATE UNIQUE INDEX idx_users_province_unique ON users (province);            -- ERROR (expected): `province` already has duplicate values, so the index cannot be created

-- 3. Composite (several columns, leftmost-prefix rule)
CREATE INDEX idx_users_province_birth ON users (province, birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';                                   -- uses the index (leading column only)
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND birth_date >= '1990-01-01';    -- uses the index (both columns)
EXPLAIN SELECT * FROM users WHERE birth_date >= '1990-01-01' AND gender = 'F';                -- leading column `province` is missing: idx_users_province_birth is NOT used

-- 3 columns: index (a, b, c) = (province, status, gender)
CREATE INDEX idx_users_abc ON users (province, status, gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- uses the index (a, b, c)
EXPLAIN SELECT * FROM users WHERE status = 'alive';                                                 -- `b` alone: NOT used
EXPLAIN SELECT * FROM users WHERE gender = 'F';                                                     -- `c` alone: NOT used
DROP INDEX idx_users_abc ON users;                                                                  -- drop it so the next sections start clean

-- 4. Partial
-- MySQL does NOT support partial indexes (CREATE INDEX has no WHERE clause). See demo_postgres.sql.

-- 5. Full-text: search inside `bio`
CREATE FULLTEXT INDEX idx_users_bio ON users (bio);
SELECT COUNT(*) FROM users WHERE MATCH(bio) AGAINST('database design');                      -- case 1: natural language mode, rows with at least one of the words (OR), words need not be next to each other
SELECT COUNT(*) FROM users WHERE MATCH(bio) AGAINST('"database design"' IN BOOLEAN MODE);    -- case 2: the exact phrase, words next to each other

-- GIN / GiST exist only in PostgreSQL. See demo_postgres.sql.

-- 6. Covering (MySQL has no INCLUDE clause: put every column the query needs into the index itself)
CREATE INDEX idx_users_province_name ON users (province, full_name);
EXPLAIN SELECT province, full_name FROM users WHERE province = 'province_01';   -- Extra: Using index (the table is not read)

-- 7. Clustered / 8. Non-clustered
-- InnoDB: the primary key IS the clustered index (it defines the physical row order), and a table has only one.
-- Every other CREATE INDEX creates a non-clustered index (called a "secondary index" in MySQL).
SHOW INDEX FROM users;


-- ===================== SLIDE 5: 7 COMMON INDEXING MISTAKES =====================
-- Remove the indexes from the previous section so each mistake starts from a clean state.
DROP INDEX idx_users_province ON users;
DROP INDEX idx_users_birth_date ON users;
DROP INDEX idx_users_name ON users;
DROP INDEX idx_users_national_id ON users;
DROP INDEX idx_users_province_birth ON users;
DROP INDEX idx_users_bio ON users;
DROP INDEX idx_users_province_name ON users;

-- Mistake 1: several single-column indexes instead of one composite index
CREATE INDEX idx_users_province ON users (province);
CREATE INDEX idx_users_status   ON users (status);
CREATE INDEX idx_users_gender   ON users (gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- MySQL picks only one index; the other conditions are filtered afterwards

DROP INDEX idx_users_province ON users;
DROP INDEX idx_users_status ON users;
DROP INDEX idx_users_gender ON users;
CREATE INDEX idx_users_province_status_gender ON users (province, status, gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- fix: all three columns are used from a single index

-- Mistake 2: wrong column order in a composite index
DROP INDEX idx_users_province_status_gender ON users;
CREATE INDEX idx_users_birth_province ON users (birth_date, province);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';    -- leading column `birth_date` is missing: this index is NOT used

CREATE INDEX idx_users_province_birth ON users (province, birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';    -- fix: `province` is now the leading column, so the index is used

-- Mistake 3: wrapping an indexed column in a function (count people born in 1990)
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT COUNT(*) FROM users WHERE YEAR(birth_date) = 1990;                                    -- the function hides the column: idx_users_birth_date cannot be used for filtering

EXPLAIN SELECT COUNT(*) FROM users WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';   -- fix 1: rewrite the condition as a range

CREATE INDEX idx_users_birth_year ON users ((YEAR(birth_date)));                                     -- fix 2: functional index (MySQL 8.0.13+)
EXPLAIN SELECT COUNT(*) FROM users WHERE YEAR(birth_date) = 1990;                                    -- the expression matches the index exactly, so it is used

-- Mistake 4: too many indexes slow down writes
SHOW INDEX FROM users;    -- list the existing indexes; every INSERT / UPDATE / DELETE has to maintain ALL of them

-- Mistake 5: foreign key without an index (InnoDB creates one automatically, unlike PostgreSQL)
SHOW INDEX FROM users;                                          -- fk_users_head is listed even though we never created it
EXPLAIN SELECT * FROM users WHERE household_head_id = 5;        -- uses that index (find the members of one household)

-- Mistake 6: ignoring NULLs (70% of people are alive, so death_date is NULL for most rows)
-- MySQL has no partial index, so the index also stores all those NULL rows. In PostgreSQL a partial index skips them; see demo_postgres.sql.
CREATE INDEX idx_users_death_date ON users (death_date);
EXPLAIN SELECT * FROM users WHERE death_date >= '2023-06-01';

-- Mistake 7: never checking whether an index is actually used
SELECT index_name FROM sys.schema_unused_indexes
WHERE object_schema = DATABASE() AND object_name = 'users';    -- indexes that have not been used since the server started (candidates to drop)


-- ===================== SLIDE 6: HOW DO I KNOW AN INDEX IS USED? =====================
-- Look up a citizen by national ID.
EXPLAIN SELECT * FROM users WHERE national_id = '000000050000';
-- No index yet: type = ALL, key = NULL, rows ~ 100000 (full table scan)

CREATE INDEX idx_users_national_id ON users (national_id);
EXPLAIN SELECT * FROM users WHERE national_id = '000000050000';
-- With the index: type = ref, key = idx_users_national_id, rows = 1

EXPLAIN ANALYZE SELECT * FROM users WHERE national_id = '000000050000';   -- runs the query for real and adds actual timing and row counts
