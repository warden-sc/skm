# 세피리아(Sefirah) 스타일 탑뷰 액션 – Godot 4 뼈대

2D 도트 그래픽 탑뷰 액션 게임의 **바로 실행 가능한** Godot 4 프로젝트입니다.

- 플레이어: 8방향 가감속 이동, 마우스 조준, 쿨타임 대시(무적 + 잔상)
- 공격: 오브젝트 풀 기반 투사체(검기 / 화살 / 마력탄), 무기별 데미지·치명타·관통·산탄
- 몬스터: 슬라임, 고블린, 스테이지 보스 **슬라임 킹**(원형 탄막, 졸개 소환, 2페이즈)
- 드랍: **골드는 확정 드랍**, **무기는 확률 드랍**(몬스터별 드랍 테이블). 중복 무기는 골드로 자동 환전
- 상점: 상인 NPC 에게 `E` → **골드로 무기 구매**, 보유 무기 장착 교체(일시정지 UI)
- 장착 무기에 따라 데미지가 달라지며 HUD / 상점에서 ATK, DPS 를 비교할 수 있습니다
- 스테이지: 정비 시간 → 웨이브(목표 처치 수) → 보스 → 클리어(체력 회복) → 다음 스테이지(몬스터 강화)
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
| 마우스 왼쪽 (누르고 있기) | 공격 |
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
  ui/game_theme.tres           ← 전역 UI 테마 (폰트 크기)
data/weapons/*.tres            ← 무기 데이터 (WeaponData 리소스)
scenes/
  main/main.tscn               ← 메인 월드
  player/player.tscn
  projectile/projectile.tscn
  enemies/slime.tscn, goblin.tscn, boss_slime_king.tscn
  world/pickup.tscn, shop_keeper.tscn
  ui/hud.tscn, shop_ui.tscn
scripts/
  autoload/game_manager.gd     ← Autoload "GameManager" (class_name 없음!)
  core/layers.gd               ← 물리 레이어 비트 상수
  core/floating_text.gd        ← 데미지 숫자 / 획득 텍스트
  data/weapon_data.gd          ← WeaponData (Resource)
  data/weapon_db.gd            ← WeaponDB (id → WeaponData 조회)
  player/player.gd             ← Player (CharacterBody2D)
  player/attack_controller.gd  ← AttackController (Node)
  projectile/projectile_spec.gd← ProjectileSpec (발사 명세, RefCounted)
  projectile/projectile.gd     ← Projectile (Area2D)
  projectile/projectile_pool.gd← ProjectilePool (Node)
  enemies/enemy.gd             ← Enemy (Area2D, 기반 클래스)
  enemies/slime.gd, goblin.gd, boss_slime_king.gd
  world/pickup.gd              ← Pickup (Area2D)
  world/shop_keeper.gd         ← ShopKeeper (Area2D)
  world/stage_manager.gd       ← StageManager (Node)
  ui/hud.gd                    ← HUD (CanvasLayer)
  ui/shop_ui.gd                ← ShopUI (CanvasLayer)
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
│  ├─ Floor (Sprite2D, region 960x640, texture_repeat=Enabled)
│  └─ ShopRug (Sprite2D)
├─ Walls (StaticBody2D, layer 1 "world")
│  ├─ TopSprite / BottomSprite / LeftSprite / RightSprite (Sprite2D)
│  └─ Top / Bottom / Left / Right (CollisionShape2D, RectangleShape2D)
├─ Entities (Node2D, y_sort_enabled=true)   ← 캐릭터·몬스터·드랍이 여기에 들어감
│  ├─ ShopKeeper  (instance: shop_keeper.tscn)
│  └─ Player      (instance: player.tscn)
├─ ProjectilePool (Node)               ← scripts/projectile/projectile_pool.gd
│                                         projectile_scene = projectile.tscn, initial_size = 128
├─ HUD     (instance: hud.tscn)
├─ ShopUI  (instance: shop_ui.tscn)
└─ StageManager (Node)                 ← scripts/world/stage_manager.gd
                                          entities_root = ../Entities, player = ../Entities/Player
                                          slime/goblin/boss/pickup_scene 지정
```

### `scenes/player/player.tscn`

```
Player (CharacterBody2D, motion_mode=Floating, layer 2 / mask 1)  ← player.gd
├─ Shadow (Sprite2D)
├─ BodySprite (Sprite2D, position (0,-8))
├─ CollisionShape2D (CircleShape2D r=5)
├─ WeaponPivot (Node2D)               ← 마우스 방향으로 회전 (lerp_angle)
│  ├─ WeaponSprite (Sprite2D, rotation 45°)  ← 장착 무기 아이콘이 표시됨
│  └─ Muzzle (Marker2D, position (14,0))     ← 투사체 발사 위치
├─ AttackController (Node)            ← attack_controller.gd, player = ".."
└─ Camera2D (smoothing, limit = 맵 크기)
```

> 탑뷰 게임이므로 `motion_mode = Floating` 이 필수입니다. (기본값 Grounded 는 플랫포머용)

### `scenes/projectile/projectile.tscn`

```
Projectile (Area2D, monitorable=false)   ← projectile.gd
├─ Sprite2D            ← 무기별 텍스처/색으로 교체됨
└─ CollisionShape2D (CircleShape2D r=5)
```

### `scenes/enemies/*.tscn` (세 개 모두 동일 구조)

```
Slime / Goblin / BossSlimeKing (Area2D, layer 3 / mask 2)  ← slime.gd / goblin.gd / boss_slime_king.gd
├─ Shadow (Sprite2D)
├─ Sprite2D            ← 스크립트가 `sprite` 로 참조 (이름 변경 금지)
└─ CollisionShape2D
```

인스펙터에서 `max_hp`, `move_speed`, `contact_damage`, `gold_min/max`, `weapon_drop_chance`, `weapon_drop_ids` 를 조절합니다.

### `scenes/world/pickup.tscn` / `shop_keeper.tscn`

```
Pickup (Area2D, layer 6 / mask 2)   ← pickup.gd, gold_texture = coin.png
├─ Shadow, Sprite2D, CollisionShape2D

ShopKeeper (Area2D, mask 2)         ← shop_keeper.gd, stock_ids = 판매 무기 id 목록
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
   │     ├─ HPRow:    Label "HP",   %HPBar (TextureProgressBar),   %HPLabel
   │     ├─ DashRow:  Label "DASH", %DashBar (TextureProgressBar), %DashLabel
   │     ├─ GoldRow:  TextureRect(coin), %GoldLabel
   │     └─ WeaponRow: %WeaponIcon, %WeaponLabel
   ├─ TopCenter (VBox): %StageLabel, %ProgressLabel, %BossBox(%BossName, %BossBar)
   ├─ %NoticeLabel
   ├─ ControlsHint (Label)
   └─ %GameOver (ColorRect + Label)
```

`TextureProgressBar` 는 `nine_patch_stretch = true` + stretch margin 2 로 설정되어 있어 크기를 자유롭게 바꿔도 테두리가 깨지지 않습니다.

### `scenes/ui/shop_ui.tscn`

```
ShopUI (CanvasLayer, layer 20, process_mode=Always, visible=false)  ← shop_ui.gd
├─ Dim (ColorRect)
└─ Panel (PanelContainer) → Margin → VBox
   ├─ Header: %Title, %ShopGold
   ├─ Columns: BuyColumn(%BuyList) | InventoryColumn(%InventoryList)
   ├─ %Detail (마우스를 올린 무기 상세 스탯)
   └─ Footer: 안내 Label, %CloseButton
```

---

## ⚠️ Node vs Node2D – "Function not found in base self" 를 원천 차단한 방법

`get_global_mouse_position()`, `global_position`, `look_at()`, `to_local()` 등은 **CanvasItem / Node2D 의 함수**입니다.
`extends Node` 인 스크립트에서 `self` 로 호출하면 컴파일 에러가 납니다.

이 프로젝트의 규칙:

| 스크립트 | 상속 | 위치/마우스 함수 사용 |
| --- | --- | --- |
| `player.gd` | CharacterBody2D (Node2D) | ✅ 여기서만 `get_global_mouse_position()` 호출 |
| `attack_controller.gd` | **Node** | ❌ 자기 자신에게는 절대 호출 안 함 → `player.get_aim_direction()`, `player.get_muzzle_position()` 사용 |
| `projectile_pool.gd` | **Node** | ❌ 위치는 `ProjectileSpec.origin` 으로만 전달 |
| `stage_manager.gd` | **Node** | ❌ `entities_root.to_local()`, `player.global_position` 처럼 **타입이 지정된 Node2D 참조**를 통해서만 |
| `game_manager.gd` | **Node** (Autoload) | ❌ 데이터만 다룸 |
| `projectile.gd`, `enemy.gd`, `pickup.gd`, `shop_keeper.gd` | Area2D (Node2D) | ✅ |

추가 안전장치:

- 모든 참조가 **정적 타입** (`@export var player: Player`, `@onready var _muzzle: Marker2D = ...`) 이라 잘못된 호출은 에디터에서 즉시 빨간 줄로 잡힙니다.
- `AttackController._ready()` 에서 부모가 `Player` 가 아니면 `assert` 로 명확한 메시지를 띄웁니다.
- 충돌 시그널 콜백 안에서 물리 상태 변경(`monitoring`, `disabled`, Area2D 추가)은 전부 `set_deferred` / `call_deferred` 로 처리해서
  `Can't change this state while flushing queries` 에러가 나지 않습니다.
- `GameManager` 스크립트에는 `class_name` 을 붙이지 않았습니다 (Autoload 이름과 충돌 방지).

---

## 데이터 흐름 (시그널)

```
[입력] ─▶ Player ──(get_aim_direction / get_muzzle_position)──▶ AttackController
                                                                    │ ProjectileSpec.from_weapon(GameManager.equipped_weapon)
                                                                    ▼
                                                             ProjectilePool.spawn()
                                                                    │
                                Projectile.area_entered(Enemy) ─────┘
                                    │ enemy.take_damage()   → release() → finished ─▶ 풀로 반환
                                    ▼
                         Enemy.died ─▶ StageManager ─▶ 골드(확정)/무기(확률) Pickup 생성, 처치 수 → 보스 스폰
                                                         │
Pickup ─▶ GameManager.add_gold / add_weapon              │ report_boss_* / set_kill_progress / set_stage
Player ─▶ GameManager.damage_player / set_dash_cooldown  │
ShopUI ─▶ GameManager.buy_weapon / equip_weapon          ▼
                                        GameManager ── signals ──▶ HUD (TextureProgressBar, Label)
                                                                 ─▶ ShopUI (목록 갱신)
                                                                 ─▶ Player (무기 스프라이트 교체)
```

GameManager 시그널 목록: `player_hp_changed`, `player_damaged`, `player_died`, `dash_cooldown_changed`,
`gold_changed`, `inventory_changed`, `weapon_equipped`, `stage_changed`, `kill_progress_changed`,
`intermission_changed`, `boss_spawned`, `boss_hp_changed`, `boss_defeated`, `notice_requested`, `shop_open_requested`

---

## 물리 레이어

| 레이어 | 이름 | 비트값 | 사용 |
| --- | --- | --- | --- |
| 1 | world | 1 | 벽, 상인 몸체 |
| 2 | player | 2 | Player (CharacterBody2D) |
| 3 | enemy | 4 | Enemy (Area2D) |
| 4 | player_projectile | 8 | 플레이어 투사체 → mask: enemy + world |
| 5 | enemy_projectile | 16 | 보스 탄막 → mask: player + world |
| 6 | pickup | 32 | 드랍 아이템 → mask: player |

상수는 `scripts/core/layers.gd` (`Layers.ENEMY` 등) 에 모여 있습니다.

---

## 무기 & 데미지

| 무기 | 등급 | ATK | 특징 | 획득 |
| --- | --- | --- | --- | --- |
| 녹슨 검 | 일반 | 6 | 짧은 검기, 관통 2 | 시작 무기 |
| 강철 검 | 희귀 | 12 | 넓은 검기, 관통 3 | 상점 150G / 고블린 드랍 |
| 화염검 | 영웅 | 22 | 거대 검기, 관통 6 | 상점 600G / 보스 드랍 |
| 고블린 단검 | 희귀 | 6 | 초고속, 치명타 30% x2.2 | 고블린 드랍 전용 |
| 사냥꾼의 활 | 일반 | 10 | 긴 사거리 | 상점 90G / 고블린 드랍 |
| 연사 석궁 | 희귀 | 6 | 0.13초 연사 | 상점 220G |
| 견습 지팡이 | 일반 | 7 | 3갈래 마력탄 | 상점 110G / 슬라임 드랍 |
| 슬라임 지팡이 | 희귀 | 6 | 5갈래 점액탄 | 슬라임 드랍 전용 |
| 슬라임 왕의 홀 | 전설 | 11 | 7갈래, 관통 2 | 보스 드랍 전용 |

1발 데미지 = `weapon.damage × GameManager.damage_multiplier` (치명타 시 `× crit_multiplier`).
몬스터는 스테이지마다 HP +45%, 접촉 데미지 +20%, 골드 +30% 씩 강해집니다 (`Enemy.apply_stage_scaling`).

### 새 무기 추가

1. 파일시스템에서 `data/weapons/iron_sword.tres` 복제 → 인스펙터에서 `id`, 수치, 아이콘 수정
2. `scripts/data/weapon_db.gd` 의 `WEAPON_PATHS` 에 경로 추가
3. 상점에서 팔려면 `ShopKeeper.stock_ids`, 드랍시키려면 몬스터의 `weapon_drop_ids` 에 id 추가

### 새 몬스터 추가

1. `scenes/enemies/slime.tscn` 복제, 스크립트를 `extends Enemy` 인 새 스크립트로 교체
2. `_get_move_velocity(delta)` (이동 패턴) / `_update_visual(delta, move)` (연출) 오버라이드
3. `StageManager._spawn_regular_enemy()` 의 스폰 목록에 추가

---

## 그래픽 교체

`assets/sprites/` 의 PNG 는 `tools/generate_sprites.py` 로 만든 플레이스홀더입니다.
같은 파일명으로 덮어쓰면 바로 반영됩니다. (프로젝트 기본 텍스처 필터가 **Nearest** 라 도트가 선명하게 유지됩니다.)
애니메이션이 필요하면 `BodySprite`/`Sprite2D` 를 `AnimatedSprite2D` 로 바꾸고 스크립트의 `@onready` 타입만 맞춰 주세요.

한글 폰트: 기본 폰트에서 시스템 폰트 폴백으로 한글이 표시됩니다. 픽셀 폰트(예: Galmuri)를 쓰려면
`assets/ui/game_theme.tres` 의 `default_font` 에 지정하세요.

---

## 테스트

모든 시스템(이동·대시·발사·풀 반환·피격·드랍·줍기·무기 교체 데미지·상점·보스 탄막·사망·재시작)을 실제로 구동해 검증하는 헤드리스 테스트:

```bash
godot --headless --path . res://tests/smoke_test.tscn
# → ALL TESTS PASSED (exit code 0)
```

> `-s` 옵션으로 스크립트를 직접 실행하면 Autoload(GameManager) 보다 먼저 컴파일되어 `Identifier not found: GameManager` 가 나므로 반드시 **씬으로** 실행합니다.
