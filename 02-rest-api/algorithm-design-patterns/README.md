# Algorithm

- **Domain:** REST API
- **Week:** Week 5-6

## Mục lục
- [Algorithm](#algorithm)
  - [Mục lục](#mục-lục)
  - [Reference](#reference)
  - [Key concepts](#key-concepts)
    - [Design pattern là gì](#design-pattern-là-gì)
    - [1. Singleton](#1-singleton)
    - [2. Factory Method](#2-factory-method)
    - [3. Strategy](#3-strategy)
    - [4. Observer](#4-observer)
    - [5. Builder](#5-builder)
    - [6. Adapter](#6-adapter)
    - [7. State](#7-state)
    - [Tổng hợp](#tổng-hợp)
  - [Q\&A](#qa)
  - [Hands-on](#hands-on)
  - [Done](#done)
  - [Slide](#slide)

## Reference
- [The 7 most important software design patterns](https://www.educative.io/blog/the-7-most-important-software-design-patterns)

## Key concepts

Các ví dụ lấy từ project `english-center-system-clean`. Code là Java rút gọn, chỉ để thấy ý tưởng. Chỗ nào project chưa có thì ghi là đề xuất. Chi tiết từng case xem [real_cases.md](real_cases.md).

### Design pattern là gì
- Là những mẫu thiết kế có sẵn để giải quyết những vấn đề chúng ta hay gặp.

Cách học design pattern:
- Xem context, UML, code example
- Phải nhớ pattern giải quyết vấn đề gì
- Học và tìm hiểu pattern trong framework
- Áp dụng vào thực tế

- Lợi ích: team nói "dùng Strategy" là ai cũng hiểu ngay, khỏi giải thích dài.
- Lưu ý: không có vấn đề thật mà vẫn dùng pattern thì code chỉ rối thêm.

### 1. Singleton
- **Khái niệm:** Singleton pattern là một design pattern mà toàn bộ hệ thống chỉ có một đối tượng của class đó, giúp hệ thống tiết kiệm bộ nhớ và dễ quản lý tài nguyên dùng chung. Ví dụ: config dự án, kết nối với mail service, kết nối đến DB.

- **Ưu điểm:** tiết kiệm tài nguyên (chỉ tạo một lần).
- **Nhược điểm:** dễ thành biến global trá hình, khó test (khó thay bằng bản giả). Dùng chung cho nhiều request nên không lưu dữ liệu riêng của một request vào đó.
- **Ví dụ:**
```java
class Config {
    private static Config instance;
    private Config() {}                       // private: bên ngoài không `new` được

    static synchronized Config get() {        // lần đầu tạo, các lần sau trả lại cái cũ
        if (instance == null) instance = new Config();
        return instance;
    }
}

Config.get() == Config.get(); // true: cùng một object
```

- Real case: [real_cases.md, Case 1](real_cases.md#case-1-singleton-mailservice-dùng-chung), [Case 2](real_cases.md#case-2-singleton-một-datasource-cho-cả-app)

### 2. Factory Method
- **Khái niệm:** Factory Pattern thuộc nhóm mẫu khởi tạo. Nó gom việc khởi tạo vào một chỗ, để không phải rải nhiều if-else khắp nơi.
- **Vấn đề:** code phải tạo object thuộc nhiều loại tùy điều kiện. Nếu chỗ nào cũng tự `if/else` rồi `new` thì thêm loại mới phải sửa khắp nơi.
- **Ưu điểm:** gom việc chọn/tạo đối tượng về một chỗ. Thêm, xóa, sửa một loại chỉ sửa ở một chỗ, nơi dùng không phụ thuộc class cụ thể.
- **Nhược điểm:** phải thêm class factory và các class cụ thể. Ít loại, cố định thì viết thẳng `if/else` còn gọn hơn.

- Real case: [real_cases.md, Case 3](real_cases.md#case-3-factory-method-chọn-kênh-gửi-otp), [Case 4](real_cases.md#case-4-factory-method-hmac-của-jdk)

### 3. Strategy
- **Khái niệm:** strategy pattern là mình tách các cách xử lý khác nhau thành các class riêng, rồi chọn strategy phù hợp lúc chạy, dựa vào tham số tương ứng thay vì `if/else`. 
- **Vấn đề:** cùng một việc nhưng có nhiều cách làm. Nhét hết vào một hàm toàn `if/else` thì thêm cách mới phải sửa hàm cũ, dễ làm hỏng nhánh đang chạy.
- **Ưu điểm:** dễ mở rộng, mỗi cách xử lý tách riêng, dễ bảo trì.
- **Nhược điểm:** thêm nhiều class, phải nhảy qua lại nhiều file mới hiểu. Ít nhánh, cố định thì dùng `switch` còn dễ đọc hơn.
- **Ví dụ:**
```java
interface MailStrategy { String ctaUrl(String appUrl, String email); }
class VerifyEmail   implements MailStrategy { public String ctaUrl(String u, String e) { return u + "/auth/verify-email?email=" + e; } }
class ResetPassword implements MailStrategy { public String ctaUrl(String u, String e) { return u + "/auth/forgot-password"; } }
class AccountInvite implements MailStrategy { public String ctaUrl(String u, String e) { return u + "/auth/forgot-password?email=" + e; } }

Map<Kind, MailStrategy> strategies = Map.of(
    Kind.VERIFY_EMAIL, new VerifyEmail(),
    Kind.RESET_PASSWORD, new ResetPassword(),
    Kind.ACCOUNT_INVITE, new AccountInvite());

String url = strategies.get(kind).ctaUrl(appUrl, email); // thêm loại mail mới: thêm 1 class + 1 dòng trong map
```

- Real case: [real_cases.md, Case 5](real_cases.md#case-5-strategy-các-loại-mail-otp), [Case 6](real_cases.md#case-6-strategy-luật-xét-điều-kiện-ghi-danh)

### 4. Observer
- **Khái niệm:** Observer Pattern là một design pattern cho phép một đối tượng thông báo cho những đối tượng khác khi có sự thay đổi hoặc một sự kiện xảy ra.
- **Vấn đề:** một hàm phải làm quá nhiều việc sau một sự kiện (ví dụ đăng ký xong thì tạo hồ sơ, gửi mã xác nhận, báo admin...). Gọi trực tiếp từng hàm thì thêm việc mới phải sửa hàm đó, hàm càng rối và dính chặt vào các việc kia.
- **Ưu điểm:** Giảm sự phụ thuộc giữa các đối tượng, dễ thêm hoặc xóa các Observer, dễ mở rộng hệ thống.
- **Nhược điểm:** Có thể khó debug vì một sự kiện có thể kích hoạt nhiều đối tượng, Khó kiểm soát luồng thực thi.
- **Ví dụ:** có người đăng ký tài khoản. Sau khi lưu xong, hệ thống phải làm vài việc: tạo hồ sơ học viên, gửi mã xác nhận email.
```java
userService.save(user);
roleProfileService.onAssigned(user, STUDENT);   // việc 1
emailVerificationService.sendCode(email);        // việc 2
```
- **Cách Observer:** hàm đăng ký chỉ thông báo một câu "có người vừa đăng ký xong". Ai quan tâm thì tự đăng ký nhận thông báo và tự làm việc của mình.
```java
userService.save(user);
publishEvent(new UserRegistered(user));   // chỉ báo tin, không biết ai nhận

@EventListener
void on(UserRegistered e) { /* ai quan tâm thì tự lắng nghe và làm việc của mình */ }
```

- Real case: [real_cases.md, Case 7](real_cases.md#case-7-observer-gửi-mail-sau-khi-tạo-otp), [Case 8](real_cases.md#case-8-observer-user-đăng-ký)

### 5. Builder
- **Khái niệm:** Builder pattern dùng khi một object có nhiều trường hoặc tham số không bắt buộc, dễ nhầm thứ tự nếu dùng constructor dài. Builder giúp mình tạo object rõ ràng hơn, từng field một, đỡ lỗi nhầm tham số và dễ đọc hơn.
- **Vấn đề:** object có nhiều thông tin, trong đó nhiều cái tùy chọn. Constructor dài rất khó đọc, dễ nhầm thứ tự tham số.
- **Ưu điểm:** đọc dễ vì mỗi giá trị có tên, không nhầm thứ tự tham số, bỏ qua được field tùy chọn, kiểm tra hợp lệ trong `build()`.
- **Nhược điểm:** viết dài hơn constructor. Object ít field thì không cần.
- **Ví dụ:**
```java
class Enrollment {
    private final Student student;
    private final Course course;
    private final LocalDate enrollDate;
    private final String status;
    private final Boolean ageEligible;

    private Enrollment(Builder b) {
        student = b.student; course = b.course; enrollDate = b.enrollDate;
        status = b.status; ageEligible = b.ageEligible;
    }

    static class Builder {
        private final Student student;
        private final Course course;
        private LocalDate enrollDate = LocalDate.now();
        private String status = "ACTIVE";
        private Boolean ageEligible;

        Builder(Student student, Course course) { this.student = student; this.course = course; }
        Builder enrollDate(LocalDate d)  { enrollDate = d; return this; }
        Builder status(String s)         { status = s; return this; }
        Builder ageEligible(Boolean b)   { ageEligible = b; return this; }

        Enrollment build() {
            if (student == null || course == null) throw new IllegalStateException("Enrollment needs student and course"); // field bắt buộc
            return new Enrollment(this);
        }
    }
}

Enrollment enrollment = new Enrollment.Builder(student, course)
    .enrollDate(LocalDate.now())
    .status("ACTIVE")
    .ageEligible(true)
    .build();
```

- Real case: [real_cases.md, Case 9](real_cases.md#case-9-builder-tạo-enrollment), [Case 10](real_cases.md#case-10-builder-errorresponse)

### 6. Adapter

### 7. State

### Tổng hợp
| Pattern | Nhóm | Dùng khi |
|---|---|---|
| Singleton | Creational | Cần đúng 1 object dùng chung (config, pool) |
| Factory Method | Creational | Tạo object theo lựa chọn, không muốn code phụ thuộc class cụ thể |
| Builder | Creational | Object có nhiều tham số, dựng từng bước |
| Adapter | Structural | Nối hai thứ có cách gọi khác nhau (đổi vendor) |
| Strategy | Behavioral | Cùng việc nhưng nhiều cách làm, chọn lúc chạy |
| Observer | Behavioral | Một thay đổi cần báo cho nhiều bên |
| State | Behavioral | Hành vi phụ thuộc trạng thái, bỏ if-else |

- App thật dùng kết hợp nhiều pattern (app giao đồ ăn trong bài dùng cả 7). Mục tiêu là code dễ bảo trì, dễ mở rộng, không phải dùng càng nhiều càng tốt.
- Cách phân nhóm Creational/Structural/Behavioral là theo Gang of Four, bài gốc không ghi.

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
