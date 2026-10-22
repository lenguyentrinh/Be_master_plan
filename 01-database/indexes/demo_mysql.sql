-- DEMO INDEX TRÊN MYSQL (8.0.18 trở lên)
-- Ngữ cảnh: cơ sở dữ liệu dân cư quốc gia, một bảng users, mỗi dòng là một công dân.
-- Đọc EXPLAIN: type = ALL là quét toàn bảng; ref/range là có dùng index; key là index được chọn;
--              Extra = "Using index" là covering index.
-- Chạy lại từ đầu thì chạy lại SETUP.


-- ===================== SETUP =====================
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    national_id       VARCHAR(12) NOT NULL,              -- số căn cước
    full_name         VARCHAR(100) NOT NULL,
    gender            CHAR(1) NOT NULL,                  -- 'M' hoặc 'F'
    birth_date        DATE NOT NULL,                     -- ngày sinh
    status            ENUM('alive', 'dead') NOT NULL,    -- còn sống hoặc đã mất
    death_date        DATE NULL,                         -- NULL nếu còn sống
    province          VARCHAR(20) NOT NULL,              -- tỉnh (63 tỉnh)
    household_head_id INT NULL,                          -- chủ hộ (foreign key)
    bio               TEXT,                              -- mô tả về công dân
    CONSTRAINT fk_users_head FOREIGN KEY (household_head_id) REFERENCES users(id)   -- InnoDB tự tạo index cho cột này
);

SET SESSION cte_max_recursion_depth = 200000;

-- 100.000 công dân, 30% đã mất
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
ANALYZE TABLE users;


-- ===================== SLIDE 4: CÁC LOẠI INDEX =====================

-- B-tree (mặc định)
CREATE INDEX idx_users_province   ON users (province);
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';                                   -- bằng: công dân của một tỉnh (nhiều dòng trùng)
EXPLAIN SELECT * FROM users WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';   -- range: người sinh năm 1990
EXPLAIN SELECT * FROM users ORDER BY birth_date LIMIT 10;                                     -- sort: 10 người lớn tuổi nhất

CREATE INDEX idx_users_name ON users (full_name);
EXPLAIN SELECT * FROM users WHERE full_name LIKE 'Nguyen Van 500%';   -- prefix: dùng index
EXPLAIN SELECT * FROM users WHERE full_name LIKE '%500';              -- wildcard đứng đầu: type = ALL

-- Unique
CREATE UNIQUE INDEX idx_users_national_id ON users (national_id);     -- OK vì số căn cước chưa trùng
INSERT INTO users (national_id, full_name, gender, birth_date, status, province)
VALUES ('000000000001', 'Test', 'M', '2000-01-01', 'alive', 'province_01');   -- LỖI: trùng số căn cước, bị chặn
CREATE UNIQUE INDEX idx_users_province_unique ON users (province);            -- LỖI: province đã có giá trị trùng, không tạo được

-- Composite (leftmost prefix)
CREATE INDEX idx_users_province_birth ON users (province, birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';                                   -- dùng index (cột đầu)
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND birth_date >= '1990-01-01';    -- dùng index (cả 2 cột)
EXPLAIN SELECT * FROM users WHERE birth_date >= '1990-01-01' AND gender = 'F';                -- thiếu cột đầu province: không dùng idx_users_province_birth

-- Partial / Filtered
-- MySQL KHÔNG hỗ trợ partial index (không có WHERE khi tạo index). Xem demo_postgres.sql.

-- Full-text: tìm trong bio
CREATE FULLTEXT INDEX idx_users_bio ON users (bio);
SELECT COUNT(*) FROM users WHERE MATCH(bio) AGAINST('database design');                      -- TH1: 2 từ không cần liền kề
SELECT COUNT(*) FROM users WHERE MATCH(bio) AGAINST('"database design"' IN BOOLEAN MODE);    -- TH2: phải liền kề

-- GIN / GiST: chỉ có trong PostgreSQL. Xem demo_postgres.sql.

-- Covering (MySQL không có INCLUDE, đưa cột cần lấy vào index)
CREATE INDEX idx_users_province_name ON users (province, full_name);
EXPLAIN SELECT province, full_name FROM users WHERE province = 'province_01';   -- Extra: Using index (không đọc bảng)

-- Clustered / Non-clustered
-- InnoDB: primary key chính là clustered index, mỗi bảng chỉ có 1. Mọi CREATE INDEX khác là non-clustered (secondary index).
SHOW INDEX FROM users;


-- ===================== SLIDE 5: 7 LỖI THƯỜNG GẶP =====================
DROP INDEX idx_users_province ON users;
DROP INDEX idx_users_birth_date ON users;
DROP INDEX idx_users_name ON users;
DROP INDEX idx_users_national_id ON users;
DROP INDEX idx_users_province_birth ON users;
DROP INDEX idx_users_bio ON users;
DROP INDEX idx_users_province_name ON users;

-- Lỗi 1: nhiều index đơn cột thay vì một composite
CREATE INDEX idx_users_province ON users (province);
CREATE INDEX idx_users_status   ON users (status);
CREATE INDEX idx_users_gender   ON users (gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- chỉ chọn 1 index, cột còn lại phải lọc thêm

DROP INDEX idx_users_province ON users;
DROP INDEX idx_users_status ON users;
DROP INDEX idx_users_gender ON users;
CREATE INDEX idx_users_province_status_gender ON users (province, status, gender);
EXPLAIN SELECT * FROM users WHERE province = 'province_01' AND status = 'alive' AND gender = 'F';   -- dùng cả 3 cột trong một index

-- Lỗi 2: sai thứ tự cột composite
DROP INDEX idx_users_province_status_gender ON users;
CREATE INDEX idx_users_birth_province ON users (birth_date, province);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';    -- thiếu cột đầu birth_date: không dùng index này

CREATE INDEX idx_users_province_birth ON users (province, birth_date);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';    -- dùng index

-- Lỗi 3: bọc hàm lên cột đã index (đếm người sinh năm 1990)
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT COUNT(*) FROM users WHERE YEAR(birth_date) = 1990;                                    -- không dùng được index theo birth_date

EXPLAIN SELECT COUNT(*) FROM users WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';   -- Cách 1: viết lại thành range

CREATE INDEX idx_users_birth_year ON users ((YEAR(birth_date)));                                     -- Cách 2: functional index (8.0.13+)
EXPLAIN SELECT COUNT(*) FROM users WHERE YEAR(birth_date) = 1990;

-- Lỗi 4: quá nhiều index làm ghi chậm
SHOW INDEX FROM users;    -- liệt kê index đang có; mỗi lần INSERT/UPDATE/DELETE đều phải cập nhật hết

-- Lỗi 5: foreign key (MySQL InnoDB tự tạo index, khác PostgreSQL)
SHOW INDEX FROM users;                                          -- có index fk_users_head dù ta chưa tạo
EXPLAIN SELECT * FROM users WHERE household_head_id = 5;        -- dùng index (tìm thành viên của một hộ)

-- Lỗi 6: bỏ qua NULL (70% người còn sống nên death_date là NULL)
-- MySQL không có partial index nên index chứa cả các dòng NULL. PostgreSQL dùng partial index, xem demo_postgres.sql.
CREATE INDEX idx_users_death_date ON users (death_date);
EXPLAIN SELECT * FROM users WHERE death_date >= '2023-06-01';

-- Lỗi 7: không kiểm tra index có được dùng
SELECT index_name FROM sys.schema_unused_indexes
WHERE object_schema = DATABASE() AND object_name = 'users';    -- index chưa từng được dùng kể từ khi server khởi động


-- ===================== SLIDE 6: LÀM SAO BIẾT INDEX CÓ ĐƯỢC DÙNG =====================
-- Tra cứu công dân theo số căn cước
EXPLAIN SELECT * FROM users WHERE national_id = '000000050000';
-- Chưa có index: type = ALL, key = NULL, rows ~ 100000 (quét toàn bảng)

CREATE INDEX idx_users_national_id ON users (national_id);
EXPLAIN SELECT * FROM users WHERE national_id = '000000050000';
-- Có index: type = ref, key = idx_users_national_id, rows = 1

EXPLAIN ANALYZE SELECT * FROM users WHERE national_id = '000000050000';   -- có thêm thời gian chạy thực tế
