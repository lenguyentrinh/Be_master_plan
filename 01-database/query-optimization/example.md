# Examples: Query Optimization

Mỗi slide (8 đến 13) có một ví dụ riêng, khớp với `slide_content.md`. Mặc định dùng PostgreSQL, trừ khi ghi chú khác. Các ví dụ dùng chung hai bảng `customers` và `orders` ở phần Setup. Mỗi ví dụ chạy độc lập; nếu trùng tên index hoặc view thì `DROP` trước khi chạy lại.

## Setup

```sql
CREATE TABLE customers (
    id    serial PRIMARY KEY,
    email text NOT NULL,
    name  text,
    city  text
);

CREATE TABLE orders (
    id          serial PRIMARY KEY,
    customer_id int NOT NULL REFERENCES customers(id),
    status      text NOT NULL,
    total       numeric(10,2) NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ~100k khách hàng, ~1 triệu đơn hàng
INSERT INTO customers (email, name, city)
SELECT 'user' || g || '@example.com', 'User ' || g,
       (ARRAY['Hanoi','Hue','Da Nang','Saigon'])[(random() * 3)::int + 1]
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

## Slide 8: Query Optimization

Ví dụ mở đầu: cùng một yêu cầu "tổng tiền của một khách hàng", đo thời gian thật bằng `EXPLAIN ANALYZE` để thấy tối ưu có tác dụng.

```sql
EXPLAIN ANALYZE SELECT sum(total) FROM orders WHERE customer_id = 42;
-- Seq Scan on orders (quét ~1 triệu dòng)

CREATE INDEX idx_orders_customer ON orders (customer_id);

EXPLAIN ANALYZE SELECT sum(total) FROM orders WHERE customer_id = 42;
-- Index Scan / Bitmap Heap Scan using idx_orders_customer, nhanh hơn rõ rệt
```

---

## Slide 9: Measure Before You Optimize

Statistics cũ làm optimizer ước lượng sai số dòng. Chèn nhiều dòng rồi so sánh ước lượng (`rows=`) và thực tế (`actual rows`) trước và sau `ANALYZE`.

```sql
-- Thêm nhiều đơn 'pending' mới, chưa ANALYZE
INSERT INTO orders (customer_id, status, total)
SELECT 1, 'pending', 10 FROM generate_series(1, 200000);

EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1;
-- So sánh rows= (ước lượng) với actual rows: lệch nhiều

ANALYZE orders;

EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1;
-- Ước lượng gần với thực tế hơn, plan hợp lý hơn
```

---

## Slide 10: Read Less Data

Bỏ `SELECT *`, bỏ hàm bọc cột đã index, so sánh theo khoảng ngày.

```sql
CREATE INDEX idx_orders_created ON orders (created_at);

-- Không tốt: SELECT * và hàm trên cột đã index (index không dùng được)
EXPLAIN ANALYZE
SELECT * FROM orders WHERE EXTRACT(YEAR FROM created_at) = 2026;
-- Seq Scan

-- Tốt hơn: chỉ lấy cột cần, so sánh range
EXPLAIN ANALYZE
SELECT id, total FROM orders
WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01';
-- Index / Bitmap Index Scan on idx_orders_created
```

---

## Slide 11: JOINs and Subqueries

Tìm khách hàng có ít nhất một đơn hàng: `IN` so với `EXISTS`, kèm index cột join.

```sql
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders (customer_id);

-- IN với subquery lớn
EXPLAIN ANALYZE
SELECT id FROM customers WHERE id IN (SELECT customer_id FROM orders);

-- EXISTS: dừng ở dòng khớp đầu tiên
EXPLAIN ANALYZE
SELECT c.id FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);

-- Join: chỉ lấy khách hàng có đơn (inner), hoặc tất cả khách hàng kèm đơn nếu có (left)
SELECT c.id, o.id AS order_id
FROM customers c LEFT JOIN orders o ON o.customer_id = c.id;
```

Ghi chú: PostgreSQL hiện đại thường tự viết lại `IN`/`EXISTS` thành cùng một plan (semi join); hãy so sánh bằng `EXPLAIN ANALYZE` trên DB của bạn.

---

## Slide 12: Avoid Costly Operations

Thay `DISTINCT` bằng `GROUP BY`, và `UNION` bằng `UNION ALL`.

```sql
-- DISTINCT trên dữ liệu lớn
EXPLAIN ANALYZE SELECT DISTINCT city FROM customers;

-- GROUP BY cho cùng kết quả
EXPLAIN ANALYZE SELECT city FROM customers GROUP BY city;

-- UNION: tốn thêm bước khử trùng lặp
EXPLAIN ANALYZE
SELECT id FROM orders WHERE status = 'paid'
UNION
SELECT id FROM orders WHERE status = 'shipped';

-- UNION ALL: hai tập này không giao nhau nên giữ nguyên kết quả mà nhanh hơn
EXPLAIN ANALYZE
SELECT id FROM orders WHERE status = 'paid'
UNION ALL
SELECT id FROM orders WHERE status = 'shipped';
```

---

## Slide 13: Database-Specific Features

Materialized view lưu sẵn kết quả tổng hợp, và partitioning chia bảng theo thời gian.

```sql
-- Materialized view: tính một lần, đọc nhiều lần
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT created_at::date AS day, sum(total) AS revenue
FROM orders GROUP BY 1;

SELECT * FROM daily_revenue ORDER BY day DESC LIMIT 7;

REFRESH MATERIALIZED VIEW daily_revenue; -- cần refresh khi dữ liệu gốc đổi

-- Partitioning (PostgreSQL): chia bảng theo khoảng thời gian
CREATE TABLE orders_part (
    id         bigserial,
    created_at timestamptz NOT NULL,
    total      numeric(10,2)
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2026 PARTITION OF orders_part
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- Hint (MySQL): ép dùng một index cụ thể, chỉ dùng khi thật sự cần
-- SELECT * FROM orders USE INDEX (idx_orders_created) WHERE created_at > '2026-01-01';
```
