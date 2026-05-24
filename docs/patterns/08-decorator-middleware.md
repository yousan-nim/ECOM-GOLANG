# 08 · Decorator / Middleware

> ห่อ behavior เพิ่ม (log, metric, trace, retry, cache) โดยไม่แตะ business code — โดยห่อด้วย interface เดียวกัน

## ปัญหาที่แก้

cross-cutting concern (logging, metrics, tracing, retry) ถ้าใส่ปนใน business logic →
โค้ดรก, ซ้ำทุก method, แก้ทีต้องไล่ทั้งระบบ

## วิธีทำใน Go

### ที่ชั้น HTTP — Gin middleware (decorator ของ handler)

```go
r.Use(RequestLogger(logger), Recovery(), auth.JWT(secret))
```

### ที่ชั้น service/repo — wrapper ที่ implement interface เดิม

นี่คือทริคที่หลายคนมองข้าม: ห่อ `OrderRepo` ด้วยตัวที่ implement `OrderRepo` เหมือนกัน

```go
type loggingRepo struct {
    next OrderRepo
    log  *slog.Logger
}

func (l loggingRepo) Save(ctx context.Context, o *Order) error {
    start := time.Now()
    err := l.next.Save(ctx, o)         // เรียกตัวจริง
    l.log.InfoContext(ctx, "repo.Save", "order_id", o.ID, "dur", time.Since(start), "err", err)
    return err
}

// ซ้อนได้หลายชั้นตอน wire:
var repo OrderRepo = NewGormOrderRepo(db)
repo = loggingRepo{next: repo, log: logger}
repo = metricsRepo{next: repo, reg: registry}
```

service ไม่รู้เลยว่าถูกห่อ — มันเห็นแค่ `OrderRepo`

## ใช้ที่ไหนในโปรเจกต์เรา

- middleware: auth, request log, recovery, trace_id injection, rate limit
- decorator ชั้น repo/client: latency metric, query logging, retry ของ outbound call

## ข้อควรระวัง

- ลำดับการห่อสำคัญ (เช่น tracing นอกสุด, retry ในสุด) — กำหนดที่ main.go ให้ชัด
- อย่าห่อจนลึกเกินจำเป็น — debug ยาก
- decorator ต้อง **ไม่เปลี่ยน semantic** ของ method ที่ห่อ (ทำแค่เสริม)

## เกี่ยวข้อง
[Adapter](09-adapter.md) · [Composition](10-composition-embedding.md) · [Circuit Breaker/Retry](11-circuit-breaker-retry.md)
