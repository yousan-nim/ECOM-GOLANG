# 11 · Circuit Breaker / Retry + Backoff

> ป้องกันระบบล่มลามเมื่อ dependency ภายนอก (payment gateway, broker) มีปัญหา

> **สถานะ: ใช้เมื่อจำเป็น** — ใส่กับ outbound call ที่ออกนอกระบบจริงเท่านั้น

## ปัญหาที่แก้

- payment gateway ช้า/ล่ม → request ค้างสะสม → thread/goroutine หมด → ทั้ง service ตาย (cascading failure)
- retry แบบไม่มี backoff → ยิงซ้ำกระหน่ำ dependency ที่กำลังป่วย (retry storm)

## วิธีทำใน Go

### Retry + exponential backoff + jitter

```go
func withRetry(ctx context.Context, attempts int, fn func() error) error {
    var err error
    for i := 0; i < attempts; i++ {
        if err = fn(); err == nil || !isRetryable(err) {
            return err
        }
        backoff := time.Duration(1<<i)*100*time.Millisecond + jitter()
        select {
        case <-time.After(backoff):
        case <-ctx.Done():
            return ctx.Err()
        }
    }
    return err
}
```

### Circuit breaker (เช่น `sony/gobreaker`)

```go
cb := gobreaker.NewCircuitBreaker(gobreaker.Settings{
    Name:        "payment-gateway",
    MaxRequests: 1,
    Timeout:     30 * time.Second,          // half-open หลัง 30s
    ReadyToTrip: func(c gobreaker.Counts) bool { return c.ConsecutiveFailures > 5 },
})
res, err := cb.Execute(func() (any, error) { return gateway.Charge(ctx, req) })
```
state: **Closed** (ปกติ) → **Open** (ตัดวงจร, fail เร็ว) → **Half-open** (ลองทีละนิด)

## ใช้ที่ไหนในโปรเจกต์เรา

- payment-service → payment gateway ภายนอก (สำคัญสุด)
- relay → Kafka (retry; แต่ outbox ทำให้ปลอดภัยอยู่แล้ว ไม่ต้อง breaker)
- **ไม่ต้องใส่** กับการคุยภายในผ่าน event (async อยู่แล้ว ทนความล่าช้าได้)

## ข้อควรระวัง

- retry เฉพาะ error ที่ retry ได้ (timeout, 503) — อย่า retry `400/validation`
- retry ต้องคู่กับ idempotency เสมอ ([05](05-idempotent-consumer.md))
- ตั้ง timeout ผ่าน `context` ทุก outbound call
- อย่าใส่ breaker พร่ำเพรื่อ — ใส่เฉพาะจุดที่ "ออกนอกระบบ"

## เกี่ยวข้อง
[Decorator](08-decorator-middleware.md) (ห่อ retry เป็น decorator) · [Idempotent Consumer](05-idempotent-consumer.md)
