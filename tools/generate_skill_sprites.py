#!/usr/bin/env python3
"""무기 액티브 스킬 [Q] 의 아이콘 · 이펙트 그림.

  assets/sprites/skills/<스킬 id>.png   HUD 스킬 칸 아이콘 (20x20)
  assets/sprites/effects/…             스킬 연출 (마계의 손아귀 · 마법진 · 태양 원반)
  assets/sprites/projectiles/…         스킬 투사체 (초승달 참격 · 핏빛 참격 · 태양의 화살 · 내리꽂히는 화살)
실행: python3 tools/generate_skill_sprites.py   (Pillow 필요)
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
K = (20, 18, 30, 255)


def canvas(w, h=None):
    return Image.new("RGBA", (w, h if h else w), (0, 0, 0, 0))


def save(img, *path):
    full = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def blend(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        under = img.getpixel((x, y))
        a = col[3] / 255.0
        if under[3] == 0:
            img.putpixel((x, y), col)
        else:
            img.putpixel((x, y), tuple(int(under[i] * (1 - a) + col[i] * a) for i in range(3)) + (max(under[3], col[3]),))


def disc(img, cx, cy, r, inner, outer, alpha=255):
    for y in range(img.height):
        for x in range(img.width):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
            if d <= 1.0:
                blend(img, x, y, lerp(inner, outer, d) + (alpha,))


def line(img, x0, y0, x1, y1, col, width=1.0):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for oy in range(-int(width), int(width) + 1):
            for ox in range(-int(width), int(width) + 1):
                if math.hypot(ox, oy) <= width * 0.75:
                    blend(img, int(round(x + ox)), int(round(y + oy)), col)


def arc(img, cx, cy, r, a0, a1, col, width=1.5):
    steps = int(abs(a1 - a0) * r * 2) + 2
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * i / steps
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        for oy in range(-2, 3):
            for ox in range(-2, 3):
                if math.hypot(ox, oy) <= width:
                    blend(img, int(round(x + ox)), int(round(y + oy)), col)


def frame(img, bg, edge):
    """아이콘 바탕: 둥근 사각형 + 테두리"""
    out = canvas(20)
    for y in range(20):
        for x in range(20):
            corner = (x in (0, 19)) and (y in (0, 19))
            if corner:
                continue
            border = x in (0, 19) or y in (0, 19)
            out.putpixel((x, y), (edge if border else lerp(bg, (0, 0, 0), y / 40.0)) + (255,))
    out.alpha_composite(img)
    return out


def blade(img, x0, y0, x1, y1, light, dark):
    line(img, x0, y0, x1, y1, dark + (255,), 1.6)
    line(img, x0, y0, x1, y1, light + (255,), 0.7)


# ============================================================ 아이콘
def icon_whirlwind():
    img = canvas(20)
    arc(img, 10, 10, 7, 0.3, 5.6, (255, 240, 200, 255), 1.2)
    arc(img, 10, 10, 4.5, 2.0, 7.5, (200, 220, 255, 230), 1.0)
    blade(img, 10, 10, 16, 4, (240, 240, 250), (120, 130, 150))
    return frame(img, (40, 50, 80), (150, 160, 200))


def icon_tempest():
    img = canvas(20)
    for k in range(3):
        arc(img, 10, 10, 3 + 2.3 * k, k * 1.1, k * 1.1 + 4.5, (255, 230 - 30 * k, 140, 255), 1.0)
    for a in range(8):
        ang = a * math.pi / 4
        blend(img, int(10 + math.cos(ang) * 8.5), int(10 + math.sin(ang) * 8.5), (255, 255, 220, 255))
    blade(img, 10, 10, 15, 5, (255, 250, 220), (200, 160, 60))
    return frame(img, (70, 55, 20), (250, 200, 90))


def icon_abyss():
    img = canvas(20)
    disc(img, 10, 11, 8, (120, 0, 30), (20, 0, 10), 255)
    for x0 in (4, 8, 12, 15):
        line(img, x0, 18, x0 + random.Random(x0).randint(-1, 1), 11, (60, 0, 20, 255), 0.8)
        blend(img, x0, 11, (255, 60, 90, 255))
    blade(img, 4, 16, 16, 3, (255, 90, 120), (90, 0, 30))
    return frame(img, (25, 5, 15), (220, 40, 70))


def icon_flurry():
    img = canvas(20)
    for i, (x, y) in enumerate([(5, 6), (14, 6), (5, 14), (14, 14)]):
        line(img, x - 3, y - 3, x + 3, y + 3, (220, 220, 255, 255), 0.7)
        line(img, x + 3, y - 3, x - 3, y + 3, (160, 150, 220, 200), 0.6)
    disc(img, 10, 10, 3, (120, 90, 200), (40, 20, 80))
    return frame(img, (30, 25, 50), (150, 130, 220))


def icon_volley():
    img = canvas(20)
    for k in range(-2, 3):
        ang = -math.pi / 2 + k * 0.32
        x1, y1 = 10 + math.cos(ang) * 8, 15 + math.sin(ang) * 11
        line(img, 10, 16, x1, y1, (200, 170, 110, 255), 0.5)
        blend(img, int(x1), int(y1), (255, 255, 230, 255))
    return frame(img, (40, 60, 40), (140, 200, 120))


def icon_meteor_rain():
    img = canvas(20)
    for i, (x, y) in enumerate([(5, 4), (10, 2), (15, 5), (7, 10), (13, 11)]):
        line(img, x, y, x, y + 5, (255, 230, 150, 255), 0.6)
        blend(img, x, y + 6, (255, 140, 60, 255))
    disc(img, 10, 17, 4, (255, 200, 100), (180, 60, 20), 180)
    return frame(img, (60, 40, 20), (250, 190, 90))


def icon_helios():
    img = canvas(20)
    disc(img, 10, 10, 5, (255, 255, 220), (255, 170, 40))
    for a in range(12):
        ang = a * math.pi / 6
        line(img, 10 + math.cos(ang) * 6, 10 + math.sin(ang) * 6, 10 + math.cos(ang) * 8.5, 10 + math.sin(ang) * 8.5, (255, 220, 100, 255), 0.5)
    line(img, 2, 17, 18, 3, (255, 255, 255, 255), 0.6)
    return frame(img, (80, 50, 10), (255, 210, 80))


def icon_blast():
    img = canvas(20)
    disc(img, 10, 10, 7, (255, 250, 230), (180, 90, 230))
    disc(img, 10, 10, 3, (255, 255, 255), (230, 200, 255))
    return frame(img, (40, 25, 70), (190, 140, 250))


def icon_cataclysm():
    img = canvas(20)
    for i, (x, y, r) in enumerate([(5, 14, 3), (9, 10, 3.5), (14, 6, 4.5)]):
        disc(img, x, y, r, (255, 250, 220), [(255, 120, 60), (120, 200, 255), (180, 120, 255)][i])
    return frame(img, (50, 30, 60), (220, 170, 250))


def icon_meteor_swarm():
    img = canvas(20)
    arc(img, 10, 13, 7, 0, math.tau, (200, 150, 255, 255), 0.8)
    for x, y in [(4, 3), (10, 1), (16, 4), (7, 7), (13, 8)]:
        line(img, x - 2, y - 2, x + 1, y + 2, (255, 240, 160, 200), 0.5)
        blend(img, x + 1, y + 2, (255, 255, 255, 255))
    disc(img, 10, 13, 2.5, (255, 255, 255), (200, 150, 255))
    return frame(img, (30, 15, 60), (210, 160, 255))


# ============================================================ 투사체 · 이펙트
def crescent(w, h, inner, outer):
    """앞으로 날아가는 초승달 참격 (오른쪽이 진행 방향)"""
    img = canvas(w, h)
    cy = (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d1 = math.hypot((x - w * 0.35) / (w * 0.62), (y - cy) / (h * 0.52))
            d2 = math.hypot((x - w * 0.12) / (w * 0.62), (y - cy) / (h * 0.62))
            if d1 <= 1.0 and d2 > 1.0:
                t = min(1.0, (d2 - 1.0) * 2.5)
                img.putpixel((x, y), lerp(outer, inner, t) + (int(255 * (0.5 + 0.5 * t)),))
    return img


def sun_arrow():
    img = canvas(26, 9)
    for x in range(26):
        half = 1.2 if x < 20 else (26 - x) * 0.7
        for y in range(9):
            d = abs(y - 4) / max(half + 1.5, 0.1)
            if d <= 1.0:
                img.putpixel((x, y), lerp((255, 255, 235), (255, 170, 40), d) + (int(255 * (0.4 + 0.6 * x / 26)),))
    return img


def sky_arrow():
    """하늘에서 내리꽂히는 화살 (아래쪽이 화살촉)"""
    img = canvas(7, 18)
    line(img, 3, 0, 3, 14, (210, 180, 120, 255), 0.5)
    for y in range(13, 18):
        half = (17 - y) * 0.6
        for x in range(7):
            if abs(x - 3) <= half:
                img.putpixel((x, y), (255, 245, 210, 255))
    for y in range(0, 4):
        img.putpixel((1, y), (255, 220, 120, 255))
        img.putpixel((5, y), (255, 220, 120, 255))
    return img


def hell_hand():
    """바닥에서 솟구치는 마계의 손아귀 (검붉은 손가락 다섯)"""
    img = canvas(18, 24)
    for x in range(4, 14):
        for y in range(14, 24):
            img.putpixel((x, y), lerp((90, 10, 30), (30, 0, 10), (y - 14) / 10) + (255,))
    for i, (fx, top) in enumerate([(4, 7), (7, 3), (10, 2), (13, 4), (15, 10)]):
        line(img, fx, 15, fx + (0 if i < 4 else 1), top, (110, 15, 40, 255), 1.1)
        blend(img, fx, top, (255, 60, 90, 255))
        blend(img, fx, top - 1, (255, 140, 160, 255))
    return img


def magic_circle(size, col):
    img = canvas(size)
    c = size / 2
    arc(img, c, c, c - 2, 0, math.tau, col + (255,), 0.9)
    arc(img, c, c, c * 0.68, 0, math.tau, col + (200,), 0.7)
    for k in range(6):
        a0 = k * math.tau / 6
        a1 = a0 + math.tau / 3
        line(img, c + math.cos(a0) * c * 0.68, c + math.sin(a0) * c * 0.68, c + math.cos(a1) * c * 0.68, c + math.sin(a1) * c * 0.68, col + (170,), 0.5)
    for k in range(12):
        a = k * math.tau / 12
        blend(img, int(c + math.cos(a) * (c - 5)), int(c + math.sin(a) * (c - 5)), (255, 255, 255, 255))
    return img


def sun_disc(size):
    img = canvas(size)
    c = size / 2
    disc(img, c, c, c * 0.55, (255, 255, 240), (255, 180, 40))
    for k in range(16):
        a = k * math.tau / 16
        line(img, c + math.cos(a) * c * 0.6, c + math.sin(a) * c * 0.6, c + math.cos(a) * (c - 1), c + math.sin(a) * (c - 1), (255, 220, 110, 220), 0.6)
    return img


def main():
    icons = {
        "whirlwind": icon_whirlwind, "holy_tempest": icon_tempest, "abyss_descent": icon_abyss,
        "flurry": icon_flurry, "shadow_dance": icon_flurry,
        "volley": icon_volley, "meteor_rain": icon_meteor_rain, "helios": icon_helios,
        "blast": icon_blast, "cataclysm": icon_cataclysm, "meteor_swarm": icon_meteor_swarm,
    }
    for name, fn in icons.items():
        save(fn(), "skills", name + ".png")
    save(crescent(26, 18, (255, 255, 235), (255, 200, 90)), "projectiles", "skill_crescent.png")
    save(crescent(28, 20, (255, 120, 150), (110, 0, 30)), "projectiles", "abyss_slash.png")
    save(sun_arrow(), "projectiles", "sun_arrow.png")
    save(sky_arrow(), "projectiles", "sky_arrow.png")
    save(hell_hand(), "effects", "hell_hand.png")
    save(magic_circle(48, (200, 150, 255)), "effects", "magic_circle.png")
    save(sun_disc(40), "effects", "sun_disc.png")
    print("ok")


if __name__ == "__main__":
    main()
