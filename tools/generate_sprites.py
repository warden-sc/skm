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


def star():
    """아르카나의 별똥별: 16x16 다섯 갈래 별 (흰 중심 → 금색 → 보라 테두리)"""
    img = canvas(16)
    cx, cy = 7.5, 8.0
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        r = 7.4 if i % 2 == 0 else 3.1
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))

    def inside(x, y):
        hit = False
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
                hit = not hit
            j = i
        return hit

    for y in range(16):
        for x in range(16):
            if inside(x + 0.5, y + 0.5):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                col = (255, 255, 240) if d < 2.2 else ((255, 225, 110) if d < 4.6 else (240, 170, 255))
                img.putpixel((x, y), col + (255,))
    return outline(img, (70, 30, 110, 255))


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



# ---------------------------------------------------------------- 4스테이지: 숲
FOREST_WOLF = [
    "................",
    "................",
    "...........kk...",
    "..........kddk..",
    "..d......kdmmkk.",
    ".kdd....kmmmmkmk",
    "..kdk..kmmmmmmmk",
    "...kmmmmmmmmmWk.",
    "..kmmmmmmmmmkk..",
    "..kmGmmGmmmmk...",
    "..kmmmmmmmmmk...",
    "..kmk.kmk.kmk...",
    "..kk..kk..kk....",
    "................",
    "................",
    "................",
]

MUSHROOM = [
    "................",
    "................",
    ".....kkkkkk.....",
    "...kkrrWrrrkk...",
    "..krrrrrrWrrrk..",
    ".krWrrrrrrrrWrk.",
    ".krrrrrWrrrrrrk.",
    ".kkkkkkkkkkkkkk.",
    "....kWWWWWWk....",
    "....kWkWWkWk....",
    "....kWWWWWWk....",
    "....kWWrrWWk....",
    "...kWWWWWWWWk...",
    "...kkk.kk.kkk...",
    "................",
    "................",
]


def treant():
    """덩굴 트렌트 (20x20): 이끼 낀 나무 몸통 + 잎 왕관 + 빛나는 눈"""
    img = canvas(20)
    bark, dark, leaf, leaf2 = (110, 74, 48, 255), (70, 46, 30, 255), (70, 150, 60, 255), (120, 200, 80, 255)
    ellipse(img, 10, 5, 8.5, 4.5, leaf)
    ellipse(img, 7, 4, 3.5, 2.5, leaf2)
    ellipse(img, 13, 3.5, 3, 2, leaf2)
    rect(img, 6, 7, 13, 16, bark)
    rect(img, 6, 15, 13, 16, dark)
    rect(img, 2, 9, 5, 11, bark)      # 팔
    rect(img, 1, 11, 2, 13, dark)
    rect(img, 14, 9, 17, 11, bark)
    rect(img, 17, 11, 18, 13, dark)
    rect(img, 6, 17, 8, 19, dark)     # 뿌리 다리
    rect(img, 11, 17, 13, 19, dark)
    put(img, [(8, 10), (11, 10)], (230, 255, 120, 255))
    put(img, [(9, 13), (10, 13)], dark)
    put(img, [(7, 8), (12, 12), (6, 14)], leaf)
    return outline(img)


def dryad():
    """숲의 주인 드라이어드 (24x32): 잎 머리카락 · 꽃 왕관 · 덩굴 드레스 · 나무 지팡이"""
    img = canvas(24, 32)
    skin, hair, hair2 = (150, 210, 140, 255), (60, 140, 60, 255), (110, 200, 80, 255)
    dress, dress2, wood = (40, 110, 60, 255), (80, 170, 90, 255), (120, 80, 50, 255)
    flower, flower2 = (255, 140, 190, 255), (255, 230, 120, 255)
    # 머리카락 (잎사귀 갈래)
    ellipse(img, 11.5, 7, 6.5, 6, hair)
    for x, y in ((5, 12), (6, 15), (17, 12), (16, 15), (5, 17)):
        ellipse(img, x, y, 1.6, 2.4, hair)
    ellipse(img, 9, 4, 2.5, 1.6, hair2)
    # 얼굴
    rect(img, 9, 6, 14, 11, skin)
    put(img, [(10, 8), (13, 8)], (40, 90, 40, 255))
    put(img, [(11, 10), (12, 10)], (110, 160, 100, 255))
    # 꽃 왕관
    for x in (7, 11, 15):
        put(img, [(x, 2), (x + 1, 2), (x, 3), (x + 1, 3)], flower)
        put(img, [(x, 2)], flower2)
    # 몸 / 덩굴 드레스 (아래로 퍼짐)
    rect(img, 9, 12, 14, 17, dress2)
    for y in range(17, 30):
        half = 3 + (y - 17) * 0.55
        for x in range(int(11.5 - half), int(11.5 + half) + 1):
            img.putpixel((x, y), dress if (x + y) % 5 else dress2)
    for x, y in ((8, 20), (14, 23), (10, 26), (16, 28), (6, 28)):
        put(img, [(x, y), (x + 1, y)], flower if (x + y) % 2 else flower2)
    # 팔 + 나무 지팡이
    rect(img, 6, 13, 8, 15, skin)
    rect(img, 15, 13, 17, 15, skin)
    rect(img, 19, 4, 19, 30, wood)
    ellipse(img, 19, 3, 2.2, 2.2, hair2)
    put(img, [(19, 3)], flower2)
    return outline(img)


def thorn():
    """드라이어드의 가시 탄 (10x5)"""
    img = canvas(10, 5)
    for x in range(10):
        half = 2.0 * (1 - x / 10.0)
        for y in range(5):
            if abs(y - 2) <= half:
                img.putpixel((x, y), (120, 200, 70, 255) if abs(y - 2) < 0.8 else (60, 120, 40, 255))
    put(img, [(9, 2)], (230, 255, 160, 255))
    return img


def spore():
    """포자 버섯의 포자 탄 (8x8)"""
    img = canvas(8)
    ellipse(img, 3.5, 3.5, 3.2, 3.2, (170, 120, 210, 255))
    ellipse(img, 3, 3, 1.6, 1.6, (230, 200, 255, 255))
    return img


def floor_forest():
    """숲 바닥 (32x32): 짙은 풀 + 낙엽 + 작은 꽃"""
    rnd = random.Random(11)
    img = canvas(32)
    for y in range(32):
        for x in range(32):
            v = rnd.randint(-6, 6)
            img.putpixel((x, y), (34 + v, 82 + v, 44 + v, 255))
    for _ in range(26):  # 풀잎
        x, y = rnd.randint(0, 31), rnd.randint(1, 31)
        img.putpixel((x, y), (60, 120, 58, 255))
        img.putpixel((x, y - 1), (78, 140, 66, 255))
    for _ in range(8):  # 낙엽
        x, y = rnd.randint(0, 30), rnd.randint(0, 30)
        col = rnd.choice([(150, 100, 50, 255), (170, 130, 60, 255)])
        put(img, [(x, y), (x + 1, y)], col)
    for _ in range(1):  # 꽃
        x, y = rnd.randint(1, 30), rnd.randint(1, 30)
        put(img, [(x, y)], (255, 230, 120, 255))
        put(img, [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], (240, 150, 200, 255))
    return img


# ---------------------------------------------------------------- 5스테이지: 어둠의 성
DARK_PAL = dict(PAL)
DARK_PAL.update({
    "a": (58, 60, 74, 255),     # 어두운 강철
    "A": (96, 100, 120, 255),   # 강철 하이라이트
    "e": (36, 36, 48, 255),     # 그림자 강철
    "x": (200, 60, 255, 255),   # 보랏빛 눈
    "q": (120, 30, 50, 255),    # 핏빛 망토
    "h": (70, 55, 90, 255),     # 어두운 천
})

DARK_KNIGHT = [
    "................",
    ".....kkkkkk.....",
    "....kAAAAAak....",
    "....kaxaxaak....",
    "....kaaaaaak....",
    ".....kaaaak.....",
    "...kkqAAAAqkk...",
    "..kAkqaaaaqkAk.k",
    "..kakqaAAaqkakkA",
    "..kak.aaaa.kakkA",
    "...k.kaeeak.k.kA",
    ".....kaeeak...kA",
    "....kaak.kaak..k",
    "....kek...kek...",
    "....kkk...kkk...",
    "................",
]

HEAVY_KNIGHT = [
    ".....kkkkkk.....",
    "....kAAAAAAk....",
    "...kAaxaaxaAk...",
    "...kaaaaaaaak...",
    "...kkaaaaaakk...",
    "kkkkqAAAAAAqk...",
    "kAAkaaaAAaaaak..",
    "kAqkaaaaaaaaak..",
    "kAqkeaaaaaaeak..",
    "kAAkeeaaaaeeak..",
    "kkkk.kaeeak.k...",
    "....kaaeeaak....",
    "...kaaak.kaaak..",
    "...keek...keek..",
    "...kkkk...kkkk..",
    "................",
]

DARK_ARCHER = [
    "................",
    ".....kkkkkk.....",
    "....khhhhhhk....",
    "...khhxhhxhhk...",
    "...khheeeehhk...",
    "....kheeeehk.k..",
    "...kkhhhhhhkktk.",
    "..khkhaaaahkkWtk",
    "..khkhaAAahk.Wtk",
    "..kk.haaaah..Wtk",
    "....khhhhhhk.ktk",
    "....khhkkhhk..k.",
    "....khk..khk....",
    "....kek..kek....",
    "....kkk..kkk....",
    "................",
]


def dullahan(with_head=True):
    """기사단장 듀라한 (24x32): 머리 없는 흑기사, 핏빛 망토, 대검. with_head 면 옆구리에 투구 머리를 끼고 있음"""
    img = canvas(24, 32)
    steel, dark, hi = DARK_PAL["a"], DARK_PAL["e"], DARK_PAL["A"]
    cape, eye = DARK_PAL["q"], DARK_PAL["x"]
    # 망토 (뒤)
    for y in range(8, 30):
        half = 5 + (y - 8) * 0.3
        for x in range(int(11.5 - half), int(11.5 + half) + 1):
            img.putpixel((x, y), cape)
    # 목에서 피어오르는 어둠
    for x, y in ((11, 3), (12, 2), (10, 4), (13, 4), (11, 5), (12, 5)):
        img.putpixel((x, y), (150, 60, 220, 255))
    rect(img, 8, 6, 15, 7, hi)          # 목 가리개
    rect(img, 7, 8, 16, 18, steel)      # 몸통
    rect(img, 7, 8, 16, 9, hi)
    rect(img, 11, 10, 12, 17, dark)
    rect(img, 4, 8, 6, 11, hi)          # 어깨
    rect(img, 17, 8, 19, 11, hi)
    rect(img, 4, 12, 6, 18, steel)      # 팔
    rect(img, 17, 12, 19, 18, steel)
    rect(img, 8, 19, 15, 21, dark)      # 허리
    rect(img, 8, 22, 10, 29, steel)     # 다리
    rect(img, 13, 22, 15, 29, steel)
    rect(img, 7, 29, 10, 31, dark)
    rect(img, 13, 29, 16, 31, dark)
    # 대검 (오른손, 아래로)
    rect(img, 20, 6, 21, 27, (180, 185, 205, 255))
    rect(img, 18, 18, 23, 19, DARK_PAL["y"])
    put(img, [(20, 5), (21, 5)], (220, 225, 240, 255))
    if with_head:
        # 왼팔에 낀 투구 머리 (보라 눈)
        ellipse(img, 3.5, 17.5, 3.4, 3.2, steel)
        rect(img, 1, 15, 6, 15, hi)
        put(img, [(2, 17), (5, 17)], eye)
        put(img, [(3, 19), (4, 19)], dark)
    return outline(img)


def dullahan_head():
    """던져진 듀라한의 머리 (14x14): 투구 + 빛나는 눈 + 어둠의 기운"""
    img = canvas(14)
    steel, hi, eye = DARK_PAL["a"], DARK_PAL["A"], DARK_PAL["x"]
    ellipse(img, 6.5, 7, 6, 5.6, steel)
    rect(img, 2, 3, 11, 4, hi)
    rect(img, 6, 1, 7, 3, DARK_PAL["q"])   # 투구 장식
    rect(img, 3, 7, 10, 7, DARK_PAL["e"])  # 눈 틈
    put(img, [(4, 7), (5, 7), (8, 7), (9, 7)], eye)
    for x in range(3, 11, 2):
        put(img, [(x, 10)], DARK_PAL["e"])
    return outline(img)


def throne():
    """빈 옥좌 (32x44): 검은 돌 옥좌 + 해진 핏빛 천 + 왕관 장식"""
    img = canvas(32, 44)
    stone, dark, hi = (52, 50, 66, 255), (32, 30, 42, 255), (86, 82, 104, 255)
    gold, cloth = (200, 160, 70, 255), (110, 26, 44, 255)
    rect(img, 6, 2, 25, 30, stone)       # 등받이
    rect(img, 6, 2, 25, 3, hi)
    for x in (6, 12, 19, 25):            # 뾰족한 장식
        rect(img, x - 1, 0, x, 2, hi)
    rect(img, 12, 6, 19, 24, cloth)      # 등받이 천
    put(img, [(15, 8), (16, 8), (14, 9), (17, 9), (15, 10), (16, 10)], gold)  # 문장
    rect(img, 2, 22, 29, 33, stone)      # 팔걸이 + 좌석
    rect(img, 2, 22, 6, 24, hi)
    rect(img, 25, 22, 29, 24, hi)
    rect(img, 7, 26, 24, 28, cloth)      # 좌석 천
    rect(img, 4, 34, 27, 40, dark)       # 계단
    rect(img, 1, 40, 30, 43, stone)
    rect(img, 1, 40, 30, 40, hi)
    return outline(img)


def floor_castle():
    """어둠의 성 바닥 (32x32): 검푸른 석판 + 금 간 틈 + 핏빛 융단 가장자리"""
    rnd = random.Random(21)
    img = canvas(32)
    for y in range(32):
        for x in range(32):
            v = rnd.randint(-4, 4)
            grout = x % 16 == 0 or y % 16 == 0
            base = (34, 33, 44) if grout else (66 + v, 64 + v, 80 + v)
            img.putpixel((x, y), base + (255,))
    for _ in range(3):  # 금
        x, y = rnd.randint(2, 28), rnd.randint(2, 28)
        for i in range(4):
            put(img, [(x + i, y + (i % 2))], (30, 28, 40, 255))
    for _ in range(5):  # 보랏빛 이끼
        x, y = rnd.randint(0, 31), rnd.randint(0, 31)
        img.putpixel((x, y), (80, 60, 100, 255))
    return img


def dark_slash():
    """듀라한의 암흑 검기 (14x14 초승달)"""
    img = canvas(14)
    for y in range(14):
        for x in range(14):
            d1 = math.hypot(x - 4.0, y - 6.5)
            d2 = math.hypot(x - 1.5, y - 6.5)
            if d1 <= 6.2 and d2 > 6.0:
                img.putpixel((x, y), (200, 120, 255, 255) if d1 > 4.8 else (120, 50, 190, 255))
    return img


# ---------------------------------------------------------------- 6~10스테이지
X_PAL = dict(PAL)
X_PAL.update({
    "a": (58, 60, 74, 255), "A": (96, 100, 120, 255), "e": (36, 36, 48, 255),
    "h": (120, 150, 70, 255),   # 홉고블린 피부
    "H": (80, 105, 45, 255),
    "f": (230, 210, 190, 255),  # 뼈
    "F": (170, 155, 140, 255),
    "u": (190, 235, 255, 255),  # 유령
    "U": (120, 180, 220, 255),
    "z": (200, 80, 60, 255),    # 와이번 비늘
    "Z": (130, 45, 40, 255),
    "j": (90, 170, 140, 255),   # 리자드맨
    "J": (50, 110, 90, 255),
    "i": (245, 180, 200, 255),  # 서큐버스 피부
    "I": (110, 30, 70, 255),    # 서큐버스 날개/옷
    "Q": (220, 180, 70, 255),   # 금
    "q": (160, 30, 50, 255),    # 핏빛
    "x": (200, 60, 255, 255),
})

HOBGOBLIN = [
    "................",
    "...k........k...",
    "...kHk.kkkk.kHk.",
    "....kHkhhhhkHk..",
    ".....khrhhrhk...",
    ".....khhhhhhk...",
    ".....khWkkWhk..k",
    "....kkhhhhhhkkkt",
    "...khkttttttkhkt",
    "...khktTTTTtkhkt",
    "...kk.ttttttkkkk",
    "......kTTTTk....",
    ".....khk..khk...",
    ".....kHk..kHk...",
    ".....kkk..kkk...",
    "................",
]

ORC_WARRIOR = [
    "....kkkkkk......",
    "...kGGGGGGk.....",
    "..kGGrGGrGGk....",
    "..kGGGGGGGGk....",
    "..kGWGGGGWGk..k.",
    "...kGGGGGGk..klk",
    "kkkkmmTTTTmk.klk",
    "ktykTTTTTTTmkklk",
    "ktykTTyTTTTkGklk",
    "ktykTTTTTTTkGkyk",
    "kkkk.kTTTTk.kkyk",
    "....kTkkTk...kk.",
    "....kmk.kmk.....",
    "....kdk.kdk.....",
    "....kkk.kkk.....",
    "................",
]

ORC_SHAMAN = [
    "..........kfk...",
    "....kkkkkkkfk...",
    "...kPPPPPPkTk...",
    "..kPGGGGGGPkTk..",
    "..kPGxGGxGPkTk..",
    "..kPGGGGGGPkTk..",
    "...kGWGGWGk.kTk.",
    "..kPPPPPPPPk.Tk.",
    ".kPPPPyPPPPPkTk.",
    ".kPkPPPPPPkPkTk.",
    ".kk.kPPPPk.kkTk.",
    "....kPPPPk...k..",
    "...kPPPPPPk.....",
    "...kGGkkGGk.....",
    "...kkk..kkk.....",
    "................",
]

SKELETON = [
    "................",
    ".....kkkkk......",
    "....kfffffk.....",
    "....kfekefk.....",
    "....kfffffk.....",
    ".....kfkfk......",
    "...kk.kfk.kk..k.",
    "..kfkkfffkkfk.kl",
    "..kfk.kfk.kfkkl.",
    "...k.kfffk.kkl..",
    ".....kf.fk..kk..",
    ".....kfkfk......",
    "....kf...fk.....",
    "....kF...Fk.....",
    "....kk...kk.....",
    "................",
]

GHOST = [
    "................",
    ".....kkkkkk.....",
    "....kuuuuuuk....",
    "...kuuuuuuuuk...",
    "...kuukuukuuk...",
    "...kuukuukuuk...",
    "..kuuuuuuuuuuk..",
    "..kuuuukkuuuuk..",
    "..kuuuuuuuuuuk..",
    "..kUuuuuuuuuUk..",
    "..kUUuuuuuuUUk..",
    "..kUUUuuuuUUUk..",
    "..kUkUUkkUUkUk..",
    "..kk.kk..kk.kk..",
    "................",
    "................",
]

BABY_WYVERN = [
    "................",
    ".kk..........kk.",
    "kzzk........kzzk",
    "kzZzk..kk..kzZzk",
    ".kzZzkkzzkkzZzk.",
    "..kzZkzyzzkZzk..",
    "...kkzzzzzzkk...",
    "....kzzWzWzk....",
    "....kzzzzzzk....",
    ".....kzZZzk.....",
    "......kzzk......",
    "......kzZk......",
    ".......kzk......",
    "........kk......",
    "................",
    "................",
]

LIZARDMAN = [
    "..........k.....",
    "....kkkk.klk....",
    "...kjjjjkklk....",
    "..kjjrjjjklk....",
    "..kjjjjjjJlk....",
    "...kkjjjjkTk....",
    "..kjjJJJJjTk....",
    ".kjkjJyyJjTk....",
    ".kjkjJJJJkjk....",
    ".kk.kjJJjkkk....",
    "....kjjjjk......",
    "...kjjkkjjk.....",
    "...kjk..kjk.....",
    "...kJk..kJk..kk.",
    "...kkk..kkkkkJk.",
    "............kk..",
]

LESSER_SUCCUBUS = [
    ".k............k.",
    "kIk..kkkkkk..kIk",
    "kIIkkpppppkkkIIk",
    "kIIkpiiiiipkkIIk",
    ".kIkpixiixipkIk.",
    "..kkpiiiiiipkk..",
    "...kpkiqqikpk...",
    "..kIkkiiiikkIk..",
    ".kIIkIIIIIIkIIk.",
    ".kIk.kiIIik.kIk.",
    "..k..kIIIIk..k..",
    ".....kIIIIk.....",
    "....kiik.kiik...",
    "....kik...kik.k.",
    "....kkk...kkkIk.",
    "..............k.",
]

ROYAL_GUARD = [
    "......kk........",
    ".....kQQk....k..",
    "....kAAAAk..kQk.",
    "...kAAAAAAk.klk.",
    "...kAkkkkAk.klk.",
    "...kAAAAAAk.klk.",
    "kkkkqQQQQqkkklk.",
    "kqqkqqqqqqqkklk.",
    "kqQkqqQQqqqkAlk.",
    "kqqkqqqqqqqkAkk.",
    "kkkk.kqqqqk.kk..",
    "....kAAkAAk.....",
    "...kAAk.kAAk....",
    "...kek...kek....",
    "...kkk...kkk....",
    "................",
]

COURT_MAGE = [
    "......kk........",
    ".....kBBk.......",
    "....kBQBBk......",
    "...kBBBBBBk.kk..",
    "..kkkkkkkkkkCk..",
    "....kssssk.kCCk.",
    "....kskskk..kk..",
    "....kssssk..kTk.",
    "...kBBQQBBk.kTk.",
    "..kBBBBBBBBkkTk.",
    "..kBkBBQBBkBkTk.",
    "..kk.kBBBBk.kTk.",
    "....kBBBBBBk.k..",
    "...kBBBBBBBBk...",
    "...kkkkkkkkkk...",
    "................",
]


def orc_king():
    """오크킹 (40x40): 거대한 오크, 머리에 금관, 털 망토, 거대 도끼"""
    img = canvas(40)
    skin, skin_d = (70, 150, 70, 255), (45, 105, 50, 255)
    fur, fur_d, gold = (150, 120, 90, 255), (100, 80, 60, 255), X_PAL["Q"]
    leather = (110, 70, 45, 255)
    ellipse(img, 19.5, 26, 15, 9, fur)            # 털 망토
    rect(img, 10, 16, 29, 32, leather)            # 몸통
    rect(img, 10, 16, 29, 18, fur_d)
    rect(img, 19, 18, 20, 32, (80, 50, 35, 255))
    rect(img, 4, 17, 9, 29, skin)                 # 팔
    rect(img, 30, 17, 35, 29, skin)
    rect(img, 4, 27, 9, 30, skin_d)
    rect(img, 12, 33, 17, 39, skin_d)             # 다리
    rect(img, 22, 33, 27, 39, skin_d)
    rect(img, 12, 4, 27, 16, skin)                # 머리
    rect(img, 12, 13, 27, 16, skin_d)
    put(img, [(15, 9), (16, 9), (23, 9), (24, 9)], (230, 60, 40, 255))
    put(img, [(14, 14), (25, 14), (14, 13), (25, 13)], (245, 240, 220, 255))  # 엄니
    rect(img, 11, 1, 28, 4, gold)                 # 왕관
    for x in (11, 16, 20, 24, 28):
        put(img, [(x, 0)], gold)
    put(img, [(15, 2), (20, 2), (24, 2)], (220, 40, 60, 255))
    rect(img, 36, 4, 37, 34, (110, 75, 50, 255))  # 도끼 자루
    ellipse(img, 36.5, 8, 3.5, 6, (190, 195, 210, 255))  # 도끼날
    rect(img, 36, 3, 37, 13, (120, 125, 140, 255))
    return outline(img)


def reaper():
    """죽음의 사신 (36x46): 검은 두건 로브, 해골 얼굴, 빛나는 눈, 머리 위로 ∩ 모양으로 휜 거대한 낫"""
    body = canvas(32, 40)
    robe, robe_d, robe_hi = (62, 56, 84, 255), (34, 30, 48, 255), (104, 94, 136, 255)
    bone, eye = X_PAL["f"], (120, 255, 220, 255)
    for y in range(8, 38):                         # 로브 (아래로 퍼지고 너덜너덜)
        half = 5 + (y - 8) * 0.32
        for x in range(int(14.5 - half), int(14.5 + half) + 1):
            if y > 34 and (x + y) % 3 == 0:
                continue
            body.putpixel((x, y), robe if (x - 14) % 5 else robe_hi)
    ellipse(body, 14.5, 7, 6.5, 6.5, robe_d)      # 두건
    ellipse(body, 14.5, 8, 4, 4, bone)            # 해골
    put(body, [(12, 7), (13, 7), (16, 7), (17, 7)], eye)
    put(body, [(13, 10), (15, 10), (14, 11)], robe_d)
    rect(body, 22, 16, 25, 21, robe)              # 낫을 쥔 소매
    put(body, [(25, 18), (26, 18)], bone)
    img = canvas(36, 46)
    img.alpha_composite(body, (0, 6))
    steel, steel_d = (215, 222, 238, 255), (140, 150, 172, 255)
    rect(img, 27, 4, 28, 44, (110, 90, 70, 255))  # 낫 자루
    for i in range(21):                           # 낫날: 자루 끝에서 왼쪽으로 ∩ 모양으로 휘었다가 끝이 아래로 꺾임
        x = 28 - i
        y = 4 - int(round(4.0 * math.sin(i / 20.0 * math.pi)))
        put(img, [(x, y), (x, y + 1)], steel)
        if 1 < i < 18:
            put(img, [(x, y + 2)], steel_d)
    put(img, [(8, 5), (7, 6), (7, 7), (6, 8)], steel)  # 아래로 꺾인 날 끝
    return outline(img)


def wyvern():
    """와이번 (48x40): 붉은 비룡, 활짝 편 날개, 긴 꼬리"""
    img = canvas(48, 40)
    scale, dark, belly = X_PAL["z"], X_PAL["Z"], (240, 190, 120, 255)
    wing, wing_d = (170, 70, 60, 255), (110, 40, 40, 255)
    for side in (-1, 1):                           # 날개
        for i in range(17):
            x = 24 + side * (5 + i)
            top = 6 + int(abs(i - 7) * 0.5)
            bot = 22 - int(i * 0.45)
            for y in range(top, bot):
                img.putpixel((x, y), wing if (y + i) % 6 else wing_d)
            img.putpixel((x, top), dark)
    ellipse(img, 24, 20, 6, 9, scale)              # 몸
    ellipse(img, 24, 22, 3, 6, belly)
    rect(img, 22, 6, 26, 12, scale)                # 목/머리
    ellipse(img, 24, 5, 4, 3.5, scale)
    put(img, [(22, 4), (26, 4)], (255, 220, 80, 255))
    put(img, [(21, 1), (27, 1), (21, 2), (27, 2)], dark)  # 뿔
    for i in range(10):                            # 꼬리
        put(img, [(24 + int(3 * math.sin(i * 0.6)), 29 + i)], dark)
        put(img, [(25 + int(3 * math.sin(i * 0.6)), 29 + i)], scale)
    put(img, [(19, 28), (20, 29), (28, 28), (27, 29)], dark)  # 발
    return outline(img)


def succubus():
    """상급마족 서큐버스 (28x36): 뿔, 긴 흑발, 박쥐 날개, 꼬리"""
    img = canvas(28, 36)
    skin, wing, wing_d = X_PAL["i"], X_PAL["I"], (70, 15, 45, 255)
    hair, cloth, eye = (40, 20, 40, 255), (140, 20, 70, 255), (255, 60, 160, 255)
    for side in (-1, 1):                            # 날개
        for i in range(9):
            x = 14 + side * (4 + i)
            for y in range(6 + i // 2, 20 - i // 3):
                img.putpixel((x, y), wing if (y + i) % 4 else wing_d)
    ellipse(img, 13.5, 8, 5.5, 6, hair)             # 머리카락
    rect(img, 8, 9, 10, 22, hair)
    rect(img, 17, 9, 19, 22, hair)
    rect(img, 11, 5, 16, 11, skin)                  # 얼굴
    put(img, [(12, 8), (15, 8)], eye)
    put(img, [(13, 10), (14, 10)], (200, 40, 80, 255))
    put(img, [(10, 2), (10, 3), (11, 4), (17, 2), (17, 3), (16, 4)], (60, 30, 40, 255))  # 뿔
    rect(img, 11, 12, 16, 22, skin)                 # 몸
    rect(img, 11, 14, 16, 16, cloth)
    rect(img, 11, 20, 16, 24, cloth)
    rect(img, 11, 25, 12, 33, skin)                 # 다리
    rect(img, 15, 25, 16, 33, skin)
    put(img, [(11, 34), (12, 34), (15, 34), (16, 34)], hair)
    for i in range(8):                              # 꼬리
        put(img, [(18 + i, 26 + int(2 * math.sin(i * 0.8)))], wing_d)
    put(img, [(26, 25), (26, 27), (27, 26)], wing_d)
    return outline(img)


def lost_king():
    """옥좌 잃은 왕 (32x40): 저주로 빛바랜 검보라 망토 + 잿빛 담비털, 창백한 얼굴과 보랏빛 눈, 녹슨 홀 (왕관은 따로)"""
    img = canvas(32, 40)
    robe, robe_d, ermine = (58, 32, 74, 255), (32, 18, 44, 255), (150, 145, 152, 255)
    skin, beard, gold = (186, 186, 172, 255), (170, 170, 176, 255), (150, 120, 60, 255)
    for y in range(12, 39):
        half = 6 + (y - 12) * 0.3
        for x in range(int(15.5 - half), int(15.5 + half) + 1):
            if y > 35 and (x * 7 + y) % 4 == 0:
                continue   # 해진 자락
            img.putpixel((x, y), robe if (x + y) % 7 else robe_d)
    rect(img, 8, 11, 23, 13, ermine)               # 담비털 깃
    put(img, [(10, 12), (14, 12), (18, 12), (22, 12)], (30, 30, 30, 255))
    rect(img, 11, 3, 20, 10, skin)                 # 얼굴
    put(img, [(13, 6), (18, 6)], (200, 90, 255, 255))   # 저주받은 보랏빛 눈
    for y in range(9, 18):                         # 수염
        w = max(1, 5 - (y - 9) // 2)
        rect(img, 15 - w, y, 16 + w, y, beard)
    rect(img, 10, 2, 21, 3, (130, 130, 140, 255))  # 잿빛 머리
    rect(img, 26, 8, 27, 34, gold)                 # 홀
    ellipse(img, 26.5, 7, 2.5, 2.5, (150, 60, 220, 255))  # 저주받은 보석
    return outline(img)


def crown():
    """옥좌 잃은 왕의 왕관 (16x12): 따로 체력이 있는 기믹 대상"""
    img = canvas(16, 12)
    gold, gold_d = X_PAL["Q"], (170, 120, 40, 255)
    rect(img, 1, 6, 14, 10, gold)
    rect(img, 1, 9, 14, 10, gold_d)
    for x in (1, 5, 10, 14):
        rect(img, x, 2, x, 6, gold)
    rect(img, 7, 0, 8, 6, gold)
    put(img, [(4, 8), (11, 8)], (60, 120, 255, 255))
    put(img, [(7, 7), (8, 7), (7, 8), (8, 8)], (230, 40, 70, 255))
    return outline(img)


def heart():
    """매혹의 하트 탄 (9x8)"""
    rows = [
        ".pp...pp.",
        "pWvp.pvvp",
        "pvvvpvvvp",
        "pvvvvvvvp",
        ".pvvvvvp.",
        "..pvvvp..",
        "...pvp...",
        "....p....",
    ]
    pal = {"p": (200, 40, 120, 255), "v": (255, 120, 190, 255), "W": (255, 230, 240, 255)}
    img = canvas(9, 8)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                img.putpixel((x, y), pal[ch])
    return img


def axe():
    """오크킹의 손도끼 (12x12)"""
    img = canvas(12)
    rect(img, 5, 1, 6, 11, (110, 75, 50, 255))
    ellipse(img, 7.5, 3.5, 3.5, 3, (200, 205, 220, 255))
    rect(img, 5, 1, 6, 6, (120, 125, 140, 255))
    return outline(img)


def _floor(seed, base, var, specks):
    rnd = random.Random(seed)
    img = canvas(32)
    for y in range(32):
        for x in range(32):
            v = rnd.randint(-var, var)
            img.putpixel((x, y), (base[0] + v, base[1] + v, base[2] + v, 255))
    for count, col, size in specks:
        for _ in range(count):
            x, y = rnd.randint(0, 31 - size), rnd.randint(0, 31)
            for i in range(size):
                img.putpixel((x + i, y), col)
    return img


def floor_fortress():
    """오크 요새: 다져진 흙 + 나무 판자"""
    img = _floor(31, (110, 82, 56), 6, [(10, (90, 66, 44, 255), 2), (6, (140, 110, 80, 255), 1)])
    for y in (0, 16):
        for x in range(32):
            img.putpixel((x, y), (75, 55, 38, 255))
    return img


def floor_graveyard():
    """망자의 묘지: 잿빛 흙 + 뼛조각"""
    return _floor(41, (46, 50, 52), 4, [(5, (150, 148, 140, 255), 2), (10, (32, 36, 38, 255), 2), (4, (60, 40, 70, 255), 1)])


def floor_crag():
    """비룡의 둥지: 붉은 바위 + 금"""
    img = _floor(51, (112, 86, 72), 7, [(8, (80, 58, 48, 255), 3), (6, (150, 110, 90, 255), 1)])
    return img


def floor_demon():
    """마계: 자줏빛 석판 + 붉은 균열"""
    img = _floor(61, (70, 40, 72), 5, [(5, (200, 40, 80, 255), 3), (8, (50, 25, 55, 255), 2)])
    for i in range(32):
        img.putpixel((i, 0), (40, 20, 45, 255))
        img.putpixel((0, i), (40, 20, 45, 255))
    return img


def floor_royal():
    """버려진 왕궁: 먼지 쌓인 검은 대리석 + 빛바랜 금 줄눈 + 금 간 틈"""
    img = _floor(71, (66, 60, 72), 4, [(6, (84, 78, 92, 255), 3), (4, (40, 36, 46, 255), 4), (3, (70, 50, 80, 255), 1)])
    for i in range(32):
        img.putpixel((i, 15), (110, 92, 58, 255))
        img.putpixel((15, i), (110, 92, 58, 255))
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



# ---------------------------------------------------------------- 신발 (착용 오버레이 = 플레이어 발 위치에 정확히 맞춤)
# 이름: (주색, 밝은 포인트, 어두운 색, 날개 장식 여부)
BOOTS_COLORS = {
    "leather_boots": ((138, 90, 60, 255), (190, 140, 90, 255), (90, 58, 40, 255), False),
    "iron_greaves": ((148, 176, 194, 255), (244, 244, 244, 255), (86, 108, 134, 255), False),
    "shadow_boots": ((70, 50, 100, 255), (170, 120, 230, 255), (40, 28, 60, 255), False),
    "windwalker_boots": ((235, 245, 250, 255), (255, 205, 117, 255), (115, 200, 220, 255), True),
}


def boots_worn(main_col, light, dark, wings):
    img = canvas(16)
    for y in range(13, 16):
        for x, ch in enumerate(PLAYER[y]):
            if ch in "tT":
                put(img, [(x, y)], main_col if y < 15 else dark)
            elif ch == "k" and y == 15:
                put(img, [(x, y)], dark)
    put(img, [(4, 13), (11, 13)], light)
    if wings:
        put(img, [(2, 13), (13, 13)], light)
    return img


def boots_icon(main_col, light, dark, wings):
    img = canvas(16)
    for ox in (1, 8):
        rect(img, ox + 1, 3, ox + 4, 10, main_col)   # 목
        rect(img, ox + 1, 10, ox + 6, 12, main_col)  # 발등
        rect(img, ox + 1, 12, ox + 6, 13, dark)      # 밑창
        rect(img, ox + 1, 3, ox + 4, 4, light)       # 윗단
        if wings:
            put(img, [(ox, 5), (ox - 1 if ox > 1 else ox, 4), (ox, 6)], light)
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


# ---------------------------------------------------------------- 11~15스테이지
def _c(*rgb):
    return tuple(rgb) + (255,)


def failed_experiment():
    """실패한 실험체 (16x16): 꿰맨 자국이 있는 일그러진 살덩이, 짝짝이 팔, 한쪽만 빛나는 눈"""
    img = canvas(16)
    flesh, flesh_d, stitch = _c(196, 130, 150), _c(140, 80, 104), _c(60, 30, 40)
    ellipse(img, 8, 9, 5.5, 4.5, flesh)            # 구부정한 몸통
    ellipse(img, 6.5, 5, 3.5, 3, flesh)            # 한쪽으로 쏠린 머리
    rect(img, 1, 8, 3, 13, flesh_d)                # 굵은 팔
    rect(img, 12, 9, 13, 12, flesh)                # 가는 팔
    rect(img, 5, 13, 6, 15, flesh_d)               # 다리
    rect(img, 10, 13, 11, 15, flesh_d)
    put(img, [(5, 4)], _c(170, 255, 90))           # 빛나는 눈
    put(img, [(8, 4)], stitch)
    for y in range(6, 13):                         # 꿰맨 자국
        put(img, [(8, y)], stitch)
        if y % 2 == 0:
            put(img, [(7, y), (9, y)], stitch)
    put(img, [(4, 7), (11, 8), (6, 11)], _c(120, 200, 80))  # 약물 얼룩
    return outline(img)


def homunculus():
    """호문쿨루스 (14x14): 커다란 머리의 작고 창백한 인조 생명체, 초록 눈"""
    img = canvas(14)
    skin, skin_d = _c(214, 220, 200), _c(150, 160, 140)
    ellipse(img, 7, 5, 4.5, 4, skin)
    rect(img, 5, 8, 8, 11, skin_d)
    rect(img, 3, 9, 4, 10, skin_d)
    rect(img, 9, 9, 10, 10, skin_d)
    rect(img, 5, 12, 5, 13, skin_d)
    rect(img, 8, 12, 8, 13, skin_d)
    put(img, [(5, 5), (9, 5)], _c(90, 255, 120))
    put(img, [(6, 2), (8, 2), (7, 3)], skin_d)     # 머리의 혈관
    return outline(img)


def mad_alchemist():
    """광기의 연금술사 (16x16): 고글을 쓴 연구복, 손에 독 플라스크"""
    img = canvas(16)
    coat, coat_d, skin = _c(200, 205, 196), _c(130, 136, 128), PAL["s"]
    rect(img, 4, 7, 11, 14, coat)
    rect(img, 7, 7, 8, 14, coat_d)
    rect(img, 5, 2, 10, 7, skin)
    rect(img, 4, 1, 11, 2, _c(90, 70, 60))         # 헝클어진 머리
    put(img, [(4, 3), (11, 3), (3, 2), (12, 1)], _c(90, 70, 60))
    rect(img, 5, 4, 10, 4, _c(60, 60, 70))          # 고글
    put(img, [(6, 4), (9, 4)], _c(140, 255, 160))
    rect(img, 12, 8, 13, 11, coat)                  # 팔 + 플라스크
    ellipse(img, 13.5, 6, 1.6, 1.8, _c(110, 230, 90))
    put(img, [(13, 3), (14, 3)], _c(200, 200, 210))
    rect(img, 5, 14, 6, 15, _c(60, 50, 50))
    rect(img, 9, 14, 10, 15, _c(60, 50, 50))
    return outline(img)


def chimera():
    """금단의 실험체 키메라 (48x40): 사자 머리와 갈기, 등에 솟은 염소 머리, 박쥐 날개, 꿰맨 자국 (꼬리는 따로)"""
    img = canvas(48, 40)
    fur, fur_d, mane = _c(196, 150, 86), _c(140, 100, 56), _c(150, 70, 40)
    goat, goat_d, wing, stitch = _c(170, 160, 150), _c(110, 104, 98), _c(90, 50, 70), _c(50, 25, 30)
    for i in range(12):                            # 박쥐 날개
        x = 22 + i
        for y in range(4 + i // 3, 18 - i // 4):
            img.putpixel((x, y), wing if (x + y) % 5 else _c(60, 30, 50))
    ellipse(img, 26, 25, 15, 9, fur)               # 몸통
    ellipse(img, 26, 28, 12, 5, fur_d)
    for x in (14, 20, 31, 37):                     # 다리
        rect(img, x, 30, x + 3, 38, fur_d)
        rect(img, x, 37, x + 4, 38, _c(70, 50, 30))
    ellipse(img, 11, 19, 10, 10, mane)             # 사자 갈기 + 머리
    ellipse(img, 10, 20, 6.5, 6.5, fur)
    put(img, [(7, 18), (12, 18)], _c(255, 230, 60))
    rect(img, 7, 23, 12, 24, _c(110, 30, 30))      # 입
    put(img, [(8, 24), (11, 24), (8, 25), (11, 25)], _c(245, 240, 220))
    ellipse(img, 31, 13, 4, 4, goat)               # 등에 솟은 염소 머리
    put(img, [(29, 12), (33, 12)], _c(230, 60, 60))
    put(img, [(27, 9), (26, 8), (26, 7), (27, 6), (35, 9), (36, 8), (36, 7), (35, 6)], goat_d)  # 뿔
    for x in range(18, 36):                        # 꿰맨 자국
        if x % 3 == 0:
            put(img, [(x, 22), (x, 23)], stitch)
        put(img, [(x, 22 + (x % 2))], stitch)
    return outline(img)


def chimera_tail():
    """키메라의 꼬리 (20x24): 독니를 드러낸 뱀 머리 꼬리 — 본체와 체력이 따로"""
    img = canvas(20, 24)
    scale, scale_d = _c(110, 170, 90), _c(60, 110, 60)
    for i in range(16):                            # 휘어진 꼬리
        x = 10 + int(round(4 * math.sin(i * 0.45)))
        y = 23 - i
        rect(img, x - 1, y, x + 1, y, scale if i % 3 else scale_d)
    ellipse(img, 10, 5, 5, 4, scale)               # 뱀 머리
    ellipse(img, 10, 6, 3.5, 2, scale_d)
    put(img, [(8, 4), (12, 4)], _c(255, 220, 40))
    put(img, [(8, 8), (12, 8)], _c(245, 245, 230))  # 독니
    put(img, [(10, 9), (10, 10), (9, 11), (11, 11)], _c(220, 50, 70))  # 혀
    return outline(img)


def magic_puppet():
    """마도 인형 (16x16): 나무·금속 관절 인형, 가슴에 푸른 마력핵"""
    img = canvas(16)
    wood, wood_d, metal = _c(170, 130, 90), _c(110, 80, 56), _c(140, 150, 170)
    rect(img, 5, 1, 10, 5, wood)
    put(img, [(6, 3), (9, 3)], _c(80, 220, 255))
    rect(img, 4, 6, 11, 11, wood)
    rect(img, 4, 6, 11, 6, metal)
    ellipse(img, 7.5, 8.5, 1.5, 1.5, _c(90, 230, 255))
    rect(img, 2, 6, 3, 11, wood_d)
    rect(img, 12, 6, 13, 11, wood_d)
    put(img, [(2, 9), (13, 9)], metal)
    rect(img, 5, 12, 6, 15, wood_d)
    rect(img, 9, 12, 10, 15, wood_d)
    put(img, [(5, 13), (10, 13)], metal)
    return outline(img)


def magic_drone():
    """마도 드론 (16x14): 둥근 금속 몸체에 날개 판, 아래로 마력 포구"""
    img = canvas(16, 14)
    metal, metal_d, glow = _c(150, 160, 182), _c(90, 96, 116), _c(120, 200, 255)
    ellipse(img, 7.5, 6, 4.5, 4, metal)
    ellipse(img, 7.5, 7, 3, 2, metal_d)
    rect(img, 0, 4, 2, 6, metal_d)
    rect(img, 13, 4, 15, 6, metal_d)
    ellipse(img, 7.5, 5, 1.6, 1.6, glow)
    rect(img, 7, 10, 8, 12, metal_d)
    put(img, [(7, 12), (8, 12)], glow)
    return outline(img)


def magic_sentinel():
    """마도 수호병 (18x18): 두꺼운 강철 갑주, 마력 방패, 빛나는 바이저"""
    img = canvas(18)
    steel, steel_d, glow = _c(120, 128, 150), _c(70, 76, 96), _c(110, 210, 255)
    rect(img, 5, 1, 12, 6, steel)
    rect(img, 6, 3, 11, 3, glow)
    rect(img, 4, 7, 13, 13, steel)
    rect(img, 4, 7, 13, 8, steel_d)
    rect(img, 5, 14, 7, 17, steel_d)
    rect(img, 10, 14, 12, 17, steel_d)
    rect(img, 13, 6, 16, 14, _c(70, 90, 140))       # 마력 방패
    rect(img, 14, 8, 15, 12, glow)
    rect(img, 1, 7, 3, 12, steel_d)
    return outline(img)


def legion():
    """폭주한 마도기신 레기온 (48x48): 거대한 마도 기계 거인, 금 간 장갑, 붉게 폭주하는 눈 (가슴의 마도코어는 따로)"""
    img = canvas(48, 48)
    armor, armor_d, armor_hi = _c(96, 100, 124), _c(56, 58, 76), _c(150, 156, 180)
    rune, red = _c(120, 200, 255), _c(255, 70, 60)
    rect(img, 14, 14, 33, 34, armor)               # 몸통
    rect(img, 14, 14, 33, 16, armor_hi)
    rect(img, 16, 30, 31, 34, armor_d)
    rect(img, 4, 12, 13, 20, armor_d)              # 어깨
    rect(img, 34, 12, 43, 20, armor_d)
    rect(img, 5, 20, 11, 36, armor)                # 팔
    rect(img, 36, 20, 42, 36, armor)
    rect(img, 3, 36, 12, 41, armor_d)              # 주먹
    rect(img, 35, 36, 44, 41, armor_d)
    rect(img, 16, 35, 21, 46, armor_d)             # 다리
    rect(img, 26, 35, 31, 46, armor_d)
    rect(img, 18, 3, 29, 13, armor)                # 머리
    rect(img, 19, 7, 28, 8, _c(30, 30, 40))
    put(img, [(21, 7), (22, 7), (25, 7), (26, 7)], red)
    put(img, [(23, 0), (24, 0), (23, 1), (24, 1), (23, 2), (24, 2)], armor_d)  # 안테나
    for x in range(6, 42, 3):                      # 마력 룬 선
        put(img, [(x, 18)], rune)
    for y in range(20, 34, 3):
        put(img, [(8, y), (39, y)], rune)
    put(img, [(17, 18), (18, 19), (19, 20), (30, 26), (31, 27), (29, 28)], _c(30, 30, 40))  # 금
    put(img, [(18, 20), (31, 28)], red)            # 폭주하는 마력이 새어나옴
    return outline(img)


def magic_core():
    """레기온의 마도코어 (14x14): 가슴에 박힌 빛나는 마력 결정 — 약점"""
    img = canvas(14)
    ellipse(img, 6.5, 6.5, 6, 6, _c(70, 60, 110))
    for y in range(14):
        for x in range(14):
            d = abs(x - 6.5) + abs(y - 6.5) * 0.8
            if d < 5:
                t = d / 5
                img.putpixel((x, y), _c(int(255 - 120 * t), int(230 - 140 * t), 255))
    put(img, [(5, 4), (6, 3)], _c(255, 255, 255))
    return outline(img)


def fishman():
    """어인 전사 (16x16): 푸른 비늘, 지느러미 머리, 삼지창"""
    img = canvas(16)
    scale, scale_d, belly = _c(70, 130, 150), _c(40, 80, 100), _c(170, 200, 190)
    rect(img, 4, 2, 10, 7, scale)
    put(img, [(5, 1), (7, 0), (9, 1), (7, 1), (6, 1), (8, 1)], _c(200, 90, 90))   # 지느러미
    put(img, [(5, 4), (9, 4)], _c(255, 230, 90))
    rect(img, 5, 6, 9, 6, scale_d)
    rect(img, 4, 8, 10, 12, scale)
    rect(img, 6, 9, 8, 12, belly)
    rect(img, 4, 13, 5, 15, scale_d)
    rect(img, 9, 13, 10, 15, scale_d)
    rect(img, 12, 1, 12, 14, _c(150, 120, 80))     # 삼지창
    put(img, [(11, 1), (13, 1), (11, 0), (13, 0), (12, 0)], _c(200, 210, 220))
    rect(img, 11, 9, 11, 10, scale)
    return outline(img)


def jellyfish():
    """심해 해파리 (16x16): 반투명 푸른 갓, 늘어진 촉수, 전기"""
    img = canvas(16)
    bell, bell_d = (130, 180, 255, 220), (80, 120, 220, 230)
    ellipse(img, 7.5, 5, 6, 4.5, bell)
    rect(img, 2, 6, 13, 7, bell_d)
    for x in (3, 5, 7, 9, 11):
        for y in range(8, 15):
            if (y + x) % 3 != 0:
                put(img, [(x + (1 if y % 4 == 0 else 0), y)], (150, 200, 255, 200))
    put(img, [(5, 4), (10, 4), (7, 2)], _c(230, 250, 255))
    return outline(img, (30, 40, 80, 255))


def anglerfish():
    """아귀 (16x16): 커다란 입과 이빨, 머리 위에 빛나는 미끼"""
    img = canvas(16)
    body, body_d = _c(70, 66, 90), _c(44, 40, 60)
    ellipse(img, 8, 10, 7, 5, body)
    rect(img, 2, 11, 13, 12, _c(20, 15, 25))       # 입
    for x in range(2, 14, 2):
        put(img, [(x, 11)], _c(240, 240, 220))
    put(img, [(10, 8)], _c(255, 240, 120))
    put(img, [(8, 5), (8, 4), (7, 3), (6, 2), (5, 2)], body_d)   # 미끼 줄기
    ellipse(img, 4, 2, 1.5, 1.5, _c(180, 255, 230))
    put(img, [(0, 9), (0, 10), (1, 10), (15, 8), (15, 12)], body_d)
    return outline(img)


def kraken():
    """심해의 포식자 크라켄 (52x44): 거대한 문어 머리, 노란 눈, 아래로 뻗은 짧은 촉수 (큰 촉수는 따로)"""
    img = canvas(52, 44)
    skin, skin_d, sucker = _c(150, 60, 80), _c(96, 34, 56), _c(230, 170, 170)
    ellipse(img, 26, 16, 16, 15, skin)             # 머리
    ellipse(img, 26, 10, 10, 7, _c(170, 76, 96))
    for x in range(14, 40, 4):                     # 무늬
        put(img, [(x, 6 + (x % 3)), (x + 1, 7 + (x % 3))], skin_d)
    ellipse(img, 18, 22, 4, 3.5, _c(255, 220, 70))  # 눈
    ellipse(img, 34, 22, 4, 3.5, _c(255, 220, 70))
    rect(img, 17, 20, 19, 24, _c(20, 10, 10))
    rect(img, 33, 20, 35, 24, _c(20, 10, 10))
    for k, base in enumerate((10, 17, 24, 31, 38)):  # 짧은 촉수
        for i in range(14):
            x = base + 2 + int(round(3 * math.sin(i * 0.5 + k)))
            y = 28 + i
            rect(img, x - 2 + i // 7, y, x + 1, y, skin if i % 4 else skin_d)
            if i % 3 == 1:
                put(img, [(x - 1, y)], sucker)
    return outline(img)


def kraken_tentacle():
    """크라켄의 촉수 (16x32): 바닥에서 솟아오른 거대 촉수 — 따로 체력이 있음"""
    img = canvas(16, 32)
    skin, skin_d, sucker = _c(150, 60, 80), _c(96, 34, 56), _c(230, 170, 170)
    for i in range(30):
        y = 31 - i
        w = 4.5 - i * 0.12
        cx = 8 + 2.5 * math.sin(i * 0.22)
        for x in range(16):
            if abs(x - cx) <= w:
                img.putpixel((x, y), skin if x < cx + w - 1 else skin_d)
        if i % 3 == 0 and i < 26:
            put(img, [(int(cx - w + 1), y)], sucker)
    put(img, [(9, 1), (10, 2)], skin_d)
    return outline(img)


def clockwork_soldier():
    """태엽 병정 (16x16): 놋쇠 몸통, 등의 태엽 열쇠, 창"""
    img = canvas(16)
    brass, brass_d, red = _c(210, 170, 80), _c(150, 110, 50), _c(170, 50, 50)
    rect(img, 5, 1, 10, 5, brass)
    rect(img, 5, 1, 10, 1, red)
    put(img, [(6, 3), (9, 3)], _c(40, 30, 20))
    rect(img, 4, 6, 11, 11, red)
    rect(img, 4, 9, 11, 9, brass)
    ellipse(img, 7.5, 7.5, 1, 1, brass_d)
    rect(img, 1, 7, 2, 8, brass_d)                  # 태엽 열쇠
    put(img, [(0, 6), (0, 9), (3, 7)], brass_d)
    rect(img, 5, 12, 6, 15, brass_d)
    rect(img, 9, 12, 10, 15, brass_d)
    rect(img, 13, 0, 13, 13, _c(150, 120, 80))
    put(img, [(12, 1), (14, 1), (13, 0)], _c(220, 225, 235))
    rect(img, 12, 8, 12, 9, red)
    return outline(img)


def sand_scorpion():
    """모래 전갈 (18x16): 황토색 갑각, 집게, 위로 말린 독침 꼬리"""
    img = canvas(18, 16)
    shell, shell_d = _c(200, 160, 90), _c(140, 100, 50)
    ellipse(img, 9, 10, 5, 3.5, shell)
    for x in (4, 6, 11, 13):
        put(img, [(x, 13), (x - 1 if x < 9 else x + 1, 14)], shell_d)
    ellipse(img, 2, 8, 2, 1.6, shell_d)            # 집게
    ellipse(img, 16, 8, 2, 1.6, shell_d)
    put(img, [(3, 9), (15, 9)], shell)
    for i, (x, y) in enumerate(((9, 7), (9, 6), (10, 5), (11, 4), (11, 3), (10, 2), (9, 2))):
        put(img, [(x, y)], shell if i % 2 else shell_d)
    put(img, [(8, 2), (8, 3)], _c(150, 40, 160))   # 독침
    put(img, [(7, 10), (11, 10)], _c(30, 20, 20))
    return outline(img)


def time_wraith():
    """시간의 망령 (16x16): 모래빛 망토 유령, 얼굴 대신 시계판"""
    img = canvas(16)
    cloak, cloak_d = (210, 190, 140, 230), (150, 130, 90, 230)
    for y in range(4, 16):
        half = 3 + (y - 4) * 0.35
        for x in range(16):
            if abs(x - 7.5) <= half and not (y > 13 and (x + y) % 3 == 0):
                img.putpixel((x, y), cloak if (x + y) % 5 else cloak_d)
    ellipse(img, 7.5, 5, 4, 4, cloak_d)
    ellipse(img, 7.5, 5.5, 2.6, 2.6, _c(240, 230, 200))  # 시계판
    put(img, [(7, 4), (7, 5), (8, 5), (9, 5)], _c(40, 30, 20))
    put(img, [(5, 9), (10, 9)], _c(120, 220, 255))
    return outline(img)


def arkeos():
    """모래시계의 파수꾼 아르케오스 (36x46): 모래빛 로브, 등 뒤의 시계 고리, 손에 든 거대한 모래시계"""
    img = canvas(36, 46)
    robe, robe_d, gold = _c(120, 96, 150), _c(76, 58, 104), _c(230, 190, 90)
    sand, glass = _c(240, 205, 120), (200, 230, 255, 200)
    for a in range(0, 360, 6):                     # 등 뒤의 시계 고리
        r = math.radians(a)
        put(img, [(int(round(15 + 13 * math.cos(r))), int(round(14 + 13 * math.sin(r))))], gold)
    for a in range(0, 360, 30):
        r = math.radians(a)
        put(img, [(int(round(15 + 11 * math.cos(r))), int(round(14 + 11 * math.sin(r))))], gold)
    for y in range(14, 45):                        # 로브
        half = 5 + (y - 14) * 0.3
        for x in range(int(15 - half), int(15 + half) + 1):
            img.putpixel((x, y), robe if (x + y) % 6 else robe_d)
    ellipse(img, 15, 10, 5, 5.5, robe_d)           # 두건
    ellipse(img, 15, 11, 3, 3.5, _c(30, 24, 40))
    put(img, [(14, 11), (16, 11)], _c(120, 230, 255))
    rect(img, 9, 20, 21, 21, gold)                 # 허리띠
    rect(img, 27, 18, 33, 18, gold)                # 모래시계
    rect(img, 27, 34, 33, 34, gold)
    rect(img, 27, 18, 27, 34, gold)
    rect(img, 33, 18, 33, 34, gold)
    for y in range(19, 34):
        w = abs(y - 26) * 0.35
        for x in range(28, 33):
            if abs(x - 30) <= w + 0.4:
                img.putpixel((x, y), sand if (y < 24 and y > 20) or y > 30 else glass)
    put(img, [(30, 26), (30, 27), (30, 28)], sand)
    rect(img, 22, 24, 26, 26, robe)                # 팔
    return outline(img)


def mirror_shade():
    """거울 망령 (16x16): 깨진 유리 조각이 박힌 보랏빛 유령"""
    img = canvas(16)
    body, body_d = (170, 140, 230, 210), (110, 80, 170, 220)
    for y in range(3, 16):
        half = 4 + (y - 3) * 0.2 if y < 12 else 6.5 - (y - 12)
        for x in range(16):
            if abs(x - 7.5) <= half and not (y > 12 and x % 2):
                img.putpixel((x, y), body if (x * 3 + y) % 7 else body_d)
    put(img, [(5, 6), (10, 6)], _c(255, 255, 255))
    put(img, [(4, 9), (5, 10), (11, 8), (10, 11)], _c(220, 240, 255))  # 유리 조각
    return outline(img, (40, 25, 70, 255))


def shadow_swordsman():
    """그림자 검사 (16x16): 플레이어를 닮은 검은 그림자, 보랏빛 눈과 검"""
    pal = dict(PAL)
    pal.update({"T": (30, 26, 44, 255), "t": (60, 50, 80, 255), "s": (50, 44, 70, 255),
                "B": (40, 34, 60, 255), "b": (26, 22, 40, 255), "c": (190, 120, 255, 255)})
    img = from_map(PLAYER, pal=pal)
    put(img, [(6, 6), (9, 6)], _c(200, 120, 255))
    rect(img, 13, 3, 13, 10, _c(170, 140, 220))
    rect(img, 12, 10, 14, 10, _c(90, 70, 120))
    return outline(img, (14, 10, 22, 255))


def shard_sprite():
    """파편 정령 (16x16): 공중에 뜬 수정 거울 조각 덩어리"""
    img = canvas(16)
    pts = [(7, 1), (4, 5), (11, 4), (3, 10), (12, 11), (7, 14)]
    for i, (x, y) in enumerate(pts):
        col = _c(200, 220, 255) if i % 2 else _c(150, 170, 230)
        for dy in range(-2, 3):
            for dx in range(-1 + abs(dy) // 2, 2 - abs(dy) // 2):
                put(img, [(x + dx, y + dy)], col)
    ellipse(img, 7.5, 7.5, 2.5, 2.5, _c(220, 160, 255))
    put(img, [(7, 7)], _c(255, 255, 255))
    return outline(img, (40, 30, 80, 255))


def doppelganger():
    """거울에 갇힌 미혹의 도플갱어 (24x32): 플레이어를 닮은 키 큰 그림자, 반쪽 가면, 보랏빛 눈"""
    img = canvas(24, 32)
    body, body_d, hi = _c(46, 36, 70), _c(28, 22, 44), _c(120, 90, 180)
    mask, eye = _c(230, 225, 240), _c(220, 120, 255)
    ellipse(img, 12, 7, 6, 6.5, body_d)            # 머리 (후드)
    ellipse(img, 12, 8, 4.5, 5, body)
    rect(img, 12, 4, 16, 12, mask)                 # 반쪽 가면
    put(img, [(9, 8), (14, 8)], eye)
    put(img, [(13, 11), (14, 11), (15, 10)], _c(150, 140, 170))
    for y in range(13, 31):                        # 몸 (아래로 그림자처럼 흩어짐)
        half = 5 + (y - 13) * 0.2
        for x in range(24):
            if abs(x - 12) <= half and not (y > 27 and (x + y) % 2):
                img.putpixel((x, y), body if (x + y) % 6 else body_d)
    for y in range(14, 30, 3):
        put(img, [(12, y)], hi)
    rect(img, 19, 6, 19, 22, _c(190, 170, 230))     # 거울 검
    rect(img, 17, 21, 21, 21, hi)
    rect(img, 3, 15, 5, 22, body_d)                # 팔
    return outline(img, (12, 8, 20, 255))


def magic_mirror():
    """도플갱어가 갇혀 있던 거울 (30x42): 은빛 장식 테두리, 보랏빛으로 일렁이는 거울면 — 따로 체력이 있음"""
    img = canvas(30, 42)
    frame, frame_d, glass = _c(190, 190, 205), _c(110, 110, 130), _c(70, 50, 110)
    ellipse(img, 14.5, 18, 13.5, 17, frame)
    ellipse(img, 14.5, 18, 11, 14.5, glass)
    for y in range(6, 32):
        for x in range(4, 26):
            if ((x - 14.5) / 11) ** 2 + ((y - 18) / 14.5) ** 2 <= 1.0 and (x - y) % 9 == 0:
                img.putpixel((x, y), _c(140, 110, 200))
    put(img, [(9, 10), (10, 9), (11, 8)], _c(220, 210, 255))  # 반사광
    rect(img, 11, 34, 18, 37, frame_d)             # 받침
    rect(img, 7, 38, 22, 41, frame)
    for x in (2, 27):
        put(img, [(x, 18), (x, 17), (x, 19)], frame_d)
    put(img, [(14, 0), (15, 0), (14, 1), (15, 1)], _c(220, 120, 255))  # 꼭대기 보석
    return outline(img, (30, 26, 44, 255))


def flask():
    """연금술사의 독 플라스크 탄 (8x8)"""
    img = canvas(8)
    ellipse(img, 3.5, 4.5, 3, 2.8, _c(110, 230, 90))
    rect(img, 3, 0, 4, 2, _c(200, 205, 215))
    put(img, [(2, 3)], _c(220, 255, 200))
    return outline(img)


def ink():
    """크라켄의 먹물 탄 (9x9)"""
    img = orb((70, 50, 90), (10, 8, 20), 9)
    put(img, [(3, 2)], _c(140, 120, 170))
    return img


def sand_orb():
    """모래 탄 (8x8)"""
    return orb((255, 240, 190), (220, 170, 80))


def glass_shard():
    """거울 파편 탄 (8x8)"""
    img = canvas(8)
    put(img, [(3, 0), (3, 1), (4, 1), (2, 2), (3, 2), (4, 2), (3, 3), (4, 3), (2, 4), (3, 4), (4, 4), (3, 5), (4, 5), (3, 6), (3, 7)],
        _c(210, 220, 255))
    put(img, [(3, 2), (3, 4)], _c(255, 255, 255))
    return outline(img, (80, 60, 140, 255))


def floor_lab():
    """금단의 연구소: 차가운 회녹색 타일 + 약품 얼룩"""
    img = _floor(81, (70, 82, 78), 4, [(5, (90, 150, 70, 255), 2), (6, (50, 60, 58, 255), 2), (3, (120, 60, 80, 255), 1)])
    for i in range(32):
        img.putpixel((i, 0), (50, 58, 56, 255))
        img.putpixel((0, i), (50, 58, 56, 255))
        img.putpixel((i, 16), (56, 66, 62, 255))
        img.putpixel((16, i), (56, 66, 62, 255))
    return img


def floor_foundry():
    """마도 공장: 강철 판 + 리벳 + 푸른 마력 회로"""
    img = _floor(91, (66, 68, 80), 4, [(6, (50, 52, 62, 255), 3)])
    for i in range(32):
        img.putpixel((i, 0), (40, 42, 52, 255))
        img.putpixel((0, i), (40, 42, 52, 255))
    for x, y in ((3, 3), (28, 3), (3, 28), (28, 28)):
        img.putpixel((x, y), (130, 135, 150, 255))
    for i in range(9, 23):
        img.putpixel((i, 16), (66, 96, 130, 255))
    for i in range(13, 20):
        img.putpixel((16, i), (66, 96, 130, 255))
    return img


def floor_abyss():
    """가라앉은 신전: 짙은 청록 석판 + 해초와 따개비"""
    img = _floor(101, (36, 58, 72), 4, [(6, (40, 90, 70, 255), 3), (6, (70, 96, 110, 255), 1), (5, (24, 40, 52, 255), 2)])
    for i in range(32):
        img.putpixel((i, 0), (24, 40, 52, 255))
        img.putpixel((0, i), (24, 40, 52, 255))
    return img


def floor_hourglass():
    """시간의 회랑: 사암 바닥 + 모래 + 시계 문양"""
    img = _floor(111, (150, 124, 84), 5, [(8, (180, 150, 100, 255), 2), (6, (120, 96, 64, 255), 2)])
    for a in range(0, 360, 12):
        r = math.radians(a)
        img.putpixel((int(16 + 11 * math.cos(r)) % 32, int(16 + 11 * math.sin(r)) % 32), (110, 88, 58, 255))
    for i in range(6):
        img.putpixel((16, 16 - i), (110, 88, 58, 255))
        img.putpixel((16 + i, 16), (110, 88, 58, 255))
    return img


def floor_mirror():
    """거울의 미궁: 보랏빛 유리 타일 + 반사광"""
    img = _floor(121, (54, 46, 80), 4, [(4, (100, 90, 150, 255), 3), (5, (36, 30, 56, 255), 2)])
    for i in range(32):
        img.putpixel((i, 0), (90, 80, 130, 255))
        img.putpixel((0, i), (90, 80, 130, 255))
        if i < 10:
            img.putpixel((4 + i, 14 - i), (120, 110, 170, 255))
    return img


def save_late_sprites():
    for name, painter in (("failed_experiment", failed_experiment), ("homunculus", homunculus), ("mad_alchemist", mad_alchemist),
                          ("chimera", chimera), ("chimera_tail", chimera_tail),
                          ("magic_puppet", magic_puppet), ("magic_drone", magic_drone), ("magic_sentinel", magic_sentinel),
                          ("legion", legion), ("magic_core", magic_core),
                          ("fishman", fishman), ("jellyfish", jellyfish), ("anglerfish", anglerfish),
                          ("kraken", kraken), ("kraken_tentacle", kraken_tentacle),
                          ("clockwork_soldier", clockwork_soldier), ("sand_scorpion", sand_scorpion), ("time_wraith", time_wraith),
                          ("arkeos", arkeos),
                          ("mirror_shade", mirror_shade), ("shadow_swordsman", shadow_swordsman), ("shard_sprite", shard_sprite),
                          ("doppelganger", doppelganger), ("magic_mirror", magic_mirror)):
        save(painter(), "characters", f"{name}.png")
    save(flask(), "projectiles", "flask.png")
    save(ink(), "projectiles", "ink.png")
    save(sand_orb(), "projectiles", "sand_orb.png")
    save(glass_shard(), "projectiles", "glass_shard.png")
    save(orb((220, 255, 180), (90, 200, 60)), "projectiles", "acid.png")
    save(orb((230, 250, 255), (80, 170, 255)), "projectiles", "mana_bolt.png")
    for name, painter in (("floor_lab", floor_lab), ("floor_foundry", floor_foundry), ("floor_abyss", floor_abyss),
                          ("floor_hourglass", floor_hourglass), ("floor_mirror", floor_mirror)):
        save(painter(), "tiles", f"{name}.png")


# ---------------------------------------------------------------- 16~17스테이지
def harpy():
    """하피 (16x16): 새 날개 팔, 깃털 머리, 발톱"""
    img = canvas(16)
    wing, wing_d, skin = _c(150, 110, 80), _c(100, 70, 50), _c(230, 190, 160)
    for i in range(6):
        rect(img, 0 + i // 2, 4 + i, 4, 4 + i, wing if i % 2 else wing_d)
        rect(img, 11, 4 + i, 15 - i // 2, 4 + i, wing if i % 2 else wing_d)
    rect(img, 5, 1, 10, 5, skin)
    rect(img, 4, 0, 11, 1, _c(120, 60, 40))
    put(img, [(4, 2), (11, 2), (4, 3), (11, 3)], _c(120, 60, 40))
    put(img, [(6, 3), (9, 3)], _c(220, 40, 40))
    rect(img, 5, 6, 10, 10, wing_d)
    rect(img, 6, 7, 9, 9, skin)
    put(img, [(5, 11), (6, 12), (10, 11), (9, 12), (5, 13), (6, 13), (9, 13), (10, 13)], _c(230, 200, 90))
    return outline(img)


def wind_spirit():
    """바람 정령 (16x16): 소용돌이치는 연두빛 바람 덩어리"""
    img = canvas(16)
    for a in range(0, 720, 12):
        r = math.radians(a)
        d = 1.0 + a / 720.0 * 5.5
        x, y = 7.5 + math.cos(r) * d, 7 + math.sin(r) * d * 0.8
        put(img, [(int(round(x)), int(round(y)))], (190, 255, 220, 230) if a % 48 else (120, 220, 180, 230))
    put(img, [(6, 6), (9, 6)], _c(40, 90, 80))
    rect(img, 6, 13, 9, 14, (150, 230, 200, 160))
    return outline(img, (40, 90, 80, 255))


def giant_eagle():
    """거대 독수리 (18x16): 펼친 갈색 날개, 흰 머리, 노란 부리"""
    img = canvas(18, 16)
    wing, wing_d = _c(120, 84, 56), _c(80, 54, 36)
    for i in range(8):
        rect(img, i, 5 + i // 2, i, 9 - i // 4, wing if i % 2 else wing_d)
        rect(img, 17 - i, 5 + i // 2, 17 - i, 9 - i // 4, wing if i % 2 else wing_d)
    ellipse(img, 8.5, 9, 4, 4, wing)
    ellipse(img, 8.5, 4, 3, 3, _c(240, 238, 230))
    put(img, [(7, 3), (10, 3)], _c(30, 20, 10))
    put(img, [(8, 6), (9, 6), (9, 7)], _c(250, 200, 60))
    put(img, [(7, 13), (10, 13), (6, 14), (11, 14)], _c(250, 200, 60))
    return outline(img)


def griffin():
    """그리핀 (48x40, 날개 제외): 흰 독수리 머리와 노란 부리, 앞발은 독수리 발톱, 뒷몸은 사자 (날개는 따로)"""
    img = canvas(48, 40)
    fur, fur_d, feather, feather_d = _c(200, 160, 96), _c(150, 112, 62), _c(240, 236, 226), _c(190, 182, 170)
    beak, talon = _c(250, 196, 60), _c(70, 60, 50)
    ellipse(img, 27, 25, 14, 8, fur)                 # 사자 몸통
    ellipse(img, 29, 28, 11, 4, fur_d)
    for x in (30, 36):                               # 뒷다리
        rect(img, x, 30, x + 3, 38, fur_d)
    rect(img, 30, 37, 34, 38, _c(90, 66, 40))
    rect(img, 36, 37, 40, 38, _c(90, 66, 40))
    for i in range(8):                               # 꼬리 (끝에 술)
        put(img, [(41 + i // 2, 22 - i), (42 + i // 2, 22 - i)], fur_d)
    ellipse(img, 46, 13, 2, 2.5, _c(110, 80, 50))
    ellipse(img, 15, 20, 9, 9, feather)              # 깃털 가슴
    ellipse(img, 15, 23, 7, 5, feather_d)
    for x in (11, 18):                               # 앞발 (독수리 발톱)
        rect(img, x, 28, x + 3, 36, _c(240, 200, 70))
        put(img, [(x - 1, 37), (x + 1, 38), (x + 3, 38), (x + 4, 37)], talon)
    ellipse(img, 11, 10, 7, 7, feather)              # 독수리 머리
    put(img, [(9, 8), (8, 8)], _c(20, 20, 20))
    put(img, [(9, 7)], _c(250, 220, 80))
    rect(img, 2, 10, 5, 12, beak)                    # 부리
    put(img, [(1, 11), (2, 13), (3, 13)], _c(200, 140, 30))
    put(img, [(14, 3), (15, 2), (16, 2), (17, 3)], feather_d)  # 깃털 볏
    return outline(img)


def griffin_wing():
    """그리핀의 날개 (오른쪽, 26x30) — 몸통과 체력이 따로. 왼쪽 날개는 좌우 반전"""
    img = canvas(26, 30)
    feather, feather_d, tip = _c(236, 230, 214), _c(184, 172, 154), _c(130, 100, 70)
    for x in range(0, 25):                           # 날개 윗변 (어깨 → 바깥 끝으로 치켜 올라감)
        top = 9 - int(x * 0.32)
        rect(img, x, top, x, top + 4, feather)
        put(img, [(x, top)], feather_d)
    for k in range(7):                               # 아래로 늘어진 칼깃 (바깥쪽일수록 길게)
        x0 = 3 + k * 3
        top = 12 - int(x0 * 0.32)
        length = 11 + k * 2
        for t in range(length):
            y = top + t
            x = x0 + t // 4
            if y < 30 and x < 26:
                put(img, [(x, y), (x + 1, y)], feather if t < length - 3 else tip)
                put(img, [(x + 2, y)], feather_d)
    return outline(img)


def feather_bolt():
    """그리핀 깃털 탄 (8x8)"""
    img = canvas(8)
    put(img, [(1, 6), (2, 5), (3, 4), (4, 3), (5, 2), (6, 1)], _c(240, 236, 226))
    put(img, [(2, 6), (3, 5), (4, 4), (5, 3), (6, 2), (3, 6), (5, 4)], _c(190, 182, 170))
    return outline(img, (80, 70, 60, 255))


def hill_giant():
    """언덕 거인 (24x24): 털옷을 걸친 덩치 큰 거인, 통나무 곤봉"""
    img = canvas(24)
    skin, skin_d, fur = _c(210, 160, 120), _c(160, 116, 84), _c(120, 90, 60)
    rect(img, 7, 2, 15, 9, skin)
    put(img, [(9, 5), (13, 5)], _c(40, 30, 20))
    rect(img, 9, 7, 13, 7, skin_d)
    rect(img, 5, 10, 17, 18, fur)
    rect(img, 7, 11, 15, 13, skin)
    rect(img, 2, 10, 4, 17, skin)
    rect(img, 18, 10, 20, 15, skin)
    rect(img, 7, 19, 9, 23, skin_d)
    rect(img, 13, 19, 15, 23, skin_d)
    rect(img, 20, 3, 22, 16, _c(110, 80, 50))       # 통나무 곤봉
    rect(img, 19, 2, 23, 6, _c(130, 96, 60))
    return outline(img)


def cyclops():
    """외눈 거인 (24x24): 이마의 커다란 외눈, 뿔, 바위를 든 손"""
    img = canvas(24)
    skin, skin_d = _c(150, 170, 130), _c(100, 120, 90)
    rect(img, 7, 3, 16, 10, skin)
    ellipse(img, 11.5, 6, 2.5, 2, _c(245, 245, 235))
    put(img, [(11, 6), (12, 6)], _c(180, 30, 30))
    put(img, [(11, 1), (11, 2), (12, 2)], _c(220, 210, 190))
    rect(img, 9, 9, 14, 9, skin_d)
    rect(img, 6, 11, 17, 18, _c(110, 80, 60))
    rect(img, 8, 11, 15, 13, skin)
    rect(img, 3, 11, 5, 16, skin)
    rect(img, 18, 10, 20, 14, skin)
    ellipse(img, 20, 7, 3, 3, _c(130, 124, 116))     # 들고 있는 바위
    rect(img, 7, 19, 9, 23, skin_d)
    rect(img, 14, 19, 16, 23, skin_d)
    return outline(img)


def chained_giant():
    """사슬 묶인 거인 (24x24): 목과 손목에 쇠고랑, 큰 쇠문짝 방패"""
    img = canvas(24)
    skin, skin_d, iron = _c(170, 150, 140), _c(120, 104, 96), _c(90, 94, 104)
    rect(img, 8, 2, 15, 9, skin)
    put(img, [(10, 5), (13, 5)], _c(230, 200, 80))
    rect(img, 7, 9, 16, 10, iron)                    # 목 쇠고랑
    rect(img, 6, 11, 17, 18, skin_d)
    rect(img, 6, 15, 17, 15, iron)
    rect(img, 3, 11, 5, 17, skin)
    rect(img, 3, 16, 5, 17, iron)
    rect(img, 7, 19, 9, 23, skin_d)
    rect(img, 14, 19, 16, 23, skin_d)
    rect(img, 17, 6, 22, 20, _c(110, 114, 124))      # 쇠문짝 방패
    rect(img, 18, 8, 21, 8, iron)
    rect(img, 18, 13, 21, 13, iron)
    rect(img, 18, 18, 21, 18, iron)
    return outline(img)


def titan():
    """티탄 (56x60): 잿빛 거인, 양 손목의 쇠고랑에서 늘어진 쇠사슬 끝에 구멍 없이 꽉 찬 커다란 원형 쇠 구속구"""
    img = canvas(56, 60)
    skin, skin_d, skin_hi = _c(140, 146, 160), _c(96, 100, 116), _c(180, 186, 200)
    iron, iron_d, cloth = _c(84, 86, 96), _c(50, 52, 60), _c(110, 80, 60)
    rect(img, 20, 4, 35, 17, skin)                   # 머리
    rect(img, 20, 4, 35, 6, skin_d)
    put(img, [(24, 10), (25, 10), (30, 10), (31, 10)], _c(255, 140, 60))
    rect(img, 24, 14, 31, 14, skin_d)
    rect(img, 16, 18, 39, 36, skin)                  # 몸통
    rect(img, 18, 20, 37, 22, skin_hi)
    rect(img, 27, 22, 28, 34, skin_d)
    rect(img, 18, 33, 37, 40, cloth)                 # 허리천
    rect(img, 9, 18, 15, 34, skin)                   # 팔
    rect(img, 40, 18, 46, 34, skin)
    rect(img, 8, 32, 16, 35, iron)                   # 손목 쇠고랑
    rect(img, 39, 32, 47, 35, iron)
    rect(img, 19, 41, 25, 58, skin_d)                # 다리
    rect(img, 30, 41, 36, 58, skin_d)
    rect(img, 18, 54, 26, 56, iron)                  # 발목 쇠고랑
    rect(img, 29, 54, 37, 56, iron)
    for side, cx in ((-1, 7), (1, 48)):              # 쇠사슬 + 끝의 원형 구속구
        for i in range(12):
            x = cx + side * (i // 6)
            y = 36 + i
            put(img, [(x, y)], iron if i % 2 else iron_d)
            if i % 2 == 0:
                put(img, [(x - 1, y), (x + 1, y)], iron_d)
        rx, ry = cx - side, 52
        for y in range(60):                            # 구멍 없이 꽉 찬 원형 쇠 구속구
            for x in range(56):
                d = math.hypot(x - rx, y - ry)
                if d <= 7.2:
                    img.putpixel((x, y), iron_d if d > 6.0 or (x - rx) + (y - ry) > 4.0 else iron)
        put(img, [(rx - 3, ry - 4), (rx - 4, ry - 3), (rx - 2, ry - 4), (rx - 4, ry - 2)], _c(150, 154, 168))  # 반사광
        put(img, [(rx - 1, ry), (rx, ry), (rx + 1, ry), (rx, ry - 1), (rx, ry + 1)], iron_d)  # 리벳
    return outline(img)


def cover_rock():
    """티탄이 내려찍어 튀어나와 땅에 박힌 바위 (24x20) — 엄폐물"""
    img = canvas(24, 20)
    rock, rock_d, rock_hi = _c(128, 120, 112), _c(84, 78, 72), _c(170, 162, 150)
    ellipse(img, 11.5, 11, 10.5, 8, rock)
    ellipse(img, 13, 14, 8, 4.5, rock_d)
    ellipse(img, 8, 7, 4, 2.5, rock_hi)
    put(img, [(14, 6), (15, 7), (16, 8), (16, 9)], rock_d)
    rect(img, 2, 18, 21, 19, _c(70, 60, 50))          # 박힌 흙
    return outline(img)


def boulder():
    """티탄이 던지는 바위 (16x16)"""
    img = canvas(16)
    ellipse(img, 7.5, 7.5, 7, 6.5, _c(120, 112, 104))
    ellipse(img, 9, 9.5, 5, 3.5, _c(84, 78, 72))
    ellipse(img, 5, 5, 2.5, 2, _c(168, 160, 150))
    return outline(img)


def floor_peak():
    """바람의 봉우리: 바람에 깎인 회백색 바위 + 마른 풀"""
    img = _floor(131, (122, 128, 120), 5, [(6, (150, 156, 146, 255), 3), (6, (96, 102, 94, 255), 2), (5, (130, 150, 90, 255), 1)])
    for i in range(0, 32, 2):
        img.putpixel((i, (i * 3) % 32), (104, 110, 102, 255))
    return img


def floor_titan():
    """티탄의 감옥: 거친 암반 + 깊은 균열 + 쇠사슬 자국"""
    img = _floor(141, (84, 80, 78), 5, [(6, (60, 56, 54, 255), 3), (5, (110, 104, 98, 255), 2)])
    for i in range(14):
        img.putpixel((4 + i, 10 + int(3 * math.sin(i * 0.7))), (44, 40, 38, 255))
    for x in range(20, 30, 2):
        img.putpixel((x, 25), (70, 72, 82, 255))
        img.putpixel((x + 1, 26), (70, 72, 82, 255))
    return img


def save_late2_sprites():
    for name, painter in (("harpy", harpy), ("wind_spirit", wind_spirit), ("giant_eagle", giant_eagle),
                          ("griffin", griffin), ("griffin_wing", griffin_wing),
                          ("hill_giant", hill_giant), ("cyclops", cyclops), ("chained_giant", chained_giant),
                          ("titan", titan), ("cover_rock", cover_rock)):
        save(painter(), "characters", f"{name}.png")
    save(feather_bolt(), "projectiles", "feather.png")
    save(boulder(), "projectiles", "boulder.png")
    save(orb((235, 255, 245), (120, 220, 180)), "projectiles", "wind_orb.png")
    save(floor_peak(), "tiles", "floor_peak.png")
    save(floor_titan(), "tiles", "floor_titan.png")


# ---------------------------------------------------------------- 18~20스테이지
def puppet_soldier():
    """인형 병사 (16x16): 관절이 보이는 나무 병정 인형, 머리 위로 실"""
    img = canvas(16)
    wood, wood_d, red = _c(200, 160, 110), _c(140, 104, 66), _c(170, 40, 50)
    rect(img, 5, 2, 10, 6, wood)
    put(img, [(6, 4), (9, 4)], _c(30, 20, 20))
    put(img, [(6, 5), (9, 5)], _c(230, 120, 120))
    rect(img, 4, 7, 11, 11, red)
    rect(img, 4, 9, 11, 9, _c(230, 200, 90))
    put(img, [(3, 7), (2, 8), (2, 9), (12, 7), (13, 8), (13, 9)], wood_d)
    rect(img, 5, 12, 6, 15, wood_d)
    rect(img, 9, 12, 10, 15, wood_d)
    put(img, [(5, 13), (10, 13)], wood)
    put(img, [(3, 0), (3, 1), (3, 2), (3, 3), (3, 4), (3, 5), (12, 0), (12, 1), (12, 2), (12, 3), (12, 4), (12, 5)], (220, 220, 230, 150))
    return outline(img)


def jester_doll():
    """광대 인형 (16x16): 두 갈래 모자, 하얀 얼굴, 마름모 무늬 옷"""
    img = canvas(16)
    purple, yellow, face = _c(130, 60, 160), _c(240, 200, 60), _c(240, 236, 230)
    put(img, [(3, 1), (4, 2), (5, 3), (12, 1), (11, 2), (10, 3)], purple)
    put(img, [(2, 0), (13, 0)], yellow)
    rect(img, 5, 3, 10, 7, face)
    put(img, [(6, 5), (9, 5)], _c(40, 20, 50))
    put(img, [(7, 7), (8, 7)], _c(200, 40, 60))
    for y in range(8, 13):
        for x in range(4, 12):
            img.putpixel((x, y), purple if (x + y) % 2 else yellow)
    rect(img, 5, 13, 6, 15, purple)
    rect(img, 9, 13, 10, 15, yellow)
    put(img, [(2, 8), (13, 8)], _c(250, 120, 60))
    return outline(img)


def thread_spider():
    """실 거미 (16x14): 은빛 실을 뿜는 커다란 거미, 붉은 눈"""
    img = canvas(16, 14)
    body, body_d = _c(70, 60, 80), _c(40, 34, 48)
    ellipse(img, 8, 8, 4, 3.5, body)
    ellipse(img, 8, 4, 2.5, 2, body_d)
    put(img, [(7, 4), (9, 4)], _c(255, 60, 60))
    for side in (-1, 1):
        for k in range(4):
            x0 = 8 + side * 3
            put(img, [(x0 + side * 2, 6 + k), (x0 + side * 4, 5 + k * 2), (x0 + side * 5, 7 + k * 2)], body_d)
    put(img, [(8, 12), (8, 13)], (230, 230, 240, 200))
    return outline(img)


def marionette():
    """꼭두각시 마리오네트 (32x48): 금이 간 도자기 얼굴의 큰 인형, 손발 관절, 머리 위 십자 조종대에서 내려온 실"""
    img = canvas(32, 48)
    face, cheek, dress, dress_d = _c(236, 230, 226), _c(230, 140, 150), _c(120, 30, 60), _c(80, 20, 44)
    joint, wood = _c(180, 150, 120), _c(150, 116, 84)
    rect(img, 6, 1, 25, 2, wood)                     # 십자 조종대
    rect(img, 15, 0, 16, 5, wood)
    for x in (7, 15, 24):                            # 조종대에서 내려오는 실
        for y in range(3, 16 if x == 15 else 24):
            put(img, [(x, y)], (230, 230, 240, 200))
    ellipse(img, 15.5, 13, 6, 6, face)               # 머리
    rect(img, 9, 7, 22, 9, _c(60, 30, 40))           # 머리카락
    put(img, [(9, 10), (9, 11), (22, 10), (22, 11)], _c(60, 30, 40))
    put(img, [(13, 12), (18, 12)], _c(30, 20, 40))
    put(img, [(13, 13), (18, 13)], _c(120, 200, 255))
    put(img, [(12, 15), (19, 15)], cheek)
    put(img, [(15, 16), (16, 16)], _c(150, 30, 50))
    put(img, [(19, 9), (20, 10), (19, 11), (20, 12)], _c(120, 110, 110))  # 얼굴의 금
    for y in range(20, 40):                          # 드레스
        half = 4 + (y - 20) * 0.4
        for x in range(int(15.5 - half), int(15.5 + half) + 1):
            img.putpixel((x, y), dress if (x + y) % 5 else dress_d)
    rect(img, 13, 20, 18, 22, _c(240, 220, 230))     # 레이스 깃
    for side in (-1, 1):                             # 관절 팔
        x0 = 15 + side * 6
        put(img, [(x0, 21), (x0 + side, 22), (x0 + side * 2, 23)], joint)
        ellipse(img, x0 + side * 3, 24, 1.2, 1.2, wood)
        put(img, [(x0 + side * 3, 25), (x0 + side * 3, 26), (x0 + side * 4, 27)], joint)
    for x in (12, 19):                               # 관절 다리
        rect(img, x, 40, x + 1, 46, joint)
        put(img, [(x, 43), (x + 1, 43)], wood)
    return outline(img)


def switch_plate(on):
    """마리오네트 실 끊기 스위치 (16x12): 바닥 발판"""
    img = canvas(16, 12)
    base = _c(110, 100, 90)
    ellipse(img, 7.5, 7, 7.5, 4.5, base)
    ellipse(img, 7.5, 6 if not on else 7, 5, 3, _c(255, 210, 80) if not on else _c(110, 200, 120))
    put(img, [(6, 5), (7, 5)], _c(255, 245, 200) if not on else _c(200, 255, 210))
    return outline(img)


def sea_serpent():
    """바다뱀 (18x14): 청록 비늘, 지느러미"""
    img = canvas(18, 14)
    sc, sc_d = _c(60, 150, 160), _c(30, 96, 110)
    for i in range(14):
        x = 2 + i
        y = 8 + int(round(2 * math.sin(i * 0.7)))
        rect(img, x, y - 1, x, y + 1, sc if i % 3 else sc_d)
    ellipse(img, 15, 6, 2.5, 2, sc)
    put(img, [(16, 5)], _c(255, 230, 80))
    put(img, [(5, 6), (8, 5), (11, 6)], _c(220, 120, 120))
    return outline(img)


def storm_spirit():
    """폭풍 정령 (16x16): 번개가 치는 먹구름 덩어리"""
    img = canvas(16)
    ellipse(img, 7.5, 6, 6, 4, _c(90, 96, 120))
    ellipse(img, 5, 5, 3, 2.5, _c(120, 126, 150))
    ellipse(img, 10, 4.5, 3, 2.5, _c(110, 116, 140))
    put(img, [(5, 6), (9, 6)], _c(255, 255, 160))
    put(img, [(7, 10), (6, 11), (7, 12), (6, 13), (7, 14)], _c(255, 240, 120))
    put(img, [(10, 10), (11, 11), (10, 12)], _c(255, 240, 120))
    return outline(img)


def frost_spirit():
    """서리 정령 (16x16): 얼음 결정 몸, 하늘빛 눈"""
    img = canvas(16)
    ice, ice_d = _c(200, 236, 255), _c(130, 190, 230)
    for i in range(6):
        a = math.radians(i * 60)
        for r in range(7):
            put(img, [(int(round(7.5 + math.cos(a) * r)), int(round(7.5 + math.sin(a) * r)))], ice if r % 2 else ice_d)
    ellipse(img, 7.5, 7.5, 2.5, 2.5, ice)
    put(img, [(6, 7), (9, 7)], _c(40, 90, 160))
    return outline(img, (40, 70, 120, 255))


def leviathan():
    """폭풍의 지배자 레비아탄 (64x48): 짙은 청색 바다룡, 뿔 달린 머리, 몸을 감은 똬리, 등지느러미"""
    img = canvas(64, 48)
    sc, sc_d, belly = _c(40, 80, 130), _c(24, 50, 90), _c(150, 200, 210)
    fin = _c(80, 170, 190)
    for k in range(3):                               # 똬리 (아래쪽 몸)
        cx, cy, rx, ry = 34 + k * 6, 34 + k * 2, 18 - k * 3, 7 - k
        for a in range(0, 360, 3):
            r = math.radians(a)
            for t in range(4):
                put(img, [(int(cx + math.cos(r) * (rx - t)), int(cy + math.sin(r) * (ry - t * 0.6)))], sc if (a // 15 + t) % 3 else sc_d)
    for i in range(26):                              # 솟아오른 목
        x = 16 + int(i * 0.35)
        y = 36 - i
        rect(img, x - 3, y, x + 3, y, sc)
        put(img, [(x - 3, y)], belly)
        if i % 3 == 0:
            put(img, [(x + 4, y), (x + 5, y - 1)], fin)  # 등지느러미
    ellipse(img, 22, 8, 9, 6, sc)                    # 머리
    rect(img, 9, 9, 16, 12, sc)                      # 주둥이
    put(img, [(9, 12), (10, 12), (12, 12), (14, 12)], _c(240, 240, 230))  # 이빨
    ellipse(img, 20, 6, 1.5, 1.2, _c(255, 230, 80))
    put(img, [(25, 1), (26, 0), (27, 0), (29, 2), (30, 1), (31, 1)], _c(200, 210, 220))  # 뿔
    for x in (24, 28, 32):
        put(img, [(x, 3), (x + 1, 2)], fin)
    return outline(img)


def icicle():
    """고드름 (8x14)"""
    img = canvas(8, 14)
    for y in range(13):
        w = max(0, 3 - y // 4)
        rect(img, 4 - w, y, 3 + w, y, _c(220, 245, 255) if y < 9 else _c(170, 220, 250))
    return outline(img, (60, 110, 160, 255))


def apprentice_mage():
    """견습 마법사 (16x16): 파란 고깔모자와 로브, 작은 지팡이"""
    img = canvas(16)
    robe, robe_d = _c(60, 90, 180), _c(40, 60, 130)
    put(img, [(7, 0), (7, 1), (8, 1), (6, 2), (7, 2), (8, 2), (9, 2)], robe_d)
    rect(img, 4, 3, 11, 3, robe_d)
    rect(img, 5, 4, 10, 7, PAL["s"])
    put(img, [(6, 5), (9, 5)], _c(30, 30, 50))
    for y in range(8, 16):
        half = 3 + (y - 8) * 0.35
        for x in range(int(7.5 - half), int(7.5 + half) + 1):
            img.putpixel((x, y), robe if (x + y) % 4 else robe_d)
    rect(img, 13, 4, 13, 14, _c(140, 100, 60))
    put(img, [(13, 3), (12, 3), (14, 3), (13, 2)], _c(150, 220, 255))
    return outline(img)


def magic_armor():
    """마력 갑옷 (18x18): 속이 빈 채 푸른 마력으로 움직이는 갑옷, 큰 방패"""
    img = canvas(18)
    steel, steel_d, glow = _c(160, 168, 186), _c(100, 108, 128), _c(120, 180, 255)
    rect(img, 5, 1, 12, 6, steel)
    rect(img, 6, 3, 11, 3, _c(20, 20, 30))
    put(img, [(7, 3), (10, 3)], glow)
    rect(img, 4, 7, 13, 13, steel)
    rect(img, 4, 7, 13, 8, steel_d)
    put(img, [(8, 10), (9, 10), (8, 11), (9, 11)], glow)
    rect(img, 5, 14, 7, 17, steel_d)
    rect(img, 10, 14, 12, 17, steel_d)
    rect(img, 13, 6, 17, 15, _c(90, 70, 140))
    rect(img, 15, 8, 15, 13, glow)
    rect(img, 1, 7, 3, 12, steel_d)
    return outline(img)


def grimoire():
    """날아다니는 마도서 (16x14): 펼쳐진 책, 빛나는 룬"""
    img = canvas(16, 14)
    cover, page = _c(110, 40, 60), _c(240, 230, 200)
    rect(img, 1, 3, 7, 11, cover)
    rect(img, 8, 3, 14, 11, cover)
    rect(img, 2, 4, 7, 10, page)
    rect(img, 8, 4, 13, 10, page)
    for y in (5, 7, 9):
        put(img, [(3, y), (4, y), (5, y), (10, y), (11, y), (12, y)], _c(150, 90, 220))
    put(img, [(7, 2), (8, 2), (7, 12), (8, 12)], _c(230, 200, 80))
    return outline(img)


def archmage():
    """대마법사 (32x46): 별무늬 남보라 로브, 긴 흰 수염, 끝에 마력 구슬이 달린 거대한 지팡이"""
    img = canvas(32, 46)
    robe, robe_d, star = _c(56, 46, 120), _c(34, 28, 80), _c(255, 220, 110)
    beard, skin = _c(236, 236, 240), _c(230, 196, 160)
    put(img, [(13, 0), (13, 1), (14, 1), (12, 2), (13, 2), (14, 2)], robe_d)  # 고깔모자
    for y in range(3, 10):
        half = 1 + (y - 3) * 0.9
        rect(img, int(13.5 - half), y, int(13.5 + half), y, robe if y < 9 else robe_d)
    rect(img, 9, 10, 18, 14, skin)
    put(img, [(11, 12), (16, 12)], _c(80, 160, 255))
    for y in range(14, 46):                          # 로브
        half = 6 + (y - 14) * 0.22
        for x in range(int(13.5 - half), int(13.5 + half) + 1):
            img.putpixel((x, y), robe if (x * 3 + y) % 7 else robe_d)
    for y in range(14, 30):                          # 긴 수염
        w = max(1, 5 - (y - 14) // 3)
        rect(img, 13 - w, y, 14 + w, y, beard)
    for x, y in ((8, 34), (18, 38), (10, 42), (17, 28), (7, 25)):  # 별무늬
        put(img, [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], star)
    rect(img, 26, 6, 27, 45, _c(120, 84, 50))        # 지팡이
    put(img, [(25, 6), (28, 6), (24, 4), (29, 4)], _c(200, 170, 90))
    ellipse(img, 26.5, 3, 3, 3, _c(140, 220, 255))   # 마력 구슬
    put(img, [(25, 2)], _c(255, 255, 255))
    rect(img, 20, 22, 25, 24, robe)                  # 지팡이를 쥔 팔
    rect(img, 24, 22, 26, 25, skin)
    return outline(img)


def floor_theater():
    """인형 극장: 낡은 무대 마루 + 붉은 카펫 자국"""
    img = _floor(151, (120, 84, 60), 5, [(6, (96, 66, 46, 255), 3), (4, (150, 60, 60, 255), 2)])
    for y in (0, 8, 16, 24):
        for x in range(32):
            img.putpixel((x, y), (80, 54, 38, 255))
    for y in range(32):
        img.putpixel(((y // 8) * 11 % 32, y), (86, 58, 40, 255))
    return img


def floor_storm():
    """폭풍의 바다: 젖은 검푸른 바위 + 물웅덩이"""
    img = _floor(161, (52, 62, 78), 5, [(6, (70, 90, 110, 255), 3), (6, (36, 44, 56, 255), 2), (3, (120, 150, 180, 255), 1)])
    return img


def floor_arcane():
    """대마법사의 탑: 짙은 남색 석판 + 금빛 룬"""
    img = _floor(171, (46, 44, 76), 4, [(5, (60, 56, 96, 255), 3), (4, (34, 32, 58, 255), 2)])
    for i in range(32):
        img.putpixel((i, 0), (30, 28, 50, 255))
        img.putpixel((0, i), (30, 28, 50, 255))
    for a in range(0, 360, 20):
        r = math.radians(a)
        img.putpixel((int(16 + 8 * math.cos(r)), int(16 + 8 * math.sin(r))), (200, 170, 90, 255))
    for p in ((16, 9), (16, 23), (9, 16), (23, 16)):
        img.putpixel(p, (230, 200, 110, 255))
    return img


def save_late3_sprites():
    for name, painter in (("puppet_soldier", puppet_soldier), ("jester_doll", jester_doll), ("thread_spider", thread_spider),
                          ("marionette", marionette), ("sea_serpent", sea_serpent), ("storm_spirit", storm_spirit),
                          ("frost_spirit", frost_spirit), ("leviathan", leviathan), ("apprentice_mage", apprentice_mage),
                          ("magic_armor", magic_armor), ("grimoire", grimoire), ("archmage", archmage)):
        save(painter(), "characters", f"{name}.png")
    save(switch_plate(False), "world", "switch_off.png")
    save(switch_plate(True), "world", "switch_on.png")
    save(icicle(), "projectiles", "icicle.png")
    save(orb((255, 255, 220), (255, 200, 60)), "projectiles", "spark_orb.png")
    save(orb((240, 230, 255), (170, 90, 255)), "projectiles", "arcane_orb.png")
    save(floor_theater(), "tiles", "floor_theater.png")
    save(floor_storm(), "tiles", "floor_storm.png")
    save(floor_arcane(), "tiles", "floor_arcane.png")


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
    for name, cols in BOOTS_COLORS.items():
        save(boots_worn(*cols), "boots", f"{name}_worn.png")
        save(boots_icon(*cols), "boots", f"{name}.png")
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
    save(star(), "projectiles", "star.png")
    save(rock(), "projectiles", "rock.png")
    save(orb(), "projectiles", "orb.png")
    save(orb((255, 255, 255), (230, 60, 110)), "projectiles", "enemy_bullet.png")

    save(coin(), "items", "coin.png")

    save(floor_tile(), "tiles", "floor.png")
    save(floor_hell(), "tiles", "floor_hell.png")
    save(floor_ruins(), "tiles", "floor_ruins.png")
    save(floor_forest(), "tiles", "floor_forest.png")
    save(outline(from_map(FOREST_WOLF)), "characters", "forest_wolf.png")
    save(outline(from_map(MUSHROOM)), "characters", "mushroom.png")
    save(treant(), "characters", "treant.png")
    save(dryad(), "characters", "dryad.png")
    save(thorn(), "projectiles", "thorn.png")
    save(spore(), "projectiles", "spore.png")
    save(outline(from_map(DARK_KNIGHT, pal=DARK_PAL)), "characters", "dark_knight.png")
    save(outline(from_map(HEAVY_KNIGHT, pal=DARK_PAL)), "characters", "heavy_knight.png")
    save(outline(from_map(DARK_ARCHER, pal=DARK_PAL)), "characters", "dark_archer.png")
    save(dullahan(True), "characters", "dullahan.png")
    save(dullahan(False), "characters", "dullahan_headless.png")
    save(dullahan_head(), "characters", "dullahan_head.png")
    save(throne(), "world", "throne.png")
    save(floor_castle(), "tiles", "floor_castle.png")
    save(dark_slash(), "projectiles", "dark_slash.png")
    for name, rows in (("hobgoblin", HOBGOBLIN), ("orc_warrior", ORC_WARRIOR), ("orc_shaman", ORC_SHAMAN),
                       ("skeleton", SKELETON), ("ghost", GHOST), ("baby_wyvern", BABY_WYVERN), ("lizardman", LIZARDMAN),
                       ("lesser_succubus", LESSER_SUCCUBUS), ("royal_guard", ROYAL_GUARD), ("court_mage", COURT_MAGE)):
        save(outline(from_map(rows, pal=X_PAL)), "characters", f"{name}.png")
    save(orc_king(), "characters", "orc_king.png")
    save(reaper(), "characters", "reaper.png")
    save(wyvern(), "characters", "wyvern.png")
    save(succubus(), "characters", "succubus.png")
    save(lost_king(), "characters", "lost_king.png")
    save(crown(), "characters", "crown.png")
    save(heart(), "projectiles", "heart.png")
    save(axe(), "projectiles", "axe.png")
    save(floor_fortress(), "tiles", "floor_fortress.png")
    save(floor_graveyard(), "tiles", "floor_graveyard.png")
    save(floor_crag(), "tiles", "floor_crag.png")
    save(floor_demon(), "tiles", "floor_demon.png")
    save(floor_royal(), "tiles", "floor_royal.png")
    save(wall_tile(), "tiles", "wall.png")
    save(rug(), "tiles", "rug.png")
    save_late_sprites()
    save_late2_sprites()
    save_late3_sprites()

    save(bar_under(), "ui", "bar_under.png")
    save(bar((200, 50, 70)), "ui", "bar_hp.png")
    save(bar((65, 166, 246)), "ui", "bar_dash.png")
    save(bar((150, 80, 180)), "ui", "bar_boss.png")
    save(bar((255, 190, 70)), "ui", "bar_guard.png")


if __name__ == "__main__":
    main()
