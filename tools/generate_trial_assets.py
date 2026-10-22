#!/usr/bin/env python3
"""보스방 해방 시련(봉인 코어 · 정화 제단)의 그림.

  assets/sprites/characters/seal_core.png   봉인 코어 (사슬에 묶인 보랏빛 수정)
  assets/sprites/world/gate_altar.png       정화 제단 (돌 받침 + 빛나는 룬)
실행: python3 tools/generate_trial_assets.py   (Pillow 필요)
"""
import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(HERE, "..", "assets", "sprites")


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def put(img, x, y, col):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), col)


def outline(img, col=(24, 16, 32, 255)):
    out = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height and img.getpixel((nx, ny))[3] > 160:
                        out.putpixel((x, y), col)
                        break
    return out


def seal_core():
    img = canvas(24, 34)
    # 수정: 위아래로 뾰족한 육각 기둥
    for y in range(34):
        for x in range(24):
            cx, top, bot = 11.5, 2, 30
            if y < top or y > bot:
                continue
            t = (y - top) / (bot - top)
            half = 8.5 * math.sin(math.pi * t) ** 0.7
            d = abs(x - cx)
            if d <= half:
                shade = d / max(half, 0.1)
                col = lerp((240, 210, 255), (120, 60, 190), shade * 0.8 + (0.2 if x > cx else 0.0))
                put(img, x, y, col + (255,))
    # 가운데 빛나는 룬
    for y in range(12, 22):
        put(img, 11, y, (255, 250, 255, 255))
        put(img, 12, y, (255, 230, 255, 255))
    for x in range(8, 16):
        put(img, x, 16, (255, 240, 255, 255))
    # 감긴 사슬 두 줄
    for row in (10, 23):
        for x in range(2, 22, 3):
            for dx in range(2):
                put(img, x + dx, row + (x // 3) % 2, (150, 150, 165, 255))
                put(img, x + dx, row + 1 + (x // 3) % 2, (90, 90, 105, 255))
    return outline(img)


def gate_altar():
    img = canvas(28, 22)
    for y in range(10, 22):
        for x in range(2, 26):
            col = lerp((150, 140, 130), (80, 75, 70), (y - 10) / 12)
            if y in (10, 11):
                col = (180, 170, 160)
            put(img, x, y, col + (255,))
    for x in range(6, 22):
        for y in range(4, 10):
            put(img, x, y, lerp((170, 160, 150), (110, 100, 95), (y - 4) / 6) + (255,))
    for x in (9, 14, 19):
        put(img, x, 15, (130, 230, 255, 255))
        put(img, x, 16, (90, 180, 240, 255))
    for y in range(0, 4):
        put(img, 13, y, (180, 240, 255, 255))
        put(img, 14, y, (220, 250, 255, 255))
    return outline(img, (30, 26, 24, 255))


def main():
    os.makedirs(os.path.join(SPRITES, "world"), exist_ok=True)
    seal_core().save(os.path.join(SPRITES, "characters", "seal_core.png"))
    gate_altar().save(os.path.join(SPRITES, "world", "gate_altar.png"))
    print("ok")


if __name__ == "__main__":
    main()
