-- AI Calorie Coach — backend schema
-- MySQL 5.7+ / 8.x, utf8mb4
-- Run once via cPanel → phpMyAdmin → Import, or `mysql -u user -p db_name < schema.sql`.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS food_items;
DROP TABLE IF EXISTS wall_user_blocks;
DROP TABLE IF EXISTS wall_post_reports;
DROP TABLE IF EXISTS wall_post_saves;
DROP TABLE IF EXISTS wall_post_likes;
DROP TABLE IF EXISTS public_wall_posts;
DROP TABLE IF EXISTS meals;
DROP TABLE IF EXISTS saved_foods;
DROP TABLE IF EXISTS user_settings;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS auth_rate_limit;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
  id              CHAR(36)        NOT NULL PRIMARY KEY,
  email           VARCHAR(255)    NOT NULL,
  name            VARCHAR(255)    NULL,
  photo_url       VARCHAR(512)    NULL,
  provider        ENUM('google','apple') NOT NULL,
  provider_sub    VARCHAR(255)    NOT NULL,
  created_at      DATETIME        NOT NULL,
  updated_at      DATETIME        NOT NULL,
  deleted_at      DATETIME        NULL,
  UNIQUE KEY uniq_provider_sub (provider, provider_sub),
  KEY idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE meals (
  id              CHAR(36)        NOT NULL PRIMARY KEY,
  user_id         CHAR(36)        NOT NULL,
  date            DATETIME        NOT NULL,
  meal_type       VARCHAR(32)     NOT NULL,
  total_min       INT             NOT NULL DEFAULT 0,
  total_max       INT             NOT NULL DEFAULT 0,
  total_avg       INT             NOT NULL DEFAULT 0,
  photo_id        CHAR(36)        NULL,
  assumptions     JSON            NULL,
  updated_at      DATETIME        NOT NULL,
  deleted_at      DATETIME        NULL,
  KEY idx_user_date (user_id, date),
  KEY idx_user_updated (user_id, updated_at),
  CONSTRAINT fk_meals_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE food_items (
  id              CHAR(36)        NOT NULL PRIMARY KEY,
  meal_id         CHAR(36)        NOT NULL,
  name            VARCHAR(255)    NOT NULL,
  portion_size    VARCHAR(64)     NULL,
  cal_min         INT             NOT NULL DEFAULT 0,
  cal_max         INT             NOT NULL DEFAULT 0,
  cal_avg         INT             NOT NULL DEFAULT 0,
  confidence      DOUBLE          NOT NULL DEFAULT 0,
  protein         DOUBLE          NULL,
  carbs           DOUBLE          NULL,
  fat             DOUBLE          NULL,
  fiber           DOUBLE          NULL,
  sugar           DOUBLE          NULL,
  saturated_fat   DOUBLE          NULL,
  trans_fat       DOUBLE          NULL,
  cholesterol     DOUBLE          NULL,
  sodium          DOUBLE          NULL,
  potassium       DOUBLE          NULL,
  updated_at      DATETIME        NOT NULL,
  deleted_at      DATETIME        NULL,
  KEY idx_meal (meal_id),
  CONSTRAINT fk_food_items_meal FOREIGN KEY (meal_id) REFERENCES meals(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE public_wall_posts (
  id              CHAR(36)        NOT NULL PRIMARY KEY,
  user_id         CHAR(36)        NOT NULL,
  meal_id         CHAR(36)        NOT NULL,
  photo_id        CHAR(36)        NOT NULL,
  meal_type       VARCHAR(32)     NOT NULL,
  food_names      JSON            NOT NULL,
  total_min       INT             NOT NULL DEFAULT 0,
  total_max       INT             NOT NULL DEFAULT 0,
  total_avg       INT             NOT NULL DEFAULT 0,
  protein         DOUBLE          NULL,
  carbs           DOUBLE          NULL,
  fat             DOUBLE          NULL,
  status          ENUM('active','hidden','removed') NOT NULL DEFAULT 'active',
  posted_at       DATETIME        NOT NULL,
  updated_at      DATETIME        NOT NULL,
  deleted_at      DATETIME        NULL,
  UNIQUE KEY uniq_wall_user_meal (user_id, meal_id),
  KEY idx_wall_status_posted (status, posted_at),
  KEY idx_wall_user_status (user_id, status),
  CONSTRAINT fk_wall_posts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_wall_posts_meal FOREIGN KEY (meal_id) REFERENCES meals(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE wall_post_likes (
  post_id         CHAR(36)        NOT NULL,
  user_id         CHAR(36)        NOT NULL,
  created_at      DATETIME        NOT NULL,
  PRIMARY KEY (post_id, user_id),
  KEY idx_wall_likes_user (user_id),
  KEY idx_wall_likes_recent (created_at),
  CONSTRAINT fk_wall_likes_post FOREIGN KEY (post_id) REFERENCES public_wall_posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_wall_likes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE wall_post_saves (
  post_id         CHAR(36)        NOT NULL,
  user_id         CHAR(36)        NOT NULL,
  created_at      DATETIME        NOT NULL,
  PRIMARY KEY (post_id, user_id),
  KEY idx_wall_saves_user (user_id),
  KEY idx_wall_saves_recent (created_at),
  CONSTRAINT fk_wall_saves_post FOREIGN KEY (post_id) REFERENCES public_wall_posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_wall_saves_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE wall_post_reports (
  id                    CHAR(36)        NOT NULL PRIMARY KEY,
  post_id               CHAR(36)        NOT NULL,
  reporter_user_id      CHAR(36)        NOT NULL,
  reason                ENUM('offensive_content','non_food_image','privacy_concern','spam','other') NOT NULL,
  details               VARCHAR(500)    NULL,
  status                ENUM('open','reviewed','dismissed') NOT NULL DEFAULT 'open',
  created_at            DATETIME        NOT NULL,
  UNIQUE KEY uniq_wall_reporter_post (post_id, reporter_user_id),
  KEY idx_wall_reports_reporter (reporter_user_id),
  CONSTRAINT fk_wall_reports_post FOREIGN KEY (post_id) REFERENCES public_wall_posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_wall_reports_user FOREIGN KEY (reporter_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE wall_user_blocks (
  blocker_user_id       CHAR(36)        NOT NULL,
  blocked_user_id       CHAR(36)        NOT NULL,
  created_at            DATETIME        NOT NULL,
  PRIMARY KEY (blocker_user_id, blocked_user_id),
  KEY idx_wall_blocks_blocked (blocked_user_id),
  CONSTRAINT fk_wall_blocks_blocker FOREIGN KEY (blocker_user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_wall_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE saved_foods (
  id                      CHAR(36)        NOT NULL PRIMARY KEY,
  user_id                 CHAR(36)        NOT NULL,
  name                    VARCHAR(255)    NOT NULL,
  cal_per_100g            DOUBLE          NOT NULL,
  protein                 DOUBLE          NULL,
  carbs                   DOUBLE          NULL,
  fat                     DOUBLE          NULL,
  fiber                   DOUBLE          NULL,
  sodium                  DOUBLE          NULL,
  default_serving_g       DOUBLE          NOT NULL DEFAULT 100,
  default_serving_label   VARCHAR(64)     NOT NULL DEFAULT '100 g',
  search_count            INT             NOT NULL DEFAULT 0,
  is_from_ai              TINYINT(1)      NOT NULL DEFAULT 0,
  date_added              DATETIME        NOT NULL,
  updated_at              DATETIME        NOT NULL,
  deleted_at              DATETIME        NULL,
  KEY idx_user_updated (user_id, updated_at),
  CONSTRAINT fk_saved_foods_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_settings (
  user_id                      CHAR(36)    NOT NULL PRIMARY KEY,
  daily_calorie_goal           INT         NOT NULL DEFAULT 2000,
  show_calorie_range           TINYINT(1)  NOT NULL DEFAULT 1,
  has_completed_onboarding     TINYINT(1)  NOT NULL DEFAULT 0,
  updated_at                   DATETIME    NOT NULL,
  CONSTRAINT fk_settings_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE refresh_tokens (
  token_hash      CHAR(64)        NOT NULL PRIMARY KEY,
  user_id         CHAR(36)        NOT NULL,
  issued_at       DATETIME        NOT NULL,
  expires_at      DATETIME        NOT NULL,
  revoked_at      DATETIME        NULL,
  KEY idx_user (user_id),
  CONSTRAINT fk_refresh_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Lightweight IP-based rate limit table for login.
CREATE TABLE auth_rate_limit (
  ip              VARCHAR(64)     NOT NULL,
  window_start    DATETIME        NOT NULL,
  attempts        INT             NOT NULL DEFAULT 0,
  PRIMARY KEY (ip, window_start)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
