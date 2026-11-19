# Algorithm

- **Domain:** REST API
- **Week:** Week 5-6

## Mục lục
- [Reference](#reference)
- [Key concepts](#key-concepts)
  - [Design pattern là gì](#design-pattern-là-gì)
  - [1. Singleton](#1-singleton)
  - [2. Factory Method](#2-factory-method)
  - [3. Strategy](#3-strategy)
  - [4. Observer](#4-observer)
  - [5. Builder](#5-builder)
  - [6. Adapter](#6-adapter)
  - [7. State](#7-state)
  - [Tổng hợp](#tổng-hợp)
- [Q&A](#qa)
- [Hands-on](#hands-on)
- [Done](#done)
- [Slide](#slide)

## Reference
- [The 7 most important software design patterns](https://www.educative.io/blog/the-7-most-important-software-design-patterns)

## Key concepts

### Design pattern là gì
- Giải pháp tái sử dụng cho các vấn đề lặp lại trong phần mềm; giúp team có chung "từ vựng" khi trao đổi.
- Lạm dụng pattern làm code khó đọc, khó debug. Chỉ dùng khi có vấn đề thật.

### 1. Singleton
- **Nhóm:** Creational. Giới hạn class chỉ có 1 instance.
- **Cách làm:** constructor private + `getInstance()`. Subclass cần constructor protected + registry (map tên -> singleton).
- **Khi dùng:** cache, thread pool, registry.
- **VD:** `ConfigurationManager` giữ DB settings, payment key, feature flag, env; mọi component đọc cùng một nguồn.

### 2. Factory Method
- **Nhóm:** Creational. Tạo object qua factory method thay vì `new`, caller không cần biết class cụ thể.
- **Lợi ích:** loose coupling, thêm loại mới dễ.
- **VD:** `PaymentFactory` trả về processor Credit Card / PayPal / Apple Pay / Google Pay theo lựa chọn của khách.

### 3. Strategy
- **Nhóm:** Behavioral. Gom các thuật toán liên quan sau một abstraction chung, hoán đổi lúc runtime mà không sửa client.
- **VD:** `DeliveryStrategy` gồm `StandardPricing`, `ExpressPricing`, `PeakHourPricing`, `DiscountPricing`; checkout service chọn khi chạy.

### 4. Observer
- **Nhóm:** Behavioral. Quan hệ 1-nhiều: subject đổi trạng thái thì mọi observer được thông báo.
- **Lợi ích:** cập nhật theo event, subject không cần biết observer xử lý thế nào.
- **Lưu ý:** nhiều subject, ít observer thì lưu observer lặp lại gây tốn bộ nhớ.
- **VD:** order đổi status thì customer, restaurant, driver cùng nhận thông báo (giống follow Twitter, subscribe Facebook page).

### 5. Builder
- **Nhóm:** Creational. Dựng object phức tạp từng bước, tránh constructor quá lớn, dễ đọc và đảm bảo field bắt buộc.
- **Khác Abstract Factory:** Builder dựng từng bước; Abstract Factory trả object một lần.
- **VD:** `OrderBuilder.addBurger().addFries().addDrink().applyCoupon().addInstructions().build()`.

### 6. Adapter
- **Nhóm:** Structural. Chuyển interface của class này sang interface class kia để hai bên không tương thích vẫn làm việc được.
- **Lợi ích:** giảm coupling, đổi vendor dễ.
- **VD:** `MapServiceAdapter` cho app một interface chung trên Google Maps và Mapbox (hoặc adapter đổi output XML thành input JSON).

### 7. State
- **Nhóm:** Behavioral. Object (context) đổi hành vi theo state bên trong; mỗi state là một object riêng, tránh chuỗi if-else.
- **VD:** order đi qua Placed -> Preparing -> Ready for Pickup -> Out for Delivery -> Delivered; Placed thì hủy được, Delivered thì không.

### Tổng hợp
| Pattern | Nhóm | Giải quyết |
|---|---|---|
| Singleton | Creational | Một instance dùng chung |
| Factory Method | Creational | Tạo object không phụ thuộc class cụ thể |
| Builder | Creational | Dựng object phức tạp từng bước |
| Adapter | Structural | Nối hai interface không tương thích |
| Strategy | Behavioral | Đổi thuật toán lúc runtime |
| Observer | Behavioral | Thông báo nhiều bên khi state đổi |
| State | Behavioral | Đổi hành vi theo state, bỏ if-else |

- Hệ thống thật kết hợp nhiều pattern (VD app food delivery dùng cả 7). Mục tiêu là dễ bảo trì, linh hoạt, mở rộng, không phải dùng càng nhiều càng tốt.
- Phân nhóm Creational/Structural/Behavioral là theo Gang of Four, bài viết gốc không ghi.

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
