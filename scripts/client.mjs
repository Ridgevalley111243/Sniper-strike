#!/usr/bin/env node
// Private client deliveries, encrypted so they can live in a public repo.
//
//   npm run client -- new "Client name"     create clients-private/<slug>/ to fill in
//   npm run client -- publish <slug>        encrypt it into public/c/<id>/ and print the link
//   npm run client -- remove <slug>         delete the published (encrypted) files
//
// clients-private/ holds your original files and each client's key. It is
// git-ignored: never commit it. Without the key a delivery can't be opened,
// so keep every client link somewhere safe.
import { createCipheriv, randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { basename, extname, join } from 'node:path';

// Where the site is published (matches astro.config.mjs).
const SITE = `${process.env.SITE_URL ?? 'https://ridgevalley111243.github.io'}${process.env.BASE_PATH ?? '/trutechwebsite'}`.replace(/\/$/, '');
const PRIVATE = 'clients-private';
const PUBLIC = 'public/c';
const MAX_FILE = 95 * 1024 * 1024; // GitHub rejects files over 100 MB

const KINDS = {
  image: ['.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg', '.avif'],
  video: ['.mp4', '.webm', '.mov', '.m4v'],
  audio: ['.mp3', '.wav', '.m4a', '.ogg'],
  pdf: ['.pdf'],
};
const MIME = {
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.gif': 'image/gif',
  '.svg': 'image/svg+xml', '.avif': 'image/avif', '.mp4': 'video/mp4', '.webm': 'video/webm', '.mov': 'video/quicktime',
  '.m4v': 'video/mp4', '.mp3': 'audio/mpeg', '.wav': 'audio/wav', '.m4a': 'audio/mp4', '.ogg': 'audio/ogg',
  '.pdf': 'application/pdf', '.zip': 'application/zip',
};

const b64url = (buf) => buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const slugify = (s) => s.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'client';
const kindOf = (file) => Object.entries(KINDS).find(([, exts]) => exts.includes(extname(file).toLowerCase()))?.[0] ?? 'file';

/** AES-256-GCM: output is iv (12 bytes) ‖ ciphertext ‖ tag, what WebCrypto expects. */
function encrypt(key, plain) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  return Buffer.concat([iv, cipher.update(plain), cipher.final(), cipher.getAuthTag()]);
}

function die(message) {
  console.error(`\n✗ ${message}\n`);
  process.exit(1);
}

function create(name) {
  if (!name) die('Give the client a name:  npm run client -- new "Client name"');
  const slug = slugify(name);
  const dir = join(PRIVATE, slug);
  if (existsSync(dir)) die(`${dir} already exists.`);
  mkdirSync(join(dir, 'files'), { recursive: true });
  const config = {
    client: name,
    project: 'Project name',
    status: 'Ready for review',
    date: new Date().toISOString().slice(0, 10),
    message: 'Hello! Here are the files for your project. Let me know what you think.',
    // Optional per-file titles/notes, keyed by file name in files/. Files not
    // listed here are still included, titled by their file name.
    items: { 'example.pdf': { title: 'Example title', note: 'Optional note' } },
    // Extra links (e.g. a large video on YouTube/Drive, or a live preview).
    links: [{ title: 'Live preview', url: 'https://example.com', note: 'Optional note' }],
  };
  writeFileSync(join(dir, 'client.json'), JSON.stringify(config, null, 2) + '\n');
  console.log(`\n✓ Created ${dir}/\n  1. Put the client's files in ${dir}/files/\n  2. Edit ${dir}/client.json\n  3. Run: npm run client -- publish ${slug}\n`);
}

function publish(slug) {
  const dir = join(PRIVATE, slug ?? '');
  const configPath = join(dir, 'client.json');
  if (!slug || !existsSync(configPath)) die(`No client "${slug}". Create one with: npm run client -- new "Client name"`);
  const config = JSON.parse(readFileSync(configPath, 'utf8'));

  // Keep the same link across re-publishes unless --new-link is passed.
  if (!config.id || !config.key || process.argv.includes('--new-link')) {
    if (config.id) rmSync(join(PUBLIC, config.id), { recursive: true, force: true });
    config.id = b64url(randomBytes(12));
    config.key = b64url(randomBytes(32));
  }
  const key = Buffer.from(config.key.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
  const out = join(PUBLIC, config.id);
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });

  const filesDir = join(dir, 'files');
  const files = existsSync(filesDir) ? readdirSync(filesDir).filter((f) => !f.startsWith('.') && statSync(join(filesDir, f)).isFile()) : [];
  const items = [];
  files.sort().forEach((file, i) => {
    const plain = readFileSync(join(filesDir, file));
    if (plain.length > MAX_FILE) die(`${file} is over 95 MB. Upload it to YouTube/Google Drive and add it under "links" instead.`);
    const encName = `${String(i + 1).padStart(3, '0')}.bin`; // no original names in the public repo
    writeFileSync(join(out, encName), encrypt(key, plain));
    const meta = config.items?.[file] ?? {};
    items.push({
      title: meta.title ?? basename(file, extname(file)).replace(/[-_]+/g, ' '),
      note: meta.note,
      kind: kindOf(file),
      file: encName,
      name: file,
      mime: MIME[extname(file).toLowerCase()] ?? 'application/octet-stream',
      size: plain.length,
    });
  });
  for (const link of config.links ?? []) {
    if (link.url && !link.url.includes('example.com')) items.push({ title: link.title, note: link.note, kind: 'link', url: link.url });
  }
  if (items.length === 0) die(`Add files to ${filesDir}/ or links to client.json first.`);

  const manifest = {
    client: config.client,
    project: config.project,
    status: config.status,
    date: config.date,
    message: config.message,
    items,
  };
  writeFileSync(join(out, 'manifest.bin'), encrypt(key, Buffer.from(JSON.stringify(manifest))));
  writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');

  const link = `${SITE}/client/#${config.id}.${config.key}`;
  const links = join(PRIVATE, 'LINKS.txt');
  const others = existsSync(links) ? readFileSync(links, 'utf8').split('\n').filter((l) => l && !l.startsWith(`${slug}\t`)) : [];
  writeFileSync(links, [...others, `${slug}\t${config.client}\t${link}`].join('\n') + '\n');

  console.log(`\n✓ Encrypted ${items.length} item(s) for ${config.client} into ${out}/`);
  console.log(`\n  Client link (send this to the client and keep a copy; it can't be recovered):\n\n  ${link}\n`);
  console.log('  Commit public/c/ and deploy. Only encrypted data is committed.\n');
}

function remove(slug) {
  const configPath = join(PRIVATE, slug ?? '', 'client.json');
  if (!slug || !existsSync(configPath)) die(`No client "${slug}".`);
  const { id } = JSON.parse(readFileSync(configPath, 'utf8'));
  if (id) rmSync(join(PUBLIC, id), { recursive: true, force: true });
  console.log(`\n✓ Removed the published delivery for ${slug}. Its link no longer works.\n`);
}

const [command, arg] = process.argv.slice(2);
if (command === 'new') create(process.argv.slice(3).filter((a) => !a.startsWith('--')).join(' '));
else if (command === 'publish') publish(arg);
else if (command === 'remove') remove(arg);
else console.log('Usage:\n  npm run client -- new "Client name"\n  npm run client -- publish <slug> [--new-link]\n  npm run client -- remove <slug>');
