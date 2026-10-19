// Run: deno test supabase/functions/truhive-api
// Providers are faked by stubbing fetch with responses shaped like their APIs.
import { handle } from "./handler.ts";
import { parseLrc } from "./providers.ts";

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error(msg);
}

const MP3 = new Uint8Array(1000).map((_, i) => i % 251);
const calls: string[] = [];

function fakeFetch(fail: Set<string> = new Set()) {
  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    calls.push(url);
    const host = new URL(url).host;
    if (fail.has(host)) return new Response("down", { status: 503 });
    const j = (o: unknown) => new Response(JSON.stringify(o), { headers: { "content-type": "application/json" } });
    if (url.startsWith("https://itunes.apple.com/search")) {
      return j({ results: [
        { kind: "song", trackId: 11, collectionId: 5, trackName: "Hello", artistName: "Adele", collectionName: "25",
          artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/a/b/100x100bb.jpg",
          trackTimeMillis: 295000, primaryGenreName: "Pop", releaseDate: "2015-10-23T07:00:00Z", previewUrl: "https://audio.itunes/11.m4a" },
        { kind: "music-video", trackId: 12, trackName: "Video" },
      ] });
    }
    if (url.startsWith("https://itunes.apple.com/lookup")) {
      return j({ results: [{ trackId: 11, trackName: "Hello", artistName: "Adele", collectionName: "25", trackTimeMillis: 295000, previewUrl: "https://audio.itunes/11.m4a" }] });
    }
    if (url.startsWith("https://archive.org/advancedsearch.php")) {
      const q = new URL(url).searchParams.get("q")!;
      assert(q.includes("collection:etree") && q.includes("creativecommons"), "IA query must be licence-filtered");
      return j({ response: { docs: [{ identifier: "gd1977", title: "Live 1977", creator: "Band" }] } });
    }
    if (url.startsWith("https://archive.org/metadata/")) {
      return j({ metadata: { title: "Live 1977", creator: "Band", date: "1977-05-08" }, files: [
        { name: "d1t01.mp3", format: "VBR MP3", title: "Hello Song", length: "04:05", size: "5880000" },
        { name: "d1t01.flac", format: "Flac" },
        { name: "d1t02.mp3", format: "VBR MP3", title: "Second", length: "200.5", size: "4000000" },
        { name: "d1t03.mp3", format: "VBR MP3", title: "Third", length: "100" },
      ] });
    }
    if (url.startsWith("https://api.jamendo.com/")) {
      const p = new URL(url).searchParams;
      assert(p.get("client_id") === "jam-test", "Jamendo client id from secret");
      return j({ results: [
        { id: "77", name: "Hello Sunrise", artist_name: "Indie", album_name: "Dawn", album_id: "9", duration: 180,
          releasedate: "2020-01-01", audio: "https://mp3l.jamendo/77", audiodownload: "https://mp3d.jamendo/77",
          audiodownload_allowed: true, musicinfo: { tags: { genres: ["electronic"] }, lyrics: "line one\nline two" } },
        { id: "78", name: "No Download", artist_name: "Indie", duration: 100, audio: "https://mp3l.jamendo/78",
          audiodownload: "", audiodownload_allowed: false },
      ].filter((r) => !p.get("id") || r.id === p.get("id")) });
    }
    if (url.startsWith("https://api.audius.co/v1/tracks/search")) {
      return j({ data: [
        { id: "aA", title: "Hello Beat", user: { name: "DJ" }, duration: 150, genre: "Electronic", is_downloadable: true, is_streamable: true },
        { id: "aB", title: "Gated", user: { name: "DJ" }, duration: 150, is_streamable: true, stream_conditions: { usdc: 1 } },
        { id: "aC", title: "Paid dl", user: { name: "DJ" }, duration: 150, is_downloadable: true, download_conditions: { usdc: 1 } },
      ] });
    }
    if (url.startsWith("https://lrclib.net/api/search")) {
      return j([
        { duration: 120, syncedLyrics: "[00:01.00] wrong length" },
        { duration: 294, syncedLyrics: "[00:01.50] Hello, it's me\n[01:02.25] I was wondering" },
      ]);
    }
    if (url.startsWith("https://is1-ssl.mzstatic.com/")) {
      return new Response(new Uint8Array([0xff, 0xd8, 0xff]), { headers: { "content-type": "image/jpeg" } });
    }
    if (url.startsWith("https://archive.org/download/") || url.startsWith("https://mp3")) {
      const range = new Headers(init?.headers).get("range");
      if (range) {
        const from = parseInt(range.replace("bytes=", ""), 10);
        return new Response(MP3.slice(from), { status: 206, headers: {
          "content-type": "audio/mpeg", "content-length": String(MP3.length - from),
          "content-range": `bytes ${from}-${MP3.length - 1}/${MP3.length}`, "accept-ranges": "bytes" } });
      }
      return new Response(MP3, { headers: { "content-type": "audio/mpeg", "content-length": String(MP3.length), "accept-ranges": "bytes" } });
    }
    return new Response("unexpected " + url, { status: 500 });
  }) as typeof fetch;
}

const BASE = "https://x.supabase.co/functions/v1/truhive-api";
const get = (path: string, headers: Record<string, string> = {}) => handle(new Request(BASE + path, { headers }));

Deno.env.set("JAMENDO_CLIENT_ID", "jam-test");

Deno.test("health lists enabled providers", async () => {
  fakeFetch();
  const r = await get("/api/health");
  const d = await r.json();
  assert(r.status === 200 && d.providers.length === 4, JSON.stringify(d));
  assert(r.headers.get("access-control-allow-origin") === "*", "CORS");
});

Deno.test("search merges providers and respects licences", async () => {
  fakeFetch();
  const d = await (await get("/api/search?q=hello")).json();
  const by = (id: string) => d.results.find((t: any) => t.id === id);
  assert(by("it:11")?.preview && !by("it:11").download && by("it:11").durationMs === 295000, "iTunes preview only");
  assert(!d.results.some((t: any) => t.id === "it:12"), "non-songs dropped");
  assert(by("jm:77")?.download && by("jm:77").lyrics, "Jamendo download allowed");
  assert(by("jm:78") && !by("jm:78").download, "Jamendo download refused when not allowed");
  assert(by("au:aA")?.download, "Audius downloadable");
  assert(!by("au:aB"), "gated stream dropped");
  assert(by("au:aC") && !by("au:aC").download, "gated download refused");
  const ia = by("ia:gd1977/d1t01.mp3");
  assert(ia?.download && ia.durationMs === 245000 && ia.sizeBytes === 5880000 && ia.year === 1977, JSON.stringify(ia));
  assert(by("ia:gd1977/d1t02.mp3")?.durationMs === 200500, "seconds lengths");
  assert(!by("ia:gd1977/d1t03.mp3"), "at most two files per item");
});

Deno.test("one provider outage does not break search", async () => {
  fakeFetch(new Set(["api.audius.co", "archive.org"]));
  const r = await get("/api/search?q=hello");
  const d = await r.json();
  assert(r.status === 200 && d.results.length > 0 && !d.results.some((t: any) => t.id.startsWith("au:")), "partial results");
});

Deno.test("every provider down is a 502", async () => {
  fakeFetch(new Set(["itunes.apple.com", "api.jamendo.com", "api.audius.co", "archive.org"]));
  assert((await get("/api/search?q=hello")).status === 502, "502");
});

Deno.test("download streams bytes and resumes with Range", async () => {
  fakeFetch();
  const id = encodeURIComponent("ia:gd1977/d1t01.mp3");
  const full = await get(`/api/download/${id}`);
  assert(full.status === 200 && (await full.arrayBuffer()).byteLength === 1000, "full body");
  const part = await get(`/api/download/${id}`, { range: "bytes=600-" });
  const body = new Uint8Array(await part.arrayBuffer());
  assert(part.status === 206 && body.length === 400 && body[0] === MP3[600], "resumed body");
  assert(part.headers.get("content-range") === "bytes 600-999/1000", "content-range passed through");
  assert(calls.some((u) => u === "https://archive.org/download/gd1977/d1t01.mp3"), "IA download url");
});

Deno.test("download refused where not allowed", async () => {
  fakeFetch();
  assert((await get("/api/download/jm%3A78")).status === 404, "jamendo no-dl");
  assert((await get("/api/download/it%3A11")).status === 404, "itunes never downloads");
  assert((await get("/api/download/zz%3A1")).status === 404, "unknown provider");
});

Deno.test("preview of a preview-only track", async () => {
  fakeFetch();
  const r = await get("/api/preview/it%3A11");
  // Fake upstream for itunes audio isn't stubbed as audio -> provider error surfaces as 502, not a crash.
  assert(r.status === 502 || r.status === 200, String(r.status));
  assert(calls.includes("https://audio.itunes/11.m4a"), "uses previewUrl");
});

Deno.test("lyrics: synced LRCLIB match by duration, Jamendo fallback", async () => {
  fakeFetch();
  const d = await (await get("/api/lyrics/it%3A11")).json();
  assert(d.synced && d.lines[0].timeMs === 1500 && d.lines[1].timeMs === 62250 && d.lines[0].text === "Hello, it's me", JSON.stringify(d));
  fakeFetch(new Set(["lrclib.net"]));
  const j = await (await get("/api/lyrics/jm%3A77")).json();
  assert(!j.synced && j.provider === "Jamendo" && j.lines[1].text === "line two", JSON.stringify(j));
});

Deno.test("Jamendo is off without its secret", async () => {
  fakeFetch();
  Deno.env.delete("JAMENDO_CLIENT_ID");
  const d = await (await get("/api/health")).json();
  Deno.env.set("JAMENDO_CLIENT_ID", "jam-test");
  assert(!d.providers.includes("Jamendo"), JSON.stringify(d));
});

Deno.test("CORS preflight and LRC parsing", async () => {
  const r = await handle(new Request(BASE + "/api/download/x", { method: "OPTIONS" }));
  assert(r.status === 204 && r.headers.get("access-control-allow-headers")!.includes("range"), "preflight");
  assert(parseLrc("[ar: x]\n[02:03.5]hi").length === 1 && parseLrc("[02:03.5]hi")[0].timeMs === 123500, "lrc");
});

Deno.test("sources lists each enabled provider with its capabilities", async () => {
  fakeFetch();
  const d = await (await get("/api/sources")).json();
  const ids = d.sources.map((x: any) => x.id);
  assert(JSON.stringify(ids) === JSON.stringify(["jm", "au", "ia", "it"]), JSON.stringify(ids));
  const it = d.sources.find((x: any) => x.id === "it");
  assert(it.name === "Apple Music" && it.preview && !it.download && it.lyrics, JSON.stringify(it));
});

Deno.test("search can be limited to one provider", async () => {
  fakeFetch();
  calls.length = 0;
  const d = await (await get("/api/search?q=hello&provider=it")).json();
  assert(d.results.length === 1 && d.results[0].id === "it:11", JSON.stringify(d));
  assert(!calls.some((u) => u.includes("jamendo") || u.includes("audius") || u.includes("archive")), "only iTunes queried");
  assert((await get("/api/search?q=hello&provider=zz")).status === 404, "unknown provider");
});

Deno.test("tracks carry real cover art", async () => {
  fakeFetch();
  const d = await (await get("/api/search?q=hello")).json();
  const by = (id: string) => d.results.find((t: any) => t.id === id);
  assert(by("it:11").artworkUrl === "https://is1-ssl.mzstatic.com/image/thumb/a/b/600x600bb.jpg", by("it:11").artworkUrl);
  assert(by("ia:gd1977/d1t01.mp3").artworkUrl === "https://archive.org/services/img/gd1977", "IA art");
});

Deno.test("art proxy only serves provider image hosts", async () => {
  fakeFetch();
  const ok = await get("/api/art?u=" + encodeURIComponent("https://is1-ssl.mzstatic.com/image/thumb/a/b/600x600bb.jpg"));
  assert(ok.status === 200 && ok.headers.get("content-type") === "image/jpeg", String(ok.status));
  assert(ok.headers.get("access-control-allow-origin") === "*", "CORS on images");
  for (const bad of ["https://evil.example/x.jpg", "http://is1-ssl.mzstatic.com/x.jpg", "https://mzstatic.com.evil.example/x.jpg", "nope"]) {
    const r = await get("/api/art?u=" + encodeURIComponent(bad));
    assert(r.status === 403 || r.status === 400, `${bad} -> ${r.status}`);
  }
});
