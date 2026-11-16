# Real cases: Trigger, stored procedure

Các case dùng file [demo_mysql.sql](demo_mysql.sql) (MySQL 8.0.18+). Chạy phần tạo bảng, procedure và trigger trong file đó trước, rồi copy từng case từ trên xuống.

## Case 1. Stored procedure: tạo đơn và trừ tiền
<a id="case-1"></a>

**Tình huống:** user mua hàng. App phải trừ tiền trong `users.balance` rồi thêm một dòng vào `orders`.

**Nếu không dùng procedure:** app gửi 2 câu SQL riêng. Nếu app sập giữa hai câu thì user bị trừ tiền nhưng không có đơn. Hai request chạy cùng lúc cũng có thể cùng thấy "đủ tiền" rồi cùng trừ.

**Cách làm:** procedure `create_order` làm cả luồng trong một transaction: khóa dòng user, kiểm tra đủ tiền, trừ tiền, thêm đơn. Có lỗi thì hủy hết (`ROLLBACK`).

**Chạy thử (trường hợp đủ tiền):**
```sql
CALL create_order(1, 200000, @oid);
SELECT @oid;
SELECT id, balance FROM users WHERE id = 1;
```
Kỳ vọng: `@oid` là số id của đơn mới, `balance` của user 1 giảm đúng 200000, `orders` có thêm 1 dòng.

**Chạy thử (trường hợp không đủ tiền):**
```sql
CALL create_order(2, 999999, @oid2);
SELECT COUNT(*) FROM orders WHERE user_id = 2;
SELECT balance FROM users WHERE id = 2;
```
Kỳ vọng: báo lỗi `Insufficient balance`, `COUNT(*)` là `0`, `balance` của user 2 không đổi.

## Case 2. Trigger BEFORE INSERT: chặn đơn có số tiền sai
<a id="case-2"></a>

**Tình huống:** nhiều nơi cùng thêm đơn vào `orders`: API, job import, script chạy tay.

**Nếu không dùng trigger:** chỉ cần một nơi quên kiểm tra là có đơn `total` âm trong database.

**Cách làm:** trigger `trg_orders_before_insert` chạy trước mỗi lần `INSERT`. Nếu `NEW.total <= 0` thì báo lỗi và câu `INSERT` bị hủy.

**Chạy thử:**
```sql
INSERT INTO orders (user_id, total) VALUES (1, -5);
SELECT COUNT(*) FROM orders;
```
Kỳ vọng: báo lỗi `Order total must be positive`, số đơn trong `orders` không tăng.

## Case 3. Trigger AFTER UPDATE: ghi lịch sử đổi trạng thái đơn
<a id="case-3"></a>

**Tình huống:** cần biết đơn nào đã đổi từ `pending` sang `paid`, bất kể ai sửa.

**Nếu không dùng trigger:** phải nhớ viết code ghi lịch sử ở mọi chỗ có `UPDATE orders`. Người sửa tay trong database sẽ không để lại dấu vết.

**Cách làm:** trigger `trg_orders_after_update` chạy sau mỗi `UPDATE`. Nếu `OLD.status` khác `NEW.status` thì thêm một dòng vào `orders_audit`.

**Chạy thử:**
```sql
UPDATE orders SET status = 'paid' WHERE id = @oid;
UPDATE orders SET status = 'paid' WHERE id = @oid;
SELECT * FROM orders_audit;
```
Kỳ vọng: `orders_audit` có đúng 1 dòng (`pending` → `paid`). Lần update thứ hai không đổi status nên không ghi thêm.

## Case 4. Procedure và trigger khác nhau thế nào khi chạy
<a id="case-4"></a>

**Tình huống:** bạn cần chọn nên đặt logic vào procedure hay trigger, và biết cách tìm chúng khi debug.

**Cách xem trong database:**
```sql
SHOW PROCEDURE STATUS WHERE Db = 'demo_sp';
SHOW TRIGGERS;
```
Kỳ vọng: thấy procedure `create_order` và hai trigger `trg_orders_before_insert`, `trg_orders_after_update`.

**So sánh qua demo:**
- Procedure `create_order` chỉ chạy khi có người gõ `CALL` (Case 1).
- Trigger tự chạy, kể cả khi bạn chỉ gõ `UPDATE` tay như ở Case 3. Nếu không chạy `SHOW TRIGGERS` thì không thấy chúng ở đâu trong code app. Đây là lý do trigger dễ gây bất ngờ khi debug.
- Cách chọn: luồng nhiều bước thì dùng procedure, việc luôn phải xảy ra thì dùng trigger và giữ nó ngắn.
