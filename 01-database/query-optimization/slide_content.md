# Slide content: Query Optimization

Nội dung từng slide của deck Canva, nối tiếp phần Indexes (slide 1 đến 7) nên bắt đầu từ slide 8. Gồm 6 slide: 1 slide tiêu đề và agenda + 5 slide nội dung, present khoảng 15 phút. Chữ trên slide bằng tiếng Anh, phần **Ghi chú** là speaker notes tiếng Việt. Nội dung bám theo các mục trong `README.md`; hai mục Q&A và Hands-on không làm slide.

Deck: https://www.canva.com/design/DAHYhGFyqoI/DXfLNbB4reodOOOhBwBHPQ/edit

| Slide | Câu hỏi cần trả lời | Mục trong README |
|---|---|---|
| 8 | Giới thiệu chủ đề và 5 phần sẽ trình bày | Toàn bộ README |
| 9 | Làm sao biết query đang chậm ở đâu? | 1. Đo trước khi tối ưu |
| 10 | Làm sao đọc ít dữ liệu hơn? | 2. Đọc ít dữ liệu hơn |
| 11 | JOIN và subquery viết thế nào cho hiệu quả? | 3. JOIN và subquery |
| 12 | Thao tác nào tốn kém và nên tránh? | 4. Tránh thao tác tốn kém |
| 13 | Có công cụ nào riêng của DB để hỗ trợ? | 5. Cấu trúc và tính năng riêng của DB |

---

## Slide 8: Query Optimization

- Backend Master Plan - Database (Week 1-4)
- 5 parts to cover in about 15 minutes

**Hình:** 5 thẻ agenda: 1 Measure first (EXPLAIN, statistics) | 2 Read less data | 3 JOINs and subqueries | 4 Avoid costly operations | 5 Database-specific features

**Ghi chú:** Chào mọi người. Phần này nói về tối ưu query, khoảng 15 phút, gồm 5 phần dựa trên bài 15 kỹ thuật của DataCamp. (1) Đo trước khi tối ưu bằng EXPLAIN và statistics. (2) Đọc ít dữ liệu hơn: index, SELECT *, LIMIT, WHERE. (3) JOIN và subquery. (4) Tránh các thao tác tốn kém: DISTINCT, ORDER BY, GROUP BY, UNION. (5) Các tính năng riêng của DB: hint, partitioning, sharding, stored procedure, materialized view. Mục tiêu là biết nhìn ra query chậm và biết cách sửa.

---

## Slide 9: Measure Before You Optimize

- EXPLAIN shows how the database will run a query
- Look for: full table scans, weak join strategy, high sort cost, temporary tables
- The optimizer picks plans from statistics; stale statistics mean bad plans
- Auto update: SQL Server on big data changes, PostgreSQL auto-analyze after a threshold
- Manual: ANALYZE (PostgreSQL), UPDATE STATISTICS (SQL Server)

**Hình:** Luồng 3 ô "Table statistics → Optimizer → Execution plan" và một dải cảnh báo "Stale statistics → wrong estimates → bad plan; Fix: ANALYZE / UPDATE STATISTICS"

**Ghi chú:** Nguyên tắc đầu tiên là đo trước khi sửa (kỹ thuật 5 và 11, khoảng 3 phút). EXPLAIN cho biết DB sẽ chạy query như thế nào. Cần chú ý full table scan (thường do thiếu index hoặc WHERE chưa tốt), cách join chưa hợp lý, chi phí sort cao và việc tạo bảng tạm. Optimizer chọn plan dựa trên statistics, nên statistics cũ sẽ cho plan tệ, ví dụ chọn sai index hoặc quét toàn bảng. SQL Server tự cập nhật khi dữ liệu đổi nhiều, PostgreSQL có auto-analyze khi vượt ngưỡng; khi cần có thể chạy ANALYZE hoặc UPDATE STATISTICS thủ công.

---

## Slide 10: Read Less Data

- Index frequently filtered and joined columns (B-tree for ranges); too many indexes slow writes
- Avoid SELECT *: fetch only the columns you need
- LIMIT when inspecting results, not when a model needs the full dataset
- WHERE: filter early, no functions on indexed columns; = is usually faster than LIKE
- YEAR(created_at) = 2025 → created_at >= '2025-01-01' AND created_at < '2026-01-01'

**Hình:** Hai query song song: ✗ SELECT * ... WHERE YEAR(created_at) = 2025 và ✓ SELECT id, email ... WHERE created_at >= ... AND < ...

**Ghi chú:** Ý chính: ít dữ liệu hơn thì nhanh hơn (kỹ thuật 1, 2, 3, 6, khoảng 3 phút). Index cột hay lọc và join giúp tránh full scan, nhưng đánh quá nhiều thì ghi chậm; có clustered, non-clustered, full-text và B-tree cho range. Không dùng SELECT *, chỉ lấy cột cần để giảm dữ liệu đọc, truyền và giữ trong bộ nhớ. LIMIT hữu ích khi kiểm tra kết quả nhưng không dùng khi cần toàn bộ dữ liệu. WHERE nên lọc sớm và không bọc hàm quanh cột đã index; so sánh theo khoảng ngày thay cho YEAR() hoặc MONTH(). Toán tử = thường nhanh hơn LIKE.

---

## Slide 11: JOINs and Subqueries

- Pick the right join: inner (matches only), outer (all rows + NULLs), left / right
- Wrong join type can create duplicates; join small result sets first; index join columns
- Prefer joins or CTEs over subqueries; uncorrelated over correlated (runs once per outer row)
- EXISTS over IN: EXISTS stops at the first match, IN builds the full subquery result first

**Hình:** Bốn ô: Inner / Outer / Left / Right join (hình Venn đơn giản); khung EXISTS vs IN

**Ghi chú:** JOIN và subquery (kỹ thuật 4, 7, 8, khoảng 3 phút). Inner join chỉ trả dòng khớp ở cả hai bảng; outer join trả tất cả dòng của một bên kèm dòng khớp bên kia, không khớp thì NULL; left/right giữ toàn bộ bảng bên trái/phải. Chọn sai loại join có thể sinh dòng trùng và chậm. Nên join tập nhỏ trước và đánh index cột join. Với subquery: ưu tiên thay bằng join hoặc CTE cho dễ đọc, ưu tiên uncorrelated vì correlated chạy lại cho từng dòng của query ngoài. Với dữ liệu lớn, EXISTS thường tốt hơn IN vì dừng ngay ở dòng khớp đầu tiên, trong khi IN phải tính xong toàn bộ kết quả subquery.

---

## Slide 12: Avoid Costly Operations

- DISTINCT: dedupe during data cleaning, or use GROUP BY / window functions (ROW_NUMBER)
- ORDER BY / GROUP BY: only when needed; index those columns or sort in the application
- Pre-aggregate earlier or use a materialized view to skip recomputing
- UNION ALL instead of UNION when duplicates are acceptable or impossible

**Hình:** 3 thẻ: DISTINCT → GROUP BY | ORDER BY / GROUP BY → index / pre-aggregate | UNION → UNION ALL

**Ghi chú:** Một số thao tác rất tốn kém nên chỉ dùng khi cần (kỹ thuật 9, 13, 14, khoảng 3 phút). DISTINCT trên dữ liệu lớn tốn tài nguyên; nên khử trùng lặp từ lúc làm sạch dữ liệu, hoặc dùng GROUP BY, hoặc window function như ROW_NUMBER. ORDER BY và GROUP BY buộc DB quét, sắp xếp và tổng hợp; chỉ dùng khi cần, đánh index các cột đó, có thể sort ở tầng application, hoặc tổng hợp sẵn bằng materialized view. UNION khử trùng lặp nên thêm thời gian; UNION ALL giữ tất cả dòng nên nhanh hơn khi chấp nhận trùng hoặc chắc chắn không trùng.

---

## Slide 13: Database-Specific Features

- Query hints override the optimizer (MySQL USE INDEX, SQL Server OPTION (LOOP JOIN)); use with care
- Partitioning: split one table by a partition key; Sharding: split one database across servers by a sharding key
- Stored procedures: reusable, precompiled SQL saved in the database
- Break complex queries into steps; materialized views store precomputed results (refresh when data changes)

**Hình:** 4 thẻ: Hints | Partitioning vs Sharding | Stored procedure | Materialized view

**Ghi chú:** Phần cuối là các tính năng riêng của DB (kỹ thuật 10, 12, 15, khoảng 3 phút). Hint ép optimizer chọn cách chạy cụ thể, ví dụ USE INDEX của MySQL hay OPTION (LOOP JOIN) của SQL Server; chỉ dùng thận trọng. Partitioning chia một bảng lớn thành nhiều phần theo partition key; sharding chia một database ra nhiều server theo sharding key, giúp phân tải. Stored procedure là logic SQL lưu và biên dịch sẵn, dễ quản lý. Cuối cùng, chia query phức tạp thành các bước nhỏ để dễ tìm điểm nghẽn, và dùng materialized view lưu sẵn kết quả, nhớ refresh khi dữ liệu gốc đổi. Kết luận của bài: tối ưu query là quá trình liên tục.
