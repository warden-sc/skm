#!/usr/bin/env python3
"""운영자 모드(개발자 강림)의 그림 + 효과음.

  assets/sprites/characters/developer.png      개발자 (흰 망토 · 금빛 테두리 · 머리 위 빛의 고리 · 빛나는 석판) 32x32
  assets/sprites/weapons/admin_sword.png        운영자의 검
  assets/sprites/weapons/admin_bow.png          운영자의 활 (+ _held: 손에 든 모습)
  assets/sprites/weapons/admin_staff.png        운영자의 지팡이
  assets/audio/sfx/descent.wav                  빛기둥이 내리꽂히는 소리
  assets/audio/sfx/ascend.wav                   빛기둥을 타고 올라가는 소리
실행: python3 tools/generate_admin_assets.py   (Pillow 필요)
"""
import math
import os
import random

from PIL import Image

from generate_trial_assets import RATE, canvas, env, lerp, outline, put, write_wav

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(HERE, "..", "assets", "sprites")

WHITE = (250, 250, 255)
GOLD = (255, 205, 80)
GOLD_DARK = (190, 130, 40)
CYAN = (120, 235, 255)
SKIN = (240, 200, 170)


def developer():
    img = canvas(32, 32)
    # 머리 위 빛의 고리
    for a in range(0, 360, 12):
        x = 16 + 6 * math.cos(math.radians(a))
        y = 3 + 1.6 * math.sin(math.radians(a))
        put(img, x, y, GOLD + (255,))
    # 망토 (아래로 퍼지는 사다리꼴)
    for y in range(12, 31):
        half = 4 + (y - 12) * 0.55
        for x in range(32):
            d = x - 15.5
            if abs(d) <= half:
                col = lerp(WHITE, (200, 205, 225), abs(d) / half * 0.7 + (y - 12) / 40)
                if abs(abs(d) - half) < 1.0 or y == 30:
                    col = GOLD
                put(img, x, y, col + (255,))
    # 가운데 금빛 띠
    for y in range(13, 30):
        put(img, 15, y, GOLD_DARK + (255,))
        put(img, 16, y, GOLD + (255,))
    # 두건 + 얼굴
    for y in range(5, 13):
        for x in range(10, 22):
            d = math.hypot((x - 15.5) / 5.6, (y - 9.5) / 4.6)
            if d <= 1.0:
                put(img, x, y, (235, 238, 250, 255) if d > 0.62 else SKIN + (255,))
    put(img, 14, 9, (40, 60, 90, 255))
    put(img, 17, 9, (40, 60, 90, 255))
    # 두 손에 든 빛나는 석판
    for y in range(17, 23):
        for x in range(19, 26):
            edge = x in (19, 25) or y in (17, 22)
            put(img, x, y, (GOLD if edge else CYAN) + (255,))
    for x in (21, 23):
        put(img, x, 19, WHITE + (255,))
        put(img, x, 20, WHITE + (255,))
    return outline(img, (40, 34, 60, 255))


def admin_sword():
    img = canvas(16, 16)
    for i in range(10):
        x, y = 4 + i, 11 - i
        put(img, x, y, WHITE + (255,))
        put(img, x + 1, y, CYAN + (255,))
        put(img, x, y - 1, (210, 245, 255, 255))
    for i in range(-2, 3):
        put(img, 4 + i, 11 + i, GOLD + (255,))
    for i in range(3):
        put(img, 3 - i, 12 + i, GOLD_DARK + (255,))
    put(img, 13, 1, (255, 255, 255, 255))
    return outline(img)


def admin_bow(held=False):
    img = canvas(16, 16)
    for t in range(0, 181, 6):
        a = math.radians(t - 90)
        x = 5 + 6 * math.cos(a) * (0.55 if held else 0.7)
        y = 8 + 7 * math.sin(a)
        put(img, x, y, GOLD + (255,))
        put(img, x - 1, y, WHITE + (255,))
    for y in range(1, 16):
        put(img, 5 if held else 4, y, CYAN + (255,))
    put(img, 9, 8, WHITE + (255,))
    return outline(img)


def admin_staff():
    img = canvas(16, 16)
    for i in range(11):
        put(img, 3 + i * 0.8, 14 - i, GOLD_DARK + (255,) if i % 3 else GOLD + (255,))
    for y in range(0, 6):
        for x in range(9, 16):
            d = abs(x - 12) + abs(y - 2.5)
            if d <= 3:
                put(img, x, y, lerp(WHITE, CYAN, d / 3) + (255,))
    return outline(img)


def descent():
    """하늘에서 빛기둥이 내리꽂힘: 올라가는 반짝임 → 쾅 → 길게 울리는 화음"""
    rnd = random.Random(7)
    n = int(RATE * 2.4)
    out = []
    for i in range(n):
        t = i / RATE
        sweep = 0.0
        if t < 0.7:
            f = 400 + 2400 * (t / 0.7) ** 2
            sweep = math.sin(2 * math.pi * f * t) * (t / 0.7) * 0.5
        boom = (math.sin(2 * math.pi * 55 * t) + rnd.uniform(-1, 1) * 0.6) * env(max(t - 0.7, 0), 0.005, 0.6) * (t > 0.7)
        choir = sum(math.sin(2 * math.pi * f * t) * a for f, a in ((523, 1.0), (659, 0.7), (784, 0.6), (1046, 0.4))) * env(max(t - 0.72, 0), 0.08, 1.6) * (t > 0.72)
        out.append(sweep + boom * 0.9 + choir * 0.35)
    return out


def ascend():
    """빛기둥을 타고 올라감: 화음이 위로 미끄러지며 사라짐"""
    n = int(RATE * 1.8)
    out = []
    for i in range(n):
        t = i / RATE
        rise = 1.0 + t * 0.8
        s = sum(math.sin(2 * math.pi * f * rise * t) for f in (523, 659, 784)) * env(t, 0.1, 1.7)
        sparkle = math.sin(2 * math.pi * (1500 + 1800 * t) * t) * env(t, 0.02, 1.2) * 0.3
        out.append(s * 0.4 + sparkle)
    return out


def main():
    developer().save(os.path.join(SPRITES, "characters", "developer.png"))
    admin_sword().save(os.path.join(SPRITES, "weapons", "admin_sword.png"))
    admin_bow().save(os.path.join(SPRITES, "weapons", "admin_bow.png"))
    admin_bow(True).save(os.path.join(SPRITES, "weapons", "admin_bow_held.png"))
    admin_staff().save(os.path.join(SPRITES, "weapons", "admin_staff.png"))
    write_wav("descent.wav", descent())
    write_wav("ascend.wav", ascend())
    print("ok")


if __name__ == "__main__":
    main()
