// Provider adapters for the TRUHive backend.
//
// Every adapter only uses providers' public, documented APIs and only marks a
// track downloadable when the provider says the artist or licence allows it.
// Nothing is stored: audio is streamed straight through to the user's device.

export type Track = {
  id: string;
  title: string;
  artist: string;
  album: string;
  durationMs: number;
  genre?: string;
  year?: number;
  artworkSeed: string;
  provider: string;
  preview: boolean;
  download: boolean;
  lyrics: boolean;
  format?: string;
  sizeBytes?: number;
  /** Cover image on the provider's CDN; the app loads it through /api/art. */
  artworkUrl?: string;
};

/** What the audio and lyrics routes need to serve one track. */
export type TrackInfo = {
  title: string;
  artist: string;
  album: string;
  durationSec: number;
  previewUrl?: string;
  downloadUrl?: string;
  plainLyrics?: string;
};

export interface Provider {
  prefix: string;
  name: string;
  description: string;
  /** What this provider can ever do; each track still says what it allows. */
  can: { preview: boolean; download: boolean; lyrics: boolean };
  enabled(): boolean;
  search(q: string): Promise<Track[]>;
  info(id: string): Promise<TrackInfo | null>;
}

const UA = "TRUHive/1.0 (+https://github.com/Ridgevalley111243/Sniper-strike)";

export async function getJson(url: string, timeoutMs = 6000, headers: Record<string, string> = {}) {
  const r = await fetch(url, { headers: { "user-agent": UA, ...headers }, signal: AbortSignal.timeout(timeoutMs) });
  if (!r.ok) throw new Error(`${new URL(url).host} HTTP ${r.status}`);
  return await r.json();
}

const year = (s?: string) => {
  const y = parseInt((s ?? "").slice(0, 4), 10);
  return Number.isFinite(y) && y > 1800 ? y : undefined;
};
const first = (v: unknown) => (Array.isArray(v) ? v[0] : v) as string | undefined;

// ---------------------------------------------------------------- iTunes
// Search + 30-second previews of mainstream catalogue. Never downloadable.
export const itunes: Provider = {
  prefix: "it",
  name: "Apple Music",
  description: "Mainstream catalogue · 30-second previews",
  can: { preview: true, download: false, lyrics: true },
  enabled: () => true,
  async search(q) {
    const d = await getJson(
      `https://itunes.apple.com/search?media=music&entity=song&limit=15&term=${encodeURIComponent(q)}`,
    );
    return (d.results ?? [])
      .filter((r: any) => r.kind === "song" && r.previewUrl)
      .map((r: any): Track => ({
        id: `it:${r.trackId}`,
        title: r.trackName,
        artist: r.artistName,
        album: r.collectionName ?? "",
        durationMs: r.trackTimeMillis ?? 0,
        genre: r.primaryGenreName,
        year: year(r.releaseDate),
        artworkSeed: `it:${r.collectionId ?? r.trackId}`,
        provider: "Apple Music",
        preview: true,
        download: false,
        lyrics: true,
        format: "AAC",
        artworkUrl: r.artworkUrl100?.replace(/\/\d+x\d+bb\./, "/600x600bb."),
      }));
  },
  async info(id) {
    const d = await getJson(`https://itunes.apple.com/lookup?id=${encodeURIComponent(id)}`);
    const r = d.results?.[0];
    if (!r) return null;
    return {
      title: r.trackName,
      artist: r.artistName,
      album: r.collectionName ?? "",
      durationSec: (r.trackTimeMillis ?? 0) / 1000,
      previewUrl: r.previewUrl,
    };
  },
};

// ------------------------------------------------------- Internet Archive
// Only items that are Creative Commons, public domain, or in the Live Music
// Archive (etree: bands that allow non-commercial sharing of live shows).
const IA_FILTER =
  "mediatype:audio AND (collection:etree OR licenseurl:*creativecommons* OR licenseurl:*publicdomain*)";

function iaSeconds(len?: string): number {
  if (!len) return 0;
  if (len.includes(":")) return len.split(":").reduce((t, p) => t * 60 + parseFloat(p), 0);
  return parseFloat(len) || 0;
}

const iaMp3s = (files: any[]) =>
  files.filter((f) => /\.mp3$/i.test(f.name) && (f.format ?? "").includes("MP3")).slice(0, 2);

export const archive: Provider = {
  prefix: "ia",
  name: "Internet Archive",
  description: "Public domain, Creative Commons and live concert recordings",
  can: { preview: true, download: true, lyrics: false },
  enabled: () => true,
  async search(q) {
    const query = `(${q.replace(/[()]/g, " ")}) AND ${IA_FILTER}`;
    const d = await getJson(
      `https://archive.org/advancedsearch.php?q=${encodeURIComponent(query)}` +
        `&fl[]=identifier&fl[]=title&fl[]=creator&fl[]=year&rows=6&sort[]=downloads+desc&output=json`,
    );
    const docs: any[] = d.response?.docs ?? [];
    const items = await Promise.allSettled(
      docs.map((doc) => getJson(`https://archive.org/metadata/${encodeURIComponent(doc.identifier)}`, 5000)),
    );
    const out: Track[] = [];
    items.forEach((res, i) => {
      if (res.status !== "fulfilled") return;
      const doc = docs[i];
      const meta = res.value.metadata ?? {};
      for (const f of iaMp3s(res.value.files ?? [])) {
        out.push({
          id: `ia:${doc.identifier}/${f.name}`,
          title: f.title || first(meta.title) || f.name.replace(/\.mp3$/i, ""),
          artist: f.creator || first(meta.creator) || first(doc.creator) || "Unknown artist",
          album: first(meta.title) ?? "",
          durationMs: Math.round(iaSeconds(f.length) * 1000),
          genre: first(meta.subject)?.split(";")[0]?.trim() || undefined,
          year: year(String(first(meta.year) ?? first(meta.date) ?? doc.year ?? "")),
          artworkSeed: `ia:${doc.identifier}`,
          provider: "Internet Archive",
          preview: true,
          download: true,
          lyrics: false,
          format: "MP3",
          sizeBytes: f.size ? parseInt(f.size, 10) : undefined,
          artworkUrl: `https://archive.org/services/img/${encodeURIComponent(doc.identifier)}`,
        });
      }
    });
    return out;
  },
  async info(id) {
    const slash = id.indexOf("/");
    if (slash < 0) return null;
    const ident = id.slice(0, slash), file = id.slice(slash + 1);
    const d = await getJson(`https://archive.org/metadata/${encodeURIComponent(ident)}`);
    const f = (d.files ?? []).find((x: any) => x.name === file);
    if (!f) return null;
    const url = `https://archive.org/download/${encodeURIComponent(ident)}/${file.split("/").map(encodeURIComponent).join("/")}`;
    return {
      title: f.title || first(d.metadata?.title) || file,
      artist: f.creator || first(d.metadata?.creator) || "",
      album: first(d.metadata?.title) ?? "",
      durationSec: iaSeconds(f.length),
      previewUrl: url,
      downloadUrl: url,
    };
  },
};

// ---------------------------------------------------------------- Jamendo
// Independent Creative Commons music. Needs a free client ID (secret
// JAMENDO_CLIENT_ID). Downloads only where `audiodownload_allowed` is true.
const jamendoId = () => Deno.env.get("JAMENDO_CLIENT_ID") ?? "";
const jamendoTracks = (params: string) =>
  getJson(
    `https://api.jamendo.com/v3.0/tracks/?client_id=${encodeURIComponent(jamendoId())}` +
      `&format=json&audioformat=mp32&audiodlformat=mp32&include=musicinfo+lyrics&${params}`,
  );

export const jamendo: Provider = {
  prefix: "jm",
  name: "Jamendo",
  description: "Independent artists · Creative Commons",
  can: { preview: true, download: true, lyrics: true },
  enabled: () => jamendoId() !== "",
  async search(q) {
    const d = await jamendoTracks(`limit=15&search=${encodeURIComponent(q)}`);
    return (d.results ?? []).map((r: any): Track => {
      const lyrics = typeof r.musicinfo?.lyrics === "string" && r.musicinfo.lyrics.trim() !== "";
      return {
        id: `jm:${r.id}`,
        title: r.name,
        artist: r.artist_name,
        album: r.album_name ?? "",
        durationMs: (r.duration ?? 0) * 1000,
        genre: r.musicinfo?.tags?.genres?.[0],
        year: year(r.releasedate),
        artworkSeed: `jm:${r.album_id ?? r.id}`,
        provider: "Jamendo",
        preview: !!r.audio,
        download: r.audiodownload_allowed === true && !!r.audiodownload,
        lyrics,
        format: "MP3",
        artworkUrl: r.album_image || r.image || undefined,
      };
    });
  },
  async info(id) {
    const d = await jamendoTracks(`id=${encodeURIComponent(id)}`);
    const r = d.results?.[0];
    if (!r) return null;
    return {
      title: r.name,
      artist: r.artist_name,
      album: r.album_name ?? "",
      durationSec: r.duration ?? 0,
      previewUrl: r.audio || undefined,
      downloadUrl: r.audiodownload_allowed === true && r.audiodownload ? r.audiodownload : undefined,
      plainLyrics: r.musicinfo?.lyrics || undefined,
    };
  },
};

// ----------------------------------------------------------------- Audius
// Streams are public; downloads only when the artist enabled them with no
// gating conditions. Optional AUDIUS_API_KEY raises rate limits.
const AUDIUS = "https://api.audius.co/v1";
const audiusQs = () => {
  const key = Deno.env.get("AUDIUS_API_KEY");
  return `app_name=TRUHive${key ? `&api_key=${encodeURIComponent(key)}` : ""}`;
};
const audiusDownloadable = (r: any) => r.is_downloadable === true && !r.download_conditions;

export const audius: Provider = {
  prefix: "au",
  name: "Audius",
  description: "Independent artists · hip-hop, electronic, Afrobeats",
  can: { preview: true, download: true, lyrics: false },
  enabled: () => Deno.env.get("AUDIUS_DISABLED") !== "1",
  async search(q) {
    const d = await getJson(`${AUDIUS}/tracks/search?query=${encodeURIComponent(q)}&${audiusQs()}`);
    return (d.data ?? [])
      .filter((r: any) => r.is_streamable !== false && !r.stream_conditions)
      .slice(0, 15)
      .map((r: any): Track => ({
        id: `au:${r.id}`,
        title: r.title,
        artist: r.user?.name ?? "",
        album: "",
        durationMs: (r.duration ?? 0) * 1000,
        genre: r.genre || undefined,
        year: year(r.release_date),
        artworkSeed: `au:${r.id}`,
        provider: "Audius",
        preview: true,
        download: audiusDownloadable(r),
        lyrics: false,
        format: "MP3",
        artworkUrl: r.artwork?.["480x480"] || r.artwork?.["150x150"] || undefined,
      }));
  },
  async info(id) {
    const d = await getJson(`${AUDIUS}/tracks/${encodeURIComponent(id)}?${audiusQs()}`);
    const r = d.data;
    if (!r) return null;
    const base = `${AUDIUS}/tracks/${encodeURIComponent(id)}`;
    return {
      title: r.title,
      artist: r.user?.name ?? "",
      album: "",
      durationSec: r.duration ?? 0,
      previewUrl: `${base}/stream?${audiusQs()}`,
      downloadUrl: audiusDownloadable(r) ? `${base}/download?${audiusQs()}` : undefined,
    };
  },
};

// ---------------------------------------------------------------- ccMixter
// Creative Commons remixes and originals; every upload's licence allows
// sharing, so the MP3 is downloadable. A cappellas and samples are skipped.
const CCMIXTER = "https://ccmixter.org/api/query";
const ccSkip = /,(acappella|sample|sample_pack|stems?),/;

function ccMp3(u: any) {
  const files: any[] = u.files ?? [];
  return files.find((f) => f.file_format_info?.mime_type === "audio/mpeg" && f.download_url) ??
    files.find((f) => /\.mp3$/i.test(f.file_name ?? "") && f.download_url);
}

function ccTrack(u: any): Track | null {
  const f = ccMp3(u);
  if (!f || ccSkip.test(u.upload_tags ?? "")) return null;
  const tags = String(u.upload_tags ?? "").split(",");
  return {
    id: `cc:${u.upload_id}`,
    title: u.upload_name,
    artist: u.user_real_name || u.user_name || "",
    album: "",
    durationMs: Math.round(iaSeconds(f.file_format_info?.ps) * 1000),
    genre: tags.find((t) => ["hip_hop", "electronic", "pop", "rock", "ambient", "jazz", "funk", "reggae", "soul", "blues", "folk", "classical", "experimental"].includes(t))?.replace("_", " "),
    year: year(String(u.upload_date ?? "")) ?? year(String(u.upload_date_format ?? "").split(", ")[2]),
    artworkSeed: `cc:${u.upload_id}`,
    provider: "ccMixter",
    preview: true,
    download: true,
    lyrics: false,
    format: "MP3",
    sizeBytes: f.file_rawsize ? Number(f.file_rawsize) : undefined,
  };
}

export const ccmixter: Provider = {
  prefix: "cc",
  name: "ccMixter",
  description: "Creative Commons remixes and originals",
  can: { preview: true, download: true, lyrics: false },
  enabled: () => Deno.env.get("CCMIXTER_DISABLED") !== "1",
  async search(q) {
    const d = await getJson(`${CCMIXTER}?f=json&lic=all&sort=rank&limit=15&searchp=${encodeURIComponent(q)}`);
    return (Array.isArray(d) ? d : []).map(ccTrack).filter((t): t is Track => t !== null);
  },
  async info(id) {
    const d = await getJson(`${CCMIXTER}?f=json&ids=${encodeURIComponent(id)}`);
    const u = Array.isArray(d) ? d[0] : null;
    const f = u && ccMp3(u);
    if (!f) return null;
    return {
      title: u.upload_name,
      artist: u.user_real_name || u.user_name || "",
      album: "",
      durationSec: iaSeconds(f.file_format_info?.ps),
      previewUrl: f.download_url,
      downloadUrl: f.download_url,
    };
  },
};

// --------------------------------------------------------------- Openverse
// Openly licensed music gathered from many collections (Wikimedia Commons,
// Freesound and more). Every item carries a CC licence or public-domain mark,
// so the file is downloadable. Anonymous use is rate limited per IP; set
// OPENVERSE_CLIENT_ID / OPENVERSE_CLIENT_SECRET for the higher limits.
const OPENVERSE = "https://api.openverse.org/v1";
let ovToken: { value: string; expires: number } | null = null;

async function ovHeaders(): Promise<Record<string, string>> {
  const id = Deno.env.get("OPENVERSE_CLIENT_ID"), secret = Deno.env.get("OPENVERSE_CLIENT_SECRET");
  if (!id || !secret) return {};
  if (!ovToken || ovToken.expires < Date.now() + 60_000) {
    const r = await fetch(`${OPENVERSE}/auth_tokens/token/`, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded", "user-agent": UA },
      body: new URLSearchParams({ grant_type: "client_credentials", client_id: id, client_secret: secret }),
      signal: AbortSignal.timeout(6000),
    });
    if (!r.ok) return {}; // fall back to anonymous access
    const t = await r.json();
    ovToken = { value: t.access_token, expires: Date.now() + (t.expires_in ?? 3600) * 1000 };
  }
  return { authorization: `Bearer ${ovToken.value}` };
}

// Sources that already have their own TRUHive source.
const OV_SKIP = new Set(["jamendo", "ccmixter"]);

function ovTrack(r: any): Track | null {
  if (!r.url || r.mature) return null;
  return {
    id: `ov:${r.id}`,
    title: r.title || "Untitled",
    artist: r.creator || "Unknown artist",
    album: r.audio_set?.title ?? "",
    durationMs: typeof r.duration === "number" ? r.duration : 0,
    genre: r.genres?.[0],
    artworkSeed: `ov:${r.id}`,
    provider: "Openverse",
    preview: true,
    download: true,
    lyrics: false,
    format: r.filetype ? String(r.filetype).toUpperCase() : undefined,
    sizeBytes: r.filesize ? Number(r.filesize) : undefined,
    artworkUrl: r.thumbnail || undefined,
  };
}

export const openverse: Provider = {
  prefix: "ov",
  name: "Openverse",
  description: "Openly licensed music from Wikimedia Commons, Freesound and more",
  can: { preview: true, download: true, lyrics: false },
  enabled: () => Deno.env.get("OPENVERSE_DISABLED") !== "1",
  search: (q) =>
    cached(`ov|${q.toLowerCase().trim()}`, async () => {
      const d = await getJson(
        `${OPENVERSE}/audio/?category=music&page_size=20&q=${encodeURIComponent(q)}`,
        6000,
        await ovHeaders(),
      );
      return (d.results ?? [])
        .filter((r: any) => !OV_SKIP.has(r.source))
        .map(ovTrack)
        .filter((t: Track | null): t is Track => t !== null);
    }),
  async info(id) {
    const r = await getJson(`${OPENVERSE}/audio/${encodeURIComponent(id)}/`, 6000, await ovHeaders());
    if (!r?.url) return null;
    return {
      title: r.title || "Untitled",
      artist: r.creator || "",
      album: r.audio_set?.title ?? "",
      durationSec: typeof r.duration === "number" ? r.duration / 1000 : 0,
      previewUrl: r.url,
      downloadUrl: r.url,
    };
  },
};

// A small per-instance memo so repeated searches don't spend rate-limited
// quota. It only holds search results (public catalogue data) for minutes.
const memo = new Map<string, { at: number; value: Track[] }>();
async function cached(key: string, fn: () => Promise<Track[]>, ttlMs = 10 * 60_000): Promise<Track[]> {
  const hit = memo.get(key);
  if (hit && Date.now() - hit.at < ttlMs) return hit.value;
  const value = await fn();
  if (memo.size > 200) memo.delete(memo.keys().next().value!);
  memo.set(key, { at: Date.now(), value });
  return value;
}

// Order is the order the app lists them: download-capable sources first.
export const PROVIDERS: Provider[] = [jamendo, audius, ccmixter, openverse, archive, itunes];

/** Image hosts /api/art will fetch from, so it can't be used as an open proxy. */
const ART_HOSTS = ["mzstatic.com", "jamendo.com", "archive.org", "audius.co", "openverse.org"];
export const artAllowed = (u: URL) =>
  u.protocol === "https:" && ART_HOSTS.some((h) => u.hostname === h || u.hostname.endsWith(`.${h}`));

/** Splits "jm:123" into its provider and that provider's own track id. */
export function resolve(id: string): [Provider, string] | null {
  const i = id.indexOf(":");
  if (i < 0) return null;
  const p = PROVIDERS.find((x) => x.prefix === id.slice(0, i));
  return p && p.enabled() ? [p, id.slice(i + 1)] : null;
}

// ----------------------------------------------------------------- Lyrics
export type LyricLine = { timeMs: number | null; text: string };

/** Parses LRC ("[01:02.50] words") into timed lines. */
export function parseLrc(lrc: string): LyricLine[] {
  const out: LyricLine[] = [];
  for (const raw of lrc.split(/\r?\n/)) {
    const m = raw.match(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/);
    if (!m) continue;
    out.push({ timeMs: Math.round((parseInt(m[1], 10) * 60 + parseFloat(m[2])) * 1000), text: m[3].trim() });
  }
  return out;
}

/** LRCLIB lookup: prefers synced lyrics within 3 s of the track's length. */
export async function lrclib(info: TrackInfo): Promise<{ synced: boolean; lines: LyricLine[] } | null> {
  const d: any[] = await getJson(
    `https://lrclib.net/api/search?track_name=${encodeURIComponent(info.title)}` +
      `&artist_name=${encodeURIComponent(info.artist)}`,
  );
  const close = (r: any) => !info.durationSec || Math.abs((r.duration ?? 0) - info.durationSec) <= 3;
  const hit = d.find((r) => r.syncedLyrics && close(r)) ?? d.find((r) => r.plainLyrics && close(r));
  if (!hit) return null;
  if (hit.syncedLyrics) return { synced: true, lines: parseLrc(hit.syncedLyrics) };
  return { synced: false, lines: plainLines(hit.plainLyrics) };
}

export const plainLines = (text: string): LyricLine[] =>
  text.split(/\r?\n/).map((t) => ({ timeMs: null, text: t.trim() }));
