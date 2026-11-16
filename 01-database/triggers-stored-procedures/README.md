# Event trigger, stored procedure

- **Domain:** Database
- **Week:** Week 1-4

## Mục lục
- [Reference](#reference)
- [Key concepts](#key-concepts)
  - [1. Stored procedure](#1-stored-procedure)
  - [2. Trigger](#2-trigger)
  - [3. Khi nào dùng cái nào](#3-khi-nào-dùng-cái-nào)
  - [4. Nhược điểm cần biết](#4-nhược-điểm-cần-biết)
- [Q&A](#qa)
- [Hands-on](#hands-on)
- [Done](#done)
- [Slide](#slide)

## Reference
- [Mastering SQL Procedures and Triggers: A Guide with Examples | Tdiascontato | Medium](https://medium.com/@tdiascontato/mastering-sql-procedures-and-triggers-a-guide-with-examples-081f9e6e735f)

## Key concepts
Code chạy thử được nằm trong [demo_mysql.sql](demo_mysql.sql) (MySQL 8.0.18+). Ví dụ trong bài dùng 3 bảng: `users` (người dùng, có `balance` là số dư), `orders` (đơn hàng), `orders_audit` (lịch sử đổi trạng thái đơn).

### 1. Stored procedure
**Là gì:** một "hàm" viết bằng SQL, lưu sẵn trong database. Muốn chạy thì gọi tên nó bằng `CALL`.

**Dùng khi nào:** khi một việc cần nhiều câu SQL chạy liền nhau. Ví dụ tạo đơn gồm 2 bước: trừ tiền user, rồi thêm đơn. Nếu app gửi từng câu riêng và bị sập ở giữa, user mất tiền mà không có đơn. Gói 2 bước vào một procedure có transaction thì hoặc làm xong cả hai, hoặc không làm gì.

```sql
CREATE PROCEDURE create_order(IN p_user_id INT, IN p_total DECIMAL(12,2))
BEGIN
    START TRANSACTION;
    UPDATE users SET balance = balance - p_total WHERE id = p_user_id;
    INSERT INTO orders (user_id, total) VALUES (p_user_id, p_total);
    COMMIT;
END;

CALL create_order(1, 200000);   -- trừ 200.000 của user 1 và tạo đơn
```

- `IN` là giá trị truyền vào procedure. Có thêm `OUT` là giá trị procedure trả ra.
- Bản đầy đủ trong demo có thêm: kiểm tra đủ tiền, và tự `ROLLBACK` (hủy hết) khi có lỗi.
- Real case: [real_cases.md, Case 1](real_cases.md#case-1)

### 2. Trigger
**Là gì:** đoạn SQL gắn vào một bảng và **tự chạy** mỗi khi bảng đó có `INSERT`, `UPDATE` hoặc `DELETE`. Không cần ai gọi.

**Dùng khi nào:** khi có việc phải luôn xảy ra, dù dữ liệu được sửa từ đâu (app, script, người gõ tay). Ví dụ: mỗi khi đơn đổi trạng thái thì phải ghi lại lịch sử.

```sql
CREATE TRIGGER trg_orders_after_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO orders_audit (order_id, old_status, new_status)
        VALUES (OLD.id, OLD.status, NEW.status);
    END IF;
END;

UPDATE orders SET status = 'paid' WHERE id = 1;   -- tự có thêm 1 dòng trong orders_audit
```

- `AFTER UPDATE`: chạy sau khi đã sửa xong. Còn `BEFORE` là chạy trước khi ghi, hay dùng để chặn dữ liệu sai.
- `OLD` là dòng trước khi sửa, `NEW` là dòng sau khi sửa (ở `INSERT` chỉ có `NEW`, ở `DELETE` chỉ có `OLD`).
- `FOR EACH ROW`: chạy một lần cho mỗi dòng bị ảnh hưởng.
- Real case: [real_cases.md, Case 2](real_cases.md#case-2) (chặn dữ liệu sai), [Case 3](real_cases.md#case-3) (ghi lịch sử)

### 3. Khi nào dùng cái nào
- **Procedure:** bạn chủ động gọi, dùng cho một luồng nghiệp vụ gồm nhiều bước (tạo đơn, chuyển tiền). Nhận được tham số.
- **Trigger:** database tự chạy, dùng cho việc luôn phải xảy ra (ghi lịch sử, chặn dữ liệu sai). Không có tham số.
- Real case: [real_cases.md, Case 4](real_cases.md#case-4)

### 4. Nhược điểm cần biết
- **Khó tìm lỗi:** logic nằm trong database, không nằm trong code app, nên dễ quên và khó test hơn.
- **Trigger chạy ngầm:** người đọc code app không thấy nó, nên dễ bất ngờ khi dữ liệu tự đổi.
- **Trigger làm ghi chậm:** update 1 triệu dòng thì trigger chạy 1 triệu lần.
- **Mỗi DB viết khác nhau:** code procedure/trigger của MySQL không chạy được trên PostgreSQL hay SQL Server.
- **Cách giảm rủi ro:** giữ trigger ngắn, không để trigger gọi trigger khác, lưu script tạo procedure/trigger trong repo.
- Real case: [real_cases.md, Case 4](real_cases.md#case-4)

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
