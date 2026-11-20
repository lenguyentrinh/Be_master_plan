# Rules

1. **Không tự ý sửa text cũ.** Mọi chỉnh sửa, xóa hoặc viết lại nội dung đã có trong repo phải hỏi ý người dùng và được đồng ý trước khi làm.
2. Chỉ được thêm nội dung mới (section/file mới) khi người dùng yêu cầu, không đụng vào phần đã có.
3. Mỗi topic (thư mục sub domain) phải có mục `## Slide` trong `README.md` để điền link slide trình bày.
4. Mỗi topic present khoảng 15 phút nên deck chỉ 5 đến 6 slide, bám sát các mục trong `README.md` của topic đó, không thêm nội dung ngoài README.
5. Deck phải trả lời được các câu hỏi cốt lõi của topic. Với `01-database/indexes`: index là gì, B-tree là gì, có mấy loại index, các lỗi thường gặp, làm sao biết index đang hoạt động (dùng `EXPLAIN` hoặc `EXPLAIN ANALYZE`).
6. Hai mục Q&A và Hands-on trong README không làm slide.
7. Chữ trên slide viết bằng tiếng Anh. Không cần speaker notes trên Canva.
8. **Quy trình làm mỗi topic, theo đúng thứ tự:**
   1. Đọc refer tham khảo, ghi note vào `README.md` của topic.

9. **Mỗi khái niệm phải có ví dụ thực tế.** Khi present, mỗi loại index/khái niệm cần kèm một case thực tế (bảng, dữ liệu, query cụ thể trong nghiệp vụ như đơn hàng, người dùng) cho thấy vấn đề gặp phải, cách giải quyết, và kết quả trước/sau (ví dụ output `EXPLAIN`), để người nghe hiểu được ý, không chỉ có cú pháp. Case bổ sung viết ở file riêng của topic (ví dụ `real_cases.md`), không sửa text cũ trong `README.md`.
10. **Mỗi bài (`README.md` của topic) bắt buộc có mục lục (`## Mục lục`)** liệt kê các mục chính kèm link anchor, đặt ngay sau phần tiêu đề. Khi thêm section mới vào README thì phải thêm dòng tương ứng vào mục lục.
11. **`README.md` chỉ ghi note ngắn gọn nhưng đủ ý để người đọc hiểu; phần giải thích sâu, sơ đồ, ví dụ từng bước viết ở file riêng của topic** (ví dụ `sort_buffer.md`) và README phải có link sang file đó để ai muốn hiểu sâu thì tra cứu.
12. **Mỗi mục trong `README.md` phải có link sang case tương ứng trong `real_cases.md`** (dạng `[real_cases.md, Case N](real_cases.md#anchor)`), đặt ở cuối mục. Khi thêm mục mới vào README thì thêm case tương ứng vào `real_cases.md` và link qua.
13. **Real case phải dựa trên file demo của topic** (ví dụ `demo_mysql.sql`: bảng `users`, MySQL 8.0.18+), chạy thử được bằng cách copy từ trên xuống, và không ghi số liệu bịa; chỉ ghi cần nhìn vào đâu và kỳ vọng thấy gì.
14. **Ví dụ của các topic `02-rest-api` lấy từ project `D:\WorkSpace\vibeCode\english-center-system-clean`** (Spring Boot, code ở `backend/src/main/java/com/trinh/english_center_be/...`), ghi rõ đường dẫn file và dòng/route thật trong project. Mục nào project chưa có thì ghi thẳng "project chưa có", không bịa ví dụ.
15. **Bố cục `README.md` của topic có refer là bài báo/tài liệu thì phải bám đúng mục lục của bài gốc** (cùng thứ tự, cùng tên mục), không tự gộp hay đổi thứ tự.
