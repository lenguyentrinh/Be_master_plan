# Slide content: Database Indexes

Nội dung từng slide của deck Canva (7 slide: 1 slide tiêu đề và agenda + 6 slide nội dung, present khoảng 15 phút). Chữ trên slide bằng tiếng Anh, phần **Ghi chú** là speaker notes tiếng Việt. Nội dung bám theo các mục trong `README.md`; hai mục Q&A và Hands-on không làm slide.

Deck: https://www.canva.com/design/DAHYhGFyqoI/DXfLNbB4reodOOOhBwBHPQ/edit

| Slide | Câu hỏi cần trả lời | Mục trong README |
|---|---|---|
| 1 | Giới thiệu chủ đề và 6 phần sẽ trình bày | Toàn bộ README |
| 2 | Index là gì? | 1. Index là gì |
| 3 | B-tree là gì? | 2. Các loại index (B-tree, Unique) |
| 4 | Có mấy loại index? | 2. Các loại index |
| 5 | Thiết kế index thế nào? | 3. Thứ tự cột, 4. Covering, 5. JOIN, 6. ORDER BY và GROUP BY |
| 6 | Các lỗi thường gặp? | 7. Bảy lỗi thường gặp |
| 7 | Làm sao biết index có đang hoạt động? | 8. Kiểm tra bằng EXPLAIN, 9. Bảo trì index |

---

## Slide 1: Indexes

- Backend Master Plan - Database (Week 1-4)
- 6 parts to cover in about 15 minutes

**Hình:** 6 thẻ agenda: 1 What is an Index? | 2 What is a B-tree? | 3 How many types of index? | 4 Designing indexes | 5 Common mistakes | 6 Is the index used? (EXPLAIN / EXPLAIN ANALYZE)

**Ghi chú:** Chào mọi người. Hôm nay mình trình bày về Index trong database, khoảng 15 phút, gồm 6 phần. (1) Index là gì. (2) B-tree là gì. (3) Có mấy loại index. (4) Cách thiết kế index: thứ tự cột, covering, JOIN, ORDER BY. (5) Các lỗi thường gặp. (6) Làm sao biết index có đang được dùng hay không, bằng EXPLAIN hoặc EXPLAIN ANALYZE. Mục tiêu là hiểu khi nào index giúp query nhanh hơn và khi nào nó gây hại.

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

## Slide 3: What is a B-tree?

- The default index structure: a balanced tree (root, internal nodes, linked leaf nodes)
- Supports equality, range, sort (ORDER BY) and prefix LIKE 'abc%'
- Cannot help LIKE '%abc' (leading wildcard)
- Duplicate keys: search the parent node holding the key, then the adjacent leaf nodes
- Unique index = a rule on a B-tree; the primary key creates one automatically

**Hình:** Cây B-tree 3 tầng vẽ lại từ ảnh tham khảo: root [100 155 226]; tầng 2 [48 50 79], [128 140], [168 200], [270 290]; tầng 3 [105 117], [120], [145] dưới [128 140] và [250 264], [299], [300 320 439] dưới [270 290]

**Ghi chú:** B-tree là cấu trúc dữ liệu cây mặc định của index (khoảng 2 phút). Tìm kiếm đi từ root xuống các node trong rồi tới leaf node; các leaf được nối theo thứ tự nên rất hợp cho range và sort. B-tree dùng được cho so sánh bằng, range, ORDER BY và LIKE 'abc%' (prefix), nhưng không dùng được cho LIKE '%abc' vì wildcard đứng đầu. Trường hợp đặc biệt: nếu có nhiều key trùng nhau thì sẽ tìm ở node cha chứa key đó rồi tìm sang leaf node liền kề. Unique index là một quy tắc chạy trên B-tree: nếu cột đã có giá trị trùng thì không tạo được; nếu ban đầu chưa trùng thì tạo được và từ đó cột bị chặn không cho thêm giá trị trùng. Primary key tự tạo unique index.

---

## Slide 4: How Many Types of Index?

- B-tree (default) and Unique: equality, range, sort, LIKE 'abc%'; no duplicate values
- Composite: many columns, leftmost prefix; Partial / Filtered: only some rows
- Full-text and GIN / GiST: text search, JSONB, arrays, geometry
- Covering: INCLUDE columns, no table read (Index Only Scan)
- Clustered: physical row order, 1 per table; Non-clustered: separate pointers, many

**Hình:** Lưới 9 loại index (B-tree, Unique, Composite, Partial / Filtered, Full-text, GIN / GiST, Covering, Clustered, Non-clustered)

**Ghi chú:** Có 9 loại index trong tài liệu này (khoảng 2 phút). B-tree là mặc định, dùng cho so sánh bằng, range, sort, LIKE theo prefix. Unique chống trùng giá trị, primary key tự tạo unique index. Composite dùng cho nhiều cột, theo quy tắc leftmost prefix. Partial/Filtered chỉ index một phần dòng (PostgreSQL gọi là partial, SQL Server gọi là filtered). Full-text và GIN/GiST cho văn bản, JSONB, hình học. Covering dùng INCLUDE để không phải đọc bảng. Clustered quy định thứ tự vật lý của dòng nên mỗi bảng chỉ có 1; non-clustered là cấu trúc riêng trỏ về dòng và có thể có nhiều. Composite và covering sẽ nói kỹ ở slide thiết kế index. Không cần nhớ hết, cứ nhớ B-tree là mặc định.

---

## Slide 5: Designing Indexes: Order, Covering, JOIN, ORDER BY

- Composite: equality columns first, then the first range column (most selective first)
- Leftmost prefix: (a, b, c) serves a, (a, b), (a, b, c), but not b or c alone
- Covering: INCLUDE (total, status) skips the table read; great for hot queries
- JOIN: index the foreign key on the "many" side; add filter columns too
- ORDER BY / GROUP BY: an index matching WHERE + ORDER BY skips the sort step

**Hình:** 4 thẻ: Column order, Covering, JOIN, ORDER BY / GROUP BY

**Ghi chú:** Slide này gom các mục thiết kế index (khoảng 4 phút). (1) Composite: cột so sánh bằng đặt trước, rồi tới cột range đầu tiên; giữa các cột equality đặt cột có độ chọn lọc (selectivity) cao nhất trước. Cột đứng sau điều kiện range không dùng được index. Leftmost prefix: index (a, b, c) dùng được cho a, (a, b), (a, b, c) nhưng không dùng được riêng b hoặc c. (2) Covering: INCLUDE các cột query cần để không phải quay lại đọc bảng; nên dùng cho query chạy thường xuyên như dashboard, API endpoint. (3) JOIN: index cột foreign key ở phía nhiều; primary key phía một đã có index sẵn; nếu JOIN kèm điều kiện lọc thì đưa cả cột lọc vào composite index. (4) ORDER BY / GROUP BY: index khớp thứ tự cột của WHERE và ORDER BY có thể bỏ được bước sort; GROUP BY dùng index trên cột nhóm, cột INCLUDE hỗ trợ hàm tổng hợp.

---

## Slide 6: 7 Common Indexing Mistakes

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

## Slide 7: How Do I Know an Index Is Used?

- PostgreSQL: EXPLAIN ANALYZE   |   MySQL: EXPLAIN
- SQL Server: actual execution plan and SET STATISTICS IO ON
- Index used? Look for Index Scan / Index Only Scan instead of Seq Scan
- Test with realistic data volumes: the optimizer picks different plans by table size
- Also check usage with system views; keep stats fresh (ANALYZE), drop unused indexes

**Hình:** Before (Seq Scan on orders) → After (Index Scan using idx_orders_customer)

**Ghi chú:** Làm sao biết index có đang hoạt động hay không (khoảng 3 phút): không đoán mò, hãy kiểm tra bằng EXPLAIN. PostgreSQL dùng EXPLAIN ANALYZE, MySQL dùng EXPLAIN, SQL Server xem actual execution plan và SET STATISTICS IO ON. Nếu plan hiện Index Scan hoặc Index Only Scan là index đang được dùng; nếu là Seq Scan thì đang quét toàn bảng. Phải test với lượng dữ liệu thực tế, vì optimizer chọn plan khác nhau tùy kích thước bảng. Ngoài ra có thể xem system view thống kê việc dùng index, cập nhật thống kê (ANALYZE), rebuild/reorganize vào giờ thấp điểm, và xóa index không dùng. Gợi ý demo: tạo bảng orders khoảng 1 triệu dòng và so sánh plan trước/sau khi tạo index trên customer_id.
