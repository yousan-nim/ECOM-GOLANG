-- ┌───────────────────────────────────────────────────────────┐
-- │ V3: users + roles + refresh tokens                        │
-- └───────────────────────────────────────────────────────────┘

CREATE TABLE users (
    id              BIGSERIAL    PRIMARY KEY,
    public_id       UUID         NOT NULL DEFAULT uuid_generate_v7() UNIQUE,
    email           CITEXT       NOT NULL UNIQUE,
    email_verified  BOOLEAN      NOT NULL DEFAULT FALSE,
    password_hash   TEXT         NOT NULL,
    full_name       TEXT         NOT NULL,
    phone           TEXT,
    avatar_url      TEXT,
    status          TEXT         NOT NULL DEFAULT 'ACTIVE'
                                  CHECK (status IN ('ACTIVE','SUSPENDED','DELETED')),
    last_login_at   TIMESTAMPTZ,

    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    updated_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    version         BIGINT       NOT NULL DEFAULT 0,
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_users_status      ON users (status) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_phone       ON users (phone)  WHERE phone IS NOT NULL;
CREATE INDEX idx_users_last_login  ON users (last_login_at DESC NULLS LAST);

-- Roles: a user can have multiple roles (CUSTOMER + VENDOR_ADMIN, etc.)
CREATE TABLE user_roles (
    user_id     BIGINT  NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role        TEXT    NOT NULL
                CHECK (role IN ('CUSTOMER','VENDOR_ADMIN','PLATFORM_ADMIN','PLATFORM_SUPPORT')),
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by  BIGINT  REFERENCES users(id) ON DELETE SET NULL,
    PRIMARY KEY (user_id, role)
);

CREATE INDEX idx_user_roles_role ON user_roles (role);

-- Refresh tokens: rotation + revoke list.
CREATE TABLE refresh_tokens (
    id           BIGSERIAL   PRIMARY KEY,
    user_id      BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash   TEXT        NOT NULL UNIQUE,   -- never store raw token
    issued_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ NOT NULL,
    revoked_at   TIMESTAMPTZ,
    revoked_reason TEXT,
    user_agent   TEXT,
    ip_address   INET,
    replaced_by  BIGINT      REFERENCES refresh_tokens(id) ON DELETE SET NULL
);

CREATE INDEX idx_refresh_tokens_user      ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_active    ON refresh_tokens (user_id, expires_at)
    WHERE revoked_at IS NULL;

SELECT attach_standard_triggers('users');
