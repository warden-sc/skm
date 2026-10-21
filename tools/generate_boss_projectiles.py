#!/usr/bin/env python3
"""후반(60스테이지 이후) 보스의 전용 탄 그림 — 둥근 구체 대신 보스 컨셉에 맞는 모양 (assets/sprites/projectiles/).

탄은 날아가는 방향으로 돌아가므로, 방향이 있는 그림은 오른쪽이 앞입니다.
실행: python3 tools/generate_boss_projectiles.py   (Pillow 필요)
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "projectiles")
K = (24, 18, 28, 255)


def canvas(w, h=None):
    return Image.new("RGBA", (w, h if h else w), (0, 0, 0, 0))


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def put(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), col)


def outline(img, col=K):
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


def solar_flare():
    """파에톤: 태양 전차에서 떨어지는 불꽃 혜성 (앞은 하얀 핵, 뒤로 금빛 꼬리)"""
    img = canvas(18, 10)
    for x in range(18):
        for y in range(10):
            hx = 13.0
            d_head = math.hypot(x - hx, (y - 4.5) * 1.1) / 4.2
            tail = x < hx and abs(y - 4.5) <= 3.8 * (x / hx) ** 1.4
            if d_head <= 1.0 or tail:
                t = d_head if d_head <= 1.0 else 0.6 + 0.4 * (1 - x / hx)
                col = lerp((255, 255, 235), (255, 150, 30), t)
                a = 255 if d_head <= 1.0 else int(255 * (0.35 + 0.65 * x / hx))
                put(img, x, y, col + (a,))
    return img


def omen_eye():
    """카산드라 · 거짓 예언자: 불길한 예언의 눈 (보라 아몬드 눈 + 붉은 홍채)"""
    img = canvas(14, 10)
    for x in range(14):
        for y in range(10):
            u, v = (x - 6.5) / 6.8, (y - 4.5) / 4.6
            if abs(v) <= (1 - u * u) * 1.0:
                put(img, x, y, lerp((235, 220, 255), (150, 90, 210), abs(v)) + (255,))
    for x in range(14):
        for y in range(10):
            d = math.hypot(x - 7.5, y - 4.5)
            if d <= 2.6:
                put(img, x, y, ((255, 60, 80) if d > 1.1 else (20, 0, 10)) + (255,))
    put(img, 6, 3, (255, 255, 255, 255))
    return outline(img, (60, 20, 70, 255))


def gold_coin():
    """미다스 · 마몬 · 수상한 상인: 빙글 도는 금화 (비스듬한 타원 + 테두리 + 반짝임)"""
    img = canvas(12, 12)
    for x in range(12):
        for y in range(12):
            d = math.hypot((x - 5.5) / 4.0, (y - 5.5) / 5.4)
            if d <= 1.0:
                col = (255, 240, 140) if d < 0.62 else ((235, 180, 50) if d < 0.85 else (170, 110, 20))
                put(img, x, y, col + (255,))
    for y in range(3, 9):
        put(img, 5, y, (200, 140, 30, 255))
    put(img, 4, 3, (255, 255, 255, 255))
    put(img, 3, 4, (255, 255, 220, 255))
    return outline(img, (90, 50, 10, 255))


def laurel_leaf():
    """피티아: 신탁의 월계수 잎 (잎맥 + 은빛 빛)"""
    img = canvas(14, 7)
    for x in range(14):
        half = 3.2 * math.sin(math.pi * x / 13.0)
        for y in range(7):
            if abs(y - 3) <= half:
                put(img, x, y, lerp((200, 255, 170), (60, 150, 70), abs(y - 3) / 3.2) + (255,))
    for x in range(1, 13):
        put(img, x, 3, (240, 255, 220, 255))
    return outline(img, (20, 60, 30, 255))


def sun_lance():
    """아폴론: 태양의 창 (긴 빛줄기 + 금빛 창날)"""
    img = canvas(22, 8)
    for x in range(22):
        for y in range(8):
            if x < 15:
                d = abs(y - 3.5) / 1.6
                if d <= 1.0:
                    put(img, x, y, lerp((255, 255, 230), (255, 190, 60), d) + (int(255 * (0.4 + 0.6 * x / 15)),))
            else:
                half = (21 - x) * 0.55 + 0.4
                if abs(y - 3.5) <= half:
                    put(img, x, y, lerp((255, 255, 255), (255, 210, 80), abs(y - 3.5) / max(half, 0.1)) + (255,))
    return img


def sleep_z():
    """벨페고르: 졸음의 「Z」 구름 (보라 구름 위 하얀 Z)"""
    img = canvas(12, 12)
    for x in range(12):
        for y in range(12):
            d = min(math.hypot(x - 4, y - 6) / 3.6, math.hypot(x - 7.5, y - 5) / 4.0, math.hypot(x - 6, y - 8) / 3.4)
            if d <= 1.0:
                put(img, x, y, lerp((215, 200, 255), (130, 110, 200), d) + (230,))
    for x in range(3, 9):
        put(img, x, 3, (255, 255, 255, 255))
        put(img, x, 8, (255, 255, 255, 255))
    for i in range(5):
        put(img, 8 - i - 0.2 * i, 4 + i, (255, 255, 255, 255))
    return img


def fly():
    """바알제붑: 파리 (검은 몸통 + 반투명 날개 + 붉은 눈)"""
    img = canvas(12, 10)
    for x in range(12):
        for y in range(10):
            if math.hypot((x - 6) / 3.6, (y - 5.5) / 2.2) <= 1.0:
                put(img, x, y, (35, 40, 30, 255))
    for cx, cy in ((4.5, 2.3), (7.5, 2.3)):
        for x in range(12):
            for y in range(10):
                if math.hypot((x - cx) / 2.4, (y - cy) / 1.8) <= 1.0 and img.getpixel((x, y))[3] == 0:
                    put(img, x, y, (190, 220, 230, 170))
    put(img, 9, 5, (220, 40, 40, 255))
    put(img, 9, 6, (220, 40, 40, 255))
    for x in (4, 6):
        put(img, x, 6, (80, 90, 60, 255))
    return img


def beast_sigil():
    """거짓 예언자: 짐승의 표 (검붉은 원 문양 + 뿔 두 개)"""
    img = canvas(12, 12)
    for x in range(12):
        for y in range(12):
            d = math.hypot(x - 5.5, y - 6.5)
            if 3.0 <= d <= 4.6:
                put(img, x, y, (200, 30, 40, 255))
            elif d < 3.0:
                put(img, x, y, (60, 0, 10, 220))
    for i in range(4):
        put(img, 2 + i * 0.3, 2.5 - i * 0.6, (240, 220, 200, 255))
        put(img, 9 - i * 0.3, 2.5 - i * 0.6, (240, 220, 200, 255))
    for y in range(4, 10):
        put(img, 5, y, (255, 120, 80, 255))
    for x in range(3, 9):
        put(img, x, 6, (255, 120, 80, 255))
    return outline(img, (30, 0, 5, 255))


def abyss_star():
    """타락한 별: 검게 타는 별 조각 (보라 별 + 검은 연기 꼬리)"""
    img = canvas(16, 12)
    cx, cy = 11.0, 6.0
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 4.6 if i % 2 == 0 else 2.0
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))

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

    for x in range(16):
        for y in range(12):
            if x < 9 and abs(y - cy) <= 2.6 * (x / 9.0):
                put(img, x, y, (40, 20, 60, int(220 * x / 9.0)))
            if inside(x + 0.5, y + 0.5):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                put(img, x, y, ((250, 230, 255) if d < 1.6 else (150, 80, 220)) + (255,))
    return img


def locust():
    """아바돈: 무저갱의 메뚜기 (금관을 쓴 사람 얼굴 · 전갈 꼬리 — 계 9장)"""
    img = canvas(16, 10)
    for x in range(16):
        for y in range(10):
            if math.hypot((x - 8) / 5.2, (y - 5.5) / 2.4) <= 1.0:
                put(img, x, y, lerp((120, 110, 70), (60, 50, 30), abs(y - 5.5) / 2.4) + (255,))
    for x in range(1, 5):
        put(img, x, 5 - (4 - x) * 0.5, (150, 40, 40, 255))
    put(img, 1, 3, (230, 60, 60, 255))
    for x in range(11, 15):
        for y in range(3, 8):
            if math.hypot(x - 13, y - 5.5) <= 2.2:
                put(img, x, y, (230, 190, 150, 255))
    for x in range(12, 15):
        put(img, x, 2, (255, 210, 60, 255))
    put(img, 14, 5, (200, 30, 30, 255))
    for x0 in (6, 9):
        for i in range(4):
            put(img, x0 + i * 0.3, 1 + i * 0.7, (200, 220, 230, 160))
    return outline(img, (30, 20, 10, 255))


def main():
    save(solar_flare(), "solar_flare.png")
    save(omen_eye(), "omen_eye.png")
    save(gold_coin(), "gold_coin.png")
    save(laurel_leaf(), "laurel_leaf.png")
    save(sun_lance(), "sun_lance.png")
    save(sleep_z(), "sleep_z.png")
    save(fly(), "fly.png")
    save(beast_sigil(), "beast_sigil.png")
    save(abyss_star(), "abyss_star.png")
    save(locust(), "locust.png")
    print("ok")


if __name__ == "__main__":
    main()
