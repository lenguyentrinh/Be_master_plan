# Examples: Database Indexes

Mỗi slide (1 đến 6) có một ví dụ riêng, khớp với `slide_content.md`. Mặc định dùng PostgreSQL, trừ khi ghi chú khác. Các ví dụ dùng chung hai bảng `customers` và `orders` ở phần Setup. Mỗi ví dụ chạy độc lập; nếu trùng tên index thì `DROP INDEX` trước khi chạy lại.

## Setup

```sql
CREATE TABLE customers (
    id    serial PRIMARY KEY,
    email text NOT NULL,
    name  text
);

CREATE TABLE orders (
    id          serial PRIMARY KEY,
    customer_id int NOT NULL REFERENCES customers(id),
    status      text NOT NULL,
    total       numeric(10,2) NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ~100k khách hàng, ~1 triệu đơn hàng
INSERT INTO customers (email, name)
SELECT 'user' || g || '@example.com', 'User ' || g
FROM generate_series(1, 100000) g;

INSERT INTO orders (customer_id, status, total, created_at)
SELECT (random() * 99999)::int + 1,
       (ARRAY['pending','paid','shipped','cancelled'])[(random() * 3)::int + 1],
       (random() * 500)::numeric(10,2),
       now() - (random() * interval '365 days')
FROM generate_series(1, 1000000);

ANALYZE;
```

---

## Slide 1: Indexes

Ví dụ mở đầu: tìm một khách hàng theo email. Không có index thì DB phải đọc cả bảng; có index thì nhảy thẳng tới dòng cần tìm.

```sql
EXPLAIN SELECT * FROM customers WHERE email = 'user42@example.com';
-- Seq Scan on customers

CREATE INDEX idx_customers_email ON customers (email);

EXPLAIN SELECT * FROM customers WHERE email = 'user42@example.com';
-- Index Scan using idx_customers_email on customers
```

---

## Slide 2: What is an Index?

Đo cái giá phải trả: đọc nhanh hơn nhưng ghi chậm hơn và tốn dung lượng.

```sql
-- Trước khi có index
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 500;   -- Seq Scan

CREATE INDEX idx_orders_customer ON orders (customer_id);

-- Sau khi có index
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 500;   -- Index/Bitmap Scan

-- Dung lượng index phải trả thêm
SELECT pg_size_pretty(pg_relation_size('idx_orders_customer')) AS index_size,
       pg_size_pretty(pg_relation_size('orders'))              AS table_size;

-- Ghi chậm hơn: mỗi INSERT phải cập nhật thêm index
EXPLAIN ANALYZE
INSERT INTO orders (customer_id, status, total) VALUES (500, 'pending', 10);
```

Số "giảm I/O 10.000 lần" trong bài gốc chỉ là số minh họa; hãy so sánh `Execution Time` thực tế trên máy của bạn.

---

## Slide 3: What is a B-tree?

B-tree là loại index mặc định; unique index là một quy tắc chạy trên B-tree. Ví dụ dưới cho thấy unique index, và B-tree dùng được cho prefix nhưng không dùng được cho wildcard đứng đầu.

```sql
-- TH1: đã có giá trị trùng thì không tạo được unique index
INSERT INTO customers (email, name) VALUES ('dup@example.com', 'A'), ('dup@example.com', 'B');
CREATE UNIQUE INDEX idx_customers_email_u ON customers (email);
-- ERROR: could not create unique index ... Key (email)=(dup@example.com) is duplicated.

-- TH2: dọn dữ liệu trùng rồi tạo được; từ đó cột chặn giá trị trùng
DELETE FROM customers WHERE email = 'dup@example.com';
CREATE UNIQUE INDEX idx_customers_email_u ON customers (email);
INSERT INTO customers (email, name) VALUES ('user1@example.com', 'X');
-- ERROR: duplicate key value violates unique constraint

-- B-tree dùng được cho prefix, không dùng được cho wildcard đứng đầu
CREATE INDEX idx_customers_email_p ON customers (email text_pattern_ops);
EXPLAIN SELECT * FROM customers WHERE email LIKE 'user42%';          -- dùng index
EXPLAIN SELECT * FROM customers WHERE email LIKE '%42@example.com';  -- Seq Scan
```

---

## Slide 4: How Many Types of Index?

Mỗi loại index một câu lệnh tạo (8 loại; Full-text của MySQL và GIN/GiST của PostgreSQL gộp chung một loại vì cùng phục vụ tìm kiếm văn bản và dữ liệu đặc biệt, chỉ khác hệ DB).

```sql
CREATE INDEX        idx_orders_customer  ON orders (customer_id);                  -- 1. B-tree (mặc định)
CREATE UNIQUE INDEX idx_customers_email  ON customers (email);                     -- 2. Unique
CREATE INDEX        idx_orders_cust_date ON orders (customer_id, created_at);      -- 3. Composite
CREATE INDEX        idx_orders_pending   ON orders (created_at)
                    WHERE status = 'pending';                                      -- 5. Partial (PostgreSQL)
CREATE INDEX        idx_orders_cover     ON orders (customer_id)
                    INCLUDE (total, status);                                       -- 6. Covering
```

```sql
-- 4. Full-text / GIN / GiST
-- MySQL
CREATE FULLTEXT INDEX idx_articles_content ON articles (title, body);
SELECT * FROM articles WHERE MATCH(title, body) AGAINST('my name is');                       -- từ khóa không cần liền kề
SELECT * FROM articles WHERE MATCH(title, body) AGAINST('"my name is"' IN BOOLEAN MODE);     -- cả cụm từ
-- PostgreSQL
CREATE INDEX idx_articles_search ON articles USING gin (to_tsvector('english', title || ' ' || body));
SELECT id, title FROM articles
WHERE to_tsvector('english', title || ' ' || body) @@ plainto_tsquery('english', 'database design');    -- không cần liền kề
SELECT id, title FROM articles
WHERE to_tsvector('english', title || ' ' || body) @@ phraseto_tsquery('english', 'database design');   -- liền kề

-- PostgreSQL: GIN (JSONB, array, full-text) / GiST (hình học, range, khoảng cách)
CREATE INDEX idx_products_tags       ON products  USING gin  (tags);
CREATE INDEX idx_locations_coords    ON locations USING gist (coordinates);
```

```sql
-- 7. Clustered: quy định thứ tự vật lý, mỗi bảng chỉ 1
-- MySQL (InnoDB): primary key chính là clustered index
CREATE TABLE orders (id BIGINT PRIMARY KEY, customer_id INT);
-- PostgreSQL không có clustered index thực sự; CLUSTER chỉ sắp xếp lại bảng một lần
CLUSTER orders USING idx_orders_customer;

-- 8. Non-clustered (MySQL gọi là secondary index): cấu trúc riêng trỏ về dòng dữ liệu, có thể có nhiều
CREATE INDEX idx_orders_customer ON orders (customer_id);
```

---

### Slide 4 (tiếp): thiết kế index: thứ tự cột, covering, JOIN, ORDER BY

Phần thiết kế index nằm trong slide 4 (không còn slide riêng). Một chuỗi ví dụ trên cùng bảng `orders`.

```sql
-- Composite + leftmost prefix
CREATE INDEX idx_orders_cust_date ON orders (customer_id, created_at);
EXPLAIN SELECT * FROM orders WHERE customer_id = 500;                                   -- dùng index (cột đầu)
EXPLAIN SELECT * FROM orders
WHERE customer_id = 500 AND created_at > now() - interval '30 days';                   -- dùng index (cả bộ key)
EXPLAIN SELECT * FROM orders WHERE created_at > now() - interval '30 days';            -- thường Seq Scan (vi phạm leftmost prefix)

-- Thứ tự cột: equality (customer_id, status) trước, range (created_at) sau
CREATE INDEX idx_orders_good ON orders (customer_id, status, created_at);
-- Kém hơn: cột range đứng giữa, cột sau nó không dùng được để lọc
CREATE INDEX idx_orders_bad  ON orders (customer_id, created_at, status);

-- Covering: không phải đọc bảng
CREATE INDEX idx_orders_cover ON orders (customer_id) INCLUDE (total, status);
VACUUM ANALYZE orders;   -- cần visibility map để Index Only Scan hiệu quả
EXPLAIN SELECT total, status FROM orders WHERE customer_id = 500;   -- Index Only Scan

-- JOIN: index khóa ngoại ở phía "many"; PK customers.id đã có index
EXPLAIN ANALYZE
SELECT c.name, o.total
FROM customers c JOIN orders o ON o.customer_id = c.id
WHERE c.id = 500;

-- ORDER BY: index khớp WHERE + ORDER BY thì bỏ được bước Sort
EXPLAIN SELECT * FROM orders WHERE customer_id = 500 ORDER BY created_at;   -- không có node "Sort"

-- GROUP BY: index cột nhóm, INCLUDE hỗ trợ hàm tổng hợp
CREATE INDEX idx_orders_status_cover ON orders (status) INCLUDE (total);
EXPLAIN SELECT status, SUM(total) FROM orders GROUP BY status;
```

---

## Slide 5: 7 Common Indexing Mistakes

Ví dụ cho lỗi số 3 (hàm bọc cột), cách sửa bằng expression index, lỗi số 5 (thiếu index khóa ngoại) và lỗi số 1.

```sql
-- Lỗi 3: hàm bọc cột làm index thường mất tác dụng
CREATE INDEX idx_customers_email ON customers (email);
EXPLAIN SELECT * FROM customers WHERE LOWER(email) = 'user42@example.com';   -- Seq Scan

-- Cách sửa: expression index
CREATE INDEX idx_customers_email_lower ON customers (LOWER(email));
EXPLAIN SELECT * FROM customers WHERE LOWER(email) = 'user42@example.com';   -- Index Scan

-- Lỗi 5: PostgreSQL không tự tạo index cho FK, phải tự tạo
CREATE INDEX idx_orders_customer ON orders (customer_id);

-- Lỗi 1: thay vì hai index đơn cột ...
-- CREATE INDEX i1 ON orders (customer_id);  CREATE INDEX i2 ON orders (created_at);
-- ... dùng một composite index khi query lọc cả hai cột
CREATE INDEX idx_orders_cust_date ON orders (customer_id, created_at);
```

---

## Slide 6: How Do I Know an Index Is Used?

```sql
-- EXPLAIN: kế hoạch dự đoán, không chạy query (PostgreSQL và MySQL đều có)
EXPLAIN SELECT * FROM orders WHERE customer_id = 500;

-- EXPLAIN ANALYZE: chạy query thật, cho số dòng và thời gian thực tế (PostgreSQL; MySQL từ 8.0.18)
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 500;
```

Cách đọc plan (PostgreSQL), so sánh trước/sau khi `CREATE INDEX idx_orders_customer ON orders (customer_id)`:

```text
Trước:  Seq Scan on orders        Filter: (customer_id = 500)
Sau:    Index Scan using idx_orders_customer on orders   Index Cond: (customer_id = 500)
```

Cách đọc kết quả (MySQL): nhìn cột `key` và `type`.

```text
Trước:  type = ALL     key = NULL                    (quét toàn bảng)
Sau:    type = ref     key = idx_orders_customer     (có dùng index)
```

Kiểm tra index có được dùng và bảo trì:

```sql
-- Index nào đã được dùng bao nhiêu lần (PostgreSQL)
SELECT indexrelname, idx_scan FROM pg_stat_user_indexes WHERE relname = 'orders';

-- Liệt kê index chưa từng được dùng
SELECT schemaname, relname AS table_name, indexrelname AS index_name,
       idx_scan, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

ANALYZE orders;                                       -- cập nhật thống kê
REINDEX INDEX CONCURRENTLY idx_orders_customer;       -- rebuild, nên chạy giờ thấp điểm
-- DROP INDEX CONCURRENTLY idx_unused;                -- xóa index không dùng (sau khi chắc chắn)
```

Lưu ý: test với dữ liệu cỡ thực tế. Với bảng vài chục dòng, optimizer vẫn chọn Seq Scan dù có index.
