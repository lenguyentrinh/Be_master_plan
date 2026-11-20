# Real cases: Design patterns

Mỗi pattern có 2 case. Mỗi case gồm: tình huống, code trước khi dùng pattern (vấn đề), code sau khi dùng (cách giải), và phần "Nhìn vào đâu" để tự kiểm tra kết quả. Code là Java rút gọn (bỏ import, getter), không ghi số liệu đo đạc; chỉ nói cần nhìn gì và kỳ vọng thấy gì.

## Mục lục
- [Singleton](#singleton): [Case 1](#case-1-singleton-config-dùng-chung), [Case 2](#case-2-singleton-connection-pool)
- [Factory Method](#factory-method): [Case 3](#case-3-factory-method-chọn-cổng-thanh-toán), [Case 4](#case-4-factory-method-chọn-kênh-thông-báo)
- [Strategy](#strategy): [Case 5](#case-5-strategy-tính-phí-ship), [Case 6](#case-6-strategy-khuyến-mãi)
- [Observer](#observer): [Case 7](#case-7-observer-order-đổi-trạng-thái), [Case 8](#case-8-observer-user-đăng-ký)
- [Builder](#builder): [Case 9](#case-9-builder-tạo-order), [Case 10](#case-10-builder-httprequest-của-jdk)
- [Adapter](#adapter): [Case 11](#case-11-adapter-đổi-nhà-cung-cấp-bản-đồ), [Case 12](#case-12-adapter-đối-tác-trả-về-xml)
- [State](#state): [Case 13](#case-13-state-vòng-đời-order), [Case 14](#case-14-state-thanh-toán-và-hoàn-tiền)

---

## Singleton

### Case 1. Singleton, config dùng chung
**Tình huống:** app có `OrderService`, `PaymentService`, `ShippingService`. Cả ba đều cần đọc `app.properties` (feature flag, key thanh toán).

**Vấn đề:** mỗi service tự `new Config()`, mỗi lần new lại đọc file.
```java
class Config {
    Config() { System.out.println("Loading app.properties..."); /* đọc file */ }
}
class OrderService   { Config config = new Config(); }
class PaymentService { Config config = new Config(); }
class ShippingService{ Config config = new Config(); }
```

**Cách giải:**
```java
class Config {
    private static Config instance;
    private Config() { System.out.println("Loading app.properties..."); }
    static synchronized Config get() {
        if (instance == null) instance = new Config();
        return instance;
    }
}
class OrderService { Config config = Config.get(); }
class PaymentService { Config config = Config.get(); }
```

**Nhìn vào đâu:**
- Khởi tạo `OrderService`, `PaymentService`, `ShippingService` rồi xem console. Trước: dòng `Loading app.properties...` in ra 3 lần. Sau: chỉ in 1 lần.
- `Config.get() == Config.get()` phải trả `true`.

### Case 2. Singleton, connection pool
**Tình huống:** REST API nhận nhiều request đồng thời, mỗi request cần truy vấn DB.

**Vấn đề:** mỗi request tạo một pool mới, nên số kết nối tới DB tăng theo số request.
```java
@GetMapping("/orders/{id}")
Order get(@PathVariable long id) {
    HikariDataSource ds = new HikariDataSource(cfg); // mỗi request một pool
    return query(ds, id);
}
```

**Cách giải:** chỉ một `DataSource` cho cả app, dùng lại cho mọi request.
```java
class Db {
    private static final HikariDataSource DS = new HikariDataSource(cfg); // tạo 1 lần khi load class
    static DataSource get() { return DS; }
}
```
Trong Spring, bean mặc định đã là singleton nên `@Bean DataSource` hoạt động tương tự.

**Nhìn vào đâu:** chạy vài trăm request song song rồi xem số connection ở MySQL: `SHOW STATUS LIKE 'Threads_connected';`. Trước: số này tăng theo request, dễ gặp lỗi `Too many connections`. Sau: số này không vượt quá `maximumPoolSize` đã cấu hình.

---

## Factory Method

### Case 3. Factory Method, chọn cổng thanh toán
**Tình huống:** checkout cho khách chọn Card hoặc PayPal, sắp tới thêm Apple Pay.

**Vấn đề:** `if/else` chọn class nằm ở nhiều nơi (checkout, retry, refund). Thêm Apple Pay phải sửa tất cả.
```java
if (method.equals("paypal")) new PayPal().pay(order);
else if (method.equals("card")) new CreditCard().pay(order);
```

**Cách giải:**
```java
interface Payment { void pay(Order order); }

class PaymentFactory {
    static Payment create(String method) {
        return switch (method) {
            case "paypal" -> new PayPal();
            case "card"   -> new CreditCard();
            case "apple"  -> new ApplePay();   // thêm loại mới: một dòng ở đây
            default -> throw new IllegalArgumentException("Unknown: " + method);
        };
    }
}
PaymentFactory.create(method).pay(order);
```

**Nhìn vào đâu:** thêm `ApplePay`, rồi `grep` tìm `new PayPal()` trong code. Sau khi dùng factory, chỉ còn một chỗ duy nhất, các chỗ checkout, retry, refund không phải sửa.

### Case 4. Factory Method, chọn kênh thông báo
**Tình huống:** gửi thông báo "đơn đã giao" qua Email, SMS hoặc Push tùy cài đặt của từng user.

**Vấn đề:** `NotificationService` biết hết chi tiết từng kênh, nên mỗi lần thêm kênh phải sửa service.

**Cách giải:**
```java
interface Notifier { void send(String to, String message); }

class NotifierFactory {
    static Notifier create(String channel) {
        return switch (channel) {
            case "EMAIL" -> new EmailNotifier();
            case "SMS"   -> new SmsNotifier();
            case "PUSH"  -> new PushNotifier();
            default -> throw new IllegalArgumentException(channel);
        };
    }
}
NotifierFactory.create(user.getChannel()).send(user.getContact(), "Order delivered");
```

**Nhìn vào đâu:** viết test với 3 user có channel khác nhau. Kỳ vọng mỗi user nhận đúng một loại notifier, và `NotificationService` không import `EmailNotifier`, `SmsNotifier`, `PushNotifier`.

---

## Strategy

### Case 5. Strategy, tính phí ship
**Tình huống:** phí ship phụ thuộc loại giao: thường, nhanh, giờ cao điểm.

**Vấn đề:** một method dài đầy `if/else`, thêm cách tính mới phải sửa method này và dễ làm hỏng nhánh cũ.
```java
int fee(Order o, String type) {
    if (type.equals("standard")) return 15000;
    else if (type.equals("express")) return 30000;
    else if (type.equals("peak")) return 20000 + o.distanceKm() * 1000;
    ...
}
```

**Cách giải:**
```java
interface PricingStrategy { int fee(Order order); }
class StandardPricing implements PricingStrategy { public int fee(Order o) { return 15000; } }
class ExpressPricing  implements PricingStrategy { public int fee(Order o) { return 30000; } }
class PeakPricing     implements PricingStrategy {
    public int fee(Order o) { return 20000 + o.distanceKm() * 1000; }
}

Map<String, PricingStrategy> pricing = Map.of(
    "standard", new StandardPricing(), "express", new ExpressPricing(), "peak", new PeakPricing());
int fee = pricing.get(type).fee(order);
```

**Nhìn vào đâu:** mỗi strategy test riêng được bằng một test nhỏ (input `Order`, assert phí). Thêm cách tính mới chỉ thêm class mới, các test cũ không phải sửa.

### Case 6. Strategy, khuyến mãi
**Tình huống:** checkout hỗ trợ mã giảm theo phần trăm, giảm số tiền cố định, miễn phí ship.

**Cách giải:**
```java
interface Promotion { BigDecimal apply(BigDecimal total); }

Promotion percent10 = total -> total.multiply(new BigDecimal("0.90"));
Promotion minus50k  = total -> total.subtract(new BigDecimal("50000")).max(BigDecimal.ZERO);

BigDecimal payable = order.getPromotion().apply(order.getTotal());
```
Cùng ý tưởng với `Comparator` trong JDK: `list.sort(Comparator.comparing(Order::getTotal))`, thuật toán so sánh được truyền vào lúc chạy.

**Nhìn vào đâu:** với cùng `total`, đổi `Promotion` thì `payable` đổi theo mà không phải sửa code checkout. Test trường hợp biên: giảm cố định lớn hơn tổng tiền thì `payable` phải bằng 0, không âm.

---

## Observer

### Case 7. Observer, order đổi trạng thái
**Tình huống:** khi order chuyển trạng thái, cần báo cho khách, quán và tài xế.

**Vấn đề:** `setStatus` gọi thẳng từng bên. Thêm gửi SMS phải sửa `Order`.
```java
void setStatus(String s) {
    this.status = s;
    customerNotifier.notify(this);
    restaurantNotifier.notify(this);
    driverNotifier.notify(this);
}
```

**Cách giải:**
```java
interface OrderListener { void onStatusChanged(Order order); }

class Order {
    private final List<OrderListener> listeners = new ArrayList<>();
    void addListener(OrderListener l) { listeners.add(l); }
    void setStatus(String s) {
        this.status = s;
        listeners.forEach(l -> l.onStatusChanged(this));
    }
}
order.addListener(o -> customerNotifier.notify(o));
order.addListener(o -> driverNotifier.notify(o));
order.setStatus("READY");
```

**Nhìn vào đâu:** gọi `setStatus("READY")` và kiểm tra mọi listener đã đăng ký đều chạy. Thêm listener SMS bằng một dòng `addListener`, file `Order` không đổi.

### Case 8. Observer, user đăng ký
**Tình huống:** sau khi user đăng ký cần gửi email chào mừng và tạo ví.

**Vấn đề:** `UserService.register()` chứa luôn logic gửi mail và tạo ví, nên vừa dài vừa dính chặt vào các module khác.

**Cách giải:** dùng event của Spring (đây chính là Observer).
```java
record UserRegistered(Long userId, String email) {}

@Service
class UserService {
    private final ApplicationEventPublisher publisher;
    void register(String email) {
        Long id = save(email);
        publisher.publishEvent(new UserRegistered(id, email)); // chỉ phát tín hiệu
    }
}
@Component class WelcomeEmailListener {
    @EventListener void on(UserRegistered e) { /* gửi mail */ }
}
@Component class CreateWalletListener {
    @EventListener void on(UserRegistered e) { /* tạo ví */ }
}
```

**Nhìn vào đâu:** gọi `register()` rồi xem log của hai listener. Kỳ vọng cả hai chạy, và `UserService` không import `WelcomeEmailListener` hay `CreateWalletListener`. Lưu ý mặc định `@EventListener` chạy đồng bộ trong cùng thread với `register()`.

---

## Builder

### Case 9. Builder, tạo order
**Tình huống:** order có món, coupon, ghi chú, giờ hẹn giao... nhiều trường tùy chọn.

**Vấn đề:** constructor dài, dễ nhầm thứ tự tham số.
```java
new Order(user, items, "SALE10", null, true, "no onion"); // true là gì? null là gì?
```

**Cách giải:**
```java
Order order = new Order.Builder(user)
    .addItem("burger")
    .addItem("fries")
    .applyCoupon("SALE10")
    .note("no onion")
    .build();   // build() kiểm tra có ít nhất một món
```
(code class `Order.Builder` xem ở README, mục Builder)

**Nhìn vào đâu:** đọc dòng code là hiểu từng giá trị là gì. `new Order.Builder(user).build()` không có món nào phải ném `IllegalStateException`, nhờ đó không bao giờ có order rỗng.

### Case 10. Builder, `HttpRequest` của JDK
**Tình huống:** gọi API đối tác bằng `java.net.http` (JDK 11+).

**Cách giải:** JDK đã dùng Builder sẵn.
```java
HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create("https://partner.example.com/shipments"))
    .header("Content-Type", "application/json")
    .header("Authorization", "Bearer " + token)
    .timeout(Duration.ofSeconds(5))
    .POST(HttpRequest.BodyPublishers.ofString(json))
    .build();
HttpResponse<String> res = HttpClient.newHttpClient()
    .send(request, HttpResponse.BodyHandlers.ofString());
```

**Nhìn vào đâu:** request có nhiều phần tùy chọn (header, timeout, body) nhưng mỗi phần là một bước có tên. Bỏ `.timeout(...)` thì request vẫn tạo được, vì phần nào không bắt buộc thì có thể không gọi.

---

## Adapter

### Case 11. Adapter, đổi nhà cung cấp bản đồ
**Tình huống:** app tính khoảng cách quán tới nhà khách bằng Google Maps, sau đó muốn chuyển sang Mapbox.

**Vấn đề:** code gọi `GoogleMapsClient` trực tiếp ở nhiều nơi (tính phí ship, gợi ý quán gần, ước tính thời gian giao).

**Cách giải:**
```java
interface MapService { double distance(String from, String to); }

class GoogleMapsAdapter implements MapService {
    private final GoogleMapsClient client;
    GoogleMapsAdapter(GoogleMapsClient c) { client = c; }
    public double distance(String a, String b) { return client.getDistanceMatrix(a, b).meters(); }
}
class MapboxAdapter implements MapService {
    private final MapboxClient client;
    MapboxAdapter(MapboxClient c) { client = c; }
    public double distance(String a, String b) { return client.directions(a, b).distance(); }
}
MapService map = new MapboxAdapter(client);
```

**Nhìn vào đâu:** `grep` tìm `GoogleMapsClient` trong code. Sau khi dùng Adapter, chỉ còn trong `GoogleMapsAdapter`. Đổi vendor là đổi dòng `new MapboxAdapter(...)`, phần còn lại của app không sửa.

### Case 12. Adapter, đối tác trả về XML
**Tình huống:** đối tác vận chuyển cũ trả trạng thái đơn bằng XML, còn app chỉ làm việc với object `ShipmentStatus`.

**Cách giải:**
```java
record ShipmentStatus(String trackingCode, String status) {}

interface ShippingTracker { ShipmentStatus track(String trackingCode); }

class LegacyXmlTrackerAdapter implements ShippingTracker {
    private final LegacyPartnerClient client; // trả về chuỗi XML
    public ShipmentStatus track(String code) {
        String xml = client.getStatusXml(code);
        return parse(xml); // XML -> ShipmentStatus, chỉ nằm trong adapter
    }
}
```
JDK cũng có sẵn một Adapter: `new InputStreamReader(inputStream)` biến `InputStream` (byte) thành `Reader` (ký tự).

**Nhìn vào đâu:** phần còn lại của app chỉ thấy `ShippingTracker`. Khi đối tác đổi sang JSON, chỉ viết thêm adapter mới và đổi chỗ khởi tạo, không sửa code dùng `ShipmentStatus`.

---

## State

### Case 13. State, vòng đời order
**Tình huống:** order đi theo PLACED, PREPARING, READY, DELIVERING, DELIVERED. Chỉ hủy được khi còn PLACED.

**Vấn đề:** kiểm tra trạng thái bằng `if` rải khắp nơi, dễ sót, ví dụ vô tình cho hủy order đã giao.
```java
if (order.getStatus().equals("DELIVERED")) { /* có chỗ nhớ chặn, có chỗ quên */ }
```

**Cách giải:**
```java
enum OrderStatus {
    PLACED, PREPARING, READY, DELIVERING, DELIVERED, CANCELED;

    boolean canMoveTo(OrderStatus target) {
        return switch (this) {
            case PLACED     -> target == PREPARING || target == CANCELED;
            case PREPARING  -> target == READY;
            case READY      -> target == DELIVERING;
            case DELIVERING -> target == DELIVERED;
            default         -> false;
        };
    }
}
if (!order.getStatus().canMoveTo(target)) throw new IllegalStateException("Not allowed");
```

**Nhìn vào đâu:** viết test cho hai ca: `PLACED -> CANCELED` phải cho phép, `DELIVERED -> CANCELED` phải bị chặn. Với REST API, bắt `IllegalStateException` và trả HTTP `409 Conflict`.

### Case 14. State, thanh toán và hoàn tiền
**Tình huống:** giao dịch có PENDING, PAID, REFUNDED. Chỉ hoàn tiền khi đã PAID, và chỉ hoàn một lần.

**Vấn đề:** gọi API refund hai lần (khách bấm hai lần, hoặc client retry) có thể hoàn tiền hai lần nếu không kiểm tra trạng thái.

**Cách giải:** mỗi trạng thái tự quy định hành động nào hợp lệ.
```java
enum PaymentStatus {
    PENDING  { PaymentStatus pay() { return PAID; }
               PaymentStatus refund() { throw bad("refund"); } },
    PAID     { PaymentStatus pay() { throw bad("pay"); }
               PaymentStatus refund() { return REFUNDED; } },
    REFUNDED { PaymentStatus pay() { throw bad("pay"); }
               PaymentStatus refund() { throw bad("refund"); } };

    abstract PaymentStatus pay();
    abstract PaymentStatus refund();
    IllegalStateException bad(String action) {
        return new IllegalStateException(action + " not allowed in " + this);
    }
}
payment.setStatus(payment.getStatus().refund());
```

**Nhìn vào đâu:** gọi `refund()` liên tiếp hai lần trên một giao dịch `PAID`. Lần một chuyển sang `REFUNDED`, lần hai phải ném `IllegalStateException` (`refund not allowed in REFUNDED`), nghĩa là không bao giờ hoàn tiền hai lần.
