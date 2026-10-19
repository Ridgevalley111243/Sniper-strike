"""Drops unused font families from a Flutter web build.

The web engine downloads every family in FontManifest.json at startup.
lucide_icons_flutter bundles six weight-variant fonts (~3 MB) next to the
base `Lucide` family; TRUHive only uses `Lucide`, so the variants are removed.

Usage: python3 tool/slim_web_build.py [build/web]
"""
import json
import os
import re
import sys

UNUSED = re.compile(r"^packages/lucide_icons_flutter/Lucide\d+$")

root = sys.argv[1] if len(sys.argv) > 1 else "build/web"
manifest = os.path.join(root, "assets", "FontManifest.json")
with open(manifest) as f:
    families = json.load(f)

kept, removed = [], 0
for family in families:
    if not UNUSED.match(family["family"]):
        kept.append(family)
        continue
    for font in family["fonts"]:
        path = os.path.join(root, "assets", font["asset"])
        if os.path.exists(path):
            removed += os.path.getsize(path)
            os.remove(path)

with open(manifest, "w") as f:
    json.dump(kept, f, separators=(",", ":"))
print(f"Removed {len(families) - len(kept)} unused font families ({removed / 1e6:.1f} MB)")
