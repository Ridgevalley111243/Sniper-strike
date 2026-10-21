// Shows the current profile photo (Settings in the admin) without waiting for
// the next rebuild. Slots are elements with data-photo-slot; data-photo holds
// the photo the page was built with, data-fallback the image shown without one.
import { fetchSettings } from '../lib/content';

export async function liveProfilePhoto() {
  const slots = document.querySelectorAll<HTMLElement>('[data-photo-slot]');
  if (!slots.length) return;
  const { photo, owner } = await fetchSettings();
  slots.forEach((slot) => {
    if ((slot.dataset.photo ?? '') === photo) return;
    slot.dataset.photo = photo;
    slot.classList.toggle('has-photo', Boolean(photo));
    if (!slot.dataset.fallback) slot.hidden = !photo;
    const img = slot.querySelector('img')!;
    img.src = photo || slot.dataset.fallback || '';
    img.alt = photo ? `Photo of ${owner || 'the founder of Trutech Business'}` : '';
  });
}
