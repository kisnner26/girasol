"""genera el icono de girasol: papel crema, petalos de trazo en tinta, centro con puntos."""
import math, sys
from PIL import Image, ImageDraw

INK, PAPER = (26, 18, 8), (245, 240, 232)
S = 2048            # se dibuja al doble y se reduce, para bordes suaves
out = sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png"

img = Image.new("RGB", (S, S), PAPER)
d = ImageDraw.Draw(img)
cx = cy = S / 2

def petal(angle, inner, outer, half_w, fill=None, width=14):
    # elipse alargada girada `angle` alrededor del centro
    pts = []
    for k in range(64):
        t = 2 * math.pi * k / 64
        x = half_w * math.cos(t)
        y = -(inner + (outer - inner) / 2) + (outer - inner) / 2 * math.sin(t)
        pts.append((cx + x * math.cos(angle) - y * math.sin(angle), cy + x * math.sin(angle) + y * math.cos(angle)))
    d.polygon(pts, fill=fill, outline=INK, width=width)

N = 12
for i in range(N):
    petal(2 * math.pi * i / N, 300, 880, 150, fill=INK if i % 2 == 0 else PAPER)
r = 260
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=PAPER, outline=INK, width=16)
for k in range(24):
    a = 2 * math.pi * k / 24
    for rad, sz in ((150, 12), (75, 9)):
        x, y = cx + rad * math.cos(a), cy + rad * math.sin(a)
        d.ellipse((x - sz, y - sz, x + sz, y + sz), fill=INK)
img.resize((1024, 1024), Image.LANCZOS).save(out)
print("icono", out)
