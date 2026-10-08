// Drafts plain-English news summaries for the Education tab's news box.
//
// Reads enabled feeds from `news_sources`, skips items already seen, asks
// Claude to judge relevance and write a short summary, and saves each one
// to `articles` as kind 'news', status 'in_review'. Nothing is published:
// a Reviewer checks every draft against its source in Directus first.
// Items judged not relevant are saved as 'archived' so they aren't
// re-assessed on the next run.
//
// Secrets (Supabase > Edge Functions > Secrets):
//   ANTHROPIC_API_KEY  - Claude API key
//   CRON_SECRET        - shared secret the scheduler sends as x-cron-secret
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import Anthropic from "npm:@anthropic-ai/sdk@0.128.0";
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { type FeedItem, parseFeed } from "./feed.ts";

const MODEL = "claude-opus-5-5";
const MAX_ITEMS_PER_RUN = 5;
const MAX_ITEM_AGE_DAYS = 3;
const FEED_TIMEOUT_MS = 15_000;

const SYSTEM_PROMPT = `You write news summaries for Walkies, a UK app that \
helps women walk more and learn about their health. Readers are adults in the \
UK with no medical training.

For each news item you are given the headline and the publisher's own short \
description. Work only from that text: do not add facts, figures, names or \
claims that are not in it. If the description is too thin to summarise \
accurately, say less rather than guess.

Decide first whether the item is relevant: women's health, menstrual health, \
pregnancy, menopause, physical activity, walking, sleep, mental wellbeing, or \
UK health services for women. General politics, celebrity news, product \
promotions and items with no health content are not relevant.

When relevant, write:
- title: a clear, calm headline in British English, at most 12 words, no clickbait.
- summary: one or two sentences, at most 45 words, saying what happened and why it matters.
- body: 100 to 180 words of Markdown in short paragraphs. Explain the news in \
plain English, attribute claims to the source ("the report says"), and do not \
give personal medical advice or tell readers to start, stop or change any \
treatment. Do not add a disclaimer; the app shows one.

When not relevant, set relevant to false and leave the other fields as empty strings.`;

const DRAFT_SCHEMA = {
  type: "object",
  properties: {
    relevant: { type: "boolean" },
    title: { type: "string" },
    summary: { type: "string" },
    body: { type: "string" },
  },
  required: ["relevant", "title", "summary", "body"],
  additionalProperties: false,
};

interface Draft {
  relevant: boolean;
  title: string;
  summary: string;
  body: string;
}

interface NewsSource {
  name: string;
  feed_url: string;
}

const anthropic = new Anthropic(); // reads ANTHROPIC_API_KEY
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

async function fetchFeed(source: NewsSource): Promise<FeedItem[]> {
  const response = await fetch(source.feed_url, {
    headers: { "user-agent": "WalkiesNewsBot/1.0" },
    signal: AbortSignal.timeout(FEED_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return parseFeed(await response.text());
}

/** Returns the draft, or null if Claude declined or returned nothing usable. */
async function draftSummary(source: NewsSource, item: FeedItem): Promise<Draft | null> {
  const response = await anthropic.beta.messages.create({
    model: MODEL,
    max_tokens: 16000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: {
      effort: "medium",
      format: { type: "json_schema", schema: DRAFT_SCHEMA },
    },
    system: SYSTEM_PROMPT,
    messages: [{
      role: "user",
      content: `Publisher: ${source.name}\nHeadline: ${item.title}\n` +
        `Description: ${item.description || "(none)"}`,
    }],
  });

  if (response.stop_reason === "refusal") {
    console.warn(`Declined: ${item.link} (${response.stop_details?.category})`);
    return null;
  }
  if (response.stop_reason === "max_tokens") {
    console.warn(`Truncated: ${item.link}`);
    return null;
  }
  const text = response.content
    .filter((block) => block.type === "text")
    .map((block) => block.text)
    .join("");
  try {
    return JSON.parse(text) as Draft;
  } catch {
    console.warn(`Unparseable draft for ${item.link}`);
    return null;
  }
}

async function run(): Promise<Record<string, number>> {
  const counts = { feeds: 0, feedErrors: 0, considered: 0, drafted: 0, archived: 0, skipped: 0 };

  const { data: sources, error } = await supabase
    .from("news_sources")
    .select("name, feed_url")
    .eq("enabled", true);
  if (error) throw error;

  const cutoff = Date.now() - MAX_ITEM_AGE_DAYS * 24 * 60 * 60 * 1000;
  const candidates: { source: NewsSource; item: FeedItem }[] = [];
  for (const source of (sources ?? []) as NewsSource[]) {
    try {
      const items = await fetchFeed(source);
      counts.feeds++;
      for (const item of items) {
        if (item.published && item.published.getTime() < cutoff) continue;
        candidates.push({ source, item });
      }
    } catch (e) {
      counts.feedErrors++;
      console.error(`Feed failed: ${source.feed_url}: ${e}`);
    }
  }
  if (candidates.length === 0) return counts;

  // Drop items already drafted (or archived) on an earlier run
  const { data: existing, error: existingError } = await supabase
    .from("articles")
    .select("source_url")
    .in("source_url", candidates.map((c) => c.item.link));
  if (existingError) throw existingError;
  const seen = new Set((existing ?? []).map((row) => row.source_url as string));

  const fresh = candidates
    .filter((c) => !seen.has(c.item.link))
    .filter((c, i, all) => all.findIndex((o) => o.item.link === c.item.link) === i)
    .sort((a, b) => (b.item.published?.getTime() ?? 0) - (a.item.published?.getTime() ?? 0))
    .slice(0, MAX_ITEMS_PER_RUN);

  // Draft in parallel to stay well inside the function's time limit
  const results = await Promise.allSettled(
    fresh.map(({ source, item }) => draftSummary(source, item)),
  );

  for (const [i, result] of results.entries()) {
    const { source, item } = fresh[i];
    counts.considered++;
    if (result.status === "rejected") {
      // Leave it unrecorded so the next run tries again
      console.error(`Drafting failed for ${item.link}: ${result.reason}`);
      counts.skipped++;
      continue;
    }
    const draft = result.value;
    if (!draft) {
      counts.skipped++;
      continue;
    }

    const relevant = draft.relevant && draft.title.trim() !== "";
    const { error: insertError } = await supabase.from("articles").insert({
      kind: "news",
      status: relevant ? "in_review" : "archived",
      title: relevant ? draft.title.trim() : item.title,
      summary: relevant ? draft.summary.trim() : null,
      body: relevant ? draft.body.trim() : null,
      source_name: source.name,
      source_url: item.link,
      publish_at: null,
      is_ai_drafted: true,
    });
    if (insertError) {
      console.error(`Save failed for ${item.link}: ${insertError.message}`);
      counts.skipped++;
    } else if (relevant) {
      counts.drafted++;
    } else {
      counts.archived++;
    }
  }
  return counts;
}

Deno.serve(async (request) => {
  const secret = Deno.env.get("CRON_SECRET");
  if (!secret || request.headers.get("x-cron-secret") !== secret) {
    return new Response("Forbidden", { status: 403 });
  }
  try {
    const counts = await run();
    return Response.json(counts);
  } catch (e) {
    // Supabase errors are plain objects, not Error instances
    const message = e instanceof Error
      ? e.message
      : (e as { message?: string })?.message ?? JSON.stringify(e);
    console.error(message);
    return Response.json({ error: message }, { status: 500 });
  }
});
