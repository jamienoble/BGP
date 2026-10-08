-- Content (Education tab) and Community tables
-- Run once in the Supabase SQL Editor. Safe to re-run.
--
-- Access model:
--   * The app (signed-in users) reads published content and visible
--     community posts through row level security.
--   * Staff edit everything through Directus, which connects as the
--     database owner and so is not limited by these policies. Directus
--     roles decide what each staff member may change.
--   * Deleting an account (delete_user()) removes the user's posts,
--     comments, reactions, reports, blocks and views via ON DELETE CASCADE.

BEGIN;

-- =====================================================================
-- Shared helpers
-- =====================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- =====================================================================
-- Content
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.content_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  sort integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- kind: 'article' for evergreen pieces, 'news' for the news box.
-- status: draft -> in_review -> published (or archived).
-- cover_image: Directus file id (shown via the CMS /assets/ URL) or a full URL.
CREATE TABLE IF NOT EXISTS public.articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL DEFAULT 'article' CHECK (kind IN ('article', 'news')),
  title text NOT NULL,
  summary text,
  body text,                       -- Markdown
  cover_image text,
  category_id uuid REFERENCES public.content_categories(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'in_review', 'published', 'archived')),
  publish_at timestamptz,
  author_name text,
  reviewed_by text,
  source_name text,
  source_url text UNIQUE,          -- set for news; also stops duplicate drafts
  is_ai_drafted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- playback_url: the HLS (.m3u8) URL from the video host (Bunny Stream,
-- Cloudflare Stream, Mux) or a direct .mp4 URL.
CREATE TABLE IF NOT EXISTS public.videos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  summary text,
  playback_url text NOT NULL,
  thumbnail_image text,
  duration_seconds integer CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  category_id uuid REFERENCES public.content_categories(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'in_review', 'published', 'archived')),
  publish_at timestamptz,
  presenter_name text,
  reviewed_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Per-user progress ("continue watching", basic view statistics)
CREATE TABLE IF NOT EXISTS public.content_views (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('article', 'video')),
  content_id uuid NOT NULL,
  progress_seconds integer NOT NULL DEFAULT 0,
  completed boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, content_type, content_id)
);

-- RSS/Atom feeds the news drafting function reads
CREATE TABLE IF NOT EXISTS public.news_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  feed_url text NOT NULL UNIQUE,
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS articles_feed_idx
  ON public.articles (status, kind, publish_at DESC);
CREATE INDEX IF NOT EXISTS videos_feed_idx
  ON public.videos (status, publish_at DESC);

DROP TRIGGER IF EXISTS articles_updated_at ON public.articles;
CREATE TRIGGER articles_updated_at BEFORE UPDATE ON public.articles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
DROP TRIGGER IF EXISTS videos_updated_at ON public.videos;
CREATE TRIGGER videos_updated_at BEFORE UPDATE ON public.videos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.content_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_sources ENABLE ROW LEVEL SECURITY;  -- no app access

DROP POLICY IF EXISTS "Categories are readable" ON public.content_categories;
CREATE POLICY "Categories are readable" ON public.content_categories
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Published articles are readable" ON public.articles;
CREATE POLICY "Published articles are readable" ON public.articles
  FOR SELECT TO authenticated
  USING (status = 'published' AND (publish_at IS NULL OR publish_at <= now()));

DROP POLICY IF EXISTS "Published videos are readable" ON public.videos;
CREATE POLICY "Published videos are readable" ON public.videos
  FOR SELECT TO authenticated
  USING (status = 'published' AND (publish_at IS NULL OR publish_at <= now()));

DROP POLICY IF EXISTS "Users manage their own views" ON public.content_views;
CREATE POLICY "Users manage their own views" ON public.content_views
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =====================================================================
-- Community
-- =====================================================================

-- Public community identity, separate from the private user_profiles
CREATE TABLE IF NOT EXISTS public.community_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL
    CHECK (char_length(btrim(display_name)) BETWEEN 2 AND 30),
  confirmed_adult_at timestamptz NOT NULL,
  accepted_rules_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.community_topics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  sort integer NOT NULL DEFAULT 0,
  is_locked boolean NOT NULL DEFAULT false,   -- read-only (e.g. announcements)
  created_at timestamptz NOT NULL DEFAULT now()
);

-- status: visible, hidden (auto-hidden after reports, awaiting a
-- moderator) or removed (by a moderator)
CREATE TABLE IF NOT EXISTS public.community_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id uuid NOT NULL REFERENCES public.community_topics(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 5000),
  status text NOT NULL DEFAULT 'visible'
    CHECK (status IN ('visible', 'hidden', 'removed')),
  report_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  edited_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.community_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 2000),
  status text NOT NULL DEFAULT 'visible'
    CHECK (status IN ('visible', 'hidden', 'removed')),
  report_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.community_reactions (
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.community_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id uuid REFERENCES public.community_posts(id) ON DELETE CASCADE,
  comment_id uuid REFERENCES public.community_comments(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (reason IN (
    'harassment', 'hate', 'self_harm', 'misinformation', 'spam',
    'sexual', 'illegal', 'other'
  )),
  details text CHECK (details IS NULL OR char_length(details) <= 1000),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'actioned', 'dismissed')),
  resolved_by text,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((post_id IS NULL) <> (comment_id IS NULL)),
  UNIQUE (reporter_id, post_id),
  UNIQUE (reporter_id, comment_id)
);

CREATE TABLE IF NOT EXISTS public.community_blocks (
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

-- Set by moderators in Directus. banned_until NULL = permanent.
CREATE TABLE IF NOT EXISTS public.community_restrictions (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  banned_until timestamptz,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS community_posts_feed_idx
  ON public.community_posts (topic_id, created_at DESC);
CREATE INDEX IF NOT EXISTS community_posts_author_idx
  ON public.community_posts (author_id);
CREATE INDEX IF NOT EXISTS community_comments_post_idx
  ON public.community_comments (post_id, created_at);
CREATE INDEX IF NOT EXISTS community_reports_open_idx
  ON public.community_reports (status, created_at);

-- Can the current user post? (profile set up, not restricted)
CREATE OR REPLACE FUNCTION public.community_can_post()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_profiles p WHERE p.user_id = auth.uid()
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.community_restrictions r
    WHERE r.user_id = auth.uid()
      AND (r.banned_until IS NULL OR r.banned_until > now())
  );
$$;

-- Has the current user blocked this author?
CREATE OR REPLACE FUNCTION public.community_is_blocked(author uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_blocks b
    WHERE b.blocker_id = auth.uid() AND b.blocked_id = author
  );
$$;

-- Rate limits: 10 posts and 60 comments per hour per user
CREATE OR REPLACE FUNCTION public.community_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  recent integer;
BEGIN
  IF TG_TABLE_NAME = 'community_posts' THEN
    SELECT count(*) INTO recent FROM public.community_posts
      WHERE author_id = NEW.author_id AND created_at > now() - interval '1 hour';
    IF recent >= 10 THEN
      RAISE EXCEPTION 'rate_limited' USING ERRCODE = 'P0001';
    END IF;
  ELSE
    SELECT count(*) INTO recent FROM public.community_comments
      WHERE author_id = NEW.author_id AND created_at > now() - interval '1 hour';
    IF recent >= 60 THEN
      RAISE EXCEPTION 'rate_limited' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS community_posts_rate_limit ON public.community_posts;
CREATE TRIGGER community_posts_rate_limit BEFORE INSERT ON public.community_posts
  FOR EACH ROW EXECUTE FUNCTION public.community_rate_limit();
DROP TRIGGER IF EXISTS community_comments_rate_limit ON public.community_comments;
CREATE TRIGGER community_comments_rate_limit BEFORE INSERT ON public.community_comments
  FOR EACH ROW EXECUTE FUNCTION public.community_rate_limit();

-- Each report bumps the target's count; 3 reports hide it until a
-- moderator reviews it in Directus
CREATE OR REPLACE FUNCTION public.community_apply_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.post_id IS NOT NULL THEN
    UPDATE public.community_posts
      SET report_count = report_count + 1,
          status = CASE WHEN report_count + 1 >= 3 AND status = 'visible'
                        THEN 'hidden' ELSE status END
      WHERE id = NEW.post_id;
  ELSE
    UPDATE public.community_comments
      SET report_count = report_count + 1,
          status = CASE WHEN report_count + 1 >= 3 AND status = 'visible'
                        THEN 'hidden' ELSE status END
      WHERE id = NEW.comment_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS community_reports_apply ON public.community_reports;
CREATE TRIGGER community_reports_apply AFTER INSERT ON public.community_reports
  FOR EACH ROW EXECUTE FUNCTION public.community_apply_report();

ALTER TABLE public.community_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_restrictions ENABLE ROW LEVEL SECURITY;

-- Profiles: everyone signed in can see display names; you manage your own
DROP POLICY IF EXISTS "Community profiles are readable" ON public.community_profiles;
CREATE POLICY "Community profiles are readable" ON public.community_profiles
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Users create their community profile" ON public.community_profiles;
CREATE POLICY "Users create their community profile" ON public.community_profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users update their community profile" ON public.community_profiles;
CREATE POLICY "Users update their community profile" ON public.community_profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Topics are readable" ON public.community_topics;
CREATE POLICY "Topics are readable" ON public.community_topics
  FOR SELECT TO authenticated USING (true);

-- Posts: visible ones from people you haven't blocked, plus your own
-- unless a moderator removed them
DROP POLICY IF EXISTS "Posts are readable" ON public.community_posts;
CREATE POLICY "Posts are readable" ON public.community_posts
  FOR SELECT TO authenticated
  USING (
    (status = 'visible' AND NOT public.community_is_blocked(author_id))
    OR (author_id = auth.uid() AND status <> 'removed')
  );
DROP POLICY IF EXISTS "Users create posts" ON public.community_posts;
CREATE POLICY "Users create posts" ON public.community_posts
  FOR INSERT TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND status = 'visible'
    AND report_count = 0
    AND public.community_can_post()
    AND NOT EXISTS (
      SELECT 1 FROM public.community_topics t
      WHERE t.id = topic_id AND t.is_locked
    )
  );
DROP POLICY IF EXISTS "Users edit their posts" ON public.community_posts;
CREATE POLICY "Users edit their posts" ON public.community_posts
  FOR UPDATE TO authenticated
  USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
DROP POLICY IF EXISTS "Users delete their posts" ON public.community_posts;
CREATE POLICY "Users delete their posts" ON public.community_posts
  FOR DELETE TO authenticated USING (author_id = auth.uid());

DROP POLICY IF EXISTS "Comments are readable" ON public.community_comments;
CREATE POLICY "Comments are readable" ON public.community_comments
  FOR SELECT TO authenticated
  USING (
    (status = 'visible' AND NOT public.community_is_blocked(author_id))
    OR (author_id = auth.uid() AND status <> 'removed')
  );
DROP POLICY IF EXISTS "Users create comments" ON public.community_comments;
CREATE POLICY "Users create comments" ON public.community_comments
  FOR INSERT TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND status = 'visible'
    AND report_count = 0
    AND public.community_can_post()
  );
DROP POLICY IF EXISTS "Users delete their comments" ON public.community_comments;
CREATE POLICY "Users delete their comments" ON public.community_comments
  FOR DELETE TO authenticated USING (author_id = auth.uid());

DROP POLICY IF EXISTS "Reactions are readable" ON public.community_reactions;
CREATE POLICY "Reactions are readable" ON public.community_reactions
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Users add their reactions" ON public.community_reactions;
CREATE POLICY "Users add their reactions" ON public.community_reactions
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Users remove their reactions" ON public.community_reactions;
CREATE POLICY "Users remove their reactions" ON public.community_reactions
  FOR DELETE TO authenticated USING (user_id = auth.uid());

-- Reports: users file them; only moderators (in Directus) read them
DROP POLICY IF EXISTS "Users file reports" ON public.community_reports;
CREATE POLICY "Users file reports" ON public.community_reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid() AND status = 'open');

DROP POLICY IF EXISTS "Users manage their blocks" ON public.community_blocks;
CREATE POLICY "Users manage their blocks" ON public.community_blocks
  FOR ALL TO authenticated
  USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());

DROP POLICY IF EXISTS "Users see their own restriction" ON public.community_restrictions;
CREATE POLICY "Users see their own restriction" ON public.community_restrictions
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Post edits may only change the text (status, counts and authorship are
-- moderator-controlled)
REVOKE UPDATE ON public.community_posts FROM authenticated, anon;
GRANT UPDATE (body, edited_at) ON public.community_posts TO authenticated;
REVOKE UPDATE ON public.community_profiles FROM authenticated, anon;
GRANT UPDATE (display_name) ON public.community_profiles TO authenticated;

-- Feed view: posts with author name and counts. security_invoker makes it
-- apply the caller's row level security on the underlying tables.
CREATE OR REPLACE VIEW public.community_post_feed
WITH (security_invoker = true) AS
SELECT
  p.id,
  p.topic_id,
  p.author_id,
  pr.display_name AS author_name,
  p.body,
  p.status,
  p.created_at,
  p.edited_at,
  (SELECT count(*) FROM public.community_comments c
     WHERE c.post_id = p.id) AS comment_count,
  (SELECT count(*) FROM public.community_reactions r
     WHERE r.post_id = p.id) AS reaction_count,
  EXISTS (SELECT 1 FROM public.community_reactions r
     WHERE r.post_id = p.id AND r.user_id = auth.uid()) AS reacted_by_me
FROM public.community_posts p
LEFT JOIN public.community_profiles pr ON pr.user_id = p.author_id;

GRANT SELECT ON public.community_post_feed TO authenticated;
REVOKE ALL ON public.community_post_feed FROM anon;

-- =====================================================================
-- Starter data (edit or remove in Directus)
-- =====================================================================

INSERT INTO public.content_categories (name, slug, sort) VALUES
  ('Movement', 'movement', 1),
  ('Menstrual health', 'menstrual-health', 2),
  ('Menopause', 'menopause', 3),
  ('Mental wellbeing', 'mental-wellbeing', 4)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.community_topics (name, slug, description, sort, is_locked) VALUES
  ('Announcements', 'announcements', 'News from the Walkies team', 0, true),
  ('Walking wins', 'walking-wins', 'Share your progress and routes', 1, false),
  ('Health chat', 'health-chat', 'Support and experiences. Not medical advice.', 2, false),
  ('Introductions', 'introductions', 'Say hello', 3, false)
ON CONFLICT (slug) DO NOTHING;

COMMIT;
