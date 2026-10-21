# Trutech Business: website & portfolio

*Where ideas turn into reality.*

The website for Trutech Business: home, services, portfolio with case studies, about, contact, and private
encrypted pages where clients view the work made for them.

Built with [Astro](https://astro.build) (fast static pages, almost no JavaScript) and deployed to GitHub Pages by
`.github/workflows/pages.yml` on every push to `main`:
**https://ridgevalley111243.github.io/trutechwebsite/**

```bash
npm install
npm run dev      # local preview at http://localhost:4321/trutechwebsite/
npm run check    # type-check
npm run build    # production build into dist/
```

## Managing the site (admin page)
Add and edit portfolio projects, upload images and change your contact details from any browser, including a phone:
**https://ridgevalley111243.github.io/trutechwebsite/admin/**

The admin page is [Sveltia CMS](https://sveltiacms.app). Every save is a commit to `main`, so the site redeploys
with the change in about a minute. Its settings are in `public/admin/config.yml`.

**First sign-in** (once per device): create a GitHub access token that can only edit this repository.
1. Open https://github.com/settings/personal-access-tokens/new (signed in to GitHub).
2. Name it "Trutech admin", pick an expiration (up to a year), and under **Repository access** choose
   **Only select repositories** → `trutechwebsite`.
3. Under **Permissions → Repository permissions**, set **Contents** to **Read and write**.
4. Generate the token and copy it.
5. On the admin page, tap **Sign In Using Access Token** and paste it.

The browser remembers the token. Only sign in on your own devices; sign out from the menu on a shared one, and if a
token leaks, delete it on GitHub and create a new one. When it expires, create a new one the same way.

**Portfolio** holds everything on the Work page:
- **Type** is shown above the title, and the part before "·" becomes a Work page filter
  (e.g. `Graphic design`, `Website`, `Web application · EdTech`).
- **Cover image** is shown on the card; without one a branded cover is generated.
- **Gallery** images appear on the project page in order. Give each a short description.
- **Show on home page** puts the project in Selected work (the first three by **Order**).
- Uploaded images are converted to WebP and scaled to at most 1600px wide, so phone photos stay light.

**Settings** holds your name, email, phone, WhatsApp and social links. Social links pick an icon from the brand marks in
`src/components/Icon.astro` (more can be copied from [Simple Icons](https://simpleicons.org)).

## Editing by hand
Projects are Markdown files in **`src/content/projects/`** and contact details are in **`src/data/settings.json`**;
the admin page edits the same files. Other text (tagline, intro, services, about, toolkit, process) is in
**`src/site.ts`**. A project file looks like this:

```yaml
title: Project name
client: Client name
category: Web application · EdTech   # the part before "·" becomes a filter on the Work page
year: 2026
status: Live | Completed | In development | Planned
summary: One or two sentences shown on the card.
services: [Web design, Supabase]
cover: /work/my-project.webp         # optional image in public/work/
gallery:                             # optional extra images
  - { src: /work/my-project-2.webp, alt: Dashboard on mobile }
link: https://…                      # optional live link
featured: true                       # show on the home page (top 3 by order)
order: 1
```

## Client work (private links)
Clients get a private link where they can view and download their files. Because this repository is public, the
files are **encrypted**: the repo and the website only hold scrambled data, and the key is the part of the link after
`#`, which browsers never send to the server.

```bash
npm run client -- new "Client name"        # creates clients-private/client-name/
# put the files in clients-private/client-name/files/ and edit client.json
npm run client -- publish client-name      # encrypts into public/c/<id>/ and prints the link
git add public/c && git commit -m "Client delivery" && git push
```

- Send the printed link to the client. **Keep a copy** (it's also saved in `clients-private/LINKS.txt`): the key
  isn't stored anywhere else, so a lost link can't be recovered. Just publish again with `--new-link`.
- `clients-private/` contains the original files and keys and is git-ignored: never commit it.
- Re-publishing keeps the same link; `--new-link` issues a new one (the old link stops working).
- `npm run client -- remove client-name` takes a delivery offline.
- Images, PDFs, video and audio preview in the page; anything else is a download. For files over 95 MB (long
  videos), upload them to YouTube (unlisted) or Google Drive and add them under `links` in `client.json`.

## Brand
- **Colours** (`src/styles/global.css`): `#0A1931` navy, `#1A3D63`, `#4A7FA7`, `#B3CFE5`, `#F6FAFD`.
- **Fonts**: headings use **Al Ragas**. Add the font file as `public/fonts/AlRagas.woff2` (or `.otf`/`.ttf`) and
  it's used automatically; until then the similar Google font *Gloock* is shown. Body text is *Montserrat*.
- **Logo files**: `public/brand/` (transparent leaf mark, light variant, logo for dark backgrounds, icons and the
  social sharing image).
