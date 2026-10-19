{{flutter_js}}
{{flutter_build_config}}

// Hide the HTML loading screen once Flutter paints its first frame.
window.addEventListener("flutter-first-frame", () => {
  const el = document.getElementById("loading");
  if (!el) return;
  el.classList.add("done");
  setTimeout(() => el.remove(), 400);
});

// Load the rendering engine from this app's own files (not a CDN) so the
// installed web app also starts while offline.
_flutter.loader.load({
  config: { canvasKitBaseUrl: "canvaskit/" },
});
