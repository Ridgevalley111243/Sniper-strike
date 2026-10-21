// @ts-check
import { defineConfig } from 'astro/config';

// GitHub Pages serves this repo's site under /Sniper-strike/. When you add a
// custom domain, set `site` to it and remove `base`.
export default defineConfig({
  site: 'https://ridgevalley111243.github.io',
  base: '/Sniper-strike',
  trailingSlash: 'ignore',
});
