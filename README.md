# Trutech Business: website & portfolio

*Where ideas turn into reality.*

The website for Trutech Business: home, services, portfolio, about, contact, a hidden admin, and private links where
clients review and download the work made for them.

Built with [Astro](https://astro.build) and deployed to GitHub Pages by `.github/workflows/pages.yml`:
**https://ridgevalley111243.github.io/trutechwebsite/**

Content (projects, contact details, client work) is stored in Supabase, in the "Class of 2019 Dues" project, in tables
prefixed `site_` that are separate from the dues system.

```bash
npm install
npm run dev      # local preview at http://localhost:4321/trutechwebsite/
npm run check    # type-check
npm run build    # production build into dist/ (reads content from Supabase)
SITE_DATA_FILE=snapshot.json npm run build   # build from a JSON snapshot instead
```

## The admin
**Opening it:** the admin isn't linked anywhere. Long-press an empty part of any page on a phone, or double-click an
empty part on a computer. It's at `/admin/`, so you can also bookmark it.

**Signing in:** email and password (Supabase Auth). Only accounts listed in `site_admins` can change anything; row
level security enforces this in the database. The first sign-in with a temporary password asks for a new one.

- **Portfolio:** add, edit, hide or delete projects (graphic design, websites, systems): title, type, client, status,
  summary, cover, gallery with descriptions, services, live link, story (Markdown), home page and order. Images are
  converted to WebP (at most 1600px wide) in the browser and stored in the public `site-media` bucket.
- **Client work:** create a private link for a client, upload files of any format (JPG, PDF, MP4, Affinity, ZIP…, up
  to 50 MB each) to the private `client-files` bucket, and send the link on WhatsApp. Choose **Review** (the client
  approves or asks for changes) or **Final delivery** (the client downloads and leaves a rating). Reviews appear in the
  admin. Links can be switched off, replaced with a new link, or given an end date.
- **Settings:** name, location, email, phone, WhatsApp and social links.
- **Account:** change password, sign out.

## How changes reach the site
- Pages are static and built from Supabase. On the Work page, project pages and the home page's Selected work, the
  browser also fetches the current projects and redraws them if they changed, so admin edits show straight away. A new
  project's page is drawn by `404.html` until the next build.
- Every 15 minutes the workflow compares Supabase's `site_content_version()` with the site's `/content-version.txt`
  and rebuilds only when they differ. Contact details and settings appear with that rebuild.

## Client links
A client opens `/client/#<token>`. The page calls the `client-portal` edge function
(`supabase/functions/client-portal/`), which checks the token and returns the files as short-lived signed links,
and saves the client's review. After saving, the review opens in WhatsApp, ready to send to the WhatsApp number in
Settings. Clients can't read the tables or the private bucket directly.

## Code map
- `src/lib/content.ts` – Supabase access and data types, shared by the build and the browser.
- `src/lib/render.ts` – HTML for project cards and pages (same output at build time and in the browser).
- `src/scripts/live.ts` – refreshes portfolio sections in the browser.
- `src/pages/admin.astro`, `src/scripts/admin.ts` – the admin.
- `src/pages/client.astro` – the client page.
- `src/site.ts` – the rest of the site text (tagline, services, about, toolkit, process).

## Brand
- **Colours** (`src/styles/global.css`): `#0A1931` navy, `#1A3D63`, `#4A7FA7`, `#B3CFE5`, `#F6FAFD`.
- **Fonts**: headings use **Al Ragas**. Add the font file as `public/fonts/AlRagas.woff2` (or `.otf`/`.ttf`) and
  it's used automatically; until then the similar Google font *Gloock* is shown. Body text is *Montserrat*.
- **Logo files**: `public/brand/` (transparent leaf mark, light variant, logo for dark backgrounds, icons and the
  social sharing image).
