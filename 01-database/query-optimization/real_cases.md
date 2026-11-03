# Real cases: Query optimization

## Case 1. ANALYZE giúp optimizer chọn index hay quét cả bảng

Bảng `orders` có 1 triệu dòng, đã đánh index cột `status`: `cancelled` ~10.000 dòng (1%), `delivered` ~900.000 dòng (90%).

```sql
SELECT * FROM orders WHERE status = 'cancelled';  -- ít dòng: Index Scan
SELECT * FROM orders WHERE status = 'delivered';  -- gần hết bảng: Seq Scan rẻ hơn
```

- Có index không có nghĩa DB luôn dùng index. Khi điều kiện lọc ra phần lớn bảng thì quét thẳng bảng rẻ hơn.
- Optimizer biết điều này nhờ **statistics** (số dòng, giá trị phổ biến, tần suất). `ANALYZE` chỉ thu thập statistics, optimizer mới là bên ước tính chi phí và chọn plan.
- Chạy lại `ANALYZE` khi dữ liệu đổi nhiều (sau import/xóa lớn); kiểm tra bằng cách so `rows=` ước lượng với `actual rows=` trong `EXPLAIN ANALYZE`.

```sql
ANALYZE orders;  -- PostgreSQL (MySQL: ANALYZE TABLE; SQL Server: UPDATE STATISTICS)
```
