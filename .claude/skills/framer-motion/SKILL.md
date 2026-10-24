---
name: framer-motion
description: Build animations with Framer Motion (also published as Motion) — React components (motion.div, AnimatePresence, layout animations, gestures, scroll-linked effects) and the framework-free DOM API (animate, scroll, inView, stagger) for Astro, plain HTML or any non-React site. Use whenever the user asks to animate, add motion, transitions, entrance/exit effects, hover or tap effects, page transitions, parallax, scroll reveals, or mentions framer-motion / motion.
---

# Framer Motion

Framer Motion (v11+; the same library is also published as `motion`) has two halves:

| Project | Import from | What you use |
| --- | --- | --- |
| React (Next.js, Vite, Astro islands) | `framer-motion` (or `motion/react`) | `<motion.div>`, `AnimatePresence`, hooks |
| No React (Astro pages, plain HTML/JS) | `framer-motion/dom` (or `motion`) | `animate()`, `scroll()`, `inView()`, `stagger()`, `hover()`, `press()` |

First check which one fits: look at `package.json` for `react`. Don't add React only to animate. The DOM API covers entrances, scroll effects, hovers and sequences without it.

Install: `npm i framer-motion`. React and react-dom are optional peer dependencies; only the React half needs them.

## Rules that always apply

- **Respect reduced motion.** React: wrap the app in `<MotionConfig reducedMotion="user">`, or check `useReducedMotion()`. DOM: check `matchMedia('(prefers-reduced-motion: reduce)').matches` and skip or shorten the motion.
- **Animate `transform` and `opacity`** (x, y, scale, rotate, opacity). Avoid animating width, height, top and left; use `layout` animations instead.
- **Content must be visible without JavaScript.** Don't ship HTML hidden with CSS that only JavaScript reveals, unless you add a no-JS fallback. Set the hidden start state from the script, or from a `.js` class set early in `<head>`.
- **Keep it short:** UI feedback 150–250 ms, entrances 300–600 ms. Prefer springs for things the user touches.
- **Exits need `AnimatePresence`**, and each child needs a stable `key`.
- **Bundle size:** for many small animated elements in React, use `LazyMotion` + `m` (`import { LazyMotion, domAnimation, m } from 'framer-motion'`).

## React

```tsx
import { motion, AnimatePresence, MotionConfig } from 'framer-motion';

<MotionConfig reducedMotion="user">
  <motion.section
    initial={{ opacity: 0, y: 24 }}
    whileInView={{ opacity: 1, y: 0 }}
    viewport={{ once: true, amount: 0.3 }}
    transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
  />
</MotionConfig>
```

- **Gestures:** `whileHover={{ scale: 1.03 }}`, `whileTap={{ scale: 0.97 }}`, `whileFocus`, `drag`, `drag="x"`, `dragConstraints={ref}`.
- **Transitions:** `{ type: 'spring', stiffness: 300, damping: 30 }`, `{ duration, ease, delay }`, and `repeat: Infinity, repeatType: 'reverse'`.
- **Variants and stagger:**
  ```tsx
  const list = { hidden: {}, show: { transition: { staggerChildren: 0.08 } } };
  const item = { hidden: { opacity: 0, y: 16 }, show: { opacity: 1, y: 0 } };
  <motion.ul variants={list} initial="hidden" whileInView="show" viewport={{ once: true }}>
    {items.map((i) => <motion.li key={i.id} variants={item} />)}
  </motion.ul>
  ```
- **Exit animations:**
  ```tsx
  <AnimatePresence mode="wait">
    {open && <motion.div key="panel" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} />}
  </AnimatePresence>
  ```
- **Layout:** `layout` animates size and position changes. `layoutId="pill"` on two elements makes a shared-element move, such as an active tab underline. Group related ones in `<LayoutGroup>`.
- **Scroll-linked effects:**
  ```tsx
  const ref = useRef(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] });
  const y = useTransform(scrollYProgress, [0, 1], [-60, 60]);
  const smooth = useSpring(y, { stiffness: 120, damping: 20 });
  <motion.img ref={ref} style={{ y: smooth }} />
  ```
  Use `useScroll()` with no target for page progress bars, with `style={{ scaleX: scrollYProgress }}`.
- **Imperative sequences:** `const [scope, animate] = useAnimate(); await animate(scope.current, { opacity: 1 }); await animate('li', { x: 0 }, { delay: stagger(0.05) });`
- **Other hooks:** `useMotionValue`, `useMotionValueEvent(value, 'change', fn)`, `useInView(ref, { once: true })`, `useMotionTemplate`, `useAnimationFrame`, `useReducedMotion`, `useDragControls`, `useIsPresent`.
- **Reordering:** `<Reorder.Group axis="y" values={items} onReorder={setItems}>` with `<Reorder.Item value={item}>`.
- **Next.js App Router:** motion components are client-only, so add `'use client'` to files that use them.
- **Astro:** put React motion components in islands with `client:visible` (or `client:load` for above-the-fold content). For simple page effects, prefer the DOM API below, which needs no React.

## No React: the DOM API

```ts
import { animate, scroll, inView, stagger, hover, press } from 'framer-motion/dom';

const calm = matchMedia('(prefers-reduced-motion: reduce)').matches;

// Reveal on scroll, staggered, once
inView('.reveal', (el) => {
  if (!calm) animate(el, { opacity: [0, 1], y: [24, 0] }, { duration: 0.5, ease: [0.22, 1, 0.36, 1] });
}, { amount: 0.3 });

// Stagger a group
animate('.card', { opacity: [0, 1], y: [16, 0] }, { delay: stagger(0.08) });

// Scroll-linked: progress bar and parallax
scroll(animate('.progress', { scaleX: [0, 1] }, { ease: 'linear' }));
scroll(animate('.hero img', { y: [0, 120] }, { ease: 'linear' }), {
  target: document.querySelector('.hero')!, offset: ['start start', 'end start'],
});

// Gestures
hover('.btn', (el) => { animate(el, { scale: 1.04 }); return () => animate(el, { scale: 1 }); });
press('.btn', (el) => { animate(el, { scale: 0.96 }); return () => animate(el, { scale: 1 }); });

// Springs and sequences
animate('.badge', { rotate: 90 }, { type: 'spring', stiffness: 400, damping: 20 });
await animate([
  ['.title', { opacity: [0, 1], y: [20, 0] }],
  ['.sub', { opacity: [0, 1] }, { at: '-0.2' }],
]);
```

- `animate()` returns controls: `.play()`, `.pause()`, `.stop()`, `.cancel()`, `.time`, `.speed`, and it can be awaited (`.then`).
- `inView` and `scroll` return a stop function. Call it when you remove the element, or on page swaps with View Transitions.
- In Astro, put this in a `<script>` in the component. Astro bundles it, and it runs once per page load.

## Before you finish

1. Check with reduced motion on: Chrome DevTools → Rendering → Emulate `prefers-reduced-motion`.
2. Check that the content shows with JavaScript disabled.
3. Look for layout shift or overflow at phone width (about 390px).
4. Make sure nothing animates forever without a reason, and that animated things can still be clicked and focused.
