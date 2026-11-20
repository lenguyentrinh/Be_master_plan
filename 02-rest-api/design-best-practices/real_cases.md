# Real cases: Design best practices

Tất cả case lấy từ project `D:\WorkSpace\vibeCode\english-center-system-clean` (Spring Boot, MySQL). Đường dẫn Java bên dưới tính từ `backend/src/main/java/com/trinh/english_center_be/`. Toàn bộ API có context-path `/api` (`backend/src/main/resources/application.yml`, `server.servlet.context-path`). Không ghi số liệu, chỉ ghi nhìn vào đâu và kỳ vọng thấy gì. Mục nào project chưa có thì ghi rõ "project chưa có".

Domain trong project: `courses` (khóa học), `users`, `teachers`, `categories`, `enrollments` (học viên đăng ký khóa học), `sessions` (buổi học của khóa).

## Case 1
**Mục 1: RESTful web API design concepts** (stateless, uniform interface)
- Stateless: `shared/config/SecurityConfig.java:44` đặt `SessionCreationPolicy.STATELESS`. Server không giữ session, mỗi request tự mang thông tin xác thực.
- Danh tính lấy từ request, không lấy từ bộ nhớ server: `EnrollmentController.java` có `actingUserId(Authentication auth)` đọc user từ `auth.getPrincipal()`.
- Uniform interface: các controller dùng chung `GET/POST/PUT/DELETE` trên `/courses`, `/users`, `/teachers`, `/categories`.
- Chạy thử: `POST /api/auth/login` lấy token, gọi `GET /api/auth/me` kèm token thì thấy user hiện tại, bỏ token thì bị từ chối.

## Case 2
**Mục 2: Define RESTful web API resource URIs**
- **Tốt, danh từ số nhiều và lồng 1 cấp:** `/courses`, `/courses/{id}`, `/courses/{courseId}/sessions` (`SessionController.java:26`), `/courses/{id}/students` (`EnrollmentController.java:39`), `/users/{id}/enrollments` (dòng 79). Đúng dạng collection/item/collection.
- **Có động từ trong URI (bài khuyên tránh):**
  - `POST /courses/{id}/enroll` và `DELETE /courses/{id}/enroll` (`EnrollmentController.java:57, 65`): học viên tự đăng ký / hủy.
  - `POST /courses/{id}/assign-teacher/{teacherId}` (`CourseController.java:77`).
  - Nhóm `/auth/*`: `login`, `signup`, `verify-email`, `forgot-password`... (`AuthController.java`).
- **Một việc có hai URI:** admin ghi danh học viên bằng `POST /courses/{id}/students` (dòng 49), học viên tự đăng ký bằng `POST /courses/{id}/enroll` (dòng 57). Cùng tạo một enrollment nhưng tách URI theo người gọi (phân quyền `hasRole('ADMIN')` và `hasRole('STUDENT')`).
- **Đường dẫn cố định đặt cạnh đường dẫn có biến:** `GET /courses/schedule` (`CourseController.java:89`) cùng controller với `GET /courses/{id}`. Spring ưu tiên đường dẫn cố định nên `schedule` không bị hiểu thành `id`. Kỳ vọng: gọi `/api/courses/schedule` ra lịch dạy, không phải lỗi không tìm thấy khóa học.

## Case 3
**Mục 3: Define RESTful web API methods** (method, status code, PUT vs PATCH)
- **POST tạo mới trả 201:** `CourseController.java:55-56` (`ResponseEntity.status(HttpStatus.CREATED)`), tương tự `UserController.java:76`, `CategoryController.java:41`, `EnrollmentController.java:52`.
- **POST không tạo resource trả 200:** `assignTeacher` (`CourseController.java:77-82`) trả `ResponseEntity.ok`. Đúng theo bài: POST xử lý mà không tạo resource thì trả 200.
- **409 Conflict cho vi phạm nghiệp vụ** (`BusinessException(..., HttpStatus.CONFLICT)`), gồm:
  - `EnrollmentServiceImpl.java:99` "Student is already enrolled in this course".
  - Dòng 103 "Class is full".
  - Dòng 77 "Course is not open for enrollment".
  - `CategoryServiceImpl.java:83` không xóa được category đang được course dùng.
  - Kỳ vọng khi test: đăng ký một học viên vào cùng khóa hai lần thì lần hai nhận `409`.
- **400 cho dữ liệu sai:** `EnrollmentServiceImpl.java:94` "User is not a student" trả `400`. Body sai validate (`@Valid @RequestBody`) trả `400` kèm `errors` theo từng field (`shared/exception/GlobalExceptionHandler.java:41-62`).
- **Định dạng lỗi thống nhất:** `ErrorResponse` gồm `status`, `message`, `timestamp`, `path`, `origin` (và `errors` khi lỗi validate) do `GlobalExceptionHandler` tạo ra.
- **Định dạng thành công thống nhất:** mọi endpoint bọc `ApiResponse<>(200, message, data)`.
- **PUT dùng cho sub-resource:** `PUT /users/{id}/role` (`UserController.java:82`) comment trong code ghi "Gives the user exactly one role, replacing the previous one", tức thay thế toàn bộ giá trị role. Đây là cách dùng PUT đúng nghĩa thay thế.
- **Project không dùng PATCH:** tìm `PatchMapping` trong `backend/src/main/java` không có kết quả. Cập nhật một phần cũng dùng `PUT` (`PUT /users/{id}`, `PUT /courses/{id}`).
- **DELETE trả 200 kèm body:** `CourseController.java:70-74` trả `ApiResponse<Void>` với status 200, bài khuyên `204 No Content`. Tìm `NO_CONTENT` trong project không có kết quả.
- **Content negotiation:** không có xử lý riêng cho `Accept` / `415` / `406`, dùng mặc định của Spring.

## Case 4
**Mục 4: Implement asynchronous methods**
- Project chưa có endpoint nào trả `202 Accepted` kèm `Location` để polling (tìm `ACCEPTED` không có kết quả).
- Có xử lý bất đồng bộ **bên trong service**: `@EnableAsync` ở `shared/config/SecurityConfig.java:28`, và `modules/auth/service/MailService.java:57, 62, 68` đánh `@Async` cho việc gửi mail. Nhờ vậy request như `POST /auth/signup` hay `POST /auth/forgot-password` không phải chờ gửi mail xong. Nhưng client vẫn nhận response thường, không có endpoint hỏi tiến độ, nên chưa phải mẫu 202 của bài.

## Case 5
**Mục 5: Implement data pagination and filtering**
- **Phân trang + lọc:** `GET /users/search?q=&role=&status=&page=1&size=10` (`UserController.java:51-58`). Mặc định `page=1`, `size=10`.
- **Giới hạn trên chống DoS (đúng bài):** `UserServiceImpl.java:44` `MAX_PAGE_SIZE = 100`, dòng 84 `Math.min(Math.max(size, 1), MAX_PAGE_SIZE)`. Kỳ vọng: gọi `size=100000` thì response chỉ trả tối đa 100 item.
- **Response phân trang:** `shared/response/PageResponse.java` trả `{items, total, page, size}`, `page` bắt đầu từ 1.
- **Lọc theo khoảng thời gian có giới hạn:** `GET /courses/schedule?from=&to=` (`CourseController.java:89-98`), vượt `MAX_RANGE_DAYS` thì `400` (`CourseScheduleServiceImpl.java:40`).
- **Lọc theo trạng thái:** `GET /courses/{id}/students?status=` (`EnrollmentController.java:39-43`).
- **Điểm cần lưu ý:** phân trang làm trong bộ nhớ, lấy toàn bộ `matches` rồi cắt `subList` (`UserServiceImpl.java:99-101`). Với bảng lớn thì nên đẩy phân trang xuống database.
- **Chưa phân trang:** `GET /courses` (`CourseController.java:39`) và `GET /users` (`UserController.java:42`) trả toàn bộ danh sách.
- Chưa thấy `sort` và `fields` (field selection).

## Case 6
**Mục 6: Support partial responses**
- Project chưa có (không có `Accept-Ranges`, `Content-Range`, xử lý header `Range`). Project không phục vụ file lớn qua API.

## Case 7
**Mục 7: Implement HATEOAS**
- Project chưa có. Response chỉ có `ApiResponse<>(status, message, data)`, không kèm `links`. Client tự biết URL (ví dụ tự ghép `/courses/{id}/students`).

## Case 8
**Mục 8: Implement versioning**
- Project chưa có versioning: không có `/v1` trong đường dẫn, chỉ có context-path `/api`. Tìm `/v1` trong `backend/src/main/java` không có kết quả.
- Kỳ vọng khi gặp breaking change (ví dụ đổi cấu trúc `CourseResponse`): client cũ sẽ vỡ ngay vì không có bản cũ chạy song song. Muốn an toàn thì cần thêm tiền tố (URI versioning) hoặc header trước khi đổi.

## Case 9
**Mục 9: Multitenant web APIs**
- Project chưa có multitenant: hệ thống phục vụ một trung tâm, không có khái niệm tenant (tìm `tenant` không có kết quả).
- Cách phân biệt dữ liệu theo người dùng là **role và chủ sở hữu**, không phải tenant: `@PreAuthorize("hasRole('ADMIN') or #id == authentication.principal.id")` (`UserController.java:65`, `EnrollmentController.java:80`). Kỳ vọng: học viên gọi `GET /users/{id}/enrollments` với id của người khác thì bị từ chối (`GlobalExceptionHandler.java:106` xử lý `AccessDeniedException`).

## Case 10
**Mục 10: Enable distributed tracing and trace context in APIs**
- Project chưa có header `Correlation-ID` / `X-Request-ID`, cũng không có MDC trong log (tìm không có kết quả). Đây là hệ thống một service nên nhu cầu thấp.
- Lỗi hiện có `timestamp` và `path` (`ErrorResponse`) giúp tìm log, nhưng chưa có mã truy vết riêng cho từng request.

## Case 11
**Mục 11: Web API maturity model**
- Project ở **Level 2**: mỗi resource có URI riêng (Level 1), dùng đúng `GET/POST/PUT/DELETE` và status code `201`, `400`, `409` (Level 2). Chưa có hypermedia (Level 3, xem Case 7).
- Một số endpoint hành động (`enroll`, `assign-teacher`, `/auth/*`) mang tính RPC hơn resource (xem Case 2).

## Case 12
**Mục 12: OpenAPI Initiative**
- Project có springdoc OpenAPI: dependency `springdoc-openapi-starter-webmvc-ui` (`backend/pom.xml:99-100`), cấu hình ở `application.yml` mục `springdoc` (`api-docs.path: /v3/api-docs`, `swagger-ui.path: /swagger-ui.html`). Swagger được mở trong `SecurityConfig.java:53-54`.
- Chạy thử: mở `http://localhost:8080/api/swagger-ui/index.html` (theo `README.md` của project).
- Đây là **code-first** (sinh tài liệu từ code), ngược với contract-first mà bài khuyến khích.
