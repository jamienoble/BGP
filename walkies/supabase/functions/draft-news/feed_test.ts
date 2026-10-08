import { assertEquals } from "jsr:@std/assert@1.0.13";
import { decodeEntities, parseFeed } from "./feed.ts";

Deno.test("parses RSS items with CDATA and encoded HTML", () => {
  const xml = `<?xml version="1.0"?><rss><channel><title>Feed</title>
    <item>
      <title><![CDATA[Menopause & work: new guidance]]></title>
      <link>https://example.org/a</link>
      <description>&lt;p&gt;Employers should &lt;b&gt;support&lt;/b&gt; staff.&lt;/p&gt;</description>
      <pubDate>Tue, 06 Oct 2026 09:00:00 GMT</pubDate>
    </item>
    <item><title>No link</title></item>
  </channel></rss>`;
  const items = parseFeed(xml);
  assertEquals(items.length, 1);
  assertEquals(items[0].title, "Menopause & work: new guidance");
  assertEquals(items[0].link, "https://example.org/a");
  assertEquals(items[0].description, "Employers should support staff.");
  assertEquals(items[0].published?.toISOString(), "2026-10-06T09:00:00.000Z");
});

Deno.test("parses Atom entries and picks the alternate link", () => {
  const xml = `<feed xmlns="http://www.w3.org/2005/Atom">
    <entry>
      <title type="html">Walking &amp;amp; sleep</title>
      <link rel="self" href="https://example.org/self"/>
      <link rel="alternate" href="https://example.org/post?a=1&amp;b=2"/>
      <summary>Short walks help.</summary>
      <updated>2026-10-05T12:00:00Z</updated>
    </entry>
  </feed>`;
  const items = parseFeed(xml);
  assertEquals(items.length, 1);
  assertEquals(items[0].title, "Walking & sleep");
  assertEquals(items[0].link, "https://example.org/post?a=1&b=2");
  assertEquals(items[0].description, "Short walks help.");
});

Deno.test("decodes numeric entities", () => {
  assertEquals(decodeEntities("it&#8217;s &#x2014; ok"), "it’s — ok");
});
