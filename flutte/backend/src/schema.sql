PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id),
  expires_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS houses (
  id INTEGER PRIMARY KEY, owner_id INTEGER NOT NULL REFERENCES users(id),
  name TEXT NOT NULL, city TEXT NOT NULL, description TEXT NOT NULL,
  price_cents INTEGER NOT NULL CHECK(price_cents > 0),
  guests INTEGER NOT NULL CHECK(guests BETWEEN 1 AND 30),
  bedrooms INTEGER NOT NULL CHECK(bedrooms BETWEEN 1 AND 20),
  amenities TEXT NOT NULL DEFAULT '[]', active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS photos (
  id INTEGER PRIMARY KEY, house_id INTEGER NOT NULL REFERENCES houses(id),
  url TEXT NOT NULL, position INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS bookings (
  id INTEGER PRIMARY KEY, house_id INTEGER NOT NULL REFERENCES houses(id),
  guest_id INTEGER NOT NULL REFERENCES users(id),
  start_date TEXT NOT NULL, end_date TEXT NOT NULL,
  guests INTEGER NOT NULL CHECK(guests > 0),
  nightly_cents INTEGER NOT NULL CHECK(nightly_cents > 0),
  total_cents INTEGER NOT NULL CHECK(total_cents > 0),
  status TEXT NOT NULL DEFAULT 'confirmed' CHECK(status IN ('confirmed','cancelled')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK(end_date > start_date)
);
CREATE TABLE IF NOT EXISTS blocks (
  id INTEGER PRIMARY KEY, house_id INTEGER NOT NULL REFERENCES houses(id),
  start_date TEXT NOT NULL, end_date TEXT NOT NULL, CHECK(end_date > start_date)
);
CREATE INDEX IF NOT EXISTS bookings_availability ON bookings(house_id, status, start_date, end_date);
CREATE INDEX IF NOT EXISTS blocks_availability ON blocks(house_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS houses_owner ON houses(owner_id);
CREATE TABLE IF NOT EXISTS uploads (
  filename TEXT PRIMARY KEY, owner_id INTEGER NOT NULL REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS resets (
  token_hash TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), expires_at INTEGER NOT NULL
);
-- Half-open intervals: checkout day is available for the next guest.
CREATE TRIGGER IF NOT EXISTS booking_conflict BEFORE INSERT ON bookings
WHEN NEW.status = 'confirmed' BEGIN
  SELECT RAISE(ABORT, 'date_conflict') WHERE EXISTS (
    SELECT 1 FROM bookings WHERE house_id = NEW.house_id AND status = 'confirmed'
    AND start_date < NEW.end_date AND end_date > NEW.start_date
  ) OR EXISTS (
    SELECT 1 FROM blocks WHERE house_id = NEW.house_id
    AND start_date < NEW.end_date AND end_date > NEW.start_date
  );
END;
CREATE TRIGGER IF NOT EXISTS block_conflict BEFORE INSERT ON blocks BEGIN
  SELECT RAISE(ABORT, 'date_conflict') WHERE EXISTS (
    SELECT 1 FROM bookings WHERE house_id = NEW.house_id AND status = 'confirmed'
    AND start_date < NEW.end_date AND end_date > NEW.start_date
  ) OR EXISTS (
    SELECT 1 FROM blocks WHERE house_id = NEW.house_id
    AND start_date < NEW.end_date AND end_date > NEW.start_date
  );
END;
