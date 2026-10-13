# 세피리아(Sefirah) 스타일 탑뷰 액션 – Godot 4 뼈대

2D 도트 그래픽 탑뷰 액션 게임의 **바로 실행 가능한** Godot 4 프로젝트입니다.

- 플레이어: 8방향 가감속 이동, 마우스 조준, 쿨타임 대시(무적 + 잔상)
- 검/단검(근접): 투사체 없이 조준 방향 **부채꼴 범위**를 휘둘러 범위 안의 적을 모두 타격
- 활: 좌클릭을 누르고 있으면 **시위를 당기고**(시위·화살이 뒤로 당겨짐) 다 당기면 발사, 중간에 떼면 취소
- 마법 지팡이: 좌클릭을 누르고 있으면 **영창**(머리 위에 대사) → **지팡이 구슬에 마력이 모이고** → 시전
- 등급이 높을수록 **이펙트가 화려**: 희귀(불티) → 레어(속성 파티클·빛) → 전설(빛의 폭발·충격파·폭발 마법)
- 방패: **우클릭 가드**, 가드 게이지, **퍼펙트 가드**(탄 반사 + 적 기절), 가드 브레이크, 상시 방어력
- 투구: 방어력 + 최대 체력 증가, 플레이어 머리에 실제로 씌워져 보임
- 스테이지 3개 + 이후 강화 반복
  - 1 「초록 들판」: 슬라임·고블린 / 보스 **슬라임 킹**
  - 2 「불타는 지옥문」: 헬하운드·오크 / 보스 **지옥의 수문장** (업화를 두른 오크 킹)
  - 3 「원소의 유적」: 화염·빙결·뇌전·대지 골렘 / 보스 **원소의 거신 아르케온**
- 드랍: **골드는 확정**, **장비(무기/방패/투구)는 확률**. 중복 장비는 골드로 자동 환전
- 상점: **스테이지별 입고** (1스테이지 일반·희귀 / 2스테이지 레어 / 3스테이지 전설),
  등급별 배경색 (희귀 **파랑** / 레어 **보라** / 전설 **노랑**)
- `GameManager` 싱글톤(Autoload) + 시그널 → HUD(`TextureProgressBar`) 실시간 갱신

> **Godot 4.3 이상** (4.3 / 4.5 에서 헤드리스 통합 테스트 통과 확인). 렌더러: Compatibility.

---

## 실행 방법

1. Godot 4.3+ 실행 → **Import** → 이 폴더의 `project.godot` 선택
2. `F5` (메인 씬: `res://scenes/main/main.tscn`)

| 입력 | 동작 |
| --- | --- |
| `WASD` / 방향키 | 이동 |
| 마우스 이동 | 조준 |
| 마우스 왼쪽 (누르고 있기) | 공격 — 검: 휘두르기 / 활: 시위 당겨 발사 / 지팡이: 영창 후 시전 |
| 마우스 오른쪽 / `F` (누르고 있기) | 방패 가드 — 올린 직후 맞으면 퍼펙트 가드 |
| `Space` / `Shift` | 대시 |
| `Q` / 마우스 휠 | 무기 교체 |
| `E` | 상인과 대화(상점 열기/닫기) |
| `R` | 사망 후 재시작 |

---

## 폴더 구조

```
project.godot                  ← Autoload, 입력맵, 물리 레이어 이름, 픽셀 필터 설정
assets/
  sprites/…                    ← 플레이스홀더 도트 그래픽 (tools/generate_sprites.py 로 생성)
                                  characters / weapons / shields / helmets / projectiles / effects / items / tiles / ui
  ui/game_theme.tres           ← 전역 UI 테마 (폰트 크기)
data/
  weapons/*.tres               ← 무기 (WeaponData)
  shields/*.tres               ← 방패 (ShieldData)
  helmets/*.tres               ← 투구 (HelmetData)
  stages/stage_1~3.tres        ← 스테이지 구성 (StageData: 몬스터·보스·바닥·처치 목표)
scenes/
  main/main.tscn               ← 메인 월드
  player/player.tscn
  projectile/projectile.tscn
  enemies/                     ← slime, goblin, boss_slime_king,
                                  hellhound, orc, boss_hell_gatekeeper,
                                  golem_fire/ice/lightning/earth, boss_archeon
  world/pickup.tscn, shop_keeper.tscn
  ui/hud.tscn, shop_ui.tscn
scripts/
  autoload/game_manager.gd     ← Autoload "GameManager" (class_name 없음!)
  core/layers.gd               ← 물리 레이어 비트 상수
  core/elements.gd             ← 속성(화염/빙결/뇌전/대지/자연/신성/비전) 색·이름·파티클 방향
  core/floating_text.gd        ← 데미지 숫자 / 획득 텍스트
  fx/fx.gd                     ← 파티클 폭발 / 빛 / 충격파 / 오라 헬퍼 (static)
  fx/aoe_strike.gd             ← 예고 후 폭발하는 장판 공격 (Node2D)
  data/item_data.gd            ← ItemData (장비 공통: 등급·배경색·해금 스테이지)
  data/weapon_data.gd          ← WeaponData   data/shield_data.gd ← ShieldData   data/helmet_data.gd ← HelmetData
  data/stage_data.gd           ← StageData
  data/item_db.gd              ← ItemDB (id → 장비 조회)
  player/player.gd             ← Player (CharacterBody2D)
  player/attack_controller.gd  ← AttackController (Node) : 근접 / 시위 당기기 / 영창 / 발사
  player/guard_controller.gd   ← GuardController (Node)  : 방패 가드
  projectile/projectile_spec.gd← ProjectileSpec (발사 명세, RefCounted)
  projectile/projectile.gd     ← Projectile (Area2D) : 잔상·폭발·감속·반사
  projectile/projectile_pool.gd← ProjectilePool (Node)
  enemies/enemy.gd             ← Enemy (Area2D, 기반 클래스: 오라·감속·shoot()/telegraph_strike())
  enemies/slime.gd, goblin.gd, boss_slime_king.gd
  enemies/hellhound.gd, orc.gd, boss_hell_gatekeeper.gd
  enemies/golem.gd, boss_archeon.gd
  world/pickup.gd, shop_keeper.gd, stage_manager.gd
  ui/hud.gd, shop_ui.gd
  main/main.gd
tests/smoke_test.tscn/.gd      ← 헤드리스 통합 테스트
tools/generate_sprites.py      ← 도트 그래픽 생성기 (Pillow)
```

---

## 씬 트리 & 스크립트 부착 위치

### `scenes/main/main.tscn`

```
Main (Node2D)                          ← scripts/main/main.gd
├─ Ground (Node2D, z_index=-10)
│  ├─ Floor (Sprite2D, region 960x640, texture_repeat=Enabled)   ← 스테이지마다 텍스처 교체
│  └─ ShopRug (Sprite2D)
├─ Walls (StaticBody2D, layer 1 "world")                          ← 스테이지마다 색 교체
│  ├─ TopSprite / BottomSprite / LeftSprite / RightSprite (Sprite2D)
│  └─ Top / Bottom / Left / Right (CollisionShape2D, RectangleShape2D)
├─ Entities (Node2D, y_sort_enabled=true)   ← 캐릭터·몬스터·드랍이 여기에 들어감
│  ├─ ShopKeeper  (instance: shop_keeper.tscn)
│  └─ Player      (instance: player.tscn)
├─ ProjectilePool (Node)               ← projectile_pool.gd, projectile_scene = projectile.tscn, initial_size = 128
├─ HUD     (instance: hud.tscn)
├─ ShopUI  (instance: shop_ui.tscn)
└─ StageManager (Node)                 ← stage_manager.gd
                                          entities_root = ../Entities, player = ../Entities/Player,
                                          floor_sprite = ../Ground/Floor, walls = ../Walls,
                                          stages = [stage_1, stage_2, stage_3], pickup_scene = pickup.tscn
```

### `scenes/player/player.tscn`

```
Player (CharacterBody2D, motion_mode=Floating, layer 2 / mask 1)  ← player.gd
├─ Shadow (Sprite2D)
├─ BodySprite (Sprite2D, position (0,-8))
│  └─ HelmetSprite (Sprite2D)         ← 장착 투구의 worn_texture (몸과 같은 16x16 좌표)
├─ CollisionShape2D (CircleShape2D r=5)
├─ WeaponPivot (Node2D)               ← 마우스 방향으로 회전 (lerp_angle)
│  ├─ SwingPivot (Node2D)              ← 근접 공격 시 부채꼴로 회전하는 축
│  │  ├─ WeaponSprite (Sprite2D)       ← 무기 아이콘(45°) 또는 활의 held_texture(세로)
│  │  ├─ BowString (Line2D)            ← 활 시위 (당길수록 가운데 점이 뒤로)
│  │  └─ NockedArrow (Sprite2D)        ← 시위에 걸린 화살
│  ├─ SwingFx (Sprite2D, offset (12,0)) ← 휘두르기 이펙트 (리치/범위에 맞춰 스케일)
│  ├─ ShieldSprite (Sprite2D)           ← 평소 몸 뒤, 가드 시 정면
│  ├─ Muzzle (Marker2D, (13,-1))        ← 원거리 발사 위치 = 지팡이 구슬 위치
│  └─ ChargeOrb (Sprite2D, glow)        ← 영창 중 커지는 마력 구슬 (+ 코드로 만든 수렴 파티클)
├─ ChantLabel (Label)                  ← 영창 대사 (한 글자씩 나타남)
├─ AttackController (Node)            ← attack_controller.gd, player = ".."
├─ GuardController (Node)             ← guard_controller.gd, player = ".."
└─ Camera2D (smoothing, limit = 맵 크기)
```

> 탑뷰 게임이므로 `motion_mode = Floating` 이 필수입니다. (기본값 Grounded 는 플랫포머용)

### `scenes/projectile/projectile.tscn`

```
Projectile (Area2D, monitorable=false)   ← projectile.gd
├─ Sprite2D            ← 무기별 텍스처/색으로 교체됨
└─ CollisionShape2D (CircleShape2D r=5)
   (+ 코드로 추가: Trail(CPUParticles2D) 꼬리 잔상, Glow(Sprite2D) 빛 — 등급에 따라 켜짐)
```

### `scenes/enemies/*.tscn` (모두 동일 구조)

```
<몬스터> (Area2D, layer 3 / mask 2)  ← 각 몬스터 스크립트 (모두 Enemy 상속)
├─ Shadow (Sprite2D)
├─ Sprite2D            ← 스크립트가 `sprite` 로 참조 (이름 변경 금지)
└─ CollisionShape2D    ← 몸통 판정 (get_hit_center() 기준)
```

인스펙터에서 `max_hp`, `move_speed`, `contact_damage`, `aura_element / aura_amount`(몸에 두르는 속성 오라),
`gold_min/max`, `item_drop_chance`, `item_drop_ids`(장비 id) 를 조절합니다.
골렘 4종은 같은 `golem.gd` 에 `element` 만 다르게 지정한 씬입니다.

### `scenes/world/pickup.tscn` / `shop_keeper.tscn`

```
Pickup (Area2D, layer 6 / mask 2)   ← pickup.gd, gold_texture = coin.png
├─ Shadow, Sprite2D, CollisionShape2D

ShopKeeper (Area2D, mask 2)         ← shop_keeper.gd, stock_ids = 판매 장비 id 목록 (등급별로 스테이지가 올라야 구매 가능)
├─ Shadow, Sprite2D
├─ TalkArea (CollisionShape2D r=30)  ← 이 범위 안에서 E
├─ Solid (StaticBody2D)              ← 상인을 통과하지 못하게
└─ Hint (Label "[E] 상점")
```

### `scenes/ui/hud.tscn`

```
HUD (CanvasLayer, layer 5)  ← hud.gd   (노드 접근은 전부 %고유이름)
└─ Root (Control, 전체화면, mouse_filter=Ignore)
   ├─ %DamageFlash (ColorRect)
   ├─ StatusPanel (PanelContainer)
   │  └─ VBox
   │     ├─ HPRow:    Label "HP",    %HPBar (TextureProgressBar),    %HPLabel
   │     ├─ DashRow:  Label "DASH",  %DashBar (TextureProgressBar),  %DashLabel
   │     ├─ GuardRow: Label "GUARD", %GuardBar (TextureProgressBar), %GuardLabel
   │     ├─ GoldRow:  TextureRect(coin), %GoldLabel
   │     ├─ WeaponRow: %WeaponIcon, %WeaponLabel
   │     ├─ ShieldRow: %ShieldIcon, %ShieldLabel
   │     └─ HelmetRow: %HelmetIcon, %HelmetLabel (총 방어력 표시)
   ├─ TopCenter (VBox): %StageLabel("STAGE 2 · 불타는 지옥문"), %ProgressLabel, %BossBox(%BossName, %BossBar)
   ├─ %NoticeLabel
   ├─ ControlsHint (Label)
   └─ %GameOver (ColorRect + Label)
```

### `scenes/ui/shop_ui.tscn`

```
ShopUI (CanvasLayer, layer 20, process_mode=Always, visible=false)  ← shop_ui.gd
├─ Dim (ColorRect)
└─ Panel (PanelContainer) → Margin → VBox
   ├─ Header: %Title, %ShopGold
   ├─ Columns: BuyColumn(%BuyList) | InventoryColumn(%InventoryList)
   │    각 줄 = 등급색 배경 PanelContainer [아이콘 | [등급] 이름·요약 | 구매/장착 버튼]
   ├─ %Detail (마우스를 올린 장비 상세 스탯)
   └─ Footer: 안내 Label, %CloseButton
```

---

## ⚠️ Node vs Node2D – "Function not found in base self" 를 원천 차단한 방법

`get_global_mouse_position()`, `global_position`, `look_at()`, `to_local()`, `get_world_2d()` 등은 **CanvasItem / Node2D 의 함수**입니다.
`extends Node` 인 스크립트에서 `self` 로 호출하면 컴파일 에러가 납니다.

| 스크립트 | 상속 | 위치/마우스 함수 사용 |
| --- | --- | --- |
| `player.gd` | CharacterBody2D (Node2D) | ✅ 여기서만 `get_global_mouse_position()` 호출 |
| `attack_controller.gd` | **Node** | ❌ 자기 자신에게는 절대 호출 안 함 → `player.get_aim_direction()`, `player.get_attack_origin()`, `player.get_muzzle_position()`, `player.get_world_2d()` 사용. 시위/영창 연출도 `player.begin_windup()` 등으로 요청 |
| `guard_controller.gd` | **Node** | ❌ 방향은 `player.get_aim_direction()` 으로만 |
| `projectile_pool.gd` | **Node** | ❌ 위치는 `ProjectileSpec.origin` 으로만 전달 |
| `stage_manager.gd` | **Node** | ❌ `entities_root.to_local()`, `player.global_position` 처럼 **타입이 지정된 Node2D 참조**를 통해서만 |
| `game_manager.gd` | **Node** (Autoload) | ❌ 데이터만 다룸 |
| `fx.gd`, `elements.gd`, `item_db.gd` | (static 헬퍼) | ❌ 인스턴스 없음. 위치는 인자로 받음 |
| `projectile.gd`, `enemy.gd` 계열, `pickup.gd`, `shop_keeper.gd`, `aoe_strike.gd` | Area2D / Node2D | ✅ |

추가 안전장치:

- 모든 참조가 **정적 타입** (`@export var player: Player`, `@onready var _muzzle: Marker2D = ...`) 이라 잘못된 호출은 에디터에서 즉시 빨간 줄로 잡힙니다.
- `AttackController` / `GuardController` 의 `_ready()` 에서 부모가 `Player` 가 아니면 `assert` 로 명확한 메시지를 띄웁니다.
- 충돌 시그널 콜백 안에서 물리 상태 변경(`monitoring`, `disabled`, `collision_layer`, Area2D 추가)은 전부 `set_deferred` / `call_deferred` 로 처리해서
  `Can't change this state while flushing queries` 에러가 나지 않습니다.
- `GameManager` 스크립트에는 `class_name` 을 붙이지 않았습니다 (Autoload 이름과 충돌 방지).
- GDScript 경고를 전부 **에러로 취급**하는 설정에서도 모든 스크립트가 통과합니다 (변수 가림·정수 나눗셈·미사용 시그널 등 없음).

---

## 데이터 흐름 (시그널)

```
[좌클릭] ─▶ AttackController
            ├─ 근접(검/단검) ─▶ intersect_shape() → 조준 부채꼴 안의 Enemy 만 take_damage()  + 등급별 베기 이펙트
            ├─ 활    ─▶ player.begin_windup() → 시위 당기기 (windup_time) → 발사
            └─ 지팡이 ─▶ player.begin_windup() → 영창 + 구슬에 마력 집중 (windup_time) → 시전
                         발사 = ProjectilePool.spawn(ProjectileSpec)
                         → Projectile: 꼬리 잔상 / 명중 시 take_damage(), 감속, 폭발(주변 적 피해) → 풀로 반환

[우클릭] ─▶ GuardController (가드 게이지 / 퍼펙트 가드 판정)
적 접촉·적 탄·장판 ─▶ Player.take_hit(amount, from_position, attacker) → HitResult
                   IGNORED(대시) · DAMAGED(방패+투구 방어력 차감) · BLOCKED · PARRIED(탄 반사, 적 기절)

Enemy.shoot() / telegraph_strike() ─▶ ProjectilePool / AoeStrike (예고 원 → 폭발 → 범위 안 플레이어 피해)
Enemy.died ─▶ StageManager ─▶ 골드(확정)/장비(확률) Pickup, 처치 수 → 보스 → 다음 StageData (바닥/벽 교체)
Pickup  ─▶ GameManager.add_gold / add_item
ShopUI  ─▶ GameManager.buy_item / equip_item
                                        GameManager ── signals ──▶ HUD / ShopUI / Player(무기·방패·투구 스프라이트)
```

GameManager 시그널 목록: `player_hp_changed`, `player_damaged`, `player_died`, `dash_cooldown_changed`,
`guard_changed`, `guard_broken`, `gold_changed`, `inventory_changed`, `weapon_equipped`, `shield_equipped`, `helmet_equipped`,
`stage_changed`, `kill_progress_changed`, `intermission_changed`, `boss_spawned`, `boss_hp_changed`,
`boss_defeated`, `notice_requested`, `shop_open_requested`

---

## 물리 레이어

| 레이어 | 이름 | 비트값 | 사용 |
| --- | --- | --- | --- |
| 1 | world | 1 | 벽, 상인 몸체 |
| 2 | player | 2 | Player (CharacterBody2D) |
| 3 | enemy | 4 | Enemy (Area2D) |
| 4 | player_projectile | 8 | 플레이어 투사체 → mask: enemy + world |
| 5 | enemy_projectile | 16 | 적 탄 → mask: player + world |
| 6 | pickup | 32 | 드랍 아이템 → mask: player |

상수는 `scripts/core/layers.gd` (`Layers.ENEMY` 등) 에 모여 있습니다.

---

## 등급 & 상점

| 등급 | 상점 배경 | 상점 입고 | 이펙트 |
| --- | --- | --- | --- |
| 일반 | 회색 | 1스테이지 | 기본 베기 / 투사체 |
| 희귀 | **파랑** | 1스테이지 | + 베기 불티, 투사체 꼬리 잔상 |
| 레어 | **보라** | 2스테이지 | + 속성 파티클, 빛 번쩍임, 투사체 빛 |
| 전설 | **노랑** | 3스테이지 | + 빛의 충격파, 화면 흔들림, 거대 폭발 |

- 아직 잠긴 장비도 상점에 **어둡게 표시**되고 버튼에 `2스테이지` / `3스테이지` 처럼 해금 시점이 나옵니다.
- 스테이지를 클리어하면 "상점에 레어 등급 장비가 입고되었습니다!" 알림이 뜹니다.
- 수치: `ItemData.RARITY_BG_COLORS`, `RARITY_UNLOCK_STAGE` 에서 바꿀 수 있습니다.

## 무기

| 무기 | 종류 | 등급 | 속성 | ATK | 특징 | 획득 |
| --- | --- | --- | --- | --- | --- | --- |
| 녹슨 검 | 검 | 일반 | - | 8 | 리치 26, 110° | 시작 무기 |
| 강철 검 | 검 | 희귀 | - | 15 | 리치 30, 120° | 상점 150G / 고블린·오크 |
| 화염검 | 검 | 레어 | 화염 | 26 | 리치 36, 150°, 불티 | 상점 600G / 슬라임 킹·화염 골렘 |
| 성검 루멘 | 검 | 전설 | 신성 | 42 | 리치 42, 170°, 빛의 충격파 | 상점 1600G / 아르케온 |
| 고블린 단검 | 단검 | 희귀 | 자연 | 7 | 0.16초 연속 찌르기, 치명타 30% | 고블린 드랍 전용 |
| 사냥꾼의 활 | 활 | 일반 | - | 12 | 시위 0.3초, 사거리 280 | 상점 90G / 고블린 |
| 연사 석궁 | 활 | 희귀 | - | 8 | 시위 0.12초, 빠른 연사 | 상점 220G / 헬하운드 |
| 질풍의 활 | 활 | 레어 | 자연 | 15 | 3발 동시, 관통 2 | 상점 650G / 수문장·뇌전 골렘 |
| 태양궁 솔라리스 | 활 | 전설 | 화염 | 30 | 관통 4 + 명중마다 폭발 | 상점 1700G / 아르케온 |
| 견습 지팡이 | 지팡이 | 일반 | 비전 | 9 | 영창 0.4초, 3갈래 | 상점 110G / 슬라임 |
| 서리 지팡이 | 지팡이 | 희귀 | 빙결 | 12 | 3갈래 얼음 창, 적 감속 | 상점 240G / 헬하운드·빙결 골렘 |
| 업화의 지팡이 이그니스 | 지팡이 | 레어 | 화염 | 30 | 거대 화염구, 반경 40 폭발 | 상점 700G / 수문장·화염 골렘 |
| 대마법사의 지팡이 아르카나 | 지팡이 | 전설 | 비전 | 16 | 영창 0.7초, 9발 연쇄 폭발 | 상점 1800G / 아르케온 |
| 슬라임 지팡이 | 지팡이 | 희귀 | 자연 | 8 | 5갈래 | 슬라임 드랍 전용 |
| 슬라임 왕의 홀 | 지팡이 | 전설 | 비전 | 14 | 7갈래 + 폭발 | 슬라임 킹 드랍 전용 |

- 지팡이마다 영창 대사가 다릅니다 (예: 이그니스 "타올라라, 업화의 불꽃이여!", 아르카나 "별의 근원이여, 나의 부름에 응하라!").
- 시위 당기기 / 영창 중에는 이동이 느려지고, 가드·무기 교체·클릭 해제 시 취소됩니다.

## 방패 & 투구

| 방패 | 등급 | 막기 | 방어 | 가드 범위 | 게이지 | 퍼펙트 판정 | 획득 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 나무 방패 | 일반 | 70% | 0 | 110° | 40 | 0.15초 | 시작 방패 |
| 강철 방패 | 희귀 | 90% | 1 | 120° | 70 | 0.15초 | 상점 160G / 오크 |
| 고블린 버클러 | 희귀 | 75% | 0 | 90° | 45 | 0.28초 | 고블린 드랍 전용 |
| 왕실 방패 | 레어 | 100% | 2 | 160° | 100 | 0.20초 | 상점 500G / 보스 |
| 거신의 방벽 | 전설 | 100% | 3 | 180° | 150 | 0.22초 | 상점 1500G / 아르케온 |

| 투구 | 등급 | 방어 | 최대 HP | 획득 |
| --- | --- | --- | --- | --- |
| 가죽 두건 | 일반 | 1 | +10 | 상점 60G / 슬라임·고블린 |
| 강철 투구 | 희귀 | 2 | +20 | 상점 180G / 헬하운드 |
| 오크 전투투구 | 레어 | 3 | +35 | 상점 450G / 오크·대지 골렘 |
| 수문장의 뿔투구 | 전설 | 5 | +60 | 상점 1400G / 지옥의 수문장 |

- **방어력** = 방패 방어 + 투구 방어. 모든 피해에서 이만큼 빠집니다 (최소 1).
- **가드(우클릭)**: 정면 공격의 막기 % 를 게이지가 대신 받음. 옆·뒤는 못 막음. 가드 중 공격 불가.
- **퍼펙트 가드**: 가드를 올린 직후 맞으면 피해 0, 적 탄 **2배 반사**, 근접한 적 **기절**.
- **가드 브레이크**: 게이지 0 → 잠시 가드 불가.

---

## 스테이지 & 몬스터

| 스테이지 | 일반 몬스터 | 보스 |
| --- | --- | --- |
| 1 「초록 들판」 | **슬라임**(통통 튀며 접근), **고블린**(지그재그 접근 후 돌진) | **슬라임 킹** — 원형 탄막, 슬라임 소환, 분노 2페이즈 |
| 2 「불타는 지옥문」 | **헬하운드**(불꽃 오라, 주위를 돌다 물어뜯기 돌진), **오크**(곤봉 치켜들기 → 예고 장판 내려찍기) | **지옥의 수문장** — 업화를 두른 오크 킹. 불꽃 돌진 / 화염구 고리 / 예고 화염 기둥 / 헬하운드 소환. 체력 50% 이하 업화 각성 |
| 3 「원소의 유적」 | **화염 골렘**(화염구 3발), **빙결 골렘**(얼음 파편, 감속), **뇌전 골렘**(예고 낙뢰), **대지 골렘**(대지 강타 + 돌 파편 고리) | **원소의 거신 아르케온** (아래) |

### 3스테이지 보스: 원소의 거신 아르케온 (Archeon, the Elemental Colossus)

> 원소의 유적 가장 깊은 곳을 지키는 고대의 거신 골렘. 수정 왕관을 쓴 거대한 석상 몸체에
> 화염·빙결·뇌전·대지 **4개의 원소 핵**이 박혀 있고, 핵들이 몸 주위를 공전한다.
> 활성화된 핵의 빛이 바뀔 때마다 전혀 다른 공격을 쏟아낸다.

| 활성 핵 | 패턴 |
| --- | --- |
| 화염 | 회전하는 화염구 고리 3연발 |
| 빙결 | 양방향 나선 얼음 파편 (맞으면 감속) |
| 뇌전 | 플레이어 주변 시간차 낙뢰 6발 (예고 원) |
| 대지 | 자기 주변 대지 붕괴(반경 70 장판) → 돌 파편 고리 |

- 체력 50% 이하 **「원소 융합」**: 두 속성을 동시에 사용, 핵 공전 가속, 해당 속성 골렘 소환.
- 드랍: 성검 루멘 / 태양궁 솔라리스 / 아르카나 / 거신의 방벽 중 하나 (전설, 확정).

3스테이지 이후에는 「원소의 유적 +1」, 「+2」… 로 반복되며 몬스터 체력·공격력·골드가 계속 올라갑니다.

---

## 확장 가이드

### 새 장비 추가
1. `data/weapons|shields|helmets/` 의 `.tres` 를 복제 → 인스펙터에서 `id`, 등급, 수치, 아이콘 수정
   - 활: `weapon_type = BOW`, `held_texture`(세로 활 그림), `windup_time`(시위 시간)
   - 지팡이: `weapon_type = STAFF`, `windup_time`(영창 시간), `chant_text`(영창 대사), 필요하면 `explosion_radius`, `slow_duration`
   - 등급(`rarity`)만 올려도 상점 배경색 · 해금 스테이지 · 이펙트 화려함이 자동으로 바뀝니다.
2. `scripts/data/item_db.gd` 의 `ITEM_PATHS` 에 경로 추가
3. 상점: `ShopKeeper.stock_ids`, 드랍: 몬스터의 `item_drop_ids` 에 id 추가

### 새 몬스터 / 스테이지 추가
1. 비슷한 몬스터 씬(`scenes/enemies/*.tscn`) 복제, 스크립트를 `extends Enemy` 인 새 스크립트로 교체
2. `_get_move_velocity(delta)` (이동/패턴) / `_update_visual(delta, move)` (연출) 오버라이드.
   탄은 `shoot()`, 장판은 `telegraph_strike()`, 소환은 `request_summon()` 을 쓰면 됩니다.
3. `data/stages/` 에 `StageData` 를 만들어 `enemy_scenes`, `enemy_weights`, `boss_scene`, `floor_texture` 지정
   → `main.tscn` 의 `StageManager.stages` 배열에 추가

---

## 그래픽 교체

`assets/sprites/` 의 PNG 는 `tools/generate_sprites.py` 로 만든 플레이스홀더입니다.
같은 파일명으로 덮어쓰면 바로 반영됩니다. (프로젝트 기본 텍스처 필터가 **Nearest** 라 도트가 선명하게 유지됩니다.)

- 투구 `*_worn.png` 는 `player.png` 와 같은 16x16 좌표에 머리 부분만 그린 그림입니다 (몸 위에 겹쳐 그려짐).
- 활 `*_held.png` 는 세로로 선 활(시위 없음). 시위 끝점은 `Player.BOW_TIP_TOP / BOW_TIP_BOTTOM` 상수와 맞춰 주세요.
- 애니메이션이 필요하면 `BodySprite`/`Sprite2D` 를 `AnimatedSprite2D` 로 바꾸고 스크립트의 `@onready` 타입만 맞춰 주세요.

한글 폰트: 기본 폰트에서 시스템 폰트 폴백으로 한글이 표시됩니다. 픽셀 폰트(예: Galmuri)를 쓰려면
`assets/ui/game_theme.tres` 의 `default_font` 에 지정하세요.

---

## 테스트

모든 시스템을 실제로 구동해 검증하는 헤드리스 통합 테스트 (102개 항목):
이동·대시 / 근접 부채꼴 판정 / 활 시위 당기기·취소 / 지팡이 영창·시전 / 등급별 이펙트 / 폭발 범위 피해 /
가드·퍼펙트 가드·가드 브레이크 / 드랍·줍기 / 상점 스테이지 잠금·등급 배경색·투구 / 3개 스테이지의 일반 몹과 보스 패턴 실행 /
반복 스테이지 / 사망·재시작

```bash
godot --headless --path . res://tests/smoke_test.tscn
# → ALL TESTS PASSED (exit code 0)
```

> `-s` 옵션으로 스크립트를 직접 실행하면 Autoload(GameManager) 보다 먼저 컴파일되어 `Identifier not found: GameManager` 가 나므로 반드시 **씬으로** 실행합니다.
