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
**Tình huống (code hiện tại):** `MailService.java` có 3 method gửi mail: `sendPasswordResetOtp` (dòng 58), `sendAccountInviteOtp` (dòng 63), `sendEmailVerificationOtp` (dòng 68). Method `render` (dòng 74-83) dùng `switch (kind)` để chọn link nút bấm (dòng 77-81).

**Vấn đề:** thêm một loại mail mới phải thêm giá trị `Kind`, một method, và một `case` trong `switch`.
```java
String ctaUrl = switch (kind) {
    case VERIFY_EMAIL   -> appUrl + "/auth/verify-email?email=" + email;
    case RESET_PASSWORD -> appUrl + "/auth/forgot-password";
    case ACCOUNT_INVITE -> appUrl + "/auth/forgot-password?email=" + email;
};
```

**Cách giải (đề xuất):** mỗi loại mail là một strategy, cùng interface.
```java
interface MailStrategy {
    String codeLine();                           // "Mã xác nhận email của bạn là: %s"
    String ctaUrl(String appUrl, String email);  // link nút bấm
}
Map<Kind, MailStrategy> mails = Map.of(
    Kind.VERIFY_EMAIL, new VerifyEmailMail(),
    Kind.RESET_PASSWORD, new ResetPasswordMail(),
    Kind.ACCOUNT_INVITE, new AccountInviteMail());

String ctaUrl = mails.get(kind).ctaUrl(appUrl, email);
```

**Nhìn vào đâu:** `render` đã có comment ở dòng 73 "package-private so tests can check it without SMTP", nên test được mà không cần gửi mail. Gọi `render(Kind.VERIFY_EMAIL, ...)` và kiểm tra HTML chứa `/auth/verify-email?email=`. Sau khi tách, mỗi strategy có test riêng, thêm loại mail mới không phải sửa `switch`.

### Case 6. Strategy, luật xét điều kiện ghi danh
**Tình huống (code hiện tại):** `modules/academic/service/impl/EnrollmentServiceImpl.java`. Khi ghi danh, project tính 3 cờ (dòng 130-132): `ageEligible`, `entryLevelEligible`, `prerequisitesEligible`. Mỗi cờ là một method `static` riêng (dòng 215-235), cùng dạng `(Course, Student) -> Boolean`, trả `null` khi thiếu dữ liệu (ví dụ dòng 217).

**Vấn đề:** thêm một luật mới (ví dụ giới hạn nhóm ngành) phải thêm method, thêm dòng trong `builder`, và thêm cột trong `Enrollment`.

**Cách giải (đề xuất):** coi mỗi luật là một strategy cùng interface.
```java
interface EligibilityRule {
    Boolean check(Course course, Student student); // null = chưa đủ dữ liệu để kết luận
}
class AgeRule implements EligibilityRule { /* nội dung ageEligible */ }
class EntryLevelRule implements EligibilityRule { /* nội dung entryLevelEligible */ }
class PrerequisiteRule implements EligibilityRule { /* nội dung prerequisitesEligible */ }

List<EligibilityRule> rules = List.of(new AgeRule(), new EntryLevelRule(), new PrerequisiteRule());
```
Lưu ý: `Enrollment` đang lưu 3 cột riêng cho 3 luật, nên thêm luật vẫn phải thêm cột nếu muốn lưu kết quả. Strategy chỉ giúp gom và test logic từng luật.

**Nhìn vào đâu:** test từng rule riêng. Ví dụ `ageEligible` phải trả `null` khi `course.getMinimumAge()` hoặc `student.getDateOfBirth()` là `null` (dòng 217), trả `true`/`false` khi đủ dữ liệu. Các test này không cần dựng `EnrollmentServiceImpl`.

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
**Tình huống (code hiện tại):** `modules/auth/service/impl/AuthServiceImpl.java:146-148`. Sau khi lưu user, hàm đăng ký gọi lần lượt hai việc:
```java
userService.save(user);
roleProfileService.onAssigned(user, Roles.STUDENT);   // tạo hồ sơ học viên
emailVerificationService.sendCode(user.getEmail());   // gửi mã xác nhận email
```

**Vấn đề:** hàm đăng ký biết hết các việc phải làm sau khi có user. Thêm việc mới (ví dụ ghi log, gửi thông báo cho admin) là sửa thêm hàm này.

**Cách giải (đề xuất):** phát một event `UserRegistered`, mỗi việc là một listener.
```java
record UserRegistered(String userId, String email) {}

userService.save(user);
publisher.publishEvent(new UserRegistered(user.getId(), user.getEmail()));

@Component class CreateStudentProfileListener { @EventListener void on(UserRegistered e) { /* onAssigned */ } }
@Component class SendVerificationListener      { @EventListener void on(UserRegistered e) { /* sendCode */ } }
```
Lưu ý: `@EventListener` mặc định chạy đồng bộ trong cùng thread, giữ được thứ tự và transaction hiện tại. Trước khi tách cần xem lại ranh giới transaction của hàm đăng ký, vì `@TransactionalEventListener` sẽ chạy sau khi commit, tạo hồ sơ học viên khi đó không còn nằm cùng transaction với việc lưu user.

**Nhìn vào đâu:** đăng ký một tài khoản rồi kiểm tra cả hai việc vẫn xảy ra (có bản ghi `Student`, có email mã xác nhận). Hàm đăng ký không còn gọi trực tiếp `roleProfileService` và `emailVerificationService`.

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

**Nhìn vào đâu:** gọi API gây `BusinessException` (ví dụ ghi danh vào khóa học đã đóng) rồi xem body trả về. Kỳ vọng thấy `message`, `status`, `timestamp`, `path`, `origin`, và không có `errors`, vì `ErrorResponse` có `@JsonInclude(NON_NULL)`.

---

## Adapter

### Case 11. Adapter, gửi mail qua JavaMailSender
**Tình huống (code hiện tại):** `MailService.java:85-101`, hàm `send`, gọi trực tiếp `JavaMailSender` của Spring (import ở dòng 13): `createMimeMessage`, `MimeMessageHelper`, `sender.send(message)`.

**Vấn đề:** phần nghiệp vụ (chọn tiêu đề, nội dung theo loại mail) và phần cách gửi (API riêng của `JavaMailSender`) nằm chung trong một hàm. Đổi sang nhà cung cấp khác (SendGrid, SES) phải sửa hàm này.

**Cách giải (đề xuất):** `MailService` chỉ biết một interface do mình quy định, mỗi nhà cung cấp có một adapter.
```java
interface EmailGateway {
    void send(String to, String subject, String textBody, String htmlBody);
}

class JavaMailAdapter implements EmailGateway {
    private final JavaMailSender sender;
    public void send(String to, String subject, String text, String html) {
        MimeMessage message = sender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
        helper.setTo(to); helper.setSubject(subject); helper.setText(text, html);
        sender.send(message);
    }
}
// MailService: gateway.send(to, subject, text, html)
```

**Nhìn vào đâu:** tìm `JavaMailSender` trong code. Sau khi áp dụng, chỉ còn trong `JavaMailAdapter`. Đổi nhà cung cấp là thêm adapter mới và đổi chỗ khai báo bean, `MailService` không sửa.

### Case 12. Adapter, gửi mail ở môi trường dev
**Tình huống (code hiện tại):** `MailService.java:86-90`. Khi chưa cấu hình SMTP, `send` không gửi mà ghi log rồi thoát:
```java
JavaMailSender sender = mailSender.getIfAvailable();
if (sender == null) {
    log.warn("[DEV MAIL] {} for {}: {}", kind.title, to, otp);
    return;
}
```
Ở profile `prod`, nếu chưa có SMTP thì app báo lỗi lúc khởi động (`MailService.java:51-53`).

**Vấn đề:** hàm `send` phải tự rẽ nhánh "có SMTP hay không". Đây thực chất là hai cách gửi (gửi thật, chỉ ghi log) nằm trong một `if`.

**Cách giải (đề xuất):** dùng cùng `EmailGateway` ở Case 11 với hai adapter: `JavaMailAdapter` (gửi thật) và `LogOnlyAdapter` (chỉ ghi log). Cấu hình chọn adapter nào được dùng, `send` không còn `if`.
```java
class LogOnlyAdapter implements EmailGateway {
    public void send(String to, String subject, String text, String html) {
        log.warn("[DEV MAIL] {} to {}: {}", subject, to, text);
    }
}
```

**Nhìn vào đâu:** chạy app ở profile dev không có SMTP, gọi quên mật khẩu, kỳ vọng thấy dòng `[DEV MAIL]` trong log như hiện tại. Chạy profile `prod` không có SMTP, kỳ vọng app dừng khi khởi động. Hành vi giữ nguyên, chỉ khác là không còn `if` trong `send`.

---

## State

### Case 13. State, trạng thái khóa học
**Tình huống (code hiện tại):** `shared/enums/CourseStatus.java` có 3 giá trị `OPEN`, `CLOSE`, `ACTIVE` (kèm `label`), chưa có luật chuyển. Hàm `apply` trong `CourseServiceImpl.java:152-165` gán thẳng `course.setStatus(request.status())` (dòng 161). Khi ghi danh, `EnrollmentServiceImpl.java:92` chỉ kiểm tra `course.getStatus() == CourseStatus.CLOSE`.

**Vấn đề:** request nào cũng đặt được trạng thái bất kỳ, kể cả mở lại khóa học đã `CLOSE`. Luật "đi từ đâu sang đâu" không nằm ở đâu cả.

**Cách giải (đề xuất):** thêm `canMoveTo` cho enum. Luật dưới đây là **giả định** để minh họa, cần xác nhận với nghiệp vụ trung tâm trước khi dùng.
```java
public enum CourseStatus {
    OPEN("Open"), CLOSE("Close"), ACTIVE("Active");

    public boolean canMoveTo(CourseStatus target) {
        return switch (this) {
            case OPEN   -> target == ACTIVE || target == CLOSE;
            case ACTIVE -> target == CLOSE;
            case CLOSE  -> false;
        };
    }
}

if (course.getStatus() != null && !course.getStatus().canMoveTo(request.status())) {
    throw new BusinessException("Course status change is not allowed", HttpStatus.CONFLICT);
}
```
Lưu ý: khi tạo mới, `course.getStatus()` còn `null` nên cần xử lý riêng, và cần xem `apply` có được dùng cho cả tạo mới lẫn cập nhật.

**Nhìn vào đâu:** viết test cho hai ca: `OPEN -> ACTIVE` phải cho phép, `CLOSE -> OPEN` phải bị chặn. Với REST API, lỗi này trả HTTP `409 Conflict`, giống cách project đang trả ở `EnrollmentServiceImpl.java:93`.

### Case 14. State, trạng thái ghi danh
**Tình huống (code hiện tại):** `Enrollment.java:28-29` định nghĩa trạng thái bằng chuỗi `ACTIVE` và `CANCELLED`, field `status` là `String` (dòng 46). Chỗ đổi trạng thái:
- `EnrollmentServiceImpl.java:146`: `enrollment.setStatus(Enrollment.CANCELLED)` trong `cancel`.
- `RoleProfileService.java:65`: hủy các ghi danh `ACTIVE` khi gỡ role học viên.

**Hiện trạng:** cả hai chỗ đều chỉ lấy các bản ghi đang `ACTIVE` trước khi hủy (`EnrollmentServiceImpl.java:144`, `RoleProfileService.java:64`), nên hiện chưa hủy được hai lần. Luật này nằm rải ở câu truy vấn, không nằm ở chỗ nào gọi tên.

**Vấn đề:** khi có thêm trạng thái (ví dụ hoàn thành khóa), mỗi chỗ gọi `setStatus` phải tự nhớ lọc đúng. Một chỗ quên là chuyển sai.

**Cách giải (đề xuất):**
```java
public enum EnrollmentStatus {
    ACTIVE, CANCELLED;

    public boolean canMoveTo(EnrollmentStatus target) {
        return this == ACTIVE && target == CANCELLED; // CANCELLED là trạng thái cuối
    }
}
```
Lưu ý: chuỗi `ACTIVE`/`CANCELLED` còn được dùng ở trigger `trg_enrollments_before_insert` (xem comment `Enrollment.java:18-20`), nên khi đổi sang enum phải giữ nguyên giá trị chuỗi lưu trong DB.

**Nhìn vào đâu:** viết test `ACTIVE -> CANCELLED` cho phép, `CANCELLED -> ACTIVE` bị chặn. Sau khi áp dụng, `cancel` và `RoleProfileService` cùng đi qua một chỗ kiểm tra thay vì mỗi nơi tự lọc.
