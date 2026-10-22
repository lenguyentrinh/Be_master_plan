# Slide content: Database Indexes

## Slide 1: Indexes

**Ghi chú:**
Chào mọi người. Hôm nay mình sẽ trình bày về Index trong database, trong khoảng 15 phút, gồm 5 phần:
(1) Index là gì.
(2) B-tree là gì.
(3) Có mấy loại index, và cách thiết kế index: thứ tự cột, covering, JOIN, ORDER BY.
(4) Các lỗi thường gặp.
(5) Làm sao biết index có đang được dùng hay không, bằng EXPLAIN hoặc EXPLAIN ANALYZE.

## Slide 2: What is an Index?

**Ghi chú:**
Trước hết, hãy nhìn vào điều gì xảy ra khi một cột không có index: database phải quét toàn bộ bảng để tìm dữ liệu. Cách này gọi là full table scan.
Index chính là giải pháp cho vấn đề đó. Đây là một cấu trúc dữ liệu phụ, giúp database tìm đúng dòng cần lấy mà không phải quét toàn bộ bảng.
Tuy nhiên, index có đánh đổi. Index giúp đọc nhanh hơn nhưng ghi chậm hơn, vì mỗi lần INSERT, UPDATE hoặc DELETE, database phải cập nhật cả cấu trúc phụ này. Ngoài ra, index cũng tốn thêm bộ nhớ và ổ đĩa.
Vì vậy, chỉ nên tạo index khi hệ thống có nhiều dữ liệu, hoặc dự kiến sẽ tăng trưởng trong tương lai.
Câu hỏi tiếp theo là: index hoạt động như thế nào để việc tìm kiếm nhanh hơn? Có nhiều loại index, mỗi loại dùng một cấu trúc khác nhau, ví dụ inverted, B-tree và hash. Mình sẽ đi vào B-tree, vì đây là loại phổ biến nhất.

## Slide 3: What is a B-tree?

**Ghi chú:**
B-tree là cấu trúc dữ liệu dạng cây, được dùng mặc định và phổ biến nhất cho index.
Khi tìm kiếm, database đi từ node gốc (root), qua các node trung gian, rồi tới node lá (leaf). Các leaf được nối với nhau theo thứ tự, nên việc tìm kiếm trở nên rất nhanh.

## Slide 4: How Many Types of Index?

**Ghi chú:**
Có 8 loại index chính. Mình đi lần lượt từng loại.
- B-tree là index mặc định. Nó dùng được cho so sánh bằng, range, ORDER BY và LIKE 'abc%' (tìm theo tiền tố), nhưng không dùng được cho LIKE '%abc' vì wildcard đứng đầu. Với trường hợp nhiều key trùng nhau, database tìm ở node cha chứa key đó, rồi đọc tiếp sang các leaf node liền kề.
- Unique cũng dùng cấu trúc B-tree như index mặc định, nhưng thêm một quy tắc: không cho phép giá trị trùng. Nếu cột đã có giá trị trùng thì không thể tạo. Nếu ban đầu chưa trùng thì tạo được, và từ đó cột sẽ chặn mọi giá trị trùng được thêm vào.
- Composite dùng cho nhiều cột, theo quy tắc leftmost prefix. Cụ thể, index (a, b, c) dùng được cho a, (a, b) và (a, b, c), nhưng không dùng được riêng cho b hoặc c. Về thứ tự cột: đặt cột so sánh bằng trước, rồi đến cột range đầu tiên. Giữa các cột so sánh bằng, đặt cột có độ chọn lọc (selectivity) cao nhất trước. Các cột đứng sau cột range sẽ không tận dụng được index.
- Full-text (MySQL) dùng cho tìm kiếm văn bản, thay thế cho trường hợp LIKE với wildcard đứng đầu không dùng được index. Trong PostgreSQL có GIN và GiST, dùng cho full-text, dữ liệu hình học, JSONB và nhiều kiểu dữ liệu khác.
- Partial hoặc Filtered chỉ index một phần dòng thỏa điều kiện. PostgreSQL gọi là partial, SQL Server gọi là filtered.
- Covering dùng INCLUDE để chứa thêm các cột mà query cần, nhờ đó database không phải quay lại đọc bảng.
- Clustered quy định thứ tự vật lý của các dòng trong bảng, nên mỗi bảng chỉ có 1 (ví dụ trong MySQL).
- Non-clustered là cấu trúc riêng, trỏ về dòng dữ liệu, và một bảng có thể có nhiều. MySQL gọi loại này là secondary index.

## Slide 5: 7 Common Indexing Mistakes

**Ghi chú:**
Đây là 7 lỗi thường gặp khi dùng index.
- Lỗi 1: tạo nhiều index riêng lẻ cho các cột cùng xuất hiện trong một câu SELECT. Trường hợp này nên dùng composite index.
- Lỗi 2: dùng composite index nhưng đặt sai thứ tự cột.
- Lỗi 3, và đây là lỗi quan trọng nhất: bọc hàm lên cột đã index, ví dụ LOWER(email). Việc này làm index thường mất tác dụng. Cách sửa là viết lại query, hoặc dùng expression index (hay computed index).
- Lỗi 4: tạo quá nhiều index, khiến thao tác ghi chậm đi.
- Lỗi 5: quên tạo index cho foreign key. PostgreSQL không tự tạo index cho foreign key, còn MySQL InnoDB thì có.
- Lỗi 6: không dùng partial index khi cần, ví dụ để lọc bớt các dòng NULL.
- Lỗi 7: không kiểm tra index có được dùng hay không. Hãy dùng system view của PostgreSQL, MySQL hoặc SQL Server để tìm và xóa các index không dùng.

## Slide 6: How Do I Know an Index Is Used?

**Ghi chú:**
Câu hỏi cuối cùng: làm sao biết index có đang hoạt động hay không? Đừng đoán mò, hãy kiểm tra bằng EXPLAIN.
PostgreSQL dùng EXPLAIN ANALYZE, MySQL dùng EXPLAIN, còn SQL Server thì xem actual execution plan và bật SET STATISTICS IO ON.
Cách đọc kết quả: nếu plan hiện Index Scan hoặc Index Only Scan thì index đang được dùng. Nếu là Seq Scan thì database đang quét toàn bảng.
Phần EXPLAIN là một topic riêng, nên hôm nay mình chỉ trình bày ở mức cơ bản.
