# Query optimization

- **Domain:** Database
- **Week:** Week 1-4

## Reference
- [SQL Query Optimization: 15 Techniques for Better Performance | DataCamp](https://www.datacamp.com/blog/sql-query-optimization)

## Key concepts

### 1. Đo trước khi tối ưu (kỹ thuật 5, 11)
- Dùng `EXPLAIN` để xem DB chạy query thế nào: có full table scan không, join kiểu gì, tốn bao nhiêu cho sort, có tạo bảng tạm không.
- Optimizer chọn plan dựa trên **statistics**; statistics cũ thì plan tệ. Cập nhật bằng `ANALYZE` (PostgreSQL) hoặc `UPDATE STATISTICS` (SQL Server).
- Cập nhật tự động: SQL Server tự cập nhật khi dữ liệu đổi nhiều; PostgreSQL có auto-analyze chạy khi số thay đổi vượt ngưỡng.
- Cập nhật thủ công: `ANALYZE;` (tất cả bảng) hoặc `ANALYZE my_table;` (PostgreSQL); `UPDATE STATISTICS` cho bảng hoặc index (SQL Server).

```sql
EXPLAIN SELECT id, total FROM orders WHERE customer_id = 42;
ANALYZE orders; -- PostgreSQL: cập nhật statistics
```

### 2. Đọc ít dữ liệu hơn (kỹ thuật 1, 2, 3, 6)
- **Index:** đánh index cột hay dùng để lọc/join, tránh full scan. Đánh đổi: ghi chậm hơn, nên không đánh quá nhiều.
  - **Clustered:** sắp xếp vật lý dữ liệu của bảng, hợp với dữ liệu tuần tự không trùng như primary key.
  - **Non-clustered:** cấu trúc riêng trỏ về dòng dữ liệu.
  - **Full-text:** tìm trong các cột text dài.
  - Dùng **B-tree** cho tìm kiếm theo range.
- **Không dùng `SELECT *`:** chỉ lấy cột cần để giảm dữ liệu đọc, truyền và giữ trong bộ nhớ.
- **`LIMIT`:** dùng khi chỉ cần xem/kiểm tra kết quả (không dùng khi cần toàn bộ dữ liệu).
- **Tối ưu `WHERE`:** lọc sớm; không bọc hàm quanh cột đã index vì index sẽ mất tác dụng.
- Toán tử `=` thường nhanh hơn `LIKE`; so sánh theo khoảng ngày tốt hơn dùng hàm như `MONTH(order_date)`.

```sql
-- Không tốt: SELECT *, hàm trên cột đã index
SELECT * FROM users WHERE YEAR(created_at) = 2025;
-- Tốt hơn: chỉ lấy cột cần, so sánh range để dùng được index
SELECT id, email FROM users
WHERE created_at >= '2025-01-01' AND created_at < '2026-01-01';
```

### 3. JOIN và subquery (kỹ thuật 4, 7, 8)
- Chọn đúng loại join, join tập nhỏ trước, đánh index cột join.
  - **Inner join:** chỉ trả các dòng khớp ở cả hai bảng.
  - **Outer join:** trả tất cả dòng của một bên kèm dòng khớp bên kia; không khớp thì cột là NULL (bài dùng `FULL OUTER JOIN`).
  - **Left / Right join:** giữ tất cả dòng của bảng bên trái / phải, cột bảng còn lại là NULL nếu không khớp.
  - Chọn sai loại join có thể sinh dòng trùng và làm query chậm.
- Subquery: ưu tiên thay bằng join hoặc CTE (dễ đọc); ưu tiên **uncorrelated** hơn **correlated** (correlated chạy lại cho từng dòng của query ngoài).
- `EXISTS` thay `IN` khi subquery trả nhiều dòng, vì `EXISTS` dừng ở dòng khớp đầu tiên, còn `IN` phải tính xong toàn bộ kết quả subquery rồi mới so sánh.

```sql
-- IN với subquery lớn
SELECT * FROM customers WHERE id IN (SELECT customer_id FROM orders);
-- EXISTS: dừng khi tìm thấy dòng khớp đầu tiên
SELECT c.id FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
```

### 4. Tránh thao tác tốn kém không cần thiết (kỹ thuật 9, 13, 14)
- **`DISTINCT`:** hạn chế; khử trùng lặp từ lúc làm sạch dữ liệu, hoặc dùng `GROUP BY` / window function (`ROW_NUMBER`).
- **`ORDER BY` / `GROUP BY`:** chỉ dùng khi cần; có thể đánh index cho các cột đó, hoặc sort ở tầng application.
  - Pre-aggregate dữ liệu từ sớm hoặc dùng materialized view để không phải tính lại phép tổng hợp.
- **`UNION ALL` thay `UNION`:** `UNION ALL` bỏ bước khử trùng lặp, dùng khi chấp nhận trùng hoặc chắc chắn không có trùng.

```sql
SELECT id FROM orders_2024
UNION ALL -- không tốn bước khử trùng lặp
SELECT id FROM orders_2025;
```

### 5. Cấu trúc và tính năng riêng của DB (kỹ thuật 10, 12, 15)
- **Query hint:** ép optimizer dùng cách cụ thể (`USE INDEX` của MySQL, `OPTION (LOOP JOIN)` của SQL Server); dùng thận trọng.
- **Partitioning:** chia một bảng theo partition key. **Sharding:** chia một database ra nhiều server theo sharding key.
- **Stored procedure:** logic SQL dùng lại, lưu và biên dịch sẵn trong DB.
- **Chia nhỏ query phức tạp:** tách thành nhiều bước; dùng **materialized view** lưu sẵn kết quả (cần refresh khi dữ liệu gốc đổi).

```sql
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT created_at::date AS day, SUM(total) AS revenue
FROM orders GROUP BY 1;
REFRESH MATERIALIZED VIEW daily_revenue; -- PostgreSQL
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
