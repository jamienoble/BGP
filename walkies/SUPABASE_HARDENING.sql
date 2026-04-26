-- Supabase hardening script
-- Run this in Supabase SQL Editor after reviewing in your environment.

-- 1) Ensure RLS is mandatory (cannot be bypassed by table owner role usage)
ALTER TABLE step_goals FORCE ROW LEVEL SECURITY;
ALTER TABLE daily_steps FORCE ROW LEVEL SECURITY;
ALTER TABLE app_locks FORCE ROW LEVEL SECURITY;

-- 2) Recreate explicit authenticated-only policies for strict per-user access
DROP POLICY IF EXISTS "Users can view their own step goals" ON step_goals;
DROP POLICY IF EXISTS "Users can create their own step goals" ON step_goals;
DROP POLICY IF EXISTS "Users can update their own step goals" ON step_goals;
DROP POLICY IF EXISTS "Users can delete their own step goals" ON step_goals;

CREATE POLICY "Users can view their own step goals"
  ON step_goals FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own step goals"
  ON step_goals FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own step goals"
  ON step_goals FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own step goals"
  ON step_goals FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view their own daily steps" ON daily_steps;
DROP POLICY IF EXISTS "Users can create their own daily steps" ON daily_steps;
DROP POLICY IF EXISTS "Users can update their own daily steps" ON daily_steps;
DROP POLICY IF EXISTS "Users can delete their own daily steps" ON daily_steps;

CREATE POLICY "Users can view their own daily steps"
  ON daily_steps FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own daily steps"
  ON daily_steps FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own daily steps"
  ON daily_steps FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own daily steps"
  ON daily_steps FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view their own app locks" ON app_locks;
DROP POLICY IF EXISTS "Users can create their own app locks" ON app_locks;
DROP POLICY IF EXISTS "Users can update their own app locks" ON app_locks;
DROP POLICY IF EXISTS "Users can delete their own app locks" ON app_locks;

CREATE POLICY "Users can view their own app locks"
  ON app_locks FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own app locks"
  ON app_locks FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own app locks"
  ON app_locks FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own app locks"
  ON app_locks FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
