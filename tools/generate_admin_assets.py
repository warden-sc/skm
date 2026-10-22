#!/usr/bin/env python3
"""운영자 모드(개발자 강림) · 운영자 장비의 그림.

  assets/sprites/characters/developer.png      개발자 (흰 망토 · 금빛 테두리 · 머리 위 빛의 고리 · 빛나는 석판) 32x32
  assets/sprites/weapons/admin_sword.png        운영자의 검
  assets/sprites/weapons/admin_bow.png          운영자의 활 (+ _held: 손에 든 모습)
  assets/sprites/weapons/admin_staff.png        운영자의 지팡이
  assets/sprites/{shields,helmets,armors,boots,accessories}/admin_*.png  운영자의 방패 · 투구 · 갑옷(앞에 운영자의 문양) · 신발 · 반지 · 팔찌 · 펜던트
  assets/sprites/effects/admin_wings.png        갑옷 등 뒤의 날개 (착용하면 용사 뒤에서 퍼덕임)
  assets/sprites/effects/seraph.png             날개를 펼친 용사 (스킬로 하늘에 오를 때)
  assets/sprites/effects/divine_sword.png       하늘에서 내리꽂히는 거대한 빛의 검 · light_sword.png 작은 빛의 검
  assets/sprites/skills/{seraph_dive,heaven_judgement,genesis_light}.png  운영자 무기 스킬 아이콘
실행: python3 tools/generate_admin_assets.py   (Pillow 필요)
"""
import math
import os

from PIL import Image

from generate_trial_assets import canvas, lerp, outline, put

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


# ============================================================ 운영자 방어구 · 장신구 (신에 가까운 성기사 — 흰 금속 · 금 테두리 · 하늘빛 보석)
SILVER = (235, 238, 248)
SILVER_DARK = (170, 178, 200)


def emblem(img, cx, cy, small=False):
    """운영자의 문양: 금빛 원 안의 네 갈래 빛(별) + 가운데 하늘빛 보석"""
    r = 2 if small else 3
    for a in range(0, 360, 20 if small else 12):
        put(img, cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)), GOLD + (255,))
    for d in range(-r - 1, r + 2):
        put(img, cx + d, cy, GOLD + (255,))
        put(img, cx, cy + d, GOLD + (255,))
    put(img, cx, cy, CYAN + (255,))


def admin_shield():
    img = canvas(16, 16)
    for y in range(1, 15):
        half = 6 if y < 9 else max(0, 6 - (y - 8))
        for x in range(8 - half, 8 + half):
            edge = x in (8 - half, 8 + half - 1) or y == 1
            put(img, x, y, (GOLD if edge else lerp(SILVER, SILVER_DARK, y / 16)) + (255,))
    emblem(img, 7.5, 6.5)
    return outline(img)


def admin_helmet(worn=False):
    img = canvas(16, 16)
    top = 1 if worn else 4
    for y in range(top, top + 5):
        for x in range(3, 13):
            d = math.hypot((x - 7.5) / 5.0, (y - (top + 4)) / 4.5)
            if d <= 1.0:
                put(img, x, y, lerp(SILVER, SILVER_DARK, (y - top) / 6) + (255,))
    for x in range(3, 13):
        put(img, x, top + 4, GOLD + (255,))
    # 양옆의 작은 날개
    for i in range(4):
        put(img, 2 - i * 0.5, top + 2 - i, (255, 255, 255, 255))
        put(img, 13 + i * 0.5, top + 2 - i, (255, 255, 255, 255))
        put(img, 2 - i * 0.5, top + 3 - i, GOLD + (255,))
        put(img, 13 + i * 0.5, top + 3 - i, GOLD + (255,))
    put(img, 7, top + 1, CYAN + (255,))
    put(img, 8, top + 1, CYAN + (255,))
    if worn:
        # 얼굴이 보이도록 아래쪽은 비움 (투구 테두리만)
        return outline(img, (60, 50, 80, 255))
    for y in range(top + 5, top + 9):
        for x in (4, 5, 10, 11):
            put(img, x, y, SILVER_DARK + (255,))
    return outline(img)


def admin_armor(worn=False):
    img = canvas(16, 16)
    rows = range(8, 13) if worn else range(3, 14)
    for y in rows:
        half = 5 if worn else (6 if y < 11 else 5)
        for x in range(8 - half, 8 + half):
            edge = x in (8 - half, 8 + half - 1)
            put(img, x, y, (GOLD if edge else lerp(SILVER, SILVER_DARK, abs(x - 7.5) / half)) + (255,))
    if worn:
        for x in range(3, 13):
            put(img, x, 12, GOLD + (255,))
        emblem(img, 7.5, 10, small=True)
    else:
        for x in (2, 3, 12, 13):
            for y in (3, 4):
                put(img, x, y, GOLD + (255,))
        emblem(img, 7.5, 7.5)
    return outline(img, (60, 50, 80, 255))


def admin_boots(worn=False):
    img = canvas(16, 16)
    if worn:
        for bx in (3, 10):
            for y in (13, 14, 15):
                for x in range(bx, bx + 3):
                    put(img, x, y, (GOLD if y == 13 else SILVER) + (255,))
            put(img, bx - 1, 13, (255, 255, 255, 255))
            put(img, bx + 3, 13, (255, 255, 255, 255))
        return img
    for bx in (2, 9):
        for y in range(5, 13):
            for x in range(bx, bx + 4):
                put(img, x, y, (GOLD if y in (5, 11) else SILVER) + (255,))
        for x in range(bx, bx + 6):
            put(img, x, 12, SILVER_DARK + (255,))
        for i in range(3):
            put(img, bx - 1 - i, 6 - i, (255, 255, 255, 255))
    return outline(img)


def admin_ring():
    img = canvas(16, 16)
    for a in range(0, 360, 8):
        put(img, 8 + 5 * math.cos(math.radians(a)), 9 + 4 * math.sin(math.radians(a)), GOLD + (255,))
        put(img, 8 + 4 * math.cos(math.radians(a)), 9 + 3 * math.sin(math.radians(a)), GOLD_DARK + (255,))
    for y in range(2, 6):
        for x in range(6, 11):
            if abs(x - 8) + abs(y - 3.5) <= 2.5:
                put(img, x, y, lerp(WHITE, CYAN, (abs(x - 8) + abs(y - 3.5)) / 2.5) + (255,))
    return outline(img)


def admin_bracelet():
    img = canvas(16, 16)
    for a in range(0, 360, 6):
        for r, col in ((6, GOLD), (5, SILVER), (4, GOLD_DARK)):
            put(img, 8 + r * math.cos(math.radians(a)), 8 + r * 0.55 * math.sin(math.radians(a)), col + (255,))
    emblem(img, 8, 11, small=True)
    return outline(img)


def admin_pendant():
    img = canvas(16, 16)
    for t in range(0, 181, 10):
        a = math.radians(t)
        put(img, 8 + 6 * math.cos(a), 1 + 5 * math.sin(a), GOLD_DARK + (255,))
    for y in range(7, 15):
        for x in range(3, 13):
            if math.hypot(x - 7.5, y - 10.5) <= 4.0:
                put(img, x, y, lerp(WHITE, GOLD, math.hypot(x - 7.5, y - 10.5) / 4.0) + (255,))
    emblem(img, 7.5, 10.5, small=True)
    return outline(img)


def wings(w=32, h=20):
    """흰 깃털 날개 한 쌍 (가운데가 몸통 자리) — 끝은 금빛"""
    img = canvas(w, h)
    cx = w / 2 - 0.5
    for side in (-1, 1):
        for i in range(5):  # 깃털 다섯 겹
            length = 13 - i * 1.6
            base_y = 6 + i * 2.2
            for t in range(0, int(length * 4)):
                d = t / 4
                x = cx + side * (2 + d)
                y = base_y - math.sin(d / length * math.pi * 0.9) * (6 - i) + d * 0.25
                col = lerp(WHITE, GOLD, (d / length) ** 3)
                put(img, x, y, col + (255,))
                put(img, x, y + 1, lerp((225, 230, 245), GOLD_DARK, (d / length) ** 3) + (255,))
    return outline(img, (70, 60, 90, 255))


def seraph():
    """날개를 펼친 용사 (32x32) — 스킬로 하늘에 오를 때"""
    img = canvas(32, 32)
    wing = wings(32, 20)
    img.alpha_composite(wing, (0, 4))
    body = Image.open(os.path.join(SPRITES, "characters", "player.png")).convert("RGBA")
    armor = admin_armor(True)
    helmet = admin_helmet(True)
    body.alpha_composite(armor)
    body.alpha_composite(helmet)
    img.alpha_composite(body, (8, 14))
    return img


def divine_sword():
    """하늘에서 내리꽂히는 거대한 빛의 검 (칼끝이 아래)"""
    img = canvas(16, 48)
    for y in range(0, 10):
        put(img, 7, y, GOLD_DARK + (255,))
        put(img, 8, y, GOLD + (255,))
    for x in range(1, 15):
        put(img, x, 10, GOLD + (255,))
        put(img, x, 11, GOLD_DARK + (255,))
    for y in range(12, 46):
        half = 3 if y < 40 else max(0, 3 - (y - 40) * 0.5)
        for x in range(8 - int(half), 8 + int(half) + 1):
            col = WHITE if abs(x - 8) <= 1 else CYAN
            put(img, x, y, col + (255,))
    emblem(img, 7.5, 4, small=True)
    return outline(img, (60, 70, 110, 255))


def light_sword():
    img = canvas(8, 24)
    for x in range(1, 7):
        put(img, x, 5, GOLD + (255,))
    for y in range(0, 5):
        put(img, 4, y, GOLD + (255,))
    for y in range(6, 23):
        put(img, 3, y, WHITE + (255,))
        put(img, 4, y, CYAN + (255,))
    return img


def skill_icon(kind):
    img = canvas(20, 20)
    for y in range(20):
        for x in range(20):
            put(img, x, y, lerp((40, 34, 70), (110, 90, 40), y / 20) + (255,))
    if kind == "seraph_dive":
        w = wings(20, 12)
        img.alpha_composite(w, (0, 1))
        for y in range(5, 19):
            put(img, 9, y, WHITE + (255,))
            put(img, 10, y, CYAN + (255,))
        for x in range(6, 14):
            put(img, x, 7, GOLD + (255,))
    elif kind == "heaven_judgement":
        for i in range(5):
            x0 = 3 + i * 3.5
            for t in range(10):
                put(img, x0 + t * 0.3, 2 + t * 1.6, (WHITE if t > 6 else GOLD) + (255,))
        w = wings(20, 12)
        img.alpha_composite(w, (0, 0))
    else:
        for a in range(0, 360, 6):
            put(img, 10 + 7 * math.cos(math.radians(a)), 10 + 7 * math.sin(math.radians(a)), GOLD + (255,))
            put(img, 10 + 4 * math.cos(math.radians(a)), 10 + 4 * math.sin(math.radians(a)), CYAN + (255,))
        for d in range(-8, 9):
            put(img, 10 + d, 10, WHITE + (255,))
            put(img, 10, 10 + d, WHITE + (255,))
    return img


def main():
    developer().save(os.path.join(SPRITES, "characters", "developer.png"))
    admin_sword().save(os.path.join(SPRITES, "weapons", "admin_sword.png"))
    admin_bow().save(os.path.join(SPRITES, "weapons", "admin_bow.png"))
    admin_bow(True).save(os.path.join(SPRITES, "weapons", "admin_bow_held.png"))
    admin_staff().save(os.path.join(SPRITES, "weapons", "admin_staff.png"))
    for folder, name, img in (
        ("shields", "admin_shield", admin_shield()),
        ("helmets", "admin_helmet", admin_helmet()), ("helmets", "admin_helmet_worn", admin_helmet(True)),
        ("armors", "admin_armor", admin_armor()), ("armors", "admin_armor_worn", admin_armor(True)),
        ("boots", "admin_boots", admin_boots()), ("boots", "admin_boots_worn", admin_boots(True)),
        ("accessories", "admin_ring", admin_ring()), ("accessories", "admin_bracelet", admin_bracelet()),
        ("accessories", "admin_pendant", admin_pendant()),
        ("effects", "admin_wings", wings()), ("effects", "seraph", seraph()),
        ("effects", "divine_sword", divine_sword()), ("effects", "light_sword", light_sword()),
        ("skills", "seraph_dive", skill_icon("seraph_dive")), ("skills", "heaven_judgement", skill_icon("heaven_judgement")),
        ("skills", "genesis_light", skill_icon("genesis_light")),
    ):
        img.save(os.path.join(SPRITES, folder, name + ".png"))
    print("ok")


if __name__ == "__main__":
    main()
