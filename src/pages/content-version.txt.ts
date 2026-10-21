import type { APIRoute } from 'astro';
import { version } from '../lib/build-data';

// The content version this build was made from. The Pages workflow compares it
// with Supabase's current version and rebuilds the site when they differ.
export const GET: APIRoute = () => new Response(version, { headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
