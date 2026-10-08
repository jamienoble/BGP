// Minimal RSS 2.0 / Atom parser for news feeds. Feeds are small and
// well-formed enough that a regex pass avoids pulling in an XML library.

export interface FeedItem {
  title: string;
  link: string;
  description: string;
  published: Date | null;
}

const ENTITIES: Record<string, string> = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
};

export function decodeEntities(text: string): string {
  return text.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (match, code: string) => {
    if (code[0] === "#") {
      const n = code[1].toLowerCase() === "x"
        ? parseInt(code.slice(2), 16)
        : parseInt(code.slice(1), 10);
      return Number.isFinite(n) ? String.fromCodePoint(n) : match;
    }
    return ENTITIES[code.toLowerCase()] ?? match;
  });
}

/** Text content of the first <tag>, with CDATA unwrapped and HTML removed. */
function tagText(xml: string, tag: string): string {
  const match = xml.match(
    new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)</${tag}>`, "i"),
  );
  if (!match) return "";
  let text = match[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
  // Entity-encoded HTML is common in descriptions: decode, then strip tags
  text = decodeEntities(text).replace(/<[^>]+>/g, " ");
  return decodeEntities(text).replace(/\s+/g, " ").trim();
}

function atomLink(entry: string): string {
  const links = [...entry.matchAll(/<link\b([^>]*)\/?>/gi)].map((m) => m[1]);
  const pick = links.find((attrs) => /rel=["']alternate["']/i.test(attrs)) ??
    links.find((attrs) => !/rel=/i.test(attrs)) ?? links[0];
  const href = pick?.match(/href=["']([^"']+)["']/i)?.[1];
  return href ? decodeEntities(href) : "";
}

function parseDate(text: string): Date | null {
  if (!text) return null;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function parseFeed(xml: string): FeedItem[] {
  const rssItems = [...xml.matchAll(/<item\b[\s\S]*?<\/item>/gi)].map((m) => m[0]);
  if (rssItems.length > 0) {
    return rssItems
      .map((item) => ({
        title: tagText(item, "title"),
        link: tagText(item, "link") || tagText(item, "guid"),
        description: tagText(item, "description") ||
          tagText(item, "content:encoded"),
        published: parseDate(tagText(item, "pubDate") || tagText(item, "dc:date")),
      }))
      .filter((item) => item.title && item.link.startsWith("http"));
  }

  return [...xml.matchAll(/<entry\b[\s\S]*?<\/entry>/gi)]
    .map((m) => m[0])
    .map((entry) => ({
      title: tagText(entry, "title"),
      link: atomLink(entry),
      description: tagText(entry, "summary") || tagText(entry, "content"),
      published: parseDate(tagText(entry, "updated") || tagText(entry, "published")),
    }))
    .filter((item) => item.title && item.link.startsWith("http"));
}
