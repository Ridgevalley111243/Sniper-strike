{{flutter_js}}
{{flutter_build_config}}

// Load the rendering engine from this app's own files (not a CDN) so the
// installed web app also starts while offline.
_flutter.loader.load({
  config: { canvasKitBaseUrl: "canvaskit/" },
});
