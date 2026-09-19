#!/usr/bin/env python3
"""Procedurally generates every sprite the game uses as real PNG files.

Run from the repository root:

    python3 tools/generate_sprites.py

Sprites are written to assets/sprites/. The isometric tile footprint is 128x64 pixels;
a sprite with an s x s footprint is 128*s pixels wide and as tall as it needs to be. The
footprint diamond always sits flush with the bottom edge of the canvas, so the renderer can
place any sprite from its texture size alone (see scripts/render/sprites.gd).

Only the Python standard library is used (zlib for PNG encoding).
"""
import math
import os
import random
import struct
import zlib

TW, TH = 128, 64
HW, HH = TW // 2, TH // 2
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites"))


# --------------------------------------------------------------------------------------
# Tiny raster library
# --------------------------------------------------------------------------------------

def clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


def col(r, g, b, a=255):
    return (int(clamp(r, 0, 255)), int(clamp(g, 0, 255)), int(clamp(b, 0, 255)), int(clamp(a, 0, 255)))


def shade(c, f):
    """Multiply RGB by f (f < 1 darkens, f > 1 lightens)."""
    return col(c[0] * f, c[1] * f, c[2] * f, c[3])


def mix(a, b, t):
    return col(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)


def alpha(c, a):
    return (c[0], c[1], c[2], int(a))


class Canvas:
    def __init__(self, w, h):
        self.w = int(w)
        self.h = int(h)
        self.px = bytearray(self.w * self.h * 4)

    def blend(self, x, y, c):
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        a = c[3]
        if a <= 0:
            return
        i = (y * self.w + x) * 4
        if a >= 255:
            self.px[i:i + 4] = bytes(c)
            return
        da = self.px[i + 3]
        sa = a / 255.0
        if da == 0:
            self.px[i:i + 4] = bytes((c[0], c[1], c[2], a))
            return
        dfa = da / 255.0
        oa = sa + dfa * (1 - sa)
        for k in range(3):
            self.px[i + k] = int((c[k] * sa + self.px[i + k] * dfa * (1 - sa)) / oa)
        self.px[i + 3] = int(oa * 255)

    def hspan(self, x0, x1, y, c):
        if y < 0 or y >= self.h:
            return
        x0 = max(0, int(x0))
        x1 = min(self.w - 1, int(x1))
        for x in range(x0, x1 + 1):
            self.blend(x, y, c)

    def fill_poly(self, pts, c):
        if len(pts) < 3:
            return
        ys = [p[1] for p in pts]
        y0 = max(0, int(math.floor(min(ys))))
        y1 = min(self.h - 1, int(math.ceil(max(ys))))
        n = len(pts)
        for y in range(y0, y1 + 1):
            sy = y + 0.5
            xs = []
            for i in range(n):
                ax, ay = pts[i]
                bx, by = pts[(i + 1) % n]
                if ay == by:
                    continue
                if (sy >= min(ay, by)) and (sy < max(ay, by)):
                    t = (sy - ay) / (by - ay)
                    xs.append(ax + (bx - ax) * t)
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                self.hspan(math.floor(xs[i] + 0.5), math.ceil(xs[i + 1] - 0.5), y, c)

    def line(self, x0, y0, x1, y1, c, width=1):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            if width <= 1:
                self.blend(x0, y0, c)
            else:
                r = width // 2
                for oy in range(-r, r + 1):
                    for ox in range(-r, r + 1):
                        self.blend(x0 + ox, y0 + oy, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def outline(self, pts, c, width=1):
        for i in range(len(pts)):
            a = pts[i]
            b = pts[(i + 1) % len(pts)]
            self.line(a[0], a[1], b[0], b[1], c, width)

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            self.hspan(x, x + w - 1, yy, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry), int(cy + ry) + 1):
            dy = (y + 0.5 - cy) / ry
            if abs(dy) > 1:
                continue
            half = rx * math.sqrt(1 - dy * dy)
            self.hspan(math.floor(cx - half + 0.5), math.ceil(cx + half - 0.5), y, c)

    def speckle(self, pts_test, count, colors, rng, x0, y0, x1, y1):
        for _ in range(count):
            x = rng.randint(int(x0), int(x1))
            y = rng.randint(int(y0), int(y1))
            if pts_test(x + 0.5, y + 0.5):
                self.blend(x, y, rng.choice(colors))

    def save(self, path):
        raw = bytearray()
        stride = self.w * 4
        for y in range(self.h):
            raw.append(0)
            raw += self.px[y * stride:(y + 1) * stride]

        def chunk(tag, data):
            c = struct.pack(">I", len(data)) + tag + data
            return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


def point_in_poly(pts, x, y):
    inside = False
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
            inside = not inside
        j = i
    return inside


# --------------------------------------------------------------------------------------
# Isometric helpers
# --------------------------------------------------------------------------------------

class Iso:
    """Coordinate helper for a canvas holding an s x s footprint flush with the bottom."""

    def __init__(self, cv, s):
        self.cv = cv
        self.s = s
        self.H = cv.h

    def p(self, u, v, lift=0.0):
        """Tile-space (u, v) in [0, s] to canvas pixel coordinates."""
        return (HW * self.s + (u - v) * HW, self.H - TH * self.s + (u + v) * HH - lift)

    def diamond(self, inset=0.0, lift=0.0):
        i = inset
        s = self.s
        return [self.p(i, i, lift), self.p(s - i, i, lift), self.p(s - i, s - i, lift), self.p(i, s - i, lift)]

    def sub_diamond(self, u0, v0, u1, v1, lift=0.0):
        return [self.p(u0, v0, lift), self.p(u1, v0, lift), self.p(u1, v1, lift), self.p(u0, v1, lift)]


def draw_box(cv, base, h, color, outline=True, top_color=None, lit_left=1.0, lit_right=0.72):
    """Extruded box on a diamond base. base = [top, right, bottom, left]."""
    T, R, B, L = base
    up = lambda p: (p[0], p[1] - h)
    if h > 0:
        cv.fill_poly([L, B, up(B), up(L)], shade(color, lit_left * 0.86))
        cv.fill_poly([B, R, up(R), up(B)], shade(color, lit_right * 0.86))
    top = top_color if top_color is not None else shade(color, 1.05)
    cv.fill_poly([up(T), up(R), up(B), up(L)], top)
    if outline:
        edge = shade(color, 0.45)
        cv.outline([up(T), up(R), up(B), up(L)], edge)
        if h > 0:
            cv.line(L[0], L[1], up(L)[0], up(L)[1], edge)
            cv.line(B[0], B[1], up(B)[0], up(B)[1], edge)
            cv.line(R[0], R[1], up(R)[0], up(R)[1], edge)
            cv.line(L[0], L[1], B[0], B[1], edge)
            cv.line(B[0], B[1], R[0], R[1], edge)
    return [up(T), up(R), up(B), up(L)]


def face_windows(cv, p0, p1, h, rng, win_w=6, win_h=8, pitch_x=12, pitch_y=14, margin_y=8, margin_x=6,
                 lit=(250, 230, 150, 255), dark=(40, 55, 80, 255), lit_prob=0.35, frame=None, skip_bottom=0):
    """Grid of windows on a wall whose base edge runs from p0 to p1 and rises h pixels."""
    ex = p1[0] - p0[0]
    ey = p1[1] - p0[1]
    length = abs(ex)
    if length < pitch_x or h < pitch_y:
        return
    cols = int((length - margin_x * 2) // pitch_x)
    rows = int((h - margin_y - skip_bottom) // pitch_y)
    if cols <= 0 or rows <= 0:
        return
    slack = (length - margin_x * 2 - cols * pitch_x) / 2.0

    def P(t, y):
        return (p0[0] + ex * t, p0[1] + ey * t - y)

    for r in range(rows):
        y = skip_bottom + margin_y + r * pitch_y
        for c in range(cols):
            x = margin_x + slack + c * pitch_x + (pitch_x - win_w) / 2.0
            t0 = x / length
            t1 = (x + win_w) / length
            color = lit if rng.random() < lit_prob else dark
            quad = [P(t0, y), P(t1, y), P(t1, y + win_h), P(t0, y + win_h)]
            cv.fill_poly(quad, color)
            if frame is not None:
                cv.outline(quad, frame)


def hip_roof(cv, top, height, color):
    T, R, B, L = top
    cx = (T[0] + B[0]) / 2.0
    cy = (T[1] + B[1]) / 2.0 - height
    apex = (cx, cy)
    cv.fill_poly([T, R, apex], shade(color, 0.85))
    cv.fill_poly([R, B, apex], shade(color, 0.70))
    cv.fill_poly([B, L, apex], shade(color, 0.95))
    cv.fill_poly([L, T, apex], shade(color, 1.05))
    edge = shade(color, 0.4)
    for p in (T, R, B, L):
        cv.line(p[0], p[1], apex[0], apex[1], edge)
    cv.outline([T, R, B, L], edge)


def draw_tree(cv, x, y, size, rng, dark=(30, 90, 40, 255), light=(70, 140, 60, 255), trunk=(90, 60, 35, 255)):
    cv.rect(x - 2, y - size * 0.5, 4, size * 0.5 + 1, trunk)
    layers = 3
    for k in range(layers):
        r = size * (0.9 - k * 0.22)
        cy = y - size * 0.55 - k * size * 0.42
        c = mix(dark, light, k / max(1, layers - 1))
        cv.ellipse(x, cy, r, r * 0.9, c)
        cv.ellipse(x - r * 0.3, cy - r * 0.2, r * 0.45, r * 0.4, mix(c, light, 0.5))


def chimney(cv, x, y_base, w, h, color, smoke=True):
    cv.rect(x - w / 2, y_base - h, w, h, color)
    cv.rect(x - w / 2, y_base - h, w * 0.35, h, shade(color, 1.15))
    cv.rect(x - w / 2 - 1, y_base - h - 3, w + 2, 4, shade(color, 0.7))
    if smoke:
        for k in range(3):
            cv.ellipse(x + k * 5 - 2, y_base - h - 10 - k * 9, 7 + k * 2, 5 + k * 1.5, (200, 200, 205, 120 - k * 30))


def smokestack_cluster(cv, iso, top, h, rng, count=2, color=(120, 115, 110, 255)):
    T, R, B, L = top
    for k in range(count):
        t = 0.3 + 0.4 * k / max(1, count - 1)
        x = T[0] + (L[0] - T[0]) * t
        y = T[1] + (L[1] - T[1]) * t
        chimney(cv, x, y + 4, 10, 34 + k * 6, color)


def lot(cv, iso, grass=(96, 150, 70, 255), pave=(150, 150, 145, 255), inset=0.08, pave_inset=None):
    base = iso.diamond(0.0)
    cv.fill_poly(base, grass)
    if pave_inset is not None:
        cv.fill_poly(iso.diamond(pave_inset), pave)
    cv.outline(base, (60, 95, 45, 160))
    return base


# --------------------------------------------------------------------------------------
# Terrain
# --------------------------------------------------------------------------------------

def terrain_grass(name, seed, base=(104, 160, 76, 255)):
    rng = random.Random(seed)
    cv = Canvas(TW, TH)
    iso = Iso(cv, 1)
    d = iso.diamond()
    cv.fill_poly(d, base)
    test = lambda x, y: point_in_poly(d, x, y)
    cv.speckle(test, 260, [shade(base, 0.88), shade(base, 1.10), shade(base, 0.94)], rng, 0, 0, TW - 1, TH - 1)
    cv.outline(d, shade(base, 0.8))
    cv.save(os.path.join(OUT, name + ".png"))


def terrain_sand(name, seed):
    rng = random.Random(seed)
    base = (212, 196, 142, 255)
    cv = Canvas(TW, TH)
    iso = Iso(cv, 1)
    d = iso.diamond()
    cv.fill_poly(d, base)
    test = lambda x, y: point_in_poly(d, x, y)
    cv.speckle(test, 200, [shade(base, 0.9), shade(base, 1.06)], rng, 0, 0, TW - 1, TH - 1)
    cv.outline(d, shade(base, 0.85))
    cv.save(os.path.join(OUT, name + ".png"))


def terrain_water(name, seed):
    rng = random.Random(seed)
    base = (52, 120, 190, 255)
    cv = Canvas(TW, TH)
    iso = Iso(cv, 1)
    d = iso.diamond()
    cv.fill_poly(d, base)
    for _ in range(9):
        x = rng.randint(20, TW - 30)
        y = rng.randint(8, TH - 10)
        if point_in_poly(d, x + 6, y):
            cv.line(x, y, x + rng.randint(6, 14), y, (120, 180, 230, 150))
    cv.outline(d, shade(base, 0.9))
    cv.save(os.path.join(OUT, name + ".png"))


def terrain_forest(name, seed):
    rng = random.Random(seed)
    base = (88, 140, 66, 255)
    cv = Canvas(TW, TH + 48)
    iso = Iso(cv, 1)
    d = iso.diamond()
    cv.fill_poly(d, base)
    test = lambda x, y: point_in_poly(d, x, y)
    cv.speckle(test, 160, [shade(base, 0.85), shade(base, 1.08)], rng, 0, TH - 48, TW - 1, cv.h - 1)
    cv.outline(d, shade(base, 0.8))
    spots = []
    for _ in range(40):
        u = rng.uniform(0.15, 0.85)
        v = rng.uniform(0.15, 0.85)
        if all(abs(u - su) + abs(v - sv) > 0.32 for su, sv in spots):
            spots.append((u, v))
        if len(spots) >= 5:
            break
    spots.sort(key=lambda p: p[0] + p[1])
    for u, v in spots:
        x, y = iso.p(u, v)
        size = rng.randint(14, 22)
        dark = rng.choice([(28, 86, 40, 255), (36, 96, 44, 255), (24, 76, 48, 255)])
        light = shade(dark, 1.7)
        draw_tree(cv, x, y, size, rng, dark, light)
    cv.save(os.path.join(OUT, name + ".png"))


# --------------------------------------------------------------------------------------
# Roads: mask bit0 = north (y-1, top-right edge), bit1 = east (x+1, bottom-right edge),
# bit2 = south (y+1, bottom-left edge), bit3 = west (x-1, top-left edge)
# --------------------------------------------------------------------------------------

def road(mask):
    cv = Canvas(TW, TH)
    iso = Iso(cv, 1)
    T, R, B, L = iso.diamond()
    asphalt = (72, 72, 76, 255)
    walk = (168, 165, 158, 255)
    cv.fill_poly([T, R, B, L], asphalt)
    C = iso.p(0.5, 0.5)
    edges = {0: (T, R), 1: (R, B), 2: (B, L), 3: (L, T)}
    # Sidewalks along unconnected edges.
    sw = 0.16
    inner = {0: iso.sub_diamond(0, 0, 1, 1)[0], }
    for bit, (a, b) in edges.items():
        connected = (mask >> bit) & 1
        if connected:
            continue
        # Band between edge and a parallel edge inset toward the centre.
        if bit == 0:
            band = [iso.p(0, 0), iso.p(1, 0), iso.p(1, sw), iso.p(0, sw)]
        elif bit == 1:
            band = [iso.p(1, 0), iso.p(1, 1), iso.p(1 - sw, 1), iso.p(1 - sw, 0)]
        elif bit == 2:
            band = [iso.p(1, 1), iso.p(0, 1), iso.p(0, 1 - sw), iso.p(1, 1 - sw)]
        else:
            band = [iso.p(0, 1), iso.p(0, 0), iso.p(sw, 0), iso.p(sw, 1)]
        cv.fill_poly(band, walk)
        cv.outline(band, shade(walk, 0.8))
    # Corner sidewalk squares where two unconnected edges meet look fine as-is.
    # Lane markings toward connected edges.
    dash = (222, 200, 90, 255)
    mids = {0: iso.p(0.5, 0.0), 1: iso.p(1.0, 0.5), 2: iso.p(0.5, 1.0), 3: iso.p(0.0, 0.5)}
    count = 0
    for bit in range(4):
        if (mask >> bit) & 1:
            count += 1
            m = mids[bit]
            for k in range(4):
                t0 = 0.12 + k * 0.22
                t1 = t0 + 0.11
                x0 = C[0] + (m[0] - C[0]) * t0
                y0 = C[1] + (m[1] - C[1]) * t0
                x1 = C[0] + (m[0] - C[0]) * t1
                y1 = C[1] + (m[1] - C[1]) * t1
                cv.line(x0, y0, x1, y1, dash, 2)
    if count == 0:
        cv.fill_poly(iso.diamond(0.3), (95, 95, 98, 255))
    cv.outline([T, R, B, L], (40, 40, 44, 255))
    cv.save(os.path.join(OUT, "road_%02d.png" % mask))


# --------------------------------------------------------------------------------------
# Zone lots, rubble, fire, icons
# --------------------------------------------------------------------------------------

ZONE_COLORS = {"res": (70, 190, 80, 255), "com": (70, 130, 240, 255), "ind": (230, 190, 50, 255)}


def lot_sprite(zone, density):
    cv = Canvas(TW, TH)
    iso = Iso(cv, 1)
    d = iso.diamond()
    c = ZONE_COLORS[zone]
    cv.fill_poly(d, alpha(c, 70))
    cv.fill_poly(iso.diamond(0.08), alpha(c, 50))
    cv.outline(d, alpha(c, 230))
    cv.outline(iso.diamond(0.08), alpha(c, 120))
    cx, cy = iso.p(0.5, 0.5)
    for k in range(density):
        x = cx - (density - 1) * 5 + k * 10
        cv.rect(x - 3, cy - 3, 6, 6, alpha(c, 240))
    cv.save(os.path.join(OUT, "lot_%s_%d.png" % (zone, density)))


def rubble():
    rng = random.Random(99)
    cv = Canvas(TW, TH)
    iso = Iso(cv, 1)
    d = iso.diamond()
    base = (110, 96, 82, 255)
    cv.fill_poly(d, base)
    test = lambda x, y: point_in_poly(d, x, y)
    cv.speckle(test, 220, [shade(base, 0.7), shade(base, 1.2), (60, 55, 50, 255)], rng, 0, 0, TW - 1, TH - 1)
    for _ in range(9):
        x = rng.randint(28, TW - 36)
        y = rng.randint(12, TH - 14)
        if test(x, y):
            cv.rect(x, y, rng.randint(5, 10), rng.randint(3, 5), (75, 66, 60, 255))
            cv.rect(x + 1, y, rng.randint(3, 6), 2, (140, 130, 120, 255))
    cv.outline(d, shade(base, 0.6))
    cv.save(os.path.join(OUT, "rubble.png"))


def fire(frame):
    rng = random.Random(500 + frame)
    cv = Canvas(TW, TH + 40)
    iso = Iso(cv, 1)
    cx, cy = iso.p(0.5, 0.5)
    for k in range(4):
        x = cx - 30 + k * 20 + rng.randint(-4, 4)
        h = 30 + rng.randint(0, 22)
        w = 12 + rng.randint(0, 6)
        cv.fill_poly([(x - w, cy), (x + w, cy), (x + rng.randint(-4, 4), cy - h)], (255, 120, 20, 240))
        cv.fill_poly([(x - w * 0.6, cy), (x + w * 0.6, cy), (x + rng.randint(-3, 3), cy - h * 0.62)], (255, 210, 60, 255))
        cv.fill_poly([(x - w * 0.25, cy), (x + w * 0.25, cy), (x, cy - h * 0.3)], (255, 250, 200, 255))
    cv.save(os.path.join(OUT, "fire_%d.png" % frame))


def smoke():
    cv = Canvas(TW, 80)
    for k in range(4):
        cv.ellipse(48 + k * 10, 60 - k * 14, 14 + k * 3, 10 + k * 2, (70, 70, 75, 150 - k * 30))
    cv.save(os.path.join(OUT, "smoke.png"))


ALERT_RING = (214, 44, 44, 255)
ALERT_RING_HOT = (255, 112, 96, 255)
ALERT_BG = (24, 28, 40, 246)
ALERT_BG_HOT = (46, 26, 30, 250)

# Badge geometry: a circle centred at (A_CX, A_CY) plus a pointer whose tip sits on the
# bottom edge of the canvas, so the renderer can anchor a badge by its bottom centre.
A_W, A_H = 72, 90
A_CX, A_CY, A_R = 36, 34, 30


def alert_badge(name, painter, hot):
    """An alert pin: thick red ring, dark face, a service icon, and a downward pointer."""
    cv = Canvas(A_W, A_H)
    ring = ALERT_RING_HOT if hot else ALERT_RING
    face = ALERT_BG_HOT if hot else ALERT_BG
    if hot:
        # Outer glow, so the flash frame reads as louder than the base frame.
        for k in range(5):
            cv.ellipse(A_CX, A_CY, A_R + 3 + k * 3, A_R + 3 + k * 3, (255, 70, 58, 54 - k * 10))
    # Pointer first; the circle then covers its top.
    cv.fill_poly([(A_CX - 14, A_CY + 16), (A_CX + 14, A_CY + 16), (A_CX, A_H - 1)], ring)
    cv.fill_poly([(A_CX - 8, A_CY + 14), (A_CX + 8, A_CY + 14), (A_CX, A_CY + 27)], face)
    cv.ellipse(A_CX, A_CY, A_R, A_R, ring)
    cv.ellipse(A_CX, A_CY, A_R - 7, A_R - 7, face)
    painter(cv, A_CX, A_CY, hot)
    cv.save(os.path.join(OUT, "alert_%s%s.png" % (name, "_hot" if hot else "")))


def paint_power(cv, cx, cy, hot):
    body = (255, 232, 84, 255) if hot else (246, 202, 38, 255)
    bolt = [(4, -17), (-9, 2), (-1, 2), (-6, 19), (11, -2), (2, -2), (9, -17)]
    pts = [(cx + a, cy + b) for a, b in bolt]
    cv.fill_poly(pts, body)
    cv.outline(pts, (128, 90, 0, 255))


def paint_water(cv, cx, cy, hot):
    body = (128, 210, 255, 255) if hot else (74, 168, 246, 255)
    drop = [(0, -18), (9, -5), (13, 4), (9, 13), (0, 17), (-9, 13), (-13, 4), (-9, -5)]
    pts = [(cx + a, cy + b) for a, b in drop]
    cv.fill_poly(pts, body)
    cv.outline(pts, (18, 74, 150, 255))
    cv.ellipse(cx - 5, cy + 3, 3, 5, (226, 244, 255, 235))


def paint_abandoned(cv, cx, cy, hot):
    """A boarded-up house: this lot had a building and lost it."""
    wall = (206, 196, 180, 255) if hot else (176, 166, 152, 255)
    roof = (150, 80, 62, 255) if hot else (124, 66, 50, 255)
    board = (196, 146, 84, 255) if hot else (166, 120, 66, 255)
    dark = (34, 30, 30, 255)
    # Roof, then body.
    cv.fill_poly([(cx - 16, cy - 4), (cx, cy - 18), (cx + 16, cy - 4)], roof)
    cv.outline([(cx - 16, cy - 4), (cx, cy - 18), (cx + 16, cy - 4)], (44, 26, 20, 255))
    cv.rect(cx - 12, cy - 4, 24, 19, wall)
    cv.outline([(cx - 12, cy - 4), (cx + 12, cy - 4), (cx + 12, cy + 15), (cx - 12, cy + 15)], dark)
    # An empty doorway: the building is gone.
    cv.rect(cx - 5, cy + 3, 10, 12, dark)
    # Two planks nailed across the front.
    for dy in (1, 9):
        quad = [(cx - 15, cy + dy + 2), (cx + 15, cy + dy - 3), (cx + 15, cy + dy + 2), (cx - 15, cy + dy + 7)]
        cv.fill_poly(quad, board)
        cv.outline(quad, (86, 58, 30, 255))


def paint_road(cv, cx, cy, hot):
    slash = (255, 120, 108, 255) if hot else (226, 58, 52, 255)
    cv.rect(cx - 16, cy - 6, 32, 13, (104, 104, 110, 255))
    cv.rect(cx - 16, cy - 6, 32, 2, (168, 165, 158, 255))
    cv.rect(cx - 16, cy + 5, 32, 2, (168, 165, 158, 255))
    for k in range(3):
        cv.rect(cx - 13 + k * 10, cy - 1, 6, 3, (232, 208, 96, 255))
    cv.line(cx - 14, cy + 14, cx + 14, cy - 14, (28, 18, 18, 255), 7)
    cv.line(cx - 14, cy + 14, cx + 14, cy - 14, slash, 5)


# --------------------------------------------------------------------------------------
# Zone buildings
# --------------------------------------------------------------------------------------

RES_WALLS = {1: (168, 132, 96, 255), 2: (226, 208, 178, 255), 3: (242, 240, 232, 255)}
RES_ROOFS = {1: (110, 74, 58, 255), 2: (150, 62, 52, 255), 3: (72, 84, 118, 255)}
RES_TOWER_WALLS = {1: (118, 118, 126, 255), 2: (176, 166, 152, 255), 3: (205, 214, 228, 255)}
COM_WALLS = {1: (150, 140, 128, 255), 2: (120, 150, 185, 255), 3: (120, 170, 220, 255)}
COM_SIGNS = {1: (200, 80, 60, 255), 2: (230, 160, 40, 255), 3: (60, 180, 200, 255)}
IND_WALLS = {1: (140, 128, 110, 255), 2: (150, 145, 135, 255), 3: (128, 134, 142, 255)}


def res_sprite(density, level, wealth):
    rng = random.Random(1000 + density * 100 + level * 10 + wealth)
    if density == 1:
        h = [0, 22, 28, 34][level]
        cv = Canvas(TW, TH + h + 30)
        iso = Iso(cv, 1)
        lot(cv, iso, grass=(100, 158, 74, 255))
        # Path from the road edge to the house.
        cv.fill_poly([iso.p(0.45, 1.0), iso.p(0.55, 1.0), iso.p(0.55, 0.72), iso.p(0.45, 0.72)], (170, 165, 150, 255))
        inset = [0, 0.30, 0.24, 0.20][level]
        base = iso.diamond(inset)
        wall = RES_WALLS[wealth]
        top = draw_box(cv, base, h, wall)
        # Door and windows on the two visible faces.
        T, R, B, L = base
        face_windows(cv, L, B, h, rng, win_w=6, win_h=7, pitch_x=14, pitch_y=12, margin_y=5, margin_x=8,
                     lit_prob=0.5, frame=shade(wall, 0.5))
        face_windows(cv, B, R, h, rng, win_w=6, win_h=7, pitch_x=14, pitch_y=12, margin_y=5, margin_x=14,
                     lit_prob=0.5, frame=shade(wall, 0.5))
        door = [(B[0] + (R[0] - B[0]) * 0.12, B[1] + (R[1] - B[1]) * 0.12),
                (B[0] + (R[0] - B[0]) * 0.24, B[1] + (R[1] - B[1]) * 0.24)]
        cv.fill_poly([door[0], door[1], (door[1][0], door[1][1] - 12), (door[0][0], door[0][1] - 12)], (90, 60, 40, 255))
        hip_roof(cv, top, 12 + level * 2, RES_ROOFS[wealth])
        if level >= 3:
            # Garage beside the house.
            g = iso.sub_diamond(0.62, 0.62, 0.92, 0.92)
            gt = draw_box(cv, g, 14, shade(wall, 0.95))
            hip_roof(cv, gt, 5, RES_ROOFS[wealth])
        if wealth >= 2:
            x, y = iso.p(0.2, 0.85)
            draw_tree(cv, x, y, 10, rng)
    elif density == 2:
        h = [0, 56, 84, 112][level]
        cv = Canvas(TW, TH + h + 16)
        iso = Iso(cv, 1)
        lot(cv, iso, grass=(110, 150, 80, 255), pave_inset=0.06, pave=(160, 158, 150, 255))
        base = iso.diamond(0.13)
        wall = mix(RES_WALLS[wealth], (150, 150, 150, 255), 0.15)
        top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.75))
        T, R, B, L = base
        face_windows(cv, L, B, h, rng, win_w=7, win_h=9, pitch_x=13, pitch_y=15, margin_y=10, lit_prob=0.4,
                     frame=shade(wall, 0.6), skip_bottom=4)
        face_windows(cv, B, R, h, rng, win_w=7, win_h=9, pitch_x=13, pitch_y=15, margin_y=10, lit_prob=0.4,
                     frame=shade(wall, 0.6), skip_bottom=4)
        # Entrance canopy on the right face.
        cv.rect(B[0] + 6, B[1] - 16, 16, 14, (60, 70, 90, 255))
        # Rooftop clutter.
        Tt, Rt, Bt, Lt = top
        cx = (Tt[0] + Bt[0]) / 2
        cy = (Tt[1] + Bt[1]) / 2
        cv.rect(cx - 10, cy - 8, 10, 7, shade(wall, 0.6))
        cv.rect(cx + 4, cy - 3, 8, 6, shade(wall, 0.55))
        if wealth == 3:
            cv.outline(top, (250, 250, 250, 200))
    else:
        h = [0, 120, 180, 240][level]
        cv = Canvas(TW, TH + h + 30)
        iso = Iso(cv, 1)
        lot(cv, iso, grass=(120, 140, 90, 255), pave_inset=0.04, pave=(150, 150, 148, 255))
        base = iso.diamond(0.09)
        wall = RES_TOWER_WALLS[wealth]
        top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.7))
        T, R, B, L = base
        dark = (40, 50, 70, 255) if wealth < 3 else (150, 190, 230, 255)
        face_windows(cv, L, B, h, rng, win_w=6, win_h=8, pitch_x=11, pitch_y=13, margin_y=8, lit_prob=0.45,
                     dark=dark, frame=shade(wall, 0.65), skip_bottom=6)
        face_windows(cv, B, R, h, rng, win_w=6, win_h=8, pitch_x=11, pitch_y=13, margin_y=8, lit_prob=0.45,
                     dark=dark, frame=shade(wall, 0.65), skip_bottom=6)
        Tt, Rt, Bt, Lt = top
        cx = (Tt[0] + Bt[0]) / 2
        cy = (Tt[1] + Bt[1]) / 2
        cv.rect(cx - 12, cy - 6, 12, 8, shade(wall, 0.55))
        if level >= 3:
            cv.rect(cx + 6, cy - 26, 2, 26, (200, 200, 200, 255))
            cv.blend(int(cx + 6), int(cy - 27), (255, 60, 60, 255))
    cv.save(os.path.join(OUT, "res_d%d_l%d_w%d.png" % (density, level, wealth)))


def com_sprite(density, level, wealth):
    rng = random.Random(2000 + density * 100 + level * 10 + wealth)
    if density == 1:
        h = [0, 28, 36, 44][level]
        cv = Canvas(TW, TH + h + 16)
        iso = Iso(cv, 1)
        lot(cv, iso, grass=(150, 150, 145, 255), pave_inset=0.0, pave=(150, 150, 145, 255))
        base = iso.diamond(0.14)
        wall = COM_WALLS[1] if wealth == 1 else (200, 190, 175, 255) if wealth == 2 else (225, 225, 228, 255)
        top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.72))
        T, R, B, L = base
        # Big shop windows on the lower part of both faces.
        face_windows(cv, L, B, h, rng, win_w=16, win_h=14, pitch_x=20, pitch_y=h, margin_y=4, margin_x=6,
                     lit=(190, 225, 245, 255), dark=(160, 205, 235, 255), lit_prob=0.5, frame=(60, 60, 70, 255))
        face_windows(cv, B, R, h, rng, win_w=16, win_h=14, pitch_x=20, pitch_y=h, margin_y=4, margin_x=6,
                     lit=(190, 225, 245, 255), dark=(160, 205, 235, 255), lit_prob=0.5, frame=(60, 60, 70, 255))
        # Sign band along the top of the faces.
        sign = COM_SIGNS[wealth]
        band = 7
        cv.fill_poly([(L[0], L[1] - h + band), (B[0], B[1] - h + band), (B[0], B[1] - h + 1), (L[0], L[1] - h + 1)], sign)
        cv.fill_poly([(B[0], B[1] - h + band), (R[0], R[1] - h + band), (R[0], R[1] - h + 1), (B[0], B[1] - h + 1)], shade(sign, 0.8))
        if level >= 2:
            Tt, Rt, Bt, Lt = top
            cx = (Tt[0] + Bt[0]) / 2
            cy = (Tt[1] + Bt[1]) / 2
            cv.rect(cx - 8, cy - 5, 9, 6, shade(wall, 0.5))
    elif density == 2:
        h = [0, 70, 110, 150][level]
        cv = Canvas(TW, TH + h + 20)
        iso = Iso(cv, 1)
        lot(cv, iso, grass=(140, 140, 138, 255), pave_inset=0.0, pave=(140, 140, 138, 255))
        base = iso.diamond(0.11)
        wall = COM_WALLS[wealth]
        top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.6))
        T, R, B, L = base
        glass_lit = (215, 235, 250, 255)
        glass_dark = (90, 130, 175, 255) if wealth > 1 else (70, 80, 100, 255)
        face_windows(cv, L, B, h, rng, win_w=9, win_h=9, pitch_x=12, pitch_y=13, margin_y=6, margin_x=5,
                     lit=glass_lit, dark=glass_dark, lit_prob=0.3, skip_bottom=8)
        face_windows(cv, B, R, h, rng, win_w=9, win_h=9, pitch_x=12, pitch_y=13, margin_y=6, margin_x=5,
                     lit=glass_lit, dark=glass_dark, lit_prob=0.3, skip_bottom=8)
        cv.rect(B[0] + 4, B[1] - 18, 14, 16, (40, 50, 65, 255))
        Tt, Rt, Bt, Lt = top
        cx = (Tt[0] + Bt[0]) / 2
        cy = (Tt[1] + Bt[1]) / 2
        cv.rect(cx - 10, cy - 7, 14, 8, shade(wall, 0.5))
    else:
        h = [0, 160, 230, 300][level]
        cv = Canvas(TW, TH + h + 40)
        iso = Iso(cv, 1)
        lot(cv, iso, grass=(135, 135, 135, 255), pave_inset=0.0, pave=(135, 135, 135, 255))
        base = iso.diamond(0.08)
        wall = (80, 120, 170, 255) if wealth < 3 else (110, 165, 220, 255)
        if wealth == 1:
            wall = (100, 105, 115, 255)
        top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.55))
        T, R, B, L = base
        face_windows(cv, L, B, h, rng, win_w=8, win_h=10, pitch_x=10, pitch_y=12, margin_y=6, margin_x=4,
                     lit=(225, 240, 255, 255), dark=shade(wall, 1.3), lit_prob=0.35, skip_bottom=10)
        face_windows(cv, B, R, h, rng, win_w=8, win_h=10, pitch_x=10, pitch_y=12, margin_y=6, margin_x=4,
                     lit=(225, 240, 255, 255), dark=shade(wall, 1.2), lit_prob=0.35, skip_bottom=10)
        Tt, Rt, Bt, Lt = top
        cx = (Tt[0] + Bt[0]) / 2
        cy = (Tt[1] + Bt[1]) / 2
        # Setback crown and spire.
        crown = [(Tt[0] * 0.5 + cx * 0.5, Tt[1] * 0.5 + cy * 0.5), (Rt[0] * 0.5 + cx * 0.5, Rt[1] * 0.5 + cy * 0.5),
                 (Bt[0] * 0.5 + cx * 0.5, Bt[1] * 0.5 + cy * 0.5), (Lt[0] * 0.5 + cx * 0.5, Lt[1] * 0.5 + cy * 0.5)]
        draw_box(cv, crown, 14 + level * 4, shade(wall, 0.9), top_color=shade(wall, 0.6))
        if level >= 3:
            cv.rect(cx - 1, cy - 14 - 30 - level * 4, 3, 30, (220, 220, 225, 255))
            cv.blend(int(cx), int(cy - 14 - 31 - level * 4), (255, 80, 80, 255))
    cv.save(os.path.join(OUT, "com_d%d_l%d_w%d.png" % (density, level, wealth)))


def ind_sprite(density, level, wealth):
    rng = random.Random(3000 + density * 100 + level * 10 + wealth)
    tint = [None, (0.9, 0.86, 0.8), (1.0, 1.0, 1.0), (1.02, 1.04, 1.08)][wealth]
    base_wall = IND_WALLS[density]
    wall = col(base_wall[0] * tint[0], base_wall[1] * tint[1], base_wall[2] * tint[2])
    if density == 1:
        # Low-density industry is farmland: a worked field with a barn on it.
        h = [0, 16, 20, 24][level]
        cv = Canvas(TW, TH + h + 52)
        iso = Iso(cv, 1)
        soil = (126, 96, 66, 255)
        d = iso.diamond()
        cv.fill_poly(d, soil)
        crop = [(0, 0, 0), (118, 152, 74, 255), (140, 172, 78, 255), (206, 184, 92, 255)][level]
        # Furrows running along one axis of the tile.
        rows = 7
        for k in range(rows):
            t0 = (k + 0.25) / rows
            t1 = (k + 0.75) / rows
            quad = [iso.p(0.06, t0), iso.p(0.94, t0), iso.p(0.94, t1), iso.p(0.06, t1)]
            cv.fill_poly(quad, crop)
            cv.outline(quad, shade(crop, 0.78))
        cv.outline(d, shade(soil, 0.7))
        # A track along the near edge of the field.
        cv.fill_poly([iso.p(0.0, 0.94), iso.p(1.0, 0.94), iso.p(1.0, 1.0), iso.p(0.0, 1.0)], (158, 142, 116, 255))
        # Barn in the far corner.
        barn = iso.sub_diamond(0.08, 0.06, 0.46, 0.44)
        barn_wall = (168, 62, 52, 255) if wealth < 3 else (186, 78, 62, 255)
        barn_top = draw_box(cv, barn, h + 10, barn_wall)
        hip_roof(cv, barn_top, 9, (126, 78, 60, 255))
        Tb, Rb, Bb, Lb = barn
        cv.fill_poly([(Bb[0] - 5, Bb[1] - 2), (Bb[0] + 5, Bb[1] - 2),
                      (Bb[0] + 5, Bb[1] - 16), (Bb[0] - 5, Bb[1] - 16)], (58, 42, 36, 255))
        if level >= 2:
            # Silo beside the barn.
            sx, sy = iso.p(0.60, 0.20)
            silo = (198, 196, 186, 255)
            cv.rect(sx - 8, sy - 34, 16, 34, silo)
            cv.rect(sx - 8, sy - 34, 5, 34, shade(silo, 1.1))
            cv.ellipse(sx, sy, 8, 4, shade(silo, 0.8))
            for z in range(0, 8):
                r = math.sqrt(64 - z * z) / 8.0
                cv.ellipse(sx, sy - 34 - z * 0.8, 8 * r, 4 * r, shade((150, 142, 132, 255), 1.0 + z * 0.02))
        if level >= 3:
            # A second, longer barn for the biggest farms.
            shed = iso.sub_diamond(0.52, 0.58, 0.96, 0.86)
            shed_top = draw_box(cv, shed, 14, (150, 140, 124, 255))
            hip_roof(cv, shed_top, 6, (92, 84, 74, 255))
    elif density == 2:
        h = [0, 40, 55, 70][level]
        cv = Canvas(TW, TH + h + 70)
        iso = Iso(cv, 1)
        lot(cv, iso, grass=(140, 135, 125, 255), pave_inset=0.0, pave=(140, 135, 125, 255))
        base = iso.diamond(0.09)
        top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.72))
        T, R, B, L = base
        face_windows(cv, L, B, h, rng, win_w=12, win_h=10, pitch_x=16, pitch_y=18, margin_y=h * 0.35, margin_x=6,
                     lit=(200, 215, 205, 255), dark=(110, 125, 130, 255), lit_prob=0.5, frame=shade(wall, 0.5))
        face_windows(cv, B, R, h, rng, win_w=12, win_h=10, pitch_x=16, pitch_y=18, margin_y=h * 0.35, margin_x=6,
                     lit=(200, 215, 205, 255), dark=(110, 125, 130, 255), lit_prob=0.5, frame=shade(wall, 0.5))
        Tt, Rt, Bt, Lt = top
        for k in range(level):
            t = 0.25 + 0.25 * k
            x = Tt[0] + (Lt[0] - Tt[0]) * t
            y = Tt[1] + (Lt[1] - Tt[1]) * t
            chimney(cv, x + 10, y + 8, 9, 36 + k * 8, (105, 100, 98, 255))
    else:
        h = [0, 60, 80, 100][level]
        cv = Canvas(TW, TH + h + 80)
        iso = Iso(cv, 1)
        lot(cv, iso, grass=(125, 125, 122, 255), pave_inset=0.0, pave=(125, 125, 122, 255))
        base = iso.diamond(0.06)
        top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.7))
        T, R, B, L = base
        face_windows(cv, L, B, h, rng, win_w=9, win_h=7, pitch_x=12, pitch_y=16, margin_y=10, margin_x=6,
                     lit=(190, 205, 210, 255), dark=(90, 100, 110, 255), lit_prob=0.4, skip_bottom=6)
        face_windows(cv, B, R, h, rng, win_w=9, win_h=7, pitch_x=12, pitch_y=16, margin_y=10, margin_x=6,
                     lit=(190, 205, 210, 255), dark=(90, 100, 110, 255), lit_prob=0.4, skip_bottom=6)
        Tt, Rt, Bt, Lt = top
        # Storage tanks on the roof.
        for k in range(2):
            x = Rt[0] + (Bt[0] - Rt[0]) * (0.35 + k * 0.3) - 14
            y = Rt[1] + (Bt[1] - Rt[1]) * (0.35 + k * 0.3) - 6
            tank = (175, 178, 182, 255)
            cv.rect(x - 9, y - 22, 18, 22, tank)
            cv.rect(x - 9, y - 22, 5, 22, shade(tank, 1.15))
            cv.ellipse(x, y - 22, 9, 4, shade(tank, 1.1))
            cv.ellipse(x, y, 9, 4, shade(tank, 0.8))
            cv.rect(x - 9, y - 12, 18, 2, (200, 60, 50, 255))
        chimney(cv, Lt[0] + 22, Lt[1] + 4, 12, 50 + level * 8, (95, 92, 92, 255))
        if level >= 2:
            chimney(cv, Lt[0] + 40, Lt[1] - 4, 10, 40 + level * 6, (95, 92, 92, 255))
    cv.save(os.path.join(OUT, "ind_d%d_l%d_w%d.png" % (density, level, wealth)))


# --------------------------------------------------------------------------------------
# Civic buildings
# --------------------------------------------------------------------------------------

def civic_coal():
    rng = random.Random(41)
    s = 2
    h = 60
    cv = Canvas(TW * s, TH * s + h + 90)
    iso = Iso(cv, s)
    lot(cv, iso, grass=(120, 115, 105, 255), pave_inset=0.0, pave=(120, 115, 105, 255))
    wall = (98, 92, 88, 255)
    base = iso.diamond(0.12)
    top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.75))
    T, R, B, L = base
    face_windows(cv, L, B, h, rng, win_w=10, win_h=6, pitch_x=18, pitch_y=10, margin_y=h - 18, margin_x=10,
                 lit=(240, 200, 120, 255), dark=(70, 70, 75, 255), lit_prob=0.6)
    # Coal pile.
    px, py = iso.p(1.55, 1.7)
    cv.ellipse(px, py, 26, 12, (40, 38, 40, 255))
    cv.ellipse(px - 4, py - 5, 18, 8, (60, 58, 60, 255))
    Tt, Rt, Bt, Lt = top
    chimney(cv, Lt[0] + 40, Lt[1] + 10, 16, 80, (130, 125, 122, 255))
    chimney(cv, Lt[0] + 70, Lt[1] - 4, 16, 70, (130, 125, 122, 255))
    # Conveyor / cooling unit.
    cv.rect(Rt[0] - 44, Rt[1] + 4, 30, 14, shade(wall, 1.2))
    cv.save(os.path.join(OUT, "civic_coal.png"))


def civic_wind():
    cv = Canvas(TW, TH + 130)
    iso = Iso(cv, 1)
    lot(cv, iso, grass=(105, 160, 78, 255))
    cx, cy = iso.p(0.5, 0.5)
    cv.ellipse(cx, cy, 10, 5, (160, 160, 160, 255))
    pole = (225, 228, 232, 255)
    cv.fill_poly([(cx - 4, cy), (cx + 4, cy), (cx + 2, cy - 100), (cx - 2, cy - 100)], pole)
    cv.line(cx - 3, cy, cx - 1, cy - 100, shade(pole, 0.7))
    hub = (cx, cy - 100)
    cv.ellipse(hub[0], hub[1], 5, 5, (200, 200, 205, 255))
    for k in range(3):
        a = math.radians(90 + k * 120 + 20)
        ex = hub[0] + math.cos(a) * 42
        ey = hub[1] - math.sin(a) * 42
        cv.line(hub[0], hub[1], ex, ey, (240, 240, 245, 255), 4)
        cv.line(hub[0], hub[1], ex, ey, (190, 190, 200, 255), 1)
    cv.save(os.path.join(OUT, "civic_wind.png"))


def civic_nuclear():
    s = 3
    h = 40
    cv = Canvas(TW * s, TH * s + h + 120)
    iso = Iso(cv, s)
    lot(cv, iso, grass=(150, 150, 146, 255), pave_inset=0.0, pave=(150, 150, 146, 255))
    wall = (182, 190, 186, 255)
    base = iso.sub_diamond(0.15, 1.3, 2.85, 2.85)
    top = draw_box(cv, base, h, wall, top_color=shade(wall, 0.8))
    rng = random.Random(7)
    T, R, B, L = base
    face_windows(cv, L, B, h, rng, win_w=10, win_h=7, pitch_x=16, pitch_y=14, margin_y=8, margin_x=10,
                 lit=(210, 230, 235, 255), dark=(110, 130, 135, 255), lit_prob=0.5)
    # Reactor dome.
    dx, dy = iso.p(1.0, 0.9)
    cv.ellipse(dx, dy + 2, 42, 21, shade(wall, 0.7))
    R_dome = 38
    for z in range(0, R_dome):
        r = math.sqrt(R_dome * R_dome - z * z)
        t = z / float(R_dome)
        cv.ellipse(dx, dy - z * 0.75, r, r * 0.5, mix((165, 172, 170, 255), (240, 244, 242, 255), t))
    # Highlight streak.
    cv.ellipse(dx - 10, dy - 22, 6, 4, (250, 252, 250, 200))
    # Cooling tower.
    tx, ty = iso.p(2.3, 0.7)
    tower = (200, 202, 205, 255)
    cv.fill_poly([(tx - 30, ty), (tx + 30, ty), (tx + 20, ty - 90), (tx - 20, ty - 90)], tower)
    cv.fill_poly([(tx - 30, ty), (tx - 8, ty), (tx - 6, ty - 90), (tx - 20, ty - 90)], shade(tower, 1.1))
    cv.ellipse(tx, ty - 90, 20, 6, shade(tower, 0.7))
    for k in range(4):
        cv.ellipse(tx + k * 6, ty - 100 - k * 12, 16 + k * 4, 9 + k * 2, (240, 240, 245, 140 - k * 30))
    cv.save(os.path.join(OUT, "civic_nuclear.png"))


def civic_pump():
    cv = Canvas(TW, TH + 40)
    iso = Iso(cv, 1)
    lot(cv, iso, grass=(140, 150, 140, 255), pave_inset=0.0, pave=(140, 150, 140, 255))
    wall = (70, 120, 190, 255)
    base = iso.sub_diamond(0.25, 0.25, 0.75, 0.75)
    top = draw_box(cv, base, 22, wall, top_color=shade(wall, 0.8))
    # Intake pipe running to the tile edge.
    cv.fill_poly([iso.p(0.45, 0.75), iso.p(0.55, 0.75), iso.p(0.55, 1.0), iso.p(0.45, 1.0)], (120, 130, 140, 255))
    Tt, Rt, Bt, Lt = top
    cx = (Tt[0] + Bt[0]) / 2
    cy = (Tt[1] + Bt[1]) / 2
    cv.ellipse(cx, cy, 8, 4, (200, 210, 220, 255))
    cv.rect(cx - 2, cy - 14, 4, 14, (200, 210, 220, 255))
    cv.save(os.path.join(OUT, "civic_pump.png"))


def civic_tower():
    cv = Canvas(TW, TH + 110)
    iso = Iso(cv, 1)
    lot(cv, iso, grass=(108, 156, 78, 255))
    legs = (120, 120, 125, 255)
    pts = [iso.p(0.25, 0.25), iso.p(0.75, 0.25), iso.p(0.75, 0.75), iso.p(0.25, 0.75)]
    lift = 60
    for p in pts:
        cv.line(p[0], p[1], p[0] * 0.85 + 64 * 0.15, p[1] - lift, legs, 3)
    cv.line(pts[0][0], pts[0][1] - 20, pts[2][0], pts[2][1] - 20, legs, 1)
    cv.line(pts[1][0], pts[1][1] - 20, pts[3][0], pts[3][1] - 20, legs, 1)
    tank = (95, 150, 210, 255)
    cx, cy = iso.p(0.5, 0.5, lift)
    rx, ry, th = 30, 14, 34
    cv.rect(cx - rx, cy - th, rx * 2, th, tank)
    cv.rect(cx - rx, cy - th, 10, th, shade(tank, 1.15))
    cv.rect(cx + rx - 12, cy - th, 12, th, shade(tank, 0.75))
    cv.ellipse(cx, cy, rx, ry, shade(tank, 0.8))
    for k in range(3):
        cv.rect(cx - rx, cy - th + 8 + k * 10, rx * 2, 1, shade(tank, 0.6))
    cv.ellipse(cx, cy - th, rx, ry, shade(tank, 1.05))
    for z in range(0, 12):
        r = math.sqrt(144 - z * z) / 12.0
        cv.ellipse(cx, cy - th - z * 0.9, rx * r, ry * r, mix((70, 90, 120, 255), (110, 130, 160, 255), z / 12.0))
    cv.save(os.path.join(OUT, "civic_tower.png"))


def civic_service(name, wall, roof, s, h, decorate):
    # crc32, not hash(): Python randomises string hashing per process, which would
    # make the generated sprites differ between runs.
    rng = random.Random(zlib.crc32(name.encode()) & 0xFFFF)
    cv = Canvas(TW * s, TH * s + h + 50)
    iso = Iso(cv, s)
    lot(cv, iso, grass=(108, 156, 78, 255), pave_inset=0.05, pave=(158, 156, 150, 255))
    base = iso.diamond(0.14)
    top = draw_box(cv, base, h, wall, top_color=roof)
    T, R, B, L = base
    face_windows(cv, L, B, h, rng, win_w=9, win_h=10, pitch_x=15, pitch_y=16, margin_y=8, margin_x=8,
                 lit=(240, 230, 190, 255), dark=(60, 70, 90, 255), lit_prob=0.5, frame=shade(wall, 0.55), skip_bottom=2)
    face_windows(cv, B, R, h, rng, win_w=9, win_h=10, pitch_x=15, pitch_y=16, margin_y=8, margin_x=8,
                 lit=(240, 230, 190, 255), dark=(60, 70, 90, 255), lit_prob=0.5, frame=shade(wall, 0.55), skip_bottom=2)
    decorate(cv, iso, base, top, h)
    cv.save(os.path.join(OUT, "civic_%s.png" % name))


def deco_police(cv, iso, base, top, h):
    T, R, B, L = base
    Tt, Rt, Bt, Lt = top
    cx = (Tt[0] + Bt[0]) / 2
    cy = (Tt[1] + Bt[1]) / 2
    # Badge on the roof.
    cv.ellipse(cx, cy, 14, 7, (240, 200, 60, 255))
    cv.ellipse(cx, cy, 8, 4, (60, 70, 140, 255))
    # Entrance with blue lamps.
    cv.rect(B[0] + 10, B[1] - 20, 14, 18, (50, 60, 90, 255))
    cv.rect(B[0] + 4, B[1] - 26, 4, 4, (80, 140, 255, 255))
    cv.rect(B[0] + 26, B[1] - 15, 4, 4, (80, 140, 255, 255))
    # Parked cruisers.
    for k in range(2):
        x, y = iso.p(1.75, 0.35 + k * 0.3)
        cv.ellipse(x, y, 12, 5, (30, 30, 30, 200))
        cv.rect(x - 10, y - 8, 20, 7, (240, 240, 245, 255))
        cv.rect(x - 6, y - 12, 12, 5, (40, 60, 120, 255))
        cv.rect(x - 2, y - 14, 4, 2, (255, 60, 60, 255))


def deco_fire(cv, iso, base, top, h):
    T, R, B, L = base
    # Garage doors on the right-hand face.
    for k in range(3):
        t0 = 0.1 + k * 0.28
        t1 = t0 + 0.2
        p0 = (B[0] + (R[0] - B[0]) * t0, B[1] + (R[1] - B[1]) * t0)
        p1 = (B[0] + (R[0] - B[0]) * t1, B[1] + (R[1] - B[1]) * t1)
        cv.fill_poly([p0, p1, (p1[0], p1[1] - 26), (p0[0], p0[1] - 26)], (200, 200, 205, 255))
        for row in range(4):
            cv.line(p0[0], p0[1] - 5 - row * 6, p1[0], p1[1] - 5 - row * 6, (140, 140, 145, 255))
    Tt, Rt, Bt, Lt = top
    cx = (Tt[0] + Bt[0]) / 2
    cy = (Tt[1] + Bt[1]) / 2
    cv.rect(cx - 2, cy - 30, 4, 30, (120, 120, 125, 255))
    cv.rect(cx - 16, cy - 32, 16, 6, (220, 220, 225, 255))
    cv.rect(cx - 12, cy - 12, 24, 10, (160, 40, 40, 255))
    cv.rect(cx - 10, cy - 10, 20, 6, (255, 255, 255, 255))
    cv.rect(cx - 2, cy - 14, 4, 14, (255, 255, 255, 255))


def deco_school(cv, iso, base, top, h):
    Tt, Rt, Bt, Lt = top
    # Flag pole.
    fx, fy = iso.p(1.8, 1.8)
    cv.rect(fx - 1, fy - 60, 2, 60, (200, 200, 205, 255))
    cv.fill_poly([(fx + 1, fy - 60), (fx + 22, fy - 54), (fx + 1, fy - 48)], (220, 50, 50, 255))
    # Playground.
    px, py = iso.p(0.35, 1.75)
    cv.ellipse(px, py, 22, 10, (200, 180, 130, 255))
    cv.rect(px - 12, py - 14, 3, 14, (80, 120, 200, 255))
    cv.rect(px + 9, py - 14, 3, 14, (80, 120, 200, 255))
    cv.rect(px - 12, py - 15, 24, 2, (80, 120, 200, 255))
    cv.rect(px - 2, py - 4, 4, 4, (240, 200, 60, 255))
    # Clock on the roof edge.
    cx = (Tt[0] + Bt[0]) / 2
    cy = (Tt[1] + Bt[1]) / 2
    cv.ellipse(cx, cy, 6, 3, (250, 250, 250, 255))


def deco_hospital(cv, iso, base, top, h):
    T, R, B, L = base
    Tt, Rt, Bt, Lt = top
    cx = (Tt[0] + Bt[0]) / 2
    cy = (Tt[1] + Bt[1]) / 2
    # Helipad and red cross on the roof.
    cv.ellipse(cx, cy, 30, 15, (120, 120, 125, 255))
    cv.rect(cx - 16, cy - 3, 32, 6, (220, 40, 40, 255))
    cv.rect(cx - 3, cy - 10, 6, 20, (220, 40, 40, 255))
    # Cross on the left face.
    fx = L[0] + (B[0] - L[0]) * 0.5
    fy = L[1] + (B[1] - L[1]) * 0.5 - h * 0.55
    cv.rect(fx - 12, fy - 3, 24, 7, (220, 40, 40, 255))
    cv.rect(fx - 3, fy - 12, 7, 24, (220, 40, 40, 255))
    # Ambulance bay.
    cv.rect(B[0] + 6, B[1] - 22, 30, 20, (60, 70, 90, 255))
    cv.rect(B[0] + 8, B[1] - 20, 26, 14, (170, 210, 240, 255))


def civic_park():
    rng = random.Random(77)
    cv = Canvas(TW, TH + 50)
    iso = Iso(cv, 1)
    d = lot(cv, iso, grass=(92, 168, 78, 255))
    test = lambda x, y: point_in_poly(d, x, y)
    cv.speckle(test, 160, [(80, 150, 70, 255), (110, 185, 90, 255)], rng, 0, 50, TW - 1, cv.h - 1)
    # Pond.
    px, py = iso.p(0.62, 0.62)
    cv.ellipse(px, py, 20, 9, (70, 140, 210, 255))
    cv.ellipse(px - 4, py - 2, 8, 3, (140, 200, 240, 200))
    # Winding path.
    cv.fill_poly([iso.p(0.0, 0.5), iso.p(0.3, 0.42), iso.p(0.3, 0.58), iso.p(0.0, 0.62)], (200, 190, 160, 255))
    # Trees and a bench.
    for u, v, size in [(0.25, 0.25, 18), (0.75, 0.2, 14), (0.3, 0.8, 16)]:
        x, y = iso.p(u, v)
        draw_tree(cv, x, y, size, rng, (40, 100, 44, 255), (90, 170, 80, 255))
    bx, by = iso.p(0.85, 0.85)
    cv.rect(bx - 8, by - 6, 16, 3, (120, 80, 50, 255))
    cv.rect(bx - 7, by - 3, 2, 4, (90, 60, 40, 255))
    cv.rect(bx + 5, by - 3, 2, 4, (90, 60, 40, 255))
    cv.save(os.path.join(OUT, "civic_park.png"))


# --------------------------------------------------------------------------------------

def main():
    os.makedirs(OUT, exist_ok=True)
    for k in range(3):
        terrain_grass("terrain_grass_%d" % k, 10 + k)
    terrain_sand("terrain_sand", 20)
    for k in range(2):
        terrain_water("terrain_water_%d" % k, 30 + k)
    for k in range(2):
        terrain_forest("terrain_forest_%d" % k, 40 + k)
    for mask in range(16):
        road(mask)
    for zone in ("res", "com", "ind"):
        for density in (1, 2, 3):
            lot_sprite(zone, density)
    rubble()
    fire(0)
    fire(1)
    smoke()
    for hot in (False, True):
        alert_badge("power", paint_power, hot)
        alert_badge("water", paint_water, hot)
        alert_badge("road", paint_road, hot)
        alert_badge("abandoned", paint_abandoned, hot)
    for density in (1, 2, 3):
        for level in (1, 2, 3):
            for wealth in (1, 2, 3):
                res_sprite(density, level, wealth)
                com_sprite(density, level, wealth)
                ind_sprite(density, level, wealth)
    civic_coal()
    civic_wind()
    civic_nuclear()
    civic_pump()
    civic_tower()
    civic_service("police", (205, 208, 220, 255), (50, 70, 150, 255), 2, 44, deco_police)
    civic_service("fire_station", (190, 60, 50, 255), (90, 40, 40, 255), 2, 44, deco_fire)
    civic_service("school", (215, 150, 80, 255), (120, 70, 50, 255), 2, 40, deco_school)
    civic_service("hospital", (240, 240, 244, 255), (200, 200, 205, 255), 3, 56, deco_hospital)
    civic_park()
    print("Wrote sprites to", OUT)


if __name__ == "__main__":
    main()
