# AGENTS.md — คำสั่งสำหรับ AI agents (Claude Code / Cursor / Copilot)

> ไฟล์นี้บอก agent ว่า **"ทำงานกับ repo นี้อย่างไร"** — คำสั่ง, convention, ข้อห้าม
> ห้าม/ควร ทำอะไรเป๊ะ ๆ อยู่ใน [`rules.md`](rules.md) · เหตุผลเบื้องหลังใน [`context.md`](context.md) ·
> การออกแบบระบบใน [`design.md`](design.md)

## 1. โปรเจกต์นี้คืออะไร

E-commerce API เป็น **Go microservices 3 ตัว** (catalog, order, payment) แบบ
**Database-per-Service** ประสานกันผ่าน **event แบบ asynchronous** (choreography saga
บน Kafka/Redpanda) มี nginx เป็น gateway เดียว รายละเอียดสถาปัตยกรรม → [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

- **Module path:** `github.com/yousan-nim/ecom`
- **Go:** 1.25 · **Monorepo:** `go.work` ผูก 4 module (`pkg` + 3 services)
- **Stack:** Gin (HTTP) · GORM (DB) · PostgreSQL 16 (1 instance/service) · Kafka/Redpanda · JWT ต่อ service · Redis (cache แบบ optional)

## 2. คำสั่งสำคัญ (verify ด้วยชุดนี้เสมอ)

```bash
# build ทุก module
go build ./...

# test ทั้งหมด (จาก root — go.work เห็นทุก module)
go test ./...
go test -race -cover ./...        # ก่อนเปิด PR

# lint / format
gofmt -l .                        # ต้องไม่มี output (ถ้ามี = ยังไม่ format)
go vet ./...
golangci-lint run                 # ถ้าติดตั้งไว้

# tidy dependency ของแต่ละ service (แยก go.mod)
cd services/catalog && go mod tidy

# รันทั้ง stack (local)
docker compose -f docker-compose.yml -f docker-compose.local.yml up
#   gateway → :8080 · catalog → :8081 · order → :8082 · payment → :8083
#   redpanda console → :8085 · pgAdmin → :5050
```

รัน service เดียวตอน dev: `go run ./services/catalog/cmd` (ต้องมี env ครบ — ดู `.env.example`)

## 3. โครงสร้าง & ที่วางโค้ด

```
pkg/                     โค้ดใช้ร่วม — auth, kafka(+outbox), events, httpx, config, db, cache
services/<svc>/
  cmd/main.go            composition root: load config → open DB → migrate → serve
  internal/
    handler/             Gin handlers (ชั้น HTTP)
    service/             business logic
    repository/          GORM data access
    model/               GORM models
    consumer/            Kafka consumers (saga reactions)
```

ทุก service มีรูปเดียวกัน: **`handler → service → repository`** (ไหลทางเดียว ไม่ย้อน)
วางโค้ดใหม่ให้ตรงชั้น — logic อยู่ใน `service/`, ไม่ใช่ใน `handler/`

## 4. Convention (ทำตามของเดิมใน repo)

- **Logging:** `log/slog` แบบ JSON handler (ดู [`services/catalog/cmd/main.go`](services/catalog/cmd/main.go)) — structured เท่านั้น ไม่ใช้ `fmt.Println`
- **Error:** คืน `error` เสมอ, wrap ด้วย `fmt.Errorf("...: %w", err)`, จัดการที่ขอบ (handler) แล้วตอบด้วย `httpx.Fail`
- **HTTP error envelope:** ใช้ [`httpx.Fail(c, status, code, msg)`](pkg/httpx/httpx.go) — อย่าเขียน JSON error เอง
- **Health:** ใช้ [`httpx.Health`](pkg/httpx/httpx.go) — `/healthz` (liveness) + `/readyz` (readiness ping DB) ทุก service
- **Config:** โหลดผ่าน `config.Load("<service>")` เท่านั้น — อย่าอ่าน `os.Getenv` กระจัดกระจาย
- **Dependency injection:** ประกอบทุกอย่างที่ `cmd/main.go` (composition root) แล้วฉีดผ่าน constructor — **ห้าม global/singleton**
- **Interface:** เล็ก (1–3 method), ประกาศ **ฝั่งผู้ใช้** ไม่ใช่ฝั่ง implementation
- **Graceful shutdown:** service ต้อง drain request บน SIGINT/SIGTERM (มี pattern อยู่ใน `main.go` แล้ว)
- **Migrations:** embed `MigrationsFS` แล้วรันผ่าน `db.Migrate` ตอน boot
- **Test:** table-driven tests, ไฟล์ `_test.go` คู่กับโค้ด
- **Commit:** Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:` …)

## 5. Design patterns ที่ใช้ (อ่านก่อนแตะเรื่องที่เกี่ยว)

คลังความรู้อยู่ใน [`docs/patterns/`](docs/patterns/README.md) — อ้างถึงเมื่อทำงานเรื่องนั้น:

| งานที่ทำ | อ่าน pattern |
| -------- | ------------ |
| เพิ่ม data access | [Repository](docs/patterns/01-repository.md) · [Unit of Work](docs/patterns/02-unit-of-work.md) |
| แตะ event / saga | [Saga](docs/patterns/03-saga-choreography.md) · [Outbox](docs/patterns/04-outbox.md) · [Idempotent Consumer](docs/patterns/05-idempotent-consumer.md) |
| เขียน constructor | [Functional Options](docs/patterns/06-functional-options.md) |
| ห่อ SDK ภายนอก | [Adapter](docs/patterns/09-adapter.md) |
| เรียก external ที่อาจล่ม | [Circuit Breaker/Retry](docs/patterns/11-circuit-breaker-retry.md) |
| แยก API/DB model | [DTO/Mapper](docs/patterns/14-dto-mapper.md) |

## 6. ❌ ห้ามทำ (สรุป — ฉบับเต็มใน `rules.md`)

- อย่าแก้ไฟล์ **generated** (`*.pb.go`, migration ที่ apply ไปแล้ว)
- อย่า commit `.env` / secret — ใช้ `.env.example` เป็นแม่แบบ
- อย่าให้ service เข้า **DB ของ service อื่น** — สื่อสารผ่าน event/REST เท่านั้น
- อย่าใช้ **global state / singleton** (`var DB *gorm.DB` ระดับ package) → ดู [anti-patterns](docs/patterns/15-anti-patterns.md)
- อย่า `panic` แทน error / กลืน error (`_ =`)
- อย่าปล่อย GORM / Gin / vendor SDK รั่วเข้า domain layer
- อย่าเปิด goroutine ที่ไม่ผูก `context` (leak)

## 7. เช็คก่อนบอกว่าเสร็จ

1. `go build ./...` ผ่าน
2. `gofmt -l .` ไม่มี output · `go vet ./...` ผ่าน
3. `go test ./...` เขียว (เพิ่ม/แก้ test ให้ครอบ behavior ใหม่)
4. ไม่มี secret / debug print หลุด
5. ตรงกับ `rules.md` และ pattern ที่เกี่ยวข้อง
