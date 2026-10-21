# Examples: Database Indexes

Mỗi slide (1 đến 13) có một ví dụ riêng. Mặc định dùng PostgreSQL, trừ khi ghi chú khác. Các ví dụ dùng chung hai bảng `customers` và `orders` ở phần Setup.

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

## Slide 1: Database Indexes

Tìm một khách hàng theo email. Không có index thì DB phải đọc cả bảng; có index thì nhảy thẳng tới dòng cần tìm.

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

## Slide 3: Index Types at a Glance

Mỗi loại index một câu lệnh tạo.

```sql
CREATE INDEX        idx_orders_customer  ON orders (customer_id);                  -- B-tree (mặc định)
CREATE UNIQUE INDEX idx_customers_email  ON customers (email);                     -- Unique
CREATE INDEX        idx_orders_cust_date ON orders (customer_id, created_at);      -- Composite
CREATE INDEX        idx_orders_pending   ON orders (created_at)
                    WHERE status = 'pending';                                      -- Partial
CREATE INDEX        idx_orders_cover     ON orders (customer_id)
                    INCLUDE (total, status);                                       -- Covering
-- Full-text / GIN / GiST: xem slide 6
-- Clustered / Non-clustered: xem slide 7
```

---

## Slide 4: B-tree and Unique Index

Unique index chặn dữ liệu trùng, và không tạo được nếu cột đã có trùng.

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
EXPLAIN SELECT * FROM customers WHERE email LIKE 'user42%';   -- dùng index
EXPLAIN SELECT * FROM customers WHERE email LIKE '%42@example.com';  -- Seq Scan
```

---

## Slide 5: Composite Index and Leftmost Prefix

Index `(customer_id, created_at)`: truy vấn nào dùng được?

```sql
CREATE INDEX idx_orders_cust_date ON orders (customer_id, created_at);

-- Dùng được: cột đầu
EXPLAIN SELECT * FROM orders WHERE customer_id = 500;

-- Dùng được: cả bộ key
EXPLAIN SELECT * FROM orders
WHERE customer_id = 500 AND created_at > now() - interval '30 days';

-- Không dùng hiệu quả: chỉ lọc theo cột thứ hai (vi phạm leftmost prefix)
EXPLAIN SELECT * FROM orders WHERE created_at > now() - interval '30 days';
-- thường là Seq Scan
```

---

## Slide 6: Partial, Full-text, GIN and GiST

```sql
-- Partial: chỉ index các đơn đang pending, index nhỏ hơn nhiều
CREATE INDEX idx_orders_pending ON orders (created_at) WHERE status = 'pending';
EXPLAIN SELECT * FROM orders WHERE status = 'pending' ORDER BY created_at LIMIT 20;

-- Full-text (PostgreSQL): GIN trên to_tsvector
CREATE TABLE articles (id serial PRIMARY KEY, title text, body text);
CREATE INDEX idx_articles_search ON articles
USING gin (to_tsvector('english', title || ' ' || body));
SELECT * FROM articles
WHERE to_tsvector('english', title || ' ' || body) @@ to_tsquery('english', 'index & postgres');

-- GIN cho JSONB / array
CREATE TABLE products (id serial PRIMARY KEY, tags text[], attrs jsonb);
CREATE INDEX idx_products_tags ON products USING gin (tags);
SELECT * FROM products WHERE tags @> ARRAY['sql'];

-- GiST cho dữ liệu hình học / khoảng cách
CREATE TABLE locations (id serial PRIMARY KEY, name text, coordinates point);
CREATE INDEX idx_locations_coords ON locations USING gist (coordinates);
SELECT * FROM locations ORDER BY coordinates <-> point '(10.77, 106.69)' LIMIT 5;

-- MySQL tương đương full-text:
-- CREATE FULLTEXT INDEX idx_articles_content ON articles (title, body);
```

---

## Slide 7: Covering, Clustered and Non-clustered

```sql
-- Covering: INCLUDE các cột query cần, không phải đọc bảng
CREATE INDEX idx_orders_cover ON orders (customer_id) INCLUDE (total, status);
VACUUM ANALYZE orders;   -- cần visibility map để Index Only Scan hiệu quả

EXPLAIN SELECT total, status FROM orders WHERE customer_id = 500;
-- Index Only Scan using idx_orders_cover

-- Truy vấn lấy thêm cột không nằm trong index thì phải đọc bảng
EXPLAIN SELECT * FROM orders WHERE customer_id = 500;   -- Index Scan + đọc heap
```

```sql
-- Clustered (SQL Server): quy định thứ tự vật lý, mỗi bảng chỉ 1
CREATE CLUSTERED INDEX cix_orders_id ON orders (id);
-- Non-clustered: nhiều index, mỗi index trỏ về dòng dữ liệu
CREATE NONCLUSTERED INDEX ix_orders_customer ON orders (customer_id);

-- PostgreSQL không có clustered index thực sự; CLUSTER chỉ sắp xếp lại bảng một lần
CLUSTER orders USING idx_orders_customer;
```

---

## Slide 8: Column Order in Composite Indexes

Cùng truy vấn `customer_id = ? AND status = ? AND created_at > ?`, thứ tự cột khác nhau cho plan khác nhau.

```sql
-- Đúng: equality (customer_id, status) trước, range (created_at) sau
CREATE INDEX idx_orders_good ON orders (customer_id, status, created_at);

-- Kém: cột range đứng giữa, cột sau nó không dùng được để lọc
CREATE INDEX idx_orders_bad ON orders (customer_id, created_at, status);

EXPLAIN ANALYZE
SELECT * FROM orders
WHERE customer_id = 500 AND status = 'paid' AND created_at > now() - interval '90 days';
-- So sánh Index Cond của hai index (xóa lần lượt từng index để thấy plan thay đổi)
```

---

## Slide 9: Indexes for JOIN, ORDER BY, GROUP BY

```sql
-- JOIN: index khóa ngoại ở phía "many" (orders.customer_id); PK customers.id đã có index
CREATE INDEX idx_orders_customer ON orders (customer_id);
EXPLAIN ANALYZE
SELECT c.name, o.total
FROM customers c JOIN orders o ON o.customer_id = c.id
WHERE c.id = 500;

-- JOIN + lọc: đưa cột lọc vào composite index
CREATE INDEX idx_orders_cust_status ON orders (customer_id, status);

-- ORDER BY: index khớp WHERE + ORDER BY thì bỏ được bước Sort
CREATE INDEX idx_orders_cust_date ON orders (customer_id, created_at);
EXPLAIN SELECT * FROM orders WHERE customer_id = 500 ORDER BY created_at;
-- không có node "Sort"

-- GROUP BY: index cột nhóm, INCLUDE hỗ trợ hàm tổng hợp
CREATE INDEX idx_orders_status_cover ON orders (status) INCLUDE (total);
EXPLAIN SELECT status, SUM(total) FROM orders GROUP BY status;
```

---

## Slide 10: 7 Common Indexing Mistakes

Ví dụ cho lỗi số 3 (hàm bọc cột), cách sửa bằng expression index, và lỗi số 5 (thiếu index khóa ngoại).

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

## Slide 11: Verify with EXPLAIN

```sql
-- PostgreSQL
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 500;

-- MySQL
EXPLAIN SELECT * FROM orders WHERE customer_id = 500;

-- SQL Server
SET STATISTICS IO ON;
SELECT * FROM orders WHERE customer_id = 500;
-- bật "Include Actual Execution Plan" trong SSMS
```

Cách đọc plan (PostgreSQL), so sánh trước/sau khi `CREATE INDEX idx_orders_customer ON orders (customer_id)`:

```text
Trước:  Seq Scan on orders        Filter: (customer_id = 500)
Sau:    Index Scan using idx_orders_customer on orders   Index Cond: (customer_id = 500)
```

Lưu ý: test với dữ liệu cỡ thực tế. Với bảng vài chục dòng, optimizer vẫn chọn Seq Scan dù có index.

---

## Slide 12: Index Maintenance

```sql
-- Cập nhật thống kê cho optimizer
ANALYZE orders;

-- Rebuild index (PostgreSQL); nên chạy giờ thấp điểm
REINDEX INDEX CONCURRENTLY idx_orders_customer;

-- SQL Server: reorganize / rebuild
-- ALTER INDEX ix_orders_customer ON orders REORGANIZE;
-- ALTER INDEX ix_orders_customer ON orders REBUILD;

-- Liệt kê index chưa từng được dùng (PostgreSQL)
SELECT schemaname, relname AS table_name, indexrelname AS index_name,
       idx_scan, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Xóa index không dùng (sau khi chắc chắn)
-- DROP INDEX CONCURRENTLY idx_unused;
```

---

## Slide 13: Quick Q&A Recap

Trả lời nhanh bằng ví dụ chạy được.

```sql
-- Q: Index (a, b, c) có dùng được cho WHERE b = 1 không?
-- A: Không (leftmost prefix). Chứng minh:
CREATE TABLE t (a int, b int, c int);
INSERT INTO t SELECT i % 100, i % 1000, i FROM generate_series(1, 500000) i;
CREATE INDEX idx_t_abc ON t (a, b, c);
ANALYZE t;
EXPLAIN SELECT * FROM t WHERE a = 1;   -- dùng index
EXPLAIN SELECT * FROM t WHERE b = 1;   -- không dùng index hiệu quả

-- Q: Vì sao WHERE LOWER(email) = 'x' không dùng index trên email?
-- A: Hàm bọc cột. Dùng expression index:
CREATE INDEX idx_customers_email_lower ON customers (LOWER(email));

-- Q: Làm sao biết index có được dùng?
-- A: EXPLAIN ANALYZE, và view thống kê:
SELECT indexrelname, idx_scan FROM pg_stat_user_indexes WHERE relname = 'orders';
```
