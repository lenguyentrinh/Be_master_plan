# Real cases: Design patterns

Mỗi pattern có 2 case, đều lấy từ project `english-center-system-clean` (Spring Boot). Đường dẫn file tính từ `backend/src/main/java/com/trinh/english_center_be/`. Mỗi case gồm: tình huống (chỗ thật trong code), vấn đề, cách giải, và phần "Nhìn vào đâu" để tự kiểm tra. Code Java rút gọn (bỏ import, getter), không ghi số liệu đo đạc.

Cách đọc nhãn:
- **Code hiện tại:** trích từ project, có file và dòng.
- **Đề xuất:** project chưa có, là code gợi ý để áp dụng pattern. Không phải code đã chạy trong project.

## Mục lục
- [Singleton](#singleton): [Case 1](#case-1-singleton-mailservice-dùng-chung), [Case 2](#case-2-singleton-một-datasource-cho-cả-app)
- [Factory Method](#factory-method): [Case 3](#case-3-factory-method-chọn-kênh-gửi-otp), [Case 4](#case-4-factory-method-hmac-của-jdk)
- [Strategy](#strategy): [Case 5](#case-5-strategy-các-loại-mail-otp), [Case 6](#case-6-strategy-luật-xét-điều-kiện-ghi-danh)
- [Observer](#observer): [Case 7](#case-7-observer-gửi-mail-sau-khi-tạo-otp), [Case 8](#case-8-observer-user-đăng-ký)
- [Builder](#builder): [Case 9](#case-9-builder-tạo-enrollment), [Case 10](#case-10-builder-errorresponse)
- [Adapter](#adapter): [Case 11](#case-11-adapter-gửi-mail-qua-javamailsender), [Case 12](#case-12-adapter-gửi-mail-ở-môi-trường-dev)
- [State](#state): [Case 13](#case-13-state-trạng-thái-khóa-học), [Case 14](#case-14-state-trạng-thái-ghi-danh)

---

## Singleton

### Case 1. Singleton, MailService dùng chung
**Tình huống (code hiện tại):** `MailService` (`modules/auth/service/MailService.java:24-41`) là `@Service`, giữ cấu hình đọc từ `application.yml` (`mail.from`, `app.name`, `app.frontend-url`, `auth.otp.ttl-minutes`). `MailService` được inject vào `OtpSenderFactory` (`modules/auth/service/otp/OtpSenderFactory.java`). `OtpSenderFactory` cũng là bean singleton, hai service dùng chung một bản: `EmailVerificationServiceImpl.java:43` và `PasswordResetServiceImpl.java:53` (`private final OtpSenderFactory otpSenders;`).

**Vấn đề nếu mỗi nơi tự tạo bản riêng:** mỗi bản phải nạp lại cấu hình, các bản có thể lệch nhau. Ngoài ra field `@Value` chỉ được điền khi Spring tạo bean, tự `new MailService(...)` thì các field này là `null`.

**Cách giải (code hiện tại):** Spring bean mặc định là singleton. Project không dùng `@Scope`, nên cả hai service nhận cùng một object.
```java
@Service
public class MailService {
    @Value("${mail.from:no-reply@english-center.local}")
    private String from;
    // ...
}
// nơi dùng: chỉ khai báo, Spring đưa đúng một bản
private final OtpSenderFactory otpSenders;
```

**Nhìn vào đâu:**
- Tạm thời log `System.identityHashCode(otpSenders)` trong `sendCode` của `EmailVerificationServiceImpl` và `issueCode` của `PasswordResetServiceImpl`. Kỳ vọng thấy cùng một giá trị.
- Lưu ý: vì dùng chung cho mọi request, các field của `MailService` chỉ nên là cấu hình đọc-không-đổi. Không lưu dữ liệu của một request (ví dụ email người nhận) vào field.

### Case 2. Singleton, một DataSource cho cả app
**Tình huống (code hiện tại):** `src/main/resources/application.yml:14-17` chỉ khai báo `url`, `username`, `password` cho MySQL. Project không tự tạo pool.

**Vấn đề nếu mỗi request tự tạo pool:** số kết nối tới MySQL tăng theo số request, dễ gặp lỗi `Too many connections`.

**Cách giải (code hiện tại):** Spring Boot tự tạo **một** `DataSource` (HikariCP là pool mặc định) làm bean singleton, mọi repository và request dùng lại nó.

**Nhìn vào đâu:** chạy nhiều request song song vào API (ví dụ danh sách khóa học), rồi trong MySQL chạy `SHOW STATUS LIKE 'Threads_connected';`. Kỳ vọng số kết nối ổn định quanh kích thước pool, không tăng theo số request.

---

## Factory Method

### Case 3. Factory Method, chọn kênh gửi OTP
**Tình huống (code hiện tại, đã làm):** OTP (xác nhận email, quên mật khẩu, mời tài khoản) cần gửi tới người dùng. Hiện chỉ có mail, nhưng user đã có số điện thoại (`modules/user/entity/User.java:37`) nên sau này có thể gửi SMS.

**Vấn đề:** trước đây `EmailVerificationServiceImpl` và `PasswordResetServiceImpl` gọi thẳng `mailService.send...`. Thêm kênh SMS phải sửa cả hai service, và hai service dính chặt vào `MailService`.

**Cách giải (code hiện tại):** package `modules/auth/service/otp/` gồm `OtpChannel` (EMAIL, SMS), `OtpPurpose`, `OtpSender` (interface), `EmailOtpSender`, `SmsOtpSender`, `OtpSenderFactory`.
```java
@Component
@RequiredArgsConstructor
public class OtpSenderFactory {
    private final MailService mailService;

    public OtpSender create(OtpChannel channel) {
        return switch (channel) {
            case EMAIL -> new EmailOtpSender(mailService);
            case SMS -> new SmsOtpSender();
        };
    }
}

// nơi dùng: EmailVerificationServiceImpl.java:76
otpSenders.create(OtpChannel.EMAIL).send(OtpPurpose.VERIFY_EMAIL, user, otp);
```
- Mặc định kênh `EMAIL`: `EmailOtpSender` gọi `MailService` như cũ (vẫn `@Async`).
- Kênh `SMS`: chưa có provider nên `SmsOtpSender.send` ném `UnsupportedOperationException`, không âm thầm bỏ mất mã OTP.

**Nhìn vào đâu:** chạy `./mvnw test -Dtest=OtpSenderFactoryTest` (3 test). Kỳ vọng: `create(EMAIL)` trả `EmailOtpSender`, `create(SMS)` trả `SmsOtpSender`, gửi SMS ném `UnsupportedOperationException`. Thêm kênh mới chỉ thêm một class `OtpSender` và một `case` trong factory, hai service không sửa.

**Chỗ khác có thể áp dụng (đề xuất, project chưa có):** `modules/user/service/RoleProfileService.java:32-72` có hai `switch (role)` tạo/gỡ `Teacher` hoặc `Student`. Có thể gom thành `RoleProfileFactory` trả về handler theo role, thêm role mới chỉ thêm một class.

### Case 4. Factory Method, HMAC của JDK
**Tình huống (code hiện tại):** để băm OTP, project gọi `Mac.getInstance("HmacSHA256")` ở `EmailVerificationServiceImpl.java:107` (trong `hmac(...)`, dòng 105-114) và `PasswordResetServiceImpl.java:158`. `MessageDigest.getInstance("SHA-256")` ở `RefreshTokenServiceImpl.java:163`.

**Vấn đề:** mỗi thuật toán là một class riêng của JDK. Nếu code phải `new` thẳng từng class thì đổi thuật toán phải sửa chỗ tạo và cả chỗ dùng.

**Cách giải (code hiện tại, do JDK viết):** `getInstance(tên)` là Factory Method: đưa tên thuật toán vào, nhận object đúng loại.
```java
Mac mac = Mac.getInstance("HmacSHA256");
mac.init(new SecretKeySpec(otpSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
return HexFormat.of().formatHex(mac.doFinal(data));
```

**Nhìn vào đâu:** đổi chuỗi thuật toán (ở cả `Mac.getInstance` lẫn `SecretKeySpec`) thì phần còn lại của hàm không đổi. Lưu ý: đây là Factory của JDK, không phải code tự viết của project. Factory tự viết của project là `OtpSenderFactory` ở Case 3.

---

## Strategy

### Case 5. Strategy, các loại mail OTP
> **Kết luận:** chưa hợp, giữ `switch`.

**Tình huống (code hiện tại):** `modules/auth/service/MailService.java:77-81`, `render` dùng `switch (kind)` 3 case để chọn link nút bấm.
```java
String ctaUrl = switch (kind) {
    case VERIFY_EMAIL   -> appUrl + "/auth/verify-email?email=" + email;
    case RESET_PASSWORD -> appUrl + "/auth/forgot-password";
    case ACCOUNT_INVITE -> appUrl + "/auth/forgot-password?email=" + email;
};
```

**Vì sao chưa cần:** 3 loại mail chỉ khác dữ liệu (một câu, một link) và số loại cố định. Tách thành strategy chỉ thêm file và khó đọc hơn (đã thử rồi bỏ).

**Khi nào nên đổi:** `switch` dài, hay thêm case, mỗi case có logic thật (xem lưu ý đầu mục Strategy trong README).

### Case 6. Strategy, luật xét điều kiện ghi danh
> **Kết luận:** không phải Strategy.

**Tình huống (code hiện tại):** `modules/academic/service/impl/EnrollmentServiceImpl.java:130-132` tính 3 cờ `ageEligible`, `entryLevelEligible`, `prerequisitesEligible` (3 method `static`, dòng 215-235).

**Vì sao:** Strategy là chọn **một** cách trong nhiều cách. Ở đây cả 3 luật đều chạy rồi lưu vào 3 cột riêng, nên giữ nguyên.

---

## Observer

### Case 7. Observer, gửi mail sau khi tạo OTP
**Tình huống (code hiện tại):** sau khi lưu OTP, hai service gọi `otpSenders.create(OtpChannel.EMAIL).send(...)`, mặc định đi tới `MailService` qua `EmailOtpSender`:
- `EmailVerificationServiceImpl.java:76`: `send(OtpPurpose.VERIFY_EMAIL, user, otp)`
- `PasswordResetServiceImpl.java:97-98`: chọn `ACCOUNT_INVITE` hoặc `RESET_PASSWORD` tùy `invite`, rồi `send(...)`.

**Vấn đề:** muốn thêm việc khác khi phát OTP (ví dụ ghi log audit), phải sửa cả hai service vì mỗi service tự gọi việc gửi. Việc chọn kênh mail hay SMS đã do `OtpSenderFactory` lo (Case 3).

**Cách giải (đề xuất):** phát event, mail là một listener.
```java
record OtpIssued(String email, String fullName, String otp, Kind kind) {}

// trong service, thay cho otpSenders.create(OtpChannel.EMAIL).send(...)
publisher.publishEvent(new OtpIssued(user.getEmail(), user.getFullName(), otp, Kind.VERIFY_EMAIL));

@Component
class MailOtpListener {
    @EventListener
    void on(OtpIssued e) { /* gọi otpSenders.create(OtpChannel.EMAIL).send(...) */ }
}
```
Lưu ý: event mang mã OTP rõ, chỉ dùng trong cùng process, không ghi log nội dung event. `MailService` đã `@Async` (dòng 57), nên listener mặc định chạy đồng bộ vẫn không chặn request.

**Nhìn vào đâu:** gọi API quên mật khẩu rồi xem listener có chạy. Kỳ vọng hai service không còn import `OtpSenderFactory`. Thêm listener ghi audit chỉ thêm một class, hai service không đổi.

### Case 8. Observer, user đăng ký
**Tình huống (code hiện tại, đã làm):** khi đăng ký, sau khi lưu user cần làm hai việc: tạo hồ sơ học viên và gửi mã xác nhận email.

**Vấn đề (trước khi sửa):** `AuthServiceImpl.signup` gọi thẳng hai service, nên hàm đăng ký biết hết các việc phải làm. Thêm việc mới (ghi log, báo admin...) là sửa thêm hàm này.
```java
userService.save(user);
roleProfileService.onAssigned(user, Roles.STUDENT);   // tạo hồ sơ học viên
emailVerificationService.sendCode(user.getEmail());   // gửi mã xác nhận email
```

**Cách giải (code hiện tại):** `modules/auth/event/` gồm `UserRegistered`, `StudentProfileListener`, `VerificationCodeListener`.
```java
// AuthServiceImpl.java:146: chỉ phát tín hiệu
userService.save(user);
eventPublisher.publishEvent(new UserRegistered(user));

// mỗi việc là một listener, tự chạy khi có tín hiệu
@EventListener @Order(1) void on(UserRegistered e) { roleProfileService.onAssigned(e.user(), Roles.STUDENT); }
@EventListener @Order(2) void on(UserRegistered e) { emailVerificationService.sendCode(e.user().getEmail()); }
```
- `@EventListener` mặc định chạy **đồng bộ**, cùng luồng với `signup`, nên lỗi trong listener vẫn làm `signup` lỗi như trước. `@Order` giữ đúng thứ tự cũ (profile trước, mã xác nhận sau).
- Thêm việc mới sau khi đăng ký: thêm một listener, `AuthServiceImpl` không sửa.

**Nhìn vào đâu:** chạy `./mvnw test -Dtest=UserRegisteredListenersTest,AuthServiceImplLoginTest`. Kỳ vọng: `signup` phát đúng một `UserRegistered`, từng listener gọi đúng service, và test dựng Spring context nhỏ cho thấy hai listener chạy đúng thứ tự dù đăng ký ngược. Tôi chưa chạy cả app với database.


---

## Builder

### Case 9. Builder, tạo Enrollment
**Tình huống (code hiện tại):** `EnrollmentServiceImpl.java:125-134` dựng `Enrollment` với 8 field.
```java
Enrollment enrollment = Enrollment.builder()
        .course(course)
        .student(student)
        .enrollDate(LocalDate.now())
        .status(Enrollment.ACTIVE)
        .ageEligible(ageEligible(course, student))
        .entryLevelEligible(entryLevelEligible(course, student))
        .prerequisitesEligible(prerequisitesEligible(course, student))
        .eligibilityCheckDate(LocalDateTime.now())
        .build();
```
Builder này do Lombok sinh (`@SuperBuilder` trên `Enrollment.java`), không tự viết như trong README.

**Vấn đề nếu dùng constructor:** `Enrollment` có `@AllArgsConstructor` với 9 tham số theo thứ tự field. Ba cờ `Boolean` đứng liền nhau, đổi chỗ vẫn compile.
```java
new Enrollment(null, student, course, LocalDate.now(), "ACTIVE", a, b, c, LocalDateTime.now());
// a, b, c là cờ nào? đổi chỗ vẫn chạy nhưng sai nghĩa
```

**Nhìn vào đâu:** đọc đoạn builder là biết từng giá trị là gì. Không cần điền `id` (do `@UuidGenerator` sinh). Field nào không gọi thì để `null`.

### Case 10. Builder, ErrorResponse
**Tình huống (code hiện tại):** `shared/exception/ErrorResponse.java:11` (`@Builder`) có 6 field: `message`, `status`, `timestamp`, `path`, `origin`, `errors`. `GlobalExceptionHandler.java:30-36` dựng nó cho `BusinessException`:
```java
ErrorResponse response = ErrorResponse.builder()
        .status(ex.getStatus())
        .message(ex.getMessage())
        .timestamp(LocalDateTime.now())
        .path(request.getRequestURI())
        .origin(ex.getOrigin() != null ? ex.getOrigin() : "business")
        .build();
```

**Vấn đề:** `errors` chỉ có ở lỗi validate, các lỗi khác không có. Constructor 6 tham số buộc phải truyền `null` cho `errors`.

**Cách giải (code hiện tại):** builder cho phép bỏ qua field không cần. Cùng `builder()` này được dùng ở nhiều handler (`GlobalExceptionHandler.java:30, 50, 75, 95, 113, 132`).

**Nhìn vào đâu:** gọi API gây `BusinessException` (ví dụ ghi danh vào khóa học đã đóng) rồi xem body trả về. Kỳ vọng thấy `message`, `status`, `timestamp`, `path`, `origin`, và không có `errors`, vì `ErrorResponse` có `@JsonInclude(NON_NULL)