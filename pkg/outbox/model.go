// Package outbox holds the GORM models for the transactional-outbox and
// idempotent-consumer tables. The tables are identical across all services
// (see each service's create_messaging migration), so the models are shared.
//
// See docs/patterns/04-outbox.md and docs/patterns/05-idempotent-consumer.md.
package outbox

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
)

// Message is one pending/published domain event in the outbox.
// Write it in the SAME transaction as the business change (Unit of Work),
// then let the relay publish it to Kafka and stamp SentAt.
type Message struct {
	ID          uuid.UUID      `gorm:"column:id;primaryKey"`
	Aggregate   string         `gorm:"column:aggregate"`
	AggregateID string         `gorm:"column:aggregate_id"` // Kafka partition key
	Topic       string         `gorm:"column:topic"`
	Payload     datatypes.JSON `gorm:"column:payload"`
	Headers     datatypes.JSON `gorm:"column:headers"`
	CreatedAt   time.Time      `gorm:"column:created_at"`
	SentAt      *time.Time     `gorm:"column:sent_at"`
}

func (Message) TableName() string { return "outbox" }

// ProcessedEvent records that a consumer has handled an event, so re-delivery
// (Kafka is at-least-once) is a no-op. Insert it in the same transaction as
// the side effect, using ON CONFLICT DO NOTHING.
type ProcessedEvent struct {
	EventID   uuid.UUID `gorm:"column:event_id;primaryKey"`
	Consumer  string    `gorm:"column:consumer;primaryKey"`
	HandledAt time.Time `gorm:"column:handled_at"`
}

func (ProcessedEvent) TableName() string { return "processed_events" }
