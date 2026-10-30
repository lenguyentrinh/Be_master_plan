1. Tại sao viết lại correlated subquery thành CTE + JOIN lại nhanh hơn? (Correlated subquery chạy lại cho mỗi dòng của outer query, còn CTE tính aggregate một lần.)
2. `cost` là gì trong `EXPLAIN`? Nó là “mức độ tốn kém ước tính” (không có đơn vị, không phải thời gian chạy) để database lựa chọn giữa các cách chạy query.
3. Tại sao người ta khuyên dùng khoảng thời gian thay vì hàm `YEAR`? Hàm `YEAR` hoạt động như thế nào?

| # | Tiếng Việt | English |
|---|------------|---------|
| 1 | Tại sao viết lại correlated subquery thành CTE + JOIN lại nhanh hơn? | Why is rewriting a correlated subquery as a CTE + JOIN faster? (A correlated subquery is re-executed for every outer row, while a CTE computes the aggregate once.) |
| 2 | `cost` là gì trong `EXPLAIN`? Nó là “mức độ tốn kém ước tính” (không có đơn vị, không phải thời gian chạy) để database lựa chọn giữa các cách chạy query. | What is `cost` in `EXPLAIN`? It is an estimated, unitless "expense" (not execution time) that the database uses to choose between different ways of executing a query. |
| 3 | Tại sao người ta khuyên dùng khoảng thời gian thay vì hàm `YEAR`? Hàm `YEAR` hoạt động như thế nào? | Why is it recommended to use a date range instead of the `YEAR` function? How does the `YEAR` function work? |
