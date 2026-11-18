# Real cases: Trigger, stored procedure

Các case lấy từ project `english-center-system` (backend Spring Boot + MySQL). Mọi procedure và trigger nằm trong một file:
`backend/src/main/resources/db/migration/R__routines.sql`.

Mỗi case có 4 phần: **tình huống**, **cách làm**, **test nào kiểm case này đúng hay sai**, và **cách chạy thử**.

## Mục lục
- [Cách chạy test](#cach-chay-test)
- [Bảng: case nào được test bằng gì](#bang-test)
- [Case 1. `sp_deactivate_student`: bỏ role STUDENT](#case-1)
- [Case 2. `sp_remove_teacher`: bỏ role TEACHER](#case-2)
- [Case 3. `trg_enrollments_after_update`: audit log đổi status enrollment](#case-3)
- [Case 4. `trg_enrollments_before_insert`: từ chối enrollment ACTIVE trùng](#case-4)
- [Case 5. Trigger điểm danh: từ chối status không hợp lệ](#case-5)
- [Case 6. Khi KHÔNG dùng procedure: tạo enrollment](#case-6)
- [Case 7. Xem procedure và trigger trong database](#case-7)

---

## Cách chạy test
<a id="cach-chay-test"></a>

Có **2 tầng kiểm tra**, mỗi tầng trả lời một câu hỏi khác nhau:

| Tầng | Trả lời câu hỏi | Cần MySQL? | Chạy bằng |
|---|---|---|---|
| 1. Test Java (Mockito) | Hàm Java gọi procedure có đúng id, đúng thứ tự, đúng điều kiện không? | Không | `./mvnw test` |
| 2. `RoutinesMySqlTest` | Câu SQL của procedure và trigger có đúng không? | **Có** | xem bên dưới |

Tầng 1 không chạy SQL, tầng 2 mới chạy SQL thật. **Muốn biết một real case có đúng không thì phải chạy tầng 2.**

### Chạy tầng 1: test Java (không cần gì thêm)
```powershell
cd backend
./mvnw test "-Dtest=RoleProfileServiceTest,UserServiceImplRulesTest,UserCreationIntegrationTest"
```
Kỳ vọng: `Tests run: 31, Failures: 0, Errors: 0` (20 + 7 + 4), `BUILD SUCCESS`.

### Chạy tầng 2: `RoutinesMySqlTest` (SQL thật)
File: `backend/src/test/java/com/trinh/english_center_be/db/RoutinesMySqlTest.java` (18 test).

**Chuẩn bị:**
1. MySQL đang chạy (ví dụ `docker compose up -d mysql`, hoặc MySQL cài sẵn).
2. Tài khoản MySQL có quyền `CREATE DATABASE` và `DROP DATABASE`. Test tạo một database tạm tên `english_center_routines_test`, chạy migration vào đó, rồi xóa nó. **Database thật `english_center_db` không bị ảnh hưởng tới.**
3. Đặt biến môi trường (test không đọc từ `.env`):
   ```powershell
   $env:MYSQL_USER="root"
   $env:MYSQL_PASSWORD="<mật khẩu MySQL của bạn>"
   # chỉ cần nếu MySQL không ở localhost:3306:
   # $env:MYSQL_TEST_URL="jdbc:mysql://localhost:3307/"
   ```

**Chạy:**
```powershell
cd backend
./mvnw test "-Dtest=RoutinesMySqlTest*"
```
Dấu `*` bắt buộc, để chạy luôn các nhóm `@Nested` bên trong.

**Trong IntelliJ:** mở `RoutinesMySqlTest.java`, bấm nút Run màu xanh cạnh tên class. Lần đầu: Run → Edit Configurations → ô **Environment variables** thêm `MYSQL_USER=root;MYSQL_PASSWORD=<mật khẩu>`. Muốn chạy **một case**: bấm nút Run cạnh tên class `@Nested` (ví dụ `DeactivateStudent`) hoặc cạnh từng hàm test.

**Đọc kết quả:**

| Thấy | Nghĩa là |
|---|---|
| `Tests run: 18, Failures: 0, Errors: 0` | Tất cả procedure và trigger đúng với các real case. |
| Test đỏ | Real case tương ứng **sai**. Tên test cho biết case nào (xem bảng ở từng case bên dưới). |
| `Tests run: 0` | Test **bị bỏ qua** vì không kết nối được MySQL. Tìm dòng `[RoutinesMySqlTest] SKIPPED: ...` trong output để biết lý do (thường là sai `MYSQL_PASSWORD`, `Access denied`). Đây KHÔNG phải là "đã đúng". |

---

## Bảng: case nào được test bằng gì
<a id="bang-test"></a>

| Case | Object trong `R__routines.sql` | Test Java (tầng 1) | Test SQL thật (tầng 2) |
|---|---|---|---|
| 1 | `sp_deactivate_student` | `RoleProfileServiceTest`, `UserServiceImplRulesTest`, `UserCreationIntegrationTest` | `RoutinesMySqlTest.DeactivateStudent` (5 test) |
| 2 | `sp_remove_teacher` | `RoleProfileServiceTest` | `RoutinesMySqlTest.RemoveTeacher` (3 test) |
| 3 | `trg_enrollments_after_update` | không có (trigger không có hàm Java) | `RoutinesMySqlTest.EnrollmentAuditTrigger` (3 test) và 1 test trong `DeactivateStudent` |
| 4 | `trg_enrollments_before_insert` | không có | `RoutinesMySqlTest.DuplicateEnrollmentTrigger` (3 test) |
| 5 | `trg_attendance_before_insert`, `trg_attendance_before_update` | không có | `RoutinesMySqlTest.AttendanceTriggers` (3 test) |
| 6 | (không dùng procedure) | không có | không có |

Ngoài ra `RoutinesMySqlTest.migrationCreatesTheRoutines` kiểm tra cả 2 procedure và 4 trigger đều đã được tạo.

---

## Case 1. `sp_deactivate_student`: bỏ role STUDENT
<a id="case-1"></a>

**Tình huống:** admin đổi role của một user từ STUDENT sang TEACHER. Hệ thống phải (1) hủy mọi enrollment ACTIVE của học viên (giữ lịch sử, chỉ đổi status), (2) vô hiệu hóa profile học viên.

**Vì sao dùng procedure:** đây là nghiệp vụ nhiều bước đi cùng nhau (hủy enrollment rồi vô hiệu hóa profile). Trước đây Java nạp từng `Enrollment`, `setStatus`, `saveAll` (N câu UPDATE) rồi mới `save(student)`.

**Cách làm:** procedure `sp_deactivate_student(p_student_id, p_now)` chạy 2 câu UPDATE theo tập hợp. Java gọi nó qua `StudentRepository.callDeactivateStudent`, từ `RoleProfileService.onRemoved`. `p_now` do Java truyền vào (không dùng `NOW()` của MySQL vì múi giờ có thể khác).

**Test kiểm tra:**

| Tầng | Test | Kiểm điều gì |
|---|---|---|
| Java | `RoleProfileServiceTest.losingTheStudentRoleRunsTheDeactivateProcedureForTheProfile` | Bỏ role STUDENT thì gọi `callDeactivateStudent` đúng id profile |
| Java | `RoleProfileServiceTest.theProcedureIsGivenTheCurrentTime...` | Giờ truyền vào là giờ hiện tại của app |
| Java | `RoleProfileServiceTest.aFailingProcedureIsNotSwallowed` | Procedure lỗi thì lỗi được ném tiếp |
| Java | `UserServiceImplRulesTest.changeRoleSavesTheNewRoleThenMovesTheProfileThenRevokesSessions` | Thứ tự: lưu role, chuyển profile, rồi revoke session |
| Java | `UserServiceImplRulesTest.aFailingProfileRemovalStops...` | `onRemoved` lỗi thì không gán profile mới, không revoke session |
| Java (H2) | `UserCreationIntegrationTest.changingRoleMovesTheProfile` | Luồng thật qua `changeRole`; lệnh `CALL` được stub vì H2 không có procedure, chỉ kiểm nó được gọi đúng id |
| **SQL thật** | `DeactivateStudent.cancelsOnlyThatStudentsActiveEnrollments` | Chỉ hủy enrollment ACTIVE của đúng học viên đó; enrollment CANCELLED cũ giữ nguyên; học viên khác không bị ảnh hưởng |
| **SQL thật** | `DeactivateStudent.deactivatesTheProfile` | Profile `active = 0`, `update_at` đúng giờ truyền vào, học viên khác vẫn active |
| **SQL thật** | `DeactivateStudent.auditsEachCancellation` | Trigger audit ghi 1 row ACTIVE → CANCELLED cho mỗi enrollment vừa hủy, không ghi cho row cũ |
| **SQL thật** | `DeactivateStudent.withNoEnrollments` | Học viên không có enrollment vẫn được vô hiệu hóa, không lỗi |
| **SQL thật** | `DeactivateStudent.unknownIdChangesNothing` | Id không tồn tại: không đổi gì, không lỗi |

**Cách chạy thử:**
- Test: chạy `RoutinesMySqlTest.DeactivateStudent` (xem phần "Cách chạy test"). Cả 5 test xanh nghĩa là case đúng.

---

## Case 2. `sp_remove_teacher`: bỏ role TEACHER
<a id="case-2"></a>

**Tình huống:** admin đổi role của một giáo viên. Phải (1) gỡ giáo viên khỏi các course đang dạy (course không bị xóa), (2) xóa chuyên môn của giáo viên, (3) xóa profile giáo viên.

**Vì sao dùng procedure:** 3 bước phải đi cùng nhau và đúng thứ tự, vì `courses` và `teacher_categories` có khóa ngoại trỏ tới `teachers`: phải dọn trước rồi mới xóa profile.

**Cách làm:** procedure `sp_remove_teacher(p_teacher_id, p_now)`; Java gọi qua `TeacherRepository.callRemoveTeacher` từ `RoleProfileService.onRemoved`.

**Test kiểm tra:**

| Tầng | Test | Kiểm điều gì |
|---|---|---|
| Java | `RoleProfileServiceTest.losingTheTeacherRoleRunsTheRemoveProcedureForTheProfile` | Bỏ role TEACHER thì gọi `callRemoveTeacher` đúng id |
| Java | `RoleProfileServiceTest.nothingRunsWhenTheUserHasNoProfile`, `roleWithoutAProfileIsIgnored` | Không có profile, hoặc role không có profile (ADMIN): không gọi procedure |
| **SQL thật** | `RemoveTeacher.unassignsTheCourses` | Course còn nguyên nhưng `teacher_id = NULL`, `update_at` đúng giờ truyền vào |
| **SQL thật** | `RemoveTeacher.deletesSpecialtiesAndProfile` | Chuyên môn và profile giáo viên bị xóa |
| **SQL thật** | `RemoveTeacher.leavesOtherTeachersAlone` | Giáo viên khác giữ nguyên course, profile và chuyên môn |

**Cách chạy thử:** chạy `RoutinesMySqlTest.RemoveTeacher`.

---

## Case 3. `trg_enrollments_after_update`: audit log đổi status enrollment
<a id="case-3"></a>

**Tình huống:** hủy enrollment là đổi status từ ACTIVE sang CANCELLED (row vẫn còn). Nhưng không ai biết nó đổi **lúc nào**. Khi đổi role, nhiều enrollment bị hủy hàng loạt mà không có audit log.

**Nếu không dùng trigger:** phải nhớ ghi lịch sử ở mọi chỗ trong Java có `setStatus(CANCELLED)`, và sửa tay trong database thì không để lại gì.

**Cách làm:** trigger `trg_enrollments_after_update` chạy sau mỗi `UPDATE` trên `enrollments`; nếu `OLD.status` khác `NEW.status` thì thêm 1 row vào `enrollment_audit` (bảng tạo ở `V2__enrollment_audit.sql`). Dùng `<=>` để so sánh an toàn với NULL.

**Giới hạn cần nói rõ:** database không biết **ai** đổi, chỉ biết đổi cái gì và lúc nào. Muốn biết ai thì app phải ghi audit, hoặc truyền user qua session variable.

**Test kiểm tra:**

| Tầng | Test | Kiểm điều gì |
|---|---|---|
| **SQL thật** | `EnrollmentAuditTrigger.logsAStatusChange` | Đổi status thì có 1 row với đúng `old_status`, `new_status`, `changed_at` |
| **SQL thật** | `EnrollmentAuditTrigger.ignoresOtherUpdates` | Update cột khác, hoặc đặt lại cùng status: **không** ghi |
| **SQL thật** | `EnrollmentAuditTrigger.logsEveryChange` | Đổi hai lần thì có hai row |
| **SQL thật** | `DeactivateStudent.auditsEachCancellation` | Hủy hàng loạt qua procedure vẫn ghi đủ từng row |

Không có test Java vì trigger không có hàm Java nào.

**Cách chạy thử:** chạy `RoutinesMySqlTest.EnrollmentAuditTrigger`.

---

## Case 4. `trg_enrollments_before_insert`: từ chối enrollment ACTIVE trùng
<a id="case-4"></a>

**Tình huống:** một học viên chỉ được có **1 enrollment ACTIVE** trong mỗi course. Enrollment CANCELLED là lịch sử nên được lặp. MySQL không có index "unique chỉ cho các row ACTIVE", nên rule này trước đây chỉ do Java enforce.

**Cách làm:** trigger `trg_enrollments_before_insert` chạy trước mỗi `INSERT`; nếu row mới là ACTIVE mà đã có ACTIVE cùng course và cùng học viên thì `SIGNAL SQLSTATE '45000'` với thông báo `Student is already enrolled in this course` và câu INSERT bị hủy. Từ chối được cả enrollment trùng đến từ script hay người chạy SQL thủ công.

**Giới hạn cần nói rõ:** trigger chỉ là lớp bảo vệ bổ sung (safety net) cho các nguồn ghi dữ liệu khác (script, người chạy SQL thủ công); business rule chính vẫn được validate bằng code Java.

**Test kiểm tra:**

| Tầng | Test | Kiểm điều gì |
|---|---|---|
| **SQL thật** | `DuplicateEnrollmentTrigger.rejectsDuplicateActive` | ACTIVE thứ hai cùng course, cùng học viên bị từ chối với thông báo `already enrolled`; bảng vẫn chỉ có 1 row |
| **SQL thật** | `DuplicateEnrollmentTrigger.allowsOtherCombinations` | Cùng học viên ở course khác, hoặc học viên khác ở cùng course: được |
| **SQL thật** | `DuplicateEnrollmentTrigger.cancelledRowsMayRepeat` | Các row CANCELLED được lặp; ACTIVE mới được thêm sau khi đã hủy |

**Cách chạy thử:** chạy `RoutinesMySqlTest.DuplicateEnrollmentTrigger`.

---

## Case 5. Trigger điểm danh: từ chối status không hợp lệ
<a id="case-5"></a>

**Tình huống:** `attendance.status` trong Java là chuỗi tự do. Gõ nhầm `PRESNT` là báo cáo chuyên cần sai mà không ai thấy.

**Cách làm:** hai trigger `trg_attendance_before_insert` và `trg_attendance_before_update` chỉ cho phép `PRESENT`, `ABSENT`, `LATE` (hoặc NULL = chưa điểm danh); giá trị khác thì `SIGNAL SQLSTATE '45000'` với thông báo `Invalid attendance status`. MySQL không có trigger chung cho INSERT và UPDATE nên phải viết hai cái giống nhau.

**Nhận xét:** Hiện chưa có API ghi điểm danh; khi có, phải validate ở DTO để trả 400 thay vì để lỗi SQL thành 500. Lưu ý: với collation mặc định của MySQL 8 (không phân biệt hoa thường) `present` chữ thường **không** bị trigger từ chối, nên case này không demo giá trị đó.

**Test kiểm tra:**

| Tầng | Test | Kiểm điều gì |
|---|---|---|
| **SQL thật** | `AttendanceTriggers.acceptsValidStatuses` | `PRESENT`, `ABSENT`, `LATE`, `NULL` đều được thêm |
| **SQL thật** | `AttendanceTriggers.rejectsInvalidStatusOnInsert` | `PRESNT`, `EXCUSED` bị từ chối với `Invalid attendance status`; bảng không có row nào |
| **SQL thật** | `AttendanceTriggers.rejectsInvalidStatusOnUpdate` | Đổi row sẵn có sang `SKIPPED` bị từ chối, status cũ giữ nguyên; đổi sang `LATE` được |

**Cách chạy thử:** chạy `RoutinesMySqlTest.AttendanceTriggers`.

---

## Case 6. Khi KHÔNG dùng procedure: tạo enrollment
<a id="case-6"></a>

**Tình huống:** tạo enrollment trong course: Java kiểm tra các rule (phân quyền, xung đột lịch, course còn chỗ, `force`) rồi insert một row `enrollments`.

**Vì sao KHÔNG dùng procedure (đã thử rồi bỏ):**
- Tạo enrollment chỉ là "kiểm tra rồi insert", không phải nghiệp vụ nhiều bước.
- Project đã có nhiều rule trong Java (phân quyền, xung đột lịch, `force`). Procedure sẽ chép một phần vào SQL, rule nằm ở hai nơi.
- Phải tự điền cột audit của `BaseEntity` và tự map lỗi SQL sang HTTP 409/404.

So sánh với Case 1: bỏ role là nghiệp vụ nhiều bước thật (hủy enrollment + vô hiệu hóa profile), nên procedure phù hợp.

**Test kiểm tra:** không có, vì case này là một quyết định thiết kế, không có procedure để test.

**Cách chạy thử:** không có script demo; đây là case chỉ để nói.

---

## Case 7. Xem procedure và trigger trong database
<a id="case-7"></a>

**Tình huống:** cần biết database đang có procedure và trigger nào, và đọc nội dung thật khi debug (trigger chạy ngầm nên không thấy trong code Java).

```sql
SHOW PROCEDURE STATUS WHERE Db = 'english_center_db';          -- sp_deactivate_student, sp_remove_teacher
SHOW CREATE PROCEDURE sp_deactivate_student;                    -- nội dung thật
SHOW TRIGGERS WHERE `Table` IN ('enrollments', 'attendance');   -- 4 trigger
```

**Test kiểm tra:** `RoutinesMySqlTest.migrationCreatesTheRoutines` kiểm cả 2 procedure và 4 trigger đều tồn tại sau khi chạy migration.

**Cách chạy thử:** chạy 3 câu SQL ở trên trong MySQL của app (backend đã khởi động ít nhất một lần). Kỳ vọng: thấy 2 procedure và 4 trigger.
