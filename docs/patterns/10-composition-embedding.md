# 10 · Composition / Embedding

> Go ไม่มี inheritance — ใช้ struct embedding + interface composition แทน

## ปัญหาที่แก้

คน OOP อยากได้ "base class" ที่ subclass สืบทอด method มา Go ไม่มีสิ่งนี้
แต่ให้ผลลัพธ์คล้ายกันด้วย **embedding** (has-a ที่ promote method ขึ้นมาให้ใช้)

## วิธีทำใน Go

### Struct embedding — แชร์ helper ร่วม

```go
type BaseHandler struct{ log *slog.Logger }

func (b BaseHandler) ok(c *gin.Context, v any)  { c.JSON(200, v) }
func (b BaseHandler) fail(c *gin.Context, err error) { /* map domain error → status */ }

type OrderHandler struct {
    BaseHandler            // embed — ได้ ok(), fail() มาใช้เลย
    svc *OrderService
}

func (h *OrderHandler) Create(c *gin.Context) {
    // ...
    h.ok(c, order)         // ใช้ method ของ BaseHandler ได้ตรง ๆ
}
```

### Interface composition — ประกอบ interface เล็กเป็นใหญ่

```go
type Reader interface { FindByID(ctx context.Context, id string) (*Order, error) }
type Writer interface { Save(ctx context.Context, o *Order) error }

type OrderRepo interface {   // ประกอบจากชิ้นเล็ก
    Reader
    Writer
}
```

## ใช้ที่ไหนในโปรเจกต์เรา

- BaseHandler/BaseService ที่มี helper ร่วม (response, error mapping)
- ประกอบ repo interface จาก Reader/Writer เล็ก ๆ
- embed `*slog.Logger`, config struct ที่ใช้ซ้ำ

## ข้อควรระวัง

- **อย่าใช้ embedding เลียนแบบ inheritance ลึก ๆ** — ถ้าเริ่มซ้อน 3-4 ชั้นแสดงว่าออกแบบผิด
- embedding ทำให้ method/field ของตัวที่ฝัง "โผล่" ออกมาเป็น public ระวังเผลอเปิด API ที่ไม่ตั้งใจ
- prefer composition (field ชื่อชัด) มากกว่า embedding ถ้าไม่ได้ต้องการ promote method

## เกี่ยวข้อง
[Decorator](08-decorator-middleware.md) · [Anti-patterns](15-anti-patterns.md) (inheritance)
