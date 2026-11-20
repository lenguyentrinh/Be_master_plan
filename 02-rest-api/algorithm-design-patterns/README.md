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

Các ví dụ dùng app giao đồ ăn (order, thanh toán, giao hàng). Code là Java rút gọn (bỏ import, getter, constructor phụ), chỉ để thấy ý tưởng.

### Design pattern là gì
- Là cách giải quyết đã được nhiều người dùng cho một loại vấn đề hay gặp khi viết code (giống công thức nấu ăn: không phải code copy được, mà là cách tổ chức code).
- Lợi ích: team nói "dùng Strategy" là ai cũng hiểu ngay, khỏi giải thích dài.
- Lưu ý: không có vấn đề thật mà vẫn dùng pattern thì code chỉ rối thêm.

### 1. Singleton
- **Vấn đề:** có những thứ cả app chỉ nên có một bản. Nếu mỗi nơi tự tạo bản riêng thì tốn tài nguyên, và các bản có thể lệch nhau.
- **Cách giải:** chỉ tạo đúng 1 object, ai cần thì lấy lại chính object đó.
```java
class Config {
    private static Config instance;
    private Config() {}                       // private: bên ngoài không `new` được

    static synchronized Config get() {        // lần đầu tạo, các lần sau trả lại cái cũ
        if (instance == null) instance = new Config();
        return instance;
    }
}

Config.get() == Config.get(); // true: cùng một object
```
- **Khi dùng:** config, cache, connection pool.
- **Lưu ý:** dùng nhiều thì thành biến global trá hình, khó test.

- Real case: [real_cases.md, Case 1](real_cases.md#case-1-singleton-config-dùng-chung), [Case 2](real_cases.md#case-2-singleton-connection-pool)

### 2. Factory Method
- **Vấn đề:** code phải tạo object thuộc nhiều loại tùy điều kiện. Nếu chỗ nào cũng tự `if/else` rồi `new` thì thêm loại mới phải sửa khắp nơi.
- **Cách giải:** gom việc "chọn và tạo object" vào một hàm. Chỗ khác chỉ gọi hàm đó, không cần biết class cụ thể.
```java
interface Payment { void pay(Order order); }
class PayPal implements Payment { public void pay(Order o) { /* gọi PayPal */ } }
class CreditCard implements Payment { public void pay(Order o) { /* gọi cổng thẻ */ } }

class PaymentFactory {
    static Payment create(String method) {
        return switch (method) {
            case "paypal" -> new PayPal();
            case "card"   -> new CreditCard();
            default -> throw new IllegalArgumentException("Unknown: " + method);
        };
    }
}

PaymentFactory.create(request.getMethod()).pay(order); // thêm loại mới chỉ sửa trong factory
```

- Real case: [real_cases.md, Case 3](real_cases.md#case-3-factory-method-chọn-cổng-thanh-toán), [Case 4](real_cases.md#case-4-factory-method-chọn-kênh-thông-báo)

### 3. Strategy
- **Vấn đề:** cùng một việc nhưng có nhiều cách làm. Nhét hết vào một hàm toàn `if/else` thì thêm cách mới phải sửa hàm cũ, dễ làm hỏng nhánh đang chạy.
- **Cách giải:** mỗi cách tính là một hàm riêng, cùng dạng đầu vào/đầu ra, rồi chọn cái cần dùng lúc chạy.
```java
interface PricingStrategy { int fee(Order order); }
class StandardPricing implements PricingStrategy { public int fee(Order o) { return 15000; } }
class ExpressPricing  implements PricingStrategy { public int fee(Order o) { return 30000; } }
class PeakPricing     implements PricingStrategy { public int fee(Order o) { return 20000; } }

Map<String, PricingStrategy> pricing = Map.of(
    "standard", new StandardPricing(),
    "express",  new ExpressPricing(),
    "peak",     new PeakPricing());

int fee = pricing.get(request.getType()).fee(order); // thêm cách tính mới: thêm 1 class + 1 dòng trong map
```
- **Phân biệt với Factory:** Factory chọn "tạo object nào", Strategy chọn "làm theo cách nào".

- Real case: [real_cases.md, Case 5](real_cases.md#case-5-strategy-tính-phí-ship), [Case 6](real_cases.md#case-6-strategy-khuyến-mãi)

### 4. Observer
- **Vấn đề:** khi một object thay đổi, nhiều nơi khác cần biết. Nếu object đó gọi thẳng từng nơi thì thêm nơi mới phải sửa object đó, và nó bị dính chặt vào các nơi kia.
- **Cách giải:** các bên "đăng ký" lắng nghe. Order đổi trạng thái thì chỉ việc phát tín hiệu, ai đã đăng ký sẽ tự chạy.
```java
interface OrderListener { void onStatusChanged(Order order); }

class Order {
    private final List<OrderListener> listeners = new ArrayList<>();
    private String status;

    void addListener(OrderListener l) { listeners.add(l); }

    void setStatus(String status) {
        this.status = status;
        listeners.forEach(l -> l.onStatusChanged(this)); // báo cho tất cả bên đã đăng ký
    }
}

order.addListener(o -> notifyCustomer(o));
order.addListener(o -> notifyDriver(o));
order.setStatus("READY"); // cả hai listener tự chạy, Order không biết chúng làm gì
```
- **Giống:** follow một người trên Twitter, có bài mới thì tự nhận thông báo.

- Real case: [real_cases.md, Case 7](real_cases.md#case-7-observer-order-đổi-trạng-thái), [Case 8](real_cases.md#case-8-observer-user-đăng-ký)

### 5. Builder
- **Vấn đề:** object có nhiều thông tin, trong đó nhiều cái tùy chọn. Constructor dài rất khó đọc, dễ nhầm thứ tự tham số.
- **Cách giải:** dựng object từng bước, mỗi bước có tên rõ ràng, cuối cùng gọi `build()`.
```java
class Order {
    private final User user;
    private final List<String> items;
    private final String coupon, note;

    private Order(Builder b) { user = b.user; items = b.items; coupon = b.coupon; note = b.note; }

    static class Builder {
        private final User user;
        private final List<String> items = new ArrayList<>();
        private String coupon, note;

        Builder(User user) { this.user = user; }
        Builder addItem(String item)  { items.add(item); return this; }
        Builder applyCoupon(String c) { coupon = c; return this; }
        Builder note(String n)        { note = n; return this; }

        Order build() {
            if (items.isEmpty()) throw new IllegalStateException("Order has no items"); // kiểm tra field bắt buộc
            return new Order(this);
        }
    }
}

Order order = new Order.Builder(user)
    .addItem("burger")
    .addItem("fries")
    .applyCoupon("SALE10")
    .note("no onion")
    .build();
```

- Real case: [real_cases.md, Case 9](real_cases.md#case-9-builder-tạo-order), [Case 10](real_cases.md#case-10-builder-httprequest-của-jdk)

### 6. Adapter
- **Vấn đề:** thư viện hoặc hệ thống bên ngoài có cách gọi khác với cách code mình mong muốn. Gọi trực tiếp ở khắp nơi thì khi đổi bên ngoài phải sửa khắp nơi.
- **Cách giải:** viết lớp "đầu chuyển" cho mỗi thư viện, cùng một cách gọi. App chỉ gọi đầu chuyển, đổi vendor chỉ đổi đầu chuyển.
```java
interface MapService { double distance(String from, String to); } // cách gọi mà app mong muốn

class GoogleMapsAdapter implements MapService {
    private final GoogleMapsClient client;   // thư viện bên ngoài, cách gọi riêng
    GoogleMapsAdapter(GoogleMapsClient c) { client = c; }
    public double distance(String a, String b) { return client.getDistanceMatrix(a, b).meters(); }
}

class MapboxAdapter implements MapService {
    private final MapboxClient client;       // thư viện khác, cách gọi khác
    MapboxAdapter(MapboxClient c) { client = c; }
    public double distance(String a, String b) { return client.directions(a, b).distance(); }
}

MapService map = new MapboxAdapter(client);  // đổi vendor: chỉ đổi dòng này
map.distance(shop, home);                    // app luôn gọi một kiểu
```
- **Giống:** ổ cắm chuyển đổi khi đi du lịch.

- Real case: [real_cases.md, Case 11](real_cases.md#case-11-adapter-đổi-nhà-cung-cấp-bản-đồ), [Case 12](real_cases.md#case-12-adapter-đối-tác-trả-về-xml)

### 7. State
- **Vấn đề:** hành vi của object phụ thuộc trạng thái hiện tại, có thao tác chỉ hợp lệ ở một số trạng thái. Kiểm tra bằng `if` rải khắp nơi thì dễ sót và cho phép thao tác sai.
- **Cách giải:** quy định rõ mỗi trạng thái được chuyển sang trạng thái nào, và hành vi nằm ở trạng thái đó.
```java
enum OrderStatus {
    PLACED, PREPARING, READY, DELIVERING, DELIVERED, CANCELED;

    boolean canMoveTo(OrderStatus target) {
        return switch (this) {
            case PLACED     -> target == PREPARING || target == CANCELED; // còn hủy được
            case PREPARING  -> target == READY;
            case READY      -> target == DELIVERING;
            case DELIVERING -> target == DELIVERED;
            default         -> false;                                     // DELIVERED, CANCELED: kết thúc
        };
    }
}

if (!order.getStatus().canMoveTo(target)) {
    throw new IllegalStateException(order.getStatus() + " -> " + target + " is not allowed");
}
```
- **Lưu ý:** đây là bản rút gọn dùng `enum`. Bản đầy đủ của pattern là mỗi trạng thái một class riêng, mỗi class tự xử lý hành vi của trạng thái đó.

- Real case: [real_cases.md, Case 13](real_cases.md#case-13-state-vòng-đời-order), [Case 14](real_cases.md#case-14-state-thanh-toán-và-hoàn-tiền)

### Tổng hợp
| Pattern | Nhóm | Dùng khi |
|---|---|---|
| Singleton | Creational | Cần đúng 1 object dùng chung (config, pool) |
| Factory Method | Creational | Tạo object theo lựa chọn, không muốn code phụ thuộc class cụ thể |
| Builder | Creational | Object có nhiều tham số, dựng từng bước |
| Adapter | Structural | Nối hai thứ có cách gọi khác nhau (đổi vendor) |
| Strategy | Behavioral | Cùng việc nhưng nhiều cách làm, chọn lúc chạy |
| Observer | Behavioral | Một thay đổi cần báo cho nhiều bên |
| State | Behavioral | Hành vi phụ thuộc trạng thái, bỏ if-else |

- App thật dùng kết hợp nhiều pattern (app giao đồ ăn trong bài dùng cả 7). Mục tiêu là code dễ bảo trì, dễ mở rộng, không phải dùng càng nhiều càng tốt.
- Cách phân nhóm Creational/Structural/Behavioral là theo Gang of Four, bài gốc không ghi.

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
