# Questions: Design best practices

Câu hỏi ôn tập theo thứ tự 12 mục của [README.md](README.md). Ví dụ lấy từ project `english-center-system-clean` (xem [real_cases.md](real_cases.md)).

## Mục lục
- [Questions: Design best practices](#questions-design-best-practices)
  - [Mục lục](#mục-lục)
  - [1. RESTful web API design concepts](#1-restful-web-api-design-concepts)
  - [2. Resource URIs](#2-resource-uris)
  - [3. Methods](#3-methods)
  - [4. Asynchronous](#4-asynchronous)
  - [5. Pagination và filtering](#5-pagination-và-filtering)
  - [6. Partial responses](#6-partial-responses)
  - [7. HATEOAS](#7-hateoas)
  - [8. Versioning](#8-versioning)
  - [9. Multitenant](#9-multitenant)
  - [10. Distributed tracing](#10-distributed-tracing)
  - [11. Maturity model](#11-maturity-model)
  - [12. OpenAPI](#12-openapi)

## 1. RESTful web API design concepts
**Q1. RESTful API là gì?**
RESTful API là API tuân theo các nguyên tắc của REST, dùng HTTP để client và server (hoặc các service) giao tiếp với nhau. REST có 6 nguyên tắc (6 constraint của Roy Fielding, không nằm trong bài MS, lấy từ kiến thức chung về REST):
1. **Client-server:** client và server tách riêng, chỉ nói chuyện qua API. Project: `frontend/` (React) gọi `backend/` (Spring Boot) qua `API_BASE_URL` (`frontend/src/shared/api/client.ts:5-8`).
2. **Stateless:** server không lưu thông tin gì về client giữa các request. Mỗi request phải tự mang đủ thông tin (ví dụ token) để server xử lý. Project: `SessionCreationPolicy.STATELESS` (`SecurityConfig.java:44`), danh tính lấy từ token JWT.
3. **Cacheable:** response nói rõ có được cache hay không (header `Cache-Control`, `ETag`). Project chưa có (không có `Cache-Control`, `ETag`, `@Cacheable`).
4. **Uniform interface:** mọi resource dùng chung một kiểu: URI là danh từ, thao tác bằng `GET/POST/PUT/DELETE`. Project: `GET/POST/PUT/DELETE` trên `/courses` (`CourseController.java`).
5. **Layered system:** giữa client và server có thể có các lớp trung gian (proxy, load balancer, gateway), client không cần biết. Project chưa có lớp trung gian riêng (`docker-compose.yml` chỉ có `mysql` và `backend`).
6. **Code on demand (tùy chọn):** server có thể gửi code cho client chạy, ví dụ JavaScript. Project chưa có.

**Q2. Stateless nghĩa là gì, lợi gì?**
Server không nhớ client giữa hai request, mỗi request tự mang đủ thông tin (token, tham số). Nhờ vậy request nào cũng có thể rơi vào server nào, dễ chạy nhiều server. Trong project: `SessionCreationPolicy.STATELESS` (`SecurityConfig.java:44`).

**Q3. Loose coupling là gì?**
Client và server chỉ thống nhất giao thức HTTP và format dữ liệu (JSON). Hai bên đổi code bên trong độc lập, client không cần biết server viết bằng ngôn ngữ gì.

## 2. Resource URIs
**Q4. `POST /create-course` sai ở đâu, sửa thế nào?**
URI chứa động từ. Hành động đã nằm ở HTTP method, nên viết `POST /courses`.

**Q5. Vì sao không viết `/users/1/enrollments/99/sessions`?**
Lồng quá sâu, khó bảo trì, đổi quan hệ là vỡ. Nên giữ tối đa dạng collection/item/collection: gọi `/users/1/enrollments` rồi `/courses/99/sessions`.

**Q6. Vì sao không nên mỗi table database là một endpoint?**
API nên mô tả nghiệp vụ, không phải cấu trúc bảng. Mirror database làm tăng attack surface, dễ lộ dữ liệu nội bộ, và đổi schema là client hỏng.

**Q7. API "chatty" là gì?**
API chia resource quá nhỏ, client phải gọi nhiều request mới đủ dữ liệu cho một màn hình. Cách giảm: gộp dữ liệu hay đi cùng nhau, nhưng đừng gộp tới mức trả dư dữ liệu client không cần.

## 3. Methods
**Q8. PUT khác PATCH thế nào?**
`PUT` thay thế cả resource (gửi đủ field), `PATCH` chỉ sửa field được gửi. Trong project không có `PATCH`, cập nhật một phần cũng dùng `PUT` (Case 3).

**Q9. Idempotent là gì? Method nào bắt buộc idempotent?**
Gọi nhiều lần kết quả vẫn như gọi một lần. `PUT` bắt buộc idempotent. `POST` và `PATCH` không đảm bảo: gửi lại 3 lần `POST /courses` có thể tạo 3 khóa học trùng.

**Q10. Tạo mới thành công trả status code gì, kèm header gì?**
`201 Created` kèm header `Location` là URL của resource mới. Project làm đúng ở `CourseController.java:55-56`.

**Q11. Khi nào dùng 400, khi nào dùng 409?**
`400`: dữ liệu client gửi sai (thiếu field, sai format). `409`: request hợp lệ nhưng xung đột với trạng thái hiện tại, ví dụ đăng ký khóa học đã đăng ký rồi hoặc lớp đã đầy (`EnrollmentServiceImpl.java:99, 103`).

**Q12. `Content-Type` khác `Accept` thế nào? Khi nào trả 415, 406?**
`Content-Type` là format của body mình gửi, `Accept` là format mình muốn nhận. Server không hỗ trợ format client gửi trả `415`, không có format nào khớp `Accept` trả `406`.

## 4. Asynchronous
**Q13. Việc chạy lâu thì thiết kế API thế nào?**
Trả ngay `202 Accepted` kèm `Location` của endpoint theo dõi tiến độ. Client polling endpoint đó, khi xong nếu có tạo resource mới thì trả `303 See Other` kèm `Location` của resource đó.

## 5. Pagination và filtering
**Q14. Vì sao phải phân trang và phải đặt giới hạn tối đa cho `limit`?**
Trả hết một lần thì chậm, tốn băng thông, có thể sập server. Giới hạn tối đa chống client xin `limit` quá lớn (tấn công DoS). Project giới hạn `MAX_PAGE_SIZE = 100` ở `GET /users/search` (`UserServiceImpl.java:44`).

**Q15. Sorting và filtering ảnh hưởng gì đến cache?**
Query string là một phần của cache key, nên càng nhiều tổ hợp `sort`/`filter` thì cache càng kém hiệu quả.

**Q16. Field selection (`fields=id,name`) cần chú ý gì?**
Server phải kiểm tra field nào được phép trả, tránh lộ field nội bộ.

## 6. Partial responses
**Q17. Khi nào cần partial response, hoạt động ra sao?**
Dùng cho file lớn, mạng chập chờn. Client gửi `Range: bytes=0-2499`, server trả `206 Partial Content` kèm `Content-Range: bytes 0-2499/4580`. `HEAD` giúp biết trước kích thước và việc server có hỗ trợ `Accept-Ranges` không.

## 7. HATEOAS
**Q18. HATEOAS giải quyết vấn đề gì? Project đã có chưa?**
Response kèm link tới resource liên quan và thao tác có thể làm tiếp, client đi theo link thay vì tự ghép URL, server đổi URL không làm client hỏng. Project chưa có (Case 7).

## 8. Versioning
**Q19. Thay đổi nào là breaking change?**
Đổi tên hoặc xóa field, đổi cấu trúc response, đổi quan hệ giữa resource. Thêm field mới thì không phải, vì client cũ bỏ qua field lạ.

**Q20. Có mấy cách versioning, ưu nhược điểm?**
4 cách: URI (`/v2/courses/3`, dễ làm, dễ cache nhưng URL đổi), query string (`?version=2`), header (`api-version: 2`, URL sạch nhưng phải xét header khi cache), media type (`Accept: application/vnd.center.v2+json`, phức tạp nhất). Project chưa có versioning (Case 8).

## 9. Multitenant
**Q21. Có những cách nào xác định tenant trong request, rủi ro gì?**
Subdomain, header/JWT claim, hoặc URI path. Với header, cache phải phân biệt theo header, nếu không có thể trả dữ liệu tenant này cho tenant khác. Project chưa có multitenant (Case 9).

## 10. Distributed tracing
**Q22. Correlation-ID dùng để làm gì?**
Gắn một mã vào request, mọi service đi qua đều ghi mã đó vào log và trả lại trong response. Khi có lỗi, tìm log theo mã là thấy toàn bộ đường đi của request. Project chưa có (Case 10).

## 11. Maturity model
**Q23. Richardson Maturity Model có mấy level? Project ở level nào?**
4 level: 0 một URI, mọi thao tác POST; 1 URI riêng cho từng resource; 2 dùng đúng HTTP method và status code; 3 thêm HATEOAS. Project ở Level 2 (Case 11).

## 12. OpenAPI
**Q24. Contract-first khác code-first thế nào?**
Contract-first: viết file mô tả API (OpenAPI) trước rồi mới code. Code-first: code trước, sinh tài liệu từ code. Project dùng springdoc nên là code-first (Case 12).
