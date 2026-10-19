// TRUHive backend: one Edge Function implementing the API the app's
// BackendSource expects (see README "Connecting a backend").
//
//   GET /api/health · /api/sources · /api/search?q=[&provider=] · /api/art?u=
//       /api/preview/:id · /api/stream/:id · /api/download/:id · /api/lyrics/:id
//
// Stateless by design: no database, no storage. Audio is streamed from the
// provider to the user's device and never kept here.
import {
  artAllowed,
  artSignatureValid,
  lrclib,
  plainLines,
  PROVIDERS,
  resolve,
  signArt,
  type Track,
} from "./providers.ts";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "range, authorization, apikey, x-client-info, content-type",
  "access-control-expose-headers": "content-length, content-range, accept-ranges, content-type",
};

const json = (body: unknown, status = 200, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json; charset=utf-8", ...extra },
  });

async function search(q: string, only: string | null): Promise<Response> {
  if (!q.trim()) return json({ results: [] });
  const active = PROVIDERS.filter((p) => p.enabled() && (!only || p.prefix === only));
  if (active.length === 0) return json({ error: "unknown provider" }, 404);
  const settled = await Promise.allSettled(active.map((p) => p.search(q)));
  const results: Track[] = [];
  const errors: string[] = [];
  settled.forEach((s, i) => {
    if (s.status === "fulfilled") results.push(...s.value);
    else errors.push(`${active[i].name}: ${s.reason}`);
  });
  if (errors.length) console.warn("search provider errors", errors);
  await Promise.all(results.map(async (t) => {
    if (t.artworkUrl) t.artworkSig = await signArt(t.artworkUrl);
  }));
  // Only fail when every provider failed, so one outage never breaks search.
  if (results.length === 0 && errors.length === active.length) return json({ error: "providers unavailable" }, 502);
  return json({ results }, 200, { "cache-control": "public, max-age=300" });
}

/** Streams provider audio through, passing Range so downloads can resume. */
async function audio(id: string, kind: "preview" | "stream" | "download", req: Request): Promise<Response> {
  const r = resolve(id);
  if (!r) return json({ error: "unknown track" }, 404);
  const info = await r[0].info(r[1]);
  const url = kind === "download"
    ? info?.downloadUrl
    : kind === "stream"
    ? info?.streamUrl
    : (info?.previewUrl ?? info?.downloadUrl);
  if (!url) return json({ error: `${kind} not available for this track` }, 404);

  const headers: Record<string, string> = { "user-agent": "TRUHive/1.0" };
  const range = req.headers.get("range");
  if (range) headers.range = range;
  const up = await fetch(url, { headers });
  if (!up.ok && up.status !== 206) return json({ error: `provider HTTP ${up.status}` }, 502);

  const out = new Headers(CORS);
  for (const h of ["content-type", "content-length", "content-range", "accept-ranges"]) {
    const v = up.headers.get(h);
    if (v) out.set(h, v);
  }
  if (!out.get("content-type")?.startsWith("audio/")) out.set("content-type", "audio/mpeg");
  out.set("cache-control", "no-store");
  return new Response(up.body, { status: up.status, headers: out });
}

const ART_MAX_BYTES = 5_000_000;

/** Cover images, re-served with CORS so the web app can draw them. Only
 *  URLs this backend issued (signed) or provider image hosts are fetched. */
async function art(raw: string | null, sig: string | null): Promise<Response> {
  let u: URL;
  try {
    u = new URL(raw ?? "");
  } catch {
    return json({ error: "bad url" }, 400);
  }
  if (u.protocol !== "https:" || !(artAllowed(u) || await artSignatureValid(raw!, sig))) {
    return json({ error: "host not allowed" }, 403);
  }
  const up = await fetch(u, { headers: { "user-agent": "TRUHive/1.0" }, signal: AbortSignal.timeout(8000) });
  const type = up.headers.get("content-type") ?? "";
  const size = Number(up.headers.get("content-length") ?? 0);
  if (!up.ok || !type.startsWith("image/") || size > ART_MAX_BYTES) return json({ error: `image HTTP ${up.status}` }, 502);
  const out = new Headers(CORS);
  out.set("content-type", type);
  out.set("cache-control", "public, max-age=604800, immutable");
  return new Response(up.body, { headers: out });
}

async function lyrics(id: string): Promise<Response> {
  const r = resolve(id);
  if (!r) return json({ error: "unknown track" }, 404);
  const info = await r[0].info(r[1]);
  if (!info) return json({ error: "unknown track" }, 404);
  try {
    const found = await lrclib(info);
    if (found) return json({ provider: "LRCLIB", ...found });
  } catch (e) {
    console.warn("lrclib", String(e));
  }
  if (info.plainLyrics) return json({ provider: r[0].name, synced: false, lines: plainLines(info.plainLyrics) });
  return json({ provider: "LRCLIB", synced: false, lines: [] });
}

export async function handle(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return json({ error: "method not allowed" }, 405);
  const url = new URL(req.url);
  // The function is mounted at /functions/v1/truhive-api, so match from /api/.
  const m = url.pathname.match(/\/api\/(health|sources|search|art|preview|stream|download|lyrics)(?:\/(.+))?$/);
  if (!m) return json({ error: "not found" }, 404);
  const id = m[2] ? decodeURIComponent(m[2]) : "";
  try {
    switch (m[1]) {
      case "health":
        return json({ ok: true, providers: PROVIDERS.filter((p) => p.enabled()).map((p) => p.name) });
      case "sources":
        return json({
          sources: PROVIDERS.filter((p) => p.enabled()).map((p) => ({
            id: p.prefix,
            name: p.name,
            description: p.description,
            ...p.can,
          })),
        }, 200, { "cache-control": "public, max-age=3600" });
      case "search":
        return await search(url.searchParams.get("q") ?? "", url.searchParams.get("provider"));
      case "art":
        return await art(url.searchParams.get("u"), url.searchParams.get("s"));
      case "preview":
      case "stream":
      case "download":
        return await audio(id, m[1], req);
      case "lyrics":
        return await lyrics(id);
    }
  } catch (e) {
    console.error(m[1], String(e));
    return json({ error: "provider unavailable" }, 502);
  }
  return json({ error: "not found" }, 404);
}
