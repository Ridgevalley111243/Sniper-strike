// Everything about you, in one place. Name, contact details and social links
// are edited in the admin (Settings); all wording is edited under Site text
// (defaults in src/lib/texts.ts). Both are read from Supabase at build time.
import { settings } from './lib/build-data';
import { t, tl } from './lib/t';
import { PROCESS_COUNT, ROLE_COUNT, SERVICE_COUNT, STAT_COUNT, TOOL_COUNT } from './lib/texts';

const range = (n: number) => Array.from({ length: n }, (_, i) => i + 1);
// Icons for the services, in order: brand, web, code, growth, support, design, chat
const SERVICE_ICONS = ['web', 'code', 'growth', 'brand', 'support'];

export const site = {
  brand: 'Trutech Business',
  tagline: t('brand.tagline'),
  role: t('about.lead'),
  description: t('brand.description'),
  ...settings,

  about: {
    paragraphs: t('about.story')
      .split(/\n\s*\n/)
      .map((p) => p.trim())
      .filter(Boolean),
    stats: range(STAT_COUNT).map((i) => ({ value: t(`stat.${i}.value`), label: t(`stat.${i}.label`) })),
    roles: range(ROLE_COUNT).map((i) => ({ title: t(`role.${i}.title`), text: t(`role.${i}.text`) })),
    toolkit: range(TOOL_COUNT).map((i) => ({ area: t(`tool.${i}.area`), tools: tl(`tool.${i}.tools`) })),
  },

  services: range(SERVICE_COUNT).map((i) => ({
    icon: SERVICE_ICONS[i - 1] ?? 'web',
    title: t(`service.${i}.title`),
    text: t(`service.${i}.text`),
    points: tl(`service.${i}.points`),
  })),

  process: range(PROCESS_COUNT).map((i) => ({ title: t(`process.${i}.title`), text: t(`process.${i}.text`) })),

  /** Shown only once you add real ones. */
  testimonials: [] as { quote: string; name: string; role: string }[],
};

export const whatsappLink = (text = t('brand.whatsappHello')) =>
  site.whatsapp ? `https://wa.me/${site.whatsapp}?text=${encodeURIComponent(text)}` : '';
