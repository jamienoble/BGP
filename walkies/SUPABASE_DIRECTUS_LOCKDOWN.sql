-- Run in the Supabase SQL Editor AFTER Directus has started once,
-- and again after each Directus upgrade.
--
-- Directus creates its own tables (directus_users, directus_files, ...)
-- in the public schema. Supabase exposes the public schema through its
-- API, so without this those tables (including staff password hashes)
-- could be readable by app users. Directus itself connects as the table
-- owner and is unaffected.

DO $$
DECLARE
  t record;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public' AND tablename LIKE 'directus\_%'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t.tablename);
  END LOOP;
END $$;

-- news_sources is staff-only: no app access at all
REVOKE ALL ON public.news_sources FROM anon, authenticated;
