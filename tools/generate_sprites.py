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
    "....kTTTTTTk....",
    "...kTTtTTTTTk...",
    "...kTTTTTTTTk...",
    "...kTTssssTTk...",
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


def swing_arc():
    """근접 휘두르기 이펙트 (오른쪽을 향한 넓은 초승달, 무기 색으로 modulate)"""
    img = canvas(32)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - 4.0, y - 15.5)
            a = math.atan2(y - 15.5, x - 4.0)
            if 18.0 <= d <= 27.0 and abs(a) <= math.radians(62):
                edge = 1.0 - abs(a) / math.radians(62)
                t = (d - 18.0) / 9.0
                alpha = int(255 * min(1.0, edge * 2.2) * (0.35 + 0.65 * t))
                img.putpixel((x, y), (255, 255, 255, max(0, min(255, alpha))))
    return img


# ---------------------------------------------------------------- 방패 아이콘 (정면)
def round_shield(face, rim, boss=None):
    img = canvas(16)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5)
            if d <= 6.6:
                img.putpixel((x, y), PAL[rim] if d > 5.2 else PAL[face])
    if boss:
        put(img, [(7, 7), (8, 7), (7, 8), (8, 8)], boss)
    put(img, [(5, 4), (4, 5)], "W")
    return outline(img)


def wood_shield():
    img = canvas(16)
    for y in range(2, 15):
        for x in range(3, 13):
            if y > 10 and abs(x - 7.5) > (15 - y) * 1.2:
                continue
            img.putpixel((x, y), PAL["t"] if (x - 3) % 3 else PAL["T"])
    put(img, [(x, 5) for x in range(3, 13)] + [(x, 10) for x in range(4, 12)], "m")
    return outline(img)


def kite_shield(face, rim, emblem):
    img = canvas(16)
    for y in range(1, 15):
        half = 5.5 if y < 8 else 5.5 * (14 - y) / 6.0
        for x in range(16):
            if abs(x - 7.5) <= half:
                edge = abs(x - 7.5) > half - 1.2 or y == 1
                img.putpixel((x, y), PAL[rim] if edge else PAL[face])
    put(img, [(7, y) for y in range(3, 11)] + [(8, y) for y in range(3, 11)], emblem)
    put(img, [(x, 5) for x in range(5, 11)], emblem)
    return outline(img)


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


# ---------------------------------------------------------------- 2스테이지 몬스터
HELLHOUND = [
    "................",
    "................",
    "...........oy...",
    "..........kook..",
    "..o......knnnkk.",
    ".oyo....knnnyknk",
    "..ok...knnnnnnnk",
    "...knnnnnnnnnWk.",
    "..knnnnnnnnnkk..",
    "..knnnnnnnnnk...",
    "..knrnnnnnrnk...",
    "..knk.knk.knk...",
    "..kk..kk..kk....",
    "................",
    "................",
    "................",
]

ORC = [
    "................",
    "....kkkkkk......",
    "...kGGGGGGk.....",
    "..kGGrGGrGGk....",
    "..kGGGGGGGGk....",
    "..kGWGGGGWGk....",
    "...kGGGGGGk.....",
    "..kmmTTTTmmk....",
    ".kGmTTTTTTmGk...",
    ".kGkTTyTTTkGk...",
    ".kGkTTTTTTkGk...",
    "..k.kTTTTk.k....",
    "....kTkkTk......",
    "....kdk.kdk.....",
    "....kkk.kkk.....",
    "................",
]


def rect(img, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < img.size[0] and 0 <= y < img.size[1]:
                img.putpixel((x, y), PAL[col] if isinstance(col, str) else col)


def ellipse(img, cx, cy, rx, ry, col):
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                img.putpixel((x, y), PAL[col] if isinstance(col, str) else col)


def hell_gatekeeper():
    """지옥의 수문장: 불을 두른 거대한 오크 킹 (32x32)"""
    img = canvas(32)
    # 다리
    rect(img, 10, 25, 13, 30, "T")
    rect(img, 18, 25, 21, 30, "T")
    rect(img, 9, 29, 14, 30, "n")
    rect(img, 17, 29, 22, 30, "n")
    # 팔 (녹색 피부 + 불타는 팔찌)
    rect(img, 3, 14, 7, 24, "G")
    rect(img, 24, 14, 28, 24, "G")
    rect(img, 3, 21, 7, 23, "o")
    rect(img, 24, 21, 28, 23, "o")
    # 몸통 갑옷 (흑철 + 금 테두리)
    ellipse(img, 15.5, 19.5, 9.5, 7.5, "n")
    rect(img, 9, 15, 22, 15, "y")
    rect(img, 15, 13, 16, 26, "r")
    ellipse(img, 15.5, 20, 2.5, 2.5, "o")
    put(img, [(15, 20), (16, 20)], "y")
    # 머리
    ellipse(img, 15.5, 9.5, 6.5, 5.5, "G")
    put(img, [(12, 9), (13, 9), (18, 9), (19, 9)], "y")
    put(img, [(12, 10), (19, 10)], "r")
    put(img, [(12, 13), (12, 12), (19, 13), (19, 12)], "W")
    rect(img, 13, 13, 18, 13, "d")
    # 뿔 왕관
    rect(img, 10, 4, 21, 5, "y")
    for hx in (9, 10, 21, 22):
        put(img, [(hx, 1), (hx, 2), (hx, 3)], "W")
    put(img, [(13, 2), (13, 3), (18, 2), (18, 3), (15, 1), (16, 1), (15, 2), (16, 2), (15, 3), (16, 3)], "y")
    put(img, [(15, 4), (16, 4)], "r")
    # 어깨의 불꽃
    for base_x in (5, 26):
        for i, h in enumerate((5, 8, 6, 9, 4)):
            x = base_x - 2 + i
            for y in range(14 - h, 15):
                t = (14 - y) / h
                col = "y" if t > 0.75 else ("o" if t > 0.35 else "r")
                if 0 <= x < 32:
                    img.putpixel((x, y), PAL[col])
    return outline(img)


# ---------------------------------------------------------------- 3스테이지: 속성 골렘
GOLEM_PALETTES = {
    "fire":      ((92, 52, 44), (58, 30, 28), (255, 150, 60), (255, 230, 120)),
    "ice":       ((160, 205, 235), (90, 130, 180), (230, 250, 255), (255, 255, 255)),
    "lightning": ((96, 96, 120), (52, 52, 72), (255, 230, 80), (255, 255, 200)),
    "earth":     ((150, 112, 72), (96, 68, 42), (120, 220, 90), (210, 255, 170)),
}


def golem(body, dark, core, core_hi, size=20):
    img = canvas(size)
    b, d, c, h = body + (255,), dark + (255,), core + (255,), core_hi + (255,)
    s = size / 20.0
    R = lambda x0, y0, x1, y1, col: rect(img, int(x0 * s), int(y0 * s), int(x1 * s), int(y1 * s), col)
    R(5, 17, 8, 19, d)       # 다리
    R(11, 17, 14, 19, d)
    R(4, 8, 15, 16, b)       # 몸통
    R(4, 15, 15, 16, d)
    R(1, 8, 4, 15, d)        # 팔
    R(15, 8, 18, 15, d)
    R(1, 14, 4, 16, b)       # 주먹
    R(15, 14, 18, 16, b)
    R(7, 3, 12, 7, b)        # 머리
    R(8, 5, 8, 5, c)         # 눈
    R(11, 5, 11, 5, c)
    ellipse(img, 9.5 * s, 11.5 * s, 2.2 * s, 2.2 * s, c)   # 핵
    put(img, [(int(9 * s), int(11 * s))], h)
    put(img, [(int(6 * s), int(9 * s)), (int(13 * s), int(14 * s)), (int(5 * s), int(13 * s))], d)  # 균열
    return outline(img)


def archeon():
    """원소의 거신 아르케온 (40x40): 4원소 핵이 박힌 고대 거신 골렘"""
    img = canvas(40)
    stone, dark, gold = (78, 82, 104, 255), (44, 46, 64, 255), PAL["y"]
    rect(img, 9, 33, 16, 38, dark)
    rect(img, 23, 33, 30, 38, dark)
    rect(img, 8, 14, 31, 33, stone)
    rect(img, 8, 31, 31, 33, dark)
    rect(img, 1, 13, 8, 29, dark)
    rect(img, 31, 13, 38, 29, dark)
    rect(img, 0, 26, 8, 32, stone)
    rect(img, 31, 26, 39, 32, stone)
    rect(img, 8, 14, 31, 15, gold)
    rect(img, 19, 15, 20, 33, gold)
    rect(img, 13, 4, 26, 13, stone)
    rect(img, 15, 8, 17, 9, (120, 230, 255, 255))
    rect(img, 22, 8, 24, 9, (120, 230, 255, 255))
    # 수정 왕관
    for i, hgt in enumerate((3, 6, 4, 8, 4, 6, 3)):
        x = 13 + i * 2
        rect(img, x, 4 - hgt, x + 1, 3, (170, 120, 255, 255))
    # 4원소 핵 (십자 배치)
    cores = [((19.5, 19.5), GOLEM_PALETTES["fire"][2]), ((14.5, 24.0), GOLEM_PALETTES["ice"][2]),
             ((24.5, 24.0), GOLEM_PALETTES["lightning"][2]), ((19.5, 28.5), GOLEM_PALETTES["earth"][2])]
    for (cx, cy), col in cores:
        ellipse(img, cx, cy, 2.4, 2.4, col + (255,))
    put(img, [(19, 19), (14, 23), (24, 23), (19, 28)], "W")
    return outline(img)


# ---------------------------------------------------------------- 투구 (착용 오버레이 = 플레이어 머리 위치에 정확히 맞춤)
HELMETS_WORN = {
    "leather_cap": [
        "................",
        ".....kkkkkk.....",
        "....kttttttk....",
        "...kttTttttTk...",
        "...kTTTTTTTTk...",
        "...kTT....TTk...",
    ],
    "iron_helm": [
        "................",
        ".....kkkkkk.....",
        "....kllllllk....",
        "...kllWllllmk...",
        "...kmllllllmk...",
        "...kmm....mmk...",
    ],
    "orc_warhelm": [
        "..k........k....",
        "..klkkkkkkklk...",
        "...knnnnnnnnk...",
        "...knnmnnnnnk...",
        "...krrrrrrrrk...",
        "...knn....nnk...",
    ],
    "gatekeeper_horns": [
        ".kk..........kk.",
        ".kyk.kkkkkk.kyk.",
        "..kykrrrrrrkyk..",
        "...krroyyorrk...",
        "...krrrrrrrrk...",
        "...kro....ork...",
    ],
}


def helmet_icon(worn):
    img = canvas(16)
    img.paste(worn, (0, 5), worn)
    return img


# ---------------------------------------------------------------- 들고 있는 활 (세로, 시위는 코드에서 Line2D 로 그림)
def bow_held(wood, accent, crossbow=False):
    img = canvas(16)
    for y in range(1, 15):
        t = (y - 7.5) / 6.5
        x = round(5 + 5 * (1 - t * t))
        put(img, [(x, y)], wood)
        if 5 <= y <= 10:
            put(img, [(x - 1, y)], wood)
    put(img, [(9, 7), (9, 8), (10, 7), (10, 8)], accent)
    if crossbow:
        rect(img, 2, 7, 13, 8, "T")
    return outline(img)


# ---------------------------------------------------------------- 이펙트
def spark():
    img = canvas(4)
    for y in range(4):
        for x in range(4):
            edge = (x in (0, 3)) and (y in (0, 3))
            img.putpixel((x, y), (255, 255, 255, 0 if edge else 255))
    return img


def glow(size=32):
    img = canvas(size)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size / 2)
            if d < 1.0:
                img.putpixel((x, y), (255, 255, 255, int(255 * (1.0 - d) ** 2)))
    return img


def ring(size=32, width=2.5):
    img = canvas(size)
    c = (size - 1) / 2
    r = size / 2 - width
    for y in range(size):
        for x in range(size):
            d = abs(math.hypot(x - c, y - c) - r)
            if d < width:
                img.putpixel((x, y), (255, 255, 255, int(255 * (1.0 - d / width))))
    return img


def fireball():
    img = canvas(12)
    for y in range(12):
        for x in range(12):
            d = math.hypot(x - 6.5, y - 5.5)
            if d <= 5.2 and not (x < 3 and abs(y - 5.5) > 2):
                col = (255, 250, 200) if d < 1.8 else ((255, 200, 70) if d < 3.3 else (235, 90, 40))
                img.putpixel((x, y), col + (255,))
    return img


def ice_shard():
    img = canvas(14, 6)
    for x in range(14):
        half = 2.6 * (1 - abs(x - 6) / 7.5) if x < 13 else 0.4
        for y in range(6):
            if abs(y - 2.5) <= half:
                col = (240, 255, 255) if abs(y - 2.5) < 0.8 else (130, 210, 250)
                img.putpixel((x, y), col + (255,))
    return img


def rock():
    img = canvas(8)
    ellipse(img, 3.5, 3.5, 3.4, 3.0, (130, 100, 70, 255))
    put(img, [(2, 2), (3, 2)], (180, 150, 110, 255))
    return outline(img)


# ---------------------------------------------------------------- 스테이지 바닥
def floor_hell():
    rnd = random.Random(11)
    img = canvas(32)
    for y in range(32):
        for x in range(32):
            v = rnd.randint(-6, 6)
            img.putpixel((x, y), (72 + v, 34 + v // 2, 34 + v // 2, 255))
    for _ in range(4):  # 용암 균열
        x, y = rnd.randint(0, 31), rnd.randint(0, 31)
        for _ in range(9):
            img.putpixel((x % 32, y % 32), (255, 120, 40, 255))
            if rnd.random() < 0.5:
                img.putpixel(((x + 1) % 32, y % 32), (200, 60, 30, 255))
            x += rnd.choice((-1, 0, 1))
            y += 1
    return img


def floor_ruins():
    rnd = random.Random(5)
    img = canvas(32)
    for y in range(32):
        for x in range(32):
            v = rnd.randint(-5, 5)
            grout = x % 16 == 0 or y % 16 == 0 or (y % 16 == 8 and (x // 8) % 2 == 0)
            base = (70, 72, 82) if grout else (104 + v, 108 + v, 118 + v)
            img.putpixel((x, y), base + (255,))
    for _ in range(14):  # 이끼
        x, y = rnd.randint(0, 31), rnd.randint(0, 31)
        img.putpixel((x, y), (80, 130, 80, 255))
    return img


# ---------------------------------------------------------------- 갑옷 (착용 오버레이 = 플레이어 몸통 위치에 정확히 맞춤)
ARMOR_COLORS = {
    # 이름: (주색, 밝은 포인트, 어두운 색, 장식)
    "leather_armor": ("t", "y", "T", None),
    "chain_mail": ("l", "W", "m", "chain"),
    "hellsteel_plate": ("n", "r", "k", "trim"),
    "paladin_plate": ("W", "y", "l", "cross"),
}


def armor_worn(main_col, light, dark, deco):
    img = canvas(16)
    for y in range(8, 13):
        for x, ch in enumerate(PLAYER[y]):
            if ch in "Bb":
                col = main_col if ch == "B" else dark
                if deco == "chain" and (x + y) % 2 == 0:
                    col = dark
                put(img, [(x, y)], col)
            elif ch == "c":
                put(img, [(x, y)], light)
            elif ch == "k" and y in (8, 12):
                put(img, [(x, y)], "k")
    if deco == "trim":
        put(img, [(x, 8) for x in range(5, 11)], light)
        put(img, [(7, 10), (8, 10)], light)
    if deco == "cross":
        put(img, [(7, y) for y in range(9, 13)] + [(8, y) for y in range(9, 13)] + [(6, 10), (9, 10)], light)
    return img


def armor_icon(main_col, light, dark, deco):
    img = canvas(16)
    rect(img, 3, 3, 12, 12, main_col)          # 몸판
    rect(img, 1, 3, 3, 6, dark)                # 어깨
    rect(img, 12, 3, 14, 6, dark)
    rect(img, 6, 2, 9, 3, (0, 0, 0, 0))        # 목 부분
    rect(img, 4, 12, 11, 13, dark)
    if deco == "chain":
        for y in range(4, 12):
            for x in range(4, 12):
                if (x + y) % 2 == 0:
                    put(img, [(x, y)], dark)
    if deco == "trim":
        rect(img, 4, 4, 11, 4, light)
        rect(img, 7, 6, 8, 10, light)
    if deco == "cross":
        rect(img, 7, 5, 8, 11, light)
        rect(img, 5, 7, 10, 8, light)
    if deco is None:
        rect(img, 7, 4, 8, 11, dark)
        put(img, [(5, 6), (10, 6)], light)
    return outline(img)


# ---------------------------------------------------------------- 장신구 (팔찌 / 반지 / 펜던트)
# 등급별 (금속 색, 금속 어두운 색, 보석 색)
ACCESSORY_TIERS = [
    ((170, 110, 70), (110, 70, 45), (200, 80, 80)),      # 일반: 구리 / 가죽
    ((200, 210, 225), (130, 140, 160), (70, 140, 240)),  # 희귀: 은
    ((70, 60, 90), (40, 34, 56), (210, 30, 60)),         # 레어: 흑요석
    ((255, 205, 90), (190, 130, 40), (180, 240, 255)),   # 전설: 금 + 다이아
]


def bracelet_icon(metal, dark, gem):
    img = canvas(16)
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) / 6.5) ** 2 + ((y - 8.5) / 4.5) ** 2
            if 0.45 <= d <= 1.0:
                img.putpixel((x, y), (dark if y > 9 else metal) + (255,))
    for gx in (4, 7, 10):
        put(img, [(gx, 4), (gx + 1, 4), (gx, 5), (gx + 1, 5)], gem + (255,))
    put(img, [(5, 5)], (255, 255, 255, 255))
    return outline(img)


def ring_icon(metal, dark, gem):
    img = canvas(16)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 10.0)
            if 3.0 <= d <= 4.8:
                img.putpixel((x, y), (dark if y > 11 else metal) + (255,))
    ellipse(img, 7.5, 4.5, 2.8, 2.6, gem + (255,))
    put(img, [(6, 3), (7, 3)], (255, 255, 255, 255))
    return outline(img)


def pendant_icon(metal, dark, gem):
    img = canvas(16)
    for i in range(6):  # V 자 사슬
        put(img, [(2 + i, 1 + i), (13 - i, 1 + i)], metal + (255,))
    ellipse(img, 7.5, 10.5, 3.6, 3.8, dark + (255,))
    ellipse(img, 7.5, 10.5, 2.5, 2.7, gem + (255,))
    put(img, [(6, 9)], (255, 255, 255, 255))
    return outline(img)


ACCESSORIES = {
    "bracelet": (["leather_bracelet", "silver_bracelet", "obsidian_bracelet", "dragonscale_bracelet"], bracelet_icon),
    "ring": (["copper_ring", "ruby_ring", "blood_ruby_ring", "star_ring"], ring_icon),
    "pendant": (["wooden_pendant", "sapphire_pendant", "guardian_pendant", "life_pendant"], pendant_icon),
}


# ---------------------------------------------------------------- 회복 포션
POTIONS = {
    "small_potion": ((230, 60, 70), (255, 150, 150), 0.8),
    "potion": ((220, 40, 60), (255, 130, 140), 1.0),
    "greater_potion": ((170, 60, 220), (230, 160, 255), 1.15),
}


def potion_icon(liquid, light, sc):
    img = canvas(16)
    cx, cy, r = 7.5, 10.0, 4.6 * sc
    ellipse(img, cx, cy, r, r, (200, 230, 240, 255))                 # 유리병
    ellipse(img, cx, cy + 0.6, r - 1.0, r - 1.2, liquid + (255,))    # 물약
    rect(img, 6, int(cy - r) - 3, 9, int(cy - r) + 1, (200, 230, 240, 255))  # 병목
    rect(img, 6, int(cy - r) - 4, 9, int(cy - r) - 3, (140, 90, 50, 255))    # 코르크
    put(img, [(5, int(cy) - 1), (5, int(cy)), (6, int(cy) - 2)], light + (255,))
    return outline(img)


# ---------------------------------------------------------------- 월드 오브젝트
def portal(core, rim):
    img = canvas(32)
    for y in range(32):
        for x in range(32):
            dx, dy = (x - 15.5) / 13.0, (y - 15.5) / 15.0
            d = math.hypot(dx, dy)
            if d <= 1.0:
                a = math.atan2(dy, dx)
                swirl = (math.sin(a * 3 + d * 9) + 1) / 2
                t = d
                c = tuple(int(core[i] * (1 - t) + rim[i] * t) for i in range(3))
                c = tuple(min(255, int(v * (0.75 + 0.45 * swirl))) for v in c)
                img.putpixel((x, y), c + (int(255 * (0.55 + 0.45 * d)),))
    return outline(img)


def boss_gate(open_gate):
    img = canvas(32, 40)
    stone, dark, rune = (96, 92, 110, 255), (54, 50, 66, 255), (200, 60, 70, 255)
    rect(img, 0, 6, 31, 39, stone)
    rect(img, 0, 6, 31, 9, dark)
    for y in range(12, 40, 6):  # 벽돌 줄
        rect(img, 0, y, 31, y, dark)
    rect(img, 6, 12, 25, 39, (20, 14, 26, 255))  # 문 구멍
    ellipse(img, 15.5, 12, 9.5, 6, (20, 14, 26, 255))
    if open_gate:
        for y in range(8, 40):
            for x in range(6, 26):
                if img.getpixel((x, y))[:3] == (20, 14, 26):
                    t = abs(x - 15.5) / 10 + (40 - y) / 60
                    img.putpixel((x, y), (int(255 - 90 * t), int(70 + 40 * t), int(60 + 30 * t), 255))
    else:
        rect(img, 6, 20, 25, 23, (120, 110, 90, 255))   # 봉인 사슬
        rect(img, 14, 17, 17, 26, (200, 170, 60, 255))  # 자물쇠
    for rx, ry in ((2, 14), (28, 14), (2, 26), (28, 26)):
        put(img, [(rx, ry), (rx + 1, ry), (rx, ry + 1), (rx + 1, ry + 1)], rune if not open_gate else (255, 200, 90, 255))
    rect(img, 13, 0, 18, 5, dark)  # 해골 장식 자리
    put(img, [(14, 2), (17, 2)], rune)
    return outline(img)


def chest(opened):
    img = canvas(18, 16)
    wood, dark, gold = (150, 95, 50, 255), (95, 58, 32, 255), PAL["y"]
    rect(img, 1, 7, 16, 14, wood)
    rect(img, 1, 14, 16, 14, dark)
    if opened:
        rect(img, 1, 1, 16, 4, dark)       # 뒤로 젖혀진 뚜껑
        rect(img, 2, 5, 15, 7, (255, 230, 140, 255))  # 안쪽 빛
    else:
        rect(img, 1, 3, 16, 7, wood)
        rect(img, 1, 3, 16, 3, dark)
        rect(img, 7, 6, 10, 9, gold)
    rect(img, 4, 7, 4, 14, gold)
    rect(img, 13, 7, 13, 14, gold)
    return outline(img)


def campfire():
    img = canvas(16)
    rect(img, 2, 12, 13, 13, (110, 70, 40, 255))
    rect(img, 4, 11, 11, 11, (90, 56, 32, 255))
    for x in range(5, 11):
        h = 4 + (3 if x in (7, 8) else 0)
        for y in range(11 - h, 11):
            t = (11 - y) / h
            img.putpixel((x, y), PAL["y"] if t > 0.6 else (PAL["o"] if t > 0.25 else PAL["r"]))
    for sx, sy in ((1, 13), (14, 13), (3, 14), (12, 14)):
        put(img, [(sx, sy)], (120, 120, 130, 255))
    return outline(img)


# ---------------------------------------------------------------- 타이틀 배경 (320x180): 전사 vs 몬스터
def _paste_scaled(bg, img, x, y, scale, flip=False, alpha=1.0):
    im = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if alpha < 1.0:
        a = im.getchannel("A").point(lambda v: int(v * alpha))
        im.putalpha(a)
    bg.alpha_composite(im, (x, y))


def title_background():
    W, H = 320, 180
    rnd = random.Random(3)
    bg = Image.new("RGBA", (W, H))
    for y in range(H):  # 노을 하늘
        t = y / 125.0
        c = (int(36 + 200 * t ** 1.6), int(22 + 95 * t ** 1.4), int(64 + 30 * t))
        for x in range(W):
            bg.putpixel((x, y), tuple(min(255, v) for v in c) + (255,))
    ellipse(bg, 262, 34, 13, 13, (255, 236, 200, 255))  # 달
    ellipse(bg, 267, 31, 11, 11, (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            if bg.getpixel((x, y))[3] == 0:
                t = y / 125.0
                bg.putpixel((x, y), (int(36 + 200 * t ** 1.6), int(22 + 95 * t ** 1.4), int(64 + 30 * t), 255))
    for _ in range(40):  # 별
        x, y = rnd.randint(0, W - 1), rnd.randint(0, 60)
        bg.putpixel((x, y), (255, 240, 220, 255))
    # 먼 산 / 가까운 언덕
    for layer, (base_y, amp, col) in enumerate(((100, 22, (70, 42, 86)), (118, 14, (44, 30, 58)))):
        for x in range(W):
            h = base_y - amp * (0.5 + 0.5 * math.sin(x * (0.031 + 0.02 * layer) + layer)) - rnd.randint(0, 2)
            for y in range(int(h), H):
                bg.putpixel((x, y), col + (255,))
    # 무너진 유적 기둥
    for px, ph in ((28, 46), (44, 30), (292, 52), (276, 26)):
        rect(bg, px, 130 - ph, px + 7, 130, (58, 50, 74, 255))
        rect(bg, px - 1, 130 - ph, px + 8, 130 - ph + 2, (72, 62, 88, 255))
    # 땅
    for y in range(128, H):
        for x in range(W):
            v = rnd.randint(-5, 5)
            bg.putpixel((x, y), (40 + v, 72 + v, 46 + v, 255) if y < 134 else (32 + v, 52 + v, 36 + v, 255))
    # 전사 (투구·갑옷·방패·검)
    hero = from_map(PLAYER)
    for overlay_rows in (HELMETS_WORN["iron_helm"],):
        ov = from_map(overlay_rows)
        hero.alpha_composite(ov)
    hero.alpha_composite(armor_worn(*ARMOR_COLORS["paladin_plate"]))
    _paste_scaled(bg, Image.new("RGBA", (12, 3), (0, 0, 0, 90)), 54, 134, 4)
    sword = sword_icon("W", "y", "y", "B")
    _paste_scaled(bg, sword, 92, 46, 3)                 # 치켜든 성검
    _paste_scaled(bg, hero, 48, 72, 4)
    _paste_scaled(bg, kite_shield("l", "m", "B"), 40, 104, 2)
    # 몬스터들 (전사를 향해 왼쪽을 봄)
    _paste_scaled(bg, slime_king(), 222, 50, 3)
    _paste_scaled(bg, from_map(ORC), 176, 72, 4, flip=True)
    _paste_scaled(bg, from_map(GOBLIN), 270, 98, 3, flip=True)
    _paste_scaled(bg, from_map(SLIME), 206, 128, 2)
    _paste_scaled(bg, from_map(HELLHOUND), 134, 100, 3, flip=True)
    # 베기 섬광 + 불티
    _paste_scaled(bg, swing_arc(), 112, 70, 2, alpha=0.55)
    for _ in range(80):
        x, y = rnd.randint(112, 196), rnd.randint(60, 140)
        if math.hypot(x - 150, y - 100) < 40:
            bg.putpixel((x, y), rnd.choice(((255, 240, 160, 255), (255, 180, 80, 255), (255, 255, 255, 255))))
    return bg


def main():
    save(from_map(PLAYER), "characters", "player.png")
    save(from_map(SLIME), "characters", "slime.png")
    save(from_map(GOBLIN), "characters", "goblin.png")
    save(from_map(MERCHANT), "characters", "merchant.png")
    save(from_map(HELLHOUND), "characters", "hellhound.png")
    save(from_map(ORC), "characters", "orc.png")
    save(hell_gatekeeper(), "characters", "hell_gatekeeper.png")
    for name, pal in GOLEM_PALETTES.items():
        save(golem(*pal), "characters", f"golem_{name}.png")
    save(archeon(), "characters", "archeon.png")
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
    save(sword_icon("W", "y", "y", "B"), "weapons", "holy_sword.png")
    save(bow_icon("G", "W"), "weapons", "windrunner_bow.png")
    save(bow_icon("y", "o"), "weapons", "solaris_bow.png")
    save(staff_icon("C", "l"), "weapons", "frost_staff.png")
    save(staff_icon("o", "T"), "weapons", "ignis_staff.png")
    save(staff_icon("v", "B"), "weapons", "arcana_staff.png")
    save(bow_held("t", "T"), "weapons", "hunter_bow_held.png")
    save(bow_held("n", "m", crossbow=True), "weapons", "rapid_crossbow_held.png")
    save(bow_held("G", "g"), "weapons", "windrunner_bow_held.png")
    save(bow_held("y", "o"), "weapons", "solaris_bow_held.png")

    for name, rows in HELMETS_WORN.items():
        worn = from_map(rows)
        save(worn, "helmets", f"{name}_worn.png")
        save(helmet_icon(worn), "helmets", f"{name}.png")

    save(slash(), "projectiles", "slash.png")
    save(arrow(), "projectiles", "arrow.png")
    save(swing_arc(), "effects", "swing_arc.png")

    save(wood_shield(), "shields", "wooden_shield.png")
    save(kite_shield("l", "m", "B"), "shields", "iron_shield.png")
    save(round_shield("G", "T", "r"), "shields", "goblin_buckler.png")
    save(kite_shield("y", "o", "P"), "shields", "royal_aegis.png")
    save(kite_shield("n", "y", "C"), "shields", "colossus_bulwark.png")
    for name, cols in ARMOR_COLORS.items():
        save(armor_worn(*cols), "armors", f"{name}_worn.png")
        save(armor_icon(*cols), "armors", f"{name}.png")
    for _kind, (names, painter) in ACCESSORIES.items():
        for name, (metal, dark, gem) in zip(names, ACCESSORY_TIERS):
            save(painter(metal, dark, gem), "accessories", f"{name}.png")
    for name, (liquid, light, sc) in POTIONS.items():
        save(potion_icon(liquid, light, sc), "items", f"{name}.png")
    save(portal((255, 255, 255), (80, 170, 255)), "world", "portal_blue.png")
    save(portal((255, 240, 200), (255, 70, 60)), "world", "portal_red.png")
    save(portal((255, 255, 230), (255, 190, 60)), "world", "portal_gold.png")
    save(boss_gate(False), "world", "boss_gate_sealed.png")
    save(boss_gate(True), "world", "boss_gate_open.png")
    save(chest(False), "world", "chest_closed.png")
    save(chest(True), "world", "chest_open.png")
    save(campfire(), "world", "campfire.png")
    save(title_background(), "ui", "title_bg.png")
    save(spark(), "effects", "spark.png")
    save(glow(), "effects", "glow.png")
    save(ring(), "effects", "ring.png")
    save(fireball(), "projectiles", "fireball.png")
    save(ice_shard(), "projectiles", "ice_shard.png")
    save(rock(), "projectiles", "rock.png")
    save(orb(), "projectiles", "orb.png")
    save(orb((255, 255, 255), (230, 60, 110)), "projectiles", "enemy_bullet.png")

    save(coin(), "items", "coin.png")

    save(floor_tile(), "tiles", "floor.png")
    save(floor_hell(), "tiles", "floor_hell.png")
    save(floor_ruins(), "tiles", "floor_ruins.png")
    save(wall_tile(), "tiles", "wall.png")
    save(rug(), "tiles", "rug.png")

    save(bar_under(), "ui", "bar_under.png")
    save(bar((200, 50, 70)), "ui", "bar_hp.png")
    save(bar((65, 166, 246)), "ui", "bar_dash.png")
    save(bar((150, 80, 180)), "ui", "bar_boss.png")
    save(bar((255, 190, 70)), "ui", "bar_guard.png")


if __name__ == "__main__":
    main()
