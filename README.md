# TRUHive

**Search it. Preview it. Download it. Keep it on your device. Play it offline.**

TRUHive is a local-first music discovery, download and player app. It searches several authorized
music sources at once, groups duplicate results, previews and downloads tracks where the source
allows it, and plays everything from the device — no account, no cloud library.

- **Design:** [TRUHive — App UI (Figma)](https://www.figma.com/design/AlfPaNNTtHJdMtVgUs1yjw).
  The Splash and Welcome designs are the visual source of truth; the app's design tokens
  (`lib/core/theme/tokens.dart`) mirror the Figma variables one-to-one.
- **Stack:** Flutter (Dart). One codebase builds the Android app (primary target), iOS, and the web/PWA.

## Why Flutter

A music player lives or dies on things a web page can't do reliably:

| Need | How TRUHive does it |
| --- | --- |
| Keep playing with the screen off, lock-screen & notification controls | `just_audio` + `just_audio_background` (Android media session / foreground service, iOS background audio) |
| Real files on the device | Downloads are written to the app's `TRUHive Music` folder (browser storage on web) |
| Android Sharesheet (WhatsApp, Telegram, Bluetooth, Quick Share, Files, Gmail…) | `share_plus` shares the actual audio file — nothing is uploaded |
| Import music already on the phone | `file_picker` (audio) |
| One product on phone, tablet, desktop and web | Responsive Flutter layouts: bottom nav + mini player on phones, sidebar + player bar on desktop |

## Running

```bash
flutter pub get
flutter run                 # Android / iOS device or emulator
flutter run -d chrome       # web
flutter test                # unit tests
flutter analyze
```

**Android APK:** every push builds one in GitHub Actions (`.github/workflows/build.yml`).
Download it from the run's *Artifacts* → `truhive-android-apk`. The workflow signs with the
debug key; add a release keystore before publishing to Google Play.

**Web app:** every push to `main` deploys the web build to GitHub Pages
(`.github/workflows/pages.yml`) at `https://<owner>.github.io/<repo>/`. In the repository's
**Settings → Pages**, set **Source** to **GitHub Actions** (one-time).

## Architecture

```
lib/
├── main.dart                  bootstrap (background audio, services, router)
├── router.dart                go_router: 4-tab shell + full-screen routes
├── core/
│   ├── theme/                 tokens (Figma variables), Montserrat type ramp, ThemeData
│   ├── models/models.dart     Track, SourceTrack, TrackGroup, Playlist, Lyrics…
│   └── util/                  formatting, hashing, match normalization
├── data/storage/              Hive (metadata) + FileStore (native files | IndexedDB on web)
├── sources/                   ← the source-adapter layer
│   ├── music_source.dart      MusicSource contract + capabilities
│   ├── source_manager.dart    registry, enable/disable, health
│   ├── backend_source.dart    adapter for a TRUHive backend (real providers)
│   └── demo/                  demo adapters + original demo catalog
├── audio/synth.dart           on-device synthesizer for demo audio (WAV)
├── services/                  app state (ChangeNotifier) — one source of truth each
│   ├── search_controller.dart parallel search, timeouts, error isolation, grouping
│   ├── player_controller.dart queue, shuffle/repeat, previews, autoplay
│   ├── download_manager.dart  progress, speed, pause/resume (byte ranges), cancel
│   ├── library_repository.dart local tracks, favorites, recents, lyric unlocks
│   ├── playlist_repository.dart
│   ├── lyrics_service.dart    authorized lyrics + rewarded unlock
│   ├── ads/rewarded_ads.dart  RewardedAdProvider integration point
│   ├── share_service.dart     share file / export copy
│   └── import_service.dart, connectivity_service.dart, settings_controller.dart
└── ui/
    ├── widgets/               design-system components (buttons, chips, rows, states…)
    ├── shell/                 responsive shell, mini player, desktop player bar
    └── screens/               Splash, Welcome, Home, Search, Song Details, Now Playing,
                               Lyrics, Up Next, Downloads, Library, Playlist, Favorites,
                               Sources, Settings
```

### Search pipeline

```
query ─▶ debounce (350 ms) ─▶ SourceManager.enabled
      ─▶ every source in parallel, 8 s timeout each, stale searches dropped
      ─▶ results render as each source answers ("3 of 4 responded")
      ─▶ normalize ─▶ group duplicates (title + artist, duration ±3 s) ─▶ rank
```

A failing source never breaks the search: it is reported inline with **Retry** and
**Manage Sources**, and the other sources' results still show.

## Sources: demo vs. real

TRUHive only integrates sources that authorize the relevant search, preview, download and lyrics
behaviour, and it never scrapes or circumvents DRM.

Out of the box the app ships **demo adapters** (OpenWave, Commons Audio, Arcadia, IndieVault) so the
whole experience can be tested without a provider contract. They are clearly labeled *Demo* in the
app. Their music — titles, artists, lyrics and audio — is original and generated on the device by
`lib/audio/synth.dart`; nothing is fetched from anywhere. They simulate realistic latency and
bandwidth, and IndieVault deliberately simulates an outage to exercise error handling.

### The TRUHive backend (Supabase)

`supabase/functions/truhive-api` is the backend: a single Supabase Edge Function that searches
real providers in parallel and streams their audio to the device.

| Provider | Search | Preview | Download | Lyrics |
| --- | --- | --- | --- | --- |
| Apple Music (iTunes Search API) | ✓ | 30 s clips | — | via LRCLIB |
| Internet Archive (CC, public domain, Live Music Archive only) | ✓ | ✓ | ✓ | — |
| Jamendo (needs `JAMENDO_CLIENT_ID`) | ✓ | ✓ | where the artist allows it | Jamendo / LRCLIB |
| Audius | ✓ | ✓ | where the artist enabled it, ungated | — |

It is **stateless**: no database tables, no Storage. Songs pass through to the user's device and are
never kept on the server; nothing about users is recorded.

The CI and Pages builds bundle its URL (`--dart-define=TRUHIVE_BACKEND_URL=…`), so fresh installs
start on real sources; the demo sources stay available in **Manage Sources**.

```bash
supabase functions deploy truhive-api --no-verify-jwt     # public API, no sign-in
supabase secrets set JAMENDO_CLIENT_ID=…                  # free at devportal.jamendo.com
supabase secrets set AUDIUS_API_KEY=…                     # optional, higher rate limits
deno test --allow-env supabase/functions/truhive-api       # offline tests with stubbed providers
```

### Connecting a backend

Real providers usually need private API keys, which must never ship inside the app. Run a TRUHive
backend that holds the keys and proxies the providers, then add its URL in
**Settings → Music sources → Connect a backend**. `BackendSource` expects:

| Endpoint | Response |
| --- | --- |
| `GET /api/health` | `200` when reachable |
| `GET /api/search?q=…` | `{"results":[{"id","title","artist","album","durationMs","genre","year","artworkSeed","provider","preview":bool,"download":bool,"lyrics":bool,"format","sizeBytes"}]}` |
| `GET /api/preview/:id` | audio bytes (≈30 s clip) |
| `GET /api/download/:id` | audio bytes; honour `Range: bytes=N-` with `206` + `Accept-Ranges: bytes` for resumable downloads |
| `GET /api/lyrics/:id` | `{"provider","synced":bool,"lines":[{"timeMs","text"}]}` |

Only return `download: true` / `lyrics: true` where the provider's licence allows it — the UI
offers an action only when the source declares it.

To add a provider directly instead (for public, key-less APIs), implement `MusicSource` and register
it in `SourceManager`.

## Rewarded ads for lyrics

`RewardedAdProvider` (`lib/services/ads/rewarded_ads.dart`) is the integration point. With no ad
network configured, the app uses `DemoRewardedAdProvider`, an explicitly labeled “Demo ad slot” —
it never pretends to be a real advertisement. To go live, implement the interface with your ad SDK
(e.g. Google Mobile Ads on Android/iOS) and pass it to `AppServices.create(ads: …)`.

## Storage & privacy

- No accounts, no sign-in, no cloud library, no analytics.
- Android/iOS: audio files live in the app's `TRUHive Music` folder; **Save a copy to device** exports
  any song through the system file picker.
- Web: files live in the browser's IndexedDB. Browsers can't write into arbitrary folders, so export
  uses the normal browser download. Settings can request persistent storage so the browser keeps
  your music under storage pressure.
- Offline: search shows a clear offline state; downloaded music keeps playing.

## Accessibility

Semantic labels on every icon button, 44 px minimum touch targets, live regions for search status
and download completion, keyboard reorder alternatives (Move up / Move down) for drag-and-drop
lists, desktop media keys, and reduced-motion support for animated elements.

## Fonts & licences

Montserrat is bundled under the SIL Open Font License (`assets/fonts/OFL.txt`).
Icons: Lucide (ISC licence) via `lucide_icons_flutter`.
