-- DEMO INDEX TRÊN POSTGRESQL (11 trở lên)
-- Ngữ cảnh: cơ sở dữ liệu dân cư quốc gia, một bảng users, mỗi dòng là một công dân.
-- Đọc EXPLAIN: "Seq Scan" = quét toàn bảng; có chữ "Index" = có dùng index.


-- ===================== SETUP =====================
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id                serial PRIMARY KEY,
    national_id       text NOT NULL,              -- số căn cước
    full_name         text NOT NULL,
    gender            text NOT NULL,              -- 'M' hoặc 'F'
    birth_date        date NOT NULL,              -- ngày sinh
    status            text NOT NULL,              -- 'alive' (còn sống) hoặc 'dead' (đã mất)
    death_date        date,                       -- NULL nếu còn sống
    province          text NOT NULL,              -- tỉnh (63 tỉnh)
    household_head_id int REFERENCES users(id),   -- chủ hộ (foreign key)
    bio               text,                       -- mô tả về công dân
    skills            text[],                     -- kỹ năng
    home_location     point                       -- toạ độ nhà
);

-- 100.000 công dân, 30% đã mất
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
ANALYZE users;


-- ===================== SLIDE 4: CÁC LOẠI INDEX =====================

-- B-tree (mặc định)
CREATE INDEX idx_users_province   ON users (province);
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';                                   -- bằng: công dân của một tỉnh (nhiều dòng trùng)
EXPLAIN SELECT * FROM users WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';   -- range: người sinh năm 1990
EXPLAIN SELECT * FROM users ORDER BY birth_date LIMIT 10;                                     -- sort: 10 người lớn tuổi nhất

CREATE INDEX idx_users_name ON users (full_name text_pattern_ops);
EXPLAIN SELECT * FROM users WHERE full_name LIKE 'Nguyen Van 500%';   -- prefix: dùng index
EXPLAIN SELECT * FROM users WHERE full_name LIKE '%500';              -- wildcard đứng đầu: Seq Scan

-- Unique
CREATE UNIQUE INDEX idx_users_national_id ON users (national_id);     -- OK vì số căn cước chưa trùng
INSERT INTO users (national_id, full_name, gender, birth_date, status, province)
VALUES ('000000000001', 'Test', 'M', '2000-01-01', 'alive', 'province_01');   -- LỖI: trùng số căn cước, bị chặn
CREATE UNIQUE INDEX idx_users_province_unique ON users (province);            -- LỖI: province đã có giá trị trùng, không tạo được

-- Composite (leftmost prefix)
CREATE INDEX idx_users_province_birth ON users (province, birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';                                   -- dùng index (cột đầu)
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND birth_date >= '1990-01-01';    -- dùng index (cả 2 cột)
EXPLAIN SELECT * FROM users WHERE birth_date >= '1990-01-01' AND gender = 'F';                -- thiếu cột đầu province: không dùng

-- Partial: lao động thì phải còn sống, chỉ index người còn sống
CREATE INDEX idx_users_alive ON users (province, birth_date) WHERE status = 'alive';
EXPLAIN SELECT * FROM users
WHERE status = 'alive' AND province = 'province_01' AND birth_date BETWEEN '1996-01-01' AND '2001-12-31';
SELECT pg_size_pretty(pg_relation_size('idx_users_alive'))          AS partial_size,
       pg_size_pretty(pg_relation_size('idx_users_province_birth')) AS full_size;    -- partial nhỏ hơn

-- Full-text: tìm trong bio
CREATE INDEX idx_users_bio ON users USING gin (to_tsvector('english', bio));
SELECT count(*) FROM users WHERE to_tsvector('english', bio) @@ plainto_tsquery('english', 'database design');    -- TH1: 2 từ không cần liền kề
SELECT count(*) FROM users WHERE to_tsvector('english', bio) @@ phraseto_tsquery('english', 'database design');   -- TH2: phải liền kề

-- GIN (mảng) và GiST (hình học)
CREATE INDEX idx_users_skills ON users USING gin (skills);
EXPLAIN SELECT * FROM users WHERE skills @> ARRAY['sql'];                  -- người có kỹ năng sql

CREATE INDEX idx_users_location ON users USING gist (home_location);
EXPLAIN SELECT * FROM users WHERE home_location <@ box '((0,0),(5,5))';    -- người sống trong một vùng

-- Covering (INCLUDE)
CREATE INDEX idx_users_province_cover ON users (province) INCLUDE (full_name);
VACUUM ANALYZE users;
EXPLAIN SELECT province, full_name FROM users WHERE province = 'province_01';   -- Index Only Scan: không đọc bảng

-- Clustered / Non-clustered
-- Mọi CREATE INDEX ở trên là non-clustered. PostgreSQL không có clustered index tự duy trì.


-- ===================== SLIDE 5: 7 LỖI THƯỜNG GẶP =====================
DROP INDEX idx_users_province, idx_users_birth_date, idx_users_name, idx_users_national_id,
           idx_users_province_birth, idx_users_alive, idx_users_bio, idx_users_skills,
           idx_users_location, idx_users_province_cover;

-- Lỗi 1: nhiều index đơn cột thay vì một composite
CREATE INDEX idx_users_province ON users (province);
CREATE INDEX idx_users_status   ON users (status);
CREATE INDEX idx_users_gender   ON users (gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- phải gộp nhiều index

DROP INDEX idx_users_province, idx_users_status, idx_users_gender;
CREATE INDEX idx_users_province_status_gender ON users (province, status, gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- chỉ một index

-- Lỗi 2: sai thứ tự cột composite
DROP INDEX idx_users_province_status_gender;
CREATE INDEX idx_users_birth_province ON users (birth_date, province);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';    -- thiếu cột đầu birth_date: không dùng hiệu quả

CREATE INDEX idx_users_province_birth ON users (province, birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';    -- dùng index

-- Lỗi 3: bọc hàm lên cột đã index (đếm người sinh năm 1990)
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT count(*) FROM users WHERE EXTRACT(YEAR FROM birth_date) = 1990;                       -- Seq Scan

EXPLAIN SELECT count(*) FROM users WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';   -- Cách 1: viết lại thành range

CREATE INDEX idx_users_birth_year ON users ((EXTRACT(YEAR FROM birth_date)));                        -- Cách 2: expression index
EXPLAIN SELECT count(*) FROM users WHERE EXTRACT(YEAR FROM birth_date) = 1990;

-- Lỗi 4: quá nhiều index làm ghi chậm
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes WHERE relname = 'users';    -- mỗi index tốn thêm dung lượng, và mỗi lần INSERT/UPDATE/DELETE đều phải cập nhật hết

-- Lỗi 5: thiếu index cho foreign key (PostgreSQL không tự tạo)
EXPLAIN SELECT * FROM users WHERE household_head_id = 5;    -- Seq Scan (tìm thành viên của một hộ)
CREATE INDEX idx_users_household_head ON users (household_head_id);
EXPLAIN SELECT * FROM users WHERE household_head_id = 5;    -- dùng index

-- Lỗi 6: bỏ qua NULL, nên dùng partial index (70% người còn sống nên death_date là NULL)
CREATE INDEX idx_users_death_full    ON users (death_date);
CREATE INDEX idx_users_death_partial ON users (death_date) WHERE death_date IS NOT NULL;
SELECT pg_size_pretty(pg_relation_size('idx_users_death_full'))    AS full_size,
       pg_size_pretty(pg_relation_size('idx_users_death_partial')) AS partial_size;

-- Lỗi 7: không kiểm tra index có được dùng
SELECT indexrelname, idx_scan AS times_used
FROM pg_stat_user_indexes WHERE relname = 'users' ORDER BY idx_scan;   -- idx_scan = 0 là index chưa từng được dùng


-- ===================== SLIDE 6: LÀM SAO BIẾT INDEX CÓ ĐƯỢC DÙNG =====================
-- Tra cứu công dân theo số căn cước
EXPLAIN ANALYZE SELECT * FROM users WHERE national_id = '000000050000';
-- Chưa có index: Seq Scan, thời gian vài chục ms

CREATE INDEX idx_users_national_id ON users (national_id);
EXPLAIN ANALYZE SELECT * FROM users WHERE national_id = '000000050000';
-- Có index: Index Scan, thời gian dưới 1 ms
