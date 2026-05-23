-- Production patch for login 500s caused by a missing auth_rate_limit table.
-- Safe to run multiple times in phpMyAdmin.

CREATE TABLE IF NOT EXISTS auth_rate_limit (
  ip              VARCHAR(64)     NOT NULL,
  window_start    DATETIME        NOT NULL,
  attempts        INT             NOT NULL DEFAULT 0,
  PRIMARY KEY (ip, window_start)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
