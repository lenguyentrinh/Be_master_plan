# Design best practices

- **Domain:** REST API
- **Week:** Week 5-6

## Mục lục
- [Design best practices](#design-best-practices)
  - [Mục lục](#mục-lục)
  - [Reference](#reference)
  - [Key concepts](#key-concepts)
    - [1. RESTful web API design concepts](#1-restful-web-api-design-concepts)
    - [2. Define RESTful web API resource URIs](#2-define-restful-web-api-resource-uris)
    - [3. Define RESTful web API methods](#3-define-restful-web-api-methods)
    - [4. Implement asynchronous methods](#4-implement-asynchronous-methods)
    - [5. Implement data pagination and filtering](#5-implement-data-pagination-and-filtering)
    - [6. Support partial responses](#6-support-partial-responses)
    - [7. Implement HATEOAS](#7-implement-hateoas)
    - [8. Implement versioning](#8-implement-versioning)
    - [9. Multitenant web APIs](#9-multitenant-web-apis)
    - [10. Enable distributed tracing and trace context in APIs](#10-enable-distributed-tracing-and-trace-context-in-apis)
    - [11. Web API maturity model](#11-web-api-maturity-model)
    - [12. OpenAPI Initiative](#12-openapi-initiative)
  - [Q\&A](#qa)
  - [Hands-on](#hands-on)
  - [Done](#done)
  - [Slide](#slide)

## Reference
- [Web API Design Best Practices - Azure Architecture Center | Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design)

## Key concepts
Các mục dưới đây đi theo đúng thứ tự mục lục của bài báo. Ví dụ dùng domain của project `english-center-system-clean`: `courses` (khóa học), `users` (người dùng), `teachers` (giáo viên), `enrollments` (học viên đăng ký khóa học).

### 1. RESTful web API design concepts
**Vấn đề:** mỗi team đặt URL một kiểu (`/getCourse`, `/createNewCourse`, `/course_delete`), client nào cũng phải học lại từ đầu.

**Là gì:** RESTful web API là API theo quy ước chung: dùng HTTP chuẩn để thao tác trên **resource** (khóa học, người dùng). Hai nguyên tắc của bài:
- **Platform independence:** client gọi được API dù server viết bằng ngôn ngữ nào, vì cùng dùng HTTP và JSON/XML.
- **Loose coupling (lỏng lẻo):** client và server đổi code bên trong độc lập, chỉ cần thống nhất format dữ liệu.

**5 khái niệm nền:**
- **URI:** địa chỉ duy nhất của một resource, ví dụ `https://api.example.com/api/courses/1`.
- **Resource representation:** dạng dữ liệu server trả về cho resource đó (thường là JSON): `{"id":"1","name":"IELTS 6.5","maxStudent":20}` (field minh họa).
- **Uniform interface:** mọi API dùng chung các động từ HTTP `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, nên client không phải học lại.
- **Stateless:** server không nhớ client giữa hai request, mỗi request tự mang đủ thông tin. Nhờ vậy request nào cũng có thể rơi vào server nào, dễ chạy nhiều server.
- **Hypermedia links:** response kèm link tới resource liên quan (chi tiết ở mục 7).
- Real case: [real_cases.md, Case 1](real_cases.md#case-1)

### 2. Define RESTful web API resource URIs
**Vấn đề:** URL đặt tùy tiện thì khó đoán, khó nhớ.

**Quy tắc đặt tên URI:**
- **Dùng danh từ, không dùng động từ.** Hành động đã nằm ở method rồi.
  - Đúng: `POST /courses`
  - Sai: `POST /create-course`
- **Collection dùng danh từ số nhiều.** `/courses` là danh sách khóa học, `/courses/5` là khóa học số 5.
- **Quan hệ giữ đơn giản.** `/courses/5/sessions` là các buổi học của khóa 5. Không viết `/users/1/enrollments/99/sessions` (dài, đổi quan hệ là vỡ). Nên gọi `/users/1/enrollments` rồi `/courses/99/sessions`. Tip của bài: URI không nên phức tạp hơn dạng *collection/item/collection*.
- **Tránh quá nhiều resource nhỏ.** Hiển thị 1 trang mà client phải gọi 10 request thì chậm (gọi là API "chatty"). Nên gộp dữ liệu hay đi cùng nhau vào một response, nhưng đừng gộp quá, kẻo trả cả dữ liệu client không cần.
- **Đừng mirror cấu trúc database.** Không cần mỗi table là một endpoint. API mô tả nghiệp vụ, không phải bảng, để đổi schema DB thì client không bị ảnh hưởng và không lộ dữ liệu nội bộ.
- **Ngoại lệ:** việc không map được sang resource (ví dụ `GET /add?operand1=99&operand2=1` trả 100) thì cho phép nhưng dùng hạn chế.
- Real case: [real_cases.md, Case 2](real_cases.md#case-2)

### 3. Define RESTful web API methods
**Vấn đề:** cùng là "sửa khóa học" nhưng chỗ dùng POST, chỗ dùng GET, client không đoán được.

**HTTP request methods:** mỗi method có một nghĩa cố định.

| Method | Dùng để | Ví dụ |
| --- | --- | --- |
| `GET` | Đọc | `GET /courses/1` |
| `POST` | Tạo mới (server tự cấp id, client không tự đặt URI) | `POST /courses` |
| `PUT` | Thay thế **cả** resource | `PUT /courses/1` gửi đủ mọi field |
| `PATCH` | Sửa **một phần** | `PATCH /courses/1` chỉ gửi `{"maxStudent":30}` |
| `DELETE` | Xóa | `DELETE /courses/1` |

Một API không cần cài đủ mọi method, tùy nghiệp vụ.

**Status code nên trả theo từng method:**

| Method | Code thường dùng |
| --- | --- |
| `GET` | `200` thành công, `204` không có nội dung (search không khớp), `404` không tìm thấy |
| `POST` | `201 Created` kèm header `Location: /courses/42` (URL khóa học mới), `400` dữ liệu sai, `405` URI không hỗ trợ POST |
| `PUT` | `200` / `204` sửa xong, `201` nếu tạo mới, `409` xung đột với trạng thái hiện tại |
| `PATCH` | `200`, `400` patch sai format, `409` patch hợp lệ nhưng không áp dụng được, `415` không hỗ trợ format patch |
| `DELETE` | `204` xóa xong, `404` không tồn tại |

**Idempotent (gọi nhiều lần kết quả vẫn như gọi một lần):**
- `PUT` bắt buộc idempotent. Mạng lag, client gửi lại `PUT /courses/1` 3 lần thì khóa học vẫn chỉ có một trạng thái cuối.
- `POST` và `PATCH` không đảm bảo: gửi lại 3 lần `POST /courses` có thể tạo 3 khóa học trùng nhau.

**PATCH có 2 format JSON:**
- **JSON merge patch** (`application/merge-patch+json`): gửi các field cần đổi, `null` nghĩa là xóa field. Ví dụ `{"price":12,"color":null,"size":"small"}` là sửa `price`, xóa `color`, thêm `size`. Không dùng được nếu resource có giá trị `null` thật.
- **JSON patch** (`application/json-patch+json`): gửi danh sách thao tác theo thứ tự (`add`, `remove`, `replace`, `copy`, `test`). Linh hoạt hơn nhưng dài hơn.

**Resource MIME types:**
- `Content-Type`: body mình gửi là format gì, ví dụ `Content-Type: application/json`.
- `Accept`: mình muốn nhận format gì, ví dụ `Accept: application/json, application/xml`.
- Server không hỗ trợ format client gửi thì trả `415 Unsupported Media Type`. Không có format nào khớp `Accept` thì trả `406 Not Acceptable`.
- Real case: [real_cases.md, Case 3](real_cases.md#case-3)

### 4. Implement asynchronous methods
**Vấn đề:** `POST /courses/1/clone` sao chép khóa học kèm toàn bộ buổi học mất 2 phút, client chờ đến timeout (ví dụ minh họa, project chưa có endpoint này).

**Cách làm:** server nhận việc, trả ngay `202 Accepted` (đã nhận, chưa xong) kèm link hỏi tiến độ:
```http
HTTP/1.1 202 Accepted
Location: /api/status/12345
```
Client gọi `GET /api/status/12345` định kỳ (polling) và nhận:
```json
{"status":"In progress", "link": {"rel":"cancel","method":"delete","href":"/api/status/12345"}}
```
Khi xong, nếu việc đó tạo resource mới thì endpoint status trả `303 See Other` kèm `Location: /api/courses/12345` trỏ tới resource đó.
- Real case: [real_cases.md, Case 4](real_cases.md#case-4)

### 5. Implement data pagination and filtering
**Vấn đề:** `GET /users` có 1 triệu người dùng, trả hết một lần thì chậm, tốn băng thông, có thể sập server.

Dùng query string để client chỉ lấy phần cần:
- **Pagination:** `GET /users?limit=25&offset=50` (lấy 25 người dùng, bỏ qua 50 người đầu). Đặt giá trị mặc định (`limit=25`, `offset=0`) và **giới hạn tối đa** để chống tấn công DoS: client xin `limit=1000` mà max là 25 thì trả 25 người dùng hoặc báo `400`.
- **Filtering:** `GET /courses?status=OPEN&teacherId=t1`.
- **Sorting:** `GET /courses?sort=name`. Lưu ý: query string là một phần của cache key nên sort/filter đa dạng làm cache kém hiệu quả.
- **Field selection:** `GET /courses?fields=id,name` (chỉ trả hai field này). Server phải kiểm tra field nào được phép, tránh lộ field nội bộ.
- Real case: [real_cases.md, Case 5](real_cases.md#case-5)

### 6. Support partial responses
**Vấn đề:** tải file tài liệu PDF của khóa học 4 MB trên mạng chập chờn, đứt là phải tải lại từ đầu.

**Cách làm:** cho phép tải từng đoạn.
1. Client gửi `HEAD /courses/10/materials/5` (chỉ lấy header, không lấy body). Server trả `Accept-Ranges: bytes` (hỗ trợ tải từng đoạn) và `Content-Length: 4580` (tổng kích thước).
2. Client gửi `GET` kèm `Range: bytes=0-2499` (xin 2500 byte đầu).
3. Server trả `206 Partial Content` kèm `Content-Range: bytes 0-2499/4580`. Request tiếp theo xin phần còn lại.
- Real case: [real_cases.md, Case 6](real_cases.md#case-6)

### 7. Implement HATEOAS
**Vấn đề:** client phải tự ghép URL (`"/teachers/" + course.teacherId`), server đổi URL là client hỏng.

**Là gì:** HATEOAS (Hypertext as the Engine of Application State) là response kèm sẵn link tới resource liên quan và thao tác có thể làm tiếp. Client đi theo link, không cần tự ghép URL.

```json
{
  "courseId": 3,
  "maxStudent": 20,
  "links": [
    {"rel": "self",    "href": "https://api.example.com/api/courses/3",  "action": "GET"},
    {"rel": "teacher", "href": "https://api.example.com/api/teachers/7", "action": "GET"}
  ]
}
```
- Link thay đổi theo trạng thái resource: khóa học đã đóng đăng ký thì không còn link "enroll".
- Không có chuẩn chung cho cách mô tả link, ví dụ trên là một cách tự định nghĩa.
- Real case: [real_cases.md, Case 7](real_cases.md#case-7)

### 8. Implement versioning
**Vấn đề:** cần đổi `teacher` trong response khóa học từ một chuỗi tên thành object `{id, name}`. Đổi thẳng thì app cũ (người dùng chưa update) bị lỗi.

**No versioning:** cách đơn giản nhất, hợp API nội bộ. Thêm field mới thì client cũ bỏ qua field lạ nên không sao. Nhưng đổi tên, xóa field, đổi cấu trúc là **breaking change**, cần một trong 4 cách dưới đây để giữ song song bản cũ và bản mới:

| Cách | Ví dụ | Ghi nhớ |
| --- | --- | --- |
| URI versioning | `GET /v2/courses/3` | Dễ làm, dễ cache. URL đổi theo version, khó bảo trì khi có nhiều version |
| Query string versioning | `GET /courses/3?version=2` | URL gốc giữ nguyên, nên đặt mặc định v1. Proxy/browser cũ có thể không cache URL có query |
| Header versioning | `Custom-Header: api-version=2` | URL sạch, nhưng client phải nhớ gửi header |
| Media type versioning | `Accept: application/vnd.center.v2+json` | Hợp HATEOAS, phức tạp nhất. Không khớp thì trả `406` |

Cache (lưu sẵn response để khỏi tính lại) hoạt động dễ nhất với URI và query string vì mỗi version có URL riêng. Header và media type phải xét thêm header khi cache.
- Real case: [real_cases.md, Case 8](real_cases.md#case-8)

### 9. Multitenant web APIs
**Vấn đề:** một API phục vụ nhiều trung tâm (tenant). Server phải biết request của trung tâm nào để không trả nhầm dữ liệu.

**3 cách xác định tenant:**
- **Subdomain/domain:** `https://center1.api.example.com/courses/3`. Mỗi tenant một domain, cần cấu hình DNS.
- **Header hoặc JWT:** `X-Tenant-ID: center1` hoặc claim `tenant-id` trong token. URL sạch, nhưng cần gateway đọc header. Cache phải phân biệt theo header, nếu không có thể trả dữ liệu trung tâm này cho trung tâm khác.
- **URI path:** `GET /tenants/center1/courses/3`. Dễ hiểu nhưng API kém RESTful hơn, routing phức tạp hơn.
- Real case: [real_cases.md, Case 9](real_cases.md#case-9)

### 10. Enable distributed tracing and trace context in APIs
**Vấn đề:** một request đi qua nhiều service, lỗi xảy ra mà không biết ở service nào.

**Cách làm:** client gắn một mã vào header, ví dụ `Correlation-ID: aaaa0000-bb11-...`. Mỗi service đi qua đều ghi mã đó vào log và trả lại trong response. Khi có lỗi, tìm log theo mã là thấy toàn bộ đường đi của request. Các tên header thường gặp: `Correlation-ID`, `X-Request-ID`, `X-Trace-ID`.
- Real case: [real_cases.md, Case 10](real_cases.md#case-10)

### 11. Web API maturity model
Richardson Maturity Model (2008) là thang đo "mức độ REST" của một API:
- **Level 0:** một URI duy nhất, mọi thao tác là POST (kiểu SOAP).
- **Level 1:** mỗi resource có URI riêng.
- **Level 2:** dùng đúng HTTP method để thao tác resource. Đa số API thực tế dừng ở đây.
- **Level 3:** thêm hypermedia (HATEOAS). Theo định nghĩa của Fielding, đây mới là RESTful thật sự.
- Real case: [real_cases.md, Case 11](real_cases.md#case-11)

### 12. OpenAPI Initiative
- **OpenAPI** (trước là Swagger) là chuẩn file mô tả toàn bộ API: endpoint, tham số, response.
- Khuyến khích **contract-first**: thiết kế file mô tả (contract) trước rồi mới viết code, thay vì code xong mới mô tả.
- Từ file contract có thể sinh tài liệu và client library.
- Real case: [real_cases.md, Case 12](real_cases.md#case-12)

## Q&A
- 
- Câu hỏi ôn tập kèm đáp án: [questions.md](questions.md)

## Hands-on
- [ ] 

## Done
- [x] Read reference
- [x] Notes written
- [ ] Practice done

## Slide
- Link: 
