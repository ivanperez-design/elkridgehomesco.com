#!/usr/bin/env python3
"""Generate Elk Ridge Home logo web variants from the white-bg master.
Deterministic, local (Pillow + numpy). No network, no purchases."""
from PIL import Image
import numpy as np
import os

OUT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(OUT, "erh-logo-master.png")

im = Image.open(SRC).convert("RGB")
arr = np.asarray(im).astype(np.int16)
H, W, _ = arr.shape

# Background = average of the four corners (should be ~white)
corners = np.array([arr[2, 2], arr[2, W-3], arr[H-3, 2], arr[H-3, W-3]])
bg = corners.mean(axis=0)
print("bg sampled:", bg.round(1).tolist())

# Alpha from distance to background (white) -> feathered edges, flat white removed
dist = np.max(np.abs(arr - bg), axis=2)            # 0..255
alpha = np.clip(dist * 6.0, 0, 255).astype(np.uint8)
rgb = arr.clip(0, 255).astype(np.uint8)

color = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")

# All-white silhouette (for dark backgrounds): RGB=255, keep alpha
white = Image.fromarray(np.dstack([
    np.full((H, W), 255, np.uint8),
    np.full((H, W), 255, np.uint8),
    np.full((H, W), 255, np.uint8),
    alpha]), "RGBA")

def trim(img):
    bb = img.getbbox()
    return img.crop(bb) if bb else img

# --- Horizontal web logos (transparent) ---
def save_scaled(img, target_w, path):
    img = trim(img)
    w, h = img.size
    nh = round(h * target_w / w)
    img.resize((target_w, nh), Image.LANCZOS).save(path)
    print("saved", os.path.basename(path), f"{target_w}x{nh}")

save_scaled(color, 1100, os.path.join(OUT, "erh-logo-horizontal.png"))
save_scaled(white, 1100, os.path.join(OUT, "erh-logo-horizontal-white.png"))

# --- Isolate the elk+mountain MARK (left cluster) for the favicon ---
strong = (alpha > 80)                     # only solid art, ignore feathered edges
col_count = strong.sum(axis=0)            # strong pixels per column
content = np.where(col_count > 0)[0]
first = int(content[0])
gap_need = 35
run = 0; mark_end = None
for x in range(first, int(W*0.6)):        # the mark lives in the left portion
    if col_count[x] == 0:                 # truly empty (full-height) column
        run += 1
        if run >= gap_need:
            mark_end = x - run + 1        # first empty column = end of mark
            break
    else:
        run = 0
if mark_end is None:
    mark_end = int(W*0.4)                 # safe fallback
print("mark columns:", first, "->", mark_end)
sub = strong[:, first:mark_end]
rows = np.where(sub.max(axis=1))[0]
r0, r1 = int(rows[0]), int(rows[-1])
mark = color.crop((first, r0, mark_end, r1+1))
mw, mh = mark.size
pad = int(max(mw, mh) * 0.12)
s = max(mw, mh) + pad*2
canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
canvas.paste(mark, ((s-mw)//2, (s-mh)//2), mark)
canvas.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "erh-favicon-512.png"))
canvas.resize((180, 180), Image.LANCZOS).save(os.path.join(OUT, "erh-favicon-180.png"))
canvas.resize((32, 32), Image.LANCZOS).save(os.path.join(OUT, "erh-favicon-32.png"))
print("saved favicons 512/180/32 from mark", mark.size)

# --- OG social card 1200x630, cream bg, centered color logo ---
og = Image.new("RGBA", (1200, 630), (245, 241, 234, 255))   # --cream #F5F1EA
lg = trim(color)
lw = 760
lh = round(lg.height * lw / lg.width)
og.alpha_composite(lg.resize((lw, lh), Image.LANCZOS), ((1200-lw)//2, (630-lh)//2))
og.convert("RGB").save(os.path.join(OUT, "erh-og-card.png"))
print("saved erh-og-card.png 1200x630")
print("DONE")
