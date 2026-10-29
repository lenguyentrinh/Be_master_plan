# Transactions & Concurrency

- **Domain:** Database
- **Week:** Week 1-4

## Mục tiêu

Hiểu cách database xử lý nhiều transaction cùng lúc mà vẫn giữ dữ liệu đúng và nhất quán. Sau phần này cần giải thích được:

- Transaction và bốn tính chất ACID.
- Các lỗi có thể xảy ra khi nhiều transaction đọc/ghi cùng dữ liệu.
- Locking, MVCC, optimistic concurrency control và pessimistic concurrency control.
- Isolation level và sự đánh đổi giữa tính nhất quán với khả năng xử lý đồng thời.
- Nguyên nhân, cách phòng tránh và cách xử lý deadlock.

## Reference

- [Concurrency Control in DBMS: How Locking, MVCC and Optimistic Strategies Keep Data Consistent | Databricks](https://www.databricks.com/blog/concurrency-control)

## Key concepts

### 1. Transaction và ACID

Transaction là một nhóm thao tác  được database xem như một đơn vị công việc. Transaction hoặc hoàn thành toàn bộ, hoặc không áp dụng thay đổi nào.

- **Atomicity:** tất cả thao tác cùng thành công hoặc cùng rollback.
- **Consistency:** transaction đưa database từ một trạng thái hợp lệ sang một trạng thái hợp lệ khác.
- **Isolation:** các transaction đồng thời không làm lộ trạng thái trung gian hoặc ảnh hưởng sai đến nhau.
- **Durability:** sau khi `COMMIT`, dữ liệu vẫn được giữ lại kể cả khi hệ thống gặp sự cố.

Concurrency control chủ yếu bảo vệ tính **Isolation**, đồng thời hỗ trợ các đảm bảo ACID còn lại. Mục tiêu lý tưởng là kết quả của các transaction chạy đồng thời tương đương với một thứ tự chạy tuần tự nào đó, gọi là **serializability**.

### 2. Các vấn đề khi transaction chạy đồng thời

- **Dirty read:** transaction A đọc dữ liệu mà transaction B mới sửa nhưng chưa `COMMIT`. Nếu B rollback, A đã đọc dữ liệu chưa từng chính thức tồn tại.
- **Lost update:** hai transaction cùng đọc một giá trị, cùng sửa rồi ghi lại; lần ghi sau ghi đè thay đổi của lần ghi trước.
- **Non-repeatable read:** cùng một transaction đọc một dòng hai lần nhưng nhận hai giá trị khác nhau vì transaction khác đã sửa và commit ở giữa.
- **Phantom read:** cùng một transaction chạy lại truy vấn theo điều kiện hoặc khoảng giá trị nhưng số dòng trả về thay đổi vì transaction khác đã `INSERT` hoặc `DELETE`.
- **Write skew:** hai transaction đọc các dữ liệu liên quan, mỗi transaction sửa một phần khác nhau và cùng commit, tạo ra trạng thái vi phạm quy tắc nghiệp vụ.

### 3. Lock-based concurrency control

Database dùng lock để ngăn các thao tác xung đột trên row, page hoặc table.

- **Shared lock (S):** cho phép nhiều transaction cùng đọc dữ liệu.
- **Exclusive lock (X):** chỉ một transaction được sửa dữ liệu; transaction khác phải chờ hoặc thất bại tùy cấu hình.
- **Row-level lock:** concurrency tốt hơn vì chỉ khóa dòng cần thiết, nhưng database phải quản lý nhiều lock hơn.
- **Table-level lock:** quản lý đơn giản hơn nhưng có thể làm các transaction không liên quan phải chờ.

Ví dụ khóa một tài khoản trước khi cập nhật số dư:

```sql
BEGIN;

SELECT balance
FROM accounts
WHERE account_id = 1
FOR UPDATE;

UPDATE accounts
SET balance = balance - 200
WHERE account_id = 1;

COMMIT;
```

`FOR UPDATE` yêu cầu database khóa dòng được đọc để transaction khác không thể đồng thời sửa dòng đó trước khi transaction hiện tại kết thúc.

#### Two-phase locking (2PL)

2PL chia transaction thành hai giai đoạn:

1. **Growing phase:** chỉ được lấy thêm lock, không được nhả lock.
2. **Shrinking phase:** chỉ được nhả lock, không được lấy thêm lock.

Biến thể **strict 2PL** giữ các lock quan trọng đến khi `COMMIT` hoặc `ROLLBACK`, giúp tránh việc transaction khác đọc dữ liệu chưa chắc chắn. Đổi lại, lock có thể gây blocking và deadlock.

### 4. MVCC

**MVCC (Multi-Version Concurrency Control)** lưu nhiều phiên bản của một dòng thay vì để việc đọc và ghi luôn chặn lẫn nhau.

- Reader đọc phiên bản phù hợp với snapshot của transaction.
- Writer tạo phiên bản mới thay vì ghi đè ngay phiên bản mà reader đang đọc.
- Reader thường không chặn writer và writer thường không chặn reader.
- Khi hai transaction cùng sửa một dòng, database phát hiện xung đột khi commit; một transaction có thể phải rollback và retry.

MVCC phù hợp với hệ thống nhiều thao tác đọc hoặc các transaction ít xung đột. Đổi lại, database phải lưu và dọn các phiên bản cũ; PostgreSQL chẳng hạn cần cơ chế `VACUUM` để thu hồi phiên bản không còn dùng.

#### Snapshot isolation và write skew

- **Snapshot isolation (SI):** mỗi transaction đọc từ một snapshot cố định lúc bắt đầu. SI chặn dirty read và non-repeatable read, nhưng **vẫn cho phép write skew**.
- **Serializable snapshot isolation (SSI):** SI cộng thêm bước phát hiện các dependency nguy hiểm để chặn write skew, đổi lại có thêm overhead và transaction có thể bị abort. PostgreSQL dùng SSI cho mức `Serializable`.
- **First committer wins:** với optimistic validation thuần (ví dụ Delta Lake), transaction commit trước thắng, transaction sau phải retry.
- **Thực tế khác nhau theo DB:** PostgreSQL và MySQL/InnoDB không đợi tới lúc commit mới phát hiện xung đột ghi. Transaction ghi sau bị chặn ngay ở câu `UPDATE` cho đến khi transaction trước kết thúc. Sau đó, ở Read Committed (PostgreSQL) nó đọc lại dòng và ghi tiếp; ở Repeatable Read (PostgreSQL) nó nhận lỗi serialization failure (SQLSTATE `40001`) và phải retry.

### 5. Pessimistic và optimistic concurrency control

#### Pessimistic control

Giả định xung đột thường xảy ra nên khóa dữ liệu từ trước.

- Phù hợp với hệ thống nhiều ghi, dữ liệu nóng và yêu cầu không được retry nhiều lần.
- Ưu điểm: ngăn xung đột sớm.
- Nhược điểm: blocking, giảm throughput và có nguy cơ deadlock.

#### Optimistic control

Giả định xung đột hiếm nên cho transaction chạy trước, sau đó kiểm tra xung đột khi commit.

- Phù hợp với hệ thống nhiều đọc, ít transaction cùng sửa một dữ liệu.
- Ưu điểm: ít blocking, concurrency cao.
- Nhược điểm: nếu xung đột thường xuyên, nhiều transaction phải rollback và retry, gây lãng phí công việc.

Trong thực tế có thể kết hợp cả hai: dùng MVCC cho các thao tác thông thường và dùng `SELECT ... FOR UPDATE` cho các dòng quan trọng hoặc dễ tranh chấp.

### 6. Isolation levels

Isolation level quyết định transaction được phép nhìn thấy và chịu những vấn đề concurrency nào.

| Isolation level | Dirty read | Non-repeatable read | Phantom read | Đặc điểm |
|---|---:|---:|---:|---|
| Read Uncommitted | Có thể | Có thể | Có thể | Concurrency cao, ít dùng trong production |
| Read Committed | Không | Có thể | Có thể | Cân bằng, thường dùng cho ứng dụng web |
| Repeatable Read | Không | Không | Có thể* | Giữ kết quả đọc ổn định hơn |
| Serializable | Không | Không | Không | Nhất quán cao nhất, concurrency thấp hơn |

`*` Cách database xử lý phantom và các anomaly cụ thể có thể khác nhau. Cần kiểm tra tài liệu của hệ quản trị đang dùng. Ví dụ, PostgreSQL và Oracle thường mặc định `Read Committed`, còn MySQL/InnoDB thường mặc định `Repeatable Read`.

Thiết lập isolation level không phải lúc nào càng cao càng tốt:

- Dùng mức thấp hơn nếu cần throughput cao và nghiệp vụ chấp nhận kết quả ít nghiêm ngặt hơn.
- Dùng `Serializable` cho nghiệp vụ tài chính, compliance hoặc các thao tác bắt buộc đúng tuyệt đối.
- Chọn mức dựa trên business rule, tần suất xung đột và thời gian transaction.

Ví dụ:

```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- Các thao tác cần tính nhất quán cao
COMMIT;
```

Ví dụ trên chạy được trên PostgreSQL. MySQL không cho đổi isolation level khi transaction đang chạy, nên phải đặt trước khi bắt đầu:

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
-- Các thao tác cần tính nhất quán cao
COMMIT;
```

#### Bảng bổ sung: lost update và write skew

Bảng trên theo chuẩn SQL nên không có hai anomaly này. Thực tế:

| Isolation level | Lost update | Write skew |
|---|---|---|
| Read Committed | Có thể | Có thể |
| Repeatable Read | PostgreSQL báo lỗi serialization; MySQL vẫn có thể xảy ra với read-modify-write ở application | Có thể (SI) |
| Serializable | Không | Không |

#### Khác biệt theo DBMS

- **PostgreSQL:** `Read Uncommitted` chạy giống `Read Committed` nên không tái hiện được dirty read. `Repeatable Read` là snapshot isolation nên không có phantom, nhưng vẫn có write skew. `Serializable` dùng SSI.
- **MySQL/InnoDB:** `Repeatable Read` chặn phantom với consistent read thường; với locking read (`FOR UPDATE`, `UPDATE`) dùng next-key lock. Có thể tái hiện dirty read ở `Read Uncommitted`.

### 7. Deadlock

Deadlock xảy ra khi các transaction chờ lock của nhau theo vòng tròn:

```text
Transaction A giữ row 1, chờ row 2
Transaction B giữ row 2, chờ row 1
```

Database thường phát hiện vòng chờ, chọn một transaction làm **victim**, rollback transaction đó và giải phóng lock để transaction còn lại tiếp tục.

Cách phát hiện: database dựng **wait-for graph** (node là transaction, cạnh A → B nghĩa là A đang chờ lock của B). Có cycle trong graph tức là có deadlock. PostgreSQL chỉ kiểm tra sau `deadlock_timeout` (mặc định 1 giây); MySQL/InnoDB phát hiện gần như ngay lập tức. Số lượng deadlock nên được theo dõi như một chỉ số sức khỏe của hệ thống.

Cách giảm deadlock:

- Giữ transaction ngắn nhất có thể.
- Luôn lock nhiều resource theo cùng một thứ tự.
- Không chờ người dùng hoặc gọi API bên ngoài trong transaction.
- Dùng lock timeout phù hợp.
- Application cần retry transaction bị rollback do deadlock hoặc conflict.

### 8. Chọn cơ chế theo workload

- **Nhiều đọc, ít xung đột:** MVCC hoặc optimistic control.
- **Nhiều ghi trên cùng dữ liệu:** pessimistic locking hoặc lock có chủ đích.
- **Transaction ngắn:** locking thường dễ kiểm soát hơn.
- **Transaction dài:** MVCC có thể tránh việc giữ lock quá lâu, nhưng cần kiểm soát phiên bản cũ.
- **Yêu cầu correctness cao:** isolation level cao hơn, có thể cần `Serializable` và retry.
- **Hệ thống phân tán:** phải tính thêm network latency, coordination và cơ chế consensus.

Với hệ thống phân tán và analytics, bài reference nêu thêm:

- **Distributed 2PL:** áp dụng locking trên nhiều node, chi phí coordination cao.
- **Distributed MVCC với timestamp toàn cục:** ví dụ Google Spanner dùng TrueTime.
- **Consensus (Raft, Paxos):** để các node thống nhất thứ tự commit.
- **Lakehouse (Delta Lake):** dùng optimistic concurrency control và MVCC không khóa; các writer không xung đột đều commit được, còn xung đột thì retry hoặc tự giải quyết.

## Q&A

### Vì sao cần concurrency control?

Để nhiều transaction chạy đồng thời mà không làm mất dữ liệu, đọc dữ liệu chưa commit hoặc tạo kết quả không nhất quán.

### MVCC có phải là không dùng lock không?

Không hoàn toàn. MVCC giảm việc reader và writer chặn nhau, nhưng database vẫn có thể dùng lock cho các thao tác ghi, metadata hoặc các trường hợp như `SELECT ... FOR UPDATE`.

### Vì sao không dùng `Serializable` cho mọi transaction?

Vì mức này giảm khả năng chạy đồng thời, có thể tạo nhiều blocking, conflict hoặc retry. Chỉ nên dùng khi yêu cầu nghiệp vụ cần tính nhất quán cao.

### Khi gặp deadlock, nên retry hay sửa query?

Cần làm cả hai: sửa thứ tự truy cập và rút ngắn transaction để giảm khả năng deadlock; đồng thời application vẫn nên retry có giới hạn vì deadlock không thể loại bỏ tuyệt đối trong hệ thống đồng thời.

## Hands-on

### Bài 1: Quan sát lost update

1. Tạo bảng `accounts(account_id, balance)` và thêm một tài khoản.
2. Mở hai session database.
3. Trong cả hai session, đọc cùng một `balance` rồi cập nhật bằng giá trị cũ.
4. Quan sát việc lần ghi sau có thể ghi đè lần ghi trước.
5. Thử lại với câu lệnh cập nhật nguyên tử:

```sql
UPDATE accounts
SET balance = balance - 100
WHERE account_id = 1;
```

### Bài 2: Thử row lock

1. Session A chạy `BEGIN` rồi `SELECT ... FOR UPDATE` trên một account.
2. Session B thử cập nhật cùng account.
3. Quan sát Session B phải chờ cho đến khi A `COMMIT` hoặc `ROLLBACK`.

### Bài 3: Thử isolation level

1. Tạo hai session.
2. Chạy các kịch bản dirty read, non-repeatable read và phantom read.
3. Lặp lại với `Read Committed`, `Repeatable Read` và `Serializable`.
4. Ghi lại anomaly nào được ngăn ở từng mức.

### Bài 4: Tạo và xử lý deadlock

1. Session A khóa row 1 rồi chờ row 2.
2. Session B khóa row 2 rồi chờ row 1.
3. Quan sát database phát hiện deadlock và rollback một session.
4. Sửa code để cả hai session luôn khóa row theo cùng thứ tự.

## Done

- [ ] Đọc reference
- [ ] Hiểu bốn anomaly: dirty read, lost update, non-repeatable read, phantom read
- [ ] Thực hành lock và `SELECT ... FOR UPDATE`
- [ ] So sánh MVCC với locking
- [ ] Thử các isolation level
- [ ] Tạo, quan sát và xử lý deadlock
- [ ] Ghi lại execution result và bài học từ hands-on

## Slide

- Link:
