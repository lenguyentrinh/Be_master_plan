# Indexes

- **Domain:** Database
- **Week:** Week 1-4

## Reference
- [SQL Indexing Best Practices: The Complete Guide (2026) | AI2SQL](https://builder.ai2sql.io/blog/sql-indexing-best-practices)

## Key concepts

### 1. Index là gì
- Index giúp database tìm dòng dữ liệu mà không phải quét toàn bộ bảng (full table scan).
- Đánh đổi: **đọc nhanh hơn, ghi chậm hơn** (mỗi INSERT/UPDATE/DELETE phải cập nhật cả index) và tốn thêm bộ nhớ/ổ đĩa.
- Ví dụ trong bài: B-tree index trên `customer_id` của bảng 1 triệu dòng giảm I/O khoảng 10.000 lần (số liệu minh họa của bài viết, không phải benchmark).

### 2. Các loại index

| Loại | Dùng khi | Lưu ý |
|---|---|---|
| **B-tree** (mặc định) | So sánh bằng, range, sort, `LIKE 'abc%'` | Không dùng được cho `LIKE '%abc'` (wildcard đứng đầu) |
| **Unique** | Chống trùng giá trị | Primary key tự tạo unique index |
| **Composite** (nhiều cột) | Query lọc/sắp xếp theo nhiều cột | Thứ tự cột quan trọng, theo quy tắc *leftmost prefix* |
| **Partial / Filtered** | Chỉ cần index một phần dòng (`WHERE ...`) | PostgreSQL gọi là partial, SQL Server gọi là filtered; index nhỏ hơn |
| **Full-text** | Tìm kiếm văn bản | MySQL `FULLTEXT`; PostgreSQL GIN trên `to_tsvector` |
| **GIN / GiST** (PostgreSQL) | GIN: JSONB, array, full-text. GiST: dữ liệu hình học, range, tìm theo khoảng cách | |
| **Covering** | Index chứa đủ mọi cột query cần, không phải đọc bảng | Dùng `INCLUDE` (SQL Server, PostgreSQL 11+) |
| **Clustered** | Quy định thứ tự vật lý của dòng; mỗi bảng chỉ có 1 | Bài viết chỉ nhắc ở phần FAQ |
| **Non-clustered** | Cấu trúc riêng, trỏ về dòng dữ liệu | Có thể có nhiều index loại này |

```sql
-- B-tree (mặc định)
CREATE INDEX idx_orders_customer ON orders (customer_id);

-- Unique
CREATE UNIQUE INDEX idx_users_email ON users (email);

-- Composite: equality trước, range sau
CREATE INDEX idx_orders_cust_date ON orders (customer_id, created_at);

-- Partial (PostgreSQL)
CREATE INDEX idx_orders_pending ON orders (created_at) WHERE status = 'pending';

-- Covering (PostgreSQL 11+ / SQL Server)
CREATE INDEX idx_orders_cover ON orders (customer_id) INCLUDE (total, status);
```

### 3. Thứ tự cột trong composite index
- Đặt các cột so sánh **bằng (equality)** trước, rồi tới cột **range** đầu tiên. Cột đứng sau điều kiện range không dùng được index.
- Giữa các cột equality, đặt cột có độ chọn lọc (selectivity) cao nhất trước.
- Leftmost prefix: index `(a, b, c)` dùng được cho `a`, `a,b`, `a,b,c` nhưng không dùng được cho riêng `b` hoặc `c`.

### 4. Covering index
- Nên dùng cho query chạy thường xuyên như dashboard, API endpoint, vì tránh phải quay lại đọc bảng.

### 5. Index cho JOIN
- Index cột foreign key ở phía "nhiều" (many). Primary key phía "một" đã có index sẵn.
- Khi JOIN kèm điều kiện lọc, đưa cả cột lọc vào composite index.

### 6. Index cho ORDER BY và GROUP BY
- Index khớp thứ tự cột của WHERE và ORDER BY có thể bỏ được bước sort. Hướng sắp xếp nên khớp, dù nhiều DB vẫn quét ngược được.
- GROUP BY dùng được index trên cột nhóm; cột `INCLUDE` hỗ trợ hàm tổng hợp.

### 7. Bảy lỗi thường gặp
1. Tạo nhiều index đơn cột thay vì một composite index.
2. Sai thứ tự cột composite (ví dụ đặt cột ít chọn lọc lên đầu).
3. Dùng hàm trên cột đã index (`LOWER()`, `YEAR()`), làm index mất tác dụng. Cách sửa: viết lại query hoặc dùng expression/computed index.
4. Quá nhiều index trên bảng ghi nhiều; cần xóa index không dùng.
5. Thiếu index cho foreign key. PostgreSQL không tự tạo, còn MySQL InnoDB thì có.
6. Bỏ qua NULL; partial index có thể giúp.
7. Không kiểm tra index có được dùng hay không (xem system view của PostgreSQL, MySQL, SQL Server).

### 8. Kiểm tra bằng EXPLAIN
- PostgreSQL: `EXPLAIN ANALYZE`; MySQL: `EXPLAIN`; SQL Server: actual execution plan và `SET STATISTICS IO ON`.
- Test với lượng dữ liệu thực tế, vì optimizer chọn plan khác nhau tùy kích thước bảng.

### 9. Bảo trì index
- Cập nhật thống kê (`ANALYZE` trong PostgreSQL), rebuild/reorganize index.
- Lên lịch bảo trì vào giờ thấp điểm.

## Q&A
- **Index làm gì, và cái giá phải trả?** Tăng tốc đọc nhưng làm chậm ghi và tốn dung lượng.
- **Loại index mặc định là gì, hỗ trợ truy vấn nào?** B-tree: bằng, range, sort, prefix `LIKE`; không hỗ trợ wildcard đứng đầu.
- **Index `(a, b, c)` có dùng được cho `WHERE b = 1` không?** Không, vì vi phạm leftmost prefix.
- **Tại sao `WHERE LOWER(email) = 'x'` không dùng index trên `email`?** Hàm bọc cột khiến DB không dùng được index thường; dùng expression index hoặc viết lại query.
- **Clustered khác non-clustered thế nào?** Clustered quy định thứ tự vật lý của dòng, chỉ có 1 trên mỗi bảng. Non-clustered là cấu trúc riêng trỏ tới dòng.
- **Covering index là gì, khi nào dùng?** Index chứa đủ cột query cần, không phải đọc bảng; dùng cho query chạy thường xuyên.
- **Một bảng nên có bao nhiêu index?** Tùy workload; bảng OLTP thường khoảng 3 đến 8. Bắt đầu từ cột trong WHERE, JOIN, ORDER BY rồi xóa index không dùng.
- **Làm sao biết index có được dùng?** Dùng `EXPLAIN` / `EXPLAIN ANALYZE` và system view thống kê sử dụng index.

## Hands-on
- [ ] Tạo bảng `orders` khoảng 1 triệu dòng, so sánh `EXPLAIN ANALYZE` trước và sau khi tạo index trên `customer_id`
- [ ] Thử composite index với hai thứ tự cột khác nhau và so sánh plan
- [ ] Chứng minh leftmost prefix: query chỉ lọc theo cột thứ hai của index
- [ ] Viết query có `LOWER(email)`, rồi sửa bằng expression index
- [ ] Tạo covering index với `INCLUDE` và kiểm tra plan có "Index Only Scan"
- [ ] Tạo partial index cho `status = 'pending'` và so sánh kích thước index
- [ ] Liệt kê index không được dùng bằng system view

## Done
- [ ] Read reference
- [ ] Notes written
- [ ] Practice done

## Slide
- Link: 
