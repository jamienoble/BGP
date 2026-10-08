-- Access-rule tests for the content and community tables. Each check
-- raises an exception (failing the run) if a rule doesn't hold.
\set ON_ERROR_STOP 1
SET client_min_messages = warning;

CREATE FUNCTION pg_temp.as_user(u text) RETURNS void LANGUAGE sql AS
  $$ SELECT set_config('request.jwt.claim.sub', u, false) $$;

CREATE FUNCTION pg_temp.expect_error(stmt text, label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE stmt;
  EXCEPTION WHEN others THEN
    RETURN;
  END;
  RAISE EXCEPTION 'FAIL: % (should have been refused)', label;
END $$;

CREATE FUNCTION pg_temp.expect_ok(stmt text, label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE stmt;
EXCEPTION WHEN others THEN
  RAISE EXCEPTION 'FAIL: % (refused: %)', label, SQLERRM;
END $$;

CREATE FUNCTION pg_temp.expect_count(query text, expected bigint, label text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  actual bigint;
BEGIN
  EXECUTE 'SELECT count(*) FROM (' || query || ') q' INTO actual;
  IF actual <> expected THEN
    RAISE EXCEPTION 'FAIL: % (expected %, got %)', label, expected, actual;
  END IF;
END $$;

-- Users A, B, C, D and some content
INSERT INTO auth.users(id) VALUES
  ('00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000b'),
  ('00000000-0000-0000-0000-00000000000c'),
  ('00000000-0000-0000-0000-00000000000d');
INSERT INTO articles(title, status) VALUES ('draft', 'draft');
INSERT INTO articles(title, status, publish_at) VALUES
  ('live', 'published', now() - interval '1 day'),
  ('future', 'published', now() + interval '1 day');

SET ROLE authenticated;

-- Content -----------------------------------------------------------
SELECT pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
SELECT pg_temp.expect_count($$SELECT 1 FROM articles$$, 1,
  'only published, due articles are visible');
SELECT pg_temp.expect_error($$INSERT INTO articles(title) VALUES ('x')$$,
  'app users cannot create articles');

-- Community: joining and posting ------------------------------------
SELECT pg_temp.expect_error($$
  INSERT INTO community_posts(topic_id, author_id, body)
  SELECT id, '00000000-0000-0000-0000-00000000000a', 'hi'
  FROM community_topics WHERE slug = 'walking-wins'$$,
  'posting needs a community profile');

SELECT pg_temp.expect_ok($$
  INSERT INTO community_profiles(user_id, display_name, confirmed_adult_at, accepted_rules_at)
  VALUES ('00000000-0000-0000-0000-00000000000a', 'Alice', now(), now())$$,
  'joining the community');

SELECT pg_temp.expect_ok($$
  INSERT INTO community_posts(topic_id, author_id, body)
  SELECT id, '00000000-0000-0000-0000-00000000000a', 'hello walkers'
  FROM community_topics WHERE slug = 'walking-wins'$$,
  'posting with a profile');

SELECT pg_temp.expect_error($$
  INSERT INTO community_posts(topic_id, author_id, body)
  SELECT id, '00000000-0000-0000-0000-00000000000a', 'x'
  FROM community_topics WHERE slug = 'announcements'$$,
  'posting in a locked topic');

SELECT pg_temp.expect_error($$
  INSERT INTO community_posts(topic_id, author_id, body)
  SELECT id, '00000000-0000-0000-0000-00000000000b', 'spoof'
  FROM community_topics WHERE slug = 'walking-wins'$$,
  'posting as someone else');

SELECT pg_temp.expect_error($$UPDATE community_posts SET status = 'visible', report_count = 0$$,
  'authors cannot change moderation fields');

SELECT pg_temp.expect_ok($$UPDATE community_posts SET body = 'hello walkers!', edited_at = now()$$,
  'authors can edit their text');

-- Another member ------------------------------------------------------
SELECT pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
SELECT pg_temp.expect_ok($$
  INSERT INTO community_profiles(user_id, display_name, confirmed_adult_at, accepted_rules_at)
  VALUES ('00000000-0000-0000-0000-00000000000b', 'Bea', now(), now())$$,
  'second member joins');

UPDATE community_posts SET body = 'hacked';
SELECT pg_temp.expect_count($$SELECT 1 FROM community_posts WHERE body = 'hacked'$$, 0,
  'members cannot edit others'' posts');

INSERT INTO community_reactions(post_id, user_id)
  SELECT id, '00000000-0000-0000-0000-00000000000b' FROM community_posts;
INSERT INTO community_comments(post_id, author_id, body)
  SELECT id, '00000000-0000-0000-0000-00000000000b', 'nice' FROM community_posts;
SELECT pg_temp.expect_count($$
  SELECT 1 FROM community_post_feed
  WHERE author_name = 'Alice' AND comment_count = 1 AND reaction_count = 1 AND reacted_by_me$$,
  1, 'feed view shows names and counts');

INSERT INTO community_reports(reporter_id, post_id, reason)
  SELECT '00000000-0000-0000-0000-00000000000b', id, 'spam' FROM community_posts;
SELECT pg_temp.expect_count($$SELECT 1 FROM community_reports$$, 0,
  'members cannot read reports');
SELECT pg_temp.expect_error($$
  INSERT INTO community_reports(reporter_id, post_id, reason)
  SELECT '00000000-0000-0000-0000-00000000000b', id, 'spam' FROM community_posts$$,
  'reporting the same post twice');

INSERT INTO community_blocks VALUES
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');
SELECT pg_temp.expect_count($$SELECT 1 FROM community_post_feed$$, 0,
  'blocked authors disappear');

-- Reports hide a post at three ---------------------------------------
SELECT pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
INSERT INTO community_reports(reporter_id, post_id, reason)
  SELECT '00000000-0000-0000-0000-00000000000c', id, 'spam' FROM community_posts;
SELECT pg_temp.expect_count($$SELECT 1 FROM community_posts$$, 1,
  'still visible after two reports');

SELECT pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
INSERT INTO community_reports(reporter_id, post_id, reason)
  SELECT '00000000-0000-0000-0000-00000000000d', id, 'spam' FROM community_posts;
SELECT pg_temp.expect_count($$SELECT 1 FROM community_posts$$, 0,
  'hidden after three reports');

SELECT pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
SELECT pg_temp.expect_count($$SELECT 1 FROM community_posts WHERE status = 'hidden'$$, 1,
  'author still sees their hidden post');

-- Rate limit ----------------------------------------------------------
SELECT pg_temp.expect_error($rl$
  DO $do$ BEGIN
    FOR i IN 1..10 LOOP
      INSERT INTO community_posts(topic_id, author_id, body)
      SELECT id, '00000000-0000-0000-0000-00000000000a', 'p' || i
      FROM community_topics WHERE slug = 'walking-wins';
    END LOOP;
  END $do$ $rl$,
  'more than 10 posts an hour');

-- Signed-out access ----------------------------------------------------
RESET ROLE;
SET ROLE anon;
SELECT pg_temp.expect_count($$SELECT 1 FROM community_posts$$, 0, 'signed out: no posts');
SELECT pg_temp.expect_count($$SELECT 1 FROM articles$$, 0, 'signed out: no articles');

-- Account deletion removes the user's community data -----------------
RESET ROLE;
SET ROLE authenticated;
SELECT pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
SELECT delete_user();
RESET ROLE;
SELECT pg_temp.expect_count($$
  SELECT 1 FROM community_posts WHERE author_id = '00000000-0000-0000-0000-00000000000a'
  UNION ALL
  SELECT 1 FROM community_profiles WHERE user_id = '00000000-0000-0000-0000-00000000000a'
  UNION ALL
  SELECT 1 FROM auth.users WHERE id = '00000000-0000-0000-0000-00000000000a'$$,
  0, 'deleting an account removes its data');

\echo 'All access-rule tests passed'
