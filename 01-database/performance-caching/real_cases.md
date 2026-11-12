# Real cases: Performance & Caching

Mỗi case ứng với một mục trong `README.md`. Tất cả chạy trên **MySQL 8.0.18+**, dùng bảng `users` (dân số quốc gia, 100.000 dòng) từ [`demo_mysql.sql`](../../demo_mysql.sql).

> **Rule:** mọi real case (mới thêm) phải dựa trên tài liệu [`demo_mysql.sql`](../../demo_mysql.sql): dùng đúng bảng `users` (dân số quốc gia, 100.000 dòng, 30% đã chết), cú pháp MySQL 8.0.18+ và cách đọc `EXPLAIN` / `EXPLAIN ANALYZE` như trong file đó. Không tự bịa schema hoặc số liệu ngoài file này.

> **Lưu ý:** file này **không ghi số liệu cố định** (cost, ms) vì chúng phụ thuộc máy. Mỗi case chỉ ghi **cần nhìn vào đâu** và **kỳ vọng thấy gì**. Các lệnh chưa được chạy thử trên máy thật, nếu kết quả khác kỳ vọng thì ghi lại và báo để sửa.

## Cách thử

1. Mở MySQL client (Workbench, DBeaver hoặc `mysql`), chọn một database trống.
2. Chạy khối **SETUP** bên dưới **một lần** (vài giây).
3. Mỗi case chạy từ trên xuống dưới, theo 4 bước: **Chạy (trước)** → **Nhìn vào** → **Sửa** → **Chạy lại (sau)**.
4. Mỗi case bắt đầu từ trạng thái sạch (không có index phụ). Trước khi sang case khác, **chạy lại SETUP** để reset.

### SETUP (copy từ `demo_mysql.sql`)

```sql
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    national_id       VARCHAR(12) NOT NULL,
    full_name         VARCHAR(100) NOT NULL,
    gender            CHAR(1) NOT NULL,
    birth_date        DATE NOT NULL,
    status            ENUM('alive', 'dead') NOT NULL,
    death_date        DATE NULL,
    province          VARCHAR(20) NOT NULL,
    household_head_id INT NULL,
    bio               TEXT,
    CONSTRAINT fk_users_head FOREIGN KEY (household_head_id) REFERENCES users(id)
);

SET SESSION cte_max_recursion_depth = 200000;

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
```

Cách đọc `EXPLAIN`: `type = ALL` là quét toàn bảng; `ref` / `range` là có dùng index; `key` là index được chọn; `rows` là số dòng **ước lượng**; `Extra = Using index` là covering index. `EXPLAIN` chỉ lập kế hoạch, **không chạy** query. `EXPLAIN ANALYZE` **chạy thật** và thêm thời gian, số dòng thực tế.

---

## Case 1. Đọc execution plan: tìm operator tốn nhất

**Vấn đề:** cổng dịch vụ công tra cứu công dân theo số CCCD (`national_id`) bị chậm.

**Chạy (trước):**

```sql
EXPLAIN SELECT * FROM users WHERE national_id = '000000050000';
EXPLAIN ANALYZE SELECT * FROM users WHERE national_id = '000000050000';
```

**Nhìn vào:** `type = ALL`, `key = NULL`, `rows` khoảng 100000. Ở `EXPLAIN ANALYZE` thấy dòng `Table scan on users` với `actual time` lớn nhất và `rows` thực tế 100000. Đó là operator tốn nhất: đọc cả bảng để tìm đúng 1 người.

**Sửa:**

```sql
CREATE INDEX idx_users_national_id ON users (national_id);
```

**Chạy lại (sau):**

```sql
EXPLAIN SELECT * FROM users WHERE national_id = '000000050000';
EXPLAIN ANALYZE SELECT * FROM users WHERE national_id = '000000050000';
```

**Kỳ vọng:** `type = ref`, `key = idx_users_national_id`, `rows = 1`; plan đổi thành `Index lookup on users using idx_users_national_id`, thời gian giảm rõ rệt.

**Bài học:** đọc plan để biết **chỗ nào** chậm trước khi sửa, không đoán.

---

## Case 2. Chỉnh tham số bộ nhớ: buffer nhỏ làm sort phải chia nhiều lượt

MySQL tương ứng với `work_mem` của PostgreSQL là `sort_buffer_size` (mỗi session, mỗi lần sort). Ngoài ra `innodb_buffer_pool_size` là vùng cache dữ liệu và index (tương ứng `shared_buffers`).

**Vấn đề:** báo cáo xuất danh sách công dân sắp xếp theo `bio` (cột không có index) chạy chậm.

**Chạy (trước):**

```sql
SET SESSION sort_buffer_size = 32768;        -- 32 KB, mức nhỏ nhất cho phép
FLUSH STATUS;                                 -- reset bộ đếm của session
SELECT id, bio FROM users ORDER BY bio;       -- không LIMIT để buộc sort cả 100.000 dòng
SHOW SESSION STATUS LIKE 'Sort_merge_passes';
```

**Nhìn vào:** `Sort_merge_passes` lớn hơn 0. Đây là số lần sort phải trộn các đoạn tạm ghi ra đĩa vì buffer không đủ chứa. Có thể đo thời gian bằng `EXPLAIN ANALYZE` cùng query.

**Sửa:** tăng buffer cho **session chạy báo cáo**, không tăng bừa bãi toàn server.

```sql
SET SESSION sort_buffer_size = 268435456;    -- 256 MB
FLUSH STATUS;
SELECT id, bio FROM users ORDER BY bio;
SHOW SESSION STATUS LIKE 'Sort_merge_passes';
```

**Kỳ vọng:** `Sort_merge_passes` về 0 hoặc giảm mạnh, thời gian query giảm.

**Xem thêm:**

```sql
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';   -- kích thước cache dữ liệu hiện tại
SHOW VARIABLES LIKE 'sort_buffer_size';
```

**Bài học:** `sort_buffer_size` được cấp **mỗi connection, mỗi lần sort**, nên 256 MB × 200 connection có thể làm hết RAM. Chỉ tăng ở session cần thiết rồi trả lại: `SET SESSION sort_buffer_size = DEFAULT;`.

---

## Case 3. Tối ưu câu query

### 3a. Tránh `SELECT *` (và cơ hội dùng covering index)

**Vấn đề:** API danh sách chỉ cần tỉnh và họ tên, nhưng `users` có cột `bio` kiểu `TEXT`.

**Chạy (trước):**

```sql
CREATE INDEX idx_users_province_name ON users (province, full_name);
EXPLAIN SELECT * FROM users WHERE province = 'province_01';
```

**Nhìn vào:** `Extra` không có `Using index`, MySQL phải quay về bảng đọc đủ mọi cột (kể cả `bio`) cho từng dòng.

**Sửa và chạy lại (sau):**

```sql
EXPLAIN SELECT province, full_name FROM users WHERE province = 'province_01';
```

**Kỳ vọng:** `Extra = Using index`, bảng không bị đọc. Lấy ít cột hơn cũng giảm lượng dữ liệu trả về.

### 3b. Correlated subquery thay bằng join

**Vấn đề:** hiển thị mỗi công dân kèm tổng số người cùng tỉnh. Dùng subquery chạy lại cho từng dòng.

**Chạy (trước)** (chỉ lấy 500 người để không phải chờ lâu):

```sql
EXPLAIN ANALYZE
SELECT u.id, u.full_name,
       (SELECT COUNT(*) FROM users x WHERE x.province = u.province) AS people_in_province
FROM users u
WHERE u.id <= 500;
```

**Nhìn vào:** subquery chạy 500 lần, mỗi lần quét cả bảng (`Table scan on x`, `loops=500`). Với 100.000 người thì thành 100.000 lần quét.

**Sửa:** đếm một lần theo tỉnh rồi join.

```sql
EXPLAIN ANALYZE
SELECT u.id, u.full_name, p.people_in_province
FROM users u
JOIN (SELECT province, COUNT(*) AS people_in_province FROM users GROUP BY province) p
  ON p.province = u.province
WHERE u.id <= 500;
```

**Kỳ vọng:** bảng `users` chỉ bị quét một lần cho phần `GROUP BY`, tổng thời gian giảm nhiều. Lưu ý MySQL đôi khi tự viết lại subquery đơn giản, cần xác nhận bằng `EXPLAIN`.

### 3c. Tránh Cartesian join

**Vấn đề:** tìm các thành viên của mỗi hộ nhưng quên điều kiện nối.

**Chạy (trước)** (chỉ `EXPLAIN`, **đừng chạy thật**, vì sẽ ra 100.000 × 100.000 dòng):

```sql
EXPLAIN SELECT h.full_name AS head, m.full_name AS member
FROM users h, users m;
```

**Nhìn vào:** không có điều kiện nối, `rows` nhân với nhau (cỡ 10 tỷ), `Extra` có `Using join buffer`.

**Sửa:**

```sql
EXPLAIN SELECT h.full_name AS head, m.full_name AS member
FROM users h JOIN users m ON m.household_head_id = h.id;
```

**Kỳ vọng:** bảng `m` dùng index `fk_users_head` (`type = ref`), số dòng ước lượng giảm xuống còn vài chục nghìn thay vì hàng tỷ.

### 3d. Khớp kiểu dữ liệu

**Vấn đề:** `national_id` là `VARCHAR` nhưng code truyền số (ví dụ do ORM tự bind kiểu int).

**Chạy (trước):**

```sql
CREATE INDEX idx_users_national_id ON users (national_id);
EXPLAIN SELECT * FROM users WHERE national_id = 50000;      -- so VARCHAR với số
```

**Nhìn vào:** `possible_keys` có `idx_users_national_id` nhưng `key = NULL`, `type = ALL`. MySQL ép kiểu **cả cột** sang số để so sánh nên không dùng được index. Chạy `SHOW WARNINGS;` còn thấy phần bị ép kiểu.

**Sửa:**

```sql
EXPLAIN SELECT * FROM users WHERE national_id = '000000050000';   -- đúng kiểu chuỗi
```

**Kỳ vọng:** `type = ref`, `key = idx_users_national_id`. (Lưu ý: `50000` và `'000000050000'` còn là hai giá trị khác nhau về chuỗi, nên truyền sai kiểu không chỉ chậm mà còn có thể trả sai dòng.)

---

## Case 4. Index hiệu quả và sargability

Mỗi case dưới đây bắt đầu từ SETUP sạch.

### 4a. Hàm trên cột (`YEAR`)

**Vấn đề:** thống kê số người sinh năm 1990 chậm dù đã có index trên `birth_date`.

**Chạy (trước):**

```sql
CREATE INDEX idx_users_birth_date ON users (birth_date);
EXPLAIN SELECT COUNT(*) FROM users WHERE YEAR(birth_date) = 1990;
```

**Nhìn vào:** hàm `YEAR()` bọc cột nên không dùng được index để lọc. Quét hết các dòng.

**Sửa (cách 1): viết thành khoảng trên cột gốc:**

```sql
EXPLAIN SELECT COUNT(*) FROM users
WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';
```

**Kỳ vọng:** `type = range`, `key = idx_users_birth_date`, `rows` giảm mạnh. Nên dùng `< '1991-01-01'` thay vì `<= '1990-12-31'` để không sót dữ liệu nếu sau này cột đổi sang `DATETIME`.

**Sửa (cách 2): functional index (MySQL 8.0.13+)** khi không thể sửa query:

```sql
CREATE INDEX idx_users_birth_year ON users ((YEAR(birth_date)));
EXPLAIN SELECT COUNT(*) FROM users WHERE YEAR(birth_date) = 1990;
```

### 4b. `LIKE` wildcard đầu

**Vấn đề:** tìm công dân theo họ tên.

**Chạy:**

```sql
CREATE INDEX idx_users_name ON users (full_name);
EXPLAIN SELECT * FROM users WHERE full_name LIKE 'Nguyen Van 500%';   -- tiền tố
EXPLAIN SELECT * FROM users WHERE full_name LIKE '%500';              -- wildcard đầu
```

**Kỳ vọng:** câu đầu `type = range` dùng index; câu sau `type = ALL`. Với tìm kiểu "chứa" nên dùng full-text:

```sql
CREATE FULLTEXT INDEX idx_users_bio ON users (bio);
SELECT COUNT(*) FROM users WHERE MATCH(bio) AGAINST('"database design"' IN BOOLEAN MODE);
```

### 4c. `OR` trên hai cột khác nhau

**Vấn đề:** tìm công dân thuộc một tỉnh **hoặc** sinh đúng một ngày.

**Chạy:**

```sql
CREATE INDEX idx_users_province   ON users (province);
CREATE INDEX idx_users_birth_date ON users (birth_date);

EXPLAIN SELECT * FROM users WHERE province = 'province_01' OR birth_date = '1990-05-05';
```

**Nhìn vào:** MySQL có thể dùng `type = index_merge` với `Extra = Using union(...)`, tức là tự gộp hai index. Nếu thấy `type = ALL` thì thử tách:

```sql
EXPLAIN
SELECT * FROM users WHERE province = 'province_01'
UNION ALL
SELECT * FROM users WHERE birth_date = '1990-05-05' AND province <> 'province_01';
```

**Bài học:** không phải lúc nào viết lại cũng nhanh hơn. Luôn so sánh hai bản bằng `EXPLAIN ANALYZE` trên DB đang dùng.

### 4d. Covering index giảm lần quay về bảng

**Vấn đề:** danh sách công dân theo tỉnh chỉ cần `full_name`, nhưng mỗi dòng index lại phải quay về bảng lấy cột.

**Chạy (trước):**

```sql
CREATE INDEX idx_users_province ON users (province);
EXPLAIN SELECT province, full_name FROM users WHERE province = 'province_01';
```

**Sửa:** MySQL không có `INCLUDE`, đưa luôn cột cần vào index.

```sql
CREATE INDEX idx_users_province_name ON users (province, full_name);
EXPLAIN SELECT province, full_name FROM users WHERE province = 'province_01';
```

**Kỳ vọng:** `Extra = Using index` (bảng không bị đọc).

### 4e. Không đánh index cột low cardinality

**Vấn đề:** ai đó đánh index cho cột `gender` (chỉ `M`/`F`, mỗi giá trị 50%).

**Chạy:**

```sql
CREATE INDEX idx_users_gender ON users (gender);
EXPLAIN SELECT * FROM users WHERE gender = 'F';
SHOW INDEX FROM users;     -- xem cột Cardinality của idx_users_gender (chỉ khoảng 2)
```

**Kỳ vọng:** `possible_keys = idx_users_gender` nhưng `type = ALL`, optimizer bỏ qua index vì trả về nửa bảng thì quét thẳng rẻ hơn. Index này chỉ tốn chỗ và làm chậm `INSERT/UPDATE/DELETE`. MySQL không có partial index, nếu cần lọc nhóm hiếm thì dùng index kết hợp với cột có cardinality cao hơn (ví dụ `(province, gender)`).

---

## Case 5. Theo dõi reads/IOPS và "materialized view"

MySQL **không có** materialized view. Cách tương đương: tạo bảng tổng hợp và làm mới định kỳ (tay, cron hoặc `EVENT`).

**Vấn đề:** dashboard thống kê dân số theo tỉnh và tình trạng gọi `GROUP BY` mỗi lần mở trang.

**Chạy (trước):**

```sql
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';   -- ghi lại 2 số
EXPLAIN ANALYZE
SELECT province, status, COUNT(*) AS cnt FROM users GROUP BY province, status;
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';   -- ghi lại 2 số, lấy hiệu
```

**Nhìn vào:**
- `Innodb_buffer_pool_read_requests`: số lần đọc **logical** (từ buffer pool, trong RAM).
- `Innodb_buffer_pool_reads`: số lần phải đọc **physical** từ đĩa. Số này càng cao thì IOPS càng cao.
- `EXPLAIN ANALYZE`: `Table scan on users` và thời gian.

(Số liệu `GLOBAL` có thể lẫn hoạt động của session khác, nên thử trên server vắng.)

**Sửa:** lưu sẵn kết quả vào bảng tổng hợp.

```sql
CREATE TABLE province_stats AS
SELECT province, status, COUNT(*) AS cnt FROM users GROUP BY province, status;
ALTER TABLE province_stats ADD PRIMARY KEY (province, status);

EXPLAIN ANALYZE SELECT * FROM province_stats WHERE province = 'province_01';
```

**Kỳ vọng:** chỉ đọc vài dòng (`rows` cỡ 2), số lần đọc và thời gian giảm rõ rệt.

**Thấy rõ đánh đổi (dữ liệu cũ):**

```sql
INSERT INTO users (national_id, full_name, gender, birth_date, status, province)
VALUES ('999999999999', 'New Person', 'M', '2000-01-01', 'alive', 'province_01');

SELECT cnt FROM province_stats WHERE province = 'province_01' AND status = 'alive';          -- chưa tăng
SELECT COUNT(*) FROM users WHERE province = 'province_01' AND status = 'alive';              -- đã tăng 1

-- Làm mới (ví dụ chạy mỗi đêm)
REPLACE INTO province_stats
SELECT province, status, COUNT(*) FROM users GROUP BY province, status;
```

**Bài học:** giữa hai lần làm mới, số liệu bị trễ. Hợp với báo cáo chấp nhận trễ; không hợp với dữ liệu cần chính xác từng giây.

---

## Case 6. Parameter sniffing

Parameter sniffing là chuyện của SQL Server (plan được cache theo tham số của lần chạy đầu). MySQL **không cache plan theo tham số**, nó tối ưu lại mỗi lần chạy nên không gặp lỗi này. Case này để thấy **vì sao** cùng một câu query cần plan khác nhau tùy giá trị.

**Chạy:**

```sql
CREATE INDEX idx_users_death_date ON users (death_date);

-- Giá trị ít dòng (khoảng một tuần cuối năm 2023)
EXPLAIN SELECT * FROM users WHERE death_date >= '2023-12-25';

-- Giá trị nhiều dòng (toàn bộ người đã chết, khoảng 30% bảng)
EXPLAIN SELECT * FROM users WHERE death_date >= '2023-01-01';
```

**Kỳ vọng:** câu đầu `type = range` dùng index; câu sau có thể chuyển sang `type = ALL` vì lấy quá nhiều dòng thì đi qua index rồi quay về bảng đắt hơn quét bảng. (Nếu cả hai vẫn ra `range` thì thử mở rộng khoảng ngày.) Cùng cấu trúc query, plan tốt nhất khác nhau theo giá trị.

**Ví dụ SQL Server (không chạy được ở đây, chỉ để tham khảo):** stored procedure cache plan `Index Seek + Key Lookup` từ lần gọi đầu với giá trị hiếm, rồi dùng lại cho giá trị phổ biến và chạy rất chậm. Cách xử lý:

```sql
SELECT * FROM users WHERE death_date >= @d OPTION (RECOMPILE);
-- hoặc CREATE PROCEDURE ... WITH RECOMPILE
```

**Bài học:** nếu chuyển giữa các hệ quản trị, cần biết DB đó cache plan thế nào. Trên MySQL, nếu thấy cùng query lúc nhanh lúc chậm theo tham số thì nguyên nhân thường là statistics hoặc dữ liệu lệch, không phải sniffing.

---

## Case 7. Quản lý transaction cẩn thận

**Vấn đề:** job cập nhật hàng loạt chạy trong **một transaction dài** giữ lock, các thao tác khác trên cùng dòng bị chờ rồi timeout. Cần **hai cửa sổ** (hai session) MySQL.

**Chạy (trước):**

Session A:

```sql
START TRANSACTION;
UPDATE users SET bio = CONCAT(bio, ' [archived]') WHERE province = 'province_01';
-- CHƯA COMMIT, cứ để đó
```

Session B:

```sql
SET SESSION innodb_lock_wait_timeout = 5;       -- chờ tối đa 5 giây thay vì 50
UPDATE users SET full_name = 'Updated' WHERE id = 1;
```

**Nhìn vào:** nếu `id = 1` thuộc `province_01` thì session B đứng chờ rồi báo `ERROR 1205 (HY000): Lock wait timeout exceeded`. Vì cột `province` chưa có index nên `UPDATE` ở A còn có thể khóa **cả các dòng khác phải quét qua**. Xem ai đang chặn ai (ở session thứ ba):

```sql
SELECT * FROM sys.innodb_lock_waits\G
```

Xong thì ở session A chạy `ROLLBACK;`.

**Sửa:** chia lô nhỏ, commit từng lô. Chạy lặp lại lệnh dưới cho đến khi `Rows matched: 0`:

```sql
UPDATE users SET bio = CONCAT(bio, ' [archived]')
WHERE province = 'province_01' AND bio NOT LIKE '% [archived]'
LIMIT 500;
```

(Với `autocommit = 1` mỗi lệnh là một transaction riêng và commit ngay.)

**Kỳ vọng:** mỗi lô giữ lock rất ngắn, session B gần như không phải chờ; ít deadlock và blocking hơn.

**Bài học:** transaction ngắn, việc nặng chạy ngoài giờ cao điểm. Chạy lại SETUP để bỏ dấu `[archived]`.

---

## Case 8. Partition bảng lớn

**Vấn đề:** báo cáo luôn chỉ xem một khoảng năm sinh, và việc xóa dữ liệu cũ bằng `DELETE` chậm. Partition theo `birth_date`.

Ràng buộc của MySQL: khóa chính phải chứa cột partition và bảng partition **không hỗ trợ foreign key**, nên tạo bảng thử riêng `users_part` (không FK).

**Chạy:**

```sql
CREATE TABLE users_part (
    id          INT NOT NULL AUTO_INCREMENT,
    national_id VARCHAR(12) NOT NULL,
    full_name   VARCHAR(100) NOT NULL,
    birth_date  DATE NOT NULL,
    province    VARCHAR(20) NOT NULL,
    PRIMARY KEY (id, birth_date)
)
PARTITION BY RANGE COLUMNS (birth_date) (
    PARTITION p1950s VALUES LESS THAN ('1960-01-01'),
    PARTITION p1960s VALUES LESS THAN ('1970-01-01'),
    PARTITION p1970s VALUES LESS THAN ('1980-01-01'),
    PARTITION p1980s VALUES LESS THAN ('1990-01-01'),
    PARTITION p1990s VALUES LESS THAN ('2000-01-01'),
    PARTITION p2000s VALUES LESS THAN ('2010-01-01'),
    PARTITION p2010s VALUES LESS THAN ('2020-01-01'),
    PARTITION pmax   VALUES LESS THAN (MAXVALUE)
);

INSERT INTO users_part (national_id, full_name, birth_date, province)
SELECT national_id, full_name, birth_date, province FROM users;

-- So sánh: bảng thường (không index) và bảng partition
EXPLAIN SELECT COUNT(*) FROM users      WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';
EXPLAIN SELECT COUNT(*) FROM users_part WHERE birth_date >= '1990-01-01' AND birth_date < '1991-01-01';
```

**Nhìn vào:** cột `partitions` của bảng `users_part` chỉ liệt kê `p1990s` (partition pruning), các partition khác bị bỏ qua. Bảng `users` thì `type = ALL`.

**Xóa dữ liệu cũ:**

```sql
ALTER TABLE users_part DROP PARTITION p1950s;      -- tức thì, không quét từng dòng
-- so với: DELETE FROM users WHERE birth_date < '1960-01-01';
```

**Lưu ý:** nếu bảng thường đã có index trên `birth_date` thì kết quả đọc gần tương đương. Lợi thế chính của partition ở bảng rất lớn là **drop dữ liệu cũ nhanh** và giảm kích thước index phải duyệt. Partition key phải khớp cách query; chia quá nhỏ (theo ngày) sinh quá nhiều partition và tốn overhead.

---

## Case 9. Cập nhật statistics

**Vấn đề:** sau khi nạp một lượng lớn dữ liệu, statistics vẫn mô tả bảng như còn rỗng nên optimizer chọn plan sai. Để tái hiện ổn định, tạo bảng tắt tự cập nhật statistics.

**Chạy (trước):**

```sql
CREATE TABLE users_stale LIKE users;
ALTER TABLE users_stale STATS_AUTO_RECALC = 0;      -- tắt tự tính lại statistics
CREATE INDEX idx_stale_province ON users_stale (province);
ANALYZE TABLE users_stale;                          -- statistics lúc bảng còn rỗng

INSERT INTO users_stale SELECT * FROM users;        -- nạp 100.000 dòng, KHÔNG analyze

SHOW INDEX FROM users_stale;                        -- xem cột Cardinality của idx_stale_province
EXPLAIN SELECT * FROM users_stale WHERE province = 'province_01';
EXPLAIN ANALYZE SELECT * FROM users_stale WHERE province = 'province_01';
```

**Nhìn vào:** `Cardinality` rất thấp (0 hoặc gần 0) trong khi thực tế có 63 tỉnh. So `rows` (ước lượng) của `EXPLAIN` với `actual rows` (thực tế, khoảng 1.587) của `EXPLAIN ANALYZE`: lệch nhiều là dấu hiệu statistics cũ.

**Sửa:**

```sql
ANALYZE TABLE users_stale;
SHOW INDEX FROM users_stale;
EXPLAIN SELECT * FROM users_stale WHERE province = 'province_01';
```

**Kỳ vọng:** `Cardinality` lên khoảng 63, `rows` ước lượng sát với thực tế.

**Thêm:** với cột lệch giá trị, MySQL 8 hỗ trợ histogram: `ANALYZE TABLE users UPDATE HISTOGRAM ON status;`.

---

## Case 10. Declarative và tính năng riêng của nền tảng

**Vấn đề:** dev tự ép MySQL dùng index bằng hint (`FORCE INDEX`) vì "chắc chắn index thì nhanh hơn", thay vì để optimizer tự quyết định dựa trên statistics.

**Chạy:**

```sql
CREATE INDEX idx_users_gender ON users (gender);

-- Để optimizer tự chọn
EXPLAIN ANALYZE SELECT * FROM users WHERE gender = 'F';

-- Ép dùng index
EXPLAIN ANALYZE SELECT * FROM users FORCE INDEX (idx_users_gender) WHERE gender = 'F';
```

**Nhìn vào:** câu đầu optimizer chọn quét bảng (`Table scan`). Câu sau bị ép đi qua index rồi quay về bảng cho 50.000 dòng, `actual time` thường **lớn hơn**.

**Kỳ vọng:** bản ép index chậm hơn hoặc không nhanh hơn. Khai báo *muốn gì* (câu query) và để nền tảng chọn *làm thế nào* thường an toàn hơn, vì optimizer biết statistics hiện tại còn hint cố định thì không đổi khi dữ liệu thay đổi.

**Liên hệ README:** trên Databricks/Snowflake cũng vậy, tự partition theo cột có hàng triệu giá trị hay tự dựng index kiểu OLTP thường kém hơn clustering/micro-partitioning mà nền tảng tự làm. Phần đó không thử được trên MySQL, cần kiểm chứng bằng query profile của chính nền tảng.

---

## Tổng kết nhanh

| Mục | Triệu chứng | Công cụ phát hiện | Cách xử lý |
|---|---|---|---|
| 1. Execution plan | Query chậm, chưa rõ chỗ nào | `EXPLAIN`, `EXPLAIN ANALYZE` | Index đúng cột lọc |
| 2. Bộ nhớ | `Sort_merge_passes` > 0 | `SHOW STATUS LIKE 'Sort_merge_passes'` | Tăng `sort_buffer_size` theo session |
| 3. Query | `SELECT *`, subquery lặp, thiếu `ON`, sai kiểu | `EXPLAIN`, đọc code | Chọn cột, join, khớp kiểu |
| 4. Sargability | `type = ALL` dù có index | `EXPLAIN` | Viết lại thành range, bỏ hàm trên cột |
| 5. Reads/IOPS | `Innodb_buffer_pool_reads` cao | `SHOW GLOBAL STATUS`, `EXPLAIN ANALYZE` | Bảng tổng hợp (thay materialized view), cache |
| 6. Parameter sniffing | Cùng query, plan tốt nhất khác theo tham số | `EXPLAIN` với nhiều giá trị | `RECOMPILE` (SQL Server); MySQL tự tối ưu lại |
| 7. Transaction | Blocking, `ERROR 1205` | `sys.innodb_lock_waits` | Transaction ngắn, chia lô |
| 8. Partition | Quét cả bảng lớn theo khoảng thời gian | `EXPLAIN` (cột `partitions`) | `PARTITION BY RANGE COLUMNS` |
| 9. Statistics | `rows` lệch xa `actual rows`, `Cardinality` sai | `EXPLAIN ANALYZE`, `SHOW INDEX` | `ANALYZE TABLE` |
| 10. Nền tảng | Hint ép tay làm chậm hơn | `EXPLAIN ANALYZE` so hai bản | Để optimizer tự chọn |
