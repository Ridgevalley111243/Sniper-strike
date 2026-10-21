import type { APIRoute } from 'astro';

// Keep private client pages out of search engines, wherever the site is hosted.
// The admin isn't listed here, to keep it hidden; it is noindex instead.
export const GET: APIRoute = () => {
  const base = import.meta.env.BASE_URL.replace(/\/?$/, '/');
  return new Response(`User-agent: *\nDisallow: ${base}client/\n`, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
