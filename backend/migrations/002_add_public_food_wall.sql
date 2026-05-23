-- Public Food Wall V1
-- Adds opt-in public meal posts, likes, reports, and block relationships.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS public_wall_posts (
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

CREATE TABLE IF NOT EXISTS wall_post_likes (
  post_id         CHAR(36)        NOT NULL,
  user_id         CHAR(36)        NOT NULL,
  created_at      DATETIME        NOT NULL,
  PRIMARY KEY (post_id, user_id),
  KEY idx_wall_likes_user (user_id),
  KEY idx_wall_likes_recent (created_at),
  CONSTRAINT fk_wall_likes_post FOREIGN KEY (post_id) REFERENCES public_wall_posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_wall_likes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS wall_post_reports (
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

CREATE TABLE IF NOT EXISTS wall_user_blocks (
  blocker_user_id       CHAR(36)        NOT NULL,
  blocked_user_id       CHAR(36)        NOT NULL,
  created_at            DATETIME        NOT NULL,
  PRIMARY KEY (blocker_user_id, blocked_user_id),
  KEY idx_wall_blocks_blocked (blocked_user_id),
  CONSTRAINT fk_wall_blocks_blocker FOREIGN KEY (blocker_user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_wall_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
