# draft-news

Once a day, reads the RSS/Atom feeds listed in the `news_sources` table and
uses Claude to draft short plain-English summaries of relevant
women's-health news. Drafts land in **Directus > Articles** with kind `news`,
status `in_review` and **Is AI drafted** ticked. Nothing reaches the app
until a Reviewer checks the draft against its source and publishes it.

Each run handles at most 5 new items from the last 3 days. Items Claude
judges not relevant are saved as `archived` so they aren't checked again.

## Set up

1. **Add feeds.** In Directus, **News Sources > +**: a name (shown as
   "Summary of ...") and the feed URL. Use publishers whose terms allow
   summarising with a link back.

2. **Secrets.** Supabase > Edge Functions > Secrets:
   - `ANTHROPIC_API_KEY`: from console.anthropic.com
   - `CRON_SECRET`: any long random string (`openssl rand -hex 32`)

3. **Deploy** (needs the Supabase CLI, `npm i -g supabase`):

   ```sh
   cd walkies
   supabase login
   supabase functions deploy draft-news --project-ref cbanimdilwtfmouyfumr --no-verify-jwt
   ```

   `--no-verify-jwt` is deliberate: the function checks `CRON_SECRET` instead.

4. **Schedule.** Supabase > Database > Extensions: enable `pg_cron` and
   `pg_net`. Then in the SQL Editor (put the same secret as step 2):

   ```sql
   select vault.create_secret('PASTE_CRON_SECRET_HERE', 'draft_news_cron_secret');

   select cron.schedule(
     'draft-news',
     '17 6 * * *',  -- 06:17 UTC daily
     $$
     select net.http_post(
       url := 'https://cbanimdilwtfmouyfumr.supabase.co/functions/v1/draft-news',
       headers := jsonb_build_object(
         'content-type', 'application/json',
         'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets
                           where name = 'draft_news_cron_secret')
       ),
       body := '{}'::jsonb,
       timeout_milliseconds := 150000
     );
     $$
   );
   ```

5. **Try it now** instead of waiting:

   ```sh
   curl -X POST https://cbanimdilwtfmouyfumr.supabase.co/functions/v1/draft-news \
     -H "x-cron-secret: $CRON_SECRET"
   ```

   It replies with counts, e.g. `{"feeds":2,"considered":5,"drafted":3,...}`.

## Tests

```sh
deno test supabase/functions/draft-news/feed_test.ts
```
