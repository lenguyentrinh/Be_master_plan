# Indexes

- **Domain:** Database
- **Week:** Week 1-4

## Reference
- [SQL Indexing Best Practices: The Complete Guide (2026) | AI2SQL](https://builder.ai2sql.io/blog/sql-indexing-best-practices)

## Key concepts

### 1. Index là gì
- Index là một cấu trúc dữ liệu phụ
- Index giúp database tìm dòng dữ liệu mà không phải quét toàn bộ bảng (full table scan).
- Đánh đổi: **đọc nhanh hơn, ghi chậm hơn** (mỗi INSERT/UPDATE/DELETE phải cập nhật cả index) và tốn thêm bộ nhớ/ổ đĩa.


### 2. Các loại index

| Loại | Dùng khi | Lưu ý |
|---|---|---|
| **B-tree** (mặc định) | So sánh bằng (`email = 'alice@example.com'`), range (`age BETWEEN 10 AND 20`), sort (`ORDER BY email LIMIT 10`), `LIKE 'abc%'` (prefix) | Không dùng được cho `LIKE '%abc'` (wildcard đứng đầu). `LIKE 'abc%'`: MySQL dùng index trực tiếp; PostgreSQL cần operator class `text_pattern_ops` (hoặc collation "C") |
| **Unique** | Chống trùng giá trị | Primary key tự tạo unique index |
| **Composite** (nhiều cột) | Query lọc/sắp xếp theo nhiều cột | Thứ tự cột quan trọng, theo quy tắc *leftmost prefix* |
| **Partial** | Chỉ cần index một phần dòng (`WHERE ...`) | PostgreSQL hỗ trợ; MySQL không hỗ trợ; index nhỏ hơn |
| **Full-text / GIN / GiST** | Tìm kiếm văn bản, JSONB, array, dữ liệu hình học | MySQL: `FULLTEXT`. PostgreSQL: GIN (full-text, JSONB, array), GiST (hình học, range, tìm theo khoảng cách). Gộp chung một loại vì hai bên dùng cơ chế khác nhau |
| **Covering** | Index chứa đủ mọi cột query cần, không phải đọc bảng | PostgreSQL 11+ dùng `INCLUDE`; MySQL không có `INCLUDE`, đưa cột cần thêm vào composite index |
| **Clustered** | Quy định thứ tự vật lý của dòng; mỗi bảng chỉ có 1 | Bài viết chỉ nhắc ở phần FAQ |
| **Non-clustered** | Cấu trúc riêng, trỏ về dòng dữ liệu | Có thể có nhiều index loại này |

```sql
-- B-tree cấu trúc index (mặc định)
CREATE INDEX idx_orders_customer ON orders (customer_id);
-- TH đặc biệt: nếu có nhiều key trùng nhau thì sẽ tìm kiếm ở node cha chứa key đó và sẽ tìm leaf node liền kề.

-- Unique là quy tắc (B-tree)
CREATE UNIQUE INDEX idx_users_email ON users (email);
-- TH1: Nếu có sự trùng lặp ở column đó thì không thể tạo unique index cho column.
-- TH2: Nếu ban đầu chưa có giá trị trùng nhau thì có thể tạo unique index, cùng với đó column sẽ restrict việc thêm giá trị trùng lặp.

-- Composite: equality trước, range sau (1 key gồm nhiều column)
CREATE INDEX idx_orders_cust_date ON orders (customer_id, created_at);
-- Composite index sẽ sắp xếp theo column đầu tiên trước, nếu có sự trùng lặp ở column đầu tiên thì mới dựa vào column tiếp theo để sắp xếp.
-- Khi tìm kiếm thì nó sẽ ưu tiên column trước, sau đó mới check column sau.
-- Composite index chỉ có tác dụng khi mình tìm kiếm bộ key hoặc tìm kiếm column đầu tiên. Nếu tìm kiếm theo column tiếp theo thì nó không có tác dụng được, bởi vì nó phải tìm kiếm tuần tự theo column, không thể bỏ qua column đầu tiên để tìm kiếm column tiếp theo.

-- Partial (PostgreSQL) : tạo cấu trúc phụ cho một số record thỏa mãn điều kiện nhất định, không phải tất cả các record trong bảng (MySQL không hỗ trợ where khi tạo index)
CREATE INDEX idx_orders_pending ON orders (created_at) WHERE status = 'pending';

-- Full-text: tokenize nội dung văn bản, hỗ trợ tìm kiếm ngôn ngữ tự nhiên
-- MySQL
CREATE FULLTEXT INDEX idx_articles_content ON articles (title, body);
-- TH1: tìm keywork nhưng từ khóa không cần liền kề
SELECT * FROM articles WHERE MATCH(title, body) AGAINST('my name is');
-- TH2: tìm keywork nhưng làm một cụm từ
SELECT * FROM articles WHERE MATCH(title, body) AGAINST('"my name is"' IN BOOLEAN MODE);

-- PostgreSQL
CREATE INDEX idx_articles_search ON articles USING gin (to_tsvector('english', title || ' ' || body));
-- TH1:  không cần liền kề
SELECT id, title, body FROM articles WHERE to_tsvector('english', title || ' ' || body) @@ plainto_tsquery('english', 'database design');
-- TH2: liền kề
SELECT id, title, body FROM articles WHERE to_tsvector('english', title || ' ' || body) @@ phraseto_tsquery('english', 'database design');
-- Biểu thức trong query phải giống hệt biểu thức lúc tạo index thì GIN mới được dùng.


-- GIN / GiST (PostgreSQL)
-- GIN: cho JSONB, array, full-text
CREATE INDEX idx_products_tags ON products USING gin (tags);
-- GiST: cho dữ liệu hình học, range, truy vấn theo khoảng cách
CREATE INDEX idx_locations_coords ON locations USING gist (coordinates);

-- Covering (PostgreSQL 11+): nó sẽ giúp việc lấy giá trị cột khác đã được cover lúc tạo covering index mà không cần refer đến bảng chính. (các cột cover không dùng để sắp xếp)
CREATE INDEX idx_orders_cover ON orders (customer_id) INCLUDE (total, status);
```

### 3. Thứ tự cột trong composite index
- Đặt các cột so sánh **bằng (equality)** trước, rồi tới cột **range** đầu tiên. Cột đứng sau điều kiện range không dùng được index.
- Giữa các cột equality, đặt cột có độ chọn lọc (selectivity) cao nhất trước (quy tắc kinh nghiệm, không phải luật tuyệt đối).
- Leftmost prefix: index `(a, b, c)` dùng được cho `a`, `a,b`, `a,b,c` nhưng thường không dùng được cho riêng `b` hoặc `c` (PostgreSQL 18+ đôi khi làm được nhờ skip scan).

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
7. Không kiểm tra index có được dùng hay không (xem system view của PostgreSQL, MySQL).

### 8. Kiểm tra bằng EXPLAIN
- `EXPLAIN`: cho kế hoạch dự đoán, không chạy query; dùng để biết index có được dùng hay không (PostgreSQL và MySQL đều có).
- `EXPLAIN ANALYZE`: chạy query thật, cho số dòng và thời gian thực tế (PostgreSQL; MySQL từ 8.0.18). Cẩn thận với INSERT, UPDATE, DELETE.
- Đọc kết quả: PostgreSQL xem Index Scan / Index Only Scan so với Seq Scan; MySQL xem cột `key` và `type` (`ALL` là quét toàn bảng).
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
