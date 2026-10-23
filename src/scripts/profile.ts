// Shows the current profile photo (Settings in the admin) without waiting for
// the next rebuild. Slots are elements with data-photo-slot; data-photo holds
// the photo the page was built with, data-fallback the image shown without one.
//
// The photo stays hidden (global.css) until this has checked which photo is
// current, so a photo replaced since the last build never flashes on screen.
import { fetchSettings } from '../lib/content';

const reveal = (slot: HTMLElement) => slot.classList.add('photo-ready');

async function show(slot: HTMLElement, photo: string, owner: string) {
  const img = slot.querySelector('img')!;
  if ((slot.dataset.photo ?? '') !== photo) {
    slot.dataset.photo = photo;
    slot.classList.toggle('has-photo', Boolean(photo));
    if (!slot.dataset.fallback) slot.hidden = !photo;
    img.src = photo || slot.dataset.fallback || '';
    img.alt = photo ? `Photo of ${owner || 'the founder of Trutech Business'}` : '';
  }
  // Fade in once the right image is ready to draw.
  await img.decode().catch(() => {});
  reveal(slot);
}

export async function liveProfilePhoto() {
  const slots = [...document.querySelectorAll<HTMLElement>('[data-photo-slot]')];
  if (!slots.length) return;
  // If the check takes too long (slow connection), show what the page has.
  const fallback = setTimeout(() => slots.forEach(reveal), 4000);
  try {
    const { photo, owner } = await fetchSettings();
    await Promise.all(slots.map((slot) => show(slot, photo, owner)));
  } finally {
    clearTimeout(fallback);
    slots.forEach(reveal);
  }
}
