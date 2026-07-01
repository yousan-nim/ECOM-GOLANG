# rules.md — กฎเหล็ก (ห้ามละเมิด)

> ต่างจาก [`AGENTS.md`](AGENTS.md) (แนวทาง/convention) — ไฟล์นี้คือ **ข้อบังคับ** ที่ทั้งคนและ
> agent ต้องทำตามเป๊ะ ถ้าจำเป็นต้องละเมิด ต้องมีเหตุผลใน PR + reviewer อนุมัติ
> รวมหลักจาก skills: `security-and-hardening`, `api-and-interface-design`, `test-driven-development`, `code-review-and-quality`

## 1. Architecture (boundary ห้ามข้าม)

- **R1.1** ทุก service **ห้าม** เข้า database ของ service อื่นโดยตรง — สื่อสารผ่าน **event** หรือ REST ผ่าน gateway เท่านั้น (Database-per-Service)
- **R1.2** service **ห้ามสั่งงาน** service อื่นแบบ synchronous ใน flow checkout — ให้ react ต่อ event แล้ว emit event ของตัวเอง (choreography, ไม่มี orchestrator)
- **R1.3** DB write + Kafka publish **ต้อง atomic ผ่าน Outbox** — เขียน business data + `outbox` row ใน transaction เดียว แล้วให้ relay ส่ง (ห้าม publish ตรงจาก handler)
- **R1.4** ทุก consumer **ต้อง idempotent** — persist `event_id` ที่ประมวลแล้ว และข้ามซ้ำ (Kafka เป็น at-least-once)
- **R1.5** business logic อยู่ใน `service/` เท่านั้น — `handler/` แค่ parse/validate/ตอบ, `repository/` แค่ DB

## 2. Security (จาก `security-and-hardening`)

- **R2.1** **ห้าม** commit secret/credential/token — ทุก config sensitive มาจาก env (ดู `.env.example`); `.env` อยู่ใน `.gitignore`
- **R2.2** **ห้าม log** ข้อมูล sensitive: password, JWT, card number, CVV, refresh token — mask ก่อน log เสมอ
- **R2.3** ทุก input จาก client (body/query/param) **ต้อง validate** ที่ `handler/` ก่อนส่งเข้า `service/`
- **R2.4** ทุก DB access **ต้องผ่าน GORM/parameterized query** — ห้าม string concatenation เป็น SQL (กัน SQL injection)
- **R2.5** endpoint ที่ต้อง auth **ต้องผ่าน `pkg/auth` middleware** — ตรวจ signature + expiry, ห้ามเชื่อ claim ที่ยังไม่ verify
- **R2.6** ทุก external/broker call **ต้องมี timeout** (`context.WithTimeout`) — ห้ามเรียกแบบไม่มีเวลาจำกัด
- **R2.7** payment/charge/refund **ต้อง idempotent** ผ่าน idempotency key — ห้ามหักเงินซ้ำจาก event replay

## 3. API contracts (จาก `api-and-interface-design`)

- **R3.1** error response **ต้องใช้** envelope เดียว: [`httpx.Fail`](pkg/httpx/httpx.go) → `{"error":{"code","message"}}` — ห้ามเขียน error JSON เอง
- **R3.2** event schema เป็น Go struct ใน `pkg/events` เท่านั้น และ **versioned** — เปลี่ยน schema แบบ breaking ต้องขึ้น version ใหม่ ไม่แก้ของเดิม
- **R3.3** ทุก event **ต้องมี** `event_id`, `occurred_at`, `order_id` (order_id = Kafka partition key เพื่อคง ordering ต่อ order)
- **R3.4** เปลี่ยน public API / event payload = breaking change → ต้องอัปเดต [`design.md`](design.md) + `docs/ARCHITECTURE.md` ใน PR เดียวกัน
- **R3.5** interface ต้องเล็ก (1–3 method) ประกาศ **ฝั่งผู้ใช้** — ห้าม interface ยักษ์ประกาศข้าง implementation

## 4. Code quality (จาก `code-review-and-quality` + [anti-patterns](docs/patterns/15-anti-patterns.md))

- **R4.1** **ห้าม** global mutable state / singleton (`var DB *gorm.DB` ระดับ package) — inject ผ่าน constructor ที่ composition root
- **R4.2** **ห้าม** `panic` แทน error, **ห้าม** กลืน error ด้วย `_ =` (ยกเว้นกรณีจงใจ + มี comment อธิบาย)
- **R4.3** ทุก error ที่ส่งขึ้น layer บน **ต้อง wrap** ด้วย `%w` เพื่อคง chain
- **R4.4** ทุก goroutine **ต้องผูก `context.Context`** และมีทางจบ — ห้าม leak
- **R4.5** **ห้าม** ให้ GORM/Gin/vendor SDK type รั่วเข้า `service/` domain — ห่อด้วย Adapter/Repository/DTO
- **R4.6** โค้ด **ต้องผ่าน** `gofmt`, `go vet`; ห้าม `interface{}`/`any` พร่ำเพรื่อ (ใช้ type ชัดหรือ generics)

## 5. Testing (จาก `test-driven-development`)

- **R5.1** ทุก behavior/bug-fix **ต้องมี test** — bug fix เริ่มด้วย test ที่ fail ก่อน แล้วทำให้ผ่าน
- **R5.2** `service/` (business logic) **ต้องมี unit test** table-driven, mock repository ผ่าน interface
- **R5.3** consumer logic **ต้องมี test** ที่พิสูจน์ idempotency (ยิง event ซ้ำ → ผลไม่เปลี่ยน)
- **R5.4** `go test -race ./...` **ต้องเขียว** ก่อน merge

## 6. Git & process (จาก `git-workflow-and-versioning`)

- **R6.1** **ห้าม** push ตรงเข้า `main` — ทำงานบน branch แล้วเปิด PR
- **R6.2** PR **ต้องผ่าน** CI (build + vet + test) และ review อย่างน้อย 1 คน
- **R6.3** commit เป็น **Conventional Commits**; PR เล็ก focused (แตะเรื่องเดียว)
- **R6.4** **ห้ามแก้** migration ที่ apply แล้ว — สร้าง migration ใหม่เสมอ (forward-only)
