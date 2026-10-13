#!/usr/bin/env python3
"""플레이스홀더 2D 도트 그래픽 생성기.

실제 아트가 준비되면 같은 경로/파일명으로 PNG를 덮어쓰기만 하면 됩니다.
실행: python3 tools/generate_sprites.py   (Pillow 필요)
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")

PAL = {
    "k": (26, 28, 44, 255),     # 외곽선
    "W": (244, 244, 244, 255),
    "l": (148, 176, 194, 255),
    "m": (86, 108, 134, 255),
    "n": (51, 60, 87, 255),
    "s": (244, 196, 140, 255),  # 피부
    "r": (177, 62, 83, 255),
    "o": (239, 125, 87, 255),
    "y": (255, 205, 117, 255),
    "g": (167, 240, 112, 255),
    "G": (56, 183, 100, 255),
    "d": (37, 113, 121, 255),
    "b": (41, 54, 111, 255),
    "B": (59, 93, 201, 255),
    "c": (65, 166, 246, 255),
    "C": (115, 239, 247, 255),
    "p": (93, 39, 93, 255),
    "P": (150, 80, 180, 255),
    "v": (200, 140, 230, 255),
    "t": (138, 90, 60, 255),
    "T": (90, 58, 40, 255),
}


def save(img, *path):
    full = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full)
    print("wrote", os.path.relpath(full, os.path.join(ROOT, "..", "..")))


def from_map(rows, size=16, pal=None):
    pal = pal or PAL
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        row = row.ljust(size, ".")
        assert len(row) == size, (row, len(row))
        for x, ch in enumerate(row):
            if ch in pal:
                img.putpixel((x, y), pal[ch])
    return img


def outline(img, color=PAL["k"]):
    w, h = img.size
    src = img.copy()
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] > 0 and src.getpixel((nx, ny)) != color:
                    img.putpixel((x, y), color)
                    break
    return img


def canvas(w, h=None):
    return Image.new("RGBA", (w, h or w), (0, 0, 0, 0))


def put(img, pts, col):
    for x, y in pts:
        if 0 <= x < img.size[0] and 0 <= y < img.size[1]:
            img.putpixel((x, y), PAL[col] if isinstance(col, str) else col)


# ---------------------------------------------------------------- 캐릭터
PLAYER = [
    "................",
    ".....kkkkkk.....",
    "....kllllllk....",
    "...kllWllllmk...",
    "...kmllllllmk...",
    "...kkkkkkkkkk...",
    "....kssssksk....",
    "....ksssssskk...",
    "...kkBBBBBBkk...",
    "..kBBBcBBBBBBk..",
    "..ksBBBBBBBBsk..",
    "..kkbBBBBBBbkk..",
    "...kbbbbbbbbk...",
    "...ktk....ktk...",
    "...kTk....kTk...",
    "...kkk....kkk...",
]

SLIME = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "......kkkk......",
    "....kkggggkk....",
    "...kggWWgggGk...",
    "..kggWggggggGk..",
    "..kgggggggggGk..",
    ".kggkWggkWggGGk.",
    ".kggkkggkkgggGk.",
    ".kgggggggggggGk.",
    ".kGgggggggggGGk.",
    "..kGGGGGGGGGGk..",
    "...kkkkkkkkkk...",
]

GOBLIN = [
    "................",
    "................",
    "..k.........k...",
    "..kGk.kkkk.kGk..",
    "...kGkggggkGk...",
    "....kggggggk....",
    "...kgrkggrkgk...",
    "...kggggggggk...",
    "....kgWkWggk....",
    "....kkggggkk....",
    "...kTttttttTk...",
    "..kgkttttttkgk..",
    "..kk.kttttk.kk..",
    ".....kTkkTk.....",
    ".....kgk.kgk....",
    ".....kkk.kkk....",
]

MERCHANT = [
    "................",
    "......kkkk......",
    ".....kPPPPk.....",
    "....kPPvPPPk....",
    "..kkkkkkkkkkkk..",
    "...kssssssssk...",
    "...kskssssksk...",
    "...kssssssssk...",
    "....kWWWWWWk....",
    "...kooWWWWook...",
    "..kooyooooyook..",
    "..ksoooooooosk..",
    "...koooooooook..",
    "...kttttttttk...",
    "....kTk..kTk....",
    "....kkk..kkk....",
]


def slime_king():
    img = canvas(32)
    cx, cy, rx, ry = 15.5, 21.0, 14.0, 10.0
    for y in range(32):
        for x in range(32):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0 and y <= 30:
                col = "P"
                if d > 0.65 and y > cy:
                    col = "p"
                if ((x - 10) / 4) ** 2 + ((y - 16) / 2.5) ** 2 <= 1:
                    col = "v"
                img.putpixel((x, y), PAL[col])
    # 눈
    for ex in (10, 20):
        put(img, [(ex, 20), (ex + 1, 20), (ex, 21), (ex + 1, 21), (ex, 22), (ex + 1, 22)], "k")
        put(img, [(ex, 20)], "W")
    # 입
    put(img, [(x, 26) for x in range(13, 19)], "k")
    put(img, [(14, 27), (16, 27)], "W")
    # 왕관
    crown = [(x, y) for x in range(9, 23) for y in range(8, 12)]
    put(img, crown, "y")
    for px in (9, 15, 16, 22):
        put(img, [(px, 5), (px, 6), (px, 7)], "y")
    put(img, [(12, 6), (12, 7), (19, 6), (19, 7)], "y")
    put(img, [(12, 9), (15, 9), (16, 9), (19, 9)], "r")
    return outline(img)


# ---------------------------------------------------------------- 무기 아이콘 (우상단 대각선 방향)
def sword_icon(blade_light, blade_dark, guard="y", grip="T"):
    img = canvas(16)
    for x in range(6, 14):
        put(img, [(x, 15 - x)], blade_light)
        put(img, [(x, 16 - x)], blade_dark)
    put(img, [(14, 1)], blade_light)
    put(img, [(3, 8), (4, 9), (5, 10), (6, 11), (7, 12)], guard)
    put(img, [(4, 11), (3, 12)], grip)
    put(img, [(2, 13)], guard)
    return outline(img)


def dagger_icon():
    img = canvas(16)
    for x in range(8, 13):
        put(img, [(x, 15 - x)], "l")
        put(img, [(x, 16 - x)], "m")
    put(img, [(5, 8), (6, 9), (7, 10), (8, 11), (9, 12)], "G")
    put(img, [(6, 11), (5, 12), (4, 13)], "T")
    return outline(img)


def bow_icon(wood="t", string="W", dark=False):
    img = canvas(16)
    cx, cy, r = 3, 12, 10
    for i in range(0, 91, 3):
        a = math.radians(-90 + i)
        put(img, [(round(cx + r * math.cos(a)), round(cy + r * math.sin(a)))], wood)
    for i in range(11):
        put(img, [(cx + i, cy - 10 + i)], string)
    if dark:  # 석궁: 가운데 개머리판
        for i in range(8):
            put(img, [(2 + i, 13 - i)], "T")
    return outline(img)


def staff_icon(orb, shaft="t"):
    img = canvas(16)
    for i in range(10):
        put(img, [(2 + i, 13 - i)], shaft)
    put(img, [(x, y) for x in range(11, 15) for y in range(1, 5)], orb)
    put(img, [(12, 2)], "W")
    return outline(img)


# ---------------------------------------------------------------- 투사체
def slash():
    img = canvas(16)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 2.5, y - 7.5)
            if 8.0 <= d <= 11.5 and x >= 7:
                a = int(255 * (1.0 - (d - 8.0) / 4.0) * 0.9) + 25
                img.putpixel((x, y), (255, 255, 255, min(a, 255)))
    return img


def arrow():
    img = canvas(16)
    put(img, [(x, 7) for x in range(3, 12)], (230, 230, 230, 255))
    put(img, [(12, 6), (12, 7), (12, 8), (13, 6), (13, 7), (13, 8), (14, 7)], (255, 255, 255, 255))
    put(img, [(1, 6), (2, 6), (1, 8), (2, 8), (2, 7)], (200, 200, 200, 255))
    return img


def knife():
    img = canvas(16)
    put(img, [(x, 7) for x in range(5, 13)], (255, 255, 255, 255))
    put(img, [(x, 8) for x in range(5, 12)], (190, 190, 190, 255))
    put(img, [(13, 7)], (255, 255, 255, 255))
    put(img, [(4, 6), (4, 7), (4, 8), (4, 9)], (160, 160, 160, 255))
    put(img, [(2, 7), (3, 7), (2, 8), (3, 8)], (120, 120, 120, 255))
    return img


def orb(core=(255, 255, 255), edge=(255, 255, 255), size=8):
    img = canvas(size)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size / 2)
            if d <= 1.0:
                t = d
                col = tuple(int(core[i] * (1 - t) + edge[i] * t) for i in range(3))
                img.putpixel((x, y), col + (int(255 * (1.0 - d * 0.35)),))
    return img


def coin():
    img = from_map([
        "..kkkk..",
        ".kyyyyk.",
        "kyWyyyok",
        "kyyyyyok",
        "kyyyyyok",
        "kyyyyook",
        ".kooook.",
        "..kkkk..",
    ], size=8)
    return img


def shadow():
    img = canvas(12, 5)
    for y in range(5):
        for x in range(12):
            if ((x - 5.5) / 6) ** 2 + ((y - 2) / 2.5) ** 2 <= 1:
                img.putpixel((x, y), (0, 0, 0, 90))
    return img


# ---------------------------------------------------------------- 타일
def floor_tile():
    rnd = random.Random(7)
    img = canvas(32)
    bases = [(62, 137, 72), (58, 128, 68), (66, 142, 76), (60, 133, 70)]
    for ty in range(2):
        for tx in range(2):
            base = bases[ty * 2 + tx]
            for y in range(16):
                for x in range(16):
                    v = rnd.randint(-6, 6)
                    img.putpixel((tx * 16 + x, ty * 16 + y), (base[0] + v, base[1] + v, base[2] + v, 255))
            for _ in range(3):  # 풀잎
                x, y = rnd.randint(1, 14), rnd.randint(2, 14)
                put(img, [(tx * 16 + x, ty * 16 + y), (tx * 16 + x, ty * 16 + y - 1)], (99, 199, 77, 255))
                put(img, [(tx * 16 + x + 1, ty * 16 + y)], (99, 199, 77, 255))
    put(img, [(5, 21), (6, 21), (5, 22)], (234, 212, 170, 255))  # 꽃
    put(img, [(25, 6)], (255, 255, 255, 255))
    return img


def wall_tile():
    img = canvas(16)
    for y in range(16):
        for x in range(16):
            img.putpixel((x, y), (86, 108, 134, 255))
    for y in (0, 8):
        put(img, [(x, y) for x in range(16)], (51, 60, 87, 255))
    put(img, [(0, y) for y in range(1, 8)] + [(8, y) for y in range(9, 16)], (51, 60, 87, 255))
    put(img, [(x, 1) for x in range(1, 16)] + [(x, 9) for x in range(0, 8)] + [(x, 9) for x in range(9, 16)], (148, 176, 194, 255))
    return img


def rug():
    img = canvas(48, 24)
    for y in range(24):
        for x in range(48):
            border = x < 2 or y < 2 or x > 45 or y > 21
            stripe = (x + y) % 8 < 2
            col = (255, 205, 117, 255) if border else ((177, 62, 83, 255) if not stripe else (145, 45, 70, 255))
            img.putpixel((x, y), col)
    return img


# ---------------------------------------------------------------- UI
def bar(fill, w=64, h=8):
    img = canvas(w, h)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            c = fill
            if y == 1:
                c = tuple(min(255, v + 50) for v in fill)
            elif y == h - 2:
                c = tuple(max(0, v - 40) for v in fill)
            img.putpixel((x, y), c + (255,))
    return img


def bar_under(w=64, h=8):
    img = canvas(w, h)
    for y in range(h):
        for x in range(w):
            edge = x == 0 or y == 0 or x == w - 1 or y == h - 1
            img.putpixel((x, y), (26, 28, 44, 255) if edge else (51, 60, 87, 255))
    return img


def main():
    save(from_map(PLAYER), "characters", "player.png")
    save(from_map(SLIME), "characters", "slime.png")
    save(from_map(GOBLIN), "characters", "goblin.png")
    save(from_map(MERCHANT), "characters", "merchant.png")
    save(slime_king(), "characters", "slime_king.png")
    save(shadow(), "characters", "shadow.png")

    save(sword_icon("o", "t", "m", "T"), "weapons", "rusty_sword.png")
    save(sword_icon("W", "l", "y", "T"), "weapons", "iron_sword.png")
    save(sword_icon("y", "r", "o", "T"), "weapons", "flame_blade.png")
    save(dagger_icon(), "weapons", "goblin_dagger.png")
    save(bow_icon(), "weapons", "hunter_bow.png")
    save(bow_icon("n", "l", dark=True), "weapons", "rapid_crossbow.png")
    save(staff_icon("C"), "weapons", "apprentice_staff.png")
    save(staff_icon("g", "G"), "weapons", "slime_staff.png")
    save(staff_icon("P", "y"), "weapons", "king_scepter.png")

    save(slash(), "projectiles", "slash.png")
    save(arrow(), "projectiles", "arrow.png")
    save(knife(), "projectiles", "knife.png")
    save(orb(), "projectiles", "orb.png")
    save(orb((255, 255, 255), (230, 60, 110)), "projectiles", "enemy_bullet.png")

    save(coin(), "items", "coin.png")

    save(floor_tile(), "tiles", "floor.png")
    save(wall_tile(), "tiles", "wall.png")
    save(rug(), "tiles", "rug.png")

    save(bar_under(), "ui", "bar_under.png")
    save(bar((200, 50, 70)), "ui", "bar_hp.png")
    save(bar((65, 166, 246)), "ui", "bar_dash.png")
    save(bar((150, 80, 180)), "ui", "bar_boss.png")


if __name__ == "__main__":
    main()
