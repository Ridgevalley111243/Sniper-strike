import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

// Image paths may be written as "work/x.webp" or "/work/x.webp" (the admin
// page saves the second form); both are served under the site's base path.
const asset = z.string().transform((s) => s.trim().replace(/^\/+/, ''));

// Portfolio projects: one Markdown file each in src/content/projects/,
// usually added and edited through the admin page (public/admin/).

const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    title: z.string(),
    client: z.string(),
    category: z.string(),
    year: z.coerce.number(),
    summary: z.string(),
    /** Image in public/work/, e.g. "work/acme-cover.jpg". Leave out for a branded placeholder. */
    cover: asset.optional().transform((s) => s || undefined),
    gallery: z
      .array(z.object({ src: asset, alt: z.string().nullish().transform((s) => s ?? '') }))
      .nullish()
      .transform((g) => (g ?? []).filter((i) => i.src)),
    services: z
      .array(z.string())
      .nullish()
      .transform((s) => s ?? []),
    // The admin saves an emptied field as "".
    link: z.union([z.url(), z.literal('')]).nullish().transform((s) => s || undefined),
    /** Be honest about where a project stands; it is shown on the card. */
    status: z.enum(['Live', 'Completed', 'In development', 'Planned']),
    featured: z.boolean().nullish().transform((b) => b ?? false),
    order: z.coerce.number().nullish().transform((n) => n ?? 0),
  }),
});

export const collections = { projects };
