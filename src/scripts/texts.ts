// Shows site text edited in the admin (Site text) before the next rebuild:
// every element with data-t="key" gets the newer wording, if there is one.
import { fetchSettings } from '../lib/content';
import { formatText } from '../lib/render';

export async function liveTexts() {
  const els = document.querySelectorAll<HTMLElement>('[data-t]');
  if (!els.length) return;
  const { texts } = await fetchSettings();
  els.forEach((el) => {
    const value = texts[el.dataset.t!];
    if (typeof value !== 'string' || !value.trim()) return;
    const html = formatText(el.dataset.tKind ?? 'line', value);
    if (el.innerHTML !== html) el.innerHTML = html;
  });
}
