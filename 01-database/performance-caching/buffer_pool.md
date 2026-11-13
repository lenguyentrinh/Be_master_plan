# Giải thích chi tiết: dữ liệu nằm ở đâu, buffer pool và physical read (MySQL/InnoDB)

Tài liệu giải thích sâu cho mục 5 "Theo dõi logical/physical reads và IOPS" trong [`README.md`](README.md). Ví dụ chạy thử ở [`real_cases.md`, Case 5](real_cases.md#case-5-theo-dõi-readsiops-và-materialized-view).

## Mục lục
- [1. Bảng lưu ở đâu: đĩa và RAM](#1-bảng-lưu-ở-đâu-đĩa-và-ram)
- [2. Vòng đời của một page](#2-vòng-đời-của-một-page)
- [3. Index lưu ở đâu](#3-index-lưu-ở-đâu)
- [4. Materialized view và bảng tổng hợp lưu ở đâu](#4-materialized-view-và-bảng-tổng-hợp-lưu-ở-đâu)
- [5. Ba cách giảm physical read](#5-ba-cách-giảm-physical-read)
- [6. Cách kiểm tra buffer pool đã đủ chưa](#6-cách-kiểm-tra-buffer-pool-đã-đủ-chưa)
- [7. Phân biệt `innodb_buffer_pool_size` và `sort_buffer_size`](#7-phân-biệt-innodb_buffer_pool_size-và-sort_buffer_size)

## 1. Bảng lưu ở đâu: đĩa và RAM

- **Mọi bảng đều lưu trên ổ đĩa.** RAM chỉ giữ **bản sao của các page** đang được dùng. Không có bảng nào được "chuyển hẳn" sang RAM.
- Bảng và index được chia thành các **page** (mỗi page 16 KB trong InnoDB). Một bảng gồm nhiều page, mỗi page độc lập: page nào đang dùng thì có bản sao trong RAM, page khác của cùng bảng vẫn chỉ nằm trên đĩa.
- Vùng RAM giữ các bản sao này gọi là **buffer pool** (`innodb_buffer_pool_size`). Đây là **cache**, khác với `sort_buffer_size` chỉ là vùng làm việc tạm (xem [`sort_buffer.md`](sort_buffer.md)).

```
Bảng users trên đĩa:   [P1] [P2] [P3] [P4] [P5] [P6] ...
Buffer pool (RAM):          [P2]      [P4]
                         (chỉ các page đang cần mới có bản sao)
```

| Loại đọc | Nghĩa | Tốc độ |
|---|---|---|
| Logical read | Page đã có trong buffer pool, đọc từ RAM | Nhanh |
| Physical read | Page chưa có trong RAM, phải đọc từ đĩa | Chậm, làm tăng IOPS |

## 2. Vòng đời của một page

```
Lần đầu SELECT     -> đọc từ đĩa lên RAM        (physical read, chậm)
Các lần SELECT sau -> đọc từ RAM                (logical read, nhanh)
Lâu không dùng     -> bị đẩy khỏi RAM           (vẫn còn trên đĩa)
SELECT lại sau đó  -> lại phải đọc từ đĩa       (physical read)
```

- Khi buffer pool đầy, MySQL đẩy các page **lâu không dùng nhất** ra trước (cơ chế gần giống LRU). Page đó vẫn còn nguyên trên đĩa.
- Hệ quả: query chạy lần đầu thường chậm hơn lần sau (**cold cache** và **warm cache**). Chạy cùng một query hai lần mà lần hai nhanh hơn rõ rệt thường do page đã nằm sẵn trong RAM.

## 3. Index lưu ở đâu

- Lưu **trên đĩa**, trong cùng file `.ibd` với bảng (InnoDB), nên tắt máy bật lại vẫn còn.
- Khi đọc, các page của index cũng được đưa lên buffer pool giống page của bảng. Index nhỏ nên phần hay dùng thường nằm gọn trong RAM.
- Đây là một lý do index giúp giảm physical read: thay vì đọc cả bảng, MySQL chỉ đọc vài page index (đa phần đã ở RAM) rồi vài page dữ liệu cần thiết.
- Đổi lại index chiếm dung lượng đĩa, chiếm chỗ trong buffer pool, và mỗi `INSERT/UPDATE/DELETE` phải cập nhật tất cả index.

## 4. Materialized view và bảng tổng hợp lưu ở đâu

- Lưu **trên đĩa** như bảng thường (PostgreSQL: materialized view; MySQL không có, dùng bảng tổng hợp như `province_stats` ở Case 5). Khi đọc thì page cũng lên buffer pool như mọi bảng.
- Nó nhanh **không phải vì nằm trong RAM**, mà vì **kết quả đã tính sẵn** nên chỉ đọc rất ít dòng.

| | Đọc gì | Số page |
|---|---|---|
| Query gốc (`GROUP BY` trên bảng lớn) | Toàn bộ bảng mỗi lần chạy | Nhiều |
| Bảng tổng hợp | Vài dòng kết quả đã tính sẵn | Rất ít |

- "Khỏi đọc lại" nghĩa là khỏi đọc lại **bảng lớn** mỗi lần. Việc đọc bảng lớn chỉ làm một lần lúc tạo hoặc làm mới.
- Đây là cache **trên đĩa** (có thể cũ cho đến khi làm mới), khác với buffer pool là cache **trong RAM**.

## 5. Ba cách giảm physical read

Physical read nhiều khi query phải đọc nhiều page mà các page đó chưa có trong RAM. Muốn giảm thì giảm số page phải đọc hoặc xác suất page chưa có trong RAM.

| Cách | Giảm cái gì |
|---|---|
| Tăng RAM cho buffer pool (`innodb_buffer_pool_size`) | Xác suất phải xuống đĩa (nhiều page hơn nằm sẵn trong RAM) |
| Viết query đọc ít dữ liệu hơn (`WHERE`, chỉ lấy cột cần, đánh index) | Số page phải đọc |
| Lưu sẵn kết quả (bảng tổng hợp) | Số page phải đọc, vì bảng tổng hợp rất nhỏ |

Ba điểm cần nhớ khi tăng RAM:

1. Lần đọc đầu vẫn phải xuống đĩa.
2. Có giới hạn lợi ích: khi phần dữ liệu hay dùng (working set) đã nằm gọn trong buffer pool, tăng thêm RAM không còn nhanh hơn.
3. Ghi dữ liệu vẫn xuống đĩa (log để không mất dữ liệu khi mất điện), nên RAM lớn chủ yếu giúp **đọc**.

## 6. Cách kiểm tra buffer pool đã đủ chưa

```sql
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';   -- ghi lại 2 số trước
-- chạy query cần kiểm tra
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';   -- ghi lại 2 số sau, lấy hiệu
```

| Biến | Ý nghĩa |
|---|---|
| `Innodb_buffer_pool_read_requests` | Tổng số lần đọc (logical, từ RAM) |
| `Innodb_buffer_pool_reads` | Số lần phải đọc từ đĩa (physical) |

- `Innodb_buffer_pool_reads` lớn so với `read_requests` nghĩa là nhiều page chưa có trong RAM, tăng buffer pool có thể giúp.
- Bảng nhỏ (như `users` 100.000 dòng) thường nằm sẵn trong RAM nên physical read có thể bằng 0.
- Bộ đếm là `GLOBAL`, nên lẫn hoạt động của session khác. Thử trên server vắng.

## 7. Phân biệt `innodb_buffer_pool_size` và `sort_buffer_size`

Cả hai đều là vùng RAM mà MySQL được phép dùng, nhưng dùng cho **hai mục đích khác nhau**, nên không thay thế nhau.

| | `innodb_buffer_pool_size` | `sort_buffer_size` |
|---|---|---|
| Dùng để | Giữ bản sao page của bảng và index (cache) | Sort dữ liệu cho một câu `ORDER BY` |
| Giữ dữ liệu bao lâu | Lâu, dùng lại cho nhiều query | Chỉ trong lúc sort, xong query là bỏ |
| Dùng chung hay riêng | Dùng chung cho cả server | Riêng cho từng connection, từng lần sort |
| Mặc định | Khoảng 128 MB | Khoảng 256 KB |
| Tác dụng khi tăng | Ít physical read hơn | Ít merge pass hơn |
| Mức hợp lý | Lớn: 50 đến 75% RAM của server riêng cho DB | Nhỏ: chỉ tăng ở session nặng |

- **Ví dụ:** buffer pool giống giá sách cạnh bàn (giữ sách hay dùng, nhiều người dùng chung). Sort buffer giống mặt bàn trống để xếp thẻ (mỗi người một chỗ, xếp xong dọn đi). Giá sách to không giúp xếp thẻ nhanh hơn, mặt bàn to không giúp lấy sách nhanh hơn.
- **Hai vấn đề, hai tham số:**

| Triệu chứng | Tham số cần xem |
|---|---|
| `Innodb_buffer_pool_reads` cao (đọc đĩa nhiều) | `innodb_buffer_pool_size` |
| `Sort_merge_passes` lớn (sort tràn ra file tạm) | `sort_buffer_size`, hoặc đánh index cho cột `ORDER BY` |

- **Vì sao không tăng cả hai thật lớn:** cùng lấy từ RAM của máy. Buffer pool chỉ có một cái nên tăng lớn được. Sort buffer mỗi connection một cái nên 256 MB × 200 connection có thể làm hết RAM.
- Cách đặt `innodb_buffer_pool_size`: `SET GLOBAL innodb_buffer_pool_size = 2147483648;` (đổi khi đang chạy, MySQL 5.7.5 trở lên), muốn giữ sau restart thì `SET PERSIST` (MySQL 8.0) hoặc ghi vào `my.ini`/`my.cnf`. Chi tiết `sort_buffer_size` xem [`sort_buffer.md`](sort_buffer.md).

Nội dung theo hiểu biết chung về InnoDB, chưa kiểm tra trên từng phiên bản và cấu hình cụ thể.
