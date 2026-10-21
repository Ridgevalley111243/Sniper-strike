import type { APIRoute } from 'astro';

// Keep private client deliveries out of search engines, wherever the site is hosted.
export const GET: APIRoute = () => {
  const base = import.meta.env.BASE_URL.replace(/\/?$/, '/');
  return new Response(`User-agent: *\nDisallow: ${base}client/\nDisallow: ${base}c/\nDisallow: ${base}admin/\n`, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
