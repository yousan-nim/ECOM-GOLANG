# context.md — บริบทเบื้องหลัง ("ทำไมถึงเป็นแบบนี้")

> สิ่งที่ **อ่านจากโค้ดไม่ได้** — business, domain, ข้อจำกัด, และเหตุผลของการตัดสินใจ
> "อะไร/อย่างไร" อยู่ใน [`AGENTS.md`](AGENTS.md) · "ออกแบบยังไง" อยู่ใน [`design.md`](design.md)

## 1. Business context

- ระบบ **e-commerce แบบ multi-vendor** (มี vendor, commission rates, vendor payouts ในสคีมา) — ร้านค้าหลายเจ้าขายบน platform เดียว
- แยกเป็น microservices เพื่อให้ **scale แต่ละส่วนอิสระ** และทีมพัฒนาแยกกันได้ — catalog (อ่านหนัก), order (write หนักช่วง checkout), payment (ต้องเชื่อถือได้สูง)
- เจ้าของ/ทีม: BPS Technology (`github.com/yousan-nim/ecom`)

## 2. Domain glossary

| คำ | ความหมาย |
| -- | -------- |
| **Catalog** | สินค้า, variant/option, ราคา, stock/reservation |
| **SKU / ProductVariant** | หน่วยสินค้าที่ขายได้จริง (สี/ไซซ์ = option values ต่อ product) |
| **Reservation** | การจอง stock ระหว่าง saga ก่อน confirm (ยังไม่หักถาวร) |
| **Order / SubOrder** | 1 order แตกเป็นหลาย sub-order ตาม vendor (multi-vendor cart) |
| **Saga** | ธุรกรรมข้าม service ที่ประสานผ่าน event ไม่มี orchestrator กลาง |
| **Outbox** | ตารางที่เก็บ event รอส่ง เพื่อให้ DB write + publish เป็นอะตอม |
| **Compensating action** | การย้อน (เช่น คืน stock, cancel order) เมื่อ saga ล้ม |
| **Idempotency key** | คีย์กัน operation ซ้ำ (โดยเฉพาะ payment/charge) |

## 3. ข้อจำกัด (constraints)

- **at-least-once delivery:** Kafka/Redpanda ส่งซ้ำได้ → consumer ทุกตัวต้อง idempotent (ดู [`rules.md`](rules.md) R1.4)
- **ไม่มี distributed transaction จริง:** DB กับ Kafka commit แยกกัน → ต้องพึ่ง Outbox pattern
- **Ordering ต่อ order:** event ของ order เดียวต้องมาตามลำดับ → ใช้ `order_id` เป็น partition key
- **Redis = performance layer เท่านั้น:** ถ้า Redis ล่ม service ต้องยังทำงานได้ (degrade เป็น no-cache ไม่ fail) — เห็นได้ใน [`services/catalog/cmd/main.go`](services/catalog/cmd/main.go)
- **Auth แบบ verify-per-service:** ยังไม่มี auth/user service แยก — แต่ละ service verify JWT เอง, gateway ยังไม่ verify

## 4. การตัดสินใจสำคัญ (decision log)

- **เลือก Choreography saga (ไม่ใช่ Orchestration):** checkout flow ยังไม่ซับซ้อนมากและอยากให้ service coupling ต่ำ — แต่ละตัว react ต่อ event เอง (ต้องระวัง flow มองเห็นยากเมื่อโตขึ้น → เอกสาร flow ใน [`design.md`](design.md))
- **Database-per-Service:** กัน coupling ที่ schema level, ให้แต่ละ service เปลี่ยน DB ได้อิสระ — แลกกับความซับซ้อนของ eventual consistency
- **Monorepo + `go.work`:** แชร์ `pkg` (auth, kafka, events, httpx, config) ได้ง่าย แต่ deploy แยก service ได้
- **GORM + AutoMigrate/embed migrations:** migration ถูก embed เข้า binary แล้วรันตอน boot (`db.Migrate`) — เลือกความง่ายในการ deploy
- **Gin:** framework ที่ทีมคุ้น, ecosystem middleware กว้าง
- **slog (structured JSON logging):** พร้อมสำหรับ log aggregation บน k8s

### ยังไม่สรุป (pending — ดู `docs/ARCHITECTURE.md` §1)
- Migration tool: `golang-migrate` (prod-grade) vs GORM `AutoMigrate` (ปัจจุบัน)
- Auth/user service แยกออกมา (ตอนนี้ verify JWT per service)

## 5. สถานะปัจจุบันของโปรเจกต์ (2026-07-01)

- โครงสร้าง scaffold + composition root ของแต่ละ service เสร็จ (boot → config → DB → migrate → serve + health)
- infra: `docker-compose*.yml`, `infra/k8s/` (Deployment/Service/HPA/PDB/Ingress), `pkg/cache` (Redis) มีแล้ว
- คลัง pattern ([`docs/patterns/`](docs/patterns/README.md)) และ knowledge graph ([`graphify-out/`](graphify-out/GRAPH_REPORT.md)) จัดทำไว้เป็น reference
- **หมายเหตุ:** `docker-compose*.yml` / `.env*` เดิมเขียนสำหรับ Spring/Java ต้องปรับเป็น Go (ดู `docs/ARCHITECTURE.md` §9)
