# Query optimization

- **Domain:** Database
- **Week:** Week 1-4

## Reference
- [SQL Query Optimization: 15 Techniques for Better Performance | DataCamp](https://www.datacamp.com/blog/sql-query-optimization)

## Key concepts

### 1. Dùng index đúng cách (Use Proper Indexing)
- **Index:** đánh index cột hay dùng để lọc/join, tránh full scan. Đánh đổi: ghi chậm hơn, nên không đánh quá nhiều.
  - **Clustered:** sắp xếp vật lý dữ liệu của bảng, hợp với dữ liệu tuần tự không trùng như primary key.
  - **Non-clustered:** cấu trúc riêng trỏ về dòng dữ liệu.
  - **Full-text:** tìm trong các cột text dài.
  - Dùng **B-tree** cho tìm kiếm theo range.
  - Index lưu một bản sao đã sắp xếp của các cột được đánh index (giống mục lục thư viện), nên DB tìm dòng mà không phải quét cả bảng.
  - Nên đánh index cột hay được query, ví dụ `customer_id`, `item_id`; chọn loại index đúng với dữ liệu và query.
  - Index làm `SELECT` nhanh hơn nhưng `INSERT`, `UPDATE`, `DELETE` chậm hơn vì index phải cập nhật theo mỗi thay đổi.

```sql
-- Index cột hay query
CREATE INDEX index_customer_id ON customers (customer_id);
```

### 2. Tránh `SELECT *` (Avoid SELECT *)
- **Không dùng `SELECT *`:** chỉ lấy cột cần để giảm dữ liệu đọc, truyền và giữ trong bộ nhớ.

```sql
-- Chỉ lấy cột cần, thay vì SELECT * FROM products
SELECT product_id, product_name, product_price FROM products;
```

### 3. Tránh lấy dữ liệu thừa (Avoid Redundant or Unnecessary Data Retrieval)
- **`LIMIT`:** dùng khi chỉ cần xem/kiểm tra kết quả (không dùng khi cần toàn bộ dữ liệu).
  - Truy vấn càng chậm khi số dòng càng lớn, nên giới hạn cả dòng lẫn cột. `LIMIT` hợp để kiểm tra kết quả transform, không hợp cho model tự động cần toàn bộ dữ liệu.

```sql
-- LIMIT: xem nhanh 100 dòng
SELECT name FROM customers ORDER BY customer_group DESC LIMIT 100;
```

### 4. Dùng JOIN hiệu quả (Use Joins Efficiently)
- Chọn đúng loại join, join tập nhỏ trước, đánh index cột join.
  - **Inner join:** chỉ trả các dòng khớp ở cả hai bảng.
  - **Outer join:** trả tất cả dòng của một bên kèm dòng khớp bên kia; không khớp thì cột là NULL (bài dùng `FULL OUTER JOIN`).
  - **Left / Right join:** giữ tất cả dòng của bảng bên trái / phải, cột bảng còn lại là NULL nếu không khớp.
  - Chọn sai loại join có thể sinh dòng trùng và làm query chậm.
  - Sắp xếp thứ tự join hợp lý: bắt đầu từ bảng trả ít dòng nhất.

```sql
-- Inner join: chỉ dòng khớp ở cả hai bảng
SELECT o.order_id, c.name
FROM orders o INNER JOIN customers c ON o.customer_id = c.customer_id;

-- Left join: giữ tất cả khách hàng, order_id là NULL nếu chưa có đơn
SELECT c.name, o.order_id
FROM customers c LEFT JOIN orders o ON c.customer_id = o.customer_id;

-- CTE: tách bước "đơn 30 ngày gần đây" ra cho dễ đọc
WITH RecentOrders AS (
    SELECT customer_id, order_id FROM orders
    WHERE order_date >= DATE('now', '-30 days')
)
SELECT c.customer_name, ro.order_id
FROM customers c INNER JOIN RecentOrders ro ON c.customer_id = ro.customer_id;
```

### 5. Phân tích execution plan (Analyze Query Execution Plans)
- Dùng `EXPLAIN` để xem DB chạy query thế nào: có full table scan không, join kiểu gì, tốn bao nhiêu cho sort, có tạo bảng tạm không.
- Cách đọc plan, tìm điểm nghẽn:
  - **Full table scan:** thường do thiếu index hoặc `WHERE` chưa tốt.
  - **Join strategy kém:** DB chọn thuật toán join không tối ưu.
  - **Chi phí sort cao** và **dùng nhiều bảng tạm.**
- `EXPLAIN` / `EXPLAIN PLAN` có ở hầu hết DB; công cụ như DBeaver hiển thị plan dạng đồ họa.

```sql
EXPLAIN SELECT id, total FROM orders WHERE customer_id = 42;
```

### 6. Tối ưu mệnh đề `WHERE` (Optimize WHERE Clauses)
- **Tối ưu `WHERE`:** lọc sớm; không bọc hàm quanh cột đã index vì index sẽ mất tác dụng.
- Toán tử `=` thường nhanh hơn `LIKE`; so sánh theo khoảng ngày tốt hơn dùng hàm như `MONTH(order_date)`. 
+ TH1: like 'abc'  giong "="
+ TH2: like 'abc%' giong su dung range (so sanh trong 1 khoang)
+ TH3: like '%abc' khong co tac dung
- Hàm trên cột buộc DB tính hàm cho từng dòng rồi mới lọc, nên index không dùng hiệu quả. (Lưu ý: optimizer hiện đại tự sắp xếp thứ tự các điều kiện; điều quan trọng là điều kiện đó dùng được index.)

```sql
-- Không tốt: SELECT *, hàm trên cột đã index
SELECT * FROM users WHERE YEAR(created_at) = 2025;
-- Tốt hơn: chỉ lấy cột cần, so sánh range để dùng được index
SELECT id, email FROM users
WHERE created_at >= '2025-01-01' AND created_at < '2026-01-01';
```

Ví dụ thêm từ bài:

```sql
-- Hàm trên cột (không tốt) và cách viết lại bằng range (tốt hơn)
SELECT * FROM employees WHERE YEAR(hire_date) = 2020;
SELECT * FROM employees WHERE hire_date >= '2020-01-01' AND hire_date < '2021-01-01';

SELECT * FROM orders WHERE MONTH(order_date) = 12 AND YEAR(order_date) = 2023;
SELECT * FROM orders WHERE order_date >= '2023-12-01' AND order_date < '2024-01-01';
```

### 7. Tối ưu subquery (Optimize Subqueries)
- Subquery: ưu tiên thay bằng join hoặc CTE (dễ đọc); ưu tiên **uncorrelated** hơn **correlated** (correlated chạy lại cho từng dòng của query ngoài).
  - Subquery là query lồng trong `SELECT`, `INSERT`, `UPDATE`, `DELETE`; nhanh nếu dùng đúng, chậm nếu lạm dụng.
  - Join thường hiệu quả hơn subquery; CTE giúp tách code thành các phần nhỏ, dễ đọc, và đơn giản hóa join phức tạp.
  - **Uncorrelated** chạy độc lập và chỉ một lần; **correlated** chạy một lần cho mỗi dòng của query ngoài.

```sql
-- CTE tính tổng trước, lọc sau
WITH SalesCTE AS (
    SELECT salesperson_id, SUM(sales_amount) AS total_sales FROM sales GROUP BY salesperson_id
)
SELECT salesperson_id, total_sales FROM SalesCTE WHERE total_sales > 5000;
```

### 8. Dùng `EXISTS` thay `IN` cho subquery (Use EXISTS Instead of IN)
- `EXISTS` thay `IN` khi subquery trả nhiều dòng, vì `EXISTS` dừng ở dòng khớp đầu tiên, còn `IN` phải tính xong toàn bộ kết quả subquery rồi mới so sánh.

```sql
-- IN với subquery lớn
SELECT * FROM customers WHERE id IN (SELECT customer_id FROM orders);
-- EXISTS: dừng khi tìm thấy dòng khớp đầu tiên
SELECT c.id FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
```

Ví dụ thêm từ bài:

```sql
-- EXISTS kèm điều kiện lọc
SELECT * FROM orders o
WHERE EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id AND c.country = 'USA');
```

### 9. Hạn chế `DISTINCT` (Limit the use of DISTINCT)
- **`DISTINCT`:** hạn chế; khử trùng lặp từ lúc làm sạch dữ liệu, hoặc dùng `GROUP BY` / window function (`ROW_NUMBER`).
  - `DISTINCT` tốn tài nguyên với dữ liệu lớn. `GROUP BY` có thể hiệu quả hơn, nhất là khi có aggregate: `SELECT DISTINCT city FROM customers;` thành `SELECT city FROM customers GROUP BY city;`.

### 10. Tính năng riêng của DB (Leverage Database-Specific Features)
- **Query hint:** ép optimizer dùng cách cụ thể (`USE INDEX` của MySQL, `OPTION (LOOP JOIN)` của SQL Server); dùng thận trọng.
- **Partitioning:** chia một bảng theo partition key. **Sharding:** chia một database ra nhiều server theo sharding key.
  - Partition key thường là timestamp hoặc số nguyên; query được định tuyến tới partition liên quan. Sharding giúp phân tải ra nhiều server.

Ví dụ thêm từ bài:

```sql
-- Query hint
SELECT * FROM employees USE INDEX (idx_salary) WHERE salary > 50000;   -- MySQL: ép dùng index
SELECT * FROM orders INNER JOIN customers ON orders.customer_id = customers.id
OPTION (LOOP JOIN);                                                    -- SQL Server: chọn cách join
```

### 11. Theo dõi và cập nhật statistics (Monitor and Optimize Database Statistics)
- Optimizer chọn plan dựa trên **statistics**; statistics cũ thì plan tệ. Cập nhật bằng `ANALYZE` (PostgreSQL) hoặc `UPDATE STATISTICS` (SQL Server).
- Cập nhật tự động: SQL Server tự cập nhật khi dữ liệu đổi nhiều; PostgreSQL có auto-analyze chạy khi số thay đổi vượt ngưỡng.
- Cập nhật thủ công: `ANALYZE;` (tất cả bảng) hoặc `ANALYZE my_table;` (PostgreSQL); `UPDATE STATISTICS` cho bảng hoặc index (SQL Server).
- Statistics là thông tin về phân bố dữ liệu (số dòng, tần suất giá trị, độ trải). Statistics cũ có thể khiến optimizer chọn full table scan trong khi index scan nhanh hơn.

```sql
ANALYZE orders; -- PostgreSQL: cập nhật statistics
```

### 12. Dùng stored procedure (Utilize stored procedures)
- **Stored procedure:** logic SQL dùng lại, lưu và biên dịch sẵn trong DB.
  - Stored procedure nhận input, đọc/sửa dữ liệu, trả kết quả; nhờ biên dịch sẵn nên có thể nhanh hơn, và giúp code gọn hơn.

Ví dụ thêm từ bài:

```sql
-- Stored procedure (PostgreSQL)
CREATE OR REPLACE PROCEDURE insert_employee(emp_id INT, emp_first_name VARCHAR, emp_last_name VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO employees (employee_id, first_name, last_name)
    VALUES (emp_id, emp_first_name, emp_last_name);
END;
$$;
CALL insert_employee(101, 'John', 'Doe');
```

### 13. Tránh `ORDER BY` / `GROUP BY` không cần thiết (Avoid Unnecessary Ordering and Grouping)
- **`ORDER BY` / `GROUP BY`:** chỉ dùng khi cần; có thể đánh index cho các cột đó, hoặc sort ở tầng application.
  - Pre-aggregate dữ liệu từ sớm hoặc dùng materialized view để không phải tính lại phép tổng hợp.
  - Hai lệnh này tốn vì thường phải quét toàn bộ rồi sort hoặc tổng hợp; nên bỏ `ORDER BY` khi không cần.

### 14. `UNION ALL` thay `UNION` (Use UNION ALL Instead of UNION)
- **`UNION ALL` thay `UNION`:** `UNION ALL` bỏ bước khử trùng lặp, dùng khi chấp nhận trùng hoặc chắc chắn không có trùng.

```sql
SELECT id FROM orders_2024
UNION ALL -- không tốn bước khử trùng lặp
SELECT id FROM orders_2025;

```sql
-- UNION: khử trùng lặp nên chậm hơn
SELECT product_id FROM products WHERE category = 'Electronics'
UNION
SELECT product_id FROM products WHERE category = 'Books';

-- UNION ALL: giữ cả dòng trùng nên nhanh hơn
SELECT product_id FROM products WHERE category = 'Electronics'
UNION ALL
SELECT product_id FROM products WHERE category = 'Books';
```

### 15. Chia nhỏ query phức tạp (Break Down Complex Queries)
- **Chia nhỏ query phức tạp:** tách thành nhiều bước; dùng **materialized view** lưu sẵn kết quả (cần refresh khi dữ liệu gốc đổi).

```sql
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT created_at::date AS day, SUM(total) AS revenue
FROM orders GROUP BY 1;
REFRESH MATERIALIZED VIEW daily_revenue; -- PostgreSQL
```

Ví dụ thêm từ bài:

```sql
-- Materialized view
CREATE MATERIALIZED VIEW daily_sales AS
SELECT product_id, SUM(quantity) AS total_quantity FROM order_items GROUP BY product_id;
SELECT * FROM daily_sales;
```

## Q&A
- 

## Hands-on
- [ ] 

## Done
- [ ] Read reference
- [ ] Notes written
- [ ] Practice done

## Slide
- Link: 
