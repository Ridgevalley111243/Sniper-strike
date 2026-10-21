// Keeps portfolio sections up to date with the admin. Pages are built with the
// content from the last deploy; this fetches the current projects and redraws
// a section only when it has changed, so edits show up straight away.
import { featuredOf, fetchProjects, fingerprint, groupOf, projectFingerprint, type Project } from '../lib/content';
import { cardHTML, filtersHTML, projectHTML, workGridHTML } from '../lib/render';

const base = document.documentElement.dataset.base ?? '/';
let request: Promise<Project[]> | undefined;
const latest = () => (request ??= fetchProjects());

/** The home page's Selected work. */
export async function liveFeatured(el: HTMLElement) {
  const featured = featuredOf(await latest());
  if (fingerprint(featured) === el.dataset.fp) return;
  el.innerHTML = featured.map((p, i) => cardHTML(p, i, base)).join('');
  el.dataset.fp = fingerprint(featured);
}

/** The Work page grid and its filters. */
export async function liveWork(grid: HTMLElement, filters: HTMLElement) {
  const projects = await latest();
  if (fingerprint(projects) === grid.dataset.fp) return;
  grid.innerHTML = workGridHTML(projects, base, groupOf);
  filters.innerHTML = filtersHTML([...new Set(projects.map(groupOf))]);
  grid.dataset.fp = fingerprint(projects);
}

/** Filter buttons; delegated so they keep working after a redraw. */
export function bindFilters(grid: HTMLElement, filters: HTMLElement) {
  filters.addEventListener('click', (e) => {
    const b = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-filter]');
    if (!b) return;
    filters.querySelectorAll('[data-filter]').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
    grid.querySelectorAll<HTMLElement>('[data-group]').forEach((el) => {
      el.hidden = b.dataset.filter !== 'all' && el.dataset.group !== b.dataset.filter;
    });
  });
}

/** A project page. Also draws projects added since the last deploy (from the 404 page). */
export async function liveProject(el: HTMLElement, slug: string) {
  const projects = await latest();
  const i = projects.findIndex((p) => p.slug === slug);
  if (i < 0) {
    el.innerHTML = `<section class="container pd-head"><p class="eyebrow">Work</p><h1>This project isn’t available.</h1><p class="lead">It may have been removed or renamed.</p><a class="btn btn-primary" href="${base}work/">See all work</a></section>`;
    document.title = 'Project not found · Trutech Business';
    return;
  }
  const fp = projectFingerprint(projects, i);
  if (fp === el.dataset.fp) return;
  const n = (i + 1) % projects.length;
  el.innerHTML = projectHTML(projects[i], i, base, { project: projects[n], index: n });
  el.dataset.fp = fp;
  document.title = `${projects[i].title} · Trutech Business`;
  document.querySelector('meta[name="description"]')?.setAttribute('content', projects[i].summary);
}
