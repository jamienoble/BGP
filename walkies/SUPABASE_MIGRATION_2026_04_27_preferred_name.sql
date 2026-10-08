-- Safe migration for existing Walkies databases
-- Purpose:
--   1) Add user_profiles table for preferred greeting names
--   2) Apply strict per-user RLS for that table
--   3) Backfill profiles for existing users (best effort)
--
-- This script is idempotent and designed to avoid modifying existing
-- step_goals/daily_steps/app_locks structures or policies.

BEGIN;

-- 1) Create table if missing
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  preferred_name text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- 2) Ensure required column exists (for older/manual variants)
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS preferred_name text;

-- 3) Enable + force RLS on this table only
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles FORCE ROW LEVEL SECURITY;

-- 4) Recreate policies safely for authenticated users only
DROP POLICY IF EXISTS "Users can view their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can create their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON public.user_profiles;

CREATE POLICY "Users can view their own profile"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own profile"
  ON public.user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
  ON public.user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own profile"
  ON public.user_profiles
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- 5) Backfill profile rows for existing users if missing
--    Preferred name is seeded from auth metadata when available.
INSERT INTO public.user_profiles (user_id, preferred_name)
SELECT
  u.id,
  NULLIF((u.raw_user_meta_data ->> 'preferred_name'), '')
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1
  FROM public.user_profiles p
  WHERE p.user_id = u.id
);

COMMIT;
