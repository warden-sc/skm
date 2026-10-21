#!/usr/bin/env python3
"""용 보스의 브레스 · 고유 공격 그림 (assets/sprites/projectiles/).

브레스는 「숨결 덩어리」 투사체를 촘촘히 뿜는 방식이라, 덩어리 하나하나가 오른쪽(진행 방향)을 향한 모양입니다.
투사체는 날아가며 커지고(ProjectileSpec.grow) 끝에서 흐려져 원뿔 모양의 숨결이 됩니다.
실행: python3 tools/generate_breath_sprites.py   (Pillow 필요)
"""
import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "projectiles")


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def tongue(w, h, inner, mid, outer, seed, ragged=0.25, alpha_tail=True):
    """오른쪽으로 뻗는 불꽃 혀 모양 (앞은 둥글고 뒤로 갈수록 가늘고 흐려짐)"""
    rnd = random.Random(seed)
    img = canvas(w, h)
    cy = (h - 1) / 2
    head = w * 0.68
    for x in range(w):
        # 머리 쪽(오른쪽)이 두껍고 꼬리(왼쪽)로 갈수록 가늘게
        if x <= head:
            half = (h / 2) * (0.25 + 0.75 * (x / head) ** 0.7)
        else:
            half = (h / 2) * math.sqrt(max(0.0, 1 - ((x - head) / (w - head)) ** 2))
        wob = rnd.uniform(-ragged, ragged) * h * 0.3
        for y in range(h):
            d = abs(y - cy + wob * 0.4) / max(half, 0.01)
            if d > 1.0:
                continue
            t = max(d, 1 - x / w * 1.1)
            col = inner if t < 0.35 else (mid if t < 0.7 else outer)
            a = 255
            if alpha_tail and x < w * 0.35:
                a = int(255 * (0.35 + 0.65 * x / (w * 0.35)))
            img.putpixel((x, y), col + (a,))
    return img


def cloud(size, inner, outer, seed, blobs=5, specks=None):
    """뭉게뭉게한 구름 덩어리 (가스 · 먼지 · 냉기)"""
    rnd = random.Random(seed)
    img = canvas(size, size)
    c = (size - 1) / 2
    centers = [(c + rnd.uniform(-size * 0.22, size * 0.22), c + rnd.uniform(-size * 0.2, size * 0.2), rnd.uniform(size * 0.22, size * 0.34)) for _ in range(blobs)]
    for y in range(size):
        for x in range(size):
            best = 9.0
            for (bx, by, r) in centers:
                best = min(best, math.hypot(x - bx, y - by) / r)
            if best <= 1.0:
                col = lerp(inner, outer, best)
                a = int(255 * (1.0 if best < 0.7 else 1.0 - (best - 0.7) / 0.3 * 0.6))
                img.putpixel((x, y), col + (a,))
    if specks:
        for _ in range(specks[1]):
            x, y = rnd.randrange(2, size - 2), rnd.randrange(2, size - 2)
            if img.getpixel((x, y))[3] > 0:
                img.putpixel((x, y), specks[0] + (255,))
    return img


def gust(w, h, col, edge):
    """바람의 숨결: 앞으로 휘어진 초승달 모양 바람"""
    img = canvas(w, h)
    cy = (h - 1) / 2
    for y in range(h):
        for x in range(w):
            # 초승달: 큰 원에서 왼쪽으로 밀린 원을 뺌
            d1 = math.hypot((x - w * 0.42) / (w * 0.55), (y - cy) / (h * 0.52))
            d2 = math.hypot((x + w * 0.02) / (w * 0.5), (y - cy) / (h * 0.7))
            if d1 <= 1.0 and d2 > 1.0:
                t = min(1.0, (d2 - 1.0) * 3.0)
                img.putpixel((x, y), lerp(edge, col, t) + (int(255 * (0.55 + 0.45 * t)),))
    return img


def spit(w, h, inner, outer, seed):
    """독 침: 앞이 둥근 물방울 + 뒤로 끌리는 꼬리 + 방울 튐"""
    rnd = random.Random(seed)
    img = canvas(w, h)
    cy = (h - 1) / 2
    hx = w - h * 0.55
    r = h * 0.48
    for y in range(h):
        for x in range(w):
            dh = math.hypot(x - hx, y - cy) / r
            tail = x < hx and abs(y - cy) <= r * (x / hx) ** 1.5
            if dh <= 1.0 or tail:
                t = dh if dh <= 1.0 else 0.8
                col = lerp(inner, outer, min(t, 1.0))
                a = 255 if dh <= 1.0 else int(255 * (0.4 + 0.6 * x / hx))
                img.putpixel((x, y), col + (a,))
    img.putpixel((int(hx + 1), int(cy - 1)), (240, 255, 220, 255))
    for _ in range(3):
        x, y = rnd.randrange(0, int(hx * 0.6)), rnd.randrange(0, h)
        img.putpixel((x, y), outer + (200,))
    return img


def wisp(w, h, inner, outer, eye):
    """영혼 불꽃(망령): 둥근 머리 + 하늘거리는 꼬리, 눈 두 개"""
    img = canvas(w, h)
    cy = (h - 1) / 2
    hx, r = w - h * 0.55, h * 0.5
    for y in range(h):
        for x in range(w):
            dh = math.hypot(x - hx, y - cy) / r
            wave = math.sin(x * 0.9) * h * 0.12
            tail = x < hx and abs(y - cy - wave) <= r * (0.25 + 0.75 * (x / hx) ** 1.2)
            if dh <= 1.0 or tail:
                t = min(dh, 1.0) if dh <= 1.0 else 0.85
                a = 255 if dh <= 1.0 else int(255 * (0.3 + 0.7 * x / hx))
                img.putpixel((x, y), lerp(inner, outer, t) + (a,))
    ex = int(hx + r * 0.25)
    for ey in (int(cy - r * 0.35), int(cy + r * 0.35)):
        if 0 <= ey < h:
            img.putpixel((ex, ey), eye + (255,))
    return img


def rune(size, col, glow):
    """고대 룬 조각: 빛나는 마름모 + 가운데 룬 획"""
    img = canvas(size, size)
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = abs(x - c) / (size * 0.5) + abs(y - c) / (size * 0.36)
            if d <= 1.0:
                img.putpixel((x, y), lerp(col, glow, d) + (255,))
    mid = int(c)
    for x in range(int(c - size * 0.25), int(c + size * 0.3)):
        img.putpixel((x, mid), (255, 255, 250, 255))
    for y in range(int(c - size * 0.18), int(c + size * 0.2)):
        img.putpixel((mid, y), (255, 255, 250, 255))
    return img


def main():
    # 불꽃 브레스 (와이번 · 베르단) — 하양 → 노랑 → 주황 → 빨강
    save(tongue(16, 10, (255, 250, 210), (255, 196, 70), (232, 80, 36), 1), "breath_fire.png")
    # 베르단의 업화 (더 붉고 검붉은 테두리)
    save(tongue(18, 12, (255, 236, 160), (250, 120, 40), (150, 30, 30), 2), "breath_inferno.png")
    # 냉기 브레스 (코퀴로스) — 서리 안개 + 얼음 알갱이
    save(cloud(14, (245, 255, 255), (120, 200, 245), 3, specks=((255, 255, 255), 6)), "breath_frost.png")
    # 대지의 숨결 (테라곤) — 모래 먼지 + 돌 알갱이
    save(cloud(14, (225, 195, 140), (130, 95, 60), 4, specks=((90, 70, 50), 7)), "breath_sand.png")
    # 바람의 숨결 (제피로스) — 초승달 바람
    save(gust(14, 12, (235, 255, 245), (120, 220, 190)), "breath_gust.png")
    # 독 가스 (콜키스의 용) — 초록 연기
    save(cloud(14, (200, 255, 140), (60, 150, 60), 5, specks=((230, 255, 120), 5)), "breath_poison.png")
    # 죽음의 숨결 (헬리시온) — 보라 · 청록 망령 연기
    save(cloud(14, (210, 170, 255), (70, 40, 110), 6, specks=((140, 255, 210), 6)), "breath_necro.png")
    # 고대의 숨결 (아르케) — 금빛 성광
    save(tongue(16, 10, (255, 255, 240), (255, 230, 140), (220, 170, 70), 7), "breath_holy.png")
    # 고유 탄: 독 침 (콜키스) · 영혼 불꽃 (헬리시온 부패탄) · 고대 룬 조각 (아르케)
    save(spit(14, 8, (220, 255, 150), (70, 160, 50), 8), "venom_spit.png")
    save(wisp(14, 9, (225, 200, 255), (90, 50, 140), (140, 255, 200)), "soul_wisp.png")
    save(rune(12, (255, 236, 170), (200, 150, 60)), "rune_shard.png")
    print("ok")


if __name__ == "__main__":
    main()
