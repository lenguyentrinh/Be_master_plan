# Event trigger, stored procedure

- **Domain:** Database
- **Week:** Week 1-4
- realcase se lay trong project: D:\WorkSpace\vibeCode\english-center-system
## Mục lục
- [Event trigger, stored procedure](#event-trigger-stored-procedure)
  - [Mục lục](#mục-lục)
  - [Reference](#reference)
  - [Key concepts](#key-concepts)
    - [0. Vấn đề: nhiều nguồn cùng ghi vào database](#0-vấn-đề-nhiều-nguồn-cùng-ghi-vào-database)
    - [1. Stored procedure](#1-stored-procedure)
    - [2. Trigger](#2-trigger)
    - [3. Khi nào dùng cái nào](#3-khi-nào-dùng-cái-nào)
    - [4. Nhược điểm cần biết](#4-nhược-điểm-cần-biết)
  - [Q\&A](#qa)
  - [Hands-on](#hands-on)
  - [Done](#done)

## Reference
- [Mastering SQL Procedures and Triggers: A Guide with Examples | Tdiascontato | Medium](https://medium.com/@tdiascontato/mastering-sql-procedures-and-triggers-a-guide-with-examples-081f9e6e735f)

## Key concepts
Code của project nằm ở `backend/src/main/resources/db/migration/R__routines.sql`. Cách kiểm tra từng case xem [real_cases.md](real_cases.md#cach-chay-test). Các ví dụ SQL ngắn bên dưới là ví dụ minh họa viết theo domain của project (không có trong code project); phần real case thật lấy từ project english-center-system: `courses` (khóa học, có `max_student`), `enrollments` (đăng ký học), `attendance` (điểm danh), `enrollment_audit` (audit log đổi status của enrollment).

### 0. Vấn đề: nhiều nguồn cùng ghi vào database

### 1. Stored procedure
**Vấn đề:** một nghiệp vụ gồm nhiều câu SQL mà ứng dụng gửi từng câu một thì tốn nhiều round trip và logic bị rải trong code. Gom vào một stored procedure thì ứng dụng chỉ cần một lần gọi và logic nằm ở một chỗ.

**Là gì:** một "hàm" viết bằng SQL, lưu sẵn trong database. Muốn chạy thì gọi tên nó bằng `CALL`.

**Dùng khi nào:** khi một nghiệp vụ cần nhiều câu SQL chạy liền nhau. Ví dụ chuyển một học viên sang course khác gồm 2 bước: hủy enrollment cũ, rồi tạo enrollment mới. Gói 2 bước vào một procedure thì ứng dụng chỉ cần một lần `CALL`, và logic nằm ở một chỗ.

```sql
CREATE PROCEDURE sp_transfer_student(
    IN p_student_id     VARCHAR(36),
    IN p_from_course_id VARCHAR(36),
    IN p_to_course_id   VARCHAR(36)
)
BEGIN
    UPDATE enrollments SET status = 'CANCELLED'
    WHERE student_id = p_student_id AND course_id = p_from_course_id AND status = 'ACTIVE';

    INSERT INTO enrollments (id, student_id, course_id, status, enroll_date)
    VALUES (UUID(), p_student_id, p_to_course_id, 'ACTIVE', CURDATE());
END;

CALL sp_transfer_student('s1', 'c1', 'c2');   -- chuyển học viên s1 từ course c1 sang c2
```

- `IN` là tham số truyền vào procedure. Có thêm `OUT` là tham số procedure trả ra.
- Lợi của procedure: gom nhiều câu vào một lần gọi và xử lý theo tập hợp (set-based: 2 câu `UPDATE` thay vì N+1).
- Procedure so với Java: atomic thì Java `@Transactional` cũng làm được, nên không phải lý do để dùng procedure. Khác biệt thật là: ít round trip, xử lý set-based mà không kéo dữ liệu về app, phân quyền `EXECUTE` mà không cấp quyền ghi vào bảng, và dùng chung cho nhiều nơi gọi (nhiều service, script).
- Nghiệp vụ nhỏ (2-4 câu SQL, DB cùng mạng với app) thì chênh lệch round trip gần như không đáng kể, Java + `@Transactional` là đủ. Procedure có lợi rõ khi xử lý nhiều dòng (hàng nghìn trở lên).
- **Nhược điểm của procedure:** khi có bug ở một nghiệp vụ, dev không chỉ đọc code Java (có IDE, breakpoint, stack trace, git blame) mà còn phải mở procedure trong database để xem. Logic bị tách ra hai nơi, gây khó debug, khó review, và dễ lệch version giữa code Java với procedure đang chạy trên database.
- Real case: [real_cases.md, Case 1](real_cases.md#case-1) và [Case 2](real_cases.md#case-2)

### 2. Trigger
**Vấn đề: nhiều nguồn cùng ghi vào database.** Database không chỉ nhận dữ liệu từ API. Script import, sửa dữ liệu thủ công, admin chạy SQL trực tiếp trong console cũng ghi vào đó. Chỉ dữ liệu đi qua API mới được validate bằng code Java, các nguồn còn lại **bỏ qua** các kiểm tra đó. Business rule chỉ nằm trong Java thì chỉ enforce được với dữ liệu đi qua API. Trigger nằm trong database nên áp dụng cho mọi nguồn ghi.

**Là gì:** đoạn SQL gắn vào một bảng và **tự chạy** mỗi khi bảng đó có `INSERT`, `UPDATE` hoặc `DELETE`. Không cần ai gọi.

**Dùng khi nào:** khi có việc phải luôn xảy ra, dù dữ liệu được sửa từ nguồn nào (ứng dụng, script, người chạy SQL thủ công). Ví dụ: mỗi khi course đổi status thì phải ghi log.

```sql
CREATE TRIGGER trg_courses_after_update
AFTER UPDATE ON courses
FOR EACH ROW
BEGIN
    IF NOT (OLD.status <=> NEW.status) THEN
        INSERT INTO course_status_log (course_id, old_status, new_status)
        VALUES (OLD.id, OLD.status, NEW.status);
    END IF;
END;

UPDATE courses SET status = 'CLOSE' WHERE id = 'c1';   -- tự có thêm 1 row trong course_status_log
```

- `AFTER UPDATE`: chạy sau khi row đã được sửa. Còn `BEFORE` chạy trước khi ghi, hay dùng để validate và từ chối dữ liệu không hợp lệ.
- `OLD` là row trước khi sửa, `NEW` là row sau khi sửa (ở `INSERT` chỉ có `NEW`, ở `DELETE` chỉ có `OLD`).
- `<=>` là toán tử so sánh an toàn với NULL (null-safe equal). Dùng `<>` thì khi một vế là NULL kết quả là NULL, nên thay đổi bị bỏ sót.
- `FOR EACH ROW`: chạy một lần cho mỗi row bị ảnh hưởng.
- **Nhược điểm của trigger:**
  - **Chạy ngầm:** người đọc code ứng dụng không thấy nó, nên dễ bất ngờ khi dữ liệu tự thay đổi.
  - **Giảm hiệu năng ghi:** update 1 triệu row thì trigger chạy 1 triệu lần.
  - **Quyền khi tạo:** với MySQL 8 bật binary log, tạo trigger (và stored function) cần quyền `SUPER` hoặc server đặt `log_bin_trust_function_creators=1`, nếu không sẽ lỗi 1419 và backend không khởi động. Procedure thường không bị lỗi này.
- Real case: [real_cases.md, Case 3](real_cases.md#case-3) (audit log đổi status enrollment), [Case 4](real_cases.md#case-4) (từ chối enrollment ACTIVE trùng), [Case 5](real_cases.md#case-5) (từ chối status điểm danh không hợp lệ)

### 3. Khi nào dùng cái nào
- **Procedure:** ứng dụng chủ động gọi, dùng cho một nghiệp vụ gồm nhiều bước (chuyển học viên sang course khác, bỏ role). Nhận được tham số.
- **Trigger:** database tự chạy, dùng cho việc luôn phải xảy ra (audit log, từ chối dữ liệu không hợp lệ). Không có tham số.
- **Không dùng procedure khi:** việc chỉ là "kiểm tra rồi insert" và business rule đã nằm trong code ứng dụng (ví dụ tạo enrollment). Chép rule sang SQL làm rule nằm ở hai nơi.
- Real case: [real_cases.md, Case 6](real_cases.md#case-6) (khi không dùng procedure), [Case 7](real_cases.md#case-7)

### 4. Nhược điểm cần biết
- **Khó debug:** logic nằm trong database, không nằm trong code ứng dụng, nên dễ bị quên và khó theo dõi hơn.
- **Phụ thuộc loại database:** code procedure/trigger của MySQL không chạy được trên PostgreSQL hay SQL Server.
- **Khó test:** SQL nằm trong database nên phải test trên MySQL thật (`RoutinesMySqlTest`).
- **Cách giảm rủi ro:** giữ trigger ngắn, không để trigger gọi trigger khác, lưu script tạo procedure/trigger trong repo.
- Real case: [real_cases.md, Case 6](real_cases.md#case-6) (khi không dùng procedure), [Case 7](real_cases.md#case-7)

## Q&A
- 

## Hands-on
- [ ] 

## Done
- [ ] Read reference
- [ ] Notes written
- [ ] Practice done
