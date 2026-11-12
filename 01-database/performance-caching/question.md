1. `cost` là gì trong `EXPLAIN`? Nó là “mức độ tốn kém ước tính” (không có đơn vị, không phải thời gian chạy) để database lựa chọn giữa các cách chạy query.
2. Mình đã tạo index trên cột order_date. Tại sao khi dùng WHERE YEAR(order_date) = 2024 thì optimizer không dùng index này (non-sargable)?
