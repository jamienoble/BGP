# Walkies content and moderation (Directus)

Staff manage the Education tab and moderate the Community tab in
**Directus**, a web admin app that sits on the same Supabase database the
app uses. No code is needed to publish.

- Part 1 is a one-off setup for whoever runs the systems.
- Part 2 is the guide for editors and moderators.

---

## Part 1: One-off setup (admin)

### 1. Database

In the Supabase SQL Editor, run in this order (skip any already run):

1. `SUPABASE_MIGRATION_2026_10_08_content_community.sql`
2. `SUPABASE_DELETE_ACCOUNT.sql` (if not already run)

### 2. Storage bucket

Supabase > Storage > New bucket > name `cms`, **private**.

### 3. Run Directus

Try it locally first (needs Docker):

```sh
cd cms
cp .env.example .env    # fill in every value
docker compose up
```

Open http://localhost:8055 and sign in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`.

For real use, deploy the `directus/directus:11` image with the same
environment variables to a host such as Railway, Render or Fly.io, on an
address like `https://cms.yourdomain.co.uk`, and set `PUBLIC_URL` to it.

### 4. Lock Directus's own tables

After Directus has started once, run `SUPABASE_DIRECTUS_LOCKDOWN.sql` in the
Supabase SQL Editor. Re-run it after every Directus upgrade.

### 5. Tell the app where images live

In `lib/config/app_config.dart`, set `cmsBaseUrl` to the Directus address
(e.g. `https://cms.yourdomain.co.uk`) and rebuild the app.

Then in Directus: **Settings > Access Policies > Public**, give **read**
access to **Directus Files** only. This lets the app load uploaded images.

### 6. Make the forms friendly

Directus finds the tables automatically. In **Settings > Data Model**, for
each collection below, open the field and set its interface:

| Collection | Field | Interface |
|---|---|---|
| articles | `body` | Markdown |
| articles | `status` | Dropdown: draft, in_review, published, archived |
| articles | `kind` | Dropdown: article, news |
| articles | `cover_image` | Image (create a relation to Directus Files) |
| articles | `category_id` | Many to one, to content_categories, display `{{name}}` |
| videos | `status` | Dropdown as above |
| videos | `thumbnail_image` | Image |
| videos | `category_id` | Many to one, to content_categories |
| community_posts / community_comments | `status` | Dropdown: visible, hidden, removed |
| community_reports | `status` | Dropdown: open, actioned, dismissed |

Hide from non-admin roles: `daily_steps`, `step_goals`, `app_locks`,
`user_profiles`, `content_views` (these are users' private data).

### 7. Roles

Create these in **Settings > User Roles** (each with its own access policy):

| Role | Can | Cannot |
|---|---|---|
| **Editor** | Create and edit articles and videos; set status to `draft` or `in_review` | Set status to `published`; see community or user data |
| **Reviewer** | Everything Editor can, plus set `published` and `publish_at` | See user data |
| **Moderator** | Read and update community_posts, community_comments, community_reports, community_restrictions; read community_profiles | Edit content; see step data |
| **Administrator** | Everything | |

For Editor, add a **validation** rule on articles and videos so `status` must
be `draft` or `in_review`.

Invite staff from **User Directory**.

### 8. News drafting (optional)

See `supabase/functions/draft-news/README.md`. It adds AI-drafted news
summaries as `in_review` articles for a Reviewer to check.

---

## Part 2: Guide for editors and moderators

Sign in at the CMS address you were given.

### Publishing an article

1. **Content > Articles > +** (top right).
2. Fill in **Title**, a one or two sentence **Summary**, and the **Body**.
   The body supports simple formatting: `## Heading`, `- bullet`, blank lines
   between paragraphs.
3. Pick a **Category** and upload a **Cover image** (landscape, at least
   1200 px wide).
4. Leave **Kind** as `article`.
5. Set **Status** to `in_review` and **Save**.
6. A Reviewer checks it, sets **Status** to `published`, and optionally a
   **Publish at** date and time to schedule it. Nothing appears in the app
   until it is `published` *and* its publish time has passed.

To take something down, set it to `archived`.

### Publishing a video

Videos are uploaded to the video host (for example Bunny Stream), not to
Directus, so they stream smoothly on phones.

1. Upload the video in the video host's dashboard.
2. Copy its **HLS playlist URL** (ends in `.m3u8`).
3. In Directus: **Content > Videos > +**. Paste the URL into
   **Playback URL**, add a title, summary, category, thumbnail and, if you
   know it, the length in seconds.
4. Status `in_review`, Save. A Reviewer publishes it as above.

### Checking AI-drafted news

Items with **Kind** `news` and **Is AI drafted** ticked were written by the
news drafting job. Before publishing:

- Open the **Source URL** and check every claim against it.
- Fix or remove anything that reads as medical advice.
- Fill in **Reviewed by** with your name.

### Moderating the community

**Content > Community Reports**, filtered to `open`, is the queue.

For each report, open the reported post or comment, then:

- **Breaks the rules**: set the post or comment **Status** to `removed`, and
  the report to `actioned`.
- **Fine**: set the post or comment **Status** back to `visible` (three
  reports hide it automatically), and the report to `dismissed`.
- **Repeat or serious offender**: add a row in **Community Restrictions**
  for that user. Leave **Banned until** empty for a permanent ban.

Anything suggesting someone is at risk of harm, or illegal content, should
be escalated to the service owner straight away, not just removed.

### Community topics

**Content > Community Topics**. Tick **Is locked** for a read-only topic
(such as Announcements, where only staff post through Directus).
