#!/usr/bin/env python3
"""
MirrorMan Font Downloader
Run this script once to download all required fonts locally.
Then open index.html in your browser — no internet needed.
"""
import os, sys, urllib.request, zipfile, io

FONTS_DIR = os.path.join(os.path.dirname(__file__), "fonts")
os.makedirs(FONTS_DIR, exist_ok=True)

FONTS = [
    # Vazirmatn (Persian/Farsi UI font) - multiple weights
    ("Vazirmatn-Regular",    "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/webfonts/Vazirmatn-Regular.woff2"),
    ("Vazirmatn-Medium",     "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/webfonts/Vazirmatn-Medium.woff2"),
    ("Vazirmatn-SemiBold",   "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/webfonts/Vazirmatn-SemiBold.woff2"),
    ("Vazirmatn-Bold",       "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/webfonts/Vazirmatn-Bold.woff2"),
    ("Vazirmatn-ExtraBold",  "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/webfonts/Vazirmatn-ExtraBold.woff2"),
    ("Vazirmatn-Light",      "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/webfonts/Vazirmatn-Light.woff2"),
    # JetBrains Mono (code font)
    ("JetBrainsMono-Regular",  "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/webfonts/JetBrainsMono-Regular.woff2"),
    ("JetBrainsMono-Medium",   "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/webfonts/JetBrainsMono-Medium.woff2"),
    ("JetBrainsMono-Bold",     "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/webfonts/JetBrainsMono-Bold.woff2"),
]

def download(name, url):
    dest = os.path.join(FONTS_DIR, f"{name}.woff2")
    if os.path.exists(dest):
        print(f"  [SKIP] {name}.woff2 already exists")
        return True
    print(f"  [GET]  {name}.woff2 ...", end=" ", flush=True)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as r, open(dest, "wb") as f:
            f.write(r.read())
        print("OK")
        return True
    except Exception as e:
        print(f"FAIL: {e}")
        return False

if __name__ == "__main__":
    print("\n🪞 MirrorMan — Font Downloader\n")
    ok = all(download(n, u) for n, u in FONTS)
    if ok:
        print("\n✅ All fonts downloaded to web/fonts/")
        print("   Open web/index.html in your browser.\n")
    else:
        print("\n⚠️  Some fonts failed. Check your connection and retry.\n")
        sys.exit(1)
