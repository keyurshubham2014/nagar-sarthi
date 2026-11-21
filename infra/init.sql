-- Nagar Sarthi schema (TASK-02, REQ-D-002..004). Runs once on first container start.
CREATE TABLE IF NOT EXISTS users (
  id          SERIAL PRIMARY KEY,
  phone       TEXT NOT NULL UNIQUE,
  role        TEXT NOT NULL CHECK (role IN ('citizen', 'corporator', 'officer')),
  ward_code   TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS complaints (
  id                    SERIAL PRIMARY KEY,
  user_id               INTEGER REFERENCES users(id),
  ward_code             TEXT,
  locality              TEXT,
  category              TEXT,
  description           TEXT,
  language              TEXT,
  matched_complaint_id  TEXT,
  status                TEXT NOT NULL DEFAULT 'open',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS verification_reports (
  id             SERIAL PRIMARY KEY,
  work_order_id  TEXT NOT NULL,
  user_id        INTEGER REFERENCES users(id),
  outcome        TEXT NOT NULL CHECK (outcome IN ('held', 'failed')),
  photo_path     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
