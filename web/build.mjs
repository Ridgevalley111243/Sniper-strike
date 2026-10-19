// Bundles the game into the Android app's assets folder.
//   node build.mjs          -> production build
//   node build.mjs --serve  -> build + local dev server on http://localhost:8080
import * as esbuild from 'esbuild';
import { cpSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, '../android/app/src/main/assets/www');
const serve = process.argv.includes('--serve');

mkdirSync(out, { recursive: true });
for (const f of ['index.html', 'style.css']) cpSync(resolve(here, f), resolve(out, f));

const opts = {
  entryPoints: [resolve(here, 'src/main.js')],
  bundle: true,
  format: 'esm',
  target: ['chrome90'],
  minify: !serve,
  sourcemap: serve,
  outfile: resolve(out, 'game.js'),
  logLevel: 'info',
};

if (serve) {
  const ctx = await esbuild.context(opts);
  await ctx.watch();
  const { port } = await ctx.serve({ servedir: out, port: 8080 });
  console.log(`Dev server: http://localhost:${port}`);
} else {
  await esbuild.build(opts);
}
