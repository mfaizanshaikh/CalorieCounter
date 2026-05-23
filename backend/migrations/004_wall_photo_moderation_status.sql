-- Add a non-public holding state for wall posts awaiting photo moderation.

ALTER TABLE public_wall_posts
  MODIFY status ENUM('active','pending_review','hidden','removed') NOT NULL DEFAULT 'pending_review';
