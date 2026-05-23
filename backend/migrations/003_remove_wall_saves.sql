-- Remove wall bookmark/save support.
-- Safe to run even if the table was never created.

DROP TABLE IF EXISTS wall_post_saves;
