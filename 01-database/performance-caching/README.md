# Performance & Caching

- **Domain:** Database
- **Week:** Week 1-4

## Mục lục
- [Performance \& Caching](#performance--caching)
  - [Mục lục](#mục-lục)
  - [Reference](#reference)
  - [Key concepts](#key-concepts)
    - [1. Đọc execution plan](#1-đọc-execution-plan)
    - [2. Chỉnh các tham số bộ nhớ (ví dụ PostgreSQL)](#2-chỉnh-các-tham-số-bộ-nhớ-ví-dụ-postgresql)
    - [3. Tối ưu câu query](#3-tối-ưu-câu-query)
    - [4. Index hiệu quả và sargability](#4-index-hiệu-quả-và-sargability)
    - [5. Theo dõi logical/physical reads và IOPS](#5-theo-dõi-logicalphysical-reads-và-iops)
      - [Materialized view là gì](#materialized-view-là-gì)
    - [6. Tránh parameter sniffing](#6-tránh-parameter-sniffing)
    - [7. Quản lý transaction cẩn thận](#7-quản-lý-transaction-cẩn-thận)
    - [8. Partition bảng lớn](#8-partition-bảng-lớn)
    - [9. Cập nhật statistics định kỳ](#9-cập-nhật-statistics-định-kỳ)
    - [10. Cách tiếp cận declarative và tính năng riêng của nền tảng](#10-cách-tiếp-cận-declarative-và-tính-năng-riêng-của-nền-tảng)
    - [Ghi chú về phạm vi](#ghi-chú-về-phạm-vi)
  - [Q\&A](#qa)
  - [Hands-on](#hands-on)
  - [Done](#done)
  - [Slide](#slide)

## Reference
- [SQL Performance Tuning Best Practices | DataForge](https://www.dataforgelabs.com/advanced-sql-concepts/sql-performance-tuning/)

## Key concepts

Ý chính của bài: viết SQL chạy đúng thì dễ, viết SQL chạy hiệu quả mới khó. Phần lớn vấn đề hiệu năng đến từ query chưa tối ưu, và tuning là việc làm liên tục chứ không phải sửa một lần. Lưu ý: lời khuyên cho OLTP không phải lúc nào cũng hợp với data pipeline, nơi ghi dữ liệu tốn kém và index phải build lại mỗi lần chạy.

### 1. Đọc execution plan

- Dùng `EXPLAIN` để biết database lấy dữ liệu thế nào: dùng index nào, join ra sao, quét toàn bảng hay một phần.
- Tìm operator tốn nhất (ví dụ full table scan) để tối ưu trước.
- Xem các gợi ý và cảnh báo về index mà công cụ đưa ra.

### 2. Chỉnh các tham số bộ nhớ (ví dụ PostgreSQL)

| Tham số | Dùng cho | Gợi ý trong bài |
|---|---|---|
| `work_mem` | Sort và hash join | Khoảng RAM × 0.25 chia cho `max_connections` |
| `temp_buffers` | Bảng tạm trong một session | Tăng nếu dùng nhiều bảng tạm |
| `shared_buffers` | Cache các block dữ liệu | Khoảng 25% RAM (32 GB RAM thì 8 GB) |
| `effective_cache_size` | Ước lượng bộ nhớ có thể cache (gồm `shared_buffers` và cache của OS) | Đặt đúng tổng bộ nhớ dùng để cache |

Tên tham số khác nhau giữa các hệ quản trị.

### 3. Tối ưu câu query

- **Tránh `SELECT *`:** chỉ lấy cột cần để giảm bộ nhớ và I/O.
  ```sql
  -- Không tốt
  SELECT * FROM orders WHERE order_date = '2023-10-01';
  -- Tốt hơn
  SELECT order_id, customer_id, order_date FROM orders WHERE order_date = '2023-10-01';
  ```
- **Tránh `SELECT DISTINCT`:** tốn tài nguyên. Dùng bộ lọc cụ thể hơn hoặc `GROUP BY`. Nếu bắt buộc dùng thì đánh index cột liên quan.
- **Dùng join thay cho correlated subquery:** correlated subquery chạy một lần cho mỗi dòng. Gộp tính toán một lần (CTE) rồi join.
  ```sql
  -- Không tốt: subquery chạy cho từng dòng
  SELECT b.employee_id, b.position, b.bonus,
    (SELECT AVG(bonus) FROM bonus_jan WHERE position = b.position) AS avg_bonus
  FROM bonus_jan b;

  -- Tốt hơn: tính trung bình một lần rồi join
  WITH avg_position AS (
    SELECT position, AVG(bonus) AS avg_bonus FROM bonus_jan GROUP BY position)
  SELECT b.employee_id, b.position, b.bonus, ap.avg_bonus
  FROM bonus_jan b JOIN avg_position ap ON b.position = ap.position;
  ```
- **Ưu tiên inner join, tránh Cartesian join:** Cartesian join sinh kết quả rất lớn. Query phức tạp nên tách thành các bước nhỏ bằng bảng tạm hoặc CTE.
- **Tránh sắp xếp không cần thiết:** chỉ dùng `ORDER BY` khi cần, tốt nhất trên cột đã có index.
- **Khớp kiểu dữ liệu:** kiểu không khớp gây chuyển đổi ngầm, làm chậm query và có thể làm mất khả năng dùng index. Ví dụ so sánh cột `varchar` với số nguyên (SQL Server): cast giá trị về đúng kiểu của cột. PostgreSQL thường xử lý ép kiểu tốt hơn.

### 4. Index hiệu quả và sargability

- **Đánh index** cho cột hay dùng trong `WHERE`, `DISTINCT`, `JOIN`, `ORDER BY`, `GROUP BY`.
- **Không nên đánh index** cho bảng nhỏ hoặc cột có ít giá trị khác nhau (low cardinality), vì tốn chi phí bảo trì mà ít lợi ích.
- **Theo dõi index:** kiểm tra phân mảnh (rebuild hoặc reorganize), xác nhận bằng execution plan là index có được dùng, xóa index không dùng.
- **Viết query sargable** (để index dùng được): không bọc cột đã đánh index trong hàm.
  ```sql
  CREATE INDEX idx_order_date ON orders (order_date);
  -- Không tốt: hàm trên cột
  SELECT * FROM orders WHERE YEAR(order_date) = 2023;
  -- Tốt hơn: điều kiện khoảng
  SELECT * FROM orders WHERE order_date BETWEEN '2023-01-01' AND '2023-12-31';
  ```
  - `LIKE '%PEN%'` (wildcard đầu) buộc quét toàn bảng; `LIKE 'PEN%'` có thể dùng index.
  - `NOT IN`, `<>`, `!=` có thể gây full scan; viết lại thành điều kiện khoảng.
  - `OR` trên **cùng một cột** nên viết thành `IN` cho gọn. Hiệu năng thường như nhau vì optimizer coi hai cách là một (đã thử trên SQLite: cùng plan, đều dùng index). Bài reference gọi bản `OR` là "không tốt", nhưng khi kiểm tra thực tế thì không đúng; cần kiểm chứng bằng `EXPLAIN` trên DB đang dùng.
    ```sql
    -- Cách 1
    SELECT * FROM Employees WHERE Department = 'Sales' OR Department = 'Marketing';
    -- Cách 2 (ngắn hơn, plan giống cách 1)
    SELECT * FROM Employees WHERE Department IN ('Sales', 'Marketing');
    ```
  - `OR` trên **các cột khác nhau** (ví dụ `department = 'Sales' OR city = 'Hanoi'`) có thể làm optimizer không dùng được index. Khi đó thử tách bằng `UNION ALL` (dùng `UNION` thì tốn thêm bước khử trùng lặp) và so sánh bằng `EXPLAIN`. Không phải lúc nào cũng nhanh hơn, vì có DB gộp được hai index (ví dụ BitmapOr của PostgreSQL).
- **Giảm bookmark lookup:** dùng covering index chứa đủ cột cần, hoặc `INCLUDE` cho cột không phải key; hoặc viết lại query để cần ít cột hơn.
- **Row store và columnar store:** columnar (Parquet, Snowflake, BigQuery) nén tốt và tổng hợp nhanh, hợp với analytics khó đoán trước, và giảm nhu cầu tạo nhiều index.

### 5. Theo dõi logical/physical reads và IOPS

- IOPS cao thường do đọc vật lý quá nhiều.
- Cách xử lý: đơn giản hóa query, tăng buffer cache, bật query result caching, dùng materialized view cho query phức tạp hoặc chạy thường xuyên.

#### Materialized view là gì

Materialized view là một view mà **kết quả được lưu sẵn thành dữ liệu thật trên đĩa**, thay vì chạy lại query mỗi lần đọc. Về bản chất đây là cache kết quả query nằm ngay trong database.

| | View thường | Materialized view |
|---|---|---|
| Lưu gì | Chỉ lưu câu query | Lưu câu query và kết quả của nó |
| Khi `SELECT` | Chạy lại query gốc mỗi lần | Đọc kết quả đã lưu, nhanh |
| Dữ liệu | Luôn mới nhất | Có thể cũ cho đến khi làm mới |
| Chi phí | Không tốn chỗ lưu | Tốn chỗ lưu và tốn công làm mới |

Ví dụ: báo cáo doanh thu theo ngày từ bảng `orders` có hàng chục triệu dòng, query `GROUP BY` chạy mất vài chục giây. Dashboard gọi query này mỗi lần mở trang thì rất chậm.

```sql
-- Cú pháp PostgreSQL
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT order_date, SUM(total_amount) AS revenue
FROM orders
GROUP BY order_date;

-- Dashboard chỉ đọc kết quả đã tính sẵn
SELECT * FROM daily_revenue WHERE order_date = '2023-10-01';

-- Làm mới khi cần (ví dụ mỗi đêm)
REFRESH MATERIALIZED VIEW daily_revenue;
```

Đánh đổi: nhanh hơn nhưng dữ liệu có thể cũ. Giữa hai lần `REFRESH`, đơn hàng mới chưa hiện trong `daily_revenue`. Hợp với báo cáo hoặc dashboard chấp nhận số liệu trễ một chút; không hợp với dữ liệu cần chính xác từng giây như số dư tài khoản.

Cú pháp và cách làm mới khác nhau giữa các DBMS (ví dụ Oracle có làm mới tự động, SQL Server gọi là indexed view). Đoạn SQL trên chưa được chạy thử.

### 6. Tránh parameter sniffing

- Plan được cache theo giá trị tham số của lần chạy đầu có thể chạy tệ với giá trị khác.
- Ví dụ trong bài (SQL Server): `WITH RECOMPILE` trên stored procedure, hint `OPTION(RECOMPILE)` trên query. Ngoài ra có thể dùng biến trung gian hoặc tắt parameter sniffing ở mức instance hoặc query.

### 7. Quản lý transaction cẩn thận

- Giữ transaction ngắn để giảm lock và tranh chấp.
- Chạy tác vụ nặng hoặc bulk ngoài giờ cao điểm.
- Chọn isolation level cân bằng giữa nhất quán và hiệu năng; mức thấp hơn có thể giúp workload nhiều đọc.

### 8. Partition bảng lớn

- Partition giúp giảm lượng dữ liệu phải quét và cho phép xử lý song song.
- Chọn partition key phân bố đều và khớp với cách đọc, ghi phổ biến.
- Quá nhiều partition gây overhead, nên chia vừa với dữ liệu và nhu cầu query.

### 9. Cập nhật statistics định kỳ

- Statistics cũ khiến optimizer chọn plan kém.
- Làm mới bằng `ANALYZE` (PostgreSQL) hoặc `UPDATE STATISTICS` (SQL Server).
- Đo hiệu năng bằng `SET STATISTICS TIME ON` và `SET STATISTICS IO ON` (SQL Server).

### 10. Cách tiếp cận declarative và tính năng riêng của nền tảng

- Nhiều nền tảng tự tối ưu sẵn (ví dụ micro-partitioning của Snowflake, clustering lúc ingest và adaptive query execution của Databricks). Không nên tuning tay phần nền tảng đã tự làm; partition thủ công trên Databricks thường kém hơn clustering tự động.
- Cấu hình declarative mô tả *làm gì* thay vì *làm thế nào*, nên dễ debug, tái sử dụng và tối ưu.
- Bài giới thiệu DataForge (chạy trên Databricks) như một ví dụ cho cách tiếp cận này.

### Ghi chú về phạm vi

Reference này nói về **performance tuning**. Phần **caching** chỉ được nhắc rất ngắn (buffer cache, query result caching, materialized view ở mục 5), chưa có nội dung riêng về cache ở tầng ứng dụng (ví dụ Redis, cache-aside). Nếu topic cần phần này thì cần thêm reference.

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
