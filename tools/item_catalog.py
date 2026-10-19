"""장비 목록 생성기: 모든 장비의 .tres · 아이콘 · ItemDB 경로 목록을 한 번에 만듭니다.

    python3 tools/item_catalog.py            # 데이터 + 아이콘 생성
    python3 tools/item_catalog.py --sheet    # 밸런스 표만 출력

- 등급(일반 · 희귀 · 레어 · 전설)마다 하급 · 중급 · 상급 3단계 = 단계(t) 0 ~ 11, 신화 = 12
- 수치는 스테이지 데이터(보스 · 몬스터의 체력 · 방어력 · 공격력, 예전 단위 × Balance.K)에서 계산
  · 무기: 그 단계가 쓰이는 스테이지의 보스를 같은 단계 장비로 약 55초에 잡도록
  · 방어구: 보스 몸통 박치기를 약 6~7번 버티도록 (방어력 = 보스 공격의 40%)
  · 값: 그 단계가 쓰이기 시작하는 스테이지부터 5스테이지 동안 버는 골드 기준
- 신화: 10스테이지마다 보스가 하나씩 떨어뜨림 (상점 없음). 전설 상급보다 한참 강함
"""
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import generate_sprites as gs  # noqa: E402

K = 10  # scripts/core/balance.gd 의 Balance.K
FIT = [1, 4, 7, 11, 21, 31, 41, 51, 61, 71, 81, 91]          # 단계가 「제 실력」을 내기 시작하는 스테이지
REP = [1, 5, 8, 14, 24, 34, 44, 54, 64, 74, 84, 94]           # 그 단계의 대표 스테이지
TIER_NAMES = ["하급", "중급", "상급"]
RARITY_NAMES = ["일반", "희귀", "레어", "전설", "신화"]


# ============================================================ 스테이지 데이터
def _node_props(path):
    text = open(os.path.join(REPO, path.replace("res://", "")), encoding="utf-8").read()
    m = re.search(r'\[node name="[^"]+" (?:type="[^"]+"|instance=[^\]]+)\]\n(.*?)(\n\[|\Z)', text, re.S)
    props = {}
    if m:
        for line in m.group(1).split("\n"):
            if "=" in line:
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()
    inherit = re.search(r'\[node name="[^"]+" instance=ExtResource\("([^"]+)"\)\]', text)
    if inherit:
        ext = {i: p for p, i in re.findall(r'\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="([^"]+)"\]', text)}
        base = _node_props(ext[inherit.group(1)])
        base.update(props)
        props = base
    return props


def load_stages():
    stages = {}
    for n in range(1, 101):
        text = open(os.path.join(REPO, "data", "stages", f"stage_{n}.tres"), encoding="utf-8").read()
        ext = {i: p for p, i in re.findall(r'\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="([^"]+)"\]', text)}
        boss = _node_props(ext[re.search(r'boss_scene = ExtResource\("([^"]+)"\)', text).group(1)])
        m = re.search(r'enemy_scenes = Array\[PackedScene\]\(\[(.*?)\]\)', text)
        mobs = [_node_props(ext[i]) for i in re.findall(r'ExtResource\("([^"]+)"\)', m.group(1))] if m else []
        kill = int(re.search(r"kill_target = (\d+)", text).group(1)) if "kill_target" in text else 12
        g = lambda d, k, dv: float(d.get(k, dv))
        mob_avg = lambda k, dv: sum(g(x, k, dv) for x in mobs) / max(len(mobs), 1)
        stages[n] = {
            "boss_hp": g(boss, "max_hp", 20) * K, "boss_def": g(boss, "defense", 0) * K, "boss_cd": g(boss, "contact_damage", 8) * K,
            "mob_hp": mob_avg("max_hp", 20) * K, "mob_def": mob_avg("defense", 0) * K, "mob_cd": mob_avg("contact_damage", 8) * K,
            "gold": kill * (mob_avg("gold_min", 3) + mob_avg("gold_max", 6)) / 2 + (g(boss, "gold_min", 3) + g(boss, "gold_max", 6)) / 2 + 60 * n,
        }
    return stages


S = load_stages()


def at(t, key):
    return S[REP[min(t, 11)]][key]


def income5(t):
    f = FIT[min(t, 11)]
    return sum(S[n]["gold"] for n in range(f, min(f + 4, 100) + 1))


# ============================================================ 단계별 수치 표
RING_ATK = [.03, .05, .07, .08, .10, .12, .14, .16, .18, .20, .23, .26, .40]
RING_CRIT = [.02, .03, .04, .05, .06, .07, .08, .09, .10, .11, .13, .15, .20]
BR_CD = [.10, .15, .20, .25, .30, .35, .40, .45, .50, .55, .62, .70, 1.0]
SW_CRIT = [.05, .06, .08, .10, .11, .12, .14, .15, .16, .18, .19, .20, .25]
SW_MULT = [1.5, 1.5, 1.55, 1.6, 1.65, 1.7, 1.75, 1.8, 1.85, 1.9, 1.95, 2.0, 2.4]
SW_CD = [.36, .35, .34, .34, .33, .32, .32, .31, .30, .30, .29, .28, .26]
SW_RANGE = [38, 39, 40, 42, 44, 46, 48, 50, 52, 56, 58, 60, 72]
SW_ARC = [130, 132, 135, 140, 145, 150, 160, 165, 170, 180, 185, 190, 220]
BOOT_MOVE = [.04, .05, .06, .07, .08, .09, .10, .11, .12, .13, .14, .16, .30]
BLOCK = [.70, .74, .78, .80, .84, .88, .90, .92, .94, .95, .97, 1.0, 1.0]
BLOCK_ARC = [110, 113, 116, 120, 128, 136, 160, 165, 170, 180, 185, 190, 220]
PERFECT = [.30, .30, .31, .32, .33, .35, .38, .39, .40, .42, .43, .44, .50]
GUARD_MOVE = [.55, .55, .56, .58, .60, .60, .60, .62, .63, .65, .67, .70, .85]
GUARD_BREAK = [1.2, 1.15, 1.1, 1.0, .95, .9, .8, .75, .7, .6, .55, .5, .4]
TIER_PRICE = [1.0, 1.25, 1.5]
MYTHIC = 12


def rep_t(t):
    return min(t, 11)


def accessory_mult(t):
    """같은 단계 반지 · 팔찌를 꼈을 때 검의 평균 배율"""
    return (1 + RING_ATK[t]) * (1 + (SW_CRIT[t] + RING_CRIT[t]) * (SW_MULT[t] - 1 + BR_CD[t]))


def bracelet_pen(t):
    return round(0.12 * at(t, "boss_def")) if t < MYTHIC else round(0.2 * at(11, "boss_def"))


def sword_damage(t):
    if t == MYTHIC:
        return round(sword_damage(11) * 1.7, -1)
    rate = 1.0 / SW_CD[t]
    eff = at(t, "boss_hp") / (55.0 * rate)
    raw = (eff + max(at(t, "boss_def") - bracelet_pen(t), 0)) / accessory_mult(t)
    if t == 0:
        raw = max(raw, 150)
    return int(round(raw, -1)) if raw >= 100 else int(round(raw))


def sword_raw_dps(t):
    return sword_damage(t) * (1 + SW_CRIT[t] * (SW_MULT[t] - 1)) / SW_CD[t]


def total_defense(t):
    if t == MYTHIC:
        return round(total_defense(11) * 1.45)
    return 0.40 * at(t, "boss_cd")


def hp_bonus(t):
    if t == MYTHIC:
        return round(hp_bonus(11) * 1.6)
    return max(3.9 * at(t, "boss_cd") - 1000, 50 + 60 * t)


def nice(v):
    if v >= 1000:
        return int(round(v, -2)) if v >= 10000 else int(round(v, -1))
    if v >= 100:
        return int(round(v, -1))
    return int(round(v))


def price(t, weight):
    if t == MYTHIC:
        return 0
    if t == 0:
        return None  # 기존 값 유지
    rarity_tier = t % 3
    raw = max(income5(t) * weight * TIER_PRICE[rarity_tier], 120 * (t + 1))
    before = price(t - 1, weight) if t >= 2 else 0
    return nice(max(raw, before * 1.1))  # 윗 단계가 항상 더 비싸게


# ============================================================ 그림 (16x16, 기존 도트 스타일)
def c(rgb):
    return tuple(rgb[:3]) + (255,)


def sword_painter(blade_l, blade_d, guard, grip, gem=None, broad=False, glow=None):
    img = gs.canvas(16)
    for x in range(5 if broad else 6, 14):
        gs.put(img, [(x, 15 - x)], c(blade_l))
        gs.put(img, [(x, 16 - x)], c(blade_d))
        if broad:
            gs.put(img, [(x + 1, 15 - x)], c(blade_l))
    gs.put(img, [(14, 1)], c(blade_l))
    gs.put(img, [(3, 8), (4, 9), (5, 10), (6, 11), (7, 12)], c(guard))
    gs.put(img, [(4, 11), (3, 12)], c(grip))
    gs.put(img, [(2, 13)], c(guard))
    if gem:
        gs.put(img, [(5, 10)], c(gem))
    if glow:
        for x in range(7, 14, 3):
            gs.put(img, [(x, 14 - x)], c(glow))
    return gs.outline(img)


def bow_painter(wood, string, accent=None, crossbow=False):
    img = gs.canvas(16)
    cx, cy, r = 3, 12, 10
    for i in range(0, 91, 3):
        a = math.radians(-90 + i)
        gs.put(img, [(round(cx + r * math.cos(a)), round(cy + r * math.sin(a)))], c(wood))
    for i in range(11):
        gs.put(img, [(cx + i, cy - 10 + i)], c(string))
    if crossbow:
        for i in range(8):
            gs.put(img, [(2 + i, 13 - i)], (90, 58, 40, 255))
    if accent:
        gs.put(img, [(10, 5), (11, 6), (12, 7)], c(accent))
    return gs.outline(img)


def bow_held_painter(wood, accent, crossbow=False):
    img = gs.canvas(16)
    for y in range(1, 15):
        t = (y - 7.5) / 6.5
        x = round(5 + 5 * (1 - t * t))
        gs.put(img, [(x, y)], c(wood))
        if 5 <= y <= 10:
            gs.put(img, [(x - 1, y)], c(wood))
    gs.put(img, [(9, 7), (9, 8), (10, 7), (10, 8)], c(accent))
    if crossbow:
        gs.rect(img, 2, 7, 13, 8, (90, 58, 40, 255))
    return gs.outline(img)


def staff_painter(orb, shaft, shape="square", prong=None):
    img = gs.canvas(16)
    for i in range(10):
        gs.put(img, [(2 + i, 13 - i)], c(shaft))
    if shape == "round":
        gs.ellipse(img, 12.5, 2.5, 2.4, 2.4, c(orb))
    elif shape == "crystal":
        gs.put(img, [(12, 0), (11, 1), (12, 1), (13, 1), (11, 2), (12, 2), (13, 2), (14, 2), (12, 3), (13, 3), (12, 4)], c(orb))
    else:
        gs.put(img, [(x, y) for x in range(11, 15) for y in range(1, 5)], c(orb))
    if prong:
        gs.put(img, [(10, 2), (10, 3), (13, 5), (14, 5)], c(prong))
    gs.put(img, [(12, 2)], (255, 255, 255, 255))
    return gs.outline(img)


def shield_painter(face, rim, emblem, shape="kite", emblem_kind="cross"):
    img = gs.canvas(16)
    for y in range(1, 15):
        for x in range(16):
            if shape == "round":
                d = math.hypot(x - 7.5, y - 7.5)
                if d <= 6.6:
                    img.putpixel((x, y), c(rim) if d > 5.2 else c(face))
                continue
            if shape == "tower":
                half = 5.5 if y < 12 else 5.5 * (14 - y) / 2.5
            else:
                half = 5.5 if y < 8 else 5.5 * (14 - y) / 6.0
            if abs(x - 7.5) <= half:
                edge = abs(x - 7.5) > half - 1.2 or y == 1
                img.putpixel((x, y), c(rim) if edge else c(face))
    if emblem_kind == "cross":
        gs.put(img, [(7, y) for y in range(3, 11)] + [(8, y) for y in range(3, 11)] + [(x, 5) for x in range(5, 11)], c(emblem))
    elif emblem_kind == "diamond":
        gs.put(img, [(7, 4), (8, 4), (6, 5), (9, 5), (6, 6), (9, 6), (7, 7), (8, 7), (7, 5), (8, 5), (7, 6), (8, 6)], c(emblem))
    elif emblem_kind == "sun":
        gs.ellipse(img, 7.5, 6.5, 2.2, 2.2, c(emblem))
        gs.put(img, [(7, 2), (8, 2), (7, 11), (8, 11), (3, 6), (12, 6)], c(emblem))
    elif emblem_kind == "boss":
        gs.put(img, [(7, 7), (8, 7), (7, 8), (8, 8)], c(emblem))
    gs.put(img, [(5, 3), (4, 4)], (255, 255, 255, 255))
    return gs.outline(img)


HELM_SHAPES = {
    "hood": ["................", ".....kkkkkk.....", "....kMMMMMMk....", "...kMMLMMMMMk...", "...kMMMMMMMMk...", "...kMD....DMk..."],
    "helm": ["................", ".....kkkkkk.....", "....kMMMMMMk....", "...kMMLMMMMDk...", "...kDMMMMMMDk...", "...kDD....DDk..."],
    "visor": ["................", ".....kkkkkk.....", "....kMMMMMMk....", "...kMMLMMMMDk...", "...kGGGGGGGGk...", "...kDD....DDk..."],
    "horned": ["..k........k....", "..kLkkkkkkkLk...", "...kMMMMMMMMk...", "...kMMLMMMMMk...", "...kGGGGGGGGk...", "...kMM....MMk..."],
    "winged": [".k............k.", "kLk.kkkkkk..kLk.", ".kLkMMMMMMk.kLk.", "..kkMMLMMMMDkk..", "...kGMMMMMMGk...", "...kDD....DDk..."],
    "crown": ["...k.k.kk.k.k...", "...kGkGkkGkGk...", "...kGGGGGGGGk...", "...kMMLMMMMMk...", "...kMMMMMMMMk...", "...kMD....DMk..."],
}


def helm_worn_painter(main, light, dark, gem, shape):
    pal = {"M": c(main), "L": c(light), "D": c(dark), "G": c(gem)}
    rows = HELM_SHAPES[shape]
    return gs.from_map(rows, pal=dict(gs.PAL, **pal))


def armor_worn_painter(main, light, dark, deco):
    img = gs.canvas(16)
    for y in range(8, 13):
        for x, ch in enumerate(gs.PLAYER[y]):
            if ch in "Bb":
                col = c(main) if ch == "B" else c(dark)
                if deco == "chain" and (x + y) % 2 == 0:
                    col = c(dark)
                if deco == "scale" and (x + 2 * y) % 3 == 0:
                    col = c(dark)
                gs.put(img, [(x, y)], col)
            elif ch == "c":
                gs.put(img, [(x, y)], c(light))
            elif ch == "k" and y in (8, 12):
                gs.put(img, [(x, y)], "k")
    if deco in ("trim", "rune"):
        gs.put(img, [(x, 8) for x in range(5, 11)], c(light))
        gs.put(img, [(7, 10), (8, 10)], c(light))
    if deco == "cross":
        gs.put(img, [(7, y) for y in range(9, 13)] + [(8, y) for y in range(9, 13)] + [(6, 10), (9, 10)], c(light))
    return img


def armor_icon_painter(main, light, dark, deco):
    img = gs.canvas(16)
    gs.rect(img, 3, 3, 12, 12, c(main))
    gs.rect(img, 1, 3, 3, 6, c(dark))
    gs.rect(img, 12, 3, 14, 6, c(dark))
    gs.rect(img, 6, 2, 9, 3, (0, 0, 0, 0))
    gs.rect(img, 4, 12, 11, 13, c(dark))
    if deco == "chain":
        for y in range(4, 12):
            for x in range(4, 12):
                if (x + y) % 2 == 0:
                    gs.put(img, [(x, y)], c(dark))
    elif deco == "scale":
        for y in range(4, 12):
            for x in range(4, 12):
                if (x + 2 * y) % 3 == 0:
                    gs.put(img, [(x, y)], c(dark))
    elif deco == "trim":
        gs.rect(img, 4, 4, 11, 4, c(light))
        gs.rect(img, 7, 6, 8, 10, c(light))
    elif deco == "rune":
        gs.rect(img, 4, 4, 11, 4, c(light))
        gs.put(img, [(6, 7), (9, 7), (7, 9), (8, 9), (6, 11), (9, 11)], c(light))
    elif deco == "cross":
        gs.rect(img, 7, 5, 8, 11, c(light))
        gs.rect(img, 5, 7, 10, 8, c(light))
    else:
        gs.rect(img, 7, 4, 8, 11, c(dark))
        gs.put(img, [(5, 6), (10, 6)], c(light))
    return gs.outline(img)


def boots_worn_painter(main, light, dark, wings):
    return gs.boots_worn(c(main), c(light), c(dark), wings)


def boots_icon_painter(main, light, dark, wings):
    return gs.boots_icon(c(main), c(light), c(dark), wings)


def accessory_painter(kind, metal, dark, gem):
    painter = {"bracelet": gs.bracelet_icon, "ring": gs.ring_icon, "pendant": gs.pendant_icon}[kind]
    return painter(tuple(metal[:3]), tuple(dark[:3]), tuple(gem[:3]))


def mythic_frame(img):
    """신화 장비 아이콘: 바깥 테두리를 진홍색으로"""
    out = img.copy()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = out.getpixel((x, y))
            if a and (r, g, b) == gs.PAL["k"][:3]:
                out.putpixel((x, y), (120, 20, 30, 255))
    return out


# 단계별 색 (주색, 밝은색, 어두운색, 보석)
FAMILY = {
    1: ((126, 98, 62), (176, 146, 96), (84, 62, 40), (110, 200, 110)),       # 여행자
    2: ((200, 130, 60), (240, 188, 112), (128, 78, 34), (230, 90, 60)),     # 청동
    4: ((150, 170, 200), (232, 236, 246), (78, 92, 128), (210, 50, 64)),    # 기사단
    5: ((190, 228, 240), (252, 255, 255), (106, 156, 188), (120, 220, 255)),  # 미스릴
    7: ((60, 150, 110), (150, 222, 150), (30, 82, 62), (255, 172, 60)),     # 용비늘
    8: ((72, 72, 112), (120, 204, 255), (40, 40, 70), (120, 224, 255)),     # 룬
    10: ((244, 244, 234), (255, 222, 120), (186, 188, 210), (150, 222, 255)),  # 천상(세라핌)
    11: ((112, 62, 172), (255, 216, 110), (60, 30, 100), (255, 120, 222)),  # 창세
}
FAMILY_STYLE = {
    1: dict(helm="hood", deco=None, shield="round", emblem="boss", wings=False, staff="round"),
    2: dict(helm="helm", deco="trim", shield="round", emblem="diamond", wings=False, staff="square"),
    4: dict(helm="visor", deco="cross", shield="kite", emblem="cross", wings=False, staff="crystal"),
    5: dict(helm="helm", deco="chain", shield="kite", emblem="diamond", wings=False, staff="crystal"),
    7: dict(helm="horned", deco="scale", shield="tower", emblem="diamond", wings=False, staff="round"),
    8: dict(helm="visor", deco="rune", shield="tower", emblem="diamond", wings=False, staff="crystal"),
    10: dict(helm="winged", deco="cross", shield="kite", emblem="sun", wings=True, staff="round"),
    11: dict(helm="crown", deco="rune", shield="tower", emblem="sun", wings=True, staff="crystal"),
}

# ============================================================ 장비 목록
# (id, 이름, 설명, 단계, 세트) — 기존 장비는 아이콘을 그대로 쓰고 수치만 다시 계산
SETS = {2: "bronze", 4: "knight", 5: "mithril", 7: "dragonscale", 8: "rune", 10: "celestial", 11: "genesis"}
FAMILY_PREFIX = {1: "traveler", 2: "bronze", 4: "knight", 5: "mithril", 7: "dragonscale", 8: "rune", 10: "seraph", 11: "genesis"}

ITEMS = []


def add(cat, item_id, name, desc, t, **extra):
    entry = dict(cat=cat, id=item_id, name=name, desc=desc, t=t)
    entry.update(extra)
    ITEMS.append(entry)


# ---- 검
add("sword", "rusty_sword", "녹슨 검", "오래된 훈련용 검. 짧지만 넓게 벤다.", 0, existing=True, element=0, color=(1, 0.85, 0.7))
add("sword", "traveler_sword", "여행자의 숏소드", "길 떠나는 모험가가 허리에 차는 짧은 검. 가볍고 다루기 쉽다.", 1, element=0, color=(1, 0.95, 0.85))
add("sword", "bronze_sword", "청동 검", "청동을 두드려 만든 넓은 칼날의 검. 무게가 실린 한 방이 묵직하다.", 2, element=0, color=(1, 0.8, 0.5))
add("sword", "iron_sword", "강철 검", "잘 벼려진 강철 검. 리치가 길고 묵직하다.", 3, existing=True, element=0, color=(0.8, 0.95, 1))
add("sword", "knight_sword", "기사단 장검", "왕국 기사단의 장검. 정직한 칼날이 넓게 휩쓴다.", 4, element=0, color=(0.85, 0.9, 1))
add("sword", "mithril_sword", "미스릴 검", "깃털처럼 가볍지만 무엇이든 베는 미스릴 검. 칼날에 서리가 서린다.", 5, element=2, color=(0.7, 0.95, 1))
add("sword", "flame_blade", "화염검", "불꽃이 깃든 대검. 휘두를 때마다 불티가 흩날린다.", 6, existing=True, element=1, color=(1, 0.55, 0.25))
add("sword", "dragonscale_sword", "용아검", "용의 송곳니를 갈아 만든 검. 베인 자리에 용의 불길이 남는다.", 7, element=1, color=(1, 0.65, 0.3))
add("sword", "rune_sword", "룬 대검", "칼날에 새긴 룬이 푸르게 빛나는 대검. 마력이 실린 참격이 멀리까지 닿는다.", 8, element=7, color=(0.55, 0.85, 1))
add("sword", "holy_sword", "성검 루멘", "빛의 가호를 받은 전설의 성검. 거대한 빛의 참격이 주위를 휩쓴다.", 9, existing=True, element=6, color=(1, 0.92, 0.6))
add("sword", "seraph_sword", "세라핌의 검", "천상의 불꽃으로 벼린 검. 휘두르면 여섯 날개 같은 빛이 펼쳐진다.", 10, element=6, color=(1, 0.95, 0.75))
add("sword", "genesis_sword", "창세의 검", "세상이 처음 갈라질 때의 빛을 담은 검. 별이 흩어지는 참격.", 11, element=7, color=(1, 0.75, 1))
add("sword", "abaddon_sword", "아바돈의 검", "무저갱의 왕 아바돈이 넘겨준 검. 휘두를 때마다 심연이 넓게 갈라진다.", MYTHIC, element=8, color=(0.85, 0.3, 0.5),
    icon=lambda: mythic_frame(sword_painter((255, 120, 150), (110, 20, 50), (40, 20, 30), (90, 20, 40), gem=(255, 60, 60), broad=True, glow=(255, 200, 220))))
add("dagger", "goblin_dagger", "고블린 단검", "고블린이 쓰던 독 묻은 단검. 리치는 짧지만 매우 빠르고 치명타가 잘 터진다.", 2, existing=True, element=5, color=(0.7, 1, 0.6), in_shop=False)

# ---- 활
add("bow", "hunter_bow", "사냥꾼의 활", "시위를 당겨 멀리 있는 적을 정확하게 꿰뚫는 활.", 0, existing=True, element=0, color=(1, 0.95, 0.8), shots=1, pierce=1)
add("bow", "traveler_bow", "여행자의 단궁", "짧고 가벼운 활. 빠르게 쏘고 빠르게 달린다.", 1, element=0, color=(1, 0.95, 0.85), shots=1, pierce=1)
add("bow", "bronze_bow", "청동 장궁", "청동 고리로 묶은 장궁. 화살이 두 마리를 꿰뚫는다.", 2, element=0, color=(1, 0.85, 0.6), shots=1, pierce=2)
add("bow", "rapid_crossbow", "연사 석궁", "장전이 빠른 석궁. 짧게 당겨 볼트를 연달아 쏜다.", 3, existing=True, element=0, color=(0.7, 0.85, 1), shots=1, pierce=0, crossbow=True, fast=True)
add("bow", "knight_crossbow", "기사단 석궁", "기사단 궁병의 무거운 석궁. 볼트가 갑옷을 뚫고 지나간다.", 4, element=0, color=(0.85, 0.9, 1), shots=1, pierce=2, crossbow=True)
add("bow", "mithril_bow", "미스릴 활", "미스릴 실로 시위를 건 활. 화살 두 발이 나란히 날아간다.", 5, element=2, color=(0.7, 0.95, 1), shots=2, pierce=2)
add("bow", "windrunner_bow", "질풍의 활", "바람의 정령이 깃든 활. 화살 세 발이 바람을 타고 적을 꿰뚫는다.", 6, existing=True, element=5, color=(0.55, 1, 0.6), shots=3, pierce=2)
add("bow", "dragonscale_bow", "용골 활", "용의 뼈로 만든 활. 불붙은 화살이 맞은 자리에서 작게 터진다.", 7, element=1, color=(1, 0.65, 0.3), shots=1, pierce=3, burst=18)
add("bow", "rune_bow", "룬 장궁", "룬이 새겨진 장궁. 마력 화살 세 발이 부채꼴로 퍼진다.", 8, element=7, color=(0.55, 0.85, 1), shots=3, pierce=3)
add("bow", "solaris_bow", "태양궁 솔라리스", "태양의 불꽃을 담은 전설의 활. 불타는 화살이 적을 줄줄이 꿰뚫고 갑옷마저 녹인다.", 9, existing=True, element=1, color=(1, 0.7, 0.25), shots=1, pierce=5)
add("bow", "seraph_bow", "세라핌의 활", "빛으로 된 시위를 당기는 활. 화살 두 발이 빛줄기가 되어 꿰뚫는다.", 10, element=6, color=(1, 0.95, 0.7), shots=2, pierce=5)
add("bow", "genesis_bow", "창세의 활", "별의 궤적을 쏘는 활. 화살 세 발이 별빛으로 터진다.", 11, element=7, color=(1, 0.75, 1), shots=3, pierce=4, burst=20)
add("bow", "apollo_bow", "아폴론의 활", "태양신 아폴론이 넘겨준 활. 태양의 화살 세 발이 모든 것을 꿰뚫고 햇빛으로 터진다.", MYTHIC, element=1, color=(1, 0.8, 0.3), shots=3, pierce=10, burst=26,
    icon=lambda: mythic_frame(bow_painter((255, 210, 80), (255, 250, 220), accent=(255, 90, 60))), held=((255, 210, 80), (255, 90, 60)))

# ---- 지팡이 (spell: 0 마력 폭발 / 1 서리 / 2 점액 / 3 업화 / 4 거대 슬라임 / 5 별똥별)
add("staff", "apprentice_staff", "견습 지팡이", "마력 구슬 3발을 부채꼴로 발사한다. 구슬은 조준한 곳에서 보랏빛으로 터진다.", 0, existing=True, spell=0)
add("staff", "traveler_staff", "참나무 지팡이", "단단한 참나무 지팡이. 마력 구슬 3발을 쏘아 넓게 터뜨린다.", 1, spell=0, element=7, color=(0.75, 1, 0.7), shots=3, spread=22, radius=30, projectile="orb", chant="숲의 마력이여…")
add("staff", "bronze_staff", "청동 지팡이", "청동 고리가 달린 지팡이. 무거운 마력 구슬 하나가 크게 터진다.", 2, spell=0, element=7, color=(1, 0.8, 0.55), shots=1, spread=0, radius=40, projectile="arcane_orb", chant="모여라, 터져라!")
add("staff", "slime_staff", "슬라임 지팡이", "끈적한 점액탄 5발을 흩뿌린다. 터진 자리에 웅덩이가 남아 적을 느리게 한다.", 2, existing=True, spell=2, in_shop=False)
add("staff", "frost_staff", "서리 지팡이", "얼음 창을 날려 터진 자리의 적을 모두 얼려 느리게 만든다.", 3, existing=True, spell=1)
add("staff", "knight_staff", "기사단 전투 지팡이", "기사단 마법사의 지팡이. 번개 구슬 3발이 터지며 적을 밀어낸다.", 4, spell=0, element=3, color=(0.9, 0.9, 0.5), shots=3, spread=20, radius=34, projectile="spark_orb", chant="벼락이여, 진군하라!")
add("staff", "mithril_staff", "미스릴 지팡이", "미스릴 수정이 박힌 지팡이. 서리 폭발이 넓게 퍼져 적을 얼린다.", 5, spell=1, element=2, color=(0.65, 0.95, 1), shots=3, spread=16, radius=38, projectile="ice_shard", chant="얼어붙어라, 미스릴의 서리여!", slow=1.8)
add("staff", "ignis_staff", "업화의 지팡이 이그니스", "거대한 화염구를 쏘아 조준한 곳을 불기둥과 함께 폭발시키고, 땅을 불태운다.", 6, existing=True, spell=3)
add("staff", "dragonscale_staff", "용의 숨결 지팡이", "용의 숨결을 가둔 지팡이. 화염구가 크게 터지고 땅이 오래 불탄다.", 7, spell=3, element=1, color=(1, 0.6, 0.25), shots=1, spread=0, radius=58, projectile="fireball", chant="용이여, 숨을 내쉬어라!", zone=3.0, zone_ratio=0.22)
add("staff", "rune_staff", "룬 지팡이", "룬 문자가 떠다니는 지팡이. 조준한 곳에 마력의 별 여섯 개가 떨어진다.", 8, spell=5, element=7, color=(0.55, 0.85, 1), strikes=6, scatter=46, radius=30, projectile="orb", chant="룬이여, 하늘을 열어라!")
add("staff", "arcana_staff", "별의 지팡이 아르카나", "별의 힘을 끌어내는 전설의 지팡이. 조준한 곳 주변에 별똥별이 무작위로 쏟아진다.", 9, existing=True, spell=5)
add("staff", "king_scepter", "슬라임 왕의 홀", "슬라임 킹의 힘이 담긴 홀. 조준한 곳에 거대한 슬라임 왕을 떨어뜨려 짓누르고, 점액 웅덩이를 남긴다.", 9, existing=True, spell=4, in_shop=False)
add("staff", "seraph_staff", "세라핌의 홀", "천사의 빛을 부르는 홀. 신성한 빛 구슬 5발이 부채꼴로 터진다.", 10, spell=0, element=6, color=(1, 0.95, 0.7), shots=5, spread=34, radius=36, projectile="holy_orb", chant="빛이여, 심판하라!")
add("staff", "genesis_staff", "창세의 지팡이", "세상을 만든 별의 조각. 조준한 곳에 별 열한 개가 쏟아진다.", 11, spell=5, element=7, color=(1, 0.7, 1), strikes=11, scatter=60, radius=32, projectile="star", chant="태초의 별이여, 다시 빛나라!")
add("staff", "archmage_staff", "대마법사의 지팡이", "탑의 대마법사가 넘겨준 지팡이. 하늘을 찢고 별 열여섯 개를 쏟아붓는다.", MYTHIC, spell=5, element=7, color=(0.85, 0.55, 1), strikes=16, scatter=72, radius=36, projectile="star", chant="별의 근원이여, 나의 부름에 응하라!",
    icon=lambda: mythic_frame(staff_painter((200, 130, 255), (60, 40, 120), shape="crystal", prong=(255, 210, 90))))

# ---- 방패
add("shield", "wooden_shield", "나무 방패", "", 0, existing=True)
add("shield", "traveler_shield", "둥근 방패", "가죽을 덧댄 둥근 방패. 가볍게 들고 다닌다.", 1)
add("shield", "bronze_shield", "청동 방패", "청동판을 두른 둥근 방패. 두드리면 맑은 소리가 난다.", 2)
add("shield", "goblin_buckler", "고블린 버클러", "", 2, existing=True, in_shop=False)
add("shield", "iron_shield", "강철 방패", "", 3, existing=True)
add("shield", "knight_shield", "기사단 방패", "기사단의 문장이 새겨진 연(鳶)꼴 방패.", 4)
add("shield", "mithril_shield", "미스릴 방패", "가볍고 단단한 미스릴 방패. 가드를 올린 채로도 빠르게 움직인다.", 5)
add("shield", "royal_aegis", "왕실의 아이기스", "", 6, existing=True)
add("shield", "dragonscale_shield", "용비늘 방패", "용의 비늘을 겹겹이 이은 큰 방패.", 7)
add("shield", "rune_shield", "룬 방패", "룬이 새겨진 탑 방패. 막을 때마다 룬이 빛난다.", 8)
add("shield", "colossus_bulwark", "거신의 성벽", "", 9, existing=True)
add("shield", "seraph_shield", "세라핌의 방패", "태양 문장이 새겨진 천상의 방패.", 10)
add("shield", "genesis_shield", "창세의 방패", "별의 문장이 빛나는 거대한 방패.", 11)
add("shield", "mars_shield", "마르스의 방패", "군신 마르스가 넘겨준 신성한 방패 안킬레. 어느 방향의 공격이든 막아낸다.", MYTHIC,
    icon=lambda: mythic_frame(shield_painter((200, 40, 50), (255, 200, 90), (255, 230, 150), shape="round", emblem_kind="sun")))

# ---- 투구
add("helmet", "leather_cap", "가죽 모자", "", 0, existing=True)
add("helmet", "traveler_helmet", "여행자의 두건", "먼지를 막아 주는 두건. 가벼운 가죽을 덧댔다.", 1)
add("helmet", "bronze_helmet", "청동 투구", "청동으로 만든 둥근 투구.", 2)
add("helmet", "iron_helm", "강철 투구", "", 3, existing=True)
add("helmet", "knight_helmet", "기사단 투구", "얼굴을 가리는 면갑이 달린 기사단 투구.", 4)
add("helmet", "mithril_helmet", "미스릴 투구", "가볍게 빛나는 미스릴 투구.", 5)
add("helmet", "orc_warhelm", "오크 전쟁 투구", "", 6, existing=True)
add("helmet", "dragonscale_helmet", "용뿔 투구", "용의 뿔을 그대로 붙인 투구.", 7)
add("helmet", "rune_helmet", "룬 투구", "면갑의 틈으로 룬 빛이 새어 나오는 투구.", 8)
add("helmet", "gatekeeper_horns", "수문장의 뿔", "", 9, existing=True)
add("helmet", "seraph_helmet", "세라핌의 투구", "양옆에 작은 날개가 달린 천상의 투구.", 10)
add("helmet", "genesis_helmet", "창세의 왕관", "별의 보석이 박힌 왕관 투구.", 11)
add("helmet", "athena_helmet", "아테나의 투구", "지혜의 여신 아테나가 넘겨준 투구. 높은 깃장식 아래 모든 공격의 길이 보인다.", MYTHIC, helm=((230, 200, 110), (255, 245, 200), (150, 110, 50), (255, 70, 70), "winged"))

# ---- 갑옷
add("armor", "leather_armor", "가죽 갑옷", "", 0, existing=True)
add("armor", "traveler_armor", "여행자의 외투", "두꺼운 천에 가죽을 덧댄 외투.", 1)
add("armor", "bronze_armor", "청동 갑옷", "청동 판을 이어 붙인 갑옷.", 2)
add("armor", "chain_mail", "사슬 갑옷", "", 3, existing=True)
add("armor", "knight_armor", "기사단 판금", "기사단의 십자가 새겨진 판금 갑옷.", 4)
add("armor", "mithril_armor", "미스릴 사슬 갑옷", "미스릴 고리로 엮은 가벼운 갑옷.", 5)
add("armor", "hellsteel_plate", "지옥강 판금", "", 6, existing=True)
add("armor", "dragonscale_armor", "용비늘 갑옷", "용의 비늘을 겹겹이 단 갑옷.", 7)
add("armor", "rune_armor", "룬 판금", "룬이 빛나는 검푸른 판금.", 8)
add("armor", "paladin_plate", "성기사의 판금", "", 9, existing=True)
add("armor", "seraph_armor", "세라핌의 갑옷", "금빛 십자가 빛나는 천상의 갑옷.", 10)
add("armor", "genesis_armor", "창세의 갑옷", "별빛 룬이 흐르는 보랏빛 갑옷.", 11)
add("armor", "hephaestus_armor", "헤파이스토스의 갑옷", "대장장이 신 헤파이스토스가 프로메테우스의 불꽃으로 벼려 준 갑옷.", MYTHIC, armor=((150, 60, 40), (255, 190, 80), (80, 30, 25), "trim"))

# ---- 신발
add("boots", "leather_boots", "가죽 장화", "", 0, existing=True)
add("boots", "traveler_boots", "여행자의 장화", "오래 걸어도 발이 편한 장화.", 1)
add("boots", "bronze_boots", "청동 각반", "청동판을 댄 각반.", 2)
add("boots", "iron_greaves", "강철 각반", "", 3, existing=True)
add("boots", "knight_boots", "기사단 각반", "기사단의 무거운 각반.", 4)
add("boots", "mithril_boots", "미스릴 장화", "깃털처럼 가벼운 미스릴 장화.", 5)
add("boots", "shadow_boots", "그림자 장화", "", 6, existing=True)
add("boots", "dragonscale_boots", "용비늘 장화", "용의 비늘을 덧댄 장화.", 7)
add("boots", "rune_boots", "룬 각반", "룬이 빛나는 각반. 발걸음이 가볍다.", 8)
add("boots", "windwalker_boots", "바람걸음 장화", "", 9, existing=True)
add("boots", "seraph_boots", "세라핌의 장화", "발목에 작은 날개가 달린 장화.", 10)
add("boots", "genesis_boots", "창세의 장화", "별 위를 걷는다는 장화.", 11)
add("boots", "hermes_boots", "헤르메스의 신발", "전령의 신 헤르메스가 넘겨준 날개 달린 신발. 대시가 훨씬 자주 된다.", MYTHIC, boots=((240, 230, 200), (255, 255, 255), (190, 150, 60), True), dash=0.4)

# ---- 장신구
for kind, ids in (
    ("bracelet", ["leather_bracelet", "traveler_bracelet", "bronze_bracelet", "silver_bracelet", "knight_bracelet", "mithril_bracelet",
                  "obsidian_bracelet", "dragonscale_cuff", "rune_bracelet", "dragonscale_bracelet", "seraph_bracelet", "genesis_bracelet"]),
    ("ring", ["copper_ring", "traveler_ring", "bronze_ring", "ruby_ring", "knight_ring", "mithril_ring",
              "blood_ruby_ring", "dragonscale_ring", "rune_ring", "star_ring", "seraph_ring", "genesis_ring"]),
    ("pendant", ["wooden_pendant", "traveler_pendant", "bronze_pendant", "sapphire_pendant", "knight_pendant", "mithril_pendant",
                 "guardian_pendant", "dragonscale_pendant", "rune_pendant", "life_pendant", "seraph_pendant", "genesis_pendant"]),
):
    names = {
        "bracelet": ["", "여행자의 팔찌", "청동 팔찌", "", "기사단 팔찌", "미스릴 팔찌", "", "용비늘 팔찌", "룬 팔찌", "", "세라핌의 팔찌", "창세의 팔찌"],
        "ring": ["", "여행자의 반지", "청동 인장 반지", "", "기사단 인장 반지", "미스릴 반지", "", "용의 눈 반지", "룬 반지", "", "세라핌의 반지", "창세의 반지"],
        "pendant": ["", "여행자의 부적", "청동 펜던트", "", "기사단 휘장", "미스릴 펜던트", "", "용의 심장 펜던트", "룬 펜던트", "", "세라핌의 펜던트", "창세의 펜던트"],
    }[kind]
    descs = {
        "bracelet": ["", "가죽끈에 작은 구슬을 꿴 팔찌. 급소를 노리는 감각이 날카로워진다.", "청동 고리 팔찌. 묵직한 일격에 힘이 실린다.", "",
                     "기사단의 문장을 새긴 팔찌.", "미스릴 실로 엮은 팔찌. 갑옷의 틈을 찾아낸다.", "", "용의 비늘 한 장을 박은 팔찌.",
                     "룬이 돌아가며 빛나는 팔찌.", "", "날개 무늬가 새겨진 천상의 팔찌.", "별 조각을 박은 팔찌. 모든 일격이 별처럼 터진다."],
        "ring": ["", "여행의 무사를 비는 소박한 반지.", "청동 인장이 찍힌 반지.", "", "기사단의 인장 반지. 맹세가 손끝에 힘을 준다.",
                 "미스릴로 만든 가벼운 반지.", "", "용의 눈처럼 빛나는 호박색 보석 반지.", "룬이 새겨진 반지.", "",
                 "천사의 깃털 무늬 반지.", "태초의 별빛을 가둔 반지."],
        "pendant": ["", "길 떠나는 이에게 주는 부적.", "청동 펜던트. 몸을 단단하게 해 준다.", "", "기사단의 휘장. 지친 몸을 일으켜 세운다.",
                    "미스릴 펜던트. 상처가 빨리 아문다.", "", "아직 따뜻한 용의 심장 조각.", "룬이 생명의 힘을 끌어올리는 펜던트.", "",
                    "천상의 빛이 상처를 감싸는 펜던트.", "창세의 생명력이 흐르는 펜던트."],
    }[kind]
    for t, item_id in enumerate(ids):
        existing = names[t] == ""
        add(kind, item_id, names[t], descs[t], t, existing=existing)
add("bracelet", "spirit_bracelet", "대정령의 팔찌", "정령의 성역을 지키던 대정령이 넘겨준 팔찌. 모든 일격이 치명적이다.", MYTHIC, acc=((140, 230, 160), (60, 130, 90), (255, 255, 160)))
add("ring", "gabriel_ring", "대천사 가브리엘의 반지", "대천사 가브리엘이 권능과 함께 넘겨준 반지.", MYTHIC, acc=((255, 230, 140), (200, 150, 60), (180, 230, 255)))
add("pendant", "king_pendant", "왕의 펜던트", "잃어버린 왕이 넘겨준 펜던트. 왕국을 지키던 생명의 힘이 깃들어 있다.", MYTHIC, acc=((255, 210, 90), (150, 100, 30), (220, 40, 60)))

MYTHIC_STAGE = {"king_pendant": 10, "archmage_staff": 20, "spirit_bracelet": 30, "hermes_boots": 40, "hephaestus_armor": 50,
                "mars_shield": 60, "apollo_bow": 70, "athena_helmet": 80, "abaddon_sword": 90, "gabriel_ring": 100}

CAT_DIR = {"sword": "weapons", "dagger": "weapons", "bow": "weapons", "staff": "weapons", "shield": "shields", "helmet": "helmets",
           "armor": "armors", "boots": "boots", "bracelet": "accessories", "ring": "accessories", "pendant": "accessories"}
CAT_SCRIPT = {"sword": "weapon", "dagger": "weapon", "bow": "weapon", "staff": "weapon", "shield": "shield", "helmet": "helmet",
              "armor": "armor", "boots": "boots", "bracelet": "accessory", "ring": "accessory", "pendant": "accessory"}
CAT_CLASS = {"weapon": "WeaponData", "shield": "ShieldData", "helmet": "HelmetData", "armor": "ArmorData", "boots": "BootsData", "accessory": "AccessoryData"}


# ============================================================ 기존 .tres 읽기
def read_tres(path):
    if not os.path.exists(path):
        return {}, {}
    text = open(path, encoding="utf-8").read()
    ext = {i: p for p, i in re.findall(r'\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="([^"]+)"\]', text)}
    props = {}
    body = text.split("[resource]", 1)[1] if "[resource]" in text else ""
    key = None
    for line in body.strip().split("\n"):
        if key is not None:  # 여러 줄에 걸친 문자열
            props[key] += "\n" + line
            if _quotes_closed(props[key]):
                key = None
            continue
        if " = " in line:
            k, v = line.split(" = ", 1)
            props[k.strip()] = v.strip()
            if v.strip().startswith('"') and not _quotes_closed(v.strip()):
                key = k.strip()
    return props, ext


def _quotes_closed(value):
    count = 0
    i = 0
    while i < len(value):
        if value[i] == "\\":
            i += 2
            continue
        if value[i] == '"':
            count += 1
        i += 1
    return count % 2 == 0


def res_path(item):
    return os.path.join(REPO, "data", {"weapon": "weapons", "shield": "shields", "helmet": "helmets", "armor": "armors",
                                       "boots": "boots", "accessory": "accessories"}[CAT_SCRIPT[item["cat"]]], item["id"] + ".tres")


def gd_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def color_str(col):
    return "Color(%s, %s, %s, 1)" % tuple(("%g" % v) for v in col)


# ============================================================ 수치 계산
def weapon_props(item, old):
    t = item["t"]
    tt = rep_t(t)
    cat = item["cat"]
    p = {}
    sword_dps = sword_raw_dps(t if t == MYTHIC else tt)
    if cat in ("sword", "dagger"):
        if cat == "sword":
            dmg = sword_damage(t)
            p.update(weapon_type=0, damage=dmg, crit_chance=SW_CRIT[t], crit_multiplier=SW_MULT[t], attack_cooldown=SW_CD[t],
                     melee_range=SW_RANGE[t], melee_arc_degrees=SW_ARC[t], armor_pen=0)
        else:
            cd, crit, mult = 0.16, 0.3, 2.2
            dmg = nice(sword_dps * 0.95 * cd / (1 + crit * (mult - 1)))
            p.update(weapon_type=3, damage=dmg, crit_chance=crit, crit_multiplier=mult, attack_cooldown=cd, melee_range=30, melee_arc_degrees=90,
                     armor_pen=round(0.25 * at(tt, "boss_def")))
        p["knockback"] = 150 + 10 * min(t, 11) + (60 if t == MYTHIC else 0)
    elif cat == "bow":
        fast = item.get("fast", False)
        cd = (0.06 if fast else 0.12 - 0.003 * min(t, 11)) if t != MYTHIC else 0.08
        windup = (0.08 if fast else 0.18 - 0.003 * min(t, 11)) if t != MYTHIC else 0.12
        crit = [.15, .15, .16, .16, .17, .18, .18, .19, .2, .2, .21, .22, .28][t]
        mult = [1.8, 1.8, 1.8, 1.8, 1.85, 1.9, 1.9, 1.95, 2.0, 2.0, 2.05, 2.1, 2.4][t]
        shots = item.get("shots", 1)
        target = sword_dps * (0.85 if t != MYTHIC else 0.9)
        dmg = nice(target * (cd + windup) / (shots * (1 + crit * (mult - 1))))
        p.update(weapon_type=1, damage=dmg, crit_chance=crit, crit_multiplier=mult, attack_cooldown=round(cd, 3), windup_time=round(windup, 3),
                 armor_pen=round((0.45 if t != MYTHIC else 0.6) * at(tt, "boss_def")), projectiles_per_shot=shots,
                 spread_degrees=0.0 if shots == 1 else (4.0 if shots == 2 else 12.0), pierce=item.get("pierce", 1),
                 projectile_speed=450 + 12 * min(t, 11) + (80 if t == MYTHIC else 0), projectile_range=280 + 6 * min(t, 11) + (60 if t == MYTHIC else 0),
                 projectile_scale=1.0 + 0.04 * min(t, 11) + (0.3 if t == MYTHIC else 0), knockback=90 + 6 * min(t, 11),
                 explosion_radius=float(item.get("burst", 0)), explosion_damage_ratio=0.5)
    else:  # staff
        spell = item.get("spell", int(old.get("spell", 0)))
        crit = [.05, .06, .07, .08, .09, .1, .1, .11, .12, .15, .16, .17, .22][t]
        mult = [1.5, 1.5, 1.55, 1.6, 1.62, 1.65, 1.7, 1.75, 1.8, 2.0, 2.0, 2.0, 2.3][t]
        cd = float(old.get("attack_cooldown", 0.25)) if item.get("existing") else (0.22 if spell != 5 else 0.4)
        windup = float(old.get("windup_time", 0.5)) if item.get("existing") else ([0.4, 0.45, 0.5, 0.5, 0.55, 0.6][spell] if t != MYTHIC else 0.6)
        if item.get("existing"):
            hits = int(old.get("strike_count", 1)) if spell in (4, 5) else int(old.get("projectiles_per_shot", 1))
        else:
            hits = item.get("strikes", 1) if spell in (4, 5) else item.get("shots", 1)
        target = sword_dps * (0.72 if t != MYTHIC else 0.8)
        dmg = nice(target * (cd + windup) / (max(hits, 1) * (1 + crit * (mult - 1))))
        p.update(weapon_type=2, damage=dmg, crit_chance=crit, crit_multiplier=mult, attack_cooldown=cd, windup_time=windup, spell=spell,
                 armor_pen=round(0.15 * at(tt, "boss_def")))
        if not item.get("existing"):
            p.update(projectiles_per_shot=1 if spell in (4, 5) else item.get("shots", 1), spread_degrees=float(item.get("spread", 0)),
                     explosion_radius=float(item.get("radius", 30)), explosion_damage_ratio=0.8, projectile_speed=260.0,
                     projectile_range=220.0 + 3 * min(t, 11) + (40 if t == MYTHIC else 0), projectile_scale=1.2 + 0.03 * min(t, 11),
                     knockback=80 + 6 * min(t, 11), chant_text=gd_string(item.get("chant", "")), slow_duration=float(item.get("slow", 0)),
                     zone_duration=float(item.get("zone", 0)), zone_tick_ratio=float(item.get("zone_ratio", 0)), pierce=0)
            if spell == 5:
                p.update(strike_count=item.get("strikes", 6), strike_scatter=float(item.get("scatter", 50)), strike_interval=0.08, strike_fall_time=0.4)
    if not item.get("existing") and cat != "staff":
        p["element"] = item.get("element", 0)
    if not item.get("existing"):
        p["element"] = item.get("element", 0)
        p["effect_color"] = color_str(item.get("color", (1, 1, 1)))
    return p


def defense_props(item):
    t = item["t"]
    cat = item["cat"]
    dt = total_defense(t)
    hb = hp_bonus(t)
    if cat == "shield":
        block = BLOCK[t]
        guard = 3.0 * (at(rep_t(t), "boss_cd") * (1.4 if t == MYTHIC else 1.0)) * block
        props = dict(defense=nice(0.2 * dt), block_ratio=block, block_arc_degrees=float(BLOCK_ARC[t]), max_guard=float(nice(guard)),
                     guard_regen=float(nice(guard * 0.35)), perfect_guard_window=PERFECT[t], guard_move_multiplier=GUARD_MOVE[t],
                     guard_break_time=GUARD_BREAK[t])
        if item["id"] == "goblin_buckler":  # 작고 빠른 방패: 막는 양은 적지만 게이지가 빨리 참
            props.update(block_ratio=0.75, block_arc_degrees=90.0, max_guard=float(nice(guard * 0.7)), guard_regen=float(nice(guard * 0.6)), guard_move_multiplier=0.85, perfect_guard_window=0.45, guard_break_time=0.8)
        return props
    if cat == "helmet":
        return dict(defense=nice(0.25 * dt), bonus_max_hp=nice(0.30 * hb))
    if cat == "armor":
        return dict(defense=nice(0.35 * dt), bonus_max_hp=nice(0.45 * hb))
    if cat == "boots":
        props = dict(defense=nice(0.2 * dt), move_bonus=BOOT_MOVE[t])
        if item.get("dash"):
            props["dash_cooldown_reduction"] = item["dash"]
        return props
    if cat == "bracelet":
        return dict(slot_type=0, crit_damage_bonus=BR_CD[t], armor_pen=bracelet_pen(t))
    if cat == "ring":
        return dict(slot_type=1, crit_chance_bonus=RING_CRIT[t], attack_bonus=RING_ATK[t])
    if cat == "pendant":
        total_hp = 1000 + hb
        return dict(slot_type=2, bonus_max_hp=nice(0.25 * hb), hp_regen=round(max(0.005 * total_hp, 3.0), 1) * (1.5 if t == MYTHIC else 1.0))
    return {}


# 값 = 그 단계가 풀리는 스테이지부터 5스테이지 동안 버는 골드 × 비중 × (하급 1 · 중급 1.25 · 상급 1.5)
# 몬스터 드랍 · 보물상자로도 장비가 들어오므로, 상점은 원하는 장비를 골라 사는 곳 — 무기 하나가 5스테이지 수입의 약 20%
WEIGHT = {"sword": .21, "dagger": .18, "bow": .21, "staff": .21, "shield": .12, "helmet": .12, "armor": .13, "boots": .12,
          "bracelet": .13, "ring": .14, "pendant": .12}


# ============================================================ 아이콘
def paint(item):
    """새 장비의 아이콘(+ 착용 그림 · 활을 든 그림)을 그려서 저장. 텍스처 경로 dict 를 돌려줌"""
    t = item["t"]
    cat = item["cat"]
    d = CAT_DIR[cat]
    out = {}
    if item.get("existing"):
        return out
    fam = FAMILY.get(t)
    style = FAMILY_STYLE.get(t, {})
    icon_path = f"res://assets/sprites/{d}/{item['id']}.png"
    if "icon" in item:
        img = item["icon"]()
    elif cat == "sword":
        img = sword_painter(fam[1], fam[0], fam[2] if t not in (2, 7) else fam[1], (90, 58, 40), gem=fam[3] if t >= 4 else None, broad=t in (2, 7, 8, 11), glow=fam[3] if t in (8, 10, 11) else None)
    elif cat == "bow":
        img = bow_painter(fam[0] if t not in (10,) else fam[1], fam[1] if t != 10 else (255, 255, 255), accent=fam[3] if t >= 4 else None, crossbow=t == 4)
    elif cat == "staff":
        img = staff_painter(fam[3], fam[2] if t != 10 else fam[1], shape=style.get("staff", "square"), prong=fam[1] if t >= 7 else None)
    elif cat == "shield":
        img = shield_painter(fam[0], fam[2] if t != 10 else fam[1], fam[3] if t >= 4 else fam[1], shape=style["shield"], emblem_kind=style["emblem"])
    elif cat == "helmet":
        main, light, dark, gem, shape = item["helm"] if "helm" in item else fam + (style.get("helm"),)
        worn = helm_worn_painter(main, light, dark, gem, shape)
        if item.get("helm"):
            worn_icon = gs.canvas(16)
            worn_icon.paste(worn, (0, 5), worn)
            img = mythic_frame(worn_icon)
        else:
            img = gs.helmet_icon(worn)
        gs.save(worn, d, f"{item['id']}_worn.png")
        out["worn"] = f"res://assets/sprites/{d}/{item['id']}_worn.png"
    elif cat == "armor":
        main, light, dark, deco = item["armor"] if "armor" in item else (fam[0], fam[1], fam[2], style.get("deco"))
        gs.save(armor_worn_painter(main, light, dark, deco), d, f"{item['id']}_worn.png")
        out["worn"] = f"res://assets/sprites/{d}/{item['id']}_worn.png"
        img = armor_icon_painter(main, light, dark, deco)
        if item.get("armor"):
            img = mythic_frame(img)
    elif cat == "boots":
        main, light, dark, wings = item["boots"] if "boots" in item else (fam[0], fam[1], fam[2], style.get("wings", False))
        gs.save(boots_worn_painter(main, light, dark, wings), d, f"{item['id']}_worn.png")
        out["worn"] = f"res://assets/sprites/{d}/{item['id']}_worn.png"
        img = boots_icon_painter(main, light, dark, wings)
        if item.get("boots"):
            img = mythic_frame(img)
    else:
        metal, dark, gem = item["acc"] if "acc" in item else (fam[1] if t in (2, 5, 10, 11) else fam[0], fam[2], fam[3])
        img = accessory_painter(cat, metal, dark, gem)
        if item.get("acc"):
            img = mythic_frame(img)
    gs.save(img, d, f"{item['id']}.png")
    out["icon"] = icon_path
    if cat == "bow":
        wood, accent = item["held"] if "held" in item else ((fam[0] if t != 10 else fam[1]), fam[3])
        gs.save(bow_held_painter(wood, accent, crossbow=t == 4), d, f"{item['id']}_held.png")
        out["held"] = f"res://assets/sprites/{d}/{item['id']}_held.png"
    return out


PROJECTILE = {"bow": "res://assets/sprites/projectiles/arrow.png"}


# ============================================================ .tres 쓰기
def write_item(item):
    path = res_path(item)
    old, old_ext = read_tres(path)
    script_kind = CAT_SCRIPT[item["cat"]]
    textures = paint(item)
    ext = []  # (type, path, id)
    ext.append(("Script", f"res://scripts/data/{script_kind}_data.gd", "1_script"))

    def ext_id_for(path_value):
        for tp, pv, i in ext:
            if pv == path_value:
                return i
        i = f"{len(ext) + 1}_res"
        ext.append(("Texture2D", path_value, i))
        return i

    props = {}
    # 기존 장비: 고정 필드(텍스처 · 주문 · 투사체 등)는 그대로 두고 수치만 갈아 끼움
    if item.get("existing"):
        for k, v in old.items():
            if k == "script":
                continue
            m = re.match(r'ExtResource\("([^"]+)"\)', v)
            if m:
                props[k] = ("ext", old_ext[m.group(1)])
            else:
                props[k] = v
    else:
        props["icon"] = ("ext", textures["icon"])
        if "worn" in textures:
            props["worn_texture"] = ("ext", textures["worn"])
        if "held" in textures:
            props["held_texture"] = ("ext", textures["held"])
        if item["cat"] == "bow":
            props["projectile_texture"] = ("ext", PROJECTILE["bow"])
        elif item["cat"] == "staff":
            props["projectile_texture"] = ("ext", "res://assets/sprites/projectiles/%s.png" % item.get("projectile", "orb"))
    if script_kind == "weapon":
        new = weapon_props(item, old)
    else:
        new = defense_props(item)
    for k, v in new.items():
        props[k] = v if isinstance(v, str) else ("%g" % v if isinstance(v, float) else str(v))
    t = item["t"]
    rarity = 4 if t == MYTHIC else t // 3
    tier = 0 if t == MYTHIC else t % 3
    props["id"] = '&"%s"' % item["id"]
    if item["name"]:
        props["display_name"] = gd_string(item["name"])
    if item["desc"]:
        props["description"] = gd_string(item["desc"])
    props["rarity"] = str(rarity)
    props["tier"] = str(tier)
    set_id = "mythic" if t == MYTHIC else SETS.get(t, "")
    if item.get("in_shop", True) is False:
        set_id = ""
    if set_id:
        props["set_id"] = '&"%s"' % set_id
    else:
        props.pop("set_id", None)
    if item.get("in_shop", True) is False or t == MYTHIC:
        props["in_shop"] = "false"
    else:
        props.pop("in_shop", None)
    pr = price(t, WEIGHT[item["cat"]])
    if pr is not None:
        props["price"] = str(pr)
    elif "price" not in props:
        props["price"] = "50"
    # 쓰기
    body = []
    for k, v in props.items():
        if isinstance(v, tuple) and v[0] == "ext":
            body.append(f'{k} = ExtResource("{ext_id_for(v[1])}")')
        elif k != "script":
            body.append(f"{k} = {v}")
    lines = [f'[gd_resource type="Resource" script_class="{CAT_CLASS[script_kind]}" load_steps={len(ext) + 1} format=3]', ""]
    for tp, pv, i in ext:
        lines.append(f'[ext_resource type="{tp}" path="{pv}" id="{i}"]')
    lines += ["", "[resource]", 'script = ExtResource("1_script")'] + body
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return path


def write_item_db(paths):
    db = os.path.join(REPO, "scripts", "data", "item_db.gd")
    text = open(db, encoding="utf-8").read()
    start = text.index("const ITEM_PATHS: Array[String] = [")
    end = text.index("]\n", start) + 2
    groups = [("검 / 단검 (근접)", ("sword", "dagger")), ("활", ("bow",)), ("마법 지팡이", ("staff",)), ("방패", ("shield",)), ("투구", ("helmet",)),
              ("갑옷", ("armor",)), ("신발", ("boots",)), ("장신구 (팔찌 / 반지 / 펜던트)", ("bracelet", "ring", "pendant"))]
    lines = ["const ITEM_PATHS: Array[String] = ["]
    for title, cats in groups:
        lines.append(f"\t# {title}")
        for item in ITEMS:
            if item["cat"] in cats:
                lines.append('\t"res://%s",' % os.path.relpath(paths[item["id"]], REPO).replace(os.sep, "/"))
    lines.append("\t# 회복 포션 (소모품) — 고대 용의 피는 히든 보스 보상")
    for p in ("small_potion", "potion", "greater_potion", "elixir", "dragon_blood"):
        lines.append(f'\t"res://data/potions/{p}.tres",')
    lines.append("\t# 신화 사용 아이템 (원초의 불꽃 · 최후의 나팔)")
    for r in ("primal_flame", "last_trumpet"):
        lines.append(f'\t"res://data/relics/{r}.tres",')
    lines.append("]\n")
    text = text[:start] + "\n".join(lines) + text[end:]
    open(db, "w", encoding="utf-8").write(text)


def balance_sheet():
    rows = []
    for t in range(13):
        rt = rep_t(t)
        r = REP[rt]
        sw = sword_damage(t)
        m = accessory_mult(t)
        pen = bracelet_pen(t)
        d, h, cdmg = at(rt, "boss_def"), at(rt, "boss_hp"), at(rt, "boss_cd")
        hit = sw * m - max(d - pen, 0)
        dps = hit / SW_CD[t]
        hp_total = 1000 + hp_bonus(t)
        taken = max(cdmg - total_defense(t), 1)
        rows.append(dict(t=t, grade=("신화" if t == MYTHIC else "%s %s" % (RARITY_NAMES[t // 3], TIER_NAMES[t % 3])), stage=("최종장" if t == MYTHIC else r),
                         sword=sw, boss_hp=int(h), boss_def=int(d), boss_hit=int(cdmg), ttk=round(h / dps), hp=int(hp_total),
                         defense=int(total_defense(t)), hits=round(hp_total / taken, 1)))
    return rows


def flame_icon():
    img = gs.canvas(16)
    gs.rect(img, 4, 11, 11, 13, (90, 60, 50, 255))          # 화로
    gs.rect(img, 3, 10, 12, 10, (150, 110, 70, 255))
    gs.rect(img, 6, 14, 9, 15, (70, 45, 40, 255))
    gs._poly(img, [(8, 1), (12, 9), (8, 10), (4, 9)], (255, 110, 40, 255))   # 불꽃
    gs._poly(img, [(8, 4), (10, 9), (8, 10), (6, 9)], (255, 210, 90, 255))
    gs.put(img, [(8, 7), (8, 8)], (255, 255, 230, 255))
    gs.put(img, [(5, 4), (11, 5)], (255, 160, 60, 255))
    return mythic_frame(gs.outline(img))


def trumpet_icon():
    img = gs.canvas(16)
    for i in range(9):                                        # 관
        gs.put(img, [(2 + i, 12 - i)], (240, 200, 90, 255))
        gs.put(img, [(3 + i, 12 - i)], (200, 150, 50, 255))
    gs._poly(img, [(10, 1), (15, 1), (15, 6), (12, 6), (10, 4)], (255, 220, 110, 255))  # 나팔 끝
    gs.put(img, [(13, 2), (14, 3)], (255, 255, 230, 255))
    gs.put(img, [(5, 10), (6, 9), (7, 8)], (255, 245, 200, 255))
    gs.rect(img, 1, 13, 2, 14, (200, 150, 50, 255))
    return mythic_frame(gs.outline(img))


def paint_consumables():
    gs.save(gs.potion_icon((255, 196, 70), (255, 240, 170), 1.15), "items", "elixir.png")
    gs.save(mythic_frame(gs.potion_icon((150, 18, 32), (255, 95, 95), 1.2)), "items", "dragon_blood.png")
    gs.save(flame_icon(), "items", "primal_flame.png")
    gs.save(trumpet_icon(), "items", "last_trumpet.png")


def main():
    if "--readme" in sys.argv:
        return
    paint_consumables()
    if "--sheet" in sys.argv:
        print(json.dumps(balance_sheet(), ensure_ascii=False, indent=1))
        return
    paths = {}
    for item in ITEMS:
        paths[item["id"]] = write_item(item)
    write_item_db(paths)
    sets = {}
    for item in ITEMS:
        t = item["t"]
        s = "mythic" if t == MYTHIC else (SETS.get(t, "") if item.get("in_shop", True) else "")
        if s:
            sets.setdefault(s, []).append(item["id"])
    json.dump({"mythic_stage": MYTHIC_STAGE, "sets": sets, "sheet": balance_sheet()},
              open(os.path.join(HERE, "item_catalog.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("items:", len(ITEMS))


if __name__ == "__main__":
    main()


# ============================================================ README 장비표
def _tres_props(item):
    props, _ext = read_tres(res_path(item))
    return props


def _num(props, key, default=0.0):
    try:
        return float(props.get(key, default))
    except ValueError:
        return default


def readme_tables():
    lines = []
    cat_titles = [("sword", "검"), ("bow", "활"), ("staff", "지팡이"), ("shield", "방패"), ("helmet", "투구"), ("armor", "갑옷"),
                  ("boots", "신발"), ("bracelet", "팔찌"), ("ring", "반지"), ("pendant", "펜던트")]
    set_names = {"bronze": "청동", "knight": "기사단", "mithril": "미스릴", "dragonscale": "용비늘", "rune": "룬", "celestial": "천상",
                 "genesis": "창세", "mythic": "신화의 유산"}

    def describe(item):
        p = _tres_props(item)
        cat = item["cat"]
        if cat in ("sword", "dagger"):
            return "ATK %d · %.2f초 · 치명 %d%%" % (_num(p, "damage"), _num(p, "attack_cooldown"), round(_num(p, "crit_chance") * 100))
        if cat == "bow":
            shots = int(_num(p, "projectiles_per_shot", 1))
            return "ATK %d%s · 방깍 %d · 관통 %d" % (_num(p, "damage"), " ×%d" % shots if shots > 1 else "", _num(p, "armor_pen"), _num(p, "pierce"))
        if cat == "staff":
            hits = int(_num(p, "strike_count", 1)) if int(_num(p, "spell")) in (4, 5) else int(_num(p, "projectiles_per_shot", 1))
            return "ATK %d%s · 반경 %d" % (_num(p, "damage"), " ×%d" % hits if hits > 1 else "", _num(p, "explosion_radius"))
        if cat == "shield":
            return "방어 %d · 막기 %d%% · 가드 %d" % (_num(p, "defense"), round(_num(p, "block_ratio") * 100), _num(p, "max_guard"))
        if cat in ("helmet", "armor"):
            return "방어 %d · HP +%d" % (_num(p, "defense"), _num(p, "bonus_max_hp"))
        if cat == "boots":
            extra = " · 대시 -%d%%" % round(_num(p, "dash_cooldown_reduction") * 100) if _num(p, "dash_cooldown_reduction") else ""
            return "방어 %d · 이속 +%d%%%s" % (_num(p, "defense"), round(_num(p, "move_bonus") * 100), extra)
        if cat == "bracelet":
            return "치피 +%d%% · 방깍 %d" % (round(_num(p, "crit_damage_bonus") * 100), _num(p, "armor_pen"))
        if cat == "ring":
            return "치확 +%d%% · 공격 +%d%%" % (round(_num(p, "crit_chance_bonus") * 100), round(_num(p, "attack_bonus") * 100))
        if cat == "pendant":
            return "HP +%d · 재생 %g/s" % (_num(p, "bonus_max_hp"), _num(p, "hp_regen"))
        return ""

    def name_of(item):
        p = _tres_props(item)
        return p.get("display_name", '""').strip('"')

    def price_of(item):
        return int(_num(_tres_props(item), "price"))

    for r in range(4):
        lines.append("#### %s (상점 %d스테이지부터)" % (RARITY_NAMES[r], [1, 11, 41, 71][r]))
        lines.append("")
        lines.append("| 종류 | 하급 | 중급 | 상급 |")
        lines.append("| --- | --- | --- | --- |")
        for cat, title in cat_titles:
            cells = []
            for tier in range(3):
                t = r * 3 + tier
                found = [i for i in ITEMS if i["cat"] == cat and i["t"] == t and i.get("in_shop", True)]
                if not found:
                    cells.append("—")
                    continue
                it = found[0]
                set_id = SETS.get(t, "")
                cells.append("%s%s<br>%s · %sG" % (name_of(it), " (%s)" % set_names[set_id] if set_id else "", describe(it), format(price_of(it), ",")))
            lines.append("| %s | %s |" % (title, " | ".join(cells)))
        lines.append("")
    lines.append("드랍 전용: 고블린 단검 · 고블린 버클러 (고블린) · 슬라임 지팡이 (슬라임) · 슬라임 왕의 홀 (전설 등급 몬스터)")
    lines.append("")
    lines.append("#### 신화 (10스테이지마다 보스가 하나씩 · 100스테이지 클리어 전에는 봉인)")
    lines.append("")
    lines.append("| 스테이지 | 장비 | 능력치 |")
    lines.append("| --- | --- | --- |")
    for item_id, stage in sorted(MYTHIC_STAGE.items(), key=lambda kv: kv[1]):
        it = [i for i in ITEMS if i["id"] == item_id][0]
        lines.append("| %d | %s | %s |" % (stage, name_of(it), describe(it)))
    lines.append("")
    return "\n".join(lines)


def balance_table():
    lines = ["| 단계 | 대표 스테이지 | 그 단계 검 ATK | 보스 체력 · 방어력 · 몸통 공격 | 같은 단계로 맞췄을 때 보스 처치 | 체력 · 방어력 | 보스 몸통 공격 버티는 횟수 |",
             "| --- | --- | --- | --- | --- | --- | --- |"]
    for row in balance_sheet():
        if row["t"] == MYTHIC:
            continue
        lines.append("| %s | %s | %s | %s · %d · %d | 약 %d초 | %s · %d | %.1f번 |" % (
            row["grade"], row["stage"], format(int(row["sword"]), ","), format(row["boss_hp"], ","), row["boss_def"], row["boss_hit"],
            row["ttk"], format(row["hp"], ","), row["defense"], row["hits"]))
    return "\n".join(lines)


def write_readme():
    path = os.path.join(REPO, "README.md")
    text = open(path, encoding="utf-8").read()
    for marker, body in (("장비표", readme_tables()), ("밸런스표", balance_table())):
        start = "<!-- %s 시작 (tools/item_catalog.py --readme 로 다시 만듦) -->" % marker
        end = "<!-- %s 끝 -->" % marker
        if start in text:
            a = text.index(start) + len(start)
            b = text.index(end)
            text = text[:a] + "\n" + body + "\n" + text[b:]
    open(path, "w", encoding="utf-8").write(text)


if __name__ == "__main__" and "--readme" in sys.argv:
    write_readme()
