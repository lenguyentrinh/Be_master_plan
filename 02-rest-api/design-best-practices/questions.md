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

**Q13. Vì sao `POST` cùng URL với `GET` (`/categories`) còn `PUT`/`DELETE` lại là URL khác (`/categories/5`)? Điều này ảnh hưởng gì đến cache?**
- `/categories` là collection (cả nhóm): `GET` đọc cả danh sách, `POST` thêm một phần tử mới vào nhóm. Lúc tạo, client chưa biết id (server cấp), nên chỉ gửi vào địa chỉ của nhóm.
- `/categories/5` là item (một phần tử cụ thể): `PUT`/`DELETE` phải chỉ rõ sửa hoặc xóa phần tử nào nên URL phải kèm id. Project làm đúng ở `CategoryController.java`.
- **Hệ quả với cache:** `Cache-Control: max-age=60` chỉ nằm ở response của `GET`. Còn khi một request thay đổi dữ liệu (`POST/PUT/DELETE`) thành công, trình duyệt xóa bản cache GET của **đúng URL đó** (quy tắc riêng của HTTP, không phải do `Cache-Control`).
- **Nguyên nhân có thể gây dữ liệu cũ:** `POST /categories` cùng URL với `GET /categories` nên xóa được cache của danh sách (đã test: `GET` ngay sau `POST` có header `date` mới, tức đã tới server). `PUT/DELETE /categories/5` khác URL nên **không** xóa cache của `/categories`, danh sách có thể hiện dữ liệu cũ đến hết `max-age` (chưa test, đang kiểm tra ở project, xem `AdminCategoriesPage.tsx:28, 91`).

**Q14. Kết hợp cache ở frontend (`staleTime` 60s) với HTTP cache `no-cache` + `ETag` thì được gì? Nếu người khác đổi dữ liệu, mình có bị `304` mãi không?**
- Hai lớp xếp chồng: store FE (`staleTime: 60_000`, `useCategories.ts:25`) chạy trước, rồi mới tới cache HTTP của trình duyệt (`CategoryController.getAll()` trả `Cache-Control: no-cache, private`, filter `ETag` ở `HttpCacheConfig.java`).
- **Trong 60 giây:** store còn mới nên **không có request nào** tới server (bớt số lần gọi).
- **Hết 60 giây hoặc sau khi mình sửa/xóa (`invalidate`):** FE gọi API kèm `If-None-Match`. Dữ liệu chưa đổi thì server trả `304`, không có body (nhẹ). Dữ liệu đã đổi thì trả `200` kèm dữ liệu mới và `ETag` mới. Lưu ý: request vẫn được gửi và server vẫn chạy query để tính ETag, `304` chỉ tiết kiệm body, không phải bớt request.
- **Người khác đổi dữ liệu, mình không làm gì thì có `304` mãi không? Không.** `304` chỉ xảy ra khi `ETag` mình gửi lên **trùng** với `ETag` hiện tại của dữ liệu. Người khác thêm danh mục thì nội dung đổi, `ETag` đổi, nên lần gọi kế tiếp của mình nhận `200` kèm dữ liệu mới. ETag so sánh nội dung hiện tại, không phụ thuộc ai đã sửa.
- **Dữ liệu cũ chỉ kéo dài khi mình không gửi request**, tức là: còn trong 60 giây của store, hoặc cứ ở nguyên trang (FE không polling). Đó là lỗi do không hỏi server, không phải do `304`. Độ trễ tối đa khoảng 60 giây cộng với việc phải mount lại trang.
- **Điều kiện để `304` đúng:** body phải ổn định khi dữ liệu không đổi. `ApiResponse` của project chỉ có `status`, `message`, `data` (không có `timestamp`) nên ETag không đổi vô cớ. Nếu response chứa thời gian hiện tại thì ETag đổi mỗi lần và không bao giờ có `304`.
- HTTP không cho server báo client chủ động. Muốn thấy thay đổi của người khác ngay thì cần polling, Server-Sent Events hoặc WebSocket.
- Chưa kiểm chứng trên trình duyệt thật.

**Q15. Backend làm sao biết dữ liệu đã đổi để trả `304`? `304` có giúp giảm tải database không? Frontend có biết về `304` không?**
- **Cách project đang dùng (`ShallowEtagHeaderFilter`, `HttpCacheConfig.java`):** backend không thật sự "biết" dữ liệu đổi. Mỗi request nó vẫn chạy bình thường (`findByActiveTrueOrderByNameAsc()`, dựng response JSON), rồi băm body thành `ETag` và so với `If-None-Match` của client. Trùng thì thay bằng `304` và bỏ body, khác thì trả `200` kèm body mới.
- **Hệ quả:** database vẫn bị truy vấn mỗi lần. `304` chỉ tiết kiệm **băng thông** (không gửi body), không giảm tải database. Với bảng nhỏ như `categories` thì chấp nhận được.
- **Tiết kiệm băng thông ở đâu: chỉ ở đoạn mạng giữa backend và trình duyệt, đúng bằng kích thước phần body.**
  ```
  Database --(query vẫn chạy đủ)--> Backend --(đoạn này tiết kiệm: 304 không có body)--> Trình duyệt
  ```
  - **Có tiết kiệm:** body response. `304` chỉ gửi header, trình duyệt lấy body đã lưu trong cache của máy (không qua mạng) rồi đưa cho FE.
  - **Không tiết kiệm:** query database, việc dựng JSON và băm ETag ở backend (vẫn làm đủ mỗi lần).
  - Lượng tiết kiệm phụ thuộc body lớn hay nhỏ: `/categories` chỉ vài dòng nên gần như không đáng kể, danh sách lớn hoặc mạng chậm/di động thì mới rõ. Tự đo bằng tab Network: so cột **Size** của request `200` với request `304`.
- **Frontend không biết về `304`.** Trình duyệt tự gửi `If-None-Match`, tự nhận `304`, rồi lấy body đã lưu trong cache đưa cho axios dưới dạng response đầy đủ. Code FE (axios, store) vẫn nhận dữ liệu bình thường và cập nhật store.
- **Khác `max-age`/`staleTime`:** ở đây FE dùng bản cũ vì **server đã xác nhận** bản đó còn đúng, không phải tự coi là còn dùng được.
- **Cách thật sự "biết" mà không cần dựng response:** dùng dấu hiệu thay đổi lưu sẵn, ví dụ `MAX(updateAt)` (`BaseEntity` đã có `updateAt`, `@LastModifiedDate`), cột version (`@Version`), hoặc biến đếm phiên bản cập nhật khi tạo/sửa/xóa. Giảm cả tải database nhưng phức tạp hơn và dễ sai (ví dụ xóa mềm có cập nhật `updateAt` hay không).

**Q16. Khi nào dùng `Cache-Control: max-age`, khi nào dùng `no-cache` + `ETag`, khi nào dùng `no-store`? Có nên áp dụng ETag đại trà không?**
- `Cache-Control` là **chính sách** cache, còn `ETag` là **cơ chế kiểm tra** "dữ liệu còn mới không". Hai thứ không đối lập nhau, câu hỏi thực chất là chọn chính sách nào.

| Chính sách | Hành vi | Dùng khi |
|---|---|---|
| `max-age=N` | Trong N giây trình duyệt không gọi server, dùng bản lưu luôn | Dữ liệu đổi rất hiếm hoặc chấp nhận hơi cũ: ảnh, file tĩnh có hash trong tên, cấu hình công khai |
| `no-cache` + `ETag` | Mỗi lần vẫn hỏi server. `304` (không body) nếu chưa đổi, `200` nếu đã đổi | Dữ liệu ít đổi nhưng phải luôn đúng ngay sau khi sửa: danh mục, role, danh sách |
| `no-store` | Không lưu gì cả | Dữ liệu nhạy cảm hoặc trạng thái phiên: `/auth/me`, thông tin cá nhân, OTP |

- **Quy tắc chọn nhanh:** (1) Sau khi sửa người dùng phải thấy ngay? Có thì `no-cache` + `ETag`. (2) Chấp nhận cũ vài phút? Có thì `max-age`, tiết kiệm được cả request, nhưng chỉ khi sản phẩm cho phép. (3) Dữ liệu nhạy cảm hoặc là trạng thái đăng nhập? Có thì `no-store`.
- **`private` hay `public`:** `private` chỉ cache của trình duyệt được lưu, dùng khi cần đăng nhập hoặc body phụ thuộc người gọi. `public` cho phép proxy/CDN lưu, chỉ dùng cho dữ liệu hoàn toàn giống nhau với mọi người.
- **Không nên áp dụng ETag đại trà.** ETag chỉ đáng dùng khi dữ liệu ít đổi và response đủ lớn để tiết kiệm băng thông. `ShallowEtagHeaderFilter` vẫn phải chạy query và tạo cả body rồi mới băm, nên chỉ tiết kiệm **băng thông**, không tiết kiệm công việc của server. Muốn giảm tải DB thật thì cần `max-age` hoặc cache phía server (đổi lại độ cũ của dữ liệu, cần người làm sản phẩm quyết định).
- **Trong project:** filter ETag đăng ký cho `/categories`, `/roles`, `/courses`, `/teachers` (`HttpCacheConfig.java`), các controller đặt `CacheControl.noCache()` (`CategoryController.java:39`, `TeacherController.java:51`, `RoleController.java:29`, `CourseController.java:44`). Chỉ khớp đúng URL danh sách, các URL như `/courses/schedule` hay `/courses/{id}/students` không bị khớp có chủ đích.
- **Ứng viên cho `max-age` dài:** `/roles`, vì role là tập cố định theo `Roles` enum. Hiện đang để `no-cache` cho đồng nhất.
- Chưa kiểm chứng trên trình duyệt thật.

**Q17. `no-cache` đứng một mình khác gì `no-cache` + `ETag`?**
- `Cache-Control: no-cache` nghĩa là: "được lưu bản copy, nhưng trước khi dùng phải hỏi server". Nó **không** có nghĩa là "không cache".
- Nếu response không có `ETag` (và không có `Last-Modified`) thì trình duyệt không có gì để gửi lên kiểm tra, nên mỗi lần phải tải lại toàn bộ body, hiệu quả giống không cache.
- Có `ETag`: lần đầu server trả `200`, body và `ETag: "abc123"`. Lần sau trình duyệt gửi `If-None-Match: "abc123"`. Chưa đổi thì server trả `304` không body, đã đổi thì trả `200` với body và `ETag` mới.

| | `no-cache` đơn thuần | `no-cache` + `ETag` |
|---|---|---|
| Có gọi server mỗi lần | Có | Có |
| Server tính lại dữ liệu | Có | Có (với `ShallowEtagHeaderFilter`) |
| Body gửi về khi chưa đổi | Đầy đủ | Không có (`304`) |
| Dữ liệu luôn mới | Có | Có |

- **Cần cả hai thì mới có `304`:** `Cache-Control: no-cache` do controller đặt, `ETag` do `ShallowEtagHeaderFilter` (`HttpCacheConfig.java`) tự thêm. Thiếu filter thì `no-cache` ở controller gần như vô dụng.
- **Ngược lại**, có `ETag` mà không có `Cache-Control`, trình duyệt có thể tự suy đoán thời gian cache theo heuristic, dẫn đến dữ liệu cũ khó đoán. Vì vậy đặt rõ `no-cache`.
- Kiểm tra thật: mở tab Network, gọi `/api/categories` hai lần liên tiếp, lần hai kỳ vọng status `304`. Chưa kiểm chứng trên trình duyệt thật.

## 4. Asynchronous
**Q18. Việc chạy lâu thì thiết kế API thế nào?**
Trả ngay `202 Accepted` kèm `Location` của endpoint theo dõi tiến độ. Client polling endpoint đó, khi xong nếu có tạo resource mới thì trả `303 See Other` kèm `Location` của resource đó.

## 5. Pagination và filtering
**Q19. Vì sao phải phân trang và phải đặt giới hạn tối đa cho `limit`?**
Trả hết một lần thì chậm, tốn băng thông, có thể sập server. Giới hạn tối đa chống client xin `limit` quá lớn (tấn công DoS). Project giới hạn `MAX_PAGE_SIZE = 100` ở `GET /users/search` (`UserServiceImpl.java:44`).

**Q20. Sorting và filtering ảnh hưởng gì đến cache?**
Query string là một phần của cache key, nên càng nhiều tổ hợp `sort`/`filter` thì cache càng kém hiệu quả.

**Q21. Field selection (`fields=id,name`) cần chú ý gì?**
Server phải kiểm tra field nào được phép trả, tránh lộ field nội bộ.

## 6. Partial responses
**Q22. Khi nào cần partial response, hoạt động ra sao?**
Dùng cho file lớn, mạng chập chờn. Client gửi `Range: bytes=0-2499`, server trả `206 Partial Content` kèm `Content-Range: bytes 0-2499/4580`. `HEAD` giúp biết trước kích thước và việc server có hỗ trợ `Accept-Ranges` không.

## 7. HATEOAS
**Q23. HATEOAS giải quyết vấn đề gì? Project đã có chưa?**
Response kèm link tới resource liên quan và thao tác có thể làm tiếp, client đi theo link thay vì tự ghép URL, server đổi URL không làm client hỏng. Project chưa có (Case 7).

## 8. Versioning
**Q24. Thay đổi nào là breaking change?**
Đổi tên hoặc xóa field, đổi cấu trúc response, đổi quan hệ giữa resource. Thêm field mới thì không phải, vì client cũ bỏ qua field lạ.

**Q25. Có mấy cách versioning, ưu nhược điểm?**
4 cách: URI (`/v2/courses/3`, dễ làm, dễ cache nhưng URL đổi), query string (`?version=2`), header (`api-version: 2`, URL sạch nhưng phải xét header khi cache), media type (`Accept: application/vnd.center.v2+json`, phức tạp nhất). Project chưa có versioning (Case 8).

## 9. Multitenant
**Q26. Có những cách nào xác định tenant trong request, rủi ro gì?**
Subdomain, header/JWT claim, hoặc URI path. Với header, cache phải phân biệt theo header, nếu không có thể trả dữ liệu tenant này cho tenant khác. Project chưa có multitenant (Case 9).

## 10. Distributed tracing
**Q27. Correlation-ID dùng để làm gì?**
Gắn một mã vào request, mọi service đi qua đều ghi mã đó vào log và trả lại trong response. Khi có lỗi, tìm log theo mã là thấy toàn bộ đường đi của request. Project chưa có (Case 10).

## 11. Maturity model
**Q28. Richardson Maturity Model có mấy level? Project ở level nào?**
4 level: 0 một URI, mọi thao tác POST; 1 URI riêng cho từng resource; 2 dùng đúng HTTP method và status code; 3 thêm HATEOAS. Project ở Level 2 (Case 11).

## 12. OpenAPI
**Q29. Contract-first khác code-first thế nào?**
Contract-first: viết file mô tả API (OpenAPI) trước rồi mới code. Code-first: code trước, sinh tài liệu từ code. Project dùng springdoc nên là code-first (Case 12).
