-- ByteSurvivor: rename the Cosmic Coder tables/indexes created by the previous
-- branding. Run once against Supabase (SQL editor) or Render PostgreSQL:
--   psql "$DATABASE_URL" -f server/db/migrate_bytesurvivor_rename.sql
--
-- Every step is idempotent: it is skipped when the old object no longer exists or
-- when the new name is already taken. RLS policies and grants stay attached to the
-- table across a rename, so no policy/grant statements are repeated here.

DO $$
BEGIN
  IF to_regclass('public.cosmic_coder_users') IS NOT NULL
     AND to_regclass('public.bytesurvivor_users') IS NULL THEN
    EXECUTE 'ALTER TABLE public.cosmic_coder_users RENAME TO bytesurvivor_users';
  END IF;

  IF to_regclass('public.cosmic_coder_leaderboard') IS NOT NULL
     AND to_regclass('public.bytesurvivor_leaderboard') IS NULL THEN
    EXECUTE 'ALTER TABLE public.cosmic_coder_leaderboard RENAME TO bytesurvivor_leaderboard';
  END IF;

  IF to_regclass('public.cosmic_coder_progress') IS NOT NULL
     AND to_regclass('public.bytesurvivor_progress') IS NULL THEN
    EXECUTE 'ALTER TABLE public.cosmic_coder_progress RENAME TO bytesurvivor_progress';
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.cosmic_coder_users_public_key_idx') IS NOT NULL
     AND to_regclass('public.bytesurvivor_users_public_key_idx') IS NULL THEN
    EXECUTE 'ALTER INDEX public.cosmic_coder_users_public_key_idx RENAME TO bytesurvivor_users_public_key_idx';
  END IF;

  IF to_regclass('public.cosmic_coder_leaderboard_score_idx') IS NOT NULL
     AND to_regclass('public.bytesurvivor_leaderboard_score_idx') IS NULL THEN
    EXECUTE 'ALTER INDEX public.cosmic_coder_leaderboard_score_idx RENAME TO bytesurvivor_leaderboard_score_idx';
  END IF;
END $$;