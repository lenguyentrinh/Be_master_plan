# Rules

1. **Không tự ý sửa text cũ.** Mọi chỉnh sửa, xóa hoặc viết lại nội dung đã có trong repo phải hỏi ý người dùng và được đồng ý trước khi làm.
2. Chỉ được thêm nội dung mới (section/file mới) khi người dùng yêu cầu, không đụng vào phần đã có.
3. Mỗi topic (thư mục sub domain) phải có mục `## Slide` trong `README.md` để điền link slide trình bày.
4. Mỗi topic present khoảng 15 phút nên deck chỉ 5 đến 6 slide, bám sát các mục trong `README.md` của topic đó, không thêm nội dung ngoài README.
5. Deck phải trả lời được các câu hỏi cốt lõi của topic. Với `01-database/indexes`: index là gì, B-tree là gì, có mấy loại index, các lỗi thường gặp, làm sao biết index đang hoạt động (dùng `EXPLAIN` hoặc `EXPLAIN ANALYZE`).
6. Hai mục Q&A và Hands-on trong README không làm slide.
7. Chữ trên slide viết bằng tiếng Anh; mỗi slide phải có speaker notes bằng tiếng Việt.
8. Mỗi topic có thêm `slide_content.md` (nội dung từng slide) và `example.md` (mỗi slide một ví dụ); khi deck thay đổi phải cập nhật hai file này cho khớp.
