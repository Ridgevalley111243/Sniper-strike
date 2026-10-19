"""Gives a Flutter web build file names that change with every build.

Flutter always emits main.dart.js and flutter_bootstrap.js under the same
names, and hosts like GitHub Pages let browsers reuse cached copies, so
visitors can keep running an old version after a deploy. This renames
main.dart.js to main.<hash>.dart.js (pointing the bootstrap at it) and loads
the bootstrap with ?v=<hash>, so a new build is always fetched fresh.

Usage: python3 tool/cache_bust_web_build.py [build/web]
"""
import hashlib
import os
import sys

root = sys.argv[1] if len(sys.argv) > 1 else "build/web"


def digest(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:12]


main = os.path.join(root, "main.dart.js")
hashed = f"main.{digest(main)}.dart.js"
os.replace(main, os.path.join(root, hashed))

bootstrap = os.path.join(root, "flutter_bootstrap.js")
with open(bootstrap) as f:
    js = f.read()
if '"mainJsPath":"main.dart.js"' not in js:
    sys.exit("flutter_bootstrap.js: mainJsPath not found; the Flutter build format changed")
with open(bootstrap, "w") as f:
    f.write(js.replace('"mainJsPath":"main.dart.js"', f'"mainJsPath":"{hashed}"'))

index = os.path.join(root, "index.html")
with open(index) as f:
    html = f.read()
tag = 'src="flutter_bootstrap.js"'
if tag not in html:
    sys.exit("index.html: bootstrap script tag not found")
with open(index, "w") as f:
    f.write(html.replace(tag, f'src="flutter_bootstrap.js?v={digest(bootstrap)}"'))
print(f"main.dart.js -> {hashed}")
