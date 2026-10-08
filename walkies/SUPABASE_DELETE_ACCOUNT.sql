-- In-app account deletion (required by Google Play for apps with sign-up).
-- Run this once in the Supabase SQL Editor.
--
-- Deleting the auth user removes their step_goals, daily_steps and
-- app_locks rows through the ON DELETE CASCADE foreign keys.

CREATE OR REPLACE FUNCTION public.delete_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_user() TO authenticated;
