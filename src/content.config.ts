import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

// Portfolio projects: one Markdown file each in src/content/projects/.
const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    title: z.string(),
    client: z.string(),
    category: z.string(),
    year: z.number(),
    summary: z.string(),
    /** Image in public/work/, e.g. "work/acme-cover.jpg". Leave out for a branded placeholder. */
    cover: z.string().optional(),
    gallery: z.array(z.object({ src: z.string(), alt: z.string() })).default([]),
    services: z.array(z.string()).default([]),
    link: z.url().optional(),
    /** Be honest about where a project stands; it is shown on the card. */
    status: z.enum(['Live', 'Completed', 'In development', 'Planned']),
    featured: z.boolean().default(false),
    order: z.number().default(0),
  }),
});

export const collections = { projects };
