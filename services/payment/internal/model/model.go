// Package model maps GORM structs onto the payment schema.
//
// order/vendor are soft refs (UUID + snapshot) — no FK out of this service.
// Schema is authoritative in services/payment/migrations (do not AutoMigrate).
package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
)

type Payment struct {
	ID              int64          `gorm:"primaryKey"`
	PublicID        uuid.UUID      `gorm:"column:public_id"`
	OrderPublicID   uuid.UUID      `gorm:"column:order_public_id"`
	OrderNumber     string         `gorm:"column:order_number"`
	Provider        string         `gorm:"column:provider"`
	ProviderPayID   *string        `gorm:"column:provider_payment_id"`
	ProviderIntent  *string        `gorm:"column:provider_intent_id"`
	Method          string         `gorm:"column:method"`
	Amount          int64          `gorm:"column:amount"`
	Currency        string         `gorm:"column:currency"`
	FeeAmount       int64          `gorm:"column:fee_amount"`
	NetAmount       int64          `gorm:"column:net_amount"`
	Status          string         `gorm:"column:status"`
	FailureCode     *string        `gorm:"column:failure_code"`
	FailureMessage  *string        `gorm:"column:failure_message"`
	CardBrand       *string        `gorm:"column:card_brand"`
	CardLast4       *string        `gorm:"column:card_last4"`
	AttemptedAt     time.Time      `gorm:"column:attempted_at"`
	AuthorizedAt    *time.Time     `gorm:"column:authorized_at"`
	CapturedAt      *time.Time     `gorm:"column:captured_at"`
	FailedAt        *time.Time     `gorm:"column:failed_at"`
	RawResponse     datatypes.JSON `gorm:"column:raw_response"`
	CreatedAt       time.Time      `gorm:"column:created_at"`
	UpdatedAt       time.Time      `gorm:"column:updated_at"`
	Version         int64          `gorm:"column:version"`

	Refunds []Refund `gorm:"foreignKey:PaymentID"`
}

func (Payment) TableName() string { return "payments" }

// Payment status constants (mirror the CHECK constraint).
const (
	PaymentPending     = "PENDING"
	PaymentAuthorized  = "AUTHORIZED"
	PaymentCaptured    = "CAPTURED"
	PaymentFailed      = "FAILED"
	PaymentCancelled   = "CANCELLED"
	PaymentRefunded    = "REFUNDED"
)

type Refund struct {
	ID             int64          `gorm:"primaryKey"`
	PublicID       uuid.UUID      `gorm:"column:public_id"`
	PaymentID      int64          `gorm:"column:payment_id"`
	OrderPublicID  uuid.UUID      `gorm:"column:order_public_id"`
	OrderNumber    string         `gorm:"column:order_number"`
	Amount         int64          `gorm:"column:amount"`
	Currency       string         `gorm:"column:currency"`
	Reason         string         `gorm:"column:reason"`
	Status         string         `gorm:"column:status"`
	ProviderRefID  *string        `gorm:"column:provider_refund_id"`
	InitiatedAt    time.Time      `gorm:"column:initiated_at"`
	CompletedAt    *time.Time     `gorm:"column:completed_at"`
	RawResponse    datatypes.JSON `gorm:"column:raw_response"`
	CreatedAt      time.Time      `gorm:"column:created_at"`
	UpdatedAt      time.Time      `gorm:"column:updated_at"`
	Version        int64          `gorm:"column:version"`
}

func (Refund) TableName() string { return "refunds" }
