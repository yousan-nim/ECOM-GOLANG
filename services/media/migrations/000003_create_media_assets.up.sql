-- ┌───────────────────────────────────────────────────────────┐
-- │ V3: media_assets (media service).                          │
-- │  Uploaded files (product images, avatars, review photos).  │
-- │  The blob lives in object storage (S3/GCS); this row is     │
-- │  metadata + storage pointer. owner_* is a polymorphic soft  │
-- │  ref — no cross-service FK.                                 │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE media_assets (
    id                BIGSERIAL   PRIMARY KEY,
    public_id         UUID        NOT NULL DEFAULT uuid_generate_v7() UNIQUE,

    -- Polymorphic owner (soft ref to whichever service owns it).
    owner_type        TEXT        NOT NULL
                      CHECK (owner_type IN ('PRODUCT','VARIANT','VENDOR','USER','REVIEW','CATEGORY')),
    owner_public_id   UUID        NOT NULL,

    -- Object storage pointer.
    bucket            TEXT        NOT NULL,
    object_key        TEXT        NOT NULL UNIQUE,           -- path within the bucket
    url               TEXT,                                  -- public/CDN URL once READY

    mime_type         TEXT        NOT NULL,
    size_bytes        BIGINT      NOT NULL CHECK (size_bytes >= 0),
    checksum_sha256   TEXT,                                  -- integrity / dedup
    width             INTEGER     CHECK (width  IS NULL OR width  >= 0),  -- images
    height            INTEGER     CHECK (height IS NULL OR height >= 0),

    status            TEXT        NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING','READY','FAILED','DELETED')),  -- upload lifecycle
    alt_text          TEXT,
    sort_order        INTEGER     NOT NULL DEFAULT 0,

    uploaded_by       UUID,                                  -- → auth.users
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version           BIGINT      NOT NULL DEFAULT 0
);

CREATE INDEX idx_media_owner  ON media_assets (owner_type, owner_public_id, sort_order)
    WHERE status <> 'DELETED';
CREATE INDEX idx_media_status ON media_assets (status, created_at);

SELECT attach_standard_triggers('media_assets');
