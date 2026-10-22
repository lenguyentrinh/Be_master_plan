# Rules

1. **Không tự ý sửa text cũ.** Mọi chỉnh sửa, xóa hoặc viết lại nội dung đã có trong repo phải hỏi ý người dùng và được đồng ý trước khi làm.
2. Chỉ được thêm nội dung mới (section/file mới) khi người dùng yêu cầu, không đụng vào phần đã có.
3. Mỗi topic (thư mục sub domain) phải có mục `## Slide` trong `README.md` để điền link slide trình bày.
4. Mỗi topic present khoảng 15 phút nên deck chỉ 5 đến 6 slide, bám sát các mục trong `README.md` của topic đó, không thêm nội dung ngoài README.
5. Deck phải trả lời được các câu hỏi cốt lõi của topic. Với `01-database/indexes`: index là gì, B-tree là gì, có mấy loại index, các lỗi thường gặp, làm sao biết index đang hoạt động (dùng `EXPLAIN` hoặc `EXPLAIN ANALYZE`).
6. Hai mục Q&A và Hands-on trong README không làm slide.
7. Chữ trên slide viết bằng tiếng Anh. Không cần speaker notes trên Canva; phần lời thuyết trình tiếng Việt của từng slide viết trong `slide_content.md`.
8. Mỗi topic có thêm `slide_content.md` (nội dung từng slide kèm lời thuyết trình tiếng Việt) và `example.md` (mỗi slide một ví dụ); khi deck thay đổi phải cập nhật hai file này cho khớp.
9. **Quy trình làm mỗi topic, theo đúng thứ tự:**
   1. Đọc refer tham khảo, ghi note vào `README.md` của topic.
   2. Tạo slide trên Canva (deck dùng chung, mỗi topic nối tiếp topic trước). Cả deck dùng chung một kiểu (theo mẫu Robotic Presentation nhưng không dùng hình robot): nền trắng có lưới xám nhạt, màu chủ đạo navy `#2C4877`, tiêu đề font Anton viết hoa cỡ 64 (slide tiêu đề cỡ 84), nội dung font Poppins cỡ 22 đến 24, hình minh họa dạng khung bo tròn viền navy (chỗ cần cảnh báo dùng đỏ nhạt). Bố cục từng slide được sáng tạo tự do, miễn người đọc dễ đọc. Mỗi slide có tiêu đề, gạch đầu dòng và hình minh họa; chỉ thêm ô ghi chú nhỏ trên slide khi thật cần (ví dụ ô NOTE hoặc chú thích màu theo DB: cam là MySQL, xanh ngọc là PostgreSQL, navy là dùng chung), phần còn lại để trong `slide_content.md`.
   3. Sau khi slide xong mới thêm `example.md` và `slide_content.md` cho khớp với deck.
