// Site text for the static build: the wording edited in the admin (Site
// text), or the default from src/lib/texts.ts.
import { settings } from './build-data';
import { FIELDS, fill, linesOf, textOf } from './texts';

const vars = () => ({
  brand: 'Trutech Business',
  email: settings.email,
  phone: settings.phone,
  location: settings.location,
  base: import.meta.env.BASE_URL.replace(/\/?$/, '/'),
});

/** Plain text for a key. */
export const t = (key: string) => textOf(settings.texts, key);
/** List items for a list key. */
export const tl = (key: string) => linesOf(t(key));
/** Text with {brand}, {email}, {phone}, {location} and {base} filled in. */
export const tf = (key: string, extra: Record<string, string> = {}) => fill(t(key), { ...vars(), ...extra });
/** The kind of a key (line, hl, text, …). */
export const kindOf = (key: string) => FIELDS[key]?.kind ?? 'line';

/** Wording for project pages (see projectHTML and liveProject). */
export const projectLabels = () => ({
  back: t('project.back'),
  client: t('project.client'),
  year: t('project.year'),
  status: t('project.status'),
  link: t('project.link'),
  visit: t('project.visit'),
  services: t('project.services'),
  next: t('project.next'),
  missingTitle: t('project.missingTitle'),
  missingText: t('project.missingText'),
  missingButton: t('project.missingButton'),
});
