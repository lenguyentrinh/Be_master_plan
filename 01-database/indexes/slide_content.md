# Slide content: Database Indexes

**Quy ước màu theo DB (trên slide và tag trong file này):**

- Cam = MySQL `[MySQL]`
- Xanh ngọc = PostgreSQL `[PostgreSQL]`
- Navy = dùng chung cho các DB `[Cả hai]`
- Mỗi slide có DB riêng đều có chú thích màu ở góc phải.

---

## Slide 1: Indexes

**Ghi chú:**

Chào mọi người. Hôm nay mình sẽ trình bày về Index trong database, trong khoảng 15 phút, gồm 5 phần và một phần Q&A. Phần trình bày chỉ là overview, nên nếu có thắc mắc mọi người có thể note lại và hỏi ở phần Q&A.

1. Index là gì.
2. B-tree là gì.
3. Có mấy loại index, kèm lưu ý về thứ tự cột và covering.
4. Các lỗi thường gặp.
5. Làm sao biết index có đang được dùng hay không, bằng EXPLAIN hoặc EXPLAIN ANALYZE.

---

## Slide 2: What is an Index?

**Ghi chú:**

Trước hết, hãy nhìn vào điều gì xảy ra khi một cột không có index:

- Database phải quét toàn bộ bảng để tìm dữ liệu.
- Cách này gọi là **full table scan**.

Index chính là giải pháp cho vấn đề đó:

- Đây là một cấu trúc dữ liệu phụ.
- Giúp database tìm đúng dòng cần lấy mà không phải quét toàn bộ bảng.

Tuy nhiên, index có đánh đổi:

- Index giúp **đọc nhanh hơn** nhưng **ghi chậm hơn**, vì mỗi lần INSERT, UPDATE hoặc DELETE, database phải cập nhật cả cấu trúc phụ này.
- Index cũng tốn thêm bộ nhớ và ổ đĩa.
- Vì vậy, chỉ nên tạo index khi hệ thống có nhiều dữ liệu, hoặc dự kiến sẽ tăng trưởng trong tương lai.

Câu hỏi tiếp theo: index hoạt động như thế nào để việc tìm kiếm nhanh hơn?

- Có nhiều loại index, mỗi loại dùng một cấu trúc khác nhau, ví dụ inverted, B-tree và hash.
- Mình sẽ đi vào B-tree, vì đây là loại phổ biến nhất.

---

## Slide 3: What is a B-tree?

**Ghi chú:**

- B-tree là cấu trúc dữ liệu dạng cây, được dùng mặc định và phổ biến nhất cho index.
- Khi tìm kiếm, database đi từ node gốc (root), qua các node trung gian, rồi tới node lá (leaf).
- Các leaf được nối với nhau theo thứ tự, nên việc tìm kiếm trở nên rất nhanh.
- Chính xác hơn, các DB gọi là B-tree nhưng thực tế dùng B+tree: dữ liệu nằm ở leaf, và các leaf được nối với nhau.

Trên slide có một ô NOTE nhỏ:

- Ngoài B-tree, index còn có thể dùng hash hoặc inverted.
- Hôm nay mình chỉ tập trung vào B-tree.

---

## Slide 4: How Many Types of Index?

**Ghi chú:**

Có **8 loại** index chính. Mình đi lần lượt từng loại.

### 1. B-tree

- Là index mặc định.
- Dùng được cho: so sánh bằng, range, ORDER BY và `LIKE 'abc%'` (tìm theo tiền tố).
- Không dùng được cho `LIKE '%abc'` vì wildcard đứng đầu.
- `[MySQL]` `LIKE 'abc%'` dùng thẳng được index.
- `[PostgreSQL]` cần collation C hoặc operator class `text_pattern_ops` thì `LIKE 'abc%'` mới dùng được B-tree index.
- Với trường hợp nhiều key trùng nhau, database tìm ở node cha chứa key đó, rồi đọc tiếp sang các leaf node liền kề.

### 2. Unique

- Cũng dùng cấu trúc B-tree như index mặc định, nhưng thêm một quy tắc: không cho phép giá trị trùng (NULL thì khác nhau nên thường được phép lặp lại).
- Nếu cột đã có giá trị trùng thì không thể tạo.
- Nếu ban đầu chưa trùng thì tạo được, và từ đó cột sẽ chặn mọi giá trị trùng được thêm vào.

### 3. Composite

- Dùng cho nhiều cột, theo quy tắc **leftmost prefix**.
- Ví dụ index `(a, b, c)`:
  - Dùng được cho `a`, `(a, b)` và `(a, b, c)`.
  - Thường không dùng được riêng cho `b` hoặc `c`.
  - `[PostgreSQL]` 18 trở lên có skip scan nên một số trường hợp vẫn dùng được.
- Thứ tự cột:
  - Đặt cột so sánh bằng trước, rồi đến cột range đầu tiên.
  - Giữa các cột so sánh bằng, thường đặt cột có độ chọn lọc (selectivity) cao nhất trước (đây là kinh nghiệm chung, không phải luật cứng).
  - Các cột đứng sau cột range sẽ không tận dụng được index.

### 4. Full-text

- Dùng cho tìm kiếm văn bản, thay thế cho trường hợp `LIKE` với wildcard đứng đầu không dùng được index.
- `[MySQL]` dùng FULLTEXT index.
- `[PostgreSQL]` dùng GIN (full-text, JSONB, array) và GiST (dữ liệu hình học, range).
- Vì hai bên dùng cơ chế khác nhau nên mình gộp chung thành một loại.

### 5. Partial

- Chỉ index một phần dòng thỏa điều kiện.
- `[PostgreSQL]` hỗ trợ partial index.
- `[MySQL]` chưa hỗ trợ loại này.

### 6. Covering

- Chứa đủ các cột mà query cần, nhờ đó database không phải quay lại đọc bảng.
- `[PostgreSQL]` 11 trở lên dùng INCLUDE.
- `[MySQL]` không có INCLUDE, nên đưa các cột cần thêm vào composite index.

### 7. Clustered

- Quy định thứ tự vật lý của các dòng trong bảng, nên mỗi bảng chỉ có 1.
- `[MySQL]` InnoDB tự dùng primary key làm clustered index.
- `[PostgreSQL]` không có clustered index thật, lệnh `CLUSTER` chỉ sắp xếp lại bảng một lần.

### 8. Non-clustered

- Là cấu trúc riêng, trỏ về dòng dữ liệu, và một bảng có thể có nhiều.
- MySQL gọi loại này là secondary index.

---

## Slide 5: 7 Common Indexing Mistakes

**Ghi chú:**

Đây là 7 lỗi thường gặp khi dùng index.

1. **Nhiều index riêng lẻ:** tạo nhiều index riêng lẻ cho các cột cùng xuất hiện trong một câu SELECT. Trường hợp này nên dùng composite index.
2. **Sai thứ tự cột:** dùng composite index nhưng đặt sai thứ tự cột.
3. **Bọc hàm lên cột đã index** (lỗi quan trọng nhất):
   - Ví dụ `LOWER(email)`, việc này làm index thường mất tác dụng.
   - Cách sửa: viết lại query, hoặc dùng expression index (hay computed index).
4. **Quá nhiều index:** khiến thao tác ghi chậm đi.
5. **Quên index cho foreign key:**
   - `[PostgreSQL]` không tự tạo index cho foreign key.
   - `[MySQL]` InnoDB thì có.
6. **Không dùng partial index khi cần**, ví dụ để lọc bớt các dòng NULL:
   - `[PostgreSQL]` hỗ trợ.
   - `[MySQL]` không hỗ trợ.
7. **Không kiểm tra index có được dùng hay không.** Hãy dùng system view để tìm và xóa các index không dùng:
   - `[PostgreSQL]` `pg_stat_user_indexes`
   - `[MySQL]` `sys.schema_unused_indexes`

---

## Slide 6: How Do I Know an Index Is Used?

**Ghi chú:**

Câu hỏi cuối cùng: làm sao biết index có đang hoạt động hay không? Đừng đoán mò, hãy kiểm tra bằng EXPLAIN.

- `[Cả hai]` `EXPLAIN`: cho kế hoạch dự đoán, **không chạy** query. Dùng để biết index có được dùng hay không.
- `[Cả hai]` `EXPLAIN ANALYZE`: **chạy query thật**, cho số dòng và thời gian thực tế. Dùng khi cần so sánh ước lượng với thực tế.
- `[MySQL]` `EXPLAIN ANALYZE` có từ 8.0.18 trở lên.

Cách đọc kết quả:

- `[PostgreSQL]` plan hiện **Index Scan** hoặc **Index Only Scan** là index đang được dùng; **Seq Scan** là database quét toàn bảng.
- `[MySQL]` nhìn cột `key` (tên index đang dùng) và cột `type`: `type = ALL` là quét toàn bảng, `ref` hoặc `range` là có dùng index.
- Seq Scan hoặc `type = ALL` không phải lúc nào cũng là lỗi: bảng nhỏ, hoặc query đọc phần lớn bảng thì database chủ động quét toàn bảng.

Lưu ý:

- `EXPLAIN ANALYZE` chạy query thật, nên cẩn thận với INSERT, UPDATE, DELETE (có thể bọc trong transaction rồi rollback).
- Phần EXPLAIN là một topic riêng, nên hôm nay mình chỉ trình bày ở mức cơ bản.
