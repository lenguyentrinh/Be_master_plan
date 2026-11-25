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
- **Quan hệ không lồng quá sâu (tối đa dạng *collection/item/collection*).** `/courses/5/sessions` là các buổi học của khóa 5. Không viết `/users/1/enrollments/99/sessions` vì dài và gắn chặt các resource với nhau. Nên gọi `/users/1/enrollments`, rồi `/courses/7/sessions` (7 là course lấy từ enrollment).
- **Tránh chatty API (một trang phải gọi quá nhiều request).** Một trang gọi 10 request thì chậm, do resource chia quá nhỏ. Nên gộp dữ liệu hay đi cùng nhau vào một response, nhưng đừng gộp quá kẻo trả dữ liệu client không cần.
- **Tránh thiết kế API theo table thay vì theo nghiệp vụ (Mirror database).** Không cần mỗi table là một endpoint. API mô tả nghiệp vụ, nên đổi schema DB client không bị ảnh hưởng và không lộ dữ liệu nội bộ. Khác chatty (lỗi số request), đây là lỗi cách đặt resource; hai lỗi hay đi chung nhưng có thể xảy ra riêng.
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
| `GET` | `200` thành công, `404` không tìm thấy |
| `POST` | `201 Created` + header `Location: /courses/42`, `400` dữ liệu sai |
| `PUT` | `200`/`204` sửa xong, `201` nếu tạo mới, `409` xung đột |
| `PATCH` | `200`, `400` sai format, `409` không áp dụng được, `415` không hỗ trợ format |
| `DELETE` | `204` xóa xong, `404` không tồn tại |

**Idempotent (gọi nhiều lần vẫn như gọi một lần):**
- `PUT` bắt buộc idempotent: gửi lại `PUT /courses/1` 3 lần, kết quả vẫn một trạng thái.
- `POST`, `PATCH` không đảm bảo: gửi lại 3 lần `POST /courses` có thể tạo 3 khóa học trùng.

**PATCH có 2 format JSON:**
- **JSON merge patch** (`application/merge-patch+json`): gửi field cần đổi, `null` là xóa field. Ví dụ `{"price":12,"color":null}` sửa `price`, xóa `color`.
- **JSON patch** (`application/json-patch+json`): gửi danh sách thao tác (`add`, `remove`, `replace`...). Linh hoạt hơn nhưng dài hơn.

**Resource MIME types:**
- `Content-Type`: format body mình gửi, `Accept`: format mình muốn nhận.
- Không hỗ trợ format gửi lên thì `415`, không có format nào khớp `Accept` thì `406`.
- Real case: [real_cases.md, Case 3](real_cases.md#case-3)

### 4. Implement asynchronous methods
**Khái niệm:**Dùng method bất đồng bộ khi API chạy quá lâu: server trả ngay 202 (đã nhận), làm ngầm, client hỏi lại qua link Location để biết xong chưa.

**`Location` là gì:** header của response chứa một URL, bảo client "đi tới đây". Ở `202` nó trỏ tới nơi hỏi tiến độ (`/api/status/12345`), ở `303` nó trỏ tới kết quả (`/api/courses/12345`).

**Trong project:** project chưa có endpoint này (chưa có việc nào chạy lâu cần dùng).
- Real case: [real_cases.md, Case 4](real_cases.md#case-4)

### 5. Implement data pagination and filtering
**Khái niệm:** không trả cả danh sách lớn một lần. Dùng query string để lấy đúng phần cần: `limit/offset` để phân trang (có mặc định và giới hạn tối đa chống DoS), filter để lọc, `fields` để chỉ lấy các field cần. Request có query string thường không cache vì ít người gọi giống nhau.

**Vấn đề:** `GET /users` có 1 triệu người dùng, trả hết một lần thì chậm, tốn băng thông, có thể sập server.

Dùng query string để client chỉ lấy phần cần:
- **Pagination:** chỉ lấy một lượng dữ liệu nhất định mỗi lần, chia thành trang. `GET /users?limit=25&offset=50` (lấy 25 người dùng, bỏ qua 50 người đầu). Đặt mặc định (`limit=25`, `offset=0`) và **giới hạn tối đa** để chống DoS: client xin `limit=1000` mà max là 25 thì trả 25 hoặc báo `400`.
- **Filtering:** lọc để chỉ lấy các bản ghi cần. `GET /courses?status=OPEN&teacherId=t1`.
- **Sorting:** `GET /courses?sort=name`.
- **Lưu ý cache:** request có query string (filter, sort) thường **không cache**, vì ít người gọi giống nhau, cache lại tốn chỗ mà không tăng hiệu suất bao nhiêu. Chỉ cache `GET /courses` thuần.
- **Field selection:** chỉ lấy những field (column) cần thiết. `GET /courses?fields=id,name` (chỉ trả hai field này). Server phải kiểm tra field nào được phép, tránh lộ field nội bộ.
- Real case: [real_cases.md, Case 5](real_cases.md#case-5)

### 6. Support partial responses
**Khái niệm:** với file lớn, cho client tải từng đoạn bằng header `Range`, server trả `206 Partial Content`. Mạng đứt thì tải tiếp phần còn lại, không phải tải lại từ đầu.

**Vấn đề:** tải file PDF của khóa học 4 MB trên mạng chập chờn, đứt là phải tải lại từ đầu. Tải từng đoạn thì đứt chỉ cần tải tiếp phần còn lại.

**Cách làm:**
1. `HEAD /courses/10/materials/5` (chỉ lấy header). Server trả `Accept-Ranges: bytes` (hỗ trợ tải từng đoạn) và `Content-Length: 4580` (tổng kích thước).
2. `GET` kèm `Range: bytes=0-2499` (xin 2500 byte đầu).
3. Server trả `206 Partial Content` kèm `Content-Range: bytes 0-2499/4580`. Request tiếp theo xin phần còn lại.
- Real case: [real_cases.md, Case 6](real_cases.md#case-6)

### 7. Implement HATEOAS
**Khái niệm:** HATEOAS (Hypertext as the Engine of Application State) là response kèm sẵn link tới resource liên quan và thao tác có thể làm tiếp, để client đi theo link thay vì tự ghép URL. Server đổi URL thì client không hỏng.

**Vấn đề:** client tự ghép URL (`"/teachers/" + course.teacherId`) thì server đổi URL là client hỏng.

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
**Khái niệm:** khi sửa response theo kiểu làm client cũ hỏng (đổi tên, xóa field, đổi cấu trúc) thì không sửa bản cũ mà **thêm một version mới**. Bản cũ vẫn chạy cho client cũ, client sửa xong thì chuyển sang gọi bản mới.

**Vấn đề:** cần đổi `teacher` trong response khóa học từ chuỗi tên thành object `{id, name}`. Đổi thẳng thì app cũ (người dùng chưa update) bị lỗi.

**Khi nào không cần versioning:** thêm field mới thì client cũ bỏ qua field lạ nên không sao. API nội bộ (FE và BE cùng deploy một lúc) cũng thường không cần. Chỉ khi đổi hoặc xóa cái đã có mới cần version mới, và có 4 cách để đánh version:

| Cách | Ví dụ | Ghi nhớ |
| --- | --- | --- |
| URI versioning | `GET /v2/courses/3` | Dễ làm, dễ cache. URL đổi theo version, khó bảo trì khi có nhiều version |
| Query string versioning | `GET /courses/3?version=2` | URL gốc giữ nguyên, nên đặt mặc định v1. Proxy/browser cũ có thể không cache URL có query |
| Header versioning | `Custom-Header: api-version=2` | URL sạch, nhưng client phải nhớ gửi header |
| Media type versioning | `Accept: application/vnd.center.v2+json` | Hợp HATEOAS, phức tạp nhất. Không khớp thì trả `406` |

Về cache: URI và query string dễ cache vì mỗi version có URL riêng. Header và media type phải xét thêm header khi cache.
- Real case: [real_cases.md, Case 8](real_cases.md#case-8)

### 9. Multitenant web APIs
**Khái niệm:** một API phục vụ nhiều khách hàng (tenant) thì mỗi request phải báo cho server biết mình thuộc tenant nào (qua subdomain, header/JWT, hoặc đường dẫn URI), để server chỉ trả dữ liệu của tenant đó.

**Vấn đề:** một API phục vụ nhiều trung tâm. Server phải biết request của trung tâm nào để không trả nhầm dữ liệu.
### 10. Enable distributed tracing and trace context in APIs
**Khái niệm:** gắn một mã vào request, mỗi service đi qua ghi mã đó vào log, để biết request đã đi qua những service nào và lỗi ở đâu. Chỉ phục vụ truy vết, không làm API nhanh hơn.

**Vấn đề:** một request đi qua nhiều service, mỗi service có hàng nghìn dòng log của nhiều người dùng. Có lỗi thì không biết dòng log nào thuộc về request đó.

**Cách làm:**
1. Gắn mã vào header của request, ví dụ `Correlation-ID: aaaa0000-bb11-...` (client không gửi thì server tự sinh).
2. Mỗi service **truyền mã sang service kế tiếp** và ghi mã vào log. Không truyền thì mỗi service có mã riêng, không nối lại được.
3. **Trả mã lại trong response**, để người dùng báo lỗi kèm mã.
4. Có lỗi thì tìm log theo mã là thấy cả đường đi.

Tên header hay gặp: `Correlation-ID`, `X-Request-ID`, `X-Trace-ID`.
- Real case: [real_cases.md, Case 10](real_cases.md#case-10)

### 11. Web API maturity model
**Khái niệm:** Richardson Maturity Model (2008) là thang 4 mức (0 đến 3) đo "mức độ REST" của một API. Đa số API thực tế dừng ở Level 2.
- **Level 0:** một URI duy nhất, mọi thao tác là POST (kiểu SOAP).
- **Level 1:** mỗi resource có URI riêng.
- **Level 2:** dùng đúng HTTP method để thao tác resource. Đa số API thực tế dừng ở đây.
- **Level 3:** thêm hypermedia (HATEOAS). Theo định nghĩa của Fielding, đây mới là RESTful thật sự.
- Real case: [real_cases.md, Case 11](real_cases.md#case-11)

### 12. OpenAPI Initiative
**Khái niệm:** OpenAPI (trước là Swagger) là chuẩn file mô tả toàn bộ API của hệ thống (endpoint, tham số, response, lỗi). Bài gốc khuyên viết file này trước (contract-first) rồi mới code, để frontend và backend thống nhất từ đầu. Từ file này sinh được tài liệu, client library, và trang Swagger UI để xem và gọi thử API.

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
