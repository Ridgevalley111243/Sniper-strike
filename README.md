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

## Editing your details
Everything about you lives in **`src/site.ts`**: name, tagline, intro, contact details, social links, services,
about text, toolkit, process and testimonials. Contact buttons and footer links appear only for the details that are
set. Social links take an `icon` naming a brand mark in `src/components/Icon.astro` (`whatsapp`, `tiktok`, `x`); more
marks can be copied from [Simple Icons](https://simpleicons.org).

## Portfolio projects
Each project is a Markdown file in **`src/content/projects/`**. Copy one to add another:

```yaml
title: Project name
client: Client name
category: Web application · EdTech   # the part before "·" becomes a filter on the Work page
year: 2026
status: Live | Completed | In development | Planned
summary: One or two sentences shown on the card.
services: [Web design, Supabase]
cover: work/my-project.jpg           # optional image in public/work/
gallery:                             # optional extra images
  - { src: work/my-project-2.jpg, alt: Dashboard on mobile }
link: https://…                      # optional live link
featured: true                       # show on the home page (top 3 by order)
order: 1
```

Without a `cover`, a branded cover is generated from the palette.

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
