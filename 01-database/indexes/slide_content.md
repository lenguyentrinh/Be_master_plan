# Slide content: Database Indexes

Nội dung từng slide (slide 1 đến 13) của deck Canva. Chữ trên slide bằng tiếng Anh, phần **Ghi chú** là speaker notes tiếng Việt.

Deck: https://www.canva.com/design/DAHYhGFyqoI/DXfLNbB4reodOOOhBwBHPQ/edit

---

## Slide 1: Database Indexes

- Backend Master Plan - Database (Week 1-4)
- How indexes speed up queries, and what they cost

**Hình:** Query → Index (B-tree) → Row found directly

**Ghi chú:** Chào mọi người. Hôm nay mình trình bày về Database Index: index là gì, có những loại nào, cách thiết kế và kiểm tra index. Mục tiêu là hiểu được khi nào index giúp query nhanh hơn và khi nào nó gây hại.

---

## Slide 2: What is an Index?

- A secondary data structure that finds rows faster
- Avoids a full table scan
- Trade-off: faster reads, slower writes
- Costs extra memory and disk space
- Example: B-tree on customer_id of a 1M-row table cuts I/O ~10,000x (illustrative, not a benchmark)

**Hình:** Quét toàn bảng so với tra bằng index; khung trade-off (đọc nhanh, ghi chậm, tốn dung lượng)

**Ghi chú:** Index là một cấu trúc dữ liệu phụ giúp database tìm dòng dữ liệu mà không phải quét toàn bộ bảng (full table scan). Đánh đổi: đọc nhanh hơn nhưng ghi chậm hơn, vì mỗi INSERT/UPDATE/DELETE đều phải cập nhật cả index, và index còn tốn thêm bộ nhớ/ổ đĩa. Con số giảm I/O 10.000 lần chỉ là số liệu minh họa của bài viết, không phải benchmark thực tế.

---

## Slide 3: Index Types at a Glance

- B-tree (default): equality, range, sort, LIKE 'abc%'
- Unique: prevents duplicate values
- Composite: multiple columns, leftmost prefix rule
- Partial / Filtered: index only some rows
- Full-text, GIN / GiST: text, JSONB, geometry
- Covering, Clustered, Non-clustered

**Hình:** Lưới 8 loại index

**Ghi chú:** Đây là bức tranh tổng quan các loại index. B-tree là mặc định và dùng cho so sánh bằng, range, sort, LIKE theo prefix. Unique chống trùng giá trị (primary key tự tạo unique index). Composite dùng cho nhiều cột. Partial/Filtered chỉ index một phần dòng. Full-text và GIN/GiST cho văn bản, JSONB, hình học. Covering, Clustered, Non-clustered sẽ nói kỹ ở các slide sau. Không cần nhớ hết, cứ nhớ B-tree là mặc định.

---

## Slide 4: B-tree and Unique Index

- CREATE INDEX idx_orders_customer ON orders (customer_id);
- CREATE UNIQUE INDEX idx_users_email ON users (email);
- B-tree cannot help LIKE '%abc' (leading wildcard)
- Duplicates already in the column: cannot create a unique index
- No duplicates yet: the unique index then rejects new duplicates
- Primary key creates a unique index automatically

**Hình:** Cây B-tree, đường tìm số 50, các leaf nối nhau, ghi chú key trùng

**Ghi chú:** B-tree là cấu trúc index mặc định. Lưu ý trường hợp đặc biệt: nếu có nhiều key trùng nhau thì sẽ tìm ở node cha chứa key đó rồi sang leaf node liền kề. Unique index là một quy tắc chạy trên B-tree: nếu cột đã có giá trị trùng thì không tạo được; nếu ban đầu chưa trùng thì tạo được và từ đó cột bị chặn không cho thêm giá trị trùng. B-tree không dùng được cho LIKE '%abc' vì wildcard đứng đầu.

---

## Slide 5: Composite Index and Leftmost Prefix

- CREATE INDEX idx_orders_cust_date ON orders (customer_id, created_at);
- Sorted by the first column; ties are sorted by the next column
- Index (a, b, c) works for: a | a, b | a, b, c
- It does NOT work for b alone or c alone
- Equality columns first, then the first range column

**Hình:** Bảng sắp theo (customer_id, created_at); các WHERE dùng được / không dùng được

**Ghi chú:** Composite index là một key gồm nhiều cột. Nó sắp xếp theo cột đầu tiên, nếu cột đầu trùng thì mới dùng cột tiếp theo để sắp xếp. Vì vậy index chỉ có tác dụng khi tìm theo cả bộ key hoặc theo cột đầu tiên. Nếu chỉ tìm theo cột thứ hai thì không dùng được, vì phải tìm tuần tự theo từng cột, không thể bỏ qua cột đầu. Đây là quy tắc leftmost prefix. Quy ước: cột so sánh bằng đặt trước, cột range đặt sau.

---

## Slide 6: Partial, Full-text, GIN and GiST

- Partial: CREATE INDEX ... WHERE status = 'pending' (PostgreSQL; MySQL has no WHERE)
- Full-text: MySQL FULLTEXT; PostgreSQL GIN on to_tsvector
- GIN: JSONB, arrays, full-text
- GiST: geometry, ranges, distance queries
- Partial indexes are smaller because they cover only some rows

**Hình:** Partial (chỉ dòng pending được index), GIN (inverted index), GiST (điểm gần vị trí)

**Ghi chú:** Partial index (PostgreSQL) tạo cấu trúc phụ chỉ cho những record thỏa điều kiện, không phải toàn bộ bảng; MySQL không hỗ trợ WHERE khi tạo index (SQL Server gọi là filtered index). Full-text sẽ tokenize nội dung văn bản để tìm kiếm ngôn ngữ tự nhiên: MySQL dùng FULLTEXT, PostgreSQL dùng GIN trên to_tsvector. GIN dùng cho JSONB, array, full-text; GiST dùng cho dữ liệu hình học, range, truy vấn theo khoảng cách.

---

## Slide 7: Covering, Clustered and Non-clustered

- Covering: INCLUDE (total, status) so the query never reads the table
- Best for hot queries: dashboards, API endpoints
- INCLUDE columns are not used for sorting
- Clustered: physical row order, only 1 per table
- Non-clustered: separate structure pointing to rows, many allowed

**Hình:** Non-clustered + tra bảng; covering (không đọc bảng); Clustered so với Non-clustered

**Ghi chú:** Covering index (PostgreSQL 11+ / SQL Server) cho phép lấy giá trị các cột đã được cover lúc tạo index mà không cần quay lại bảng chính (các cột cover không dùng để sắp xếp). Nên dùng cho query chạy thường xuyên. Clustered quy định thứ tự vật lý của dòng nên mỗi bảng chỉ có 1; non-clustered là cấu trúc riêng trỏ về dòng dữ liệu và có thể có nhiều. Bài viết gốc chỉ nhắc tới clustered ở phần FAQ.

---

## Slide 8: Column Order in Composite Indexes

- Equality columns first, then the first range column
- Columns after a range condition cannot use the index
- Among equality columns: most selective column first
- Leftmost prefix: (a, b, c) serves a, (a, b), (a, b, c)
- Prefer one composite index over many single-column indexes

**Hình:** Chuỗi 1 equality → 2 equality → 3 first range → sau range không dùng được

**Ghi chú:** Thứ tự cột quyết định index có được dùng hay không. Đặt cột so sánh bằng trước, rồi tới cột range đầu tiên; cột đứng sau điều kiện range không dùng được index. Giữa các cột equality, đặt cột có độ chọn lọc (selectivity) cao nhất trước. Nhắc lại leftmost prefix: index (a, b, c) dùng được cho a, (a, b), (a, b, c) nhưng không dùng được cho riêng b hoặc c. Thà tạo một composite index còn hơn là nhiều index đơn cột.

---

## Slide 9: Indexes for JOIN, ORDER BY, GROUP BY

- JOIN: index the foreign key on the "many" side (the primary key is already indexed)
- JOIN + filter: put the filter columns into the composite index too
- ORDER BY: an index matching WHERE + ORDER BY can skip the sort step
- Sort direction should match, although many databases can scan backwards
- GROUP BY: index the grouping columns; INCLUDE columns help aggregates

**Hình:** orders (many) – customers (one); ORDER BY không cần bước sort; GROUP BY

**Ghi chú:** Với JOIN: index cột foreign key ở phía nhiều (many); primary key ở phía một đã có index sẵn. Nếu JOIN kèm điều kiện lọc thì đưa cả cột lọc vào composite index. Với ORDER BY: index khớp thứ tự cột của WHERE và ORDER BY có thể bỏ được bước sort; hướng sắp xếp nên khớp, dù nhiều DB vẫn quét ngược được. Với GROUP BY: dùng index trên cột nhóm, cột INCLUDE hỗ trợ các hàm tổng hợp.

---

## Slide 10: 7 Common Indexing Mistakes

1. Many single-column indexes instead of one composite index
2. Wrong composite column order (low-selectivity column first)
3. Functions on indexed columns: LOWER(), YEAR() disable the index
4. Too many indexes on write-heavy tables
5. Missing foreign key index (PostgreSQL does not create it; MySQL InnoDB does)
6. Ignoring NULLs (a partial index can help)
7. Never checking whether an index is actually used

**Hình:** 7 ô lỗi + ô "Fix: measure with EXPLAIN + usage views"

**Ghi chú:** Bảy lỗi hay gặp. Lỗi số 3 rất quan trọng: bọc hàm như LOWER(email) lên cột đã index sẽ làm index thường mất tác dụng; cách sửa là viết lại query hoặc dùng expression/computed index. Lỗi số 5: PostgreSQL không tự tạo index cho foreign key, còn MySQL InnoDB thì có. Lỗi số 4 và 7: quá nhiều index làm ghi chậm, và cần kiểm tra index có được dùng không bằng system view của PostgreSQL, MySQL, SQL Server để xóa index không dùng.

---

## Slide 11: Verify with EXPLAIN

- PostgreSQL: EXPLAIN ANALYZE
- MySQL: EXPLAIN
- SQL Server: actual execution plan and SET STATISTICS IO ON
- Test with realistic data volumes: the optimizer picks different plans by table size
- Compare the plan before and after creating the index

**Hình:** Before (Seq Scan on orders) → After (Index Scan using idx_orders_customer)

**Ghi chú:** Không đoán mò, hãy kiểm tra bằng EXPLAIN: PostgreSQL dùng EXPLAIN ANALYZE, MySQL dùng EXPLAIN, SQL Server xem actual execution plan và SET STATISTICS IO ON. Phải test với lượng dữ liệu thực tế, vì optimizer chọn plan khác nhau tùy kích thước bảng. Gợi ý demo: tạo bảng orders khoảng 1 triệu dòng và so sánh plan trước/sau khi tạo index trên customer_id.

---

## Slide 12: Index Maintenance

- Update statistics (ANALYZE in PostgreSQL)
- Rebuild / reorganize indexes
- Schedule maintenance during off-peak hours
- Drop unused indexes; list them via system views
- OLTP tables usually carry about 3 to 8 indexes: start from WHERE, JOIN, ORDER BY columns

**Hình:** Vòng lặp ANALYZE → Rebuild/Reorganize → Check usage → Drop unused

**Ghi chú:** Index cần được bảo trì định kỳ: cập nhật thống kê (ANALYZE trong PostgreSQL), rebuild/reorganize index, và nên lên lịch vào giờ thấp điểm. Số lượng index tùy workload; bảng OLTP thường khoảng 3 đến 8. Cách làm: bắt đầu từ các cột trong WHERE, JOIN, ORDER BY rồi xóa những index không được dùng.

---

## Slide 13: Quick Q&A Recap

- Default index type? B-tree: equality, range, sort, prefix LIKE
- Does index (a, b, c) serve WHERE b = 1? No: leftmost prefix
- Why does WHERE LOWER(email) = 'x' skip the index? Function on the column: use an expression index
- Clustered vs non-clustered? Physical row order (1 per table) vs separate pointer structure
- How to know an index is used? EXPLAIN / EXPLAIN ANALYZE and system views

**Hình:** 4 ô Q&A

**Ghi chú:** Tổng kết nhanh bằng các câu hỏi. Index mặc định là B-tree. Index (a, b, c) không dùng được cho WHERE b = 1 vì vi phạm leftmost prefix. WHERE LOWER(email) = 'x' không dùng index thường trên email vì hàm bọc cột; dùng expression index hoặc viết lại query. Clustered quy định thứ tự vật lý (chỉ 1 mỗi bảng), non-clustered là cấu trúc riêng trỏ tới dòng. Muốn biết index có được dùng thì dùng EXPLAIN và system view. Có thể để khán giả trả lời trước khi chuyển slide.
