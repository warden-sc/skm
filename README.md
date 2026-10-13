# 크루세이더 — 세피리아(Sefirah) 스타일 탑뷰 액션 (Godot 4)

2D 도트 그래픽 탑뷰 액션 게임의 **바로 실행 가능한** Godot 4 프로젝트입니다.

- **타이틀**: 전사와 몬스터가 싸우는 일러스트 배경 + **난이도 선택 (노멀 / 하드 / 베리하드)** → **조작 안내** → 모험 시작
- **맵 흐름**: 야영지(상인) → 텔레포트 → 사냥터(처치 목표 달성 시 **보스방 봉인 해제**) → 보스방 → **보물상자** + 다음 스테이지 텔레포트
- **장비 칸**: 무기 3칸(**검 / 활 / 지팡이**, 1·2·3·Q 로 전환) · 방어구 3칸(**방패 / 투구 / 갑옷**) · **보석 3칸**(치명타 확률·치명타 피해·공격력)
- **인벤토리**(I / Tab): 장비 칸 + 가방 + 능력치 요약. 상인에게 **장비 판매** 가능
- 검(근접): 부채꼴 범위 타격 / 활: **시위 당겨 발사** / 지팡이: **영창 → 구슬에 마력 집중 → 시전**
- 등급(일반·희귀·레어·전설)이 높을수록 공격력·방어력뿐 아니라 **이펙트도 화려**
- 방패 가드 · 퍼펙트 가드(탄 반사, 적 기절) · 가드 브레이크
- 스테이지 3개 + 이후 강화 반복 (슬라임 킹 → 지옥의 수문장 → 원소의 거신 아르케온)
- `GameManager` 싱글톤(Autoload) + 시그널 → HUD(`TextureProgressBar`) / 상점 / 인벤토리 실시간 갱신

> **Godot 4.3 이상** (4.3 / 4.5 에서 헤드리스 통합 테스트 통과 확인). 렌더러: Compatibility.

---

## 실행 방법

1. Godot 4.3+ 실행 → **Import** → 이 폴더의 `project.godot` 선택
2. `F5` → 타이틀(`res://scenes/title/title.tscn`) → 난이도 선택 → 조작 안내 → **모험 시작**

| 입력 | 동작 |
| --- | --- |
| `WASD` / 방향키 | 이동 |
| 마우스 이동 | 조준 |
| 마우스 왼쪽 (누르고 있기) | 공격 — 검: 휘두르기 / 활: 시위 당겨 발사 / 지팡이: 영창 후 시전 |
| 마우스 오른쪽 / `F` (누르고 있기) | 방패 가드 — 올린 직후 맞으면 퍼펙트 가드 |
| `Space` / `Shift` | 대시 (무적) |
| `1` / `2` / `3`, `Q` / 마우스 휠 | 무기 칸 전환 (검 · 활 · 지팡이) |
| `E` | 상호작용 — 상인 · 텔레포트 · 보스문 · 보물상자 |
| `I` / `Tab` | 인벤토리 |
| `ESC` | 창 닫기 |
| `R` / `T` | 쓰러졌을 때 다시 시작(같은 난이도) / 타이틀로 |

---

## 게임 흐름

```
타이틀 ─ 난이도 선택 ─ 조작 안내 ─▶ STAGE 1 야영지
                                       │ 상인[E]: 구매 · 판매   인벤토리[I]: 장착
                                       ▼ 텔레포트[E]
                                     사냥터 ── 귀환 텔레포트[E] ──▶ 야영지 (진행도 유지)
                                       │ 몬스터 N마리 처치 → 북쪽 보스문 봉인 해제
                                       ▼ 보스문[E]
                                     보스방 ── 보스 토벌 ──▶ 보물상자[E] + 금색 텔레포트 등장
                                       ▼ 텔레포트[E]
                                   STAGE 2 야영지 …
```

| 스테이지 | 일반 몬스터 | 보스 | 잡몹 드랍 최고 등급 | 보스 상자 |
| --- | --- | --- | --- | --- |
| 1 「초록 들판」 | 슬라임, 고블린 | 슬라임 킹 | 희귀 | **레어** 1개 |
| 2 「불타는 지옥문」 | 헬하운드, 오크 | 지옥의 수문장 | 레어 | **전설** 1개 |
| 3 「원소의 유적」 | 화염·빙결·뇌전·대지 골렘 | 원소의 거신 아르케온 | 전설 | **전설** 1개 |
| 4~ 「원소의 유적 +N」 | (3스테이지 반복, 점점 강해짐) | | 전설 | 전설 |

- **보물상자**: 검 / 활 / 지팡이 / 방패 / 투구 / 갑옷 중 해당 등급 장비 1개 (아직 없는 것 우선) + 골드
- 보스는 장비를 직접 떨어뜨리지 않고 **상자로 보상**합니다. 보스방에 남은 전리품은 다음 스테이지로 갈 때 자동 회수됩니다.
- **골드는 모든 몬스터가 확정 드랍**, 장비는 몬스터별 드랍 테이블에서 확률 드랍 (스테이지 최고 등급 이하만).

### 난이도

| 난이도 | 몬스터 체력 | 몬스터 공격력 | 몬스터 속도 | 동시 출현 | 골드 |
| --- | --- | --- | --- | --- | --- |
| 노멀 | x1.0 | x1.0 | x1.0 | 기본 | x1.0 |
| 하드 | x1.5 | x1.4 | x1.1 | +2 | x1.25 |
| 베리하드 | x2.2 | x1.9 | x1.2 | +4 | x1.6 |

수치는 `GameManager.DIFFICULTY_INFO` 에서 바꿀 수 있습니다.

---

## 장비

### 장비 칸

| 칸 | 개수 | 내용 |
| --- | --- | --- |
| 무기 | 3 | **검 칸**(검·단검) / **활 칸** / **지팡이 칸** — 종류별로 1개씩만. 같은 종류를 장착하면 기존 것은 가방으로 |
| 방어구 | 3 | 방패 / 투구 / 갑옷 — 방어력은 셋의 합, 최대 HP 는 투구 + 갑옷 보너스 |
| 보석 | 3 | 치명타 확률 · 치명타 피해 · 공격력 보너스 (합산, 모든 무기에 적용) |

- 손에 든 무기는 `1/2/3` 또는 `Q`·휠로 바꿉니다. (HUD 아래 단축바에서 노란 테두리)
- 마지막으로 남은 무기는 해제할 수 없습니다.
- **판매**: 야영지 상인 → 오른쪽 「보유 장비 · 판매」 → 판매 (가격의 40%). 장착 중인 장비는 인벤토리에서 해제 후 판매.
- 이미 가진 장비를 다시 주우면 판매가만큼 골드로 자동 환전됩니다.

### 등급 & 상점

| 등급 | 상점 배경 | 상점 입고 | 이펙트 |
| --- | --- | --- | --- |
| 일반 | 회색 | 1스테이지 | 기본 |
| 희귀 | **파랑** | 1스테이지 | + 베기 불티, 투사체 꼬리 잔상 |
| 레어 | **보라** | 2스테이지 | + 속성 파티클, 빛 번쩍임 |
| 전설 | **노랑** | 3스테이지 | + 빛의 충격파, 거대 폭발 |

### 무기

| 무기 | 종류 | 등급 | ATK | 특징 |
| --- | --- | --- | --- | --- |
| 녹슨 검 | 검 | 일반 | 8 | 시작 무기 |
| 강철 검 | 검 | 희귀 | 15 | 리치 30 |
| 화염검 | 검 | 레어 | 26 | 불티, 범위 150° |
| 성검 루멘 | 검 | 전설 | 42 | 빛의 충격파, 범위 170° |
| 고블린 단검 | 검 칸 | 희귀 | 7 | 빠른 찌르기 (고블린 드랍) |
| 사냥꾼의 활 / 연사 석궁 / 질풍의 활 / 태양궁 솔라리스 | 활 | 일반 → 전설 | 12 / 8 / 15 / 30 | 시위 당기기, 3발 동시, 관통 폭발 |
| 견습 / 서리 / 업화(이그니스) / 대마법사(아르카나) 지팡이 | 지팡이 | 일반 → 전설 | 9 / 12 / 30 / 16 | 영창, 감속, 화염 폭발, 9발 연쇄 폭발 |
| 슬라임 지팡이 · 슬라임 왕의 홀 | 지팡이 | 희귀 · 전설 | 8 · 14 | 드랍 전용 |

### 방어구 & 보석

| 방패 | 투구 | 갑옷 | 등급 |
| --- | --- | --- | --- |
| 나무 방패 (막기 70%) | 가죽 두건 (방어 1, HP+10) | 가죽 갑옷 (방어 1, HP+15) | 일반 |
| 강철 방패 (90%, 방어 1) / 고블린 버클러 | 강철 투구 (2, +20) | 사슬 갑옷 (2, +25) | 희귀 |
| 왕실 방패 (100%, 방어 2) | 오크 전투투구 (3, +35) | 지옥강철 갑옷 (4, +40) | 레어 |
| 거신의 방벽 (100%, 방어 3) | 수문장의 뿔투구 (5, +60) | 성기사의 판금 갑옷 (6, +70) | 전설 |

| 보석 | 등급 | 효과 |
| --- | --- | --- |
| 거친 루비 | 일반 | 치명타 확률 +3% |
| 루비 | 희귀 | 치명타 확률 +6% |
| 사파이어 | 희귀 | 치명타 피해 +30% |
| 핏빛 루비 | 레어 | 치명타 확률 +10%, 치명타 피해 +20% |
| 별의 다이아몬드 | 전설 | 치명타 확률 +15%, 치명타 피해 +40%, 공격력 +10% |

1타 데미지 = `무기 공격력 × (1 + 보석 공격력)`, 치명타 확률 = `무기 + 보석`, 치명타 배율 = `무기 + 보석`.
방어력 = 방패 + 투구 + 갑옷 (모든 피해에서 차감, 최소 1).

---

## 몬스터 & 보스

| 스테이지 | 몬스터 |
| --- | --- |
| 1 | **슬라임**(통통 튀며 접근), **고블린**(지그재그 후 돌진) / 보스 **슬라임 킹**(원형 탄막, 슬라임 소환, 분노) |
| 2 | **헬하운드**(불꽃 오라, 돌다가 돌진), **오크**(예고 장판 내려찍기) / 보스 **지옥의 수문장**(업화를 두른 오크 킹: 돌진·화염구 고리·화염 기둥·헬하운드 소환·업화 각성) |
| 3 | **화염·빙결·뇌전·대지 골렘** / 보스 **원소의 거신 아르케온** |

**원소의 거신 아르케온** — 원소의 유적 깊은 곳을 지키는 고대 거신 골렘. 몸 주위를 도는 4개의 원소 핵 중
활성 핵에 따라 화염구 고리 → 빙결 나선(감속) → 시간차 낙뢰 → 대지 붕괴 + 돌 파편을 순환하고,
체력 50% 이하 「원소 융합」에서는 두 속성을 동시에 쓰며 속성 골렘을 소환합니다.

---

## 폴더 구조

```
project.godot                  ← Autoload, 입력맵, 물리 레이어 이름, 픽셀 필터, 시작 씬(타이틀)
assets/sprites/…               ← 플레이스홀더 도트 그래픽 (tools/generate_sprites.py 로 생성)
                                  characters / weapons / shields / helmets / armors / gems / projectiles /
                                  effects / items / world(텔레포트·보스문·상자·모닥불) / tiles / ui(타이틀 배경)
data/
  weapons/ shields/ helmets/ armors/ gems/*.tres   ← 장비 데이터
  stages/stage_1~3.tres        ← 스테이지 구성 (몬스터·보스·바닥·처치 목표)
scenes/
  title/title.tscn             ← 타이틀 (난이도 선택 · 조작 안내)
  main/main.tscn               ← 게임 월드 (야영지 · 사냥터 · 보스방)
  player/ projectile/ enemies/
  world/pickup, shop_keeper, portal, boss_gate, chest
  ui/hud, shop_ui, inventory_ui
scripts/
  autoload/game_manager.gd     ← Autoload "GameManager" (class_name 없음!)
  core/  layers.gd, elements.gd, floating_text.gd
  fx/    fx.gd (파티클·빛·충격파 static 헬퍼), aoe_strike.gd (예고 장판)
  data/  item_data.gd (공통) / weapon_data / shield_data / helmet_data / armor_data / gem_data / stage_data / item_db
  player/ player.gd, attack_controller.gd (Node), guard_controller.gd (Node)
  projectile/ projectile_spec.gd, projectile.gd, projectile_pool.gd
  enemies/ enemy.gd (기반) + slime, goblin, boss_slime_king, hellhound, orc, boss_hell_gatekeeper, golem, boss_archeon
  world/ interactable.gd (상호작용 공통) → shop_keeper, portal, boss_gate, chest
         room.gd (벽·바닥을 코드로 만드는 방), pickup.gd, stage_manager.gd, campfire.gd
  ui/    hud.gd, shop_ui.gd, inventory_ui.gd, item_row.gd (장비 한 줄 UI 헬퍼), screen_fade.gd
  title/ title.gd
  main/  main.gd
tests/smoke_test.tscn/.gd      ← 헤드리스 통합 테스트
tools/generate_sprites.py      ← 도트 그래픽 생성기 (Pillow)
```

---

## 씬 트리 & 스크립트 부착 위치

### `scenes/title/title.tscn`

```
Title (Control, 전체화면)                ← title.gd
├─ Background (TextureRect, title_bg.png, Keep Aspect Covered)   ← 전사 vs 몬스터 일러스트
├─ Shade (ColorRect)                     (+ 코드로 추가: 피어오르는 불티 CPUParticles2D)
├─ TitleBox: %TitleLabel "크루세이더", SubLabel
├─ %DifficultyPanel: 「난이도 선택」 %NormalButton / %HardButton / %VeryHardButton, %DifficultyDesc
└─ %HelpPanel (숨김): %HelpTitle, %KeyGrid(키 | 설명), %FlowLabel(진행 방법), %BackButton, %StartButton
```

### `scenes/main/main.tscn`

```
Main (Node2D)                          ← main.gd (사망 시 R 재시작 / T 타이틀)
├─ Rooms
│  ├─ CampRoom  (Node2D, room.gd, (0,0),    640x400) └ ShopRug
│  ├─ FieldRoom (Node2D, room.gd, (0,1200), 960x640)
│  └─ BossRoom  (Node2D, room.gd, (0,2400), 720x440, 어두운 바닥)
├─ Markers: CampSpawn / FieldSpawn / BossArrival / BossSpawn / ChestSpot (Marker2D)
├─ Entities (Node2D, y_sort_enabled)
│  ├─ ShopKeeper        (야영지)       ← shop_keeper.gd (Interactable)
│  ├─ Campfire          (야영지)       ← campfire.gd
│  ├─ FieldPortal       (야영지, 파랑)  ← portal.gd  "[E] 사냥터로 이동"
│  ├─ CampPortal        (사냥터, 초록)  ← portal.gd  "[E] 야영지로 귀환"
│  ├─ BossGate          (사냥터 북쪽)   ← boss_gate.gd 봉인/해방
│  ├─ NextStagePortal   (보스방, 금색)  ← portal.gd  보스 토벌 후 등장
│  └─ Player
├─ ProjectilePool (Node)
├─ HUD / ShopUI / InventoryUI (CanvasLayer 인스턴스)
├─ ScreenFade (CanvasLayer)            ← screen_fade.gd 텔레포트 화면 전환
└─ StageManager (Node)                 ← stage_manager.gd (방·마커·텔레포트·보스문·스테이지 데이터 지정)
```

### `scenes/player/player.tscn`

```
Player (CharacterBody2D, motion_mode=Floating)   ← player.gd
├─ Shadow, BodySprite (Sprite2D)
│  ├─ ArmorSprite (Sprite2D)          ← 갑옷 worn_texture
│  └─ HelmetSprite (Sprite2D)         ← 투구 worn_texture
├─ CollisionShape2D
├─ WeaponPivot (Node2D, 마우스 방향 회전)
│  ├─ SwingPivot ├ WeaponSprite ├ BowString(Line2D) └ NockedArrow
│  ├─ SwingFx, ShieldSprite, Muzzle(Marker2D), ChargeOrb
├─ ChantLabel (Label)
├─ AttackController (Node), GuardController (Node)
└─ Camera2D                            ← 방을 옮길 때 set_camera_bounds() 로 경계 변경
```

### 월드 오브젝트 (`scenes/world/`)

```
Portal (Area2D) ← portal.gd        : Sprite2D(소용돌이) + CollisionShape2D   (+ 빛·파티클은 코드)
BossGate (Area2D) ← boss_gate.gd   : Sprite2D(봉인/해방 텍스처) + CollisionShape2D (+ 진행도 라벨)
Chest (Area2D) ← chest.gd          : Sprite2D(닫힘/열림) + CollisionShape2D
ShopKeeper (Area2D) ← shop_keeper.gd
```
모두 `Interactable` 을 상속: 범위 안에서 `[E]` → `_interact()` / `interacted` 시그널. 안내 문구(Hint)는 자동 생성.

### UI

```
HUD (CanvasLayer)  ← hud.gd
├─ StatusPanel: HP / DASH / GUARD (TextureProgressBar), 골드
├─ TopCenter: %StageLabel("[하드] STAGE 1 · 초록 들판"), %LocationLabel("사냥터"), %ProgressLabel("보스방 해방까지 처치 3 / 12"), %BossBox
├─ %Hotbar (아래 가운데): 무기 3칸(1/2/3) | 방패·투구·갑옷 | 보석 3칸   ← 코드로 생성
└─ %NoticeLabel, ControlsHint, %GameOver

InventoryUI (CanvasLayer, Always)  ← inventory_ui.gd
└─ Panel: %WeaponSlots / %ArmorSlots / %GemSlots (칸 클릭 = 해제), %Stats, %BagList(장착/해제), %InvDetail

ShopUI (CanvasLayer, Always)  ← shop_ui.gd
└─ Panel: %BuyList(구매, 등급 배경·스테이지 잠금) | %InventoryList(장착 / 판매), %Detail
```

---

## ⚠️ Node vs Node2D – "Function not found in base self" 를 원천 차단한 방법

`get_global_mouse_position()`, `global_position`, `to_local()`, `get_world_2d()` 등은 **CanvasItem / Node2D 의 함수**입니다.

| 스크립트 | 상속 | 위치/마우스 함수 사용 |
| --- | --- | --- |
| `player.gd` | CharacterBody2D | ✅ 여기서만 `get_global_mouse_position()` 호출 |
| `attack_controller.gd`, `guard_controller.gd` | **Node** | ❌ `player.get_aim_direction()` 등 **타입이 지정된 Player 참조**로만 |
| `stage_manager.gd` | **Node** | ❌ `Room.get_bounds()`, `Marker2D.global_position`, `entities_root.to_local()` 처럼 Node2D 참조로만 |
| `projectile_pool.gd`, `game_manager.gd` | **Node** | ❌ 데이터만 다룸 |
| `fx.gd`, `item_db.gd`, `item_row.gd`, `elements.gd` | static 헬퍼 | ❌ 위치는 인자로 받음 |
| `room.gd`, `interactable.gd` 계열, `enemy.gd` 계열, `projectile.gd`, `pickup.gd`, `aoe_strike.gd` | Node2D / Area2D | ✅ |

- 모든 참조가 **정적 타입**이라 잘못된 호출은 에디터에서 즉시 빨간 줄로 잡힙니다.
- 충돌 콜백 안의 물리 상태 변경(`monitoring`, Area2D 추가 등)은 전부 `set_deferred` / `call_deferred`.
- 타입이 지정된 배열(`Array[WeaponData]` 등)에 다른 타입을 넣어 검색하지 않도록 종류를 먼저 확인합니다.
- GDScript 경고를 전부 **에러로 취급**하는 설정에서도 모든 스크립트가 통과합니다.

---

## 데이터 흐름 (시그널)

```
[좌클릭] AttackController ─ 근접: intersect_shape → 부채꼴 안 Enemy.take_damage()
                         └ 활/지팡이: 시위·영창 → ProjectilePool.spawn(ProjectileSpec)
              데미지 = GameManager.roll_weapon_damage(무기)  ← 보석 치명타·공격력 반영
[우클릭] GuardController → Player.take_hit() → HitResult (방어력 = 방패+투구+갑옷)
[E]      Interactable ─ ShopKeeper → GameManager.request_shop → ShopUI
                     ├ Portal / BossGate.interacted → StageManager (ScreenFade 로 방 이동)
                     └ Chest.opened → StageManager → 다음 등급 장비 Pickup
[I]      InventoryUI → GameManager.equip_item / unequip_item
Enemy.died → StageManager → 골드/장비 Pickup, 처치 수 → BossGate.open()

GameManager signals ─▶ HUD / ShopUI / InventoryUI / Player(무기·방패·투구·갑옷 그림)
  player_hp_changed, player_damaged, player_died, dash_cooldown_changed, guard_changed, guard_broken,
  gold_changed, inventory_changed, equipment_changed, weapon_equipped, shield_equipped,
  helmet_equipped, armor_equipped, stats_changed, stage_changed, location_changed,
  kill_progress_changed, boss_spawned, boss_hp_changed, boss_defeated, notice_requested, shop_open_requested
```

---

## 물리 레이어

| 레이어 | 이름 | 비트값 | 사용 |
| --- | --- | --- | --- |
| 1 | world | 1 | 방 벽, 상인 몸체 |
| 2 | player | 2 | Player |
| 3 | enemy | 4 | Enemy (Area2D) |
| 4 | player_projectile | 8 | 플레이어 투사체 |
| 5 | enemy_projectile | 16 | 적 탄 |
| 6 | pickup | 32 | 드랍 아이템 |

---

## 확장 가이드

- **새 장비**: `data/<종류>/` 의 `.tres` 복제 → 수치·아이콘 수정 → `item_db.gd` 의 `ITEM_PATHS` 에 추가 →
  상점 `ShopKeeper.stock_ids` / 몬스터 `item_drop_ids` 에 id 추가. 등급만 바꿔도 배경색·해금 스테이지·이펙트·상자 등장 등급이 자동 적용.
- **새 몬스터**: `extends Enemy` 스크립트에서 `_get_move_velocity()` / `_update_visual()` 오버라이드.
  `shoot()`, `telegraph_strike()`, `request_summon()` 헬퍼 사용.
- **새 스테이지**: `StageData` (.tres) 를 만들고 `main.tscn` 의 `StageManager.stages` 에 추가.
- **새 상호작용 오브젝트**: `extends Interactable` 후 `_interact()` 오버라이드.
- **방 크기/배치**: `main.tscn` 의 `Rooms/*` 의 `size`, `Markers/*` 위치만 바꾸면 벽·카메라 경계·스폰 영역이 따라갑니다.

---

## 그래픽 교체

`assets/sprites/` 의 PNG 는 `tools/generate_sprites.py` 로 만든 플레이스홀더입니다. 같은 파일명으로 덮어쓰면 바로 반영됩니다.
투구 `*_worn.png`, 갑옷 `*_worn.png` 는 `player.png` 와 같은 16x16 좌표에 해당 부위만 그린 그림입니다.
타이틀 배경은 `assets/sprites/ui/title_bg.png` (320x180, 화면에 맞게 확대).

---

## 테스트

모든 시스템을 실제로 구동해 검증하는 헤드리스 통합 테스트 (103개 항목):
타이틀·난이도 / 이동·대시 / 근접 / 무기 칸 3개(중복 장착 없음) / 활 시위 / 지팡이 영창 / 스테이지별 드랍 등급 /
보석 치명타 / 등급 이펙트 / 가드·퍼펙트 가드 / 인벤토리 / 상점 구매·판매·잠금·갑옷 /
야영지 → 사냥터 → 보스문 해방 → 보스방 → 상자(레어/전설) → 다음 스테이지 / 2·3스테이지 보스 패턴 / 난이도 배율 / 사망·재시작

```bash
godot --headless --path . res://tests/smoke_test.tscn
# → ALL TESTS PASSED (exit code 0)
```

> `-s` 옵션으로 스크립트를 직접 실행하면 Autoload(GameManager) 보다 먼저 컴파일되어 `Identifier not found: GameManager` 가 나므로 반드시 **씬으로** 실행합니다.
