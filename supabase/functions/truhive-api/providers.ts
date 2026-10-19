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

// Order is the order the app lists them: download-capable sources first.
export const PROVIDERS: Provider[] = [jamendo, audius, archive, itunes];

/** Image hosts /api/art will fetch from, so it can't be used as an open proxy. */
const ART_HOSTS = ["mzstatic.com", "jamendo.com", "archive.org", "audius.co"];
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
