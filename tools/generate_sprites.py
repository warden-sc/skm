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

# 51스테이지 대본: 입꼬리가 올라간 상인 (눈을 가늘게 뜨고 한쪽 입꼬리가 올라감)
MERCHANT_SMIRK = MERCHANT[:6] + [
    "...kskksskksk...",
    "...kssssssskk...",
    "....kWWkkkWk....",
] + MERCHANT[9:]


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
    """꼭두각시 마리오네트 (32x48): 금이 간 잿빛 도자기 얼굴, 텅 빈 검은 눈에 붉은 눈동자, 낡은 검붉은 드레스, 머리 위 십자 조종대에서 내려온 실"""
    img = canvas(32, 48)
    face, cheek, dress, dress_d = _c(176, 170, 172), _c(120, 70, 84), _c(66, 18, 34), _c(36, 10, 22)
    joint, wood = _c(120, 100, 84), _c(90, 70, 56)
    rect(img, 6, 1, 25, 2, wood)                     # 십자 조종대
    rect(img, 15, 0, 16, 5, wood)
    for x in (7, 15, 24):                            # 조종대에서 내려오는 실
        for y in range(3, 16 if x == 15 else 24):
            put(img, [(x, y)], (170, 166, 180, 200))
    ellipse(img, 15.5, 13, 6, 6, face)               # 머리
    rect(img, 9, 7, 22, 9, _c(24, 16, 22))           # 머리카락
    put(img, [(9, 10), (9, 11), (22, 10), (22, 11), (9, 12), (22, 12), (9, 13), (22, 14)], _c(24, 16, 22))
    rect(img, 12, 11, 14, 13, _c(14, 8, 14))           # 텅 빈 눈
    rect(img, 17, 11, 19, 13, _c(14, 8, 14))
    put(img, [(13, 12), (18, 12)], _c(255, 40, 50))
    put(img, [(13, 14), (13, 15), (18, 14)], _c(40, 20, 30))  # 흘러내린 눈물 자국
    put(img, [(12, 15), (19, 15)], cheek)
    put(img, [(14, 17), (15, 16), (16, 16), (17, 17)], _c(70, 10, 20))
    put(img, [(19, 9), (20, 10), (19, 11), (20, 12), (19, 13), (11, 15), (10, 16)], _c(60, 50, 56))  # 얼굴의 금
    for y in range(20, 40):                          # 드레스
        half = 4 + (y - 20) * 0.4
        for x in range(int(15.5 - half), int(15.5 + half) + 1):
            img.putpixel((x, y), dress if (x + y) % 5 else dress_d)
    rect(img, 13, 20, 18, 22, _c(130, 120, 126))     # 레이스 깃
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
    """대마법사 아르카나 (32x46): 검보라 로브와 희미한 별무늬, 잿빛 수염, 보랏빛으로 타오르는 눈, 끝에 어두운 마력 구슬이 달린 거대한 지팡이"""
    img = canvas(32, 46)
    robe, robe_d, star = _c(58, 42, 92), _c(30, 22, 54), _c(170, 120, 220)
    beard, skin = _c(176, 174, 184), _c(178, 158, 148)
    put(img, [(13, 0), (13, 1), (14, 1), (12, 2), (13, 2), (14, 2)], robe_d)  # 고깔모자
    for y in range(3, 10):
        half = 1 + (y - 3) * 0.9
        rect(img, int(13.5 - half), y, int(13.5 + half), y, robe if y < 9 else robe_d)
    rect(img, 9, 10, 18, 14, skin)
    put(img, [(11, 12), (16, 12), (10, 12), (17, 12)], _c(210, 90, 255))
    for y in range(14, 46):                          # 로브
        half = 6 + (y - 14) * 0.22
        for x in range(int(13.5 - half), int(13.5 + half) + 1):
            img.putpixel((x, y), robe if (x * 3 + y) % 7 else robe_d)
    for y in range(14, 30):                          # 긴 수염
        w = max(1, 5 - (y - 14) // 3)
        rect(img, 13 - w, y, 14 + w, y, beard)
    for x, y in ((8, 34), (18, 38), (10, 42), (17, 28), (7, 25)):  # 별무늬
        put(img, [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], star)
    rect(img, 26, 6, 27, 45, _c(60, 44, 40))        # 지팡이
    put(img, [(25, 6), (28, 6), (24, 4), (29, 4)], _c(110, 96, 70))
    ellipse(img, 26.5, 3, 3, 3, _c(110, 40, 170))   # 마력 구슬
    put(img, [(25, 2), (26, 3)], _c(230, 150, 255))
    rect(img, 20, 22, 25, 24, robe)                  # 지팡이를 쥔 팔
    rect(img, 24, 22, 26, 25, skin)
    return outline(img)


def floor_theater():
    """인형 극장: 어둠 속 썩은 무대 마루 + 검붉은 얼룩"""
    img = _floor(151, (62, 44, 38), 4, [(6, (46, 32, 28, 255), 3), (4, (90, 24, 30, 255), 2)])
    for y in (0, 8, 16, 24):
        for x in range(32):
            img.putpixel((x, y), (36, 24, 22, 255))
    for y in range(32):
        img.putpixel(((y // 8) * 11 % 32, y), (40, 28, 24, 255))
    return img


def floor_storm():
    """폭풍의 바다: 젖은 검푸른 바위 + 물웅덩이"""
    img = _floor(161, (52, 62, 78), 5, [(6, (70, 90, 110, 255), 3), (6, (36, 44, 56, 255), 2), (3, (120, 150, 180, 255), 1)])
    return img


def floor_arcane():
    """대마법사의 탑: 그을린 검남색 석판 + 희미하게 빛나는 보랏빛 룬"""
    img = _floor(171, (28, 24, 42), 3, [(5, (38, 32, 56, 255), 3), (4, (18, 16, 28, 255), 2)])
    for i in range(32):
        img.putpixel((i, 0), (14, 12, 22, 255))
        img.putpixel((0, i), (14, 12, 22, 255))
    for a in range(0, 360, 20):
        r = math.radians(a)
        img.putpixel((int(16 + 8 * math.cos(r)), int(16 + 8 * math.sin(r))), (100, 60, 140, 255))
    for p in ((16, 9), (16, 23), (9, 16), (23, 16)):
        img.putpixel(p, (150, 80, 200, 255))
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


# ---------------------------------------------------------------- 21스테이지
def gear(size, teeth, col, col_d, hub):
    """톱니바퀴 (회전용, size x size)"""
    img = canvas(size)
    c = (size - 1) / 2.0
    r_out, r_in = size / 2.0 - 0.5, size / 2.0 - 2.5
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c)
            a = math.atan2(y - c, x - c)
            tooth = math.cos(a * teeth) > 0.2
            if d <= r_in or (d <= r_out and tooth):
                img.putpixel((x, y), col if d < r_in - 1.5 else col_d)
            if d <= size * 0.16:
                img.putpixel((x, y), hub)
            if size * 0.16 < d < r_in - 2 and int(round(math.degrees(a))) % 90 in range(-6, 7):
                img.putpixel((x, y), col_d)   # 바퀴살
    return outline(img)


def temos():
    """기계의 정점 테모스 (56x60): 놋쇠·강철 기계 거인, 가슴 한가운데 거대한 태엽 자리(톱니는 따로 돌아감), 붉은 눈"""
    img = canvas(56, 60)
    brass, brass_d, steel, steel_d = _c(176, 136, 70), _c(120, 88, 44), _c(110, 116, 128), _c(66, 70, 82)
    rect(img, 12, 16, 43, 44, steel)                 # 몸통
    rect(img, 12, 16, 43, 18, brass)
    rect(img, 12, 42, 43, 44, brass_d)
    ellipse(img, 27.5, 30, 12, 12, steel_d)          # 가슴의 태엽 자리 (어두운 구멍)
    ellipse(img, 27.5, 30, 10, 10, _c(36, 30, 30))
    rect(img, 2, 16, 11, 22, brass)                  # 어깨
    rect(img, 44, 16, 53, 22, brass)
    rect(img, 4, 22, 10, 40, steel_d)                # 팔 (피스톤)
    rect(img, 45, 22, 51, 40, steel_d)
    rect(img, 6, 24, 8, 38, steel)
    rect(img, 47, 24, 49, 38, steel)
    rect(img, 2, 40, 12, 46, brass_d)                # 집게손
    rect(img, 43, 40, 53, 46, brass_d)
    rect(img, 16, 45, 23, 58, steel_d)               # 다리
    rect(img, 32, 45, 39, 58, steel_d)
    rect(img, 14, 56, 25, 59, brass_d)
    rect(img, 30, 56, 41, 59, brass_d)
    rect(img, 20, 3, 35, 15, brass)                  # 머리
    rect(img, 22, 7, 33, 10, _c(30, 24, 24))
    put(img, [(24, 8), (25, 8), (30, 8), (31, 8)], _c(255, 60, 40))
    rect(img, 26, 0, 29, 3, steel_d)                 # 굴뚝
    for x in (14, 41):                               # 증기 배관
        rect(img, x, 6, x + 1, 16, _c(90, 96, 108))
    for x in range(14, 43, 4):                       # 리벳
        put(img, [(x, 17)], _c(230, 200, 120))
    return outline(img)


def coolant_machine():
    """냉각수 기계 (20x28): 푸른 냉각수가 든 유리 탱크, 강철 받침, 배관"""
    img = canvas(20, 28)
    steel, steel_d, coolant = _c(110, 116, 128), _c(66, 70, 82), _c(80, 200, 240)
    rect(img, 2, 22, 17, 27, steel_d)
    rect(img, 4, 20, 15, 22, steel)
    rect(img, 4, 2, 15, 20, (180, 220, 240, 180))   # 유리
    rect(img, 5, 7, 14, 19, coolant)
    rect(img, 5, 7, 14, 8, _c(160, 240, 255))
    put(img, [(7, 11), (10, 14), (12, 10), (8, 16)], _c(200, 250, 255))   # 기포
    rect(img, 3, 0, 16, 2, steel)
    rect(img, 16, 12, 19, 14, steel_d)               # 배관
    return outline(img)


def clock_spider():
    """태엽 거미 (16x14): 놋쇠 몸통 등에 작은 태엽 열쇠"""
    img = canvas(16, 14)
    brass, brass_d = _c(190, 150, 80), _c(120, 90, 44)
    ellipse(img, 8, 8, 4.5, 3.5, brass)
    put(img, [(6, 7), (10, 7)], _c(255, 70, 50))
    for side in (-1, 1):
        for k in range(3):
            put(img, [(8 + side * 5, 6 + k * 2), (8 + side * 6, 7 + k * 2), (8 + side * 7, 8 + k * 2)], brass_d)
    rect(img, 7, 1, 8, 4, _c(150, 156, 170))
    put(img, [(5, 1), (6, 1), (9, 1), (10, 1)], _c(150, 156, 170))
    return outline(img)


def steam_golem():
    """증기 골렘 (22x22): 보일러 몸통, 굴뚝에서 증기, 붉게 달아오른 화구"""
    img = canvas(22)
    steel, steel_d = _c(96, 100, 112), _c(60, 62, 72)
    ellipse(img, 11, 12, 8, 7, steel)
    ellipse(img, 11, 13, 3.5, 2.5, _c(255, 120, 40))
    rect(img, 8, 2, 13, 6, steel_d)
    put(img, [(9, 4), (12, 4)], _c(255, 200, 80))
    rect(img, 15, 0, 16, 5, steel_d)
    rect(img, 1, 9, 3, 16, steel_d)
    rect(img, 18, 9, 20, 16, steel_d)
    rect(img, 6, 18, 9, 21, steel_d)
    rect(img, 13, 18, 16, 21, steel_d)
    return outline(img)


def machine_gunner():
    """기계 사수 (16x16): 한쪽 팔이 연발 포신인 자동 인형"""
    img = canvas(16)
    brass, steel = _c(170, 130, 70), _c(110, 116, 128)
    rect(img, 5, 1, 10, 5, steel)
    rect(img, 6, 3, 9, 3, _c(255, 60, 40))
    rect(img, 4, 6, 10, 11, brass)
    rect(img, 11, 7, 15, 9, _c(70, 72, 82))         # 포신
    put(img, [(15, 7), (15, 9)], _c(40, 40, 48))
    rect(img, 2, 6, 3, 10, steel)
    rect(img, 5, 12, 6, 15, steel)
    rect(img, 8, 12, 9, 15, steel)
    return outline(img)


def floor_machine():
    """기계 신전: 놋쇠 판 + 리벳 + 철망 바닥"""
    img = _floor(181, (70, 62, 52), 4, [(6, (54, 48, 40, 255), 3), (4, (96, 80, 50, 255), 2)])
    for i in range(32):
        img.putpixel((i, 0), (40, 36, 30, 255))
        img.putpixel((0, i), (40, 36, 30, 255))
    for y in range(18, 30, 2):
        for x in range(18, 30):
            img.putpixel((x, y), (44, 40, 36, 255))
    for p in ((3, 3), (28, 3), (3, 28), (12, 28)):
        img.putpixel(p, (170, 140, 80, 255))
    return img


def save_late4_sprites():
    save(temos(), "characters", "temos.png")
    save(gear(30, 10, _c(200, 160, 80), _c(140, 104, 50), _c(90, 70, 40)), "characters", "gear_big.png")
    save(gear(14, 7, _c(170, 176, 190), _c(110, 116, 128), _c(70, 72, 82)), "characters", "gear_small.png")
    save(coolant_machine(), "characters", "coolant_machine.png")
    save(clock_spider(), "characters", "clock_spider.png")
    save(steam_golem(), "characters", "steam_golem.png")
    save(machine_gunner(), "characters", "machine_gunner.png")
    save(gear(8, 6, _c(220, 190, 110), _c(150, 120, 60), _c(90, 70, 40)), "projectiles", "gear_bolt.png")
    save(floor_machine(), "tiles", "floor_machine.png")


# ---------------------------------------------------------------- 22스테이지
def scorpion_boss():
    """사막의 암살자 스콜피언 (56x44): 검붉은 모래색 갑각, 거대한 집게 두 개, 머리 위로 치켜든 꼬리 끝에 보랏빛 독침"""
    img = canvas(56, 44)
    shell, shell_d, shell_hi = _c(150, 96, 60), _c(96, 56, 36), _c(196, 140, 90)
    venom = _c(190, 70, 230)
    ellipse(img, 28, 32, 13, 8, shell)               # 몸통
    for x in range(18, 40, 4):                       # 마디
        rect(img, x, 26, x, 38, shell_d)
    ellipse(img, 28, 29, 9, 3, shell_hi)
    for side in (-1, 1):                             # 다리
        for k in range(4):
            x0 = 28 + side * (10 + k * 2)
            put(img, [(x0, 36 + k % 2), (x0 + side, 38 + k % 2), (x0 + side * 2, 40 + k % 2), (x0 + side * 3, 41 + k % 2)], shell_d)
    for side in (-1, 1):                             # 집게 (팔 + 큰 집게)
        ax = 28 + side * 11
        rect(img, min(ax, ax + side * 6), 26, max(ax, ax + side * 6), 28, shell)
        cx = 28 + side * 20
        ellipse(img, cx, 24, 6, 5, shell)
        ellipse(img, cx + side * 2, 21, 3, 2, shell_hi)
        rect(img, cx - 2 + side * 3, 17, cx + 2 + side * 3, 19, shell_d)   # 집게 날 사이
        put(img, [(cx + side * 5, 16), (cx + side * 6, 15), (cx + side * 1, 16), (cx, 15)], shell_d)
    put(img, [(25, 31), (31, 31)], _c(255, 60, 40))  # 눈
    put(img, [(24, 31), (32, 31)], _c(255, 140, 60))
    for i in range(22):                              # 치켜든 꼬리 (마디)
        t = i / 21.0
        x = int(round(30 + 6 * math.sin(t * math.pi * 0.9)))
        y = int(round(26 - t * 24))
        w = 3 - i // 9
        rect(img, x - w, y, x + w, y, shell if i % 4 else shell_d)
    ellipse(img, 33, 2, 2.5, 2, venom)               # 독침
    put(img, [(35, 3), (36, 4), (37, 5)], venom)
    put(img, [(32, 1)], _c(240, 190, 255))
    return outline(img)


def sand_mound():
    """모래 속으로 숨은 스콜피언이 움직이는 모래 둔덕 (28x14)"""
    img = canvas(28, 14)
    ellipse(img, 13.5, 9, 13, 5, _c(200, 164, 104))
    ellipse(img, 13.5, 8, 9, 3, _c(222, 190, 130))
    put(img, [(6, 9), (10, 11), (17, 10), (21, 8)], _c(160, 124, 74))
    return img


def desert_bandit():
    """사막 도적 (16x16): 터번과 복면, 휘어진 단검"""
    img = canvas(16)
    cloth, cloth_d, skin = _c(200, 170, 120), _c(140, 110, 70), _c(190, 140, 100)
    rect(img, 5, 1, 10, 4, cloth)
    rect(img, 5, 5, 10, 6, _c(70, 50, 40))
    put(img, [(6, 4), (9, 4)], _c(30, 20, 20))
    rect(img, 4, 7, 11, 12, cloth_d)
    rect(img, 6, 7, 9, 8, skin)
    rect(img, 5, 13, 6, 15, cloth_d)
    rect(img, 9, 13, 10, 15, cloth_d)
    put(img, [(12, 6), (13, 7), (13, 8), (12, 9)], _c(220, 225, 235))
    rect(img, 12, 9, 12, 11, _c(110, 80, 50))
    return outline(img)


def desert_viper():
    """사막 독사 (18x12): 모래색 뱀, 보랏빛 독니"""
    img = canvas(18, 12)
    sc, sc_d = _c(200, 170, 100), _c(140, 110, 60)
    for i in range(14):
        x = 2 + i
        y = 7 + int(round(2 * math.sin(i * 0.8)))
        rect(img, x, y - 1, x, y, sc if i % 3 else sc_d)
    ellipse(img, 15, 4, 2.5, 2, sc)
    put(img, [(16, 3)], _c(40, 20, 20))
    put(img, [(17, 6), (14, 6)], _c(200, 90, 240))
    return outline(img)


def mummy():
    """미라 (16x16): 낡은 붕대, 빛나는 눈"""
    img = canvas(16)
    band, band_d = _c(214, 204, 176), _c(150, 140, 116)
    rect(img, 5, 1, 10, 6, band)
    put(img, [(6, 3), (9, 3)], _c(120, 255, 160))
    rect(img, 4, 7, 11, 12, band)
    for y in range(1, 13, 2):
        rect(img, 4 if y > 6 else 5, y, 11 if y > 6 else 10, y, band_d)
    rect(img, 2, 7, 3, 9, band)
    rect(img, 12, 7, 13, 9, band)
    rect(img, 5, 13, 6, 15, band_d)
    rect(img, 9, 13, 10, 15, band_d)
    put(img, [(13, 10), (14, 11)], band_d)
    return outline(img)


def floor_desert():
    """사막: 바람 무늬가 진 고운 모래"""
    img = _floor(191, (196, 160, 104), 5, [(8, (214, 180, 124, 255), 3), (6, (170, 134, 84, 255), 2)])
    for k in range(3):
        for x in range(32):
            y = (6 + k * 11 + int(round(2 * math.sin(x * 0.4 + k)))) % 32
            img.putpixel((x, y), (178, 142, 90, 255))
    return img


def save_late5_sprites():
    save(scorpion_boss(), "characters", "scorpion_boss.png")
    save(sand_mound(), "characters", "sand_mound.png")
    save(desert_bandit(), "characters", "desert_bandit.png")
    save(desert_viper(), "characters", "desert_viper.png")
    save(mummy(), "characters", "mummy.png")
    save(orb((250, 220, 255), (170, 60, 220)), "projectiles", "venom.png")
    save(floor_desert(), "tiles", "floor_desert.png")


# ---------------------------------------------------------------- 23~24스테이지
def vampire_lord():
    """피의 군주 벨 (30x42): 창백한 얼굴, 뒤로 넘긴 흑발, 붉은 눈, 높이 선 깃의 검붉은 망토"""
    img = canvas(30, 42)
    cape, cape_in, suit = _c(40, 12, 20), _c(140, 20, 40), _c(30, 26, 36)
    skin, hair = _c(214, 206, 214), _c(20, 16, 24)
    for y in range(8, 41):                           # 망토 (바깥 검정, 안감 진홍)
        half = 5 + (y - 8) * 0.32
        for x in range(int(14.5 - half), int(14.5 + half) + 1):
            edge = abs(x - 14.5) > half - 2
            img.putpixel((x, y), cape if edge else (cape_in if y > 16 and (x + y) % 9 else cape))
    for side in (-1, 1):                             # 높이 선 깃
        for i in range(6):
            put(img, [(14 + side * (5 + i // 2), 3 + i), (14 + side * (6 + i // 2), 4 + i)], cape)
    rect(img, 11, 15, 18, 36, suit)                  # 몸
    rect(img, 13, 15, 16, 18, _c(230, 225, 230))     # 셔츠 깃
    put(img, [(14, 17), (15, 17)], _c(200, 20, 40))  # 루비 브로치
    rect(img, 11, 4, 18, 13, skin)                   # 얼굴
    rect(img, 10, 2, 19, 5, hair)                    # 뒤로 넘긴 머리
    put(img, [(10, 6), (19, 6), (14, 6), (15, 6), (14, 7)], hair)
    put(img, [(12, 9), (17, 9)], _c(255, 30, 50))    # 붉은 눈
    put(img, [(13, 12), (16, 12)], _c(250, 250, 250))  # 송곳니
    rect(img, 13, 11, 16, 11, _c(120, 20, 40))
    rect(img, 12, 37, 13, 41, suit)
    rect(img, 16, 37, 17, 41, suit)
    return outline(img, (8, 4, 8, 255))


def blood_bat():
    """흡혈 박쥐 탄 (10x8)"""
    img = canvas(10, 8)
    wing = _c(60, 20, 30)
    put(img, [(0, 2), (1, 1), (2, 2), (3, 3), (8, 1), (9, 2), (7, 2), (6, 3)], wing)
    rect(img, 1, 3, 8, 4, wing)
    ellipse(img, 4.5, 4, 1.6, 1.6, _c(90, 30, 40))
    put(img, [(4, 3), (5, 3)], _c(255, 40, 50))
    return outline(img, (20, 6, 10, 255))


def lesser_vampire():
    """하위 뱀파이어 (16x16): 창백한 얼굴, 붉은 눈, 짧은 망토"""
    img = canvas(16)
    cape, skin = _c(60, 16, 28), _c(200, 196, 206)
    rect(img, 5, 1, 10, 6, skin)
    rect(img, 5, 0, 10, 1, _c(30, 24, 30))
    put(img, [(6, 3), (9, 3)], _c(255, 40, 50))
    put(img, [(7, 5), (8, 5)], _c(240, 240, 240))
    for y in range(7, 14):
        half = 3 + (y - 7) * 0.5
        rect(img, int(7.5 - half), y, int(7.5 + half), y, cape)
    rect(img, 6, 7, 9, 12, _c(36, 30, 40))
    rect(img, 5, 14, 6, 15, _c(30, 24, 30))
    rect(img, 9, 14, 10, 15, _c(30, 24, 30))
    return outline(img, (8, 4, 8, 255))


def vampire_bat():
    """흡혈 박쥐 (16x12)"""
    img = canvas(16, 12)
    wing, body = _c(56, 30, 40), _c(80, 44, 56)
    for i in range(6):
        rect(img, i, 3 + i // 2, i, 7 - i // 3, wing)
        rect(img, 15 - i, 3 + i // 2, 15 - i, 7 - i // 3, wing)
    ellipse(img, 7.5, 6, 2.5, 3, body)
    put(img, [(6, 1), (9, 1)], body)
    put(img, [(6, 5), (9, 5)], _c(255, 50, 60))
    return outline(img, (16, 8, 12, 255))


def ghoul():
    """구울 (16x16): 회녹색 피부, 구부정한 몸, 긴 손톱"""
    img = canvas(16)
    skin, skin_d = _c(120, 140, 110), _c(80, 96, 74)
    rect(img, 4, 2, 9, 7, skin)
    put(img, [(5, 4), (8, 4)], _c(255, 230, 120))
    rect(img, 5, 6, 8, 6, _c(60, 20, 20))
    rect(img, 4, 8, 11, 12, skin_d)
    rect(img, 11, 7, 13, 10, skin)
    put(img, [(14, 10), (14, 11), (13, 11)], _c(230, 230, 220))
    rect(img, 1, 8, 3, 11, skin)
    rect(img, 5, 13, 6, 15, skin_d)
    rect(img, 9, 13, 10, 15, skin_d)
    return outline(img)


def basilisk():
    """맹독의 패주 바실리스크 (60x44, 오른쪽을 봄): 왕관 같은 볏의 거대 독룡, 노란 눈, 머리에 독샘 자리 (독샘은 따로)"""
    img = canvas(60, 44)
    sc, sc_d, belly = _c(70, 110, 60), _c(40, 70, 36), _c(170, 180, 110)
    for i in range(40):                              # 똬리 튼 몸
        t = i / 39.0
        x = 18 + i
        y = 34 - int(round(6 * math.sin(t * math.pi * 1.5)))
        rect(img, x - 1, y - 4 + (i // 12), x + 1, y + 3, sc if i % 5 else sc_d)
        put(img, [(x, y + 3)], belly)
    for i in range(5):                               # 가늘어지는 꼬리 끝
        put(img, [(58, 34 - i), (59, 33 - i)], sc_d)
    for i in range(16):                              # 치켜든 목
        x = 16 + int(i * 0.3)
        y = 33 - i
        rect(img, x - 4, y, x + 3, y, sc)
        put(img, [(x - 4, y)], belly)
    ellipse(img, 14, 12, 10, 7, sc)                  # 머리
    rect(img, 2, 13, 10, 17, sc)                     # 주둥이
    put(img, [(2, 17), (4, 17), (6, 17), (8, 17)], _c(240, 240, 220))
    ellipse(img, 12, 10, 2.5, 2, _c(255, 230, 40))   # 노란 눈
    rect(img, 12, 9, 12, 11, _c(20, 20, 10))
    for k, x in enumerate((10, 14, 18, 22)):         # 왕관 같은 볏
        h = 6 - abs(k - 1.5) * 1.5
        rect(img, x, int(5 - h), x + 1, 5, _c(200, 60, 60))
    return outline(img).transpose(Image.FLIP_LEFT_RIGHT)


def poison_gland():
    """바실리스크의 독샘 (14x12): 머리 위에서 부글거리는 초록 독주머니 — 체력이 따로"""
    img = canvas(14, 12)
    ellipse(img, 6.5, 6, 6, 5, _c(90, 200, 70))
    ellipse(img, 6.5, 7, 4, 3, _c(60, 160, 50))
    put(img, [(4, 3), (5, 3), (9, 5)], _c(200, 255, 160))
    put(img, [(3, 8), (8, 9), (10, 7)], _c(40, 110, 40))
    return outline(img, (20, 50, 20, 255))


def venom_lizard():
    """독 도마뱀 (18x12): 초록 비늘에 보라 반점"""
    img = canvas(18, 12)
    sc, sc_d = _c(90, 150, 70), _c(56, 100, 44)
    ellipse(img, 8, 7, 6, 3, sc)
    ellipse(img, 14.5, 6, 3, 2, sc)
    put(img, [(15, 5)], _c(255, 230, 60))
    for x in range(0, 3):
        put(img, [(x, 7 + (x % 2))], sc_d)
    for x in (5, 11):
        put(img, [(x, 10), (x - 1, 11), (x + 1, 11)], sc_d)
    put(img, [(6, 6), (9, 7), (11, 5)], _c(160, 70, 190))
    return outline(img)


def poison_toad():
    """독두꺼비 (16x14): 울퉁불퉁한 보랏빛 등, 노란 배"""
    img = canvas(16, 14)
    back, belly = _c(110, 70, 130), _c(220, 200, 90)
    ellipse(img, 7.5, 8, 6.5, 5, back)
    ellipse(img, 7.5, 10, 4.5, 2.5, belly)
    put(img, [(4, 4), (11, 4)], _c(255, 220, 60))
    put(img, [(5, 7), (9, 6), (11, 9), (3, 9)], _c(150, 220, 80))
    put(img, [(1, 12), (2, 13), (13, 12), (14, 13)], back)
    return outline(img)


def venom_spider():
    """맹독 거미 (16x14): 검은 몸에 초록 독 무늬"""
    img = canvas(16, 14)
    body = _c(30, 30, 34)
    ellipse(img, 8, 8, 4, 3.5, body)
    ellipse(img, 8, 4, 2.5, 2, body)
    put(img, [(7, 7), (8, 8), (9, 7), (8, 9)], _c(120, 230, 80))
    put(img, [(7, 4), (9, 4)], _c(255, 60, 60))
    for side in (-1, 1):
        for k in range(4):
            put(img, [(8 + side * 4, 6 + k), (8 + side * 6, 5 + k * 2), (8 + side * 7, 7 + k * 2)], body)
    return outline(img, (70, 100, 60, 255))


def floor_blood():
    """피의 성: 검붉은 석판 + 마른 핏자국"""
    img = _floor(201, (52, 30, 36), 4, [(6, (70, 20, 30, 255), 3), (5, (36, 20, 26, 255), 2), (3, (110, 20, 30, 255), 1)])
    for i in range(32):
        img.putpixel((i, 0), (28, 14, 18, 255))
        img.putpixel((0, i), (28, 14, 18, 255))
    return img


def floor_swamp():
    """맹독의 늪: 질척한 녹갈색 진흙 + 독물 웅덩이"""
    img = _floor(211, (60, 70, 44), 5, [(6, (70, 110, 50, 255), 3), (6, (44, 50, 32, 255), 2), (4, (120, 180, 80, 255), 1)])
    return img


def save_late6_sprites():
    for name, painter in (("vampire_lord", vampire_lord), ("lesser_vampire", lesser_vampire), ("vampire_bat", vampire_bat), ("ghoul", ghoul),
                          ("basilisk", basilisk), ("poison_gland", poison_gland), ("venom_lizard", venom_lizard),
                          ("poison_toad", poison_toad), ("venom_spider", venom_spider)):
        save(painter(), "characters", f"{name}.png")
    save(blood_bat(), "projectiles", "blood_bat.png")
    save(orb((255, 210, 210), (190, 20, 40)), "projectiles", "blood_orb.png")
    save(orb((220, 255, 200), (70, 170, 50)), "projectiles", "poison_orb.png")
    save(floor_blood(), "tiles", "floor_blood.png")
    save(floor_swamp(), "tiles", "floor_swamp.png")


# ---------------------------------------------------------------- 25~27스테이지
def sol():
    """해의 쌍둥이 솔 (30x40): 금빛 갑옷, 등 뒤의 태양 고리, 불꽃 대검"""
    img = canvas(30, 40)
    gold, gold_d, red, skin = _c(240, 190, 70), _c(180, 120, 40), _c(200, 60, 40), _c(240, 200, 160)
    for a in range(0, 360, 15):                      # 태양 고리 + 빛살
        r = math.radians(a)
        put(img, [(int(round(14.5 + 11 * math.cos(r))), int(round(11 + 11 * math.sin(r))))], _c(255, 220, 100))
        if a % 45 == 0:
            put(img, [(int(round(14.5 + 13 * math.cos(r))), int(round(11 + 13 * math.sin(r))))], _c(255, 240, 150))
    rect(img, 11, 6, 18, 13, skin)
    rect(img, 10, 4, 19, 6, gold)                    # 투구
    put(img, [(12, 9), (17, 9)], _c(255, 120, 40))
    rect(img, 9, 14, 20, 28, gold)
    rect(img, 9, 14, 20, 16, gold_d)
    put(img, [(14, 20), (15, 20), (14, 21), (15, 21)], red)
    rect(img, 6, 15, 8, 25, gold_d)
    rect(img, 21, 15, 23, 25, gold_d)
    rect(img, 10, 29, 13, 38, gold_d)
    rect(img, 16, 29, 19, 38, gold_d)
    rect(img, 25, 4, 26, 28, _c(255, 150, 60))       # 불꽃 대검
    put(img, [(24, 4), (27, 4), (25, 2), (26, 2), (25, 3), (26, 3)], _c(255, 230, 120))
    rect(img, 23, 27, 28, 28, gold_d)
    return outline(img)


def luna():
    """달의 쌍둥이 루나 (30x40): 은빛 로브, 초승달 머리장식, 달빛 활"""
    img = canvas(30, 40)
    silver, silver_d, blue, skin = _c(200, 210, 230), _c(130, 140, 170), _c(120, 150, 240), _c(236, 226, 236)
    for a in range(200, 340, 6):                     # 초승달 머리장식
        r = math.radians(a)
        put(img, [(int(round(14.5 + 8 * math.cos(r))), int(round(8 + 8 * math.sin(r))))], _c(230, 240, 255))
    rect(img, 11, 5, 18, 12, skin)
    rect(img, 10, 4, 19, 5, _c(170, 180, 220))       # 은발
    rect(img, 9, 6, 10, 18, _c(170, 180, 220))
    rect(img, 19, 6, 20, 18, _c(170, 180, 220))
    put(img, [(12, 8), (17, 8)], blue)
    for y in range(13, 39):                          # 로브
        half = 4 + (y - 13) * 0.3
        for x in range(int(14.5 - half), int(14.5 + half) + 1):
            img.putpixel((x, y), silver if (x + y) % 6 else silver_d)
    rect(img, 13, 15, 16, 18, blue)
    for i in range(16):                              # 달빛 활
        put(img, [(25 + int(round(2 * math.sin(i / 15.0 * math.pi))), 10 + i)], _c(170, 200, 255))
    rect(img, 24, 10, 24, 25, (230, 240, 255, 160))
    return outline(img)


def glacia():
    """빙결의 여왕 글라시아 (30x44): 얼음 왕관, 하늘빛 드레스, 얼음 홀"""
    img = canvas(30, 44)
    ice, ice_d, dress, skin = _c(200, 236, 255), _c(130, 190, 230), _c(110, 170, 220), _c(226, 236, 244)
    for x in (10, 13, 15, 17, 20):                   # 얼음 왕관
        h = 4 if x in (13, 17) else (6 if x == 15 else 2)
        rect(img, x, 5 - h, x, 5, ice)
    rect(img, 10, 5, 20, 6, ice_d)
    rect(img, 11, 7, 19, 14, skin)
    rect(img, 9, 7, 10, 22, _c(230, 245, 255))       # 흰 머리
    rect(img, 20, 7, 21, 22, _c(230, 245, 255))
    put(img, [(13, 10), (17, 10)], _c(60, 140, 220))
    put(img, [(14, 13), (15, 13), (16, 13)], _c(150, 190, 220))
    for y in range(15, 43):                          # 드레스
        half = 4 + (y - 15) * 0.38
        for x in range(int(15 - half), int(15 + half) + 1):
            img.putpixel((x, y), dress if (x * 2 + y) % 7 else ice_d)
    for x, y in ((9, 36), (20, 33), (13, 40), (17, 28)):
        put(img, [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], ice)
    rect(img, 25, 8, 25, 38, ice_d)                  # 얼음 홀
    for d in range(4):
        put(img, [(25 - d, 7 - d), (25 + d, 7 - d)], ice)
    put(img, [(25, 2), (25, 1)], ice)
    return outline(img, (30, 60, 100, 255))


def ice_pillar():
    """얼음 기둥 (18x30): 눈보라를 막아 주고, 여왕의 냉기를 반사하는 엄폐물"""
    img = canvas(18, 30)
    for y in range(30):
        w = 6 if y > 4 else 2 + y
        for x in range(int(8.5 - w), int(8.5 + w) + 1):
            img.putpixel((x, y), (180, 225, 250, 220) if (x - y) % 7 else (230, 248, 255, 230))
    rect(img, 4, 26, 13, 29, _c(120, 170, 210))
    put(img, [(6, 8), (6, 9), (7, 10)], _c(255, 255, 255))
    return outline(img, (60, 110, 160, 255))


def nox():
    """심연의 군주 녹스 (36x48): 어둠 그 자체인 거대한 망토, 빛나는 보랏빛 눈, 그림자 손"""
    img = canvas(36, 48)
    dark, dark_d, edge = _c(30, 22, 44), _c(14, 10, 22), _c(70, 50, 110)
    for y in range(4, 47):                           # 망토 (아래로 흩어지는 그림자)
        half = 4 + (y - 4) * 0.33
        for x in range(int(17.5 - half), int(17.5 + half) + 1):
            if y > 40 and (x * 3 + y) % 4 == 0:
                continue
            img.putpixel((x, y), edge if abs(x - 17.5) > half - 1 else (dark if (x + y) % 6 else dark_d))
    ellipse(img, 17.5, 9, 6, 6, dark_d)              # 두건 속 어둠
    put(img, [(15, 9), (20, 9), (14, 9), (21, 9)], _c(200, 120, 255))
    put(img, [(15, 10), (20, 10)], _c(255, 220, 255))
    for side in (-1, 1):                             # 그림자 손
        for i in range(8):
            put(img, [(17 + side * (9 + i), 20 + i // 2)], dark)
        put(img, [(17 + side * 17, 24), (17 + side * 18, 23), (17 + side * 18, 25)], edge)
    return outline(img, (8, 4, 14, 255))


def torch(lit):
    """횃불 (10x22)"""
    img = canvas(10, 22)
    rect(img, 4, 8, 5, 21, _c(110, 80, 50))
    rect(img, 2, 7, 7, 9, _c(80, 74, 70))
    if lit:
        ellipse(img, 4.5, 4, 3.5, 4, _c(255, 150, 40))
        ellipse(img, 4.5, 5, 2, 2.5, _c(255, 230, 120))
    else:
        put(img, [(4, 6), (5, 6), (4, 5)], _c(60, 56, 54))
    return outline(img)


def sun_priest():
    """태양 사제 (16x16): 금빛 사제복, 태양 문양"""
    img = canvas(16)
    robe, robe_d = _c(240, 220, 160), _c(200, 160, 80)
    rect(img, 5, 1, 10, 6, PAL["s"])
    rect(img, 5, 0, 10, 1, robe_d)
    put(img, [(6, 3), (9, 3)], _c(60, 40, 20))
    for y in range(7, 16):
        half = 3 + (y - 7) * 0.4
        rect(img, int(7.5 - half), y, int(7.5 + half), y, robe)
    ellipse(img, 7.5, 10, 1.6, 1.6, _c(255, 150, 40))
    rect(img, 12, 3, 12, 14, robe_d)
    put(img, [(11, 2), (13, 2), (12, 1), (12, 3)], _c(255, 200, 60))
    return outline(img)


def moon_archer():
    """월광 궁수 (16x16): 남색 망토, 은빛 활"""
    img = canvas(16)
    cloak, silver = _c(50, 60, 110), _c(200, 210, 230)
    rect(img, 5, 1, 10, 6, cloak)
    rect(img, 6, 3, 9, 5, PAL["s"])
    put(img, [(6, 4), (9, 4)], _c(80, 120, 220))
    rect(img, 4, 7, 11, 12, cloak)
    rect(img, 5, 13, 6, 15, cloak)
    rect(img, 9, 13, 10, 15, cloak)
    for i in range(10):
        put(img, [(12 + int(round(1.5 * math.sin(i / 9.0 * math.pi))), 3 + i)], silver)
    return outline(img)


def star_spirit():
    """별빛 정령 (14x14): 빛나는 별"""
    img = canvas(14)
    for i in range(5):
        a = math.radians(i * 72 - 90)
        for r in range(7):
            put(img, [(int(round(6.5 + math.cos(a) * r)), int(round(6.5 + math.sin(a) * r)))], _c(255, 240, 160))
    ellipse(img, 6.5, 6.5, 2.5, 2.5, _c(255, 255, 220))
    put(img, [(5, 6), (8, 6)], _c(120, 100, 40))
    return outline(img, (120, 90, 30, 255))


def frost_wolf():
    """서리 늑대 (18x14): 하얀 털, 얼음 갈기"""
    img = canvas(18, 14)
    fur, fur_d = _c(230, 240, 250), _c(160, 190, 220)
    ellipse(img, 8, 8, 6, 3.5, fur)
    ellipse(img, 14, 6, 3, 2.5, fur)
    put(img, [(16, 4), (17, 6), (15, 5)], fur_d)
    put(img, [(15, 5)], _c(60, 140, 220))
    for x in (4, 7, 10, 12):
        rect(img, x, 11, x, 13, fur_d)
    put(img, [(2, 6), (1, 5), (0, 4)], fur_d)
    put(img, [(6, 4), (8, 4), (10, 4)], _c(170, 225, 255))
    return outline(img)


def ice_golem():
    """얼음 골렘 (22x22): 얼음 덩어리 몸"""
    img = canvas(22)
    ice, ice_d = _c(170, 215, 245), _c(110, 160, 210)
    ellipse(img, 11, 12, 8, 7, ice)
    rect(img, 7, 2, 14, 7, ice_d)
    put(img, [(9, 4), (12, 4)], _c(40, 90, 170))
    rect(img, 1, 9, 3, 16, ice_d)
    rect(img, 18, 9, 20, 16, ice_d)
    rect(img, 6, 18, 9, 21, ice_d)
    rect(img, 13, 18, 16, 21, ice_d)
    put(img, [(8, 10), (13, 13), (10, 15)], _c(240, 252, 255))
    return outline(img, (40, 80, 130, 255))


def yeti():
    """설인 (20x20): 덥수룩한 흰 털, 파란 얼굴"""
    img = canvas(20)
    fur, fur_d, face = _c(236, 240, 246), _c(180, 190, 206), _c(120, 150, 200)
    ellipse(img, 10, 11, 7, 7, fur)
    rect(img, 7, 4, 12, 9, face)
    put(img, [(8, 6), (11, 6)], _c(20, 20, 40))
    rect(img, 8, 8, 11, 8, _c(240, 240, 240))
    rect(img, 1, 9, 3, 16, fur_d)
    rect(img, 16, 9, 18, 16, fur_d)
    rect(img, 5, 17, 8, 19, fur_d)
    rect(img, 11, 17, 14, 19, fur_d)
    return outline(img)


def shadow_stalker():
    """그림자 추적자 (16x16): 검은 실루엣, 보랏빛 눈, 단검"""
    img = canvas(16)
    dark = _c(26, 20, 36)
    rect(img, 5, 1, 10, 6, dark)
    put(img, [(6, 3), (9, 3)], _c(200, 120, 255))
    rect(img, 4, 7, 11, 12, dark)
    rect(img, 5, 13, 6, 15, dark)
    rect(img, 9, 13, 10, 15, dark)
    put(img, [(12, 7), (13, 8), (13, 9)], _c(150, 120, 190))
    return outline(img, (90, 60, 140, 255))


def abyss_bat():
    """어둠 박쥐 (16x12)"""
    img = canvas(16, 12)
    wing = _c(30, 22, 44)
    for i in range(6):
        rect(img, i, 3 + i // 2, i, 7 - i // 3, wing)
        rect(img, 15 - i, 3 + i // 2, 15 - i, 7 - i // 3, wing)
    ellipse(img, 7.5, 6, 2.5, 3, _c(44, 34, 60))
    put(img, [(6, 5), (9, 5)], _c(200, 120, 255))
    return outline(img, (80, 50, 120, 255))


def abyss_eye():
    """심연의 눈 (16x16): 떠다니는 거대한 눈알과 촉수"""
    img = canvas(16)
    ellipse(img, 7.5, 7, 6, 6, _c(220, 210, 220))
    ellipse(img, 7.5, 7, 3.5, 3.5, _c(140, 60, 200))
    ellipse(img, 7.5, 7, 1.6, 1.6, _c(10, 6, 14))
    put(img, [(6, 5)], _c(255, 255, 255))
    for x in (3, 7, 11):
        put(img, [(x, 13), (x + 1, 14), (x, 15)], _c(70, 40, 90))
    return outline(img, (40, 20, 50, 255))


def floor_celestial():
    """해와 달의 신전: 금빛·은빛이 교차하는 석판"""
    img = canvas(32)
    rnd = random.Random(221)
    for y in range(32):
        for x in range(32):
            v = rnd.randint(-4, 4)
            gold = (x // 16 + y // 16) % 2 == 0
            base = (150, 126, 80) if gold else (110, 116, 140)
            img.putpixel((x, y), (base[0] + v, base[1] + v, base[2] + v, 255))
    for i in range(32):
        img.putpixel((i, 0), (70, 60, 50, 255))
        img.putpixel((0, i), (70, 60, 50, 255))
        img.putpixel((i, 16), (90, 80, 70, 255))
        img.putpixel((16, i), (90, 80, 70, 255))
    return img


def floor_ice():
    """빙결의 궁전: 푸른 얼음판 + 금 간 자국"""
    img = _floor(231, (150, 190, 220), 5, [(6, (190, 225, 245, 255), 3), (5, (120, 160, 200, 255), 2)])
    for i in range(10):
        img.putpixel((5 + i, 20 - i // 2), (100, 140, 190, 255))
    return img


def floor_void():
    """심연: 칠흑 같은 돌바닥 + 보랏빛 균열"""
    img = _floor(241, (26, 22, 32), 3, [(4, (60, 30, 90, 255), 3), (5, (16, 14, 20, 255), 2)])
    return img


def save_late7_sprites():
    for name, painter in (("sol", sol), ("luna", luna), ("glacia", glacia), ("ice_pillar", ice_pillar), ("nox", nox),
                          ("sun_priest", sun_priest), ("moon_archer", moon_archer), ("star_spirit", star_spirit),
                          ("frost_wolf", frost_wolf), ("ice_golem", ice_golem), ("yeti", yeti),
                          ("shadow_stalker", shadow_stalker), ("abyss_bat", abyss_bat), ("abyss_eye", abyss_eye)):
        save(painter(), "characters", f"{name}.png")
    save(torch(False), "world", "torch_off.png")
    save(torch(True), "world", "torch_on.png")
    save(orb((255, 250, 220), (255, 160, 40)), "projectiles", "sun_orb.png")
    save(orb((240, 245, 255), (120, 150, 240)), "projectiles", "moon_orb.png")
    save(orb((220, 200, 240), (70, 30, 110)), "projectiles", "void_orb.png")
    for name, painter in (("floor_celestial", floor_celestial), ("floor_ice", floor_ice), ("floor_void", floor_void)):
        save(painter(), "tiles", f"{name}.png")


# ---------------------------------------------------------------- 28~30스테이지
def void_worm():
    """공허의 포식자 보이드 웜 (56x46): 보랏빛 마디의 거대 지렁이, 둥근 이빨 고리의 입, 몸에 별빛 무늬"""
    img = canvas(56, 46)
    body, body_d, glow = _c(70, 40, 100), _c(40, 22, 60), _c(190, 140, 255)
    for i in range(26):                              # 땅에서 솟은 몸 (마디)
        t = i / 25.0
        cx = 34 - int(round(10 * math.sin(t * math.pi * 0.9)))
        cy = 44 - i
        w = 7 - i // 9
        rect(img, cx - w, cy, cx + w, cy, body if i % 4 else body_d)
        if i % 5 == 2:
            put(img, [(cx - w + 2, cy), (cx + w - 3, cy)], glow)
    ellipse(img, 26, 12, 11, 10, body)               # 머리
    ellipse(img, 26, 12, 7, 6.5, _c(20, 8, 26))      # 입
    for a in range(0, 360, 30):                      # 이빨 고리
        r = math.radians(a)
        put(img, [(int(round(26 + 6 * math.cos(r))), int(round(12 + 5.5 * math.sin(r))))], _c(240, 230, 210))
    ellipse(img, 26, 12, 2.5, 2.5, _c(150, 60, 220))  # 목구멍의 공허
    rect(img, 10, 44, 46, 45, _c(60, 50, 60))         # 뚫고 나온 땅
    return outline(img, (14, 6, 20, 255))


def stomach_wall():
    """보이드 웜의 위벽 (16x18): 삼켜졌을 때 안에서 때려 부수는 살덩이 — 체력이 따로"""
    img = canvas(16, 18)
    ellipse(img, 7.5, 9, 7, 8.5, _c(170, 70, 110))
    ellipse(img, 7.5, 9, 4.5, 6, _c(210, 100, 140))
    for y in (4, 8, 12):
        put(img, [(5, y), (6, y + 1), (9, y), (10, y + 1)], _c(120, 40, 80))
    return outline(img, (60, 10, 40, 255))


def void_larva():
    """공허 유충 (16x10): 꿈틀대는 보랏빛 애벌레"""
    img = canvas(16, 10)
    for i in range(12):
        x = 2 + i
        y = 5 + int(round(1.5 * math.sin(i * 0.9)))
        rect(img, x, y - 2, x, y + 1, _c(110, 60, 150) if i % 3 else _c(70, 40, 100))
    put(img, [(13, 3), (13, 4)], _c(220, 180, 255))
    return outline(img)


def void_apostle():
    """공허 사도 (16x16): 별빛이 새는 보랏빛 로브, 얼굴 대신 공허"""
    img = canvas(16)
    robe, robe_d = _c(60, 36, 90), _c(36, 20, 56)
    for y in range(4, 16):
        half = 3 + (y - 4) * 0.35
        rect(img, int(7.5 - half), y, int(7.5 + half), y, robe if y % 3 else robe_d)
    ellipse(img, 7.5, 4, 3.5, 3.5, robe_d)
    ellipse(img, 7.5, 4.5, 2, 2, _c(10, 4, 16))
    put(img, [(7, 4), (8, 4)], _c(200, 150, 255))
    put(img, [(5, 9), (10, 11), (7, 13)], _c(220, 200, 255))
    return outline(img)


def rift_beast():
    """균열 짐승 (18x14): 몸에 차원 균열이 갈라진 네발 짐승"""
    img = canvas(18, 14)
    fur, fur_d = _c(50, 40, 70), _c(30, 24, 44)
    ellipse(img, 8, 8, 6, 3.5, fur)
    ellipse(img, 14, 6, 3, 2.5, fur)
    put(img, [(15, 5)], _c(220, 120, 255))
    for x in (4, 7, 10, 12):
        rect(img, x, 11, x, 13, fur_d)
    put(img, [(5, 7), (6, 8), (7, 7), (8, 8), (9, 7)], _c(200, 140, 255))
    return outline(img)


def nightmare():
    """몽마 나이트메어 (32x44): 뿔 달린 검은 말 머리의 악마, 별이 박힌 검보라 망토, 붉은 눈"""
    img = canvas(32, 44)
    dark, dark_d, mane = _c(62, 48, 84), _c(32, 24, 46), _c(140, 70, 210)
    for y in range(16, 43):                          # 망토
        half = 5 + (y - 16) * 0.35
        for x in range(int(15.5 - half), int(15.5 + half) + 1):
            img.putpixel((x, y), dark if (x + y) % 6 else dark_d)
    for x, y in ((10, 30), (20, 26), (14, 37), (22, 38)):
        put(img, [(x, y)], _c(220, 200, 255))
    ellipse(img, 16, 9, 6, 7, dark)                  # 말 머리
    rect(img, 10, 11, 14, 15, dark)                  # 주둥이
    put(img, [(11, 14), (12, 14)], _c(60, 40, 70))
    put(img, [(15, 7), (18, 7)], _c(255, 50, 60))
    for i in range(6):                               # 불꽃 갈기
        put(img, [(20 + i // 2, 3 + i * 2), (21 + i // 2, 4 + i * 2)], mane)
    put(img, [(13, 2), (12, 1), (12, 0), (19, 2), (20, 1), (20, 0)], _c(200, 190, 210))  # 뿔
    return outline(img, (10, 4, 16, 255))


def dream_imp():
    """몽마 하수인 (14x14): 작은 날개의 꼬마 악마"""
    img = canvas(14)
    skin = _c(110, 60, 140)
    ellipse(img, 7, 7, 4, 4, skin)
    put(img, [(5, 6), (8, 6)], _c(255, 230, 80))
    put(img, [(4, 2), (4, 3), (10, 2), (10, 3)], _c(220, 200, 230))
    put(img, [(1, 6), (2, 5), (2, 7), (12, 6), (11, 5), (11, 7)], _c(70, 30, 90))
    put(img, [(6, 9), (7, 9)], _c(255, 255, 255))
    return outline(img)


def baku():
    """꿈먹는 맥 (22x18): 코끼리 코의 몽환적인 맥"""
    img = canvas(22, 18)
    hide, hide_d = _c(150, 140, 180), _c(100, 90, 130)
    ellipse(img, 11, 9, 8, 5, hide)
    ellipse(img, 4, 7, 3.5, 3, hide)
    put(img, [(1, 9), (1, 10), (2, 11), (2, 12)], hide_d)
    put(img, [(4, 6)], _c(40, 30, 60))
    for x in (6, 10, 14, 17):
        rect(img, x, 13, x + 1, 17, hide_d)
    put(img, [(10, 6), (13, 7), (15, 9)], _c(220, 200, 255))
    return outline(img)


def sleep_fairy():
    """잠의 요정 (12x14): 졸린 눈의 작은 요정, 반투명 날개"""
    img = canvas(12, 14)
    ellipse(img, 6, 6, 2.5, 2.5, _c(240, 220, 230))
    put(img, [(5, 6), (7, 6)], _c(80, 60, 100))
    rect(img, 5, 9, 7, 12, _c(180, 160, 230))
    put(img, [(1, 5), (2, 6), (1, 7), (10, 5), (9, 6), (10, 7), (2, 8), (9, 8)], (220, 230, 255, 160))
    put(img, [(6, 1), (6, 2)], _c(255, 240, 160))
    return outline(img)


def gaia():
    """대정령 벨페르 가이아 (40x52): 나뭇잎 머리칼, 대지빛 피부, 덩굴과 꽃의 드레스, 머리 위 네 원소의 빛"""
    img = canvas(40, 52)
    leaf, leaf_d, skin = _c(90, 170, 80), _c(50, 110, 50), _c(190, 160, 120)
    dress, dress_d, flower = _c(80, 130, 70), _c(50, 90, 46), _c(240, 200, 230)
    for i, col in enumerate([(240, 90, 50), (80, 160, 240), (170, 240, 200), (170, 130, 80)]):  # 네 원소의 빛
        a = math.radians(-160 + i * 47)
        ellipse(img, 20 + 15 * math.cos(a), 12 + 10 * math.sin(a), 2, 2, _c(*col))
    ellipse(img, 20, 14, 9, 9, leaf)                 # 나뭇잎 머리칼
    for x in range(11, 30, 3):
        put(img, [(x, 22), (x + 1, 24), (x, 26)], leaf_d)
    rect(img, 16, 10, 24, 18, skin)
    put(img, [(18, 13), (22, 13)], _c(120, 240, 160))
    put(img, [(19, 16), (20, 16), (21, 16)], _c(150, 100, 80))
    for y in range(19, 51):                          # 덩굴 드레스
        half = 5 + (y - 19) * 0.45
        for x in range(int(20 - half), int(20 + half) + 1):
            img.putpixel((x, y), dress if (x * 2 + y) % 7 else dress_d)
    for x, y in ((14, 30), (25, 34), (18, 42), (28, 46), (11, 47)):
        put(img, [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], flower)
        put(img, [(x, y)], _c(255, 220, 90))
    for side in (-1, 1):                             # 팔 + 덩굴
        rect(img, 20 + side * 8, 21, 20 + side * 9, 30, skin)
        put(img, [(20 + side * 10, 31), (20 + side * 11, 33), (20 + side * 10, 35)], leaf_d)
    return outline(img, (20, 40, 20, 255))


def element_core(col, col_d):
    """정령핵 (16x18): 받침 위에 떠 있는 원소 결정"""
    img = canvas(16, 18)
    rect(img, 3, 14, 12, 17, _c(110, 104, 96))
    for y in range(13):
        w = 4 - abs(y - 6) * 0.6
        rect(img, int(7.5 - w), y, int(7.5 + w), y, col if y < 7 else col_d)
    put(img, [(6, 3), (6, 4)], _c(255, 255, 255))
    return outline(img)


def world_seed():
    """세계수의 씨앗 (16x20): 빛나는 어린 싹 — 다 자라면 가이아가 크게 회복"""
    img = canvas(16, 20)
    ellipse(img, 7.5, 16, 6, 3, _c(110, 80, 50))
    rect(img, 7, 6, 8, 15, _c(90, 160, 70))
    ellipse(img, 4.5, 6, 3, 2, _c(130, 220, 100))
    ellipse(img, 10.5, 4, 3, 2, _c(130, 220, 100))
    ellipse(img, 7.5, 2, 2, 2, _c(255, 250, 180))
    return outline(img)


def fire_spirit():
    """불꽃 정령 (14x16)"""
    img = canvas(14, 16)
    for y in range(16):
        w = max(0, 5 - abs(y - 10) * 0.6) if y > 3 else (y * 0.7)
        rect(img, int(7 - w), y, int(7 + w), y, _c(255, 120, 40) if y > 6 else _c(255, 200, 80))
    put(img, [(5, 10), (8, 10)], _c(60, 20, 10))
    return outline(img, (120, 30, 10, 255))


def water_spirit():
    """물의 정령 (14x16)"""
    img = canvas(14, 16)
    ellipse(img, 7, 9, 5.5, 6, (100, 170, 240, 220))
    ellipse(img, 7, 3, 2.5, 3, (140, 200, 250, 220))
    put(img, [(5, 8), (8, 8)], _c(20, 60, 120))
    put(img, [(4, 6), (5, 5)], _c(230, 245, 255))
    return outline(img, (30, 70, 140, 255))


def rock_spirit():
    """바위 정령 (18x16)"""
    img = canvas(18, 16)
    ellipse(img, 9, 9, 7, 6, _c(140, 120, 96))
    ellipse(img, 7, 7, 3, 2, _c(170, 150, 120))
    put(img, [(7, 9), (11, 9)], _c(255, 200, 80))
    rect(img, 2, 13, 5, 15, _c(100, 86, 70))
    rect(img, 12, 13, 15, 15, _c(100, 86, 70))
    put(img, [(6, 4), (12, 5), (9, 3)], _c(120, 200, 100))
    return outline(img)


def floor_void_lair():
    """공허의 둥지: 검보라 살갗 같은 땅 + 별빛 균열"""
    img = _floor(251, (48, 30, 56), 4, [(6, (70, 40, 84, 255), 3), (4, (180, 140, 240, 255), 1), (5, (32, 20, 40, 255), 2)])
    return img


def floor_dream():
    """꿈의 경계: 보랏빛 구름 + 반짝이는 별"""
    img = _floor(261, (70, 60, 100), 6, [(6, (96, 84, 130, 255), 4), (6, (230, 220, 255, 255), 1)])
    return img


def floor_gaia():
    """정령의 성역: 풀과 이끼 낀 돌, 작은 꽃"""
    img = _floor(271, (80, 120, 66), 6, [(6, (120, 116, 100, 255), 3), (5, (60, 96, 50, 255), 2), (4, (240, 200, 230, 255), 1)])
    return img


def save_late8_sprites():
    for name, painter in (("void_worm", void_worm), ("stomach_wall", stomach_wall), ("void_larva", void_larva),
                          ("void_apostle", void_apostle), ("rift_beast", rift_beast), ("nightmare", nightmare),
                          ("dream_imp", dream_imp), ("baku", baku), ("sleep_fairy", sleep_fairy), ("gaia", gaia),
                          ("world_seed", world_seed), ("fire_spirit", fire_spirit), ("water_spirit", water_spirit),
                          ("rock_spirit", rock_spirit)):
        save(painter(), "characters", f"{name}.png")
    for name, col, col_d in (("core_fire", (255, 110, 50), (190, 50, 30)), ("core_water", (100, 180, 250), (40, 100, 200)),
                             ("core_wind", (170, 250, 200), (90, 190, 140)), ("core_earth", (200, 150, 90), (130, 90, 50))):
        save(element_core(_c(*col), _c(*col_d)), "characters", f"{name}.png")
    save(orb((255, 240, 255), (200, 140, 255)), "projectiles", "sleep_orb.png")
    for name, painter in (("floor_void_lair", floor_void_lair), ("floor_dream", floor_dream), ("floor_gaia", floor_gaia)):
        save(painter(), "tiles", f"{name}.png")



# ---------------------------------------------------------------- 31~35스테이지 · 히든
def _poly(img, pts, col):
    from PIL import ImageDraw
    ImageDraw.Draw(img).polygon(pts, fill=col)


def _line(img, a, b, col):
    from PIL import ImageDraw
    ImageDraw.Draw(img).line([a, b], fill=col, width=1)


def _dragon(w, h, body, body_d, belly, wing, wing_d, eye, horn, wing_span=1.0, heavy=0, ox=0, oy=0):
    """오른쪽을 보는 용의 기본 몸 (꼬리 → 몸통 → 목 → 머리, 날개, 다리). 용마다 특징을 덧그림"""
    img = canvas(w, h)
    X = lambda x: x + ox
    Y = lambda y: y + oy
    if wing_span > 0:                                  # 날개 (몸 뒤)
        sx, sy = X(30), Y(27)
        tips = [(X(30 - 22 * wing_span), Y(26 - 22 * wing_span)), (X(30 - 8 * wing_span), Y(26 - 26 * wing_span)),
                (X(30 + 6 * wing_span), Y(26 - 22 * wing_span)), (X(36), Y(24))]
        _poly(img, [(sx, sy), tips[0], tips[1], tips[2], tips[3]], wing)
        for t in tips[:3]:
            _line(img, (sx, sy), t, wing_d)
        for i in range(3):                             # 날개 아래 가장자리 물결
            a, b = tips[i], tips[i + 1]
            m = ((a[0] + b[0]) // 2, (a[1] + b[1]) // 2 + 3)
            _poly(img, [a, m, b], (0, 0, 0, 0))
    for i in range(14):                                # 꼬리
        t = i / 13.0
        cx = X(4 + 18 * t)
        cy = Y(40 - 6 * math.sin(t * math.pi * 0.8) - 2 * t)
        r = 1.2 + 2.6 * t
        ellipse(img, cx, cy, r, r, body if i % 3 else body_d)
    ellipse(img, X(30), Y(34), 14 + heavy, 9 + heavy * 0.6, body)        # 몸통
    ellipse(img, X(32), Y(37 + heavy * 0.3), 9 + heavy, 4.5, belly)
    for x in (X(20), X(25), X(35), X(40)):             # 다리 + 발톱
        rect(img, x, Y(40), x + 2 + (1 if heavy else 0), Y(47), body_d)
        put(img, [(x - 1, Y(47)), (x + 3 + (1 if heavy else 0), Y(47))], _c(230, 225, 210))
    for i in range(7):                                 # 목
        t = i / 6.0
        ellipse(img, X(39 + 8 * t), Y(30 - 13 * t), 4.2 - t, 4.2 - t, body)
    ellipse(img, X(51), Y(15), 7, 5, body)              # 머리
    rect(img, X(53), Y(15), X(59), Y(18), body)        # 주둥이
    rect(img, X(53), Y(18), X(58), Y(19), body_d)
    put(img, [(X(59), Y(15)), (X(58), Y(16))], _c(40, 30, 30))   # 콧구멍
    put(img, [(X(51), Y(13)), (X(52), Y(13))], eye)
    _line(img, (X(47), Y(12)), (X(42), Y(6)), horn)    # 뿔
    _line(img, (X(48), Y(11)), (X(44), Y(4)), horn)
    return img


def zephyros():
    """바람의 드래곤 제피로스 (64x52): 비취빛 몸, 끝이 흰 깃털 날개, 몸을 감도는 바람"""
    body, body_d = _c(90, 190, 150), _c(50, 120, 100)
    img = _dragon(64, 52, body, body_d, _c(220, 245, 230), _c(150, 230, 200), _c(80, 160, 130), _c(255, 255, 200), _c(230, 240, 220), 1.15)
    for x, y in ((9, 6), (16, 2), (24, 1), (32, 5)):   # 깃털 끝
        put(img, [(x, y), (x + 1, y + 1), (x, y + 2)], _c(250, 255, 250))
    for i in range(10):                                # 바람 줄기
        a = i * 0.6
        put(img, [(int(30 + 22 * math.cos(a)), int(36 + 9 * math.sin(a)))], (220, 255, 240, 200))
    put(img, [(44, 8), (45, 7), (46, 6)], _c(200, 255, 230))   # 갈기
    return outline(img, (16, 40, 34, 255))


def terragon():
    """대지의 드래곤 테라곤 (64x52): 육중한 갈색 몸, 바위 비늘판, 수정 가시, 작은 날개"""
    body, body_d = _c(130, 100, 70), _c(84, 64, 46)
    img = _dragon(64, 52, body, body_d, _c(180, 160, 120), _c(110, 90, 70), _c(70, 56, 42), _c(255, 200, 80), _c(200, 190, 170), 0.45, heavy=3)
    for x, y in ((20, 26), (27, 23), (34, 24), (40, 27), (14, 33)):   # 바위 비늘판
        _poly(img, [(x - 3, y + 3), (x, y - 3), (x + 4, y + 2), (x + 1, y + 4)], _c(150, 140, 125))
        put(img, [(x, y - 2)], _c(190, 180, 165))
    for x, y in ((24, 21), (31, 19), (37, 21)):        # 수정 가시
        _poly(img, [(x - 1, y + 2), (x, y - 4), (x + 1, y + 2)], _c(140, 220, 200))
    return outline(img, (30, 22, 14, 255))


def coquiros():
    """얼음의 드래곤 코퀴로스 (64x52): 창백한 하늘빛 몸, 등을 따라 솟은 얼음 가시, 입가의 냉기"""
    body, body_d = _c(170, 210, 235), _c(100, 150, 190)
    img = _dragon(64, 52, body, body_d, _c(235, 245, 255), _c(190, 225, 245), _c(120, 170, 210), _c(60, 120, 255), _c(240, 250, 255), 1.0)
    for i, (x, y) in enumerate(((16, 31), (22, 26), (29, 24), (36, 25), (42, 23), (46, 17))):   # 얼음 가시
        hgt = 5 + (i % 2) * 2
        _poly(img, [(x - 2, y + 1), (x, y - hgt), (x + 2, y + 1)], (220, 245, 255, 255))
    for x, y in ((60, 18), (62, 20), (61, 22), (63, 17)):   # 냉기
        put(img, [(x, y)], (230, 250, 255, 200))
    return outline(img, (20, 40, 70, 255))


def verdan():
    """화염의 드래곤 베르단 (64x52): 진홍빛 몸, 검붉은 날개, 몸의 용암 균열, 등의 빛나는 역린"""
    body, body_d = _c(190, 50, 40), _c(120, 26, 24)
    img = _dragon(64, 52, body, body_d, _c(250, 170, 80), _c(110, 30, 30), _c(70, 16, 16), _c(255, 230, 90), _c(60, 40, 40), 1.1)
    for x, y in ((24, 34), (30, 31), (36, 35), (28, 38)):   # 용암 균열
        put(img, [(x, y), (x + 1, y + 1), (x + 2, y + 1)], _c(255, 160, 40))
    _poly(img, [(18, 30), (21, 25), (24, 30), (21, 32)], _c(255, 220, 90))   # 역린 (등 뒤쪽 = 왼쪽)
    put(img, [(21, 28)], _c(255, 255, 220))
    for x, y in ((60, 14), (62, 13), (61, 16)):          # 입가의 불씨
        put(img, [(x, y)], _c(255, 190, 60))
    return outline(img, (40, 8, 8, 255))


def helicion():
    """언데드 드래곤 헬리시온 (64x52): 뼈만 남은 몸, 갈비뼈, 찢어진 날개, 초록 영혼불"""
    bone, bone_d = _c(215, 210, 190), _c(140, 135, 120)
    img = _dragon(64, 52, _c(60, 64, 60), _c(40, 44, 40), _c(70, 80, 70), (70, 80, 72, 230), _c(160, 155, 140), _c(120, 255, 150), bone, 1.1)
    for k in range(7):                                 # 휘어진 갈비뼈
        x0 = 20 + k * 3.3
        for t in range(12):
            y = 28 + t
            x = x0 + 2.2 * math.sin(t / 11.0 * math.pi)
            if ((x - 30) / 14.0) ** 2 + ((y - 34) / 9.0) ** 2 <= 1.0:
                img.putpixel((int(x), y), bone if t < 10 else bone_d)
    rect(img, 18, 27, 43, 28, bone)                    # 등뼈
    for i in range(14):                                # 꼬리뼈
        t = i / 13.0
        put(img, [(int(4 + 18 * t), int(40 - 6 * math.sin(t * math.pi * 0.8) - 2 * t))], bone if i % 2 else bone_d)
    ellipse(img, 51, 15, 6, 4.5, bone)                 # 해골 머리
    rect(img, 53, 15, 59, 17, bone)
    rect(img, 50, 13, 52, 14, _c(30, 30, 30))
    put(img, [(51, 13)], _c(140, 255, 160))
    for x, y in ((12, 10), (20, 6), (27, 12), (16, 16)):   # 찢어진 날개 구멍
        put(img, [(x, y), (x + 1, y), (x, y + 1)], (0, 0, 0, 0))
    for x, y in ((30, 33), (33, 35), (28, 36)):        # 영혼불
        put(img, [(x, y)], _c(120, 255, 150))
    return outline(img, (14, 18, 14, 255))


def arche():
    """고대 드래곤 아르케 (72x58): 금빛이 도는 흰 비늘, 거대한 날개, 몸의 고대 룬, 네 원소의 구슬"""
    body, body_d = _c(240, 230, 200), _c(190, 165, 110)
    img = _dragon(72, 58, body, body_d, _c(255, 250, 230), _c(250, 220, 150), _c(200, 160, 90), _c(120, 220, 255), _c(255, 215, 120), 1.25, ox=4, oy=5)
    for x, y in ((28, 38), (33, 36), (38, 38), (31, 41)):    # 고대 룬
        put(img, [(x, y), (x + 1, y), (x + 1, y + 1)], _c(255, 190, 70))
    for i, col in enumerate([(170, 250, 210), (200, 150, 90), (150, 210, 255), (255, 110, 60)]):   # 네 원소
        a = math.radians(200 + i * 40)
        ellipse(img, 36 + 30 * math.cos(a) * 0.9, 30 + 26 * math.sin(a) * 0.9, 2, 2, _c(*col))
    put(img, [(55, 9), (56, 8), (57, 7)], _c(255, 230, 150))   # 왕관 같은 뿔 장식
    return outline(img, (60, 44, 20, 255))


def sylph():
    """실프 (12x16): 바람의 요정, 연둣빛 머리칼과 투명한 날개"""
    img = canvas(12, 16)
    ellipse(img, 6, 5, 2.5, 2.5, _c(240, 230, 220))
    put(img, [(4, 3), (5, 2), (7, 2), (8, 3)], _c(150, 240, 180))
    put(img, [(5, 5), (7, 5)], _c(40, 120, 90))
    for y in range(8, 15):
        rect(img, int(6 - (y - 8) * 0.4), y, int(6 + (y - 8) * 0.4), y, _c(150, 230, 190))
    put(img, [(1, 6), (2, 7), (1, 8), (10, 6), (9, 7), (10, 8)], (220, 255, 240, 170))
    return outline(img)


def storm_harpy():
    """하피 (16x16): 날개 팔의 새 인간"""
    img = canvas(16)
    ellipse(img, 8, 5, 2.5, 2.5, _c(230, 200, 170))
    put(img, [(7, 5), (9, 5)], _c(200, 40, 40))
    rect(img, 6, 8, 10, 12, _c(140, 110, 80))
    for side in (-1, 1):
        for i in range(5):
            put(img, [(8 + side * (3 + i), 7 + i // 2), (8 + side * (3 + i), 8 + i // 2)], _c(120, 90, 60) if i % 2 else _c(170, 140, 100))
    put(img, [(6, 13), (6, 14), (10, 13), (10, 14)], _c(230, 200, 80))
    return outline(img)


def storm_hawk():
    """폭풍 매 (18x12): 번개빛 날개의 큰 매"""
    img = canvas(18, 12)
    ellipse(img, 9, 7, 4, 2.5, _c(90, 100, 130))
    ellipse(img, 13, 5, 2, 2, _c(110, 120, 150))
    put(img, [(15, 5)], _c(240, 200, 60))
    put(img, [(14, 4)], _c(255, 255, 255))
    for i in range(8):
        put(img, [(8 - i, 4 - i // 3), (8 - i, 5 - i // 3)], _c(140, 160, 200) if i % 2 else _c(200, 220, 255))
    put(img, [(2, 8), (3, 8), (4, 9)], _c(70, 80, 110))
    return outline(img)


def rock_lizard():
    """바위 도마뱀 (18x10)"""
    img = canvas(18, 10)
    ellipse(img, 8, 5, 6, 2.5, _c(140, 120, 90))
    ellipse(img, 15, 4, 2.5, 2, _c(140, 120, 90))
    put(img, [(16, 3)], _c(255, 200, 60))
    for x in (4, 6, 10, 12):
        put(img, [(x, 8), (x, 9)], _c(100, 84, 62))
    put(img, [(1, 6), (2, 5)], _c(100, 84, 62))
    put(img, [(6, 3), (9, 2), (12, 3)], _c(170, 160, 140))
    return outline(img)


def crystal_sprite():
    """수정 정령 (12x16): 떠 있는 녹색 수정"""
    img = canvas(12, 16)
    _poly(img, [(6, 0), (10, 6), (6, 14), (2, 6)], _c(120, 220, 190))
    _poly(img, [(6, 0), (6, 14), (2, 6)], _c(80, 170, 150))
    put(img, [(5, 4), (5, 5)], _c(240, 255, 250))
    return outline(img)


def frost_wisp():
    """서리 정령 (12x16): 눈송이 머리의 정령"""
    img = canvas(12, 16)
    ellipse(img, 6, 9, 4, 5.5, (170, 220, 250, 220))
    for a in range(0, 360, 60):
        r = math.radians(a)
        put(img, [(int(6 + 4 * math.cos(r)), int(3 + 3 * math.sin(r)))], _c(240, 250, 255))
    put(img, [(6, 3)], _c(255, 255, 255))
    put(img, [(4, 8), (7, 8)], _c(30, 70, 140))
    return outline(img, (30, 60, 110, 255))


def glacier_turtle():
    """빙하 거북 (22x16): 얼음 바위 등껍질의 거북"""
    img = canvas(22, 16)
    ellipse(img, 10, 8, 8, 5, _c(170, 210, 230))
    for x, y in ((6, 6), (10, 4), (14, 6), (10, 8)):
        put(img, [(x, y), (x + 1, y), (x, y + 1)], _c(230, 245, 255))
    ellipse(img, 19, 9, 2.5, 2, _c(100, 140, 120))
    put(img, [(20, 8)], _c(20, 30, 30))
    for x in (5, 9, 13, 16):
        rect(img, x, 12, x + 1, 14, _c(80, 120, 100))
    return outline(img)


def ice_drake():
    """얼음 비룡 (20x14): 작은 하늘빛 비룡"""
    img = canvas(20, 14)
    ellipse(img, 9, 8, 5, 3, _c(150, 200, 235))
    ellipse(img, 15, 5, 2.5, 2, _c(150, 200, 235))
    put(img, [(16, 4)], _c(40, 90, 200))
    _poly(img, [(8, 6), (3, 0), (12, 4)], _c(200, 230, 250))
    put(img, [(2, 9), (1, 10), (3, 9)], _c(110, 160, 200))
    put(img, [(7, 11), (7, 12), (11, 11), (11, 12)], _c(110, 160, 200))
    return outline(img)


def salamander():
    """살라만더 (18x10): 불꽃을 두른 도마뱀"""
    img = canvas(18, 10)
    ellipse(img, 8, 6, 6, 2.5, _c(220, 80, 30))
    ellipse(img, 15, 5, 2.5, 2, _c(220, 80, 30))
    put(img, [(16, 4)], _c(255, 240, 120))
    for x in (5, 8, 11):
        put(img, [(x, 3), (x, 2)], _c(255, 190, 60))
    for x in (4, 6, 10, 12):
        put(img, [(x, 9)], _c(150, 40, 20))
    put(img, [(1, 7), (2, 6)], _c(150, 40, 20))
    return outline(img)


def flame_caster():
    """불꽃 술사 (14x16): 불꽃을 든 붉은 로브"""
    img = canvas(14, 16)
    for y in range(5, 16):
        half = 2.5 + (y - 5) * 0.35
        rect(img, int(7 - half), y, int(7 + half), y, _c(150, 40, 30) if y % 3 else _c(110, 26, 20))
    ellipse(img, 7, 4, 3, 3, _c(110, 26, 20))
    put(img, [(6, 4), (8, 4)], _c(255, 200, 60))
    ellipse(img, 12, 6, 1.5, 2, _c(255, 160, 40))
    put(img, [(12, 4)], _c(255, 240, 150))
    return outline(img)


def skeleton_merc():
    """해골 용병 (14x18): 녹슨 칼과 방패의 해골"""
    img = canvas(14, 18)
    bone = _c(220, 215, 195)
    ellipse(img, 7, 4, 3, 3, bone)
    put(img, [(6, 4), (8, 4)], _c(30, 30, 30))
    rect(img, 6, 8, 8, 12, bone)
    for y in (9, 11):
        put(img, [(5, y), (9, y)], bone)
    rect(img, 6, 13, 6, 17, bone)
    rect(img, 8, 13, 8, 17, bone)
    rect(img, 11, 3, 11, 11, _c(150, 110, 80))
    rect(img, 1, 8, 3, 12, _c(100, 80, 60))
    return outline(img)


def grave_ghoul():
    """구울 (16x14): 엎드려 기는 회녹색 시체귀"""
    img = canvas(16, 14)
    ellipse(img, 8, 8, 6, 3.5, _c(110, 130, 100))
    ellipse(img, 13, 6, 2.5, 2.5, _c(120, 140, 110))
    put(img, [(14, 5)], _c(255, 230, 80))
    put(img, [(14, 7), (15, 7)], _c(240, 240, 220))
    for x in (4, 7, 10, 12):
        put(img, [(x, 11), (x, 12)], _c(80, 96, 70))
    put(img, [(6, 6), (9, 7)], _c(90, 60, 60))
    return outline(img)


def grudge_soul():
    """원혼 (14x16): 사슬을 끄는 초록빛 망령"""
    img = canvas(14, 16)
    for y in range(3, 15):
        half = 3.5 - abs(y - 7) * 0.12
        rect(img, int(7 - half), y, int(7 + half), y, (120, 220, 150, 200))
    ellipse(img, 7, 4, 3.5, 3, (150, 240, 170, 230))
    put(img, [(5, 4), (8, 4)], _c(20, 40, 30))
    put(img, [(6, 6), (7, 6)], _c(20, 40, 30))
    put(img, [(2, 12), (1, 13), (2, 14), (12, 12), (13, 13)], _c(140, 140, 150))
    return outline(img, (20, 50, 30, 255))


def frost_crystal():
    """서리 결정 (14x22): 절대영도를 모으는 얼음 결정 — 체력이 따로"""
    img = canvas(14, 22)
    rect(img, 2, 18, 11, 21, _c(120, 150, 170))
    _poly(img, [(7, 0), (12, 9), (7, 18), (2, 9)], (180, 230, 255, 255))
    _poly(img, [(7, 0), (7, 18), (2, 9)], (130, 190, 240, 255))
    put(img, [(6, 4), (6, 5), (5, 7)], _c(255, 255, 255))
    return outline(img, (30, 60, 110, 255))


def dragon_soul():
    """헬리시온의 영혼 (16x16): 초록 불꽃의 용머리 혼"""
    img = canvas(16)
    ellipse(img, 8, 9, 6, 5, (110, 255, 150, 210))
    ellipse(img, 8, 9, 3.5, 3, (200, 255, 210, 240))
    for x, y in ((4, 3), (8, 1), (12, 3)):
        put(img, [(x, y), (x, y + 1), (x, y + 2)], (120, 255, 160, 200))
    put(img, [(6, 8), (10, 8)], _c(20, 60, 30))
    return outline(img, (20, 70, 30, 255))


def stone_pillar():
    """테라곤의 돌기둥 (18x28)"""
    img = canvas(18, 28)
    rect(img, 3, 4, 14, 26, _c(130, 115, 95))
    rect(img, 3, 4, 5, 26, _c(160, 145, 120))
    rect(img, 12, 4, 14, 26, _c(95, 82, 66))
    _poly(img, [(3, 4), (8, 0), (14, 4)], _c(150, 135, 110))
    for y in (10, 17, 22):
        put(img, [(6, y), (7, y), (9, y + 1), (10, y + 1)], _c(90, 78, 62))
    rect(img, 1, 25, 16, 27, _c(100, 90, 74))
    return outline(img)


def dragon_scale():
    """고대 용의 비늘 (10x10): 금빛 무지개 광택의 작은 비늘"""
    img = canvas(10)
    _poly(img, [(5, 0), (9, 4), (5, 9), (1, 4)], _c(240, 210, 120))
    _poly(img, [(5, 0), (5, 9), (1, 4)], _c(200, 160, 80))
    put(img, [(4, 3), (5, 2)], _c(255, 255, 230))
    put(img, [(6, 5)], _c(170, 230, 255))
    return outline(img, (70, 50, 20, 255))


def wind_blade():
    """바람 칼날 (10x10): 초승달 모양의 바람"""
    img = canvas(10)
    for y in range(10):
        for x in range(10):
            d1 = math.hypot(x - 4.5, y - 4.5)
            d2 = math.hypot(x - 2.5, y - 4.5)
            if d1 <= 4.6 and d2 > 4.0:
                img.putpixel((x, y), (200, 255, 230, 230))
    return img


def bone_spear():
    """뼈 창 (12x6)"""
    img = canvas(12, 6)
    rect(img, 0, 2, 9, 3, _c(220, 215, 195))
    _poly(img, [(9, 0), (11, 2), (11, 3), (9, 5)], _c(240, 235, 220))
    put(img, [(2, 1), (2, 4)], _c(180, 175, 160))
    return outline(img, (40, 40, 40, 255))


def floor_storm_canyon():
    return _floor(281, (120, 130, 120), 6, [(6, (150, 160, 150, 255), 4), (4, (90, 100, 92, 255), 2), (4, (200, 230, 210, 255), 1)])


def floor_rift_earth():
    return _floor(291, (110, 84, 60), 6, [(6, (80, 60, 42, 255), 4), (5, (140, 110, 80, 255), 2), (3, (120, 210, 190, 255), 1)])


def floor_frozen_lake():
    return _floor(301, (170, 205, 225), 5, [(6, (200, 230, 245, 255), 5), (5, (140, 180, 210, 255), 2), (4, (245, 252, 255, 255), 1)])


def floor_volcano():
    return _floor(311, (60, 40, 38), 5, [(6, (40, 26, 24, 255), 4), (5, (220, 90, 30, 255), 2), (4, (255, 180, 60, 255), 1)])


def floor_dragon_grave():
    return _floor(321, (70, 74, 66), 5, [(6, (50, 54, 48, 255), 4), (5, (200, 195, 175, 255), 2), (3, (120, 230, 150, 255), 1)])


def floor_ancient_nest():
    return _floor(331, (120, 100, 70), 5, [(6, (150, 128, 90, 255), 4), (5, (90, 74, 52, 255), 2), (4, (255, 220, 130, 255), 1)])


def save_late9_sprites():
    for name, painter in (("zephyros", zephyros), ("terragon", terragon), ("coquiros", coquiros), ("verdan", verdan),
                          ("helicion", helicion), ("arche", arche), ("sylph", sylph), ("storm_harpy", storm_harpy), ("storm_hawk", storm_hawk),
                          ("rock_lizard", rock_lizard), ("crystal_sprite", crystal_sprite), ("frost_wisp", frost_wisp),
                          ("glacier_turtle", glacier_turtle), ("ice_drake", ice_drake), ("salamander", salamander),
                          ("flame_caster", flame_caster), ("skeleton_merc", skeleton_merc), ("grave_ghoul", grave_ghoul),
                          ("grudge_soul", grudge_soul), ("frost_crystal", frost_crystal), ("dragon_soul", dragon_soul),
                          ("stone_pillar", stone_pillar)):
        save(painter(), "characters", f"{name}.png")
    save(golem((130, 105, 80), (90, 70, 52), (120, 220, 190), (220, 255, 245)), "characters", "earth_golem.png")
    save(golem((70, 50, 46), (40, 28, 26), (255, 120, 30), (255, 230, 120)), "characters", "lava_golem.png")
    save(dragon_scale(), "world", "dragon_scale.png")
    save(portal((255, 250, 220), (200, 150, 60)), "world", "portal_ancient.png")
    save(wind_blade(), "projectiles", "wind_blade.png")
    save(bone_spear(), "projectiles", "bone_spear.png")
    save(orb((210, 255, 200), (60, 110, 60)), "projectiles", "decay_orb.png")
    save(orb((255, 255, 240), (240, 190, 90)), "projectiles", "ancient_orb.png")
    for name, painter in (("floor_storm_canyon", floor_storm_canyon), ("floor_rift_earth", floor_rift_earth),
                          ("floor_frozen_lake", floor_frozen_lake), ("floor_volcano", floor_volcano),
                          ("floor_dragon_grave", floor_dragon_grave), ("floor_ancient_nest", floor_ancient_nest)):
        save(painter(), "tiles", f"{name}.png")



# ---------------------------------------------------------------- 36~37스테이지 (하늘 성채)
def seraphine():
    """심판의 천사 세라핀 (48x52): 여섯 장의 흰 날개, 금빛 후광, 흰 법의, 천칭을 든 손"""
    img = canvas(48, 52)
    wing, wing_d = _c(245, 245, 235), _c(200, 200, 190)
    for k, (dy, span) in enumerate(((10, 22), (20, 21), (30, 17))):   # 여섯 날개 (좌우 3쌍)
        for side in (-1, 1):
            tip = (24 + side * span, dy - 6)
            low = (24 + side * (span - 4), dy + 6)
            _poly(img, [(24 + side * 4, dy + 4), tip, low], wing if k % 2 == 0 else wing_d)
            _line(img, (24 + side * 4, dy + 4), tip, _c(220, 210, 170))
    ellipse(img, 24, 7, 7, 2, (255, 225, 120, 220))     # 후광
    ellipse(img, 24, 7, 5, 1.2, (0, 0, 0, 0))
    ellipse(img, 24, 12, 4, 4, _c(250, 225, 200))       # 얼굴
    rect(img, 20, 8, 28, 10, _c(250, 230, 150))         # 금발
    put(img, [(22, 12), (26, 12)], _c(120, 170, 255))
    for y in range(16, 51):                             # 법의
        half = 3 + (y - 16) * 0.3
        for x in range(int(24 - half), int(24 + half) + 1):
            img.putpixel((x, y), _c(250, 250, 245) if (x + y) % 9 else _c(225, 215, 180))
    rect(img, 23, 18, 25, 48, _c(240, 200, 90))         # 금빛 띠
    _line(img, (34, 22), (42, 22), _c(240, 200, 90))    # 천칭
    _line(img, (38, 18), (38, 22), _c(240, 200, 90))
    put(img, [(34, 24), (35, 25), (33, 25), (42, 24), (41, 25), (43, 25)], _c(255, 220, 110))
    return outline(img, (90, 80, 50, 255))


def astaroth():
    """타락한 신 아스타로트 (48x56): 부러진 검은 후광, 뒤틀린 뿔, 검보라 옷, 붉게 빛나는 눈, 찢어진 날개"""
    img = canvas(48, 56)
    robe, robe_d, skin = _c(60, 30, 70), _c(34, 16, 42), _c(150, 130, 150)
    for side in (-1, 1):                                # 찢어진 검은 날개
        _poly(img, [(24 + side * 5, 22), (24 + side * 23, 6), (24 + side * 20, 24), (24 + side * 22, 34), (24 + side * 8, 30)], _c(40, 26, 46))
        for i in range(3):
            put(img, [(24 + side * (14 + i * 3), 18 + i * 4)], (0, 0, 0, 0))
    _line(img, (14, 6), (20, 3), _c(80, 70, 60))        # 부러진 후광
    _line(img, (28, 3), (34, 6), _c(80, 70, 60))
    ellipse(img, 24, 14, 5, 5, skin)                    # 얼굴
    put(img, [(22, 13), (26, 13)], _c(255, 50, 60))
    rect(img, 22, 17, 26, 17, _c(80, 30, 40))
    for side in (-1, 1):                                # 뒤틀린 뿔
        put(img, [(24 + side * 4, 9), (24 + side * 6, 7), (24 + side * 7, 5), (24 + side * 6, 3), (24 + side * 8, 2)], _c(200, 190, 170))
    for y in range(19, 55):                             # 옷
        half = 4 + (y - 19) * 0.38
        for x in range(int(24 - half), int(24 + half) + 1):
            img.putpixel((x, y), robe if (x * 3 + y) % 8 else robe_d)
    for x, y in ((20, 30), (28, 36), (22, 44), (30, 48)):   # 금 간 성문(聖紋)
        put(img, [(x, y), (x + 1, y + 1)], _c(200, 150, 60))
    for side in (-1, 1):                                # 팔
        rect(img, 24 + side * 9, 22, 24 + side * 10, 34, skin)
        put(img, [(24 + side * 10, 35), (24 + side * 11, 36)], _c(180, 40, 60))
    return outline(img, (16, 6, 20, 255))


def faith_statue():
    """아스타로트의 신상 (16x30): 기도하는 모습의 검은 석상, 붉은 눈"""
    img = canvas(16, 30)
    rect(img, 2, 25, 13, 29, _c(90, 80, 90))
    for y in range(8, 25):
        half = 3 + (y - 8) * 0.18
        rect(img, int(7.5 - half), y, int(7.5 + half), y, _c(110, 96, 110) if y % 4 else _c(80, 70, 84))
    ellipse(img, 7.5, 5, 3, 3.5, _c(120, 106, 120))
    put(img, [(6, 5), (9, 5)], _c(255, 60, 80))
    put(img, [(7, 12), (8, 12), (7, 13), (8, 13)], _c(150, 136, 150))   # 모은 손
    return outline(img)


def angel_soldier():
    """천사 병사 (14x18): 흰 갑옷, 작은 날개, 창"""
    img = canvas(14, 18)
    put(img, [(2, 6), (1, 7), (2, 8), (11, 6), (12, 7), (11, 8)], _c(240, 240, 230))
    ellipse(img, 7, 4, 2.5, 2.5, _c(245, 220, 190))
    rect(img, 5, 1, 9, 2, _c(230, 200, 100))
    rect(img, 5, 7, 9, 13, _c(220, 225, 235))
    rect(img, 5, 14, 6, 17, _c(180, 185, 200))
    rect(img, 8, 14, 9, 17, _c(180, 185, 200))
    rect(img, 12, 2, 12, 15, _c(200, 170, 90))
    put(img, [(12, 1), (11, 2), (13, 2)], _c(240, 240, 250))
    return outline(img)


def ophanim():
    """오파님 (16x16): 눈이 박힌 불타는 금빛 바퀴"""
    img = canvas(16)
    for a in range(0, 360, 12):
        r = math.radians(a)
        put(img, [(int(round(7.5 + 6.5 * math.cos(r))), int(round(7.5 + 6.5 * math.sin(r))))], _c(250, 210, 90))
    for a in range(0, 360, 90):
        r = math.radians(a + 45)
        x, y = int(round(7.5 + 4 * math.cos(r))), int(round(7.5 + 4 * math.sin(r)))
        put(img, [(x, y)], _c(255, 255, 255))
        put(img, [(x, y + 1)], _c(60, 120, 220))
    ellipse(img, 7.5, 7.5, 1.8, 1.8, _c(255, 245, 200))
    return outline(img, (110, 80, 20, 255))


def choir_doll():
    """성가대 인형 (12x16): 입을 벌린 하얀 인형"""
    img = canvas(12, 16)
    ellipse(img, 6, 5, 3.5, 3.5, _c(240, 235, 225))
    put(img, [(4, 4), (8, 4)], _c(40, 40, 50))
    ellipse(img, 6, 7, 1, 1.2, _c(60, 30, 40))
    for y in range(9, 16):
        half = 2 + (y - 9) * 0.4
        rect(img, int(6 - half), y, int(6 + half), y, _c(230, 225, 210) if y % 2 else _c(200, 180, 120))
    return outline(img)


def fanatic():
    """광신도 (14x18): 두건 쓴 검붉은 옷의 신도, 단검"""
    img = canvas(14, 18)
    for y in range(3, 18):
        half = 2.5 + (y - 3) * 0.25
        rect(img, int(7 - half), y, int(7 + half), y, _c(110, 30, 40) if y % 3 else _c(80, 20, 28))
    ellipse(img, 7, 4, 3, 3, _c(80, 20, 28))
    put(img, [(6, 5), (8, 5)], _c(255, 230, 120))
    rect(img, 11, 8, 11, 12, _c(200, 200, 210))
    return outline(img)


def fallen_priest():
    """타락 사제 (14x18): 검보라 법의, 뒤집힌 성표"""
    img = canvas(14, 18)
    for y in range(5, 18):
        half = 2.5 + (y - 5) * 0.32
        rect(img, int(7 - half), y, int(7 + half), y, _c(70, 40, 90) if y % 3 else _c(46, 24, 60))
    ellipse(img, 7, 4, 3, 3, _c(170, 150, 160))
    rect(img, 4, 1, 10, 2, _c(46, 24, 60))
    put(img, [(6, 4), (8, 4)], _c(200, 60, 200))
    rect(img, 7, 9, 7, 14, _c(200, 160, 70))
    rect(img, 5, 12, 9, 12, _c(200, 160, 70))
    return outline(img)


def broken_angel():
    """날개 꺾인 천사 (18x14): 꺾인 검은 날개로 기어 다니는 타락 천사"""
    img = canvas(18, 14)
    ellipse(img, 9, 9, 5, 3, _c(150, 140, 150))
    ellipse(img, 14, 7, 2.5, 2.5, _c(200, 190, 190))
    put(img, [(15, 6)], _c(255, 60, 80))
    _poly(img, [(8, 7), (3, 1), (6, 8)], _c(60, 50, 64))
    _poly(img, [(10, 7), (12, 0), (11, 8)], _c(80, 70, 84))
    for x in (5, 8, 11):
        put(img, [(x, 12), (x, 13)], _c(110, 100, 110))
    return outline(img)


def floor_heaven_court():
    return _floor(341, (220, 215, 200), 5, [(6, (245, 240, 225, 255), 5), (5, (200, 190, 160, 255), 2), (4, (255, 225, 140, 255), 1)])


def floor_fallen_temple():
    return _floor(351, (66, 50, 66), 5, [(6, (46, 34, 48, 255), 4), (5, (120, 60, 80, 255), 2), (3, (200, 150, 70, 255), 1)])


def save_late10_sprites():
    for name, painter in (("seraphine", seraphine), ("astaroth", astaroth), ("faith_statue", faith_statue),
                          ("angel_soldier", angel_soldier), ("ophanim", ophanim), ("choir_doll", choir_doll),
                          ("fanatic", fanatic), ("fallen_priest", fallen_priest), ("broken_angel", broken_angel)):
        save(painter(), "characters", f"{name}.png")
    save(orb((255, 255, 240), (255, 210, 110)), "projectiles", "holy_orb.png")
    save(orb((240, 160, 240), (90, 20, 80)), "projectiles", "corrupt_orb.png")
    for name, painter in (("floor_heaven_court", floor_heaven_court), ("floor_fallen_temple", floor_fallen_temple)):
        save(painter(), "tiles", f"{name}.png")



# ---------------------------------------------------------------- 38~40스테이지 (올림포스로 가는 길)
def talos():
    """청동 거인 탈로스 (44x56): 청동 몸, 가슴의 리벳, 투구 같은 머리, 발목의 못 자리"""
    img = canvas(44, 56)
    br, br_d, br_l = _c(190, 130, 60), _c(120, 76, 34), _c(235, 180, 100)
    rect(img, 14, 40, 19, 54, br_d)                    # 다리
    rect(img, 25, 40, 30, 54, br_d)
    rect(img, 12, 52, 20, 55, br)
    rect(img, 24, 52, 32, 55, br)
    ellipse(img, 22, 30, 12, 12, br)                   # 몸통
    ellipse(img, 19, 26, 5, 5, br_l)
    for x, y in ((14, 24), (30, 24), (16, 36), (28, 36), (22, 20)):   # 리벳
        put(img, [(x, y)], _c(250, 220, 150))
    rect(img, 4, 20, 9, 38, br_d)                      # 팔
    rect(img, 35, 20, 40, 38, br_d)
    ellipse(img, 6, 40, 3.5, 3, br)
    ellipse(img, 38, 40, 3.5, 3, br)
    ellipse(img, 22, 11, 7, 7, br)                     # 머리 (투구)
    rect(img, 15, 10, 29, 12, br_d)
    put(img, [(19, 11), (25, 11)], _c(255, 160, 60))
    rect(img, 21, 2, 23, 5, _c(200, 60, 40))           # 볏
    put(img, [(17, 52), (18, 53)], _c(120, 120, 130))  # 발목 (못 자리)
    return outline(img, (50, 30, 10, 255))


def bronze_nail():
    """탈로스 발목의 청동 못 (10x12)"""
    img = canvas(10, 12)
    ellipse(img, 4.5, 2.5, 4, 2, _c(240, 200, 110))
    rect(img, 3, 3, 6, 11, _c(190, 140, 70))
    put(img, [(4, 4), (4, 5)], _c(255, 240, 180))
    return outline(img, (60, 36, 10, 255))


def minotaur():
    """미궁의 미노타우로스 (44x50): 황소 머리, 커다란 뿔, 근육질 몸, 양날 도끼"""
    img = canvas(44, 50)
    fur, fur_d, skin = _c(110, 70, 50), _c(70, 44, 30), _c(160, 110, 80)
    rect(img, 15, 36, 20, 48, fur_d)                   # 다리 (털)
    rect(img, 24, 36, 29, 48, fur_d)
    put(img, [(15, 48), (16, 49), (20, 48), (24, 48), (28, 49), (29, 48)], _c(40, 30, 26))   # 발굽
    ellipse(img, 22, 27, 11, 11, skin)                 # 몸
    rect(img, 15, 34, 29, 37, _c(150, 40, 40))         # 허리천
    rect(img, 7, 18, 11, 32, skin)                     # 팔
    rect(img, 33, 18, 37, 32, skin)
    ellipse(img, 22, 12, 7, 7, fur)                    # 황소 머리
    ellipse(img, 22, 16, 4, 3, _c(170, 130, 110))      # 주둥이
    put(img, [(21, 16), (23, 16)], _c(40, 20, 20))
    put(img, [(19, 10), (25, 10)], _c(255, 60, 40))
    for side in (-1, 1):                               # 뿔
        put(img, [(22 + side * 7, 8), (22 + side * 9, 7), (22 + side * 11, 5), (22 + side * 12, 3), (22 + side * 12, 2)], _c(235, 225, 200))
        put(img, [(22 + side * 8, 8), (22 + side * 10, 6)], _c(235, 225, 200))
    rect(img, 39, 8, 40, 40, _c(110, 80, 50))          # 도끼 자루
    _poly(img, [(40, 10), (43, 6), (43, 18), (40, 14)], _c(200, 200, 210))
    _poly(img, [(39, 10), (36, 6), (36, 18), (39, 14)], _c(170, 170, 185))
    return outline(img, (30, 16, 10, 255))


def hermes():
    """전령의 신 헤르메스 (32x46): 날개 달린 모자(페타소스), 날개 신발, 뱀 지팡이(카두케우스), 흰 망토"""
    img = canvas(32, 46)
    skin, cloak = _c(240, 205, 170), _c(240, 240, 235)
    ellipse(img, 16, 10, 5, 5, skin)                   # 얼굴
    ellipse(img, 16, 5, 7, 2.5, _c(200, 170, 90))      # 페타소스
    for side in (-1, 1):
        put(img, [(16 + side * 7, 4), (16 + side * 9, 3), (16 + side * 10, 2), (16 + side * 8, 3)], _c(255, 255, 255))
    put(img, [(14, 10), (18, 10)], _c(60, 120, 200))
    for y in range(16, 38):                            # 망토 + 튜닉
        half = 4 + (y - 16) * 0.25
        for x in range(int(16 - half), int(16 + half) + 1):
            img.putpixel((x, y), cloak if (x + y) % 7 else _c(210, 210, 200))
    rect(img, 13, 18, 19, 30, _c(90, 140, 200))
    rect(img, 13, 38, 14, 43, skin)                    # 다리
    rect(img, 18, 38, 19, 43, skin)
    for x in (12, 18):                                 # 날개 신발
        rect(img, x, 43, x + 3, 45, _c(200, 170, 90))
        put(img, [(x - 1, 41), (x - 2, 42), (x - 1, 43)], _c(255, 255, 255))
    rect(img, 26, 8, 26, 40, _c(230, 200, 100))        # 카두케우스
    put(img, [(25, 7), (27, 7), (24, 6), (28, 6)], _c(255, 255, 255))
    for i in range(6):
        put(img, [(25 + (i % 2) * 2, 12 + i * 4), (26, 14 + i * 4)], _c(90, 170, 90))
    return outline(img, (40, 40, 60, 255))


def letter():
    """전령의 편지 (12x10): 날개 달린 봉인 편지"""
    img = canvas(12, 10)
    rect(img, 2, 3, 9, 8, _c(245, 235, 210))
    _line(img, (2, 3), (5, 6), _c(200, 180, 150))
    _line(img, (9, 3), (6, 6), _c(200, 180, 150))
    put(img, [(5, 6), (6, 6)], _c(200, 40, 40))
    put(img, [(0, 2), (1, 3), (11, 2), (10, 3)], _c(255, 255, 255))
    return outline(img)


def bronze_soldier():
    """청동 병사 (14x18)"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(190, 130, 60))
    rect(img, 6, 1, 8, 1, _c(200, 60, 40))
    put(img, [(6, 4), (8, 4)], _c(255, 160, 60))
    rect(img, 4, 8, 10, 13, _c(170, 115, 50))
    rect(img, 5, 14, 6, 17, _c(120, 76, 34))
    rect(img, 8, 14, 9, 17, _c(120, 76, 34))
    rect(img, 12, 3, 12, 14, _c(200, 200, 210))
    ellipse(img, 2, 10, 2, 3, _c(220, 170, 90))
    return outline(img)


def rock_crab():
    """바위 게 (18x12)"""
    img = canvas(18, 12)
    ellipse(img, 9, 6, 6, 4, _c(130, 110, 100))
    put(img, [(7, 3), (11, 3)], _c(30, 30, 30))
    for side in (-1, 1):
        ellipse(img, 9 + side * 7.5, 3, 2, 2, _c(200, 100, 70))
        for i in range(3):
            put(img, [(9 + side * (4 + i), 9 + i // 2), (9 + side * (4 + i), 10)], _c(100, 84, 76))
    return outline(img)


def bronze_archer():
    """청동 사수 (14x18): 투석 팔을 단 청동 자동인형"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(170, 120, 60))
    put(img, [(7, 4)], _c(255, 90, 40))
    rect(img, 4, 8, 10, 14, _c(150, 100, 45))
    rect(img, 10, 6, 13, 7, _c(120, 80, 35))
    ellipse(img, 12, 5, 1.5, 1.5, _c(130, 120, 110))
    rect(img, 5, 15, 9, 17, _c(110, 70, 30))
    return outline(img)


def bull_warrior():
    """황소 전사 (14x18): 황소 투구의 전사"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(160, 110, 80))
    put(img, [(3, 2), (2, 1), (11, 2), (12, 1)], _c(235, 225, 200))
    put(img, [(6, 4), (8, 4)], _c(255, 60, 40))
    rect(img, 4, 8, 10, 13, _c(130, 50, 40))
    rect(img, 5, 14, 6, 17, _c(90, 60, 40))
    rect(img, 8, 14, 9, 17, _c(90, 60, 40))
    rect(img, 12, 4, 12, 14, _c(110, 80, 50))
    return outline(img)


def maze_guardian():
    """미궁 파수꾼 (20x20): 미궁 돌로 된 거대한 석상 병사"""
    img = golem((130, 120, 105), (90, 82, 70), (240, 200, 90), (255, 240, 180))
    return img


def maze_wraith():
    """미궁 망령 (14x16): 미궁에서 길 잃은 희생자의 망령"""
    img = canvas(14, 16)
    for y in range(3, 15):
        half = 3.5 - abs(y - 7) * 0.12
        rect(img, int(7 - half), y, int(7 + half), y, (200, 190, 160, 190))
    ellipse(img, 7, 4, 3, 3, (220, 210, 180, 220))
    put(img, [(5, 4), (8, 4)], _c(60, 40, 20))
    put(img, [(2, 12), (12, 12), (1, 14)], _c(230, 200, 100))
    return outline(img, (60, 50, 30, 255))


def satyr():
    """사티로스 (14x18): 염소 다리와 뿔, 피리"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(220, 180, 140))
    put(img, [(4, 1), (4, 2), (10, 1), (10, 2)], _c(200, 190, 170))
    put(img, [(6, 4), (8, 4)], _c(60, 40, 20))
    rect(img, 5, 8, 9, 11, _c(220, 180, 140))
    rect(img, 4, 12, 10, 14, _c(120, 80, 50))
    rect(img, 4, 15, 5, 17, _c(100, 66, 40))
    rect(img, 9, 15, 10, 17, _c(100, 66, 40))
    rect(img, 10, 6, 13, 7, _c(170, 140, 80))
    return outline(img)


def nymph():
    """님프 (12x16): 나뭇잎 옷의 숲의 정령"""
    img = canvas(12, 16)
    ellipse(img, 6, 4, 2.5, 2.5, _c(230, 220, 200))
    rect(img, 3, 2, 9, 3, _c(120, 200, 110))
    put(img, [(5, 4), (7, 4)], _c(40, 120, 60))
    for y in range(7, 16):
        half = 1.5 + (y - 7) * 0.4
        rect(img, int(6 - half), y, int(6 + half), y, _c(120, 200, 120) if y % 2 else _c(90, 170, 100))
    return outline(img)


def pegasus():
    """페가수스 (20x16): 흰 날개 말"""
    img = canvas(20, 16)
    ellipse(img, 9, 9, 6, 3.5, _c(245, 245, 250))
    ellipse(img, 16, 5, 2.5, 2.5, _c(245, 245, 250))
    put(img, [(17, 4)], _c(60, 80, 160))
    put(img, [(14, 3), (13, 4), (12, 5)], _c(200, 220, 255))
    _poly(img, [(8, 7), (3, 0), (12, 5)], _c(230, 240, 255))
    for x in (5, 8, 11, 13):
        rect(img, x, 12, x, 15, _c(210, 210, 220))
    put(img, [(2, 9), (1, 10), (2, 11)], _c(200, 220, 255))
    return outline(img)


def floor_bronze_coast():
    return _floor(361, (200, 180, 130), 6, [(6, (220, 200, 150, 255), 4), (5, (160, 140, 100, 255), 2), (4, (210, 150, 80, 255), 1)])


def floor_labyrinth():
    return _floor(371, (120, 108, 92), 5, [(6, (140, 128, 110, 255), 5), (5, (90, 80, 68, 255), 2), (3, (200, 170, 90, 255), 1)])


def floor_cloud_road():
    return _floor(381, (215, 225, 240), 5, [(6, (240, 245, 255, 255), 5), (5, (190, 200, 225, 255), 2), (4, (255, 230, 150, 255), 1)])


def save_late11_sprites():
    for name, painter in (("talos", talos), ("bronze_nail", bronze_nail), ("minotaur", minotaur), ("hermes", hermes), ("letter", letter),
                          ("bronze_soldier", bronze_soldier), ("rock_crab", rock_crab), ("bronze_archer", bronze_archer),
                          ("bull_warrior", bull_warrior), ("maze_guardian", maze_guardian), ("maze_wraith", maze_wraith),
                          ("satyr", satyr), ("nymph", nymph), ("pegasus", pegasus)):
        save(painter(), "characters", f"{name}.png")
    save(orb((210, 255, 200), (60, 150, 80)), "projectiles", "snake_orb.png")
    for name, painter in (("floor_bronze_coast", floor_bronze_coast), ("floor_labyrinth", floor_labyrinth), ("floor_cloud_road", floor_cloud_road)):
        save(painter(), "tiles", f"{name}.png")



# ---------------------------------------------------------------- 41스테이지 (레르나의 늪)
def hydra():
    """머리 아홉의 히드라 몸통 (52x40): 늪빛 비늘의 거대한 몸, 목이 돋는 어깨 (머리는 따로)"""
    img = canvas(52, 40)
    sc, sc_d, belly = _c(70, 120, 80), _c(40, 80, 50), _c(170, 190, 120)
    for i in range(14):                                # 꼬리
        t = i / 13.0
        ellipse(img, 4 + 14 * t, 32 - 3 * math.sin(t * 3), 1.5 + 2.5 * t, 1.5 + 2.5 * t, sc if i % 3 else sc_d)
    ellipse(img, 28, 26, 17, 11, sc)                   # 몸통
    ellipse(img, 30, 30, 11, 5, belly)
    for x in range(16, 42, 4):                         # 등 비늘
        put(img, [(x, 16), (x + 1, 15)], sc_d)
    for x in (18, 24, 34, 40):                         # 다리
        rect(img, x, 34, x + 2, 39, sc_d)
    for k in range(5):                                 # 목이 돋는 어깨 (목 밑동)
        cx = 18 + k * 6
        ellipse(img, cx, 14, 3, 3, sc)
    return outline(img, (16, 36, 20, 255))


def hydra_head():
    """히드라의 머리 (16x16): 독니를 드러낸 뱀 머리 + 목 일부"""
    img = canvas(16)
    sc, sc_d = _c(80, 140, 90), _c(44, 90, 56)
    rect(img, 6, 9, 9, 15, sc_d)                       # 목
    ellipse(img, 8, 6, 6, 4.5, sc)
    rect(img, 9, 7, 14, 9, sc)                         # 주둥이
    put(img, [(10, 10), (13, 10)], _c(250, 250, 230))  # 독니
    put(img, [(8, 4), (9, 4)], _c(255, 230, 60))
    put(img, [(4, 2), (5, 1), (7, 1)], _c(200, 220, 140))   # 볏
    return outline(img, (16, 36, 20, 255))


def hydra_stump():
    """잘린 히드라의 목 (12x12): 꿈틀거리는 붉은 단면"""
    img = canvas(12, 12)
    rect(img, 3, 4, 8, 11, _c(44, 90, 56))
    ellipse(img, 5.5, 4, 3.5, 2.5, _c(200, 60, 60))
    ellipse(img, 5.5, 4, 2, 1.2, _c(240, 130, 110))
    return outline(img, (40, 16, 16, 255))


def brazier(lit):
    """성화대 (14x24): 돌 받침 위의 화로 — 불이 붙었으면 불꽃"""
    img = canvas(14, 24)
    rect(img, 5, 12, 8, 21, _c(120, 110, 100))
    rect(img, 3, 21, 10, 23, _c(100, 92, 84))
    ellipse(img, 6.5, 11, 6, 3, _c(90, 70, 50))
    if lit:
        for y in range(1, 11):
            w = (10 - y) * 0.45
            rect(img, int(6.5 - w), y, int(6.5 + w), y, _c(255, 160, 40) if y > 5 else _c(255, 230, 120))
    else:
        put(img, [(5, 9), (7, 8), (8, 9)], _c(60, 60, 60))
    return outline(img)


def swamp_snake():
    """늪 뱀 (18x10)"""
    img = canvas(18, 10)
    for i in range(14):
        x = 2 + i
        y = 5 + int(round(2 * math.sin(i * 0.8)))
        rect(img, x, y - 1, x, y + 1, _c(90, 130, 70) if i % 3 else _c(60, 90, 50))
    put(img, [(15, 4)], _c(255, 230, 60))
    put(img, [(17, 5)], _c(200, 40, 40))
    return outline(img)


def hydra_spawn():
    """히드라 새끼 (16x14): 머리 둘 달린 작은 독룡"""
    img = canvas(16, 14)
    ellipse(img, 7, 9, 5, 3.5, _c(80, 140, 90))
    for dx in (0, 4):
        rect(img, 9 + dx // 2, 4, 10 + dx // 2, 7, _c(60, 110, 70))
        ellipse(img, 11 + dx // 2, 3, 2, 1.8, _c(90, 150, 100))
        put(img, [(12 + dx // 2, 2)], _c(255, 230, 60))
    for x in (4, 8):
        put(img, [(x, 12), (x, 13)], _c(44, 90, 56))
    return outline(img)


def swamp_shaman():
    """늪지 주술사 (14x18): 이끼 로브의 리자드맨 주술사"""
    img = canvas(14, 18)
    for y in range(6, 18):
        half = 2.5 + (y - 6) * 0.3
        rect(img, int(7 - half), y, int(7 + half), y, _c(70, 90, 50) if y % 3 else _c(50, 66, 36))
    ellipse(img, 7, 4, 3, 3, _c(110, 150, 90))
    rect(img, 8, 4, 11, 5, _c(110, 150, 90))
    put(img, [(7, 3)], _c(255, 220, 60))
    rect(img, 2, 3, 2, 16, _c(110, 80, 50))
    put(img, [(1, 2), (2, 1), (3, 2)], _c(140, 220, 120))
    return outline(img)


def floor_lerna_swamp():
    return _floor(391, (70, 90, 60), 5, [(6, (50, 70, 44, 255), 4), (5, (100, 120, 70, 255), 2), (4, (150, 200, 110, 255), 1)])


def save_late12_sprites():
    for name, painter in (("hydra", hydra), ("hydra_head", hydra_head), ("hydra_stump", hydra_stump),
                          ("swamp_snake", swamp_snake), ("hydra_spawn", hydra_spawn), ("swamp_shaman", swamp_shaman)):
        save(painter(), "characters", f"{name}.png")
    save(brazier(True), "world", "brazier_lit.png")
    save(brazier(False), "world", "brazier_out.png")
    save(floor_lerna_swamp(), "tiles", "floor_lerna_swamp.png")



# ---------------------------------------------------------------- 42~45스테이지 (괴물들의 바다·동굴·사막)
def polyphemus():
    """외눈 거인 폴리페모스 (44x56): 털가죽 옷, 큰 몸, 이마의 눈 자리(눈은 따로), 몽둥이"""
    img = canvas(44, 56)
    skin, skin_d, fur = _c(200, 160, 120), _c(150, 110, 80), _c(120, 90, 60)
    rect(img, 13, 40, 19, 54, skin_d)
    rect(img, 25, 40, 31, 54, skin_d)
    ellipse(img, 22, 30, 13, 12, skin)
    rect(img, 9, 32, 35, 42, fur)                      # 털가죽 허리
    for x in range(10, 35, 3):
        put(img, [(x, 42), (x + 1, 43)], _c(90, 66, 44))
    rect(img, 3, 20, 8, 36, skin_d)                    # 팔
    rect(img, 36, 20, 41, 36, skin_d)
    rect(img, 39, 4, 42, 36, _c(110, 80, 50))          # 몽둥이
    ellipse(img, 40.5, 6, 3, 4, _c(130, 96, 60))
    ellipse(img, 22, 11, 8, 8, skin)                   # 머리
    rect(img, 16, 3, 28, 5, _c(90, 60, 40))            # 머리털
    ellipse(img, 22, 10, 3.5, 3, _c(90, 60, 50))       # 눈구멍 (눈은 BossPart)
    rect(img, 19, 15, 25, 16, _c(120, 50, 40))         # 입
    return outline(img, (50, 30, 16, 255))


def cyclops_eye():
    """폴리페모스의 외눈 (12x10)"""
    img = canvas(12, 10)
    ellipse(img, 5.5, 4.5, 5, 4, _c(245, 240, 230))
    ellipse(img, 5.5, 4.5, 2.5, 2.5, _c(200, 120, 40))
    ellipse(img, 5.5, 4.5, 1.2, 1.2, _c(20, 10, 10))
    put(img, [(4, 3)], _c(255, 255, 255))
    return outline(img, (60, 20, 20, 255))


def sheep():
    """양 (16x12)"""
    img = canvas(16, 12)
    for x, y in ((5, 5), (8, 4), (11, 5), (6, 7), (10, 7), (8, 6)):
        ellipse(img, x, y, 3, 2.5, _c(240, 238, 228))
    ellipse(img, 13.5, 5, 2, 2, _c(60, 56, 50))
    put(img, [(14, 4)], _c(255, 255, 255))
    for x in (5, 7, 10, 12):
        rect(img, x, 9, x, 11, _c(60, 56, 50))
    return outline(img, (90, 86, 80, 255))


def young_cyclops():
    """어린 키클롭스 (20x20)"""
    img = canvas(20)
    ellipse(img, 10, 12, 6, 6, _c(190, 150, 110))
    ellipse(img, 10, 5, 4, 4, _c(200, 160, 120))
    ellipse(img, 10, 5, 1.6, 1.6, _c(250, 250, 240))
    put(img, [(10, 5)], _c(30, 20, 10))
    rect(img, 6, 15, 14, 17, _c(120, 90, 60))
    rect(img, 7, 18, 8, 19, _c(150, 110, 80))
    rect(img, 12, 18, 13, 19, _c(150, 110, 80))
    rect(img, 16, 6, 17, 16, _c(110, 80, 50))
    return outline(img)


def cave_wolf():
    """동굴 늑대 (18x12)"""
    img = canvas(18, 12)
    ellipse(img, 8, 6, 6, 3, _c(90, 86, 90))
    ellipse(img, 14, 4, 2.5, 2, _c(100, 96, 100))
    put(img, [(15, 3)], _c(255, 220, 80))
    put(img, [(13, 1), (14, 1)], _c(80, 76, 80))
    for x in (4, 7, 10, 12):
        rect(img, x, 9, x, 11, _c(70, 66, 70))
    put(img, [(1, 5), (2, 5), (2, 4)], _c(80, 76, 80))
    return outline(img)


def cyclops_slinger():
    """키클롭스 투석병 (14x18)"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(200, 160, 120))
    ellipse(img, 7, 4, 1.2, 1.2, _c(250, 250, 240))
    rect(img, 4, 8, 10, 13, _c(130, 100, 70))
    rect(img, 5, 14, 6, 17, _c(150, 110, 80))
    rect(img, 8, 14, 9, 17, _c(150, 110, 80))
    put(img, [(11, 6), (12, 5), (13, 4)], _c(110, 80, 50))
    ellipse(img, 12.5, 3, 1.5, 1.5, _c(130, 120, 110))
    return outline(img)


def cerberus():
    """케르베로스 몸통 (48x38): 거대한 검은 개의 몸 (머리는 따로), 뱀 꼬리"""
    img = canvas(48, 38)
    fur, fur_d = _c(50, 40, 46), _c(30, 24, 28)
    ellipse(img, 24, 22, 16, 9, fur)
    for x in (12, 18, 30, 36):                          # 다리
        rect(img, x, 28, x + 3, 36, fur_d)
        put(img, [(x, 36), (x + 3, 36)], _c(200, 190, 170))
    for k in range(3):                                  # 목 세 개
        rect(img, 15 + k * 8, 8, 19 + k * 8, 16, fur)
    for i in range(10):                                 # 뱀 꼬리
        put(img, [(7 - i // 2, 20 - i), (6 - i // 2, 20 - i)], _c(70, 110, 60))
    put(img, [(2, 10)], _c(255, 230, 60))
    for x in range(14, 36, 4):
        put(img, [(x, 15), (x + 1, 16)], _c(120, 40, 40))
    return outline(img, (12, 6, 10, 255))


def cerberus_head(col, eye):
    """케르베로스의 머리 (16x14): 속성 빛이 도는 개 머리"""
    img = canvas(16, 14)
    fur = _c(54, 44, 50)
    ellipse(img, 8, 7, 6, 5, fur)
    rect(img, 9, 7, 15, 10, fur)
    put(img, [(14, 7)], _c(20, 20, 20))
    put(img, [(10, 11), (13, 11)], _c(240, 240, 230))
    put(img, [(7, 5), (8, 5)], eye)
    put(img, [(3, 1), (4, 2), (5, 1)], fur)
    for x, y in ((4, 9), (6, 11), (9, 12)):
        put(img, [(x, y)], col)
    return outline(img, (12, 6, 10, 255))


def lyre():
    """오르페우스의 리라 (14x20)"""
    img = canvas(14, 20)
    for side in (-1, 1):
        for i in range(12):
            put(img, [(int(7 + side * (2 + 3 * math.sin(i / 11 * math.pi))), 3 + i)], _c(230, 190, 90))
    rect(img, 3, 3, 11, 4, _c(210, 170, 80))
    for x in (5, 7, 9):
        rect(img, x, 5, x, 14, (250, 245, 220, 200))
    rect(img, 4, 15, 10, 16, _c(200, 160, 70))
    rect(img, 6, 17, 8, 19, _c(150, 120, 60))
    return outline(img, (80, 60, 20, 255))


def underworld_hound():
    """명계 개 (18x12)"""
    img = canvas(18, 12)
    ellipse(img, 8, 6, 6, 3, _c(50, 40, 46))
    ellipse(img, 14, 4, 2.5, 2, _c(60, 50, 56))
    put(img, [(15, 3)], _c(255, 90, 60))
    for x in (4, 7, 10, 12):
        rect(img, x, 9, x, 11, _c(30, 24, 28))
    put(img, [(5, 3), (8, 3), (11, 3)], _c(255, 120, 60))
    return outline(img)


def shade_soldier():
    """망령 병사 (14x18)"""
    img = canvas(14, 18)
    for y in range(3, 18):
        half = 2.5 + (y - 3) * 0.2
        rect(img, int(7 - half), y, int(7 + half), y, (90, 110, 130, 200))
    ellipse(img, 7, 4, 3, 3, (130, 150, 170, 220))
    put(img, [(6, 4), (8, 4)], _c(150, 230, 255))
    rect(img, 11, 3, 11, 14, _c(160, 170, 180))
    return outline(img, (20, 30, 40, 255))


def charon_shade():
    """카론의 망령 (14x18): 노를 든 두건의 뱃사공 망령"""
    img = canvas(14, 18)
    for y in range(3, 18):
        half = 3 + (y - 3) * 0.25
        rect(img, int(7 - half), y, int(7 + half), y, _c(40, 40, 50) if y % 3 else _c(28, 28, 36))
    ellipse(img, 7, 4, 3, 3, _c(28, 28, 36))
    put(img, [(6, 5), (8, 5)], _c(140, 255, 200))
    rect(img, 12, 1, 12, 16, _c(110, 90, 60))
    rect(img, 11, 15, 13, 17, _c(110, 90, 60))
    return outline(img)


def scylla():
    """스킬라 (44x48): 상반신은 바다 요정, 하반신에서 개 머리 여섯이 뻗은 괴물"""
    img = canvas(44, 48)
    skin, sea, sea_d = _c(160, 200, 190), _c(40, 90, 110), _c(24, 60, 76)
    ellipse(img, 22, 34, 14, 10, sea)                    # 하반신 (바위·물결)
    for k in range(6):                                   # 개 머리 여섯
        a = math.radians(200 + k * 28)
        hx, hy = 22 + 18 * math.cos(a) * 1.1, 34 + 14 * math.sin(a) * -0.6 + 6
        _line(img, (22, 34), (int(hx), int(hy)), sea_d)
        ellipse(img, hx, hy, 3, 2.5, _c(70, 60, 70))
        put(img, [(int(hx) + 1, int(hy) - 1)], _c(255, 80, 60))
    ellipse(img, 22, 20, 6, 8, skin)                     # 상반신
    ellipse(img, 22, 9, 5, 5, skin)
    for i in range(8):                                   # 머리칼 (해초)
        put(img, [(16 + i, 4 + (i % 3)), (16 + i, 5 + (i % 3))], _c(40, 120, 90))
    put(img, [(20, 9), (24, 9)], _c(255, 230, 80))
    return outline(img, (10, 30, 36, 255))


def strait_shark():
    """해협 상어 (20x12)"""
    img = canvas(20, 12)
    ellipse(img, 9, 7, 8, 3, _c(110, 130, 150))
    ellipse(img, 9, 8, 6, 1.5, _c(220, 230, 235))
    _poly(img, [(8, 4), (10, 0), (12, 4)], _c(90, 110, 130))
    _poly(img, [(1, 7), (0, 3), (3, 6)], _c(90, 110, 130))
    put(img, [(15, 6)], _c(20, 20, 20))
    return outline(img)


def serpent_warrior():
    """바다뱀 전사 (14x18): 뱀 비늘의 해신 병사, 삼지창"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(70, 140, 130))
    put(img, [(6, 4), (8, 4)], _c(255, 230, 60))
    rect(img, 4, 8, 10, 13, _c(50, 110, 110))
    for i in range(4):
        put(img, [(6 + (i % 2), 14 + i)], _c(40, 90, 90))
    rect(img, 12, 2, 12, 15, _c(200, 190, 140))
    put(img, [(11, 2), (13, 2), (12, 1)], _c(220, 220, 230))
    return outline(img)


def siren_witch():
    """해협의 마녀 (12x16)"""
    img = canvas(12, 16)
    ellipse(img, 6, 4, 2.5, 2.5, _c(200, 230, 220))
    rect(img, 3, 2, 9, 3, _c(60, 150, 160))
    put(img, [(5, 4), (7, 4)], _c(40, 60, 120))
    for y in range(7, 16):
        half = 1.5 + (y - 7) * 0.4
        rect(img, int(6 - half), y, int(6 + half), y, _c(60, 120, 160) if y % 2 else _c(40, 90, 130))
    return outline(img)


def antaeus():
    """대지의 거인 안타이오스 (42x54): 흙빛 근육질 레슬러, 모래 묻은 다리"""
    img = canvas(42, 54)
    skin, skin_d = _c(170, 110, 70), _c(120, 76, 46)
    rect(img, 12, 38, 18, 52, skin_d)
    rect(img, 24, 38, 30, 52, skin_d)
    rect(img, 11, 50, 19, 53, _c(200, 170, 110))
    rect(img, 23, 50, 31, 53, _c(200, 170, 110))
    ellipse(img, 21, 26, 13, 12, skin)
    rect(img, 10, 34, 32, 39, _c(200, 170, 90))         # 허리띠
    rect(img, 2, 16, 8, 32, skin_d)                    # 팔
    rect(img, 34, 16, 40, 32, skin_d)
    ellipse(img, 5, 33, 4, 3, skin)
    ellipse(img, 37, 33, 4, 3, skin)
    ellipse(img, 21, 9, 6, 6, skin)
    rect(img, 15, 3, 27, 5, _c(60, 40, 30))
    put(img, [(19, 9), (23, 9)], _c(40, 20, 10))
    rect(img, 18, 13, 24, 14, _c(60, 40, 30))          # 수염
    return outline(img, (40, 20, 10, 255))


def libyan_fighter():
    """리비아 투사 (14x18)"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(170, 110, 70))
    rect(img, 4, 1, 10, 2, _c(60, 40, 30))
    rect(img, 4, 8, 10, 12, _c(170, 110, 70))
    rect(img, 4, 12, 10, 13, _c(200, 170, 90))
    rect(img, 5, 14, 6, 17, _c(120, 76, 46))
    rect(img, 8, 14, 9, 17, _c(120, 76, 46))
    return outline(img)


def desert_hyena():
    """사막 하이에나 (18x12)"""
    img = canvas(18, 12)
    ellipse(img, 8, 6, 6, 3, _c(180, 150, 100))
    ellipse(img, 14, 5, 2.5, 2, _c(170, 140, 90))
    for x, y in ((5, 5), (8, 6), (11, 5)):
        put(img, [(x, y)], _c(100, 80, 50))
    put(img, [(15, 4)], _c(40, 30, 20))
    for x in (4, 7, 10, 12):
        rect(img, x, 9, x, 11, _c(130, 106, 70))
    return outline(img)


def sand_wisp():
    """모래 정령 (12x16)"""
    img = canvas(12, 16)
    for y in range(2, 15):
        w = 4 - abs(y - 8) * 0.35
        rect(img, int(6 - w), y, int(6 + w), y, (220, 190, 120, 210))
    put(img, [(4, 6), (7, 6)], _c(120, 70, 30))
    for x, y in ((2, 13), (9, 14), (5, 15)):
        put(img, [(x, y)], _c(230, 200, 140))
    return outline(img, (100, 70, 30, 255))


def floor_cyclops_cave():
    return _floor(401, (90, 84, 74), 5, [(6, (70, 64, 56, 255), 4), (5, (120, 112, 98, 255), 2), (3, (230, 226, 210, 255), 1)])


def floor_underworld_gate():
    return _floor(411, (46, 40, 52), 5, [(6, (30, 26, 36, 255), 4), (5, (80, 50, 60, 255), 2), (3, (255, 120, 60, 255), 1)])


def floor_strait():
    return _floor(421, (60, 110, 130), 6, [(6, (80, 140, 160, 255), 5), (5, (40, 80, 100, 255), 2), (4, (220, 240, 245, 255), 1)])


def floor_libya_arena():
    return _floor(431, (200, 170, 115), 6, [(6, (220, 190, 135, 255), 4), (5, (170, 140, 90, 255), 2), (3, (140, 90, 60, 255), 1)])


def save_late13_sprites():
    for name, painter in (("polyphemus", polyphemus), ("cyclops_eye", cyclops_eye), ("sheep", sheep), ("young_cyclops", young_cyclops),
                          ("cave_wolf", cave_wolf), ("cyclops_slinger", cyclops_slinger), ("cerberus", cerberus),
                          ("underworld_hound", underworld_hound), ("shade_soldier", shade_soldier), ("charon_shade", charon_shade),
                          ("scylla", scylla), ("strait_shark", strait_shark), ("serpent_warrior", serpent_warrior), ("siren_witch", siren_witch),
                          ("antaeus", antaeus), ("libyan_fighter", libyan_fighter), ("desert_hyena", desert_hyena), ("sand_wisp", sand_wisp)):
        save(painter(), "characters", f"{name}.png")
    for name, col, eye in (("cerberus_head_fire", (255, 120, 40), (255, 200, 60)), ("cerberus_head_ice", (140, 210, 255), (180, 240, 255)),
                           ("cerberus_head_poison", (130, 220, 90), (200, 255, 120))):
        save(cerberus_head(_c(*col), _c(*eye)), "characters", f"{name}.png")
    save(lyre(), "world", "lyre.png")
    for name, painter in (("floor_cyclops_cave", floor_cyclops_cave), ("floor_underworld_gate", floor_underworld_gate),
                          ("floor_strait", floor_strait), ("floor_libya_arena", floor_libya_arena)):
        save(painter(), "tiles", f"{name}.png")



# ---------------------------------------------------------------- 46~49스테이지 (괴물과 영웅, 사슬의 티탄)
def arachne():
    """거미 여인 아라크네 (44x44): 상반신은 직조공 여인, 하반신은 커다란 거미"""
    img = canvas(44, 44)
    body, body_d, skin = _c(60, 44, 70), _c(36, 26, 44), _c(220, 200, 210)
    for side in (-1, 1):                               # 거미 다리 8개
        for k in range(4):
            x0, y0 = 22 + side * 6, 28 + k * 2
            x1, y1 = 22 + side * (16 + k * 2), 24 + k * 5
            _line(img, (x0, y0), (x1, y1), body_d)
            _line(img, (x1, y1), (x1 + side * 3, y1 + 8), body_d)
    ellipse(img, 22, 32, 10, 8, body)                  # 거미 배
    for x, y in ((18, 30), (26, 30), (22, 35)):
        put(img, [(x, y)], _c(200, 60, 80))
    ellipse(img, 22, 18, 5, 6, skin)                   # 상반신
    rect(img, 18, 18, 26, 24, _c(110, 70, 130))
    ellipse(img, 22, 9, 4.5, 4.5, skin)
    rect(img, 17, 4, 27, 8, _c(30, 20, 40))            # 머리칼
    for x in (20, 21, 23, 24):
        put(img, [(x, 9)], _c(220, 40, 60))            # 여러 눈
    return outline(img, (14, 8, 18, 255))


def loom():
    """아라크네의 베틀 (24x24)"""
    img = canvas(24, 24)
    wood = _c(120, 86, 56)
    rect(img, 2, 2, 4, 23, wood)
    rect(img, 19, 2, 21, 23, wood)
    rect(img, 2, 2, 21, 4, wood)
    rect(img, 2, 18, 21, 20, wood)
    for x in range(5, 19, 2):
        rect(img, x, 5, x, 17, (235, 235, 245, 220))
    for y in range(6, 17, 3):
        rect(img, 5, y, 18, y, _c(160, 100, 180))
    return outline(img)


def spider_maiden():
    """거미 시녀 (14x18)"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(210, 190, 200))
    rect(img, 4, 1, 10, 2, _c(30, 20, 40))
    put(img, [(6, 4), (8, 4)], _c(220, 40, 60))
    rect(img, 4, 8, 10, 12, _c(90, 60, 110))
    for side in (-1, 1):
        put(img, [(7 + side * 4, 13), (7 + side * 5, 15), (7 + side * 6, 17)], _c(36, 26, 44))
    ellipse(img, 7, 14, 3, 2.5, _c(60, 44, 70))
    return outline(img)


def cave_spider():
    """동굴 거미 (16x12)"""
    img = canvas(16, 12)
    ellipse(img, 8, 6, 4, 3, _c(70, 60, 60))
    ellipse(img, 8, 3, 2, 2, _c(80, 70, 70))
    put(img, [(7, 2), (9, 2)], _c(220, 40, 60))
    for side in (-1, 1):
        for k in range(4):
            put(img, [(8 + side * (4 + k % 2 + 1), 3 + k * 2), (8 + side * (6 + k % 2), 4 + k * 2)], _c(50, 40, 40))
    return outline(img)


def weaver_spider():
    """실 뽑는 거미 (14x14)"""
    img = canvas(14)
    ellipse(img, 7, 8, 4, 3.5, _c(200, 200, 215))
    ellipse(img, 7, 4, 2, 2, _c(170, 170, 190))
    put(img, [(6, 3), (8, 3)], _c(120, 40, 160))
    for side in (-1, 1):
        for k in range(3):
            put(img, [(7 + side * (5 + k % 2), 5 + k * 3)], _c(140, 140, 160))
    rect(img, 7, 12, 7, 13, (240, 240, 255, 200))
    return outline(img)


def echidna():
    """괴물의 어머니 에키드나 (40x50): 상반신은 여인, 하반신은 커다란 뱀 꼬리"""
    img = canvas(40, 50)
    sc, sc_d, skin = _c(70, 110, 80), _c(40, 70, 50), _c(210, 180, 160)
    for i in range(30):                                 # 뱀 꼬리 (똬리)
        t = i / 29.0
        a = t * math.pi * 2.2
        ellipse(img, 20 + 12 * math.cos(a) * (1 - t * 0.4), 38 + 6 * math.sin(a), 4.5 - t * 2, 4.5 - t * 2, sc if i % 3 else sc_d)
    ellipse(img, 20, 22, 6, 9, skin)                    # 상반신
    rect(img, 15, 22, 25, 28, _c(90, 40, 80))
    ellipse(img, 20, 10, 5, 5, skin)
    for i in range(10):                                 # 뱀 머리칼
        put(img, [(14 + i, 5 + (i % 3)), (14 + i, 6 + (i % 2))], _c(60, 100, 60))
    put(img, [(18, 10), (22, 10)], _c(255, 220, 60))
    return outline(img, (16, 30, 20, 255))


def monster_egg():
    """괴물의 알 (14x16)"""
    img = canvas(14, 16)
    ellipse(img, 6.5, 8.5, 5.5, 7, _c(200, 180, 150))
    for x, y in ((4, 5), (8, 8), (5, 11), (9, 4)):
        put(img, [(x, y), (x + 1, y)], _c(140, 80, 120))
    put(img, [(4, 3), (5, 3)], _c(240, 230, 210))
    return outline(img)


def baby_chimera():
    """꼬마 키메라 (18x14)"""
    img = canvas(18, 14)
    ellipse(img, 8, 8, 6, 4, _c(200, 150, 70))
    ellipse(img, 14, 6, 3, 3, _c(210, 160, 80))
    put(img, [(15, 5)], _c(30, 20, 10))
    put(img, [(12, 3), (13, 2)], _c(220, 220, 200))
    for i in range(5):
        put(img, [(2 - i // 3, 7 - i)], _c(80, 140, 70))
    for x in (5, 9, 11):
        rect(img, x, 11, x, 13, _c(150, 110, 50))
    return outline(img)


def baby_cerberus():
    """꼬마 케르베로스 (18x14): 머리 셋 달린 강아지"""
    img = canvas(18, 14)
    ellipse(img, 8, 9, 6, 3.5, _c(60, 50, 56))
    for k in range(3):
        ellipse(img, 11 + k * 2.5, 5 - (k % 2), 2, 2, _c(70, 60, 66))
        put(img, [(12 + int(k * 2.5), 4 - (k % 2))], _c(255, 120, 60))
    for x in (4, 7, 10, 12):
        rect(img, x, 11, x, 13, _c(40, 32, 36))
    return outline(img)


def nanny_harpy():
    """괴물 유모 하피 (14x16)"""
    img = canvas(14, 16)
    ellipse(img, 7, 4, 2.5, 2.5, _c(220, 190, 170))
    rect(img, 5, 1, 9, 2, _c(90, 60, 90))
    put(img, [(6, 4), (8, 4)], _c(255, 230, 60))
    rect(img, 5, 7, 9, 11, _c(120, 90, 120))
    for side in (-1, 1):
        for i in range(4):
            put(img, [(7 + side * (3 + i), 6 + i // 2)], _c(140, 100, 140) if i % 2 else _c(100, 70, 100))
    put(img, [(5, 13), (9, 13)], _c(230, 200, 80))
    return outline(img)


def nest_guard():
    """둥지 파수꾼 (14x18): 뱀 비늘 갑옷의 반인반수 경비병"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(90, 130, 90))
    put(img, [(6, 4), (8, 4)], _c(255, 220, 60))
    rect(img, 4, 8, 10, 13, _c(70, 100, 70))
    rect(img, 5, 14, 6, 17, _c(50, 70, 50))
    rect(img, 8, 14, 9, 17, _c(50, 70, 50))
    rect(img, 12, 3, 12, 15, _c(180, 180, 190))
    return outline(img)


def heracles():
    """영웅 헤라클레스 (34x48): 네메아 사자 가죽을 머리에 쓰고 몽둥이를 든 근육질 영웅"""
    img = canvas(34, 48)
    skin, pelt, pelt_d = _c(220, 170, 120), _c(210, 160, 70), _c(160, 110, 40)
    rect(img, 11, 34, 15, 46, skin)
    rect(img, 19, 34, 23, 46, skin)
    rect(img, 10, 44, 16, 47, _c(120, 80, 40))
    rect(img, 18, 44, 24, 47, _c(120, 80, 40))
    ellipse(img, 17, 25, 9, 10, skin)
    rect(img, 9, 28, 25, 34, pelt_d)                    # 가죽 허리
    rect(img, 4, 16, 8, 30, skin)                       # 팔
    rect(img, 26, 16, 30, 30, skin)
    ellipse(img, 17, 10, 5, 5, skin)
    ellipse(img, 17, 7, 8, 6, pelt)                     # 사자 가죽 머리
    for x in (10, 12, 22, 24):
        put(img, [(x, 3), (x, 4)], pelt_d)
    put(img, [(13, 6), (21, 6)], _c(40, 30, 20))        # 사자 눈
    put(img, [(15, 10), (19, 10)], _c(60, 40, 20))
    rect(img, 29, 6, 32, 34, _c(110, 80, 50))           # 몽둥이
    ellipse(img, 30.5, 7, 3, 4, _c(130, 96, 60))
    for side in (-1, 1):                                # 가죽 앞발 (어깨)
        put(img, [(17 + side * 9, 15), (17 + side * 10, 16), (17 + side * 10, 17)], pelt)
    return outline(img, (50, 30, 10, 255))


def hero_trainee():
    """영웅 견습생 (14x18)"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(220, 170, 120))
    rect(img, 4, 1, 10, 2, _c(200, 60, 40))
    rect(img, 4, 8, 10, 13, _c(180, 160, 120))
    rect(img, 5, 14, 6, 17, _c(220, 170, 120))
    rect(img, 8, 14, 9, 17, _c(220, 170, 120))
    ellipse(img, 2, 10, 2, 3, _c(190, 140, 60))
    rect(img, 12, 4, 12, 14, _c(200, 200, 210))
    return outline(img)


def centaur_archer():
    """켄타우로스 궁수 (18x18)"""
    img = canvas(18)
    ellipse(img, 8, 12, 6, 3.5, _c(140, 100, 60))
    for x in (4, 7, 10, 12):
        rect(img, x, 14, x, 17, _c(100, 70, 40))
    rect(img, 12, 5, 15, 11, _c(220, 180, 140))
    ellipse(img, 13.5, 3, 2.5, 2.5, _c(220, 180, 140))
    put(img, [(14, 3)], _c(40, 30, 20))
    for i in range(7):
        put(img, [(17, 3 + i)], _c(150, 110, 60))
    return outline(img)


def lion_cub():
    """네메아 새끼사자 (18x12)"""
    img = canvas(18, 12)
    ellipse(img, 8, 6, 6, 3, _c(220, 170, 80))
    ellipse(img, 14, 4, 3, 3, _c(200, 150, 60))
    put(img, [(15, 3)], _c(40, 30, 20))
    for x in (4, 7, 10, 12):
        rect(img, x, 9, x, 11, _c(170, 120, 50))
    put(img, [(1, 5), (2, 4)], _c(170, 120, 50))
    return outline(img)


def prometheus():
    """사슬에 묶인 티탄 프로메테우스 (40x52): 불씨를 쥔 손, 팔목의 끊어진 쇠고랑, 불타는 듯한 눈"""
    img = canvas(40, 52)
    skin, skin_d = _c(170, 130, 100), _c(120, 90, 70)
    rect(img, 13, 36, 18, 50, skin_d)
    rect(img, 22, 36, 27, 50, skin_d)
    ellipse(img, 20, 26, 11, 11, skin)
    rect(img, 9, 33, 31, 38, _c(90, 70, 60))
    rect(img, 3, 16, 8, 32, skin_d)
    rect(img, 32, 16, 37, 32, skin_d)
    for x in (2, 31):                                   # 쇠고랑
        rect(img, x, 28, x + 7, 30, _c(110, 110, 120))
    ellipse(img, 5.5, 13, 3, 4, _c(255, 160, 40))       # 손에 쥔 불씨
    ellipse(img, 5.5, 13, 1.5, 2, _c(255, 240, 150))
    ellipse(img, 20, 10, 6, 6, skin)
    rect(img, 14, 3, 26, 6, _c(80, 60, 50))
    put(img, [(18, 10), (22, 10)], _c(255, 140, 40))
    rect(img, 17, 14, 23, 16, _c(80, 60, 50))           # 수염
    return outline(img, (40, 24, 14, 255))


def titan_chain():
    """티탄의 사슬 (12x20): 바위에 박힌 굵은 쇠사슬"""
    img = canvas(12, 20)
    ellipse(img, 5.5, 16, 5, 3.5, _c(110, 100, 90))
    for k in range(5):
        y = 2 + k * 3
        ellipse(img, 5.5, y, 2.5 if k % 2 == 0 else 1.5, 1.6, _c(150, 150, 160))
        put(img, [(5, y)], (0, 0, 0, 0))
    return outline(img)


def caucasus_eagle():
    """바위산 독수리 (18x12)"""
    img = canvas(18, 12)
    ellipse(img, 9, 7, 4, 2.5, _c(100, 70, 40))
    ellipse(img, 13, 5, 2, 2, _c(230, 230, 220))
    put(img, [(15, 5)], _c(240, 190, 60))
    for i in range(8):
        put(img, [(8 - i, 5 - i // 3), (8 - i, 6 - i // 3)], _c(120, 86, 50) if i % 2 else _c(80, 56, 30))
    return outline(img)


def chain_warden():
    """사슬 감시자 (14x18)"""
    img = canvas(14, 18)
    ellipse(img, 7, 4, 3, 3, _c(120, 120, 130))
    rect(img, 5, 3, 9, 3, _c(40, 40, 50))
    rect(img, 4, 8, 10, 13, _c(90, 90, 100))
    rect(img, 5, 14, 6, 17, _c(70, 70, 80))
    rect(img, 8, 14, 9, 17, _c(70, 70, 80))
    for k in range(4):
        put(img, [(11 + (k % 2), 6 + k * 2)], _c(160, 160, 170))
    return outline(img)


def ember_spirit():
    """불씨 정령 (12x14)"""
    img = canvas(12, 14)
    for y in range(14):
        w = max(0, 4 - abs(y - 9) * 0.6) if y > 3 else y * 0.6
        rect(img, int(6 - w), y, int(6 + w), y, _c(255, 140, 40) if y > 6 else _c(255, 230, 120))
    put(img, [(4, 9), (7, 9)], _c(80, 20, 10))
    return outline(img, (120, 40, 10, 255))


def floor_web_temple():
    return _floor(441, (70, 62, 78), 5, [(6, (50, 44, 58, 255), 4), (5, (110, 100, 120, 255), 2), (4, (230, 230, 240, 255), 1)])


def floor_monster_nest():
    return _floor(451, (96, 84, 64), 6, [(6, (76, 64, 48, 255), 4), (5, (130, 110, 80, 255), 2), (4, (210, 190, 160, 255), 1)])


def floor_hero_trial():
    return _floor(461, (180, 160, 120), 5, [(6, (200, 180, 140, 255), 5), (5, (150, 130, 96, 255), 2), (3, (220, 120, 60, 255), 1)])


def floor_caucasus():
    return _floor(471, (100, 96, 92), 6, [(6, (80, 76, 74, 255), 4), (5, (130, 126, 120, 255), 2), (4, (255, 140, 50, 255), 1)])


def nest_viper():
    """둥지 독사 (18x12): 짙은 녹색 뱀, 노란 띠무늬, 초록 독니"""
    img = canvas(18, 12)
    sc, sc_d, band = _c(70, 110, 60), _c(40, 70, 36), _c(210, 190, 80)
    for i in range(14):
        x = 2 + i
        y = 7 + int(round(2 * math.sin(i * 0.9)))
        rect(img, x, y - 1, x, y, band if i % 4 == 1 else (sc if i % 3 else sc_d))
    ellipse(img, 15, 4, 2.5, 2, sc)
    put(img, [(16, 3)], _c(240, 200, 40))
    put(img, [(17, 6), (14, 6)], _c(140, 255, 90))
    return outline(img)


def save_late14_sprites():
    for name, painter in (("arachne", arachne), ("loom", loom), ("spider_maiden", spider_maiden), ("cave_spider", cave_spider),
                          ("weaver_spider", weaver_spider), ("echidna", echidna), ("monster_egg", monster_egg), ("baby_chimera", baby_chimera),
                          ("baby_cerberus", baby_cerberus), ("nanny_harpy", nanny_harpy), ("nest_viper", nest_viper), ("nest_guard", nest_guard), ("heracles", heracles),
                          ("hero_trainee", hero_trainee), ("centaur_archer", centaur_archer), ("lion_cub", lion_cub), ("prometheus", prometheus),
                          ("titan_chain", titan_chain), ("caucasus_eagle", caucasus_eagle), ("chain_warden", chain_warden), ("ember_spirit", ember_spirit)):
        save(painter(), "characters", f"{name}.png")
    save(orb((255, 255, 255), (200, 200, 220)), "projectiles", "silk.png")
    for name, painter in (("floor_web_temple", floor_web_temple), ("floor_monster_nest", floor_monster_nest),
                          ("floor_hero_trial", floor_hero_trial), ("floor_caucasus", floor_caucasus)):
        save(painter(), "tiles", f"{name}.png")



# ---------------------------------------------------------------- 50스테이지 (헤파이스토스의 대장간)
def hephaestus():
    """대장장이 신 헤파이스토스 (42x52): 검은 수염, 가죽 앞치마, 굵은 팔, 불꽃이 이는 망치"""
    img = canvas(42, 52)
    skin, skin_d, apron = _c(190, 130, 90), _c(140, 90, 60), _c(110, 70, 40)
    rect(img, 13, 38, 18, 50, skin_d)
    rect(img, 23, 38, 28, 50, _c(150, 150, 160))      # 쇠다리 보조구
    rect(img, 12, 48, 19, 51, _c(60, 40, 30))
    rect(img, 22, 48, 29, 51, _c(60, 40, 30))
    ellipse(img, 20, 27, 12, 11, skin)
    rect(img, 12, 26, 28, 40, apron)                   # 가죽 앞치마
    for y in (30, 34):
        put(img, [(14, y), (26, y)], _c(80, 50, 30))
    rect(img, 3, 16, 9, 32, skin_d)
    rect(img, 31, 16, 37, 32, skin_d)
    ellipse(img, 20, 10, 6, 6, skin)
    rect(img, 13, 3, 27, 6, _c(30, 24, 20))
    ellipse(img, 20, 16, 6, 4, _c(30, 24, 20))         # 검은 수염
    put(img, [(18, 9), (22, 9)], _c(255, 160, 60))
    rect(img, 36, 8, 38, 34, _c(110, 80, 50))          # 망치 자루
    rect(img, 32, 4, 41, 10, _c(90, 90, 100))          # 망치 머리
    for x, y in ((33, 2), (37, 1), (40, 3)):
        put(img, [(x, y)], _c(255, 170, 60))
    return outline(img, (40, 20, 10, 255))


def anvil():
    """헤파이스토스의 모루 (22x16)"""
    img = canvas(22, 16)
    rect(img, 3, 3, 20, 6, _c(90, 90, 100))
    _poly(img, [(0, 3), (3, 3), (3, 6)], _c(90, 90, 100))
    rect(img, 7, 7, 15, 11, _c(70, 70, 80))
    rect(img, 4, 12, 18, 15, _c(60, 60, 70))
    put(img, [(6, 3), (7, 3), (8, 3)], _c(255, 160, 60))
    return outline(img)


def golden_net():
    """황금 그물 (18x18)"""
    img = canvas(18)
    for i in range(0, 18, 4):
        _line(img, (i, 0), (i, 17), _c(240, 200, 80))
        _line(img, (0, i), (17, i), _c(240, 200, 80))
    for i in range(2, 18, 4):
        for j in range(2, 18, 4):
            put(img, [(i, j)], _c(255, 240, 160))
    return img


def bronze_automaton():
    """청동 자동인형 (14x18)"""
    img = canvas(14, 18)
    rect(img, 4, 1, 10, 6, _c(190, 140, 70))
    put(img, [(5, 3), (9, 3)], _c(120, 230, 255))
    rect(img, 3, 7, 11, 13, _c(170, 120, 60))
    put(img, [(7, 9)], _c(255, 200, 80))
    rect(img, 4, 14, 5, 17, _c(130, 90, 40))
    rect(img, 9, 14, 10, 17, _c(130, 90, 40))
    rect(img, 1, 7, 2, 12, _c(150, 100, 50))
    rect(img, 12, 7, 13, 12, _c(150, 100, 50))
    return outline(img)


def cyclops_smith():
    """키클롭스 대장장이 (20x20)"""
    img = canvas(20)
    ellipse(img, 10, 12, 6, 6, _c(180, 130, 100))
    rect(img, 6, 11, 14, 17, _c(110, 70, 40))
    ellipse(img, 10, 5, 4, 4, _c(190, 140, 110))
    ellipse(img, 10, 5, 1.6, 1.6, _c(250, 250, 240))
    put(img, [(10, 5)], _c(200, 60, 20))
    rect(img, 7, 18, 8, 19, _c(140, 100, 70))
    rect(img, 12, 18, 13, 19, _c(140, 100, 70))
    rect(img, 16, 4, 17, 13, _c(110, 80, 50))
    rect(img, 15, 2, 19, 5, _c(90, 90, 100))
    return outline(img)


def bronze_hound():
    """청동 사냥개 (18x12)"""
    img = canvas(18, 12)
    ellipse(img, 8, 6, 6, 3, _c(190, 140, 70))
    ellipse(img, 14, 4, 2.5, 2, _c(200, 150, 80))
    put(img, [(15, 3)], _c(255, 90, 40))
    for x in (4, 7, 10, 12):
        rect(img, x, 9, x, 11, _c(140, 100, 50))
    for x in (5, 8, 11):
        put(img, [(x, 4)], _c(230, 190, 120))
    return outline(img)


def spear_bolt():
    """던지는 청동 창 (14x6)"""
    img = canvas(14, 6)
    rect(img, 0, 2, 10, 3, _c(140, 100, 60))
    _poly(img, [(10, 0), (13, 2), (13, 3), (10, 5)], _c(220, 170, 90))
    return outline(img, (60, 30, 10, 255))


def floor_forge():
    return _floor(481, (70, 52, 46), 5, [(6, (50, 36, 32, 255), 4), (5, (110, 80, 60, 255), 2), (4, (255, 140, 50, 255), 1)])


def save_late15_sprites():
    for name, painter in (("hephaestus", hephaestus), ("anvil", anvil), ("golden_net", golden_net), ("bronze_automaton", bronze_automaton),
                          ("cyclops_smith", cyclops_smith), ("bronze_hound", bronze_hound)):
        save(painter(), "characters", f"{name}.png")
    save(spear_bolt(), "projectiles", "spear.png")
    save(orb((255, 240, 160), (255, 110, 30)), "projectiles", "molten_drop.png")
    save(floor_forge(), "tiles", "floor_forge.png")


# ---------------------------------------------------------------- 51~60스테이지 (군신의 길)
def _warrior(w, h, skin, armor, armor_d, helm, crest=None, weapon=None, shield=None, eye=(40, 30, 30)):
    """51~60 졸개용 사람형 전사 (투구 · 흉갑 · 무기 · 방패)"""
    img = canvas(w, h)
    cx = w // 2
    rect(img, cx - 3, h - 5, cx - 2, h - 1, armor_d)
    rect(img, cx + 1, h - 5, cx + 2, h - 1, armor_d)
    rect(img, cx - 4, h // 2 - 1, cx + 3, h - 6, armor)
    rect(img, cx - 4, h - 7, cx + 3, h - 6, armor_d)
    ellipse(img, cx - 0.5, h // 2 - 5, 3, 3, skin)
    rect(img, cx - 4, h // 2 - 9, cx + 3, h // 2 - 6, helm)
    put(img, [(cx - 2, h // 2 - 5), (cx + 1, h // 2 - 5)], _c(*eye))
    if crest:
        rect(img, cx - 3, h // 2 - 11, cx + 2, h // 2 - 10, _c(*crest))
    if weapon:
        rect(img, cx + 5, 1, cx + 5, h - 3, _c(*weapon))
        put(img, [(cx + 5, 0), (cx + 4, 1), (cx + 6, 1)], _c(220, 220, 230))
    if shield:
        ellipse(img, cx - 5, h // 2 + 1, 2.5, 4, _c(*shield))
    return outline(img)


def _beast(w, h, body, body_d, eye, mane=None, horns=None):
    """네 발 짐승 (늑대 · 멧돼지 · 하이에나 계열)"""
    img = canvas(w, h)
    ellipse(img, w * 0.45, h * 0.55, w * 0.33, h * 0.25, body)
    ellipse(img, w * 0.8, h * 0.4, w * 0.15, h * 0.18, body)
    for x in (int(w * 0.25), int(w * 0.38), int(w * 0.55), int(w * 0.68)):
        rect(img, x, int(h * 0.72), x, h - 1, body_d)
    put(img, [(int(w * 0.86), int(h * 0.36))], _c(*eye))
    if mane:
        ellipse(img, w * 0.62, h * 0.4, w * 0.1, h * 0.2, _c(*mane))
    if horns:
        put(img, [(int(w * 0.92), int(h * 0.55)), (int(w * 0.95), int(h * 0.5))], _c(*horns))
    rect(img, 0, int(h * 0.45), int(w * 0.15), int(h * 0.5), body_d)
    return outline(img)


def _bird(w, h, body, wing, eye, beak):
    img = canvas(w, h)
    ellipse(img, w / 2, h * 0.55, w * 0.18, h * 0.3, body)
    _poly(img, [(0, int(h * 0.25)), (int(w * 0.38), int(h * 0.5)), (int(w * 0.38), int(h * 0.7))], wing)
    _poly(img, [(w - 1, int(h * 0.25)), (int(w * 0.62), int(h * 0.5)), (int(w * 0.62), int(h * 0.7))], wing)
    ellipse(img, w / 2, h * 0.2, w * 0.12, h * 0.14, body)
    put(img, [(int(w / 2) - 1, int(h * 0.18)), (int(w / 2) + 1, int(h * 0.18))], _c(*eye))
    put(img, [(int(w / 2), int(h * 0.3)), (int(w / 2), int(h * 0.34))], _c(*beak))
    return outline(img)


def _wisp(w, h, core, edge):
    img = canvas(w, h)
    ellipse(img, w / 2, h * 0.45, w * 0.35, h * 0.35, _c(*edge))
    ellipse(img, w / 2, h * 0.45, w * 0.2, h * 0.2, _c(*core))
    for i in range(3):
        put(img, [(int(w * 0.3) + i * 3, h - 2 - i % 2)], _c(*edge))
    put(img, [(int(w / 2) - 2, int(h * 0.42)), (int(w / 2) + 1, int(h * 0.42))], _c(30, 20, 40))
    return outline(img)


def _giant(w, h, skin, skin_d, cloth, hair, eye, extra=None):
    """거인형 보스 공용 몸통"""
    img = canvas(w, h)
    rect(img, w // 2 - 8, h - 14, w // 2 - 3, h - 2, skin_d)
    rect(img, w // 2 + 2, h - 14, w // 2 + 7, h - 2, skin_d)
    ellipse(img, w / 2, h * 0.5, w * 0.3, h * 0.22, skin)
    rect(img, w // 2 - 9, int(h * 0.58), w // 2 + 8, int(h * 0.72), cloth)
    rect(img, 2, int(h * 0.3), 7, int(h * 0.6), skin_d)
    rect(img, w - 8, int(h * 0.3), w - 3, int(h * 0.6), skin_d)
    ellipse(img, w / 2, h * 0.2, 6, 6, skin)
    rect(img, w // 2 - 6, int(h * 0.08), w // 2 + 5, int(h * 0.12), hair)
    put(img, [(w // 2 - 2, int(h * 0.19)), (w // 2 + 2, int(h * 0.19))], _c(*eye))
    if extra:
        extra(img)
    return img


# ---- 51 스팀팔로스의 괴조
def stymphalian():
    """스팀팔로스의 괴조 (44x34): 청동 부리 · 청동 깃털 날개"""
    img = canvas(44, 34)
    bronze, bronze_d = _c(190, 140, 70), _c(130, 90, 40)
    _poly(img, [(0, 6), (18, 16), (18, 24), (4, 20)], bronze)
    _poly(img, [(43, 6), (25, 16), (25, 24), (39, 20)], bronze)
    for i in range(5):
        _line(img, (2 + i * 3, 9 + i), (16, 18), bronze_d)
        _line(img, (41 - i * 3, 9 + i), (27, 18), bronze_d)
    ellipse(img, 22, 20, 7, 9, _c(90, 70, 60))
    ellipse(img, 22, 9, 5, 5, _c(100, 80, 70))
    _poly(img, [(20, 12), (24, 12), (22, 19)], _c(220, 170, 80))
    put(img, [(20, 8), (24, 8)], _c(255, 80, 40))
    rect(img, 18, 29, 19, 33, bronze_d)
    rect(img, 25, 29, 26, 33, bronze_d)
    return outline(img, (40, 25, 10, 255))


def bronze_gong():
    """청동 징 (18x22)"""
    img = canvas(18, 22)
    rect(img, 2, 0, 3, 21, _c(100, 70, 40))
    rect(img, 14, 0, 15, 21, _c(100, 70, 40))
    rect(img, 2, 0, 15, 1, _c(100, 70, 40))
    ellipse(img, 8.5, 10, 6, 6, _c(210, 160, 80))
    ellipse(img, 8.5, 10, 3, 3, _c(240, 200, 120))
    put(img, [(8, 10)], _c(255, 240, 180))
    return outline(img)


def bronze_beak_bird():
    return _bird(16, 14, _c(150, 110, 60), _c(190, 140, 70), (255, 90, 40), (230, 180, 90))


def marsh_hunter():
    return _warrior(14, 20, _c(200, 160, 120), _c(90, 110, 70), _c(60, 80, 50), _c(110, 90, 60), weapon=(120, 90, 50))


def feather_wisp():
    return _wisp(14, 14, (255, 220, 150), (200, 150, 70))


def bronze_feather():
    """청동 깃털 탄 (12x6)"""
    img = canvas(12, 6)
    _poly(img, [(0, 3), (8, 0), (11, 3), (8, 5)], _c(210, 160, 80))
    _line(img, (1, 3), (10, 3), _c(130, 90, 40))
    return outline(img, (50, 30, 10, 255))


def floor_stymphalia():
    return _floor(511, (74, 92, 70), 5, [(6, (60, 78, 58, 255), 4), (5, (100, 120, 90, 255), 2), (3, (190, 150, 80, 255), 1)])


# ---- 52 용의 이빨 전사 스파르토이
def spartoi_leader():
    """스파르토이의 대장 에키온 (34x40): 땅에서 솟은 청동 갑옷 전사, 용 이빨 투구"""
    img = canvas(34, 40)
    armor, armor_d = _c(150, 120, 80), _c(100, 80, 50)
    rect(img, 11, 30, 14, 39, armor_d)
    rect(img, 19, 30, 22, 39, armor_d)
    rect(img, 9, 16, 24, 30, armor)
    for y in (19, 23, 27):
        rect(img, 10, y, 23, y, armor_d)
    ellipse(img, 16.5, 10, 5, 5, _c(170, 160, 140))
    rect(img, 11, 3, 22, 7, armor)
    for x in (12, 15, 18, 21):
        _poly(img, [(x, 3), (x + 1, 0), (x + 2, 3)], _c(240, 235, 220))     # 용 이빨 장식
    put(img, [(14, 10), (19, 10)], _c(120, 255, 140))
    rect(img, 27, 2, 28, 36, _c(120, 90, 50))
    _poly(img, [(25, 3), (27, 0), (30, 0), (30, 3)], _c(220, 220, 230))
    ellipse(img, 6, 22, 4, 7, _c(130, 100, 60))
    put(img, [(6, 22)], _c(220, 200, 120))
    for x, y in ((8, 39), (25, 38), (4, 37)):
        put(img, [(x, y)], _c(90, 70, 40))
    return outline(img, (30, 20, 10, 255))


def spartoi_warrior():
    return _warrior(16, 22, _c(170, 160, 140), _c(150, 120, 80), _c(100, 80, 50), _c(150, 120, 80), crest=(240, 235, 220), weapon=(120, 90, 50), shield=(130, 100, 60), eye=(120, 255, 140))


def theban_spearman():
    return _warrior(16, 22, _c(210, 170, 130), _c(160, 60, 50), _c(110, 40, 30), _c(170, 150, 90), crest=(200, 40, 40), weapon=(130, 100, 60))


def field_serpent():
    img = canvas(18, 12)
    for i in range(14):
        x = 2 + i
        y = 7 + int(round(2 * math.sin(i * 0.8)))
        rect(img, x, y - 1, x, y, _c(80, 120, 60) if i % 3 else _c(50, 80, 40))
    ellipse(img, 15, 4, 2.5, 2, _c(90, 130, 70))
    put(img, [(16, 3)], _c(255, 220, 60))
    return outline(img)


def throw_stone():
    """던지는 돌 (12x10)"""
    img = canvas(12, 10)
    ellipse(img, 6, 5, 5, 4, _c(140, 135, 125))
    ellipse(img, 5, 4, 2, 1.5, _c(180, 175, 165))
    return outline(img)


def floor_cadmus():
    return _floor(523, (96, 80, 58), 5, [(6, (78, 64, 46, 255), 4), (5, (120, 100, 70, 255), 2), (3, (220, 215, 200, 255), 1)])


# ---- 53 콜키스의 잠들지 않는 용
def colchian_dragon():
    """콜키스의 잠들지 않는 용 (64x52): 짙은 녹색 비늘, 작은 날개, 감기지 않는 노란 눈"""
    img = _dragon(64, 52, _c(60, 120, 80), _c(40, 80, 55), _c(190, 180, 90), _c(50, 100, 70), _c(30, 70, 50), _c(255, 220, 60), _c(220, 200, 120), 0.6)
    for x, y in ((20, 30), (26, 28), (32, 30), (38, 28)):
        put(img, [(x, y)], _c(200, 170, 60))
    return outline(img, (15, 35, 20, 255))


def golden_fleece():
    """황금 양털 (18x14)"""
    img = canvas(18, 14)
    for cx, cy in ((5, 5), (9, 4), (13, 5), (4, 9), (9, 9), (14, 9)):
        ellipse(img, cx, cy, 3, 2.6, _c(240, 200, 70))
    for x, y in ((6, 4), (10, 3), (12, 8), (5, 9)):
        put(img, [(x, y)], _c(255, 245, 170))
    rect(img, 8, 12, 9, 13, _c(200, 150, 50))
    return outline(img, (90, 60, 10, 255))


def argo_ship():
    """아르고호 뱃머리 (34x20)"""
    img = canvas(34, 20)
    _poly(img, [(0, 10), (33, 10), (28, 18), (4, 18)], _c(130, 90, 50))
    rect(img, 4, 12, 28, 12, _c(90, 60, 30))
    rect(img, 16, 0, 17, 10, _c(110, 80, 50))
    _poly(img, [(18, 1), (27, 4), (18, 8)], _c(230, 220, 200))
    for x in (6, 11, 21, 26):
        put(img, [(x, 14)], _c(200, 60, 50))
    return outline(img)


def colchis_bull():
    """콜키스의 청동 황소 (20x14)"""
    return _beast(20, 14, _c(180, 130, 60), _c(120, 80, 30), (255, 120, 40), horns=(230, 230, 230))


def colchis_warrior():
    return _warrior(16, 22, _c(200, 160, 120), _c(70, 90, 140), _c(40, 60, 100), _c(140, 140, 160), crest=(240, 200, 70), weapon=(130, 100, 60), shield=(70, 90, 140))


def grove_viper():
    img = canvas(18, 12)
    for i in range(14):
        x = 2 + i
        y = 7 + int(round(2 * math.sin(i * 0.9)))
        rect(img, x, y - 1, x, y, _c(60, 100, 60) if i % 2 else _c(200, 170, 60))
    ellipse(img, 15, 4, 2.5, 2, _c(70, 110, 60))
    put(img, [(16, 3)], _c(255, 60, 40))
    return outline(img)


def floor_ares_grove():
    return _floor(537, (58, 76, 52), 5, [(6, (44, 60, 40, 255), 4), (5, (80, 100, 64, 255), 2), (3, (200, 170, 70, 255), 1)])


# ---- 54 아마존 여왕 히폴리테
def hippolyta():
    """아마존 여왕 히폴리테 (34x44): 붉은 깃 투구, 반달 방패, 도끼"""
    img = canvas(34, 44)
    skin, tunic, tunic_d = _c(210, 160, 120), _c(170, 50, 50), _c(120, 30, 30)
    rect(img, 12, 32, 14, 43, skin)
    rect(img, 19, 32, 21, 43, skin)
    rect(img, 11, 40, 15, 43, _c(110, 70, 40))
    rect(img, 18, 40, 22, 43, _c(110, 70, 40))
    rect(img, 10, 17, 23, 32, tunic)
    rect(img, 10, 28, 23, 32, tunic_d)
    ellipse(img, 16.5, 11, 5, 5, skin)
    rect(img, 11, 4, 22, 8, _c(200, 170, 90))
    rect(img, 13, 0, 20, 3, _c(220, 50, 50))
    rect(img, 8, 6, 10, 20, _c(90, 50, 30))                 # 땋은 머리
    put(img, [(14, 11), (19, 11)], _c(60, 40, 30))
    _poly(img, [(0, 18), (7, 15), (7, 29), (0, 26)], _c(200, 170, 90))   # 반달 방패
    rect(img, 27, 6, 28, 34, _c(110, 80, 50))
    _poly(img, [(29, 6), (33, 8), (33, 14), (29, 12)], _c(210, 210, 220))
    return outline(img, (40, 15, 10, 255))


def war_girdle():
    """전쟁의 허리띠 (20x8)"""
    img = canvas(20, 8)
    rect(img, 0, 2, 19, 5, _c(200, 160, 60))
    for x in range(1, 19, 3):
        put(img, [(x, 3)], _c(255, 230, 140))
    ellipse(img, 10, 3.5, 3, 3, _c(200, 40, 40))
    put(img, [(10, 3)], _c(255, 140, 120))
    return outline(img)


def amazon_archer():
    return _warrior(14, 20, _c(210, 160, 120), _c(170, 50, 50), _c(120, 30, 30), _c(90, 50, 30), weapon=(150, 110, 60))


def amazon_rider():
    """아마존 기마병 (20x20)"""
    img = canvas(20, 20)
    ellipse(img, 9, 13, 7, 3.5, _c(140, 100, 70))
    ellipse(img, 16, 10, 2.5, 2.5, _c(150, 110, 80))
    for x in (4, 7, 11, 14):
        rect(img, x, 16, x, 19, _c(100, 70, 50))
    rect(img, 7, 4, 11, 10, _c(170, 50, 50))
    ellipse(img, 9, 2.5, 2, 2, _c(210, 160, 120))
    rect(img, 12, 0, 12, 10, _c(130, 100, 60))
    return outline(img)


def amazon_shield():
    return _warrior(16, 20, _c(210, 160, 120), _c(160, 150, 120), _c(110, 100, 80), _c(200, 170, 90), crest=(220, 50, 50), shield=(200, 170, 90))


def floor_themiscyra():
    return _floor(541, (120, 96, 72), 5, [(6, (100, 78, 58, 255), 4), (5, (150, 120, 90, 255), 2), (3, (200, 60, 50, 255), 1)])


# ---- 55 거인 형제 알로아다이
def otus():
    """거인 오토스 (40x52): 푸른 띠, 거대한 창"""
    def extra(img):
        rect(img, 36, 4, 37, 44, _c(120, 90, 50))
        _poly(img, [(34, 4), (36, 0), (39, 0), (39, 4)], _c(220, 220, 230))
    return outline(_giant(40, 52, _c(200, 150, 110), _c(150, 100, 70), _c(60, 90, 160), _c(60, 40, 30), (255, 220, 120), extra), (40, 20, 10, 255))


def ephialtes():
    """거인 에피알테스 (40x52): 붉은 띠, 거대한 창"""
    def extra(img):
        rect(img, 2, 4, 3, 44, _c(120, 90, 50))
        _poly(img, [(0, 4), (1, 0), (4, 0), (5, 4)], _c(220, 220, 230))
    return outline(_giant(40, 52, _c(195, 145, 105), _c(145, 95, 65), _c(170, 60, 50), _c(90, 60, 30), (255, 220, 120), extra), (40, 20, 10, 255))


def golden_hind():
    """아르테미스의 황금 사슴 (20x18)"""
    img = canvas(20, 18)
    ellipse(img, 9, 10, 6, 3.5, _c(230, 190, 80))
    ellipse(img, 15, 6, 2.5, 2.5, _c(240, 200, 90))
    for x in (5, 8, 11, 13):
        rect(img, x, 13, x, 17, _c(180, 140, 50))
    _line(img, (14, 3), (12, 0), _c(250, 240, 200))
    _line(img, (16, 3), (18, 0), _c(250, 240, 200))
    put(img, [(16, 6)], _c(40, 30, 20))
    return outline(img, (90, 60, 10, 255))


def young_giant():
    return _warrior(18, 24, _c(200, 150, 110), _c(110, 90, 70), _c(80, 60, 40), _c(90, 60, 30), weapon=(120, 90, 50))


def rock_slinger():
    return _warrior(14, 20, _c(190, 150, 110), _c(120, 110, 90), _c(80, 70, 60), _c(100, 80, 50))


def mountain_wolf():
    return _beast(18, 12, _c(120, 115, 110), _c(80, 75, 70), (255, 220, 80))


def floor_giant_field():
    return _floor(557, (100, 104, 76), 5, [(6, (80, 86, 60, 255), 4), (5, (130, 130, 96, 255), 2), (3, (160, 150, 130, 255), 1)])


def save_late16_sprites():
    for name, painter in (("stymphalian", stymphalian), ("bronze_gong", bronze_gong), ("bronze_beak_bird", bronze_beak_bird), ("marsh_hunter", marsh_hunter),
                          ("feather_wisp", feather_wisp), ("spartoi_leader", spartoi_leader), ("spartoi_warrior", spartoi_warrior), ("theban_spearman", theban_spearman),
                          ("field_serpent", field_serpent), ("throw_stone", throw_stone), ("colchian_dragon", colchian_dragon), ("golden_fleece", golden_fleece),
                          ("argo_ship", argo_ship), ("colchis_bull", colchis_bull), ("colchis_warrior", colchis_warrior), ("grove_viper", grove_viper),
                          ("hippolyta", hippolyta), ("war_girdle", war_girdle), ("amazon_archer", amazon_archer), ("amazon_rider", amazon_rider),
                          ("amazon_shield", amazon_shield), ("otus", otus), ("ephialtes", ephialtes), ("golden_hind", golden_hind),
                          ("young_giant", young_giant), ("rock_slinger", rock_slinger), ("mountain_wolf", mountain_wolf)):
        save(painter(), "characters", f"{name}.png")
    save(bronze_feather(), "projectiles", "bronze_feather.png")
    for name, painter in (("floor_stymphalia", floor_stymphalia), ("floor_cadmus", floor_cadmus), ("floor_ares_grove", floor_ares_grove),
                          ("floor_themiscyra", floor_themiscyra), ("floor_giant_field", floor_giant_field)):
        save(painter(), "tiles", f"{name}.png")


# ---- 56 칼리돈의 영웅 멜레아그로스
def meleager():
    """칼리돈의 영웅 멜레아그로스 (34x44): 멧돼지 가죽 망토, 사냥창"""
    img = canvas(34, 44)
    skin = _c(210, 165, 125)
    rect(img, 12, 32, 14, 43, skin)
    rect(img, 19, 32, 21, 43, skin)
    rect(img, 11, 40, 15, 43, _c(100, 70, 40))
    rect(img, 18, 40, 22, 43, _c(100, 70, 40))
    rect(img, 10, 17, 23, 32, _c(80, 110, 70))
    _poly(img, [(6, 14), (27, 14), (25, 34), (8, 34)], _c(110, 80, 60))      # 멧돼지 가죽
    rect(img, 11, 18, 22, 30, _c(80, 110, 70))
    ellipse(img, 16.5, 11, 5, 5, skin)
    rect(img, 11, 4, 22, 8, _c(110, 80, 60))
    put(img, [(11, 5), (22, 5)], _c(240, 235, 220))                         # 엄니 장식
    put(img, [(14, 11), (19, 11)], _c(50, 40, 30))
    rect(img, 28, 2, 29, 40, _c(120, 90, 50))
    _poly(img, [(26, 3), (28, 0), (31, 0), (31, 3)], _c(220, 220, 230))
    rect(img, 26, 7, 31, 7, _c(120, 90, 50))
    return outline(img, (30, 20, 10, 255))


def life_brand():
    """생명의 장작 (16x10): 반쯤 탄 장작"""
    img = canvas(16, 10)
    rect(img, 1, 3, 14, 7, _c(120, 80, 40))
    for x in (3, 7, 11):
        rect(img, x, 3, x, 7, _c(90, 60, 30))
    rect(img, 12, 3, 14, 7, _c(60, 40, 30))
    put(img, [(14, 2), (15, 4), (13, 1)], _c(255, 160, 60))
    return outline(img)


def hearth():
    """화로 (22x18)"""
    img = canvas(22, 18)
    rect(img, 2, 8, 19, 17, _c(110, 100, 95))
    rect(img, 4, 10, 17, 15, _c(60, 40, 35))
    for x in (5, 9, 13, 16):
        _line(img, (x, 14), (x + 1, 6 - (x % 3)), _c(255, 150, 50))
    put(img, [(8, 4), (12, 3), (10, 5)], _c(255, 230, 120))
    return outline(img)


def calydon_boar():
    """칼리돈의 멧돼지 (28x20)"""
    return _beast(28, 20, _c(110, 80, 60), _c(70, 50, 40), (255, 80, 40), mane=(60, 40, 30), horns=(240, 235, 220))


def boar_piglet():
    return _beast(16, 11, _c(130, 95, 70), _c(90, 60, 45), (255, 90, 50), horns=(240, 235, 220))


def curetes_warrior():
    return _warrior(16, 22, _c(205, 160, 120), _c(120, 120, 130), _c(80, 80, 90), _c(150, 150, 160), crest=(60, 120, 60), weapon=(130, 100, 60), shield=(120, 120, 130))


def calydon_hunter():
    return _warrior(14, 20, _c(205, 160, 120), _c(80, 110, 70), _c(50, 80, 50), _c(110, 80, 60), weapon=(150, 110, 60))


def floor_calydon():
    return _floor(563, (84, 100, 64), 5, [(6, (66, 82, 50, 255), 4), (5, (110, 120, 80, 255), 2), (3, (130, 90, 60, 255), 1)])


# ---- 57 해골 신전의 기사 키크노스
def cycnus():
    """해골 신전의 기사 키크노스 (34x46): 흰 백조 깃 투구, 은빛 갑옷"""
    img = canvas(34, 46)
    armor, armor_d = _c(200, 205, 215), _c(130, 135, 150)
    rect(img, 11, 33, 14, 45, armor_d)
    rect(img, 19, 33, 22, 45, armor_d)
    rect(img, 9, 18, 24, 33, armor)
    for y in (22, 26, 30):
        rect(img, 10, y, 23, y, armor_d)
    ellipse(img, 16.5, 12, 5, 5, armor)
    rect(img, 13, 11, 20, 12, _c(30, 30, 40))
    put(img, [(14, 11), (19, 11)], _c(150, 220, 255))
    for i in range(6):                                   # 백조 깃
        _line(img, (16 + i // 2, 7), (11 + i * 2, 0), _c(250, 250, 255))
    ellipse(img, 5, 25, 4, 7, _c(160, 165, 180))
    put(img, [(5, 23), (4, 26), (6, 26)], _c(240, 235, 220))              # 방패의 해골
    rect(img, 27, 4, 28, 38, _c(170, 170, 180))
    _poly(img, [(26, 4), (27, 0), (29, 0), (30, 4)], _c(240, 240, 250))
    return outline(img, (30, 30, 40, 255))


def skull_altar():
    """해골 제단 (20x20)"""
    img = canvas(20, 20)
    rect(img, 2, 12, 17, 19, _c(110, 100, 90))
    for cx, cy in ((5, 9), (10, 7), (15, 9), (7, 4), (13, 4), (10, 1)):
        ellipse(img, cx, cy + 1, 2.2, 2, _c(235, 230, 215))
        put(img, [(cx - 1, cy + 1), (cx + 1, cy + 1)], _c(40, 30, 30))
    put(img, [(9, 15), (10, 15)], _c(200, 40, 40))
    return outline(img)


def skull_pilgrim():
    return _warrior(14, 20, _c(235, 230, 215), _c(120, 110, 100), _c(80, 70, 60), _c(90, 80, 70), eye=(200, 40, 40))


def skull_knight():
    return _warrior(16, 22, _c(235, 230, 215), _c(170, 170, 180), _c(110, 110, 120), _c(150, 150, 160), crest=(250, 250, 255), weapon=(170, 170, 180), shield=(150, 150, 160), eye=(200, 40, 40))


def swan_wraith():
    return _bird(16, 14, _c(240, 240, 250), _c(200, 210, 230), (150, 220, 255), (240, 180, 80))


def floor_skull_temple():
    return _floor(571, (88, 84, 90), 5, [(6, (70, 66, 74, 255), 4), (5, (110, 106, 112, 255), 2), (3, (225, 220, 205, 255), 1)])


# ---- 58 불의 거인 엔켈라도스
def enceladus():
    """불의 거인 엔켈라도스 (44x56): 용암이 흐르는 검은 피부, 뱀 다리"""
    img = canvas(44, 56)
    skin, skin_d = _c(70, 50, 50), _c(45, 30, 30)
    for side in (-1, 1):                                  # 뱀 다리
        for i in range(10):
            x = 22 + side * (4 + i)
            y = 40 + int(round(3 * math.sin(i * 0.9)))
            rect(img, x - 1, y, x + 1, y + 3, _c(90, 110, 60))
    ellipse(img, 22, 28, 13, 12, skin)
    rect(img, 2, 16, 8, 36, skin_d)
    rect(img, 36, 16, 42, 36, skin_d)
    ellipse(img, 22, 10, 7, 7, skin)
    for x, y in ((15, 22), (20, 26), (27, 24), (24, 32), (18, 33), (30, 30)):
        _line(img, (x, y), (x + 2, y + 3), _c(255, 120, 40))   # 용암 균열
    put(img, [(19, 9), (25, 9)], _c(255, 200, 60))
    rect(img, 15, 1, 29, 4, _c(40, 25, 20))
    for x in (16, 20, 24, 28):
        put(img, [(x, 0)], _c(255, 140, 40))
    return outline(img, (25, 10, 5, 255))


def sicily_rock():
    """떨어뜨릴 바위산 조각 (22x18)"""
    img = canvas(22, 18)
    _poly(img, [(2, 17), (5, 6), (11, 1), (17, 5), (20, 17)], _c(130, 120, 105))
    _poly(img, [(6, 16), (9, 8), (13, 6), (16, 16)], _c(160, 150, 130))
    rect(img, 9, 2, 13, 4, _c(90, 130, 70))
    return outline(img)


def lava_giant():
    return _warrior(18, 24, _c(80, 55, 50), _c(60, 40, 35), _c(40, 25, 20), _c(50, 35, 30), weapon=(255, 120, 40), eye=(255, 200, 60))


def fire_serpent():
    img = canvas(18, 12)
    for i in range(14):
        x = 2 + i
        y = 7 + int(round(2 * math.sin(i * 0.8)))
        rect(img, x, y - 1, x, y, _c(230, 90, 40) if i % 3 else _c(255, 190, 70))
    ellipse(img, 15, 4, 2.5, 2, _c(240, 100, 40))
    put(img, [(16, 3)], _c(255, 255, 150))
    return outline(img)


def gigantes_shaman():
    return _wisp(16, 16, (255, 220, 120), (200, 80, 40))


def floor_phlegra():
    return _floor(587, (60, 44, 40), 5, [(6, (44, 32, 30, 255), 4), (5, (90, 64, 54, 255), 2), (4, (255, 120, 40, 255), 1)])


# ---- 59 마르스의 늑대 루푸스
def lupus():
    """마르스의 늑대 루푸스 (44x30): 붉은 갈기, 청동 목걸이"""
    img = _beast(44, 30, _c(110, 100, 95), _c(70, 62, 60), (255, 60, 40), mane=(160, 50, 40))
    rect(img, 30, 14, 33, 15, _c(200, 160, 70))
    put(img, [(31, 16)], _c(240, 200, 100))
    _poly(img, [(36, 4), (37, 0), (39, 4)], _c(110, 100, 95))
    _poly(img, [(39, 5), (41, 1), (42, 6)], _c(110, 100, 95))
    put(img, [(43, 13), (42, 14)], _c(240, 235, 220))
    return outline(img, (30, 20, 20, 255))


def war_wolf():
    return _beast(20, 13, _c(105, 95, 90), _c(65, 58, 55), (255, 70, 40), mane=(140, 50, 40))


def woodpecker():
    """마르스의 딱따구리 (14x12)"""
    return _bird(14, 12, _c(40, 40, 50), _c(230, 230, 235), (255, 255, 255), (230, 200, 90))


def wolf_warrior():
    return _warrior(16, 22, _c(205, 160, 120), _c(100, 90, 85), _c(70, 62, 60), _c(105, 95, 90), crest=(140, 50, 40), weapon=(150, 110, 60))


def floor_wolf_forest():
    return _floor(593, (70, 70, 58), 5, [(6, (54, 54, 44, 255), 4), (5, (96, 92, 76, 255), 2), (3, (150, 50, 40, 255), 1)])


# ---- 60 전쟁의 신 마르스
def mars():
    """전쟁의 신 마르스 (40x54): 붉은 깃 투구, 진홍 망토, 창과 방패"""
    img = canvas(40, 54)
    skin, armor, armor_d = _c(210, 160, 120), _c(200, 160, 80), _c(140, 100, 40)
    _poly(img, [(8, 18), (31, 18), (35, 50), (4, 50)], _c(160, 30, 30))       # 망토
    rect(img, 14, 38, 17, 52, skin)
    rect(img, 22, 38, 25, 52, skin)
    rect(img, 13, 48, 18, 53, armor_d)
    rect(img, 21, 48, 26, 53, armor_d)
    rect(img, 12, 20, 27, 38, armor)
    for y in (24, 28, 32):
        rect(img, 13, y, 26, y, armor_d)
    rect(img, 12, 34, 27, 38, _c(140, 40, 40))
    ellipse(img, 19.5, 13, 5, 5, skin)
    rect(img, 14, 6, 25, 10, armor)
    rect(img, 14, 10, 15, 15, armor)
    rect(img, 24, 10, 25, 15, armor)
    for i in range(9):                                     # 붉은 깃
        rect(img, 15 + i, 2 - (1 if 2 < i < 6 else 0), 15 + i, 5, _c(220, 40, 40))
    put(img, [(17, 13), (22, 13)], _c(255, 120, 60))
    rect(img, 34, 0, 35, 46, _c(120, 90, 50))
    _poly(img, [(33, 3), (34, 0), (36, 0), (37, 3)], _c(230, 230, 240))
    ellipse(img, 5, 30, 5, 8, _c(200, 160, 80))
    ellipse(img, 5, 30, 2, 4, _c(160, 30, 30))
    return outline(img, (40, 10, 10, 255))


def ancile():
    """앙킬레 — 마르스의 방패 (14x20): 8자 모양 청동 방패"""
    img = canvas(14, 20)
    ellipse(img, 7, 5, 6, 5, _c(200, 160, 80))
    ellipse(img, 7, 14, 6, 5, _c(200, 160, 80))
    rect(img, 4, 8, 9, 11, _c(170, 130, 60))
    ellipse(img, 7, 5, 2, 2, _c(160, 40, 40))
    ellipse(img, 7, 14, 2, 2, _c(160, 40, 40))
    return outline(img)


def legionary():
    return _warrior(16, 22, _c(205, 160, 120), _c(170, 40, 40), _c(110, 25, 25), _c(190, 160, 80), crest=(220, 40, 40), weapon=(150, 150, 160), shield=(170, 40, 40))


def pilum_thrower():
    return _warrior(14, 20, _c(205, 160, 120), _c(150, 140, 120), _c(100, 90, 80), _c(190, 160, 80), weapon=(140, 110, 70))


def centurion():
    return _warrior(16, 22, _c(205, 160, 120), _c(190, 160, 80), _c(130, 100, 40), _c(190, 160, 80), crest=(220, 40, 40), weapon=(200, 200, 210))


def pilum():
    """던지는 필룸 (16x5)"""
    img = canvas(16, 5)
    rect(img, 0, 2, 10, 2, _c(130, 100, 60))
    rect(img, 10, 2, 13, 2, _c(170, 170, 180))
    _poly(img, [(13, 1), (15, 2), (13, 3)], _c(230, 230, 240))
    return outline(img, (40, 20, 10, 255))


def floor_mars_field():
    return _floor(599, (96, 70, 58), 5, [(6, (76, 52, 44, 255), 4), (5, (130, 96, 76, 255), 2), (3, (170, 40, 40, 255), 1)])


def save_late17_sprites():
    for name, painter in (("meleager", meleager), ("life_brand", life_brand), ("hearth", hearth), ("calydon_boar", calydon_boar), ("boar_piglet", boar_piglet),
                          ("curetes_warrior", curetes_warrior), ("calydon_hunter", calydon_hunter), ("cycnus", cycnus), ("skull_altar", skull_altar),
                          ("skull_pilgrim", skull_pilgrim), ("skull_knight", skull_knight), ("swan_wraith", swan_wraith), ("enceladus", enceladus),
                          ("sicily_rock", sicily_rock), ("lava_giant", lava_giant), ("fire_serpent", fire_serpent), ("gigantes_shaman", gigantes_shaman),
                          ("lupus", lupus), ("war_wolf", war_wolf), ("woodpecker", woodpecker), ("wolf_warrior", wolf_warrior), ("mars", mars),
                          ("ancile", ancile), ("legionary", legionary), ("pilum_thrower", pilum_thrower), ("centurion", centurion)):
        save(painter(), "characters", f"{name}.png")
    save(pilum(), "projectiles", "pilum.png")
    for name, painter in (("floor_calydon", floor_calydon), ("floor_skull_temple", floor_skull_temple), ("floor_phlegra", floor_phlegra),
                          ("floor_wolf_forest", floor_wolf_forest), ("floor_mars_field", floor_mars_field)):
        save(painter(), "tiles", f"{name}.png")


# ---------------------------------------------------------------- 61~70스테이지 (델포이와 태양의 길)
def _hero(w, h, skin, tunic, tunic_d, helm, crest=None, cape=None, weapon=None, shield=None, eye=(50, 40, 30), bow=None):
    """61~70 보스용 사람형 영웅 (34x44 기준)"""
    img = canvas(w, h)
    cx = w // 2
    if cape:
        _poly(img, [(cx - 9, 16), (cx + 8, 16), (cx + 11, h - 6), (cx - 12, h - 6)], _c(*cape))
    rect(img, cx - 5, h - 12, cx - 3, h - 1, skin)
    rect(img, cx + 2, h - 12, cx + 4, h - 1, skin)
    rect(img, cx - 6, h - 4, cx - 2, h - 1, tunic_d)
    rect(img, cx + 1, h - 4, cx + 5, h - 1, tunic_d)
    rect(img, cx - 7, 17, cx + 6, h - 12, tunic)
    rect(img, cx - 7, h - 16, cx + 6, h - 12, tunic_d)
    ellipse(img, cx - 0.5, 11, 5, 5, skin)
    rect(img, cx - 6, 4, cx + 5, 8, helm)
    put(img, [(cx - 3, 11), (cx + 2, 11)], _c(*eye))
    if crest:
        for i in range(10):
            rect(img, cx - 5 + i, 1 - (1 if 3 < i < 7 else 0), cx - 5 + i, 3, _c(*crest))
    if weapon:
        rect(img, w - 6, 2, w - 5, h - 6, _c(*weapon))
        _poly(img, [(w - 7, 3), (w - 6, 0), (w - 4, 0), (w - 3, 3)], _c(230, 230, 240))
    if bow:
        for y in range(8, 34):
            x = w - 5 + int(round(3 * math.sin((y - 8) / 26 * math.pi)))
            put(img, [(x, y)], _c(*bow))
        _line(img, (w - 5, 8), (w - 5, 33), _c(240, 240, 230))
    if shield:
        ellipse(img, 5, 26, 5, 7, _c(*shield))
        ellipse(img, 5, 26, 2, 3, _c(min(shield[0] + 40, 255), min(shield[1] + 40, 255), min(shield[2] + 40, 255)))
    return img


# ---- 61 활의 왕 에우리토스
def eurytus():
    """활의 왕 에우리토스 (34x44): 녹색 사냥 옷, 금관, 거대한 활"""
    return outline(_hero(34, 44, _c(210, 165, 125), _c(60, 110, 70), _c(40, 80, 50), _c(230, 190, 80), cape=(90, 60, 40), bow=(160, 110, 60)),
                   (30, 20, 10, 255))


def archery_target():
    """과녁 (18x20)"""
    img = canvas(18, 20)
    rect(img, 8, 12, 9, 19, _c(110, 80, 50))
    for r, col in ((8, (240, 235, 220)), (6, (200, 50, 50)), (4, (240, 235, 220)), (2, (200, 50, 50))):
        ellipse(img, 8.5, 8, r, r, _c(*col))
    return outline(img)


def oechalia_archer():
    return _warrior(14, 20, _c(210, 165, 125), _c(60, 110, 70), _c(40, 80, 50), _c(110, 80, 50), weapon=(160, 110, 60))


def oechalia_spearman():
    return _warrior(16, 22, _c(210, 165, 125), _c(150, 140, 110), _c(100, 90, 70), _c(230, 190, 80), crest=(60, 110, 70), weapon=(130, 100, 60), shield=(60, 110, 70))


def oechalia_hound():
    return _beast(18, 12, _c(170, 130, 90), _c(120, 90, 60), (255, 220, 120))


def floor_oechalia():
    return _floor(613, (86, 104, 70), 5, [(6, (70, 86, 56, 255), 4), (5, (110, 130, 90, 255), 2), (3, (230, 200, 90, 255), 1)])


# ---- 62 델포이의 거대 뱀 피톤
def python_serpent():
    """델포이의 거대 뱀 피톤 (52x40): 굵게 똬리를 튼 금록색 뱀"""
    img = canvas(52, 40)
    body, body_d, belly = _c(110, 140, 60), _c(70, 95, 40), _c(220, 200, 120)
    ellipse(img, 26, 30, 22, 9, body_d)
    ellipse(img, 26, 28, 18, 7, body)
    ellipse(img, 26, 22, 13, 6, body_d)
    ellipse(img, 26, 20, 10, 5, body)
    for x in range(10, 44, 4):
        put(img, [(x, 30), (x + 1, 31)], belly)
    rect(img, 30, 6, 35, 20, body)
    ellipse(img, 35, 6, 7, 5, body)
    put(img, [(37, 4), (33, 4)], _c(255, 60, 40))
    _line(img, (42, 7), (46, 8), _c(220, 60, 60))
    for x, y in ((14, 24), (20, 26), (32, 26), (38, 24)):
        put(img, [(x, y)], _c(230, 200, 80))
    return outline(img, (20, 30, 10, 255))


def laurel_branch():
    """월계수 가지 (16x12)"""
    img = canvas(16, 12)
    _line(img, (1, 10), (14, 2), _c(110, 80, 40))
    for x, y in ((3, 7), (6, 5), (9, 4), (12, 2), (5, 9), (8, 7), (11, 5)):
        ellipse(img, x, y, 1.6, 1.0, _c(70, 150, 60))
    return outline(img)


def delphi_viper():
    img = canvas(18, 12)
    for i in range(14):
        x = 2 + i
        y = 7 + int(round(2 * math.sin(i * 0.8)))
        rect(img, x, y - 1, x, y, _c(120, 150, 60) if i % 3 else _c(80, 100, 40))
    ellipse(img, 15, 4, 2.5, 2, _c(130, 160, 70))
    put(img, [(16, 3)], _c(255, 60, 40))
    return outline(img)


def oracle_fume():
    return _wisp(16, 16, (230, 220, 255), (150, 130, 190))


def python_spawn():
    """피톤의 새끼 (16x12)"""
    img = canvas(16, 12)
    ellipse(img, 8, 8, 6, 3, _c(110, 140, 60))
    ellipse(img, 13, 4, 2.5, 2.2, _c(120, 150, 70))
    put(img, [(14, 3)], _c(255, 60, 40))
    return outline(img)


def floor_delphi_cleft():
    return _floor(619, (96, 90, 76), 5, [(6, (78, 72, 60, 255), 4), (5, (130, 122, 104, 255), 2), (3, (60, 50, 40, 255), 1)])


# ---- 63 태양 전차를 몬 파에톤
def phaethon():
    """태양 전차를 몬 파에톤 (46x40): 황금 전차 위의 소년, 불꽃 말"""
    img = canvas(46, 40)
    _poly(img, [(6, 22), (32, 22), (30, 32), (8, 32)], _c(230, 180, 60))     # 전차
    ellipse(img, 12, 33, 5, 5, _c(200, 140, 40))
    ellipse(img, 12, 33, 2, 2, _c(255, 220, 120))
    ellipse(img, 27, 33, 5, 5, _c(200, 140, 40))
    ellipse(img, 27, 33, 2, 2, _c(255, 220, 120))
    rect(img, 15, 10, 22, 22, _c(240, 230, 210))                           # 소년
    ellipse(img, 18.5, 7, 4, 4, _c(220, 175, 130))
    rect(img, 14, 2, 23, 4, _c(255, 200, 60))
    put(img, [(17, 7), (20, 7)], _c(60, 40, 30))
    ellipse(img, 39, 22, 6, 4, _c(255, 150, 50))                           # 불꽃 말
    ellipse(img, 43, 16, 3, 3, _c(255, 170, 60))
    for x in (35, 38, 41):
        rect(img, x, 26, x, 30, _c(230, 110, 40))
    _line(img, (24, 14), (40, 18), _c(220, 200, 120))                      # 고삐
    for x, y in ((36, 12), (40, 10), (44, 12), (3, 20), (6, 16)):
        put(img, [(x, y)], _c(255, 230, 120))
    return outline(img, (60, 30, 10, 255))


def rein_pillar():
    """고삐 기둥 (14x24)"""
    img = canvas(14, 24)
    rect(img, 4, 4, 9, 23, _c(210, 190, 140))
    rect(img, 3, 2, 10, 4, _c(230, 210, 160))
    _line(img, (9, 6), (13, 2), _c(240, 200, 80))
    _line(img, (9, 8), (13, 12), _c(240, 200, 80))
    put(img, [(6, 10), (6, 16)], _c(180, 160, 110))
    return outline(img)


def flame_horse():
    return _beast(20, 14, _c(255, 150, 50), _c(220, 100, 30), (255, 255, 180), mane=(255, 220, 90))


def burning_charioteer():
    return _warrior(16, 22, _c(220, 175, 130), _c(230, 180, 60), _c(180, 120, 40), _c(255, 200, 60), crest=(255, 120, 40), weapon=(200, 150, 60))


def ember_sprite():
    return _wisp(14, 14, (255, 240, 160), (255, 140, 40))


def floor_sun_road():
    return _floor(631, (120, 92, 60), 5, [(6, (100, 74, 48, 255), 4), (5, (160, 120, 70, 255), 2), (4, (255, 170, 60, 255), 1)])


# ---- 64 예언자 카산드라
def cassandra():
    """예언자 카산드라 (32x44): 흰 옷, 풀어헤친 머리, 월계관"""
    img = _hero(32, 44, _c(225, 185, 150), _c(235, 230, 240), _c(180, 170, 200), _c(70, 40, 30), cape=(120, 60, 120))
    for y in range(8, 22):
        put(img, [(9, y), (22, y)], _c(70, 40, 30))
    for x in (11, 14, 18, 21):
        put(img, [(x, 3)], _c(90, 160, 70))
    put(img, [(13, 11), (18, 11)], _c(120, 180, 255))
    return outline(img, (30, 20, 30, 255))


def trojan_sentry():
    return _warrior(16, 22, _c(210, 165, 125), _c(140, 60, 50), _c(100, 40, 30), _c(200, 160, 80), crest=(220, 200, 80), weapon=(150, 150, 160), shield=(140, 60, 50))


def cursed_seer():
    return _wisp(14, 16, (200, 140, 255), (110, 60, 150))


def horse_soldier():
    return _warrior(16, 22, _c(205, 160, 120), _c(150, 110, 70), _c(100, 70, 40), _c(160, 160, 170), crest=(60, 80, 160), weapon=(150, 150, 160))


def floor_troy():
    return _floor(641, (112, 96, 80), 5, [(6, (92, 78, 64, 255), 4), (5, (150, 130, 106, 255), 2), (3, (160, 80, 200, 255), 1)])


# ---- 65 코로니스의 까마귀
def coronis_raven():
    """코로니스의 까마귀 (44x34): 반은 흰 깃, 반은 검은 깃"""
    img = canvas(44, 34)
    _poly(img, [(0, 8), (18, 16), (18, 24), (3, 20)], _c(240, 240, 245))
    _poly(img, [(43, 8), (25, 16), (25, 24), (40, 20)], _c(30, 30, 40))
    ellipse(img, 22, 20, 7, 9, _c(60, 60, 70))
    rect(img, 15, 12, 21, 28, _c(230, 230, 235))
    ellipse(img, 22, 9, 5, 5, _c(40, 40, 50))
    _poly(img, [(25, 9), (31, 11), (25, 12)], _c(80, 80, 90))
    put(img, [(23, 8)], _c(255, 220, 80))
    rect(img, 19, 29, 19, 33, _c(60, 60, 60))
    rect(img, 25, 29, 25, 33, _c(60, 60, 60))
    return outline(img, (15, 15, 20, 255))


def black_crow():
    return _bird(14, 12, _c(40, 40, 50), _c(25, 25, 35), (255, 220, 80), (90, 90, 100))


def feather_shade():
    return _wisp(14, 14, (90, 90, 110), (30, 30, 40))


def crow_hunter():
    return _warrior(14, 20, _c(205, 160, 120), _c(60, 60, 70), _c(40, 40, 50), _c(50, 50, 60), weapon=(150, 110, 60))


def floor_raven_grove():
    return _floor(653, (70, 76, 64), 5, [(6, (54, 60, 50, 255), 4), (5, (100, 106, 90, 255), 2), (3, (240, 240, 240, 255), 1)])


# ---- 66 영웅 아킬레우스
def achilles():
    """영웅 아킬레우스 (34x44): 청동 갑옷, 말총 투구, 원형 방패"""
    img = _hero(34, 44, _c(215, 170, 130), _c(200, 160, 80), _c(140, 100, 40), _c(200, 160, 80), crest=(240, 240, 230), weapon=(130, 100, 60), shield=(200, 160, 80))
    put(img, [(13, 43), (14, 43)], _c(255, 80, 80))                         # 뒤꿈치
    return outline(img, (40, 25, 10, 255))


def myrmidon():
    return _warrior(16, 22, _c(205, 160, 120), _c(70, 70, 80), _c(40, 40, 50), _c(90, 90, 100), crest=(60, 60, 70), weapon=(150, 150, 160))


def myrmidon_shield():
    return _warrior(16, 22, _c(205, 160, 120), _c(70, 70, 80), _c(40, 40, 50), _c(90, 90, 100), crest=(200, 160, 80), shield=(90, 90, 100))


def greek_javelin():
    return _warrior(14, 20, _c(205, 160, 120), _c(160, 140, 100), _c(110, 90, 60), _c(160, 160, 170), weapon=(140, 110, 70))


def floor_troy_beach():
    return _floor(659, (190, 170, 120), 5, [(6, (170, 150, 100, 255), 4), (5, (210, 195, 150, 255), 2), (3, (90, 120, 160, 255), 1)])


# ---- 67 황금 손의 왕 미다스
def midas():
    """황금 손의 왕 미다스 (34x44): 보라 망토, 금관, 황금 손, 당나귀 귀"""
    img = _hero(34, 44, _c(215, 170, 130), _c(150, 60, 160), _c(100, 40, 110), _c(240, 200, 60), cape=(110, 40, 120))
    _poly(img, [(10, 6), (8, 0), (12, 4)], _c(160, 140, 130))              # 당나귀 귀
    _poly(img, [(23, 6), (25, 0), (21, 4)], _c(160, 140, 130))
    for x in (12, 16, 20):
        put(img, [(x, 3)], _c(255, 240, 120))
    ellipse(img, 4, 26, 3, 3, _c(255, 210, 60))                            # 황금 손
    ellipse(img, 29, 26, 3, 3, _c(255, 210, 60))
    return outline(img, (40, 20, 40, 255))


def golden_soldier():
    return _warrior(16, 22, _c(240, 200, 80), _c(230, 190, 60), _c(180, 140, 30), _c(240, 200, 60), crest=(255, 240, 150), weapon=(240, 200, 80), eye=(120, 80, 20))


def donkey_eared_servant():
    img = _warrior(14, 20, _c(210, 165, 125), _c(150, 60, 160), _c(100, 40, 110), _c(160, 140, 130))
    put(img, [(4, 0), (9, 0)], _c(160, 140, 130))
    return img


def golden_reed_sprite():
    return _wisp(14, 16, (255, 240, 150), (200, 170, 60))


def floor_pactolus():
    return _floor(661, (130, 112, 70), 5, [(6, (110, 94, 56, 255), 4), (5, (170, 150, 90, 255), 2), (4, (250, 210, 80, 255), 1)])


# ---- 68 트로이의 영웅 헥토르
def hector():
    """트로이의 영웅 헥토르 (34x44): 빛나는 투구, 붉은 망토, 창과 방패"""
    return outline(_hero(34, 44, _c(210, 165, 125), _c(170, 140, 90), _c(120, 95, 60), _c(220, 200, 120), crest=(200, 40, 40), cape=(160, 40, 40),
                         weapon=(130, 100, 60), shield=(160, 40, 40)), (40, 15, 10, 255))


def light_altar():
    """빛의 제단 (18x18)"""
    img = canvas(18, 18)
    rect(img, 3, 9, 14, 17, _c(220, 210, 180))
    rect(img, 2, 7, 15, 9, _c(240, 230, 200))
    ellipse(img, 8.5, 4, 3, 3, _c(255, 240, 160))
    put(img, [(8, 3)], _c(255, 255, 255))
    return outline(img)


def trojan_guard():
    return _warrior(16, 22, _c(210, 165, 125), _c(160, 40, 40), _c(110, 25, 25), _c(220, 200, 120), crest=(200, 40, 40), weapon=(150, 150, 160), shield=(160, 40, 40))


def trojan_archer():
    return _warrior(14, 20, _c(210, 165, 125), _c(160, 120, 80), _c(110, 80, 50), _c(170, 60, 50), weapon=(160, 110, 60))


def trojan_charioteer():
    """트로이 전차병 (20x18)"""
    img = canvas(20, 18)
    rect(img, 2, 9, 13, 13, _c(170, 130, 60))
    ellipse(img, 5, 14, 3, 3, _c(120, 90, 40))
    ellipse(img, 11, 14, 3, 3, _c(120, 90, 40))
    rect(img, 6, 2, 9, 9, _c(160, 40, 40))
    ellipse(img, 7.5, 1.5, 1.6, 1.6, _c(210, 165, 125))
    ellipse(img, 17, 10, 2.5, 3, _c(140, 100, 70))
    return outline(img)


def floor_troy_wall():
    return _floor(673, (140, 120, 96), 5, [(6, (120, 100, 78, 255), 4), (5, (176, 156, 128, 255), 2), (3, (200, 50, 50, 255), 1)])


# ---- 69 델포이의 여사제 피티아
def pythia():
    """델포이의 여사제 피티아 (32x44): 보랏빛 베일, 월계수, 연기"""
    img = _hero(32, 44, _c(220, 180, 150), _c(120, 90, 170), _c(80, 60, 120), _c(150, 130, 190), cape=(90, 70, 140))
    for x in (10, 13, 18, 21):
        put(img, [(x, 4)], _c(90, 160, 70))
    put(img, [(13, 11), (18, 11)], _c(230, 220, 255))
    for x, y in ((6, 6), (25, 4), (27, 10), (4, 12)):
        put(img, [(x, y)], (220, 210, 255, 180))
    return outline(img, (30, 20, 40, 255))


def tripod():
    """신탁의 삼발이 (18x22)"""
    img = canvas(18, 22)
    ellipse(img, 9, 6, 7, 3, _c(200, 160, 80))
    _line(img, (3, 7), (1, 21), _c(170, 130, 60))
    _line(img, (15, 7), (17, 21), _c(170, 130, 60))
    _line(img, (9, 9), (9, 21), _c(170, 130, 60))
    for x, y in ((7, 2), (10, 1), (12, 3)):
        put(img, [(x, y)], (220, 210, 255, 200))
    return outline(img)


def oracle_guard():
    return _warrior(16, 22, _c(210, 165, 125), _c(240, 235, 220), _c(190, 180, 160), _c(220, 200, 120), crest=(90, 160, 70), weapon=(150, 150, 160), shield=(240, 235, 220))


def smoke_maiden():
    return _wisp(14, 16, (240, 230, 255), (140, 120, 180))


def delphi_pilgrim():
    return _warrior(14, 20, _c(210, 165, 125), _c(170, 160, 140), _c(120, 110, 90), _c(90, 160, 70))


def floor_delphi_temple():
    return _floor(683, (150, 140, 128), 5, [(6, (130, 120, 108, 255), 4), (5, (190, 180, 166, 255), 2), (3, (150, 120, 200, 255), 1)])


# ---- 70 태양의 신 아폴론
def apollo():
    """태양의 신 아폴론 (40x54): 금빛 머리, 월계관, 흰 옷, 은빛 활, 등 뒤의 햇무리"""
    img = canvas(40, 54)
    for i in range(16):                                    # 햇무리
        a = math.tau * i / 16
        put(img, [(int(20 + 16 * math.cos(a)), int(14 + 14 * math.sin(a)))], _c(255, 220, 100))
    hero = _hero(34, 44, _c(230, 190, 150), _c(245, 240, 230), _c(210, 200, 180), _c(255, 210, 80), cape=(255, 190, 70), bow=(210, 215, 230))
    img.alpha_composite(hero, (3, 10))
    for x in (12, 15, 19, 22):
        put(img, [(x + 3, 13)], _c(90, 170, 70))
    return outline(img, (60, 40, 10, 255))


def temple_guardian():
    return _warrior(16, 22, _c(210, 165, 125), _c(240, 220, 160), _c(200, 170, 100), _c(255, 210, 80), crest=(255, 240, 180), weapon=(230, 200, 100), shield=(255, 210, 80))


def helios_priest():
    return _warrior(14, 20, _c(210, 165, 125), _c(255, 230, 170), _c(220, 180, 100), _c(255, 210, 80), weapon=(255, 220, 120))


def light_wisp():
    return _wisp(14, 14, (255, 255, 220), (255, 210, 90))


def plague_arrow():
    """역병의 화살 (14x5)"""
    img = canvas(14, 5)
    rect(img, 0, 2, 10, 2, _c(200, 205, 220))
    _poly(img, [(10, 0), (13, 2), (10, 4)], _c(140, 200, 80))
    put(img, [(1, 1), (1, 3), (2, 1), (2, 3)], _c(120, 160, 60))
    return outline(img, (30, 40, 20, 255))


def floor_sun_temple():
    return _floor(691, (200, 176, 120), 5, [(6, (180, 156, 100, 255), 4), (5, (230, 210, 160, 255), 2), (4, (255, 220, 100, 255), 1)])


def save_late18_sprites():
    for name, painter in (("eurytus", eurytus), ("archery_target", archery_target), ("oechalia_archer", oechalia_archer), ("oechalia_spearman", oechalia_spearman),
                          ("oechalia_hound", oechalia_hound), ("python_serpent", python_serpent), ("laurel_branch", laurel_branch), ("delphi_viper", delphi_viper),
                          ("oracle_fume", oracle_fume), ("python_spawn", python_spawn), ("phaethon", phaethon), ("rein_pillar", rein_pillar),
                          ("flame_horse", flame_horse), ("burning_charioteer", burning_charioteer), ("ember_sprite", ember_sprite), ("cassandra", cassandra),
                          ("trojan_sentry", trojan_sentry), ("cursed_seer", cursed_seer), ("horse_soldier", horse_soldier), ("coronis_raven", coronis_raven),
                          ("black_crow", black_crow), ("feather_shade", feather_shade), ("crow_hunter", crow_hunter), ("achilles", achilles),
                          ("myrmidon", myrmidon), ("myrmidon_shield", myrmidon_shield), ("greek_javelin", greek_javelin), ("midas", midas),
                          ("golden_soldier", golden_soldier), ("donkey_eared_servant", donkey_eared_servant), ("golden_reed_sprite", golden_reed_sprite),
                          ("hector", hector), ("light_altar", light_altar), ("trojan_guard", trojan_guard), ("trojan_archer", trojan_archer),
                          ("trojan_charioteer", trojan_charioteer), ("pythia", pythia), ("tripod", tripod), ("oracle_guard", oracle_guard),
                          ("smoke_maiden", smoke_maiden), ("delphi_pilgrim", delphi_pilgrim), ("apollo", apollo), ("temple_guardian", temple_guardian),
                          ("helios_priest", helios_priest), ("light_wisp", light_wisp)):
        save(painter(), "characters", f"{name}.png")
    save(plague_arrow(), "projectiles", "plague_arrow.png")
    for name, painter in (("floor_oechalia", floor_oechalia), ("floor_delphi_cleft", floor_delphi_cleft), ("floor_sun_road", floor_sun_road),
                          ("floor_troy", floor_troy), ("floor_raven_grove", floor_raven_grove), ("floor_troy_beach", floor_troy_beach),
                          ("floor_pactolus", floor_pactolus), ("floor_troy_wall", floor_troy_wall), ("floor_delphi_temple", floor_delphi_temple),
                          ("floor_sun_temple", floor_sun_temple)):
        save(painter(), "tiles", f"{name}.png")


# ---------------------------------------------------------------- 71~80스테이지 (아테나와 아테네로 가는 길)
def _sea_serpent(w, h, body, body_d, belly, eye):
    img = canvas(w, h)
    for i in range(9):                                    # 물 위로 솟은 몸 고리
        x = 6 + i * (w - 16) // 8
        y = h - 8 + int(round(3 * math.sin(i * 1.1)))
        ellipse(img, x, y, 4, 3, body_d if i % 2 else body)
    rect(img, w - 16, 10, w - 10, h - 10, body)
    for y in range(12, h - 10, 3):
        put(img, [(w - 13, y)], belly)
    ellipse(img, w - 10, 9, 7, 5, body)
    put(img, [(w - 8, 7)], _c(*eye))
    _line(img, (w - 3, 10), (w - 1, 12), _c(220, 60, 60))
    for x in range(4, w - 4, 6):                          # 물결
        put(img, [(x, h - 2), (x + 1, h - 3)], _c(150, 200, 240))
    return outline(img, (10, 25, 30, 255))


def laocoon_serpent():
    """바다뱀 포르케스 (48x40): 청록 비늘"""
    return _sea_serpent(48, 40, _c(40, 120, 120), _c(25, 80, 85), _c(200, 220, 180), (255, 220, 60))


def laocoon_serpent_twin():
    """바다뱀 카리보이아 (40x34): 짙은 남색 비늘"""
    return _sea_serpent(40, 34, _c(50, 70, 140), _c(30, 45, 100), _c(190, 200, 230), (255, 90, 60))


def serpent_hatchling():
    img = canvas(18, 12)
    for i in range(14):
        x = 2 + i
        y = 7 + int(round(2 * math.sin(i * 0.8)))
        rect(img, x, y - 1, x, y, _c(40, 120, 120) if i % 3 else _c(25, 80, 85))
    ellipse(img, 15, 4, 2.5, 2, _c(50, 130, 130))
    put(img, [(16, 3)], _c(255, 220, 60))
    return outline(img)


def trojan_priest():
    return _warrior(14, 20, _c(210, 165, 125), _c(240, 235, 225), _c(190, 180, 160), _c(200, 60, 60))


def beach_crab():
    """해변 게 (18x12)"""
    img = canvas(18, 12)
    ellipse(img, 9, 7, 6, 3.5, _c(200, 80, 50))
    ellipse(img, 3, 4, 2, 2, _c(220, 100, 60))
    ellipse(img, 15, 4, 2, 2, _c(220, 100, 60))
    for x in (4, 6, 12, 14):
        put(img, [(x, 10), (x, 11)], _c(160, 60, 40))
    put(img, [(7, 4), (11, 4)], _c(20, 20, 20))
    return outline(img)


def floor_troy_shore():
    return _floor(701, (176, 160, 120), 5, [(6, (156, 140, 100, 255), 4), (5, (200, 186, 150, 255), 2), (3, (60, 120, 150, 255), 1)])


# ---- 72 트로이 목마
def trojan_horse():
    """트로이 목마 (56x56): 거대한 나무 말, 배 아래 해치, 바퀴 받침"""
    img = canvas(56, 56)
    wood, wood_d, wood_l = _c(160, 115, 65), _c(115, 80, 45), _c(195, 150, 95)
    rect(img, 6, 42, 50, 46, wood_d)                        # 받침대
    for x in (9, 18, 37, 46):
        rect(img, x, 30, x + 3, 42, wood)                   # 다리
    ellipse(img, 28, 26, 20, 9, wood)                      # 몸통
    for x in range(12, 46, 5):
        rect(img, x, 19, x, 33, wood_d)
    rect(img, 22, 32, 33, 35, _c(80, 55, 30))               # 해치
    rect(img, 40, 6, 47, 22, wood)                          # 목
    ellipse(img, 47, 6, 7, 5, wood)                         # 머리
    put(img, [(49, 4)], _c(30, 20, 10))
    for y in range(4, 18, 2):
        put(img, [(39, y)], wood_l)                         # 갈기
    rect(img, 3, 18, 8, 20, wood_d)                         # 꼬리
    return outline(img, (40, 25, 10, 255))


def horse_wheel():
    """목마의 바퀴 (14x14)"""
    img = canvas(14)
    ellipse(img, 7, 7, 6, 6, _c(120, 85, 45))
    ellipse(img, 7, 7, 4, 4, _c(160, 115, 65))
    _line(img, (2, 7), (12, 7), _c(90, 60, 30))
    _line(img, (7, 2), (7, 12), _c(90, 60, 30))
    ellipse(img, 7, 7, 1.5, 1.5, _c(70, 50, 30))
    return outline(img)


def horse_hatch():
    """열린 해치 (16x10)"""
    img = canvas(16, 10)
    rect(img, 1, 1, 14, 8, _c(40, 25, 15))
    rect(img, 1, 1, 14, 2, _c(160, 115, 65))
    put(img, [(5, 5), (10, 5)], _c(255, 220, 120))
    return outline(img)


def greek_raider():
    return _warrior(16, 22, _c(205, 160, 120), _c(150, 110, 70), _c(100, 70, 40), _c(160, 160, 170), crest=(60, 80, 160), weapon=(150, 150, 160))


def greek_hoplite():
    return _warrior(16, 22, _c(205, 160, 120), _c(190, 160, 80), _c(130, 100, 40), _c(190, 160, 80), crest=(60, 80, 160), weapon=(150, 150, 160), shield=(60, 80, 160))


def torch_bearer():
    img = _warrior(14, 20, _c(205, 160, 120), _c(120, 100, 80), _c(80, 60, 40), _c(110, 90, 60))
    put(img, [(12, 1), (12, 2), (13, 1)], _c(255, 160, 50))
    return img


def floor_troy_gate():
    return _floor(709, (130, 112, 90), 5, [(6, (110, 92, 72, 255), 4), (5, (166, 146, 120, 255), 2), (3, (255, 150, 60, 255), 1)])


# ---- 73 영웅 디오메데스
def diomedes():
    """영웅 디오메데스 (34x44): 은빛 갑옷, 사자 가죽 망토, 창"""
    return outline(_hero(34, 44, _c(210, 165, 125), _c(190, 195, 205), _c(130, 135, 150), _c(190, 195, 205), crest=(60, 80, 160), cape=(170, 130, 70),
                         weapon=(130, 100, 60), shield=(190, 195, 205)), (30, 30, 40, 255))


def athena_lamp():
    """아테나의 등불 (12x16)"""
    img = canvas(12, 16)
    rect(img, 4, 8, 7, 15, _c(200, 160, 80))
    ellipse(img, 5.5, 6, 4, 3, _c(220, 180, 90))
    ellipse(img, 5.5, 3, 2, 3, _c(255, 230, 120))
    put(img, [(5, 1)], _c(255, 255, 220))
    return outline(img)


def argive_spearman():
    return _warrior(16, 22, _c(205, 160, 120), _c(190, 195, 205), _c(130, 135, 150), _c(160, 160, 170), crest=(60, 80, 160), weapon=(150, 150, 160))


def fog_wraith():
    return _wisp(16, 16, (220, 225, 235), (140, 150, 170))


def argive_horse():
    return _beast(20, 14, _c(230, 225, 215), _c(170, 165, 155), (40, 40, 60), mane=(120, 110, 100))


def floor_foggy_field():
    return _floor(719, (110, 116, 112), 5, [(6, (92, 98, 94, 255), 4), (5, (140, 146, 142, 255), 2), (3, (210, 215, 220, 255), 1)])


# ---- 74 페가수스를 탄 벨레로폰
def bellerophon():
    """페가수스를 탄 벨레로폰 (52x44): 흰 날개 말 위의 영웅"""
    img = canvas(52, 44)
    _poly(img, [(14, 18), (2, 2), (10, 4), (22, 16)], _c(245, 245, 250))      # 날개
    _poly(img, [(22, 18), (20, 0), (28, 6), (30, 18)], _c(230, 235, 245))
    ellipse(img, 24, 28, 14, 7, _c(240, 240, 245))                            # 말 몸통
    rect(img, 34, 16, 39, 28, _c(240, 240, 245))
    ellipse(img, 41, 15, 6, 4, _c(240, 240, 245))
    put(img, [(43, 14)], _c(30, 30, 40))
    for x in (14, 18, 29, 33):
        rect(img, x, 33, x + 1, 42, _c(210, 210, 220))
    rect(img, 20, 12, 27, 22, _c(60, 90, 170))                               # 기수
    ellipse(img, 23.5, 9, 3.5, 3.5, _c(210, 165, 125))
    rect(img, 20, 5, 27, 7, _c(200, 170, 80))
    rect(img, 29, 2, 30, 24, _c(130, 100, 60))                               # 창
    put(img, [(29, 0), (30, 0), (30, 1)], _c(230, 230, 240))
    _line(img, (36, 18), (26, 16), _c(255, 210, 60))                          # 고삐
    return outline(img, (40, 40, 60, 255))


def golden_bridle():
    """황금 굴레 (16x12)"""
    img = canvas(16, 12)
    ellipse(img, 7, 6, 6, 4, _c(240, 200, 60))
    ellipse(img, 7, 6, 4, 2, (0, 0, 0, 0))
    _line(img, (12, 6), (15, 2), _c(240, 200, 60))
    put(img, [(3, 4), (11, 8)], _c(255, 245, 170))
    return outline(img, (90, 60, 10, 255))


def chimera_cub():
    return _beast(18, 13, _c(220, 160, 70), _c(170, 110, 40), (255, 80, 40), mane=(200, 90, 40))


def solymi_warrior():
    return _warrior(16, 22, _c(190, 140, 100), _c(120, 90, 60), _c(80, 60, 40), _c(140, 110, 70), crest=(200, 60, 40), weapon=(140, 110, 70))


def lycian_archer():
    return _warrior(14, 20, _c(205, 160, 120), _c(80, 120, 140), _c(50, 80, 100), _c(120, 140, 160), weapon=(160, 110, 60))


def floor_lycia_sky():
    return _floor(727, (150, 170, 190), 5, [(6, (130, 150, 172, 255), 4), (5, (190, 205, 220, 255), 2), (3, (255, 255, 255, 255), 1)])


# ---- 75 큰 아이아스
def ajax():
    """큰 아이아스 (36x46): 거구, 일곱 겹 소가죽 탑 방패"""
    img = _hero(36, 46, _c(205, 160, 120), _c(150, 120, 80), _c(100, 80, 50), _c(170, 160, 140), crest=(220, 220, 210), weapon=(130, 100, 60))
    rect(img, 0, 12, 10, 40, _c(150, 110, 70))                              # 탑 방패
    for y in range(14, 40, 4):
        rect(img, 0, y, 10, y, _c(110, 80, 50))
    rect(img, 4, 12, 6, 40, _c(190, 160, 90))
    return outline(img, (30, 20, 10, 255))


def salamis_shield():
    return _warrior(16, 22, _c(205, 160, 120), _c(150, 120, 80), _c(100, 80, 50), _c(170, 160, 140), crest=(220, 220, 210), shield=(150, 110, 70))


def salamis_slinger():
    return _warrior(14, 20, _c(205, 160, 120), _c(150, 140, 110), _c(100, 90, 70), _c(120, 110, 90))


def trojan_raider():
    return _warrior(16, 22, _c(210, 165, 125), _c(160, 40, 40), _c(110, 25, 25), _c(200, 160, 80), crest=(220, 200, 80), weapon=(150, 150, 160))


def floor_greek_camp():
    return _floor(733, (150, 130, 100), 5, [(6, (130, 110, 82, 255), 4), (5, (186, 166, 130, 255), 2), (3, (120, 90, 60, 255), 1)])


# ---- 76 오디세우스
def odysseus():
    """오디세우스 (34x44): 뾰족한 여행자 모자, 붉은 망토, 큰 활"""
    img = _hero(34, 44, _c(205, 160, 120), _c(120, 90, 60), _c(80, 60, 40), _c(150, 110, 70), cape=(160, 50, 40), bow=(140, 100, 60))
    _poly(img, [(11, 6), (16, 0), (22, 6)], _c(150, 110, 70))
    put(img, [(14, 14), (15, 15), (18, 15), (19, 14)], _c(80, 60, 40))     # 수염
    return outline(img, (30, 20, 10, 255))


def odysseus_beggar():
    """거지로 변장한 오디세우스 (18x22)"""
    img = canvas(18, 22)
    _poly(img, [(4, 8), (13, 8), (15, 21), (2, 21)], _c(120, 105, 85))
    ellipse(img, 8.5, 5, 3.5, 3.5, _c(200, 160, 120))
    rect(img, 5, 1, 12, 2, _c(150, 140, 120))
    put(img, [(7, 5), (10, 5)], _c(60, 40, 30))
    rect(img, 15, 4, 15, 21, _c(110, 80, 50))
    return outline(img)


def bronze_axe():
    """열두 도끼 중 하나 (14x20)"""
    img = canvas(14, 20)
    rect(img, 6, 6, 7, 19, _c(120, 90, 50))
    _poly(img, [(1, 2), (6, 4), (6, 9), (1, 11)], _c(200, 160, 80))
    _poly(img, [(12, 2), (7, 4), (7, 9), (12, 11)], _c(200, 160, 80))
    ellipse(img, 6.5, 6.5, 1.5, 1.5, _c(30, 20, 10))                       # 구멍
    return outline(img)


def suitor():
    return _warrior(16, 22, _c(210, 165, 125), _c(150, 60, 120), _c(100, 40, 80), _c(90, 60, 40), weapon=(170, 170, 180))


def suitor_archer():
    return _warrior(14, 20, _c(210, 165, 125), _c(60, 120, 150), _c(40, 80, 110), _c(90, 60, 40), weapon=(160, 110, 60))


def circe_pig():
    return _beast(18, 12, _c(220, 160, 160), _c(180, 120, 120), (40, 30, 30))


def floor_ithaca_hall():
    return _floor(743, (120, 96, 72), 5, [(6, (100, 78, 56, 255), 4), (5, (160, 130, 96, 255), 2), (3, (200, 160, 80, 255), 1)])


# ---- 77 티데우스
def tydeus():
    """티데우스 (32x42): 작고 다부진 몸, 멧돼지 가죽 방패, 피 묻은 창"""
    img = _hero(32, 42, _c(200, 150, 110), _c(110, 80, 60), _c(80, 55, 40), _c(130, 100, 70), crest=(200, 50, 40), weapon=(130, 100, 60), shield=(110, 80, 60))
    put(img, [(28, 1), (28, 2)], _c(200, 40, 40))
    return outline(img, (40, 15, 10, 255))


def immortal_potion():
    """아테나의 불사의 약병 (10x14)"""
    img = canvas(10, 14)
    rect(img, 4, 0, 5, 3, _c(200, 170, 120))
    ellipse(img, 4.5, 8, 4, 5, _c(220, 230, 255))
    ellipse(img, 4.5, 9, 3, 3, _c(255, 230, 120))
    put(img, [(3, 7)], _c(255, 255, 255))
    return outline(img, (60, 50, 80, 255))


def theban_warrior():
    return _warrior(16, 22, _c(205, 160, 120), _c(90, 120, 80), _c(60, 80, 50), _c(160, 160, 170), crest=(200, 200, 80), weapon=(150, 150, 160))


def theban_archer():
    return _warrior(14, 20, _c(205, 160, 120), _c(90, 120, 80), _c(60, 80, 50), _c(110, 90, 60), weapon=(160, 110, 60))


def theban_hound():
    return _beast(18, 12, _c(140, 110, 80), _c(100, 75, 50), (255, 200, 80))


def floor_thebes_gate():
    return _floor(751, (124, 116, 96), 5, [(6, (104, 96, 78, 255), 4), (5, (160, 150, 126, 255), 2), (3, (150, 40, 40, 255), 1)])


# ---- 78 아테나의 올빼미 글라우크스
def glaukos():
    """아테나의 올빼미 글라우크스 (44x38): 커다란 금빛 눈, 회색 깃"""
    img = canvas(44, 38)
    _poly(img, [(0, 14), (14, 18), (14, 30), (3, 26)], _c(120, 115, 105))
    _poly(img, [(43, 14), (29, 18), (29, 30), (40, 26)], _c(120, 115, 105))
    ellipse(img, 22, 22, 11, 13, _c(150, 140, 125))
    for y in range(18, 34, 3):
        for x in range(15, 30, 4):
            put(img, [(x, y)], _c(220, 210, 190))
    ellipse(img, 22, 10, 10, 8, _c(150, 140, 125))
    _poly(img, [(13, 4), (15, 0), (17, 4)], _c(120, 115, 105))
    _poly(img, [(27, 4), (29, 0), (31, 4)], _c(120, 115, 105))
    ellipse(img, 18, 10, 3.5, 3.5, _c(255, 210, 60))
    ellipse(img, 26, 10, 3.5, 3.5, _c(255, 210, 60))
    put(img, [(18, 10), (26, 10)], _c(20, 20, 20))
    _poly(img, [(21, 12), (23, 12), (22, 15)], _c(80, 70, 60))
    rect(img, 18, 35, 19, 37, _c(200, 170, 80))
    rect(img, 25, 35, 26, 37, _c(200, 170, 80))
    return outline(img, (25, 25, 30, 255))


def night_owl():
    return _bird(14, 12, _c(110, 105, 95), _c(140, 135, 120), (255, 210, 60), (80, 70, 60))


def shadow_scout():
    return _warrior(14, 20, _c(180, 150, 120), _c(50, 50, 60), _c(30, 30, 40), _c(40, 40, 50), weapon=(120, 120, 130), eye=(255, 210, 60))


def dark_sprite():
    return _wisp(14, 14, (120, 110, 160), (40, 30, 70))


def floor_owl_night():
    return _floor(761, (60, 62, 78), 5, [(6, (46, 48, 62, 255), 4), (5, (80, 82, 100, 255), 2), (3, (200, 180, 100, 255), 1)])


# ---- 79 아크로폴리스의 청동 수호상
def bronze_statue():
    """아크로폴리스의 청동 수호상 (44x62): 투구, 거대한 창, 둥근 방패"""
    img = canvas(44, 62)
    br, br_d, br_l = _c(170, 130, 70), _c(110, 80, 40), _c(210, 170, 100)
    rect(img, 10, 56, 34, 61, _c(180, 175, 165))                          # 받침돌
    rect(img, 16, 40, 20, 56, br_d)
    rect(img, 24, 40, 28, 56, br_d)
    _poly(img, [(12, 20), (32, 20), (34, 44), (10, 44)], br)              # 긴 옷
    for x in (15, 19, 23, 27, 31):
        rect(img, x, 28, x, 44, br_d)
    ellipse(img, 22, 13, 6, 6, br)
    rect(img, 15, 4, 29, 9, br_l)
    for i in range(10):
        rect(img, 17 + i, 0 + (1 if i in (0, 9) else 0), 17 + i, 3, br_l)  # 투구 깃
    put(img, [(19, 13), (24, 13)], _c(90, 255, 220))
    rect(img, 38, 0, 39, 52, br_d)                                        # 창
    _poly(img, [(36, 4), (38, 0), (40, 0), (42, 4)], br_l)
    ellipse(img, 6, 32, 6, 9, br_l)                                       # 방패
    ellipse(img, 6, 32, 3, 5, br)
    return outline(img, (40, 25, 10, 255))


def bronze_hoplite():
    return _warrior(16, 22, _c(170, 130, 70), _c(170, 130, 70), _c(110, 80, 40), _c(210, 170, 100), crest=(210, 170, 100), weapon=(110, 80, 40), shield=(170, 130, 70), eye=(90, 255, 220))


def acropolis_archer():
    return _warrior(14, 20, _c(205, 160, 120), _c(230, 225, 210), _c(180, 170, 150), _c(200, 170, 90), weapon=(160, 110, 60))


def bronze_owl():
    return _bird(14, 12, _c(170, 130, 70), _c(210, 170, 100), (90, 255, 220), (110, 80, 40))


def floor_acropolis():
    return _floor(769, (180, 176, 166), 5, [(6, (160, 156, 146, 255), 4), (5, (210, 206, 196, 255), 2), (3, (200, 160, 80, 255), 1)])


# ---- 80 지혜의 신 아테나
def athena():
    """지혜의 신 아테나 (40x54): 높은 깃 투구, 푸른 옷, 창과 방패, 어깨의 올빼미"""
    img = canvas(40, 54)
    hero = _hero(34, 44, _c(225, 185, 150), _c(70, 100, 170), _c(45, 70, 130), _c(210, 180, 90), crest=(230, 230, 240), cape=(230, 225, 210),
                 weapon=(200, 190, 170), shield=(210, 180, 90))
    img.alpha_composite(hero, (3, 10))
    for i in range(12):                                     # 높은 투구 깃
        rect(img, 13 + i, 4 + abs(i - 6) // 2, 13 + i, 12, _c(230, 230, 240))
    ellipse(img, 31, 18, 3, 3, _c(150, 140, 125))           # 어깨의 올빼미
    put(img, [(30, 17), (32, 17)], _c(255, 210, 60))
    return outline(img, (25, 25, 50, 255))


def athena_hoplite():
    return _warrior(16, 22, _c(205, 160, 120), _c(70, 100, 170), _c(45, 70, 130), _c(210, 180, 90), crest=(230, 230, 240), weapon=(200, 190, 170), shield=(210, 180, 90))


def phalanx_shield():
    """팔랑크스 방패병 (18x22): 커다란 둥근 방패를 앞세운 호플리테스"""
    img = _warrior(18, 22, _c(205, 160, 120), _c(70, 100, 170), _c(45, 70, 130), _c(210, 180, 90), crest=(230, 230, 240))
    ellipse(img, 9, 14, 7, 7, _c(210, 180, 90))
    ellipse(img, 9, 14, 3, 3, _c(70, 100, 170))
    return outline(img)


def wisdom_owl():
    return _bird(14, 12, _c(150, 140, 125), _c(200, 190, 170), (255, 210, 60), (90, 80, 70))


def athena_apostle():
    return _warrior(14, 20, _c(220, 180, 150), _c(230, 225, 210), _c(180, 170, 150), _c(90, 160, 70), weapon=(200, 190, 170))


def owl_feather():
    """지혜의 깃 (12x6)"""
    img = canvas(12, 6)
    _poly(img, [(0, 3), (8, 0), (11, 3), (8, 5)], _c(200, 190, 170))
    _line(img, (1, 3), (10, 3), _c(110, 100, 90))
    return outline(img, (40, 40, 50, 255))


def floor_parthenon():
    return _floor(787, (206, 200, 186), 5, [(6, (186, 180, 166, 255), 4), (5, (230, 226, 214, 255), 2), (3, (90, 120, 180, 255), 1)])


def save_late19_sprites():
    for name, painter in (("laocoon_serpent", laocoon_serpent), ("laocoon_serpent_twin", laocoon_serpent_twin), ("serpent_hatchling", serpent_hatchling),
                          ("trojan_priest", trojan_priest), ("beach_crab", beach_crab), ("trojan_horse", trojan_horse), ("horse_wheel", horse_wheel),
                          ("horse_hatch", horse_hatch), ("greek_raider", greek_raider), ("greek_hoplite", greek_hoplite), ("torch_bearer", torch_bearer),
                          ("diomedes", diomedes), ("athena_lamp", athena_lamp), ("argive_spearman", argive_spearman), ("fog_wraith", fog_wraith),
                          ("argive_horse", argive_horse), ("bellerophon", bellerophon), ("golden_bridle", golden_bridle), ("chimera_cub", chimera_cub),
                          ("solymi_warrior", solymi_warrior), ("lycian_archer", lycian_archer), ("ajax", ajax), ("salamis_shield", salamis_shield),
                          ("salamis_slinger", salamis_slinger), ("trojan_raider", trojan_raider), ("odysseus", odysseus), ("odysseus_beggar", odysseus_beggar),
                          ("bronze_axe", bronze_axe), ("suitor", suitor), ("suitor_archer", suitor_archer), ("circe_pig", circe_pig), ("tydeus", tydeus),
                          ("immortal_potion", immortal_potion), ("theban_warrior", theban_warrior), ("theban_archer", theban_archer),
                          ("theban_hound", theban_hound), ("glaukos", glaukos), ("night_owl", night_owl), ("shadow_scout", shadow_scout),
                          ("dark_sprite", dark_sprite), ("bronze_statue", bronze_statue), ("bronze_hoplite", bronze_hoplite),
                          ("acropolis_archer", acropolis_archer), ("bronze_owl", bronze_owl), ("athena", athena), ("athena_hoplite", athena_hoplite),
                          ("phalanx_shield", phalanx_shield), ("wisdom_owl", wisdom_owl), ("athena_apostle", athena_apostle)):
        save(painter(), "characters", f"{name}.png")
    save(owl_feather(), "projectiles", "owl_feather.png")
    for name, painter in (("floor_troy_shore", floor_troy_shore), ("floor_troy_gate", floor_troy_gate), ("floor_foggy_field", floor_foggy_field),
                          ("floor_lycia_sky", floor_lycia_sky), ("floor_greek_camp", floor_greek_camp), ("floor_ithaca_hall", floor_ithaca_hall),
                          ("floor_thebes_gate", floor_thebes_gate), ("floor_owl_night", floor_owl_night), ("floor_acropolis", floor_acropolis),
                          ("floor_parthenon", floor_parthenon)):
        save(painter(), "tiles", f"{name}.png")


# ---------------------------------------------------------------- 81~90스테이지 (대죄의 마왕 → 묵시록 → 무저갱)
def _demon(w, h, skin, skin_d, cloth, horn, eye, wings=None, belly=None):
    """마왕 공용 몸통 (뿔 · 날개)"""
    rgba = lambda c: tuple(c) if len(c) == 4 else _c(*c)
    horn, eye = rgba(horn), rgba(eye)
    img = canvas(w, h)
    cx = w // 2
    if wings:
        _poly(img, [(cx - 6, 18), (1, 6), (4, 24), (cx - 6, 28)], rgba(wings))
        _poly(img, [(cx + 5, 18), (w - 2, 6), (w - 5, 24), (cx + 5, 28)], rgba(wings))
    rect(img, cx - 7, h - 14, cx - 3, h - 1, skin_d)
    rect(img, cx + 2, h - 14, cx + 6, h - 1, skin_d)
    ellipse(img, cx - 0.5, h * 0.55, w * 0.26, h * 0.22, skin)
    if belly:
        ellipse(img, cx - 0.5, h * 0.6, w * 0.16, h * 0.14, rgba(belly))
    rect(img, cx - 8, int(h * 0.62), cx + 7, int(h * 0.74), cloth)
    rect(img, 3, int(h * 0.36), 7, int(h * 0.62), skin_d)
    rect(img, w - 8, int(h * 0.36), w - 4, int(h * 0.62), skin_d)
    ellipse(img, cx - 0.5, h * 0.24, 6, 6, skin)
    _poly(img, [(cx - 6, int(h * 0.18)), (cx - 10, int(h * 0.04)), (cx - 4, int(h * 0.14))], horn)
    _poly(img, [(cx + 5, int(h * 0.18)), (cx + 9, int(h * 0.04)), (cx + 3, int(h * 0.14))], horn)
    put(img, [(cx - 3, int(h * 0.23)), (cx + 2, int(h * 0.23))], eye)
    return img


# ---- 81 탐욕의 마왕 마몬
def mammon():
    """탐욕의 마왕 마몬 (40x50): 금빛 피부, 금관, 금화 자루"""
    img = _demon(40, 50, _c(200, 160, 70), _c(150, 110, 40), _c(120, 40, 40), _c(240, 220, 120), (255, 60, 40), belly=(230, 190, 90))
    rect(img, 15, 4, 24, 7, _c(255, 220, 80))
    for x in (15, 19, 23):
        put(img, [(x, 2), (x, 3)], _c(255, 230, 120))
    ellipse(img, 33, 36, 5, 6, _c(150, 110, 60))
    for x, y in ((31, 31), (34, 30), (36, 33)):
        put(img, [(x, y)], _c(255, 220, 80))
    return outline(img, (50, 30, 10, 255))


def coin_pile():
    """금화 더미 (16x12)"""
    img = canvas(16, 12)
    ellipse(img, 8, 8, 7, 4, _c(220, 170, 50))
    ellipse(img, 8, 6, 5, 3, _c(245, 200, 70))
    for x, y in ((5, 5), (9, 4), (11, 7), (6, 8)):
        put(img, [(x, y)], _c(255, 245, 170))
    return outline(img, (90, 60, 10, 255))


def greed_imp():
    return _wisp(14, 14, (255, 220, 100), (160, 110, 30))


def gilded_thief():
    return _warrior(14, 20, _c(200, 160, 120), _c(90, 60, 40), _c(60, 40, 30), _c(220, 180, 60), weapon=(220, 180, 70))


def treasure_mimic():
    """보물 상자 미믹 (18x14)"""
    img = canvas(18, 14)
    rect(img, 1, 5, 16, 13, _c(140, 90, 40))
    rect(img, 1, 1, 16, 5, _c(170, 115, 55))
    rect(img, 1, 5, 16, 6, _c(220, 180, 70))
    for x in (4, 7, 10, 13):
        put(img, [(x, 6), (x, 7)], _c(240, 240, 230))
    put(img, [(6, 3), (11, 3)], _c(255, 60, 40))
    return outline(img)


def floor_greed_vault():
    return _floor(811, (110, 86, 50), 5, [(6, (92, 70, 40, 255), 4), (5, (150, 120, 70, 255), 2), (4, (255, 210, 70, 255), 1)])


# ---- 82 나태의 마왕 벨페고르
def belphegor():
    """나태의 마왕 벨페고르 (44x40): 옥좌 겸 변기에 늘어진 뚱뚱한 악마"""
    img = canvas(44, 40)
    rect(img, 6, 22, 37, 39, _c(90, 70, 60))                  # 늘어진 의자
    rect(img, 4, 18, 8, 39, _c(70, 55, 45))
    rect(img, 35, 18, 39, 39, _c(70, 55, 45))
    ellipse(img, 22, 24, 13, 11, _c(150, 110, 130))
    ellipse(img, 22, 27, 9, 7, _c(180, 140, 160))
    ellipse(img, 22, 10, 7, 6, _c(150, 110, 130))
    _poly(img, [(16, 7), (12, 0), (18, 5)], _c(220, 210, 190))
    _poly(img, [(28, 7), (32, 0), (26, 5)], _c(220, 210, 190))
    rect(img, 18, 9, 20, 9, _c(30, 20, 30))                   # 감긴 눈
    rect(img, 24, 9, 26, 9, _c(30, 20, 30))
    put(img, [(22, 13), (21, 14), (23, 14)], _c(90, 50, 70))
    return outline(img, (30, 20, 30, 255))


def sloth_wisp():
    return _wisp(14, 14, (200, 190, 230), (110, 100, 140))


def drowsy_ghoul():
    return _warrior(16, 22, _c(150, 140, 150), _c(90, 80, 100), _c(60, 55, 70), _c(80, 70, 90), eye=(200, 200, 255))


def snail_beast():
    """거대 달팽이 (18x12)"""
    img = canvas(18, 12)
    rect(img, 2, 8, 16, 11, _c(150, 140, 120))
    ellipse(img, 8, 6, 5, 5, _c(170, 110, 140))
    ellipse(img, 8, 6, 2.5, 2.5, _c(130, 80, 110))
    _line(img, (15, 7), (17, 3), _c(150, 140, 120))
    put(img, [(17, 2)], _c(40, 30, 30))
    return outline(img)


def floor_sloth_bog():
    return _floor(821, (90, 84, 100), 5, [(6, (74, 68, 84, 255), 4), (5, (120, 112, 134, 255), 2), (3, (160, 140, 200, 255), 1)])


# ---- 83 폭식의 마왕 바알제붑
def beelzebub():
    """폭식의 마왕 바알제붑 (46x44): 파리 머리, 거대한 배, 투명한 날개"""
    img = canvas(46, 44)
    _poly(img, [(18, 16), (2, 4), (6, 22)], (200, 220, 240, 170))
    _poly(img, [(28, 16), (44, 4), (40, 22)], (200, 220, 240, 170))
    ellipse(img, 23, 28, 14, 13, _c(70, 90, 50))
    ellipse(img, 23, 31, 10, 9, _c(110, 130, 70))
    ellipse(img, 23, 11, 8, 7, _c(40, 50, 40))
    ellipse(img, 19, 10, 3.5, 4, _c(180, 30, 30))            # 겹눈
    ellipse(img, 27, 10, 3.5, 4, _c(180, 30, 30))
    for x, y in ((18, 9), (20, 11), (26, 9), (28, 11)):
        put(img, [(x, y)], _c(255, 90, 90))
    rect(img, 22, 16, 23, 19, _c(30, 30, 30))
    rect(img, 15, 39, 18, 43, _c(50, 60, 40))
    rect(img, 28, 39, 31, 43, _c(50, 60, 40))
    return outline(img, (20, 25, 15, 255))


def fly_swarm():
    return _wisp(14, 14, (90, 100, 60), (30, 35, 25))


def glutton_ghoul():
    return _warrior(18, 22, _c(150, 160, 110), _c(110, 100, 70), _c(80, 70, 50), _c(90, 80, 60), eye=(255, 200, 60))


def maggot():
    """구더기 (16x10)"""
    img = canvas(16, 10)
    for i in range(5):
        ellipse(img, 3 + i * 2.6, 6, 2.6, 2.4, _c(230, 225, 200) if i % 2 else _c(210, 205, 180))
    put(img, [(14, 5)], _c(60, 40, 30))
    return outline(img)


def floor_glutton_hall():
    return _floor(829, (86, 92, 60), 5, [(6, (70, 76, 48, 255), 4), (5, (120, 126, 84, 255), 2), (3, (160, 60, 50, 255), 1)])


# ---- 84 색욕의 마왕 아스모데우스
def asmodeus():
    """색욕의 마왕 아스모데우스 (40x52): 진홍 피부, 박쥐 날개, 사슬"""
    img = _demon(40, 52, _c(190, 70, 90), _c(140, 40, 60), _c(60, 20, 40), _c(60, 40, 50), (255, 220, 120), wings=(90, 30, 60))
    for i in range(6):
        put(img, [(30 + i % 2, 30 + i * 2)], _c(200, 200, 210))
    return outline(img, (40, 10, 20, 255))


def chain_pillar():
    """욕망의 사슬 기둥 (14x26)"""
    img = canvas(14, 26)
    rect(img, 4, 4, 9, 25, _c(90, 60, 80))
    rect(img, 3, 2, 10, 4, _c(120, 80, 110))
    for y in range(6, 24, 4):
        ellipse(img, 11, y, 2, 1.5, _c(200, 200, 210))
    put(img, [(6, 10), (6, 16)], _c(255, 120, 160))
    return outline(img)


def succubus_lancer():
    return _warrior(14, 20, _c(220, 160, 170), _c(130, 40, 80), _c(90, 25, 60), _c(60, 40, 50), weapon=(200, 200, 210))


def charm_wisp():
    return _wisp(14, 14, (255, 170, 210), (180, 60, 120))


def chain_hound():
    return _beast(18, 12, _c(120, 50, 70), _c(80, 30, 50), (255, 200, 120))


def floor_lust_palace():
    return _floor(839, (100, 60, 80), 5, [(6, (82, 46, 64, 255), 4), (5, (140, 86, 110, 255), 2), (3, (255, 150, 190, 255), 1)])


# ---- 85 묵시록의 네 기사
def _horseman(horse, horse_d, rider, eye, weapon):
    img = canvas(46, 44)
    ellipse(img, 21, 28, 14, 7, _c(*horse))
    rect(img, 31, 16, 36, 28, _c(*horse))
    ellipse(img, 38, 15, 6, 4, _c(*horse))
    put(img, [(40, 14)], _c(*eye))
    for x in (11, 15, 26, 30):
        rect(img, x, 33, x + 1, 43, _c(*horse_d))
    rect(img, 17, 10, 25, 22, _c(*rider))
    ellipse(img, 21, 7, 4, 4, _c(*rider))
    put(img, [(20, 6), (23, 6)], _c(*eye))
    if weapon:
        weapon(img)
    return img


def horseman_conquest():
    """흰 말의 기사 — 정복 (46x44): 활과 면류관"""
    def w(img):
        for y in range(2, 22):
            put(img, [(29 + int(round(2 * math.sin((y - 2) / 20 * math.pi))), y)], _c(220, 200, 120))
        rect(img, 18, 2, 24, 3, _c(255, 220, 80))
    return outline(_horseman((240, 240, 245), (200, 200, 210), (230, 230, 240), (80, 120, 255), w), (40, 40, 60, 255))


def horseman_war():
    """붉은 말의 기사 — 전쟁 (46x44): 큰 칼"""
    def w(img):
        _line(img, (26, 14), (34, 0), _c(220, 220, 230))
        rect(img, 25, 14, 27, 15, _c(120, 80, 40))
    return outline(_horseman((190, 40, 40), (140, 25, 25), (130, 30, 30), (255, 220, 80), w), (40, 10, 10, 255))


def horseman_famine():
    """검은 말의 기사 — 기근 (46x44): 저울"""
    def w(img):
        _line(img, (28, 4), (28, 14), _c(200, 190, 150))
        _line(img, (24, 6), (32, 6), _c(200, 190, 150))
        ellipse(img, 24, 9, 2, 1, _c(200, 190, 150))
        ellipse(img, 32, 9, 2, 1, _c(200, 190, 150))
    return outline(_horseman((40, 40, 50), (25, 25, 30), (60, 55, 50), (200, 200, 120), w), (10, 10, 15, 255))


def horseman_death():
    """창백한 말의 기사 — 죽음 (46x44): 큰 낫"""
    def w(img):
        rect(img, 28, 0, 29, 22, _c(110, 90, 70))
        _poly(img, [(29, 0), (40, 3), (36, 6)], _c(210, 215, 220))
    return outline(_horseman((170, 190, 160), (120, 140, 110), (60, 60, 70), (120, 255, 160), w), (20, 30, 20, 255))


def plague_rider():
    return _warrior(16, 22, _c(170, 180, 150), _c(90, 100, 70), _c(60, 70, 50), _c(80, 90, 60), weapon=(150, 150, 120), eye=(200, 255, 120))


def famine_ghoul():
    return _warrior(14, 20, _c(170, 160, 140), _c(80, 75, 70), _c(55, 50, 45), _c(60, 55, 50), eye=(220, 220, 120))


def war_hound():
    return _beast(20, 13, _c(170, 50, 40), _c(120, 30, 25), (255, 220, 80), mane=(90, 20, 20))


def floor_apocalypse():
    return _floor(851, (96, 76, 70), 5, [(6, (78, 60, 56, 255), 4), (5, (130, 104, 96, 255), 2), (3, (200, 60, 40, 255), 1)])


# ---- 86 거짓 예언자
def false_prophet():
    """거짓 예언자 (34x46): 어린양의 뿔, 용의 목소리, 붉은 법의"""
    img = _hero(34, 46, _c(210, 180, 160), _c(150, 30, 40), _c(100, 20, 30), _c(240, 235, 220), cape=(60, 20, 30))
    _poly(img, [(11, 6), (8, 0), (13, 4)], _c(240, 235, 220))
    _poly(img, [(22, 6), (25, 0), (20, 4)], _c(240, 235, 220))
    put(img, [(14, 11), (19, 11)], _c(255, 80, 60))
    rect(img, 27, 4, 28, 40, _c(160, 130, 80))
    ellipse(img, 27.5, 4, 3, 3, _c(200, 40, 40))
    return outline(img, (40, 10, 15, 255))


def beast_image():
    """짐승의 우상 (16x22)"""
    img = canvas(16, 22)
    rect(img, 3, 16, 12, 21, _c(120, 110, 100))
    ellipse(img, 7.5, 10, 6, 6, _c(150, 60, 50))
    _poly(img, [(3, 6), (1, 0), (6, 4)], _c(200, 190, 170))
    _poly(img, [(12, 6), (14, 0), (9, 4)], _c(200, 190, 170))
    put(img, [(5, 9), (10, 9)], _c(255, 220, 60))
    return outline(img)


def marked_zealot():
    return _warrior(16, 22, _c(205, 160, 120), _c(150, 30, 40), _c(100, 20, 30), _c(80, 30, 40), weapon=(150, 150, 160), eye=(255, 60, 40))


def prophet_acolyte():
    return _warrior(14, 20, _c(205, 160, 120), _c(100, 20, 30), _c(70, 15, 20), _c(240, 235, 220))


def floor_false_temple():
    return _floor(859, (110, 70, 70), 5, [(6, (90, 56, 56, 255), 4), (5, (150, 100, 100, 255), 2), (3, (230, 210, 120, 255), 1)])


# ---- 87 광야의 타락천사 아자젤
def azazel():
    """광야의 타락천사 아자젤 (42x52): 검게 탄 날개, 대장장이의 칼, 사막 천"""
    img = _demon(42, 52, _c(170, 140, 120), _c(120, 95, 80), _c(150, 120, 80), _c(80, 70, 60), (255, 160, 60), wings=(40, 35, 40))
    rect(img, 35, 8, 36, 40, _c(200, 200, 210))
    rect(img, 33, 30, 38, 31, _c(150, 120, 60))
    return outline(img, (30, 20, 15, 255))


def scapegoat():
    """속죄양 — 검은 염소 (20x16)"""
    img = _beast(20, 16, _c(50, 45, 50), _c(30, 28, 32), (255, 80, 60), horns=(220, 210, 190))
    put(img, [(17, 4), (18, 3)], _c(220, 210, 190))
    return img


def wilderness_gate():
    """광야의 문 (24x30)"""
    img = canvas(24, 30)
    rect(img, 2, 4, 5, 29, _c(150, 120, 80))
    rect(img, 18, 4, 21, 29, _c(150, 120, 80))
    rect(img, 1, 1, 22, 4, _c(170, 140, 90))
    rect(img, 6, 6, 17, 29, (230, 200, 140, 120))
    for x, y in ((9, 14), (13, 20), (11, 25)):
        put(img, [(x, y)], _c(255, 230, 170))
    return outline(img)


def desert_jinn():
    return _wisp(16, 16, (255, 200, 120), (180, 100, 40))


def watcher_angel():
    return _warrior(16, 22, _c(190, 170, 150), _c(70, 60, 70), _c(45, 40, 50), _c(170, 160, 140), crest=(30, 30, 35), weapon=(200, 200, 210), eye=(255, 160, 60))


def nephilim_brute():
    return _warrior(18, 24, _c(190, 150, 120), _c(120, 100, 70), _c(80, 65, 45), _c(100, 80, 60), weapon=(120, 90, 50))


def floor_wilderness():
    return _floor(869, (170, 140, 100), 5, [(6, (150, 120, 84, 255), 4), (5, (196, 166, 124, 255), 2), (3, (120, 90, 60, 255), 1)])


# ---- 88 무저갱의 열쇠를 든 타락한 별
def fallen_star():
    """무저갱의 열쇠를 든 타락한 별 (40x50): 빛이 꺼져 가는 별의 천사"""
    img = _hero(34, 44, _c(200, 200, 220), _c(60, 60, 90), _c(40, 40, 70), _c(220, 220, 240), cape=(30, 30, 60))
    big = canvas(40, 50)
    for i in range(12):
        a = math.tau * i / 12
        put(big, [(int(20 + 18 * math.cos(a)), int(14 + 13 * math.sin(a)))], _c(255, 230, 140))
    big.alpha_composite(img, (3, 6))
    return outline(big, (20, 20, 40, 255))


def abyss_key():
    """무저갱의 열쇠 (16x10)"""
    img = canvas(16, 10)
    ellipse(img, 4, 5, 3.5, 3.5, _c(200, 160, 80))
    ellipse(img, 4, 5, 1.5, 1.5, (0, 0, 0, 0))
    rect(img, 7, 4, 15, 5, _c(200, 160, 80))
    rect(img, 12, 6, 13, 8, _c(200, 160, 80))
    rect(img, 14, 6, 15, 7, _c(200, 160, 80))
    return outline(img, (60, 40, 10, 255))


def abyss_crawler():
    return _beast(18, 12, _c(60, 40, 60), _c(40, 25, 40), (255, 90, 60))


def smoke_fiend():
    return _wisp(16, 16, (120, 100, 110), (50, 40, 50))


def fallen_soldier():
    return _warrior(16, 22, _c(180, 180, 200), _c(50, 50, 70), _c(30, 30, 45), _c(90, 90, 110), crest=(30, 30, 45), weapon=(160, 160, 180), eye=(255, 80, 60))


def floor_abyss_gate():
    return _floor(877, (56, 48, 60), 5, [(6, (42, 36, 46, 255), 4), (5, (80, 70, 86, 255), 2), (4, (255, 110, 50, 255), 1)])


# ---- 89 일곱 나팔의 천사
def trumpet_angel():
    """일곱 나팔의 천사 (44x50): 흰 날개, 금빛 나팔"""
    img = canvas(44, 50)
    _poly(img, [(16, 16), (0, 2), (4, 26), (16, 28)], _c(240, 240, 250))
    _poly(img, [(28, 16), (43, 2), (39, 26), (28, 28)], _c(240, 240, 250))
    hero = _hero(30, 40, _c(230, 200, 170), _c(245, 240, 230), _c(210, 200, 180), _c(240, 210, 120))
    img.alpha_composite(hero, (7, 10))
    _poly(img, [(27, 20), (40, 14), (41, 20), (28, 22)], _c(240, 200, 80))
    return outline(img, (60, 50, 20, 255))


def angel_trumpet():
    """일곱 나팔 (16x8)"""
    img = canvas(16, 8)
    rect(img, 0, 3, 10, 4, _c(230, 190, 70))
    _poly(img, [(10, 1), (15, 0), (15, 7), (10, 6)], _c(250, 210, 90))
    put(img, [(2, 2), (2, 5)], _c(200, 160, 50))
    return outline(img, (80, 60, 10, 255))


def hail_spirit():
    return _wisp(14, 14, (230, 240, 255), (140, 170, 220))


def blood_tide():
    return _wisp(14, 14, (255, 120, 120), (150, 20, 30))


def wormwood_wisp():
    return _wisp(14, 14, (180, 230, 140), (70, 120, 50))


def floor_trumpet_sky():
    return _floor(887, (150, 140, 160), 5, [(6, (130, 120, 140, 255), 4), (5, (190, 180, 200, 255), 2), (3, (240, 200, 90, 255), 1)])


# ---- 90 마왕 아바돈
def abaddon():
    """무저갱의 왕 아바돈 (48x60): 검은 뿔 왕관, 거대한 박쥐 날개, 전갈 꼬리"""
    img = canvas(48, 60)
    _poly(img, [(18, 20), (0, 4), (2, 30), (16, 36)], _c(50, 30, 50))
    _poly(img, [(30, 20), (47, 4), (45, 30), (32, 36)], _c(50, 30, 50))
    for x0, x1 in ((2, 16), (46, 32)):
        _line(img, (x0, 6), (x1, 30), _c(90, 50, 80))
    body = _demon(36, 48, _c(110, 50, 60), _c(70, 30, 40), _c(30, 20, 30), _c(30, 25, 30), (255, 70, 30))
    img.alpha_composite(body, (6, 10))
    for x in (17, 21, 25, 29):
        _poly(img, [(x, 12), (x + 1, 6), (x + 2, 12)], _c(40, 30, 40))       # 뿔 왕관
    for i in range(8):                                                   # 전갈 꼬리
        put(img, [(36 + i // 2, 54 - i * 2)], _c(80, 40, 50))
    _poly(img, [(40, 38), (44, 34), (42, 40)], _c(200, 180, 120))
    return outline(img, (20, 5, 10, 255))


def abaddon_throne():
    """아바돈의 옥좌 (40x40)"""
    img = canvas(40, 40)
    rect(img, 4, 4, 35, 39, _c(50, 35, 45))
    rect(img, 8, 8, 31, 30, _c(80, 30, 40))
    for x in (4, 12, 20, 28, 35):
        _poly(img, [(x - 2, 4), (x, 0), (x + 2, 4)], _c(60, 45, 55))
    rect(img, 2, 22, 7, 39, _c(60, 45, 55))
    rect(img, 32, 22, 37, 39, _c(60, 45, 55))
    put(img, [(19, 14), (20, 14)], _c(255, 80, 40))
    return outline(img, (15, 5, 10, 255))


def abyss_locust():
    """무저갱의 메뚜기 (18x14): 사람 얼굴, 전갈 꼬리"""
    img = canvas(18, 14)
    ellipse(img, 9, 8, 6, 3, _c(150, 130, 60))
    ellipse(img, 15, 6, 2.5, 2.5, _c(210, 180, 150))
    put(img, [(16, 5)], _c(30, 20, 20))
    _poly(img, [(6, 6), (1, 1), (9, 5)], (220, 220, 200, 180))
    for i in range(4):
        put(img, [(2 - i // 2, 9 - i)], _c(110, 60, 40))
    for x in (6, 9, 12):
        put(img, [(x, 11), (x, 12)], _c(110, 90, 40))
    return outline(img)


def fallen_angel_soldier():
    return _warrior(16, 22, _c(170, 160, 170), _c(40, 30, 40), _c(25, 20, 25), _c(70, 50, 70), crest=(120, 30, 40), weapon=(180, 170, 180), eye=(255, 70, 30))


def hell_wraith():
    return _wisp(16, 16, (255, 120, 80), (100, 20, 30))


def floor_abyss_throne():
    return _floor(899, (46, 34, 42), 5, [(6, (34, 24, 30, 255), 4), (5, (70, 50, 62, 255), 2), (4, (255, 80, 40, 255), 1)])


def save_late20_sprites():
    for name, painter in (("mammon", mammon), ("coin_pile", coin_pile), ("greed_imp", greed_imp), ("gilded_thief", gilded_thief),
                          ("treasure_mimic", treasure_mimic), ("belphegor", belphegor), ("sloth_wisp", sloth_wisp), ("drowsy_ghoul", drowsy_ghoul),
                          ("snail_beast", snail_beast), ("beelzebub", beelzebub), ("fly_swarm", fly_swarm), ("glutton_ghoul", glutton_ghoul),
                          ("maggot", maggot), ("asmodeus", asmodeus), ("chain_pillar", chain_pillar), ("succubus_lancer", succubus_lancer),
                          ("charm_wisp", charm_wisp), ("chain_hound", chain_hound), ("horseman_conquest", horseman_conquest), ("horseman_war", horseman_war),
                          ("horseman_famine", horseman_famine), ("horseman_death", horseman_death), ("plague_rider", plague_rider),
                          ("famine_ghoul", famine_ghoul), ("war_hound", war_hound), ("false_prophet", false_prophet), ("beast_image", beast_image),
                          ("marked_zealot", marked_zealot), ("prophet_acolyte", prophet_acolyte), ("azazel", azazel), ("scapegoat", scapegoat),
                          ("wilderness_gate", wilderness_gate), ("desert_jinn", desert_jinn), ("watcher_angel", watcher_angel),
                          ("nephilim_brute", nephilim_brute), ("fallen_star", fallen_star), ("abyss_key", abyss_key), ("abyss_crawler", abyss_crawler),
                          ("smoke_fiend", smoke_fiend), ("fallen_soldier", fallen_soldier), ("trumpet_angel", trumpet_angel),
                          ("angel_trumpet", angel_trumpet), ("hail_spirit", hail_spirit), ("blood_tide", blood_tide), ("wormwood_wisp", wormwood_wisp),
                          ("abaddon", abaddon), ("abaddon_throne", abaddon_throne), ("abyss_locust", abyss_locust),
                          ("fallen_angel_soldier", fallen_angel_soldier), ("hell_wraith", hell_wraith)):
        save(painter(), "characters", f"{name}.png")
    for name, painter in (("floor_greed_vault", floor_greed_vault), ("floor_sloth_bog", floor_sloth_bog), ("floor_glutton_hall", floor_glutton_hall),
                          ("floor_lust_palace", floor_lust_palace), ("floor_apocalypse", floor_apocalypse), ("floor_false_temple", floor_false_temple),
                          ("floor_wilderness", floor_wilderness), ("floor_abyss_gate", floor_abyss_gate), ("floor_trumpet_sky", floor_trumpet_sky),
                          ("floor_abyss_throne", floor_abyss_throne)):
        save(painter(), "tiles", f"{name}.png")


# ---------------------------------------------------------------- 91~100스테이지 (하늘로 오르는 길 → 대천사 가브리엘)
def _angel(w, h, skin, robe, robe_d, hair, wing, wings=2, halo=(255, 230, 120), weapon=None, shield=None):
    """천사 공용 몸통 (날개 · 후광)"""
    img = canvas(w, h)
    cx = w // 2
    for k in range(wings // 2):
        top = 6 + k * 10
        _poly(img, [(cx - 6, top + 10), (0, top - 4 if top > 4 else 0), (3, top + 18), (cx - 6, top + 22)], _c(*wing))
        _poly(img, [(cx + 5, top + 10), (w - 1, top - 4 if top > 4 else 0), (w - 4, top + 18), (cx + 5, top + 22)], _c(*wing))
    body = _hero(30, 40, _c(*skin), _c(*robe), _c(*robe_d), _c(*hair), weapon=weapon, shield=shield)
    img.alpha_composite(body, (cx - 15, h - 41))
    top_y = h - 41
    for x in range(cx - 5, cx + 5):
        put(img, [(x, top_y)], _c(*halo))
    put(img, [(cx - 6, top_y + 1), (cx + 5, top_y + 1)], _c(*halo))
    return img


# ---- 91 에덴의 문지기 케루빔
def cherubim():
    """케루빔 (46x52): 네 얼굴(사람 · 사자 · 소 · 독수리)과 네 날개"""
    img = _angel(46, 52, (230, 200, 170), (200, 170, 90), (150, 120, 60), (240, 210, 120), (230, 220, 160), wings=4)
    ellipse(img, 9, 30, 4, 4, _c(220, 160, 60))      # 사자
    put(img, [(8, 29), (10, 29)], _c(60, 30, 10))
    ellipse(img, 37, 30, 4, 4, _c(150, 110, 80))     # 소
    put(img, [(34, 26), (40, 26)], _c(240, 230, 210))
    ellipse(img, 23, 6, 4, 3, _c(200, 190, 180))     # 독수리
    put(img, [(23, 8)], _c(240, 200, 60))
    return outline(img, (60, 45, 15, 255))


def eden_guard():
    return _warrior(16, 22, _c(220, 190, 160), _c(220, 180, 90), _c(160, 120, 50), _c(240, 210, 120), crest=(255, 120, 40), weapon=(255, 140, 50))


def tree_spirit():
    return _wisp(14, 14, (190, 255, 160), (60, 140, 60))


def eden_serpent():
    """에덴의 뱀 (18x12)"""
    img = canvas(18, 12)
    for i in range(14):
        ellipse(img, 2 + i, 7 + 2 * math.sin(i * 0.8), 1.8, 1.8, _c(90, 150, 60))
    ellipse(img, 15, 5, 2.5, 2, _c(110, 170, 70))
    put(img, [(16, 4)], _c(255, 220, 60))
    put(img, [(17, 6)], _c(220, 40, 40))
    return outline(img)


def floor_eden_gate():
    return _floor(911, (96, 120, 70), 5, [(6, (80, 104, 58, 255), 4), (5, (130, 160, 90, 255), 2), (4, (255, 150, 60, 255), 1)])


# ---- 92 바퀴 천사 오파님
def _wheel(size, rim, spoke, eyes):
    img = canvas(size, size)
    c = size / 2 - 0.5
    ellipse(img, c, c, size * 0.48, size * 0.48, _c(*rim))
    ellipse(img, c, c, size * 0.36, size * 0.36, (0, 0, 0, 0))
    for k in range(8):
        a = k * math.pi / 4
        _line(img, (int(c), int(c)), (int(c + math.cos(a) * size * 0.4), int(c + math.sin(a) * size * 0.4)), _c(*spoke))
    for k in range(eyes):
        a = k * 2 * math.pi / eyes
        ex, ey = c + math.cos(a) * size * 0.42, c + math.sin(a) * size * 0.42
        ellipse(img, ex, ey, 1.6, 1.2, _c(250, 250, 240))
        put(img, [(int(round(ex)), int(round(ey)))], _c(40, 90, 200))
    ellipse(img, c, c, size * 0.1, size * 0.1, _c(255, 230, 140))
    return img


def ophanim_throne():
    """오파님 (40x40): 눈이 가득한 금빛 바퀴"""
    return outline(_wheel(40, (220, 180, 80), (250, 220, 130), 10), (70, 50, 10, 255))


def ophanim_wheel():
    """오파님의 둘째 바퀴 (32x32)"""
    return outline(_wheel(32, (200, 200, 220), (240, 240, 255), 8), (40, 40, 70, 255))


def eye_spirit():
    return _wisp(14, 14, (250, 250, 240), (90, 140, 230))


def fire_wheel():
    return outline(_wheel(14, (240, 110, 40), (255, 200, 80), 0))


def throne_guard():
    return _warrior(16, 22, _c(230, 210, 190), _c(230, 230, 240), _c(170, 170, 190), _c(250, 230, 150), crest=(120, 160, 255), weapon=(230, 230, 250))


def floor_wheel_sky():
    return _floor(922, (150, 150, 176), 5, [(6, (130, 130, 156, 255), 4), (5, (190, 190, 214, 255), 2), (3, (255, 230, 140, 255), 1)])


# ---- 93 느부갓네살의 금 신상
def gold_statue():
    """느부갓네살의 금 신상 (36x72): 머리 금 · 가슴 은 · 배 놋 · 다리 철 · 발 진흙"""
    img = canvas(36, 72)
    ellipse(img, 17.5, 9, 7, 7, _c(240, 200, 60))                  # 금 머리
    put(img, [(15, 9), (20, 9)], _c(120, 80, 10))
    rect(img, 12, 1, 23, 3, _c(255, 220, 90))
    rect(img, 8, 17, 27, 30, _c(200, 205, 215))                     # 은 가슴 · 팔
    rect(img, 3, 18, 7, 34, _c(185, 190, 200))
    rect(img, 28, 18, 32, 34, _c(185, 190, 200))
    rect(img, 9, 31, 26, 42, _c(180, 120, 60))                      # 놋 배
    rect(img, 10, 43, 16, 60, _c(110, 115, 125))                    # 철 다리
    rect(img, 19, 43, 25, 60, _c(110, 115, 125))
    rect(img, 8, 61, 16, 71, _c(150, 120, 90))                      # 철과 진흙 발
    rect(img, 19, 61, 27, 71, _c(150, 120, 90))
    for x, y in ((10, 64), (14, 67), (21, 65), (25, 68)):
        put(img, [(x, y)], _c(110, 115, 125))
    return outline(img, (50, 35, 10, 255))


def clay_foot():
    """진흙 발 (14x10)"""
    img = canvas(14, 10)
    rect(img, 1, 2, 12, 9, _c(150, 120, 90))
    for x, y in ((3, 4), (7, 6), (10, 3)):
        put(img, [(x, y)], _c(110, 115, 125))
    _line(img, (4, 2), (6, 8), _c(100, 75, 55))
    return outline(img)


def cut_stone():
    """손대지 않고 뜨인 돌 (24x24)"""
    img = canvas(24, 24)
    ellipse(img, 11.5, 11.5, 11, 11, _c(170, 165, 160))
    ellipse(img, 9, 9, 5, 4, _c(205, 200, 195))
    for x, y in ((14, 15), (6, 14), (16, 6)):
        put(img, [(x, y)], _c(120, 115, 110))
    return outline(img)


def babylon_spearman():
    return _warrior(16, 22, _c(200, 160, 120), _c(60, 90, 160), _c(40, 60, 110), _c(200, 170, 80), crest=(240, 200, 80), weapon=(200, 200, 210))


def chaldean_astrologer():
    return _wisp(14, 14, (220, 200, 255), (100, 60, 160))


def furnace_spirit():
    return _wisp(14, 14, (255, 230, 120), (230, 90, 30))


def floor_babylon():
    return _floor(933, (150, 120, 80), 5, [(6, (130, 100, 64, 255), 4), (5, (190, 160, 110, 255), 2), (4, (240, 200, 70, 255), 1)])


# ---- 94 거인 골리앗
def goliath():
    """거인 골리앗 (44x62): 놋 투구 · 비늘 갑옷 · 베틀채 같은 창"""
    img = _giant(44, 62, _c(200, 150, 110), _c(150, 105, 70), _c(150, 120, 60), _c(70, 50, 30), (40, 20, 10))
    for y in range(26, 42, 3):
        for x in range(12, 32, 3):
            put(img, [(x, y)], _c(170, 140, 70))
    rect(img, 15, 2, 28, 7, _c(190, 140, 60))
    rect(img, 40, 2, 41, 58, _c(130, 100, 70))
    _poly(img, [(38, 4), (40, 0), (42, 0), (43, 4)], _c(220, 220, 230))
    return outline(img, (50, 30, 15, 255))


def shieldbearer():
    """방패 든 자 (20x24)"""
    img = _warrior(16, 22, _c(200, 160, 120), _c(150, 110, 60), _c(110, 80, 40), _c(170, 130, 60))
    out = canvas(20, 24)
    out.alpha_composite(img, (4, 2))
    rect(out, 0, 6, 7, 22, _c(170, 130, 60))
    rect(out, 1, 7, 6, 21, _c(200, 160, 80))
    put(out, [(3, 14)], _c(240, 210, 120))
    return outline(out)


def sling_stone():
    """매끄러운 시냇돌 (8x6)"""
    img = canvas(8, 6)
    ellipse(img, 3.5, 2.5, 3.5, 2.5, _c(190, 195, 200))
    put(img, [(2, 1)], _c(240, 240, 245))
    return outline(img)


def philistine_spearman():
    return _warrior(16, 22, _c(200, 160, 120), _c(150, 60, 50), _c(110, 40, 30), _c(200, 170, 90), crest=(230, 220, 120), weapon=(210, 210, 220))


def philistine_slinger():
    return _warrior(14, 20, _c(200, 160, 120), _c(160, 120, 70), _c(120, 90, 50), _c(140, 100, 60))


def gath_giant():
    return outline(_giant(26, 32, _c(190, 140, 100), _c(140, 100, 70), _c(120, 80, 50), _c(60, 40, 20), (40, 20, 10)))


def floor_elah_valley():
    return _floor(944, (120, 128, 80), 5, [(6, (104, 112, 66, 255), 4), (5, (160, 166, 110, 255), 2), (4, (180, 190, 200, 255), 1)])


# ---- 95 여리고 성의 수비대장
def jericho_captain():
    """여리고 성의 수비대장 (34x44): 붉은 깃 투구, 큰 활과 창"""
    img = _hero(34, 44, _c(200, 160, 120), _c(150, 100, 60), _c(110, 70, 40), _c(180, 150, 80), crest=(200, 50, 40), cape=(130, 40, 30), weapon=(150, 110, 70), shield=(170, 120, 60))
    return outline(img, (50, 30, 15, 255))


def jericho_archer():
    return _warrior(14, 20, _c(200, 160, 120), _c(150, 100, 60), _c(110, 70, 40), _c(180, 150, 80), crest=(200, 50, 40))


def jericho_shieldman():
    return _warrior(16, 22, _c(200, 160, 120), _c(160, 110, 60), _c(120, 80, 40), _c(180, 150, 80), shield=(190, 140, 70), weapon=(200, 200, 210))


def wall_hound():
    return _beast(20, 14, _c(150, 120, 90), _c(100, 80, 60), (255, 200, 60))


def floor_jericho():
    return _floor(955, (160, 132, 96), 5, [(6, (140, 112, 80, 255), 4), (5, (196, 168, 126, 255), 2), (4, (210, 120, 80, 255), 1)])


# ---- 96 노아 홍수의 네피림 왕
def nephilim_king():
    """네피림 왕 (50x64): 거대한 몸, 왕관, 쇠사슬 띠"""
    img = _giant(50, 64, _c(170, 140, 120), _c(120, 95, 80), _c(70, 60, 80), _c(40, 30, 30), (255, 200, 80))
    for x in (18, 22, 26, 30):
        _poly(img, [(x, 6), (x + 1, 1), (x + 2, 6)], _c(230, 190, 70))
    rect(img, 16, 6, 33, 7, _c(230, 190, 70))
    for x in range(14, 36, 3):
        put(img, [(x, 44), (x + 1, 45)], _c(150, 150, 160))
    return outline(img, (40, 25, 20, 255))


def flood_giant():
    return outline(_giant(26, 32, _c(160, 140, 130), _c(110, 95, 85), _c(60, 70, 90), _c(40, 30, 30), (230, 220, 120)))


def flood_spirit():
    return _wisp(14, 14, (200, 230, 255), (60, 110, 200))


def deep_fish():
    """바다 괴어 (20x12)"""
    img = canvas(20, 12)
    ellipse(img, 9, 6, 8, 4, _c(70, 100, 140))
    _poly(img, [(1, 6), (-1, 1), (-1, 11)], _c(60, 90, 130))
    for x in (12, 14, 16):
        put(img, [(x, 8)], _c(240, 240, 230))
    put(img, [(15, 4)], _c(255, 230, 80))
    return outline(img)


def ark_plank():
    """방주의 판자 (40x16)"""
    img = canvas(40, 16)
    for i, y in enumerate((2, 7, 11)):
        rect(img, 1, y, 38, y + 3, _c(150 - i * 10, 105 - i * 6, 60))
    for x in (6, 20, 33):
        rect(img, x, 1, x + 1, 15, _c(100, 70, 40))
    return outline(img)


def floor_flood():
    return _floor(966, (96, 104, 92), 5, [(6, (80, 88, 78, 255), 4), (5, (120, 130, 116, 255), 2), (4, (90, 130, 170, 255), 1)])


# ---- 97 갈멜산의 바알 대예언자
def baal_prophet():
    """바알 대예언자 (34x46): 황소 뿔 관, 붉은 옷"""
    img = _hero(34, 44, _c(200, 150, 110), _c(170, 50, 40), _c(120, 30, 25), _c(230, 190, 80), cape=(90, 30, 30))
    out = canvas(34, 46)
    out.alpha_composite(img, (0, 2))
    _poly(out, [(10, 7), (5, 0), (12, 5)], _c(240, 230, 200))
    _poly(out, [(23, 7), (28, 0), (21, 5)], _c(240, 230, 200))
    return outline(out, (50, 20, 15, 255))


def baal_altar():
    """바알의 제단 (36x28)"""
    img = canvas(36, 28)
    rect(img, 3, 10, 32, 27, _c(130, 60, 50))
    rect(img, 1, 8, 34, 11, _c(160, 80, 60))
    _poly(img, [(12, 8), (8, 0), (15, 6)], _c(220, 210, 180))
    _poly(img, [(23, 8), (27, 0), (20, 6)], _c(220, 210, 180))
    return outline(img)


def elijah_altar():
    """엘리야의 제단 — 돌 열두 개 (36x26)"""
    img = canvas(36, 26)
    for i in range(12):
        x, y = 3 + (i % 6) * 5, 14 + (i // 6) * 6
        ellipse(img, x + 2, y + 2, 2.6, 2.6, _c(160, 155, 150))
    rect(img, 6, 6, 29, 12, _c(130, 90, 50))
    for x in (9, 15, 21, 26):
        rect(img, x, 4, x + 1, 12, _c(110, 75, 40))
    return outline(img)


def water_jar():
    """물동이 (12x14)"""
    img = canvas(12, 14)
    ellipse(img, 5.5, 8, 5, 5, _c(170, 110, 70))
    rect(img, 3, 1, 8, 4, _c(150, 95, 60))
    ellipse(img, 5.5, 2, 2, 1, _c(90, 150, 220))
    return outline(img)


def baal_priest():
    return _wisp(14, 14, (255, 180, 120), (170, 50, 40))


def baal_dancer():
    return _warrior(14, 20, _c(200, 150, 110), _c(180, 60, 50), _c(130, 40, 35), _c(230, 190, 80), crest=(240, 200, 90))


def asherah_pole():
    """아세라 목상 (16x24)"""
    img = canvas(16, 24)
    rect(img, 6, 6, 9, 23, _c(130, 90, 50))
    ellipse(img, 7.5, 5, 4, 4, _c(150, 105, 60))
    put(img, [(6, 5), (9, 5)], _c(240, 80, 40))
    rect(img, 2, 10, 13, 11, _c(130, 90, 50))
    return outline(img)


def floor_carmel():
    return _floor(977, (130, 110, 90), 5, [(6, (112, 94, 76, 255), 4), (5, (170, 150, 126, 255), 2), (4, (230, 110, 60, 255), 1)])


# ---- 98 치유의 대천사 라파엘
def raphael():
    """라파엘 (44x50): 초록빛 옷, 순례자의 지팡이"""
    img = _angel(44, 50, (230, 200, 170), (110, 180, 120), (70, 130, 80), (200, 160, 100), (230, 245, 230), weapon=(170, 130, 80))
    return outline(img, (30, 50, 30, 255))


def healing_spring():
    """치유의 샘 (34x20)"""
    img = canvas(34, 20)
    ellipse(img, 16.5, 10, 16, 9, _c(150, 145, 140))
    ellipse(img, 16.5, 10, 13, 7, _c(120, 200, 230))
    for x, y in ((10, 8), (20, 11), (15, 6)):
        put(img, [(x, y)], _c(230, 250, 255))
    return outline(img)


def cover_stone():
    """샘을 덮는 넓적한 돌 (16x12)"""
    img = canvas(16, 12)
    ellipse(img, 7.5, 6, 7.5, 5, _c(140, 135, 128))
    ellipse(img, 5.5, 4.5, 3, 2, _c(175, 170, 162))
    return outline(img)


def tobias_fish():
    """토비아의 물고기 (16x8)"""
    img = canvas(16, 8)
    ellipse(img, 8, 4, 6, 3, _c(140, 170, 190))
    _poly(img, [(2, 4), (0, 0), (0, 7)], _c(120, 150, 170))
    put(img, [(12, 3)], _c(30, 30, 40))
    put(img, [(8, 5)], _c(90, 140, 60))
    return outline(img)


def light_healer():
    return _wisp(14, 14, (240, 255, 220), (110, 190, 120))


def heaven_guard():
    return _warrior(16, 22, _c(230, 210, 190), _c(220, 230, 220), _c(160, 180, 160), _c(240, 220, 140), crest=(120, 200, 140), weapon=(230, 230, 250))


def heaven_stag():
    return _beast(20, 16, _c(240, 235, 220), _c(190, 180, 160), (120, 200, 255), horns=(230, 200, 120))


def floor_healing_sky():
    return _floor(988, (150, 176, 156), 5, [(6, (130, 156, 136, 255), 4), (5, (190, 214, 196, 255), 2), (3, (200, 240, 255, 255), 1)])


# ---- 99 천군의 장 대천사 미카엘
def michael():
    """미카엘 (46x52): 은빛 갑옷, 불칼, 빛나는 방패"""
    img = _angel(46, 52, (230, 200, 170), (210, 215, 230), (150, 155, 175), (230, 190, 90), (245, 245, 255), weapon=(255, 160, 60), shield=(230, 210, 120))
    return outline(img, (40, 40, 60, 255))


def red_dragon():
    """하늘의 붉은 용 (60x48)"""
    return _dragon(60, 48, _c(190, 40, 40), _c(130, 20, 25), _c(230, 140, 90), _c(160, 30, 35), _c(110, 15, 20), (255, 230, 80), _c(60, 30, 30), wing_span=1.1, heavy=1)


def host_spearman():
    return _warrior(16, 22, _c(230, 210, 190), _c(220, 220, 235), _c(160, 160, 180), _c(240, 220, 140), crest=(255, 240, 160), weapon=(240, 240, 255))


def host_archer():
    return _warrior(14, 20, _c(230, 210, 190), _c(210, 215, 230), _c(150, 155, 175), _c(240, 220, 140), crest=(160, 200, 255))


def dragon_whelp():
    """붉은 용의 새끼 (22x16)"""
    img = _beast(22, 16, _c(200, 60, 50), _c(140, 30, 30), (255, 230, 80), horns=(240, 220, 180))
    _poly(img, [(8, 6), (5, 0), (12, 5)], _c(170, 40, 40))
    _poly(img, [(12, 6), (14, 0), (16, 5)], _c(150, 30, 35))
    return img


def floor_host_sky():
    return _floor(999, (156, 150, 170), 5, [(6, (136, 130, 150, 255), 4), (5, (200, 196, 214, 255), 2), (4, (255, 140, 80, 255), 1)])


# ---- 100 대천사 가브리엘
def gabriel():
    """대천사 가브리엘 (50x58): 여섯 날개, 흰 백합"""
    img = _angel(50, 58, (235, 210, 185), (245, 245, 250), (200, 200, 215), (240, 210, 140), (250, 250, 255), wings=6, halo=(255, 240, 160))
    rect(img, 9, 34, 9, 46, _c(80, 150, 70))
    ellipse(img, 9, 33, 3, 2.5, _c(255, 255, 250))
    put(img, [(9, 33)], _c(250, 220, 90))
    return outline(img, (60, 55, 30, 255))


def gabriel_wing():
    """가브리엘의 날개 하나 (20x14)"""
    img = canvas(20, 14)
    _poly(img, [(1, 12), (18, 1), (19, 5), (6, 13)], _c(250, 250, 255))
    for i in range(4):
        _line(img, (4 + i * 3, 12 - i * 2), (8 + i * 3, 13 - i * 2), _c(215, 215, 230))
    return outline(img, (90, 90, 110, 255))


def lily():
    """백합 (12x18)"""
    img = canvas(12, 18)
    rect(img, 5, 7, 6, 17, _c(80, 150, 70))
    _poly(img, [(6, 8), (1, 13), (5, 12)], _c(90, 160, 80))
    for dx in (-3, 0, 3):
        ellipse(img, 5.5 + dx, 4, 2, 3, _c(255, 255, 250))
    put(img, [(5, 4), (6, 4)], _c(250, 210, 80))
    return outline(img, (90, 110, 80, 255))


def withered_lily():
    """시든 백합 (12x18)"""
    img = canvas(12, 18)
    _line(img, (5, 17), (7, 9), _c(110, 100, 60))
    _poly(img, [(7, 9), (11, 11), (8, 13)], _c(170, 150, 110))
    return outline(img, (70, 60, 40, 255))


def lily_spirit():
    return _wisp(14, 14, (255, 255, 250), (220, 210, 120))


def revelation_angel():
    return _warrior(16, 22, _c(230, 210, 190), _c(245, 245, 250), _c(200, 200, 215), _c(250, 230, 150), crest=(255, 250, 200), weapon=(255, 240, 180))


def seraph():
    """스랍 (18x16): 불타는 여섯 날개"""
    img = canvas(18, 16)
    for k, y in enumerate((2, 6, 10)):
        _poly(img, [(8, 8), (0, y), (2, y + 3)], _c(255, 160 - k * 30, 60))
        _poly(img, [(9, 8), (17, y), (15, y + 3)], _c(255, 160 - k * 30, 60))
    ellipse(img, 8.5, 8, 3, 3, _c(255, 230, 150))
    return outline(img)


def floor_gabriel_garden():
    return _floor(1000, (190, 186, 170), 5, [(6, (170, 166, 150, 255), 4), (5, (226, 222, 206, 255), 2), (3, (255, 250, 230, 255), 1)])


def save_late21_sprites():
    for name, painter in (("cherubim", cherubim), ("eden_guard", eden_guard), ("tree_spirit", tree_spirit), ("eden_serpent", eden_serpent),
                          ("ophanim_throne", ophanim_throne), ("ophanim_wheel", ophanim_wheel), ("eye_spirit", eye_spirit), ("fire_wheel", fire_wheel),
                          ("throne_guard", throne_guard), ("gold_statue", gold_statue), ("clay_foot", clay_foot), ("cut_stone", cut_stone),
                          ("babylon_spearman", babylon_spearman), ("chaldean_astrologer", chaldean_astrologer), ("furnace_spirit", furnace_spirit),
                          ("goliath", goliath), ("shieldbearer", shieldbearer), ("sling_stone", sling_stone), ("philistine_spearman", philistine_spearman),
                          ("philistine_slinger", philistine_slinger), ("gath_giant", gath_giant), ("jericho_captain", jericho_captain),
                          ("jericho_archer", jericho_archer), ("jericho_shieldman", jericho_shieldman), ("wall_hound", wall_hound),
                          ("nephilim_king", nephilim_king), ("flood_giant", flood_giant), ("flood_spirit", flood_spirit), ("deep_fish", deep_fish),
                          ("ark_plank", ark_plank), ("baal_prophet", baal_prophet), ("baal_altar", baal_altar), ("elijah_altar", elijah_altar),
                          ("water_jar", water_jar), ("baal_priest", baal_priest), ("baal_dancer", baal_dancer), ("asherah_pole", asherah_pole),
                          ("raphael", raphael), ("healing_spring", healing_spring), ("cover_stone", cover_stone), ("tobias_fish", tobias_fish),
                          ("light_healer", light_healer), ("heaven_guard", heaven_guard), ("heaven_stag", heaven_stag), ("michael", michael),
                          ("red_dragon", red_dragon), ("host_spearman", host_spearman), ("host_archer", host_archer), ("dragon_whelp", dragon_whelp),
                          ("gabriel", gabriel), ("gabriel_wing", gabriel_wing), ("lily", lily), ("withered_lily", withered_lily),
                          ("lily_spirit", lily_spirit), ("revelation_angel", revelation_angel), ("seraph", seraph)):
        save(painter(), "characters", f"{name}.png")
    for name, painter in (("floor_eden_gate", floor_eden_gate), ("floor_wheel_sky", floor_wheel_sky), ("floor_babylon", floor_babylon),
                          ("floor_elah_valley", floor_elah_valley), ("floor_jericho", floor_jericho), ("floor_flood", floor_flood),
                          ("floor_carmel", floor_carmel), ("floor_healing_sky", floor_healing_sky), ("floor_host_sky", floor_host_sky),
                          ("floor_gabriel_garden", floor_gabriel_garden)):
        save(painter(), "tiles", f"{name}.png")


# ---------------------------------------------------------------- 최종장 (상인 = 멀티버스의 주인)
def merchant_boss():
    """보스방에 나타난 상인 (32x40): 야영지 상인과 같은 보라 모자 · 주황 옷 · 흰 수염, 손에는 금화 주머니"""
    img = canvas(32, 40)
    rect(img, 9, 34, 13, 39, _c(70, 50, 40))
    rect(img, 18, 34, 22, 39, _c(70, 50, 40))
    ellipse(img, 15.5, 27, 10, 9, _c(230, 120, 60))          # 주황 옷
    rect(img, 6, 24, 25, 34, _c(230, 120, 60))
    rect(img, 6, 30, 25, 31, _c(250, 170, 90))
    for x, y in ((10, 27), (20, 28), (14, 32)):
        put(img, [(x, y)], _c(250, 190, 120))
    ellipse(img, 15.5, 15, 7, 6, _c(240, 200, 160))          # 얼굴
    put(img, [(13, 14), (18, 14)], _c(40, 30, 30))
    ellipse(img, 15.5, 19, 5, 3.5, _c(245, 245, 240))         # 흰 수염
    rect(img, 3, 8, 28, 10, _c(130, 60, 160))                 # 넓은 챙 보라 모자
    ellipse(img, 15.5, 6, 8, 5, _c(150, 75, 180))
    rect(img, 8, 8, 23, 9, _c(90, 40, 120))
    ellipse(img, 28, 28, 3.5, 4, _c(160, 120, 60))            # 금화 주머니
    put(img, [(28, 25), (27, 29), (29, 30)], _c(255, 220, 90))
    return outline(img, (40, 25, 30, 255))


def multiverse_master():
    """멀티버스의 주인 (58x70): 별이 흐르는 보라 망토, 왕관이 된 모자, 가슴의 균열, 둘레를 도는 세계의 조각"""
    img = canvas(58, 70)
    cx = 29
    _poly(img, [(cx, 14), (cx - 22, 68), (cx + 22, 68)], _c(60, 25, 90))           # 망토
    _poly(img, [(cx, 20), (cx - 16, 68), (cx + 16, 68)], _c(25, 15, 45))
    rng = __import__("random").Random(1001)
    for _ in range(26):                                                              # 망토 속 별
        x, y = rng.randint(cx - 14, cx + 14), rng.randint(30, 66)
        if abs(x - cx) < (y - 20) * 0.32:
            put(img, [(x, y)], _c(*rng.choice([(255, 255, 230), (190, 220, 255), (255, 210, 120)])))
    _poly(img, [(cx - 3, 30), (cx + 3, 30), (cx + 1, 46), (cx - 1, 46)], _c(255, 120, 220))  # 가슴의 균열
    put(img, [(cx, 34), (cx, 38), (cx, 42)], _c(255, 240, 255))
    ellipse(img, cx, 16, 7, 7, _c(220, 190, 160))                                     # 얼굴 (흰 수염이 길게)
    _poly(img, [(cx - 5, 18), (cx + 5, 18), (cx, 30)], _c(245, 245, 240))
    put(img, [(cx - 3, 14), (cx + 2, 14)], _c(255, 200, 60))
    rect(img, cx - 13, 7, cx + 13, 9, _c(130, 60, 160))                               # 왕관이 된 모자
    for x in range(cx - 9, cx + 10, 4):
        _poly(img, [(x - 2, 7), (x, 0), (x + 2, 7)], _c(240, 200, 80))
    for k, (ox, oy) in enumerate(((6, 26), (52, 26), (4, 50), (54, 50))):            # 세계의 조각
        col = [(120, 220, 120), (120, 160, 255), (255, 140, 80), (255, 240, 160)][k]
        ellipse(img, ox, oy, 3.5, 3.5, _c(*col))
        put(img, [(ox - 1, oy - 1)], _c(255, 255, 255))
    for x, y in ((14, 40), (44, 40), (20, 58), (38, 58)):                             # 떠다니는 금화
        ellipse(img, x, y, 1.6, 1.6, _c(250, 210, 80))
    return outline(img, (20, 5, 30, 255))


def multiverse_rift():
    """멀티버스의 균열 (26x30)"""
    img = canvas(26, 30)
    ellipse(img, 12.5, 15, 10, 14, _c(70, 20, 90))
    ellipse(img, 12.5, 15, 6, 10, _c(160, 60, 200))
    _poly(img, [(12, 3), (15, 15), (11, 27), (10, 15)], _c(255, 160, 240))
    for x, y in ((8, 9), (17, 20), (14, 6)):
        put(img, [(x, y)], _c(255, 255, 255))
    return outline(img, (30, 5, 40, 255))


def floor_multiverse():
    return _floor(1101, (36, 26, 52), 5, [(6, (28, 20, 42, 255), 4), (5, (60, 44, 84, 255), 2), (4, (255, 230, 150, 255), 1), (3, (150, 200, 255, 255), 1)])


def save_finale_sprites():
    for name, painter in (("merchant_boss", merchant_boss), ("multiverse_master", multiverse_master), ("multiverse_rift", multiverse_rift)):
        save(painter(), "characters", f"{name}.png")
    save(floor_multiverse(), "tiles", "floor_multiverse.png")


def main():
    save(from_map(PLAYER), "characters", "player.png")
    save(from_map(SLIME), "characters", "slime.png")
    save(from_map(GOBLIN), "characters", "goblin.png")
    save(from_map(MERCHANT), "characters", "merchant.png")
    save(from_map(MERCHANT_SMIRK), "characters", "merchant_smirk.png")
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
    save_late4_sprites()
    save_late5_sprites()
    save_late6_sprites()
    save_late7_sprites()
    save_late8_sprites()
    save_late9_sprites()
    save_late10_sprites()
    save_late11_sprites()
    save_late12_sprites()
    save_late13_sprites()
    save_late14_sprites()
    save_late15_sprites()
    save_late16_sprites()
    save_late17_sprites()
    save_late18_sprites()
    save_late19_sprites()
    save_late20_sprites()
    save_late21_sprites()
    save_finale_sprites()

    save(bar_under(), "ui", "bar_under.png")
    save(bar((200, 50, 70)), "ui", "bar_hp.png")
    save(bar((65, 166, 246)), "ui", "bar_dash.png")
    save(bar((150, 80, 180)), "ui", "bar_boss.png")
    save(bar((255, 190, 70)), "ui", "bar_guard.png")


if __name__ == "__main__":
    main()
