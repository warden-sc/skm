extends Node
## 전역 게임 상태 관리자 (Autoload 이름: GameManager)
##
## - 난이도 / 플레이어 체력 / 대시 쿨타임 / 가드 게이지 / 골드 / 인벤토리 / 장비 칸 / 회복 포션 / 스테이지 진행 데이터를 보관합니다.
## - 값이 바뀌면 항상 시그널을 발행하므로 HUD/상점/인벤토리 UI 는 시그널만 구독하면 실시간으로 갱신됩니다.
##
## 장비 칸
##   무기 3칸   : 검(단검 포함) / 활 / 지팡이 — 종류별로 1개씩. 1/2/3 으로 사용할 무기를 고릅니다.
##              레어 등급 이상 무기에는 액티브 스킬이 있어 Q 로 씀 (무기마다 대기시간 따로 — skill_cooldowns)
##   방어구 4칸 : 방패 / 투구 / 갑옷 / 신발(방어력 + 이동 속도)
##   장신구 3칸 : 팔찌(치명타 피해·방어력 관통) / 반지(치명타 확률·공격력) / 펜던트(최대 체력·체력 재생)
##
## ⚠️ Autoload 스크립트에는 class_name 을 붙이지 않습니다.
##    (붙이면 "Class 'GameManager' hides an autoload singleton" 에러가 납니다.)

# --- 플레이어 ---
signal player_hp_changed(current: int, max_hp: int)
signal player_damaged(amount: int)
signal player_died
signal dash_cooldown_changed(remaining: float, total: float)
signal guard_changed(current: float, max_guard: float)
signal guard_broken

# --- 경제 / 장비 ---
signal gold_changed(gold: int)
## 보유 아이템 목록이 바뀌었을 때 (획득 / 구매 / 판매)
signal inventory_changed
## 장비 칸 중 하나라도 바뀌었을 때
signal equipment_changed
## 현재 손에 든 무기가 바뀌었을 때
signal weapon_equipped(weapon: WeaponData)
signal shield_equipped(shield: ShieldData)
signal helmet_equipped(helmet: HelmetData)
signal armor_equipped(armor: ArmorData)
signal boots_equipped(boots: BootsData)
## 방어력 / 최대 체력 / 치명타 등 파생 능력치가 바뀌었을 때
signal stats_changed
## 회복 포션 개수가 바뀌었을 때 / 포션을 마셨을 때
signal potions_changed
signal potion_used(potion: PotionData, healed: int)
## 플레이어 상태 이상 문구 (화상 / 점액 바닥 / 감속). 없으면 빈 문자열
signal player_status_changed(text: String)
## 플레이어가 공격을 내보낼 때 (도플갱어가 따라 함)
signal player_attacked(weapon: WeaponData, aim: Vector2)

# --- 스테이지 / 보스 ---
signal stage_changed(stage: int)
signal location_changed(location_name: String)
signal kill_progress_changed(kills: int, target: int)
signal boss_spawned(boss_name: String, max_hp: int)
signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated
## 마지막 스테이지까지 모두 클리어
signal game_cleared

# --- UI ---
signal notice_requested(text: String, color: Color)
signal shop_open_requested(shop_name: String, stock_ids: Array)
## 신화 사용 아이템을 썼을 때 (Player 가 효과를 냄)
signal relic_used(relic: RelicData)
## 인벤토리에서 장비를 버림 → StageManager 가 용사 발밑에 주울 수 있는 장비로 떨어뜨림 (멀티플레이 참가자는 방장에게 보냄)
signal item_dropped(item: ItemData, by_peer: int, at_global: Vector2)

enum Difficulty { NORMAL, HARD, VERY_HARD }
enum WeaponSlot { MELEE, BOW, STAFF }

## 난이도별 몬스터 배율
const DIFFICULTY_INFO := {
	Difficulty.NORMAL: {
		"name": "노멀", "color": Color(0.55, 1.0, 0.6),
		"enemy_hp": 1.0, "enemy_defense": 0, "enemy_damage": 0.7, "enemy_speed": 1.0, "gold": 1.0, "max_alive_bonus": 0, "hit_cap": 0.35,
		"desc": "처음 모험을 떠나는 분께 추천합니다. 몬스터 공격력 x0.7 · 한 번에 최대 체력의 35% 넘게 잃지 않음",
	},
	Difficulty.HARD: {
		"name": "하드", "color": Color(1.0, 0.75, 0.35),
		"enemy_hp": 1.3, "enemy_defense": 1, "enemy_damage": 1.1, "enemy_speed": 1.1, "gold": 1.3, "max_alive_bonus": 2, "hit_cap": 0.5,
		"desc": "몬스터 체력 x1.3 · 공격력 x1.1 · 방어력 +1 · 골드 x1.3 · 한 번에 최대 체력의 50%까지",
	},
	Difficulty.VERY_HARD: {
		"name": "베리하드", "color": Color(1.0, 0.35, 0.4),
		"enemy_hp": 1.8, "enemy_defense": 3, "enemy_damage": 1.5, "enemy_speed": 1.2, "gold": 1.7, "max_alive_bonus": 4, "hit_cap": 0.75,
		"desc": "몬스터 체력 x1.8 · 공격력 x1.5 · 방어력 +3 · 더 많고 빠름 · 골드 x1.7 · 한 번에 최대 체력의 75%까지",
	},
}
const WEAPON_SLOT_NAMES := ["검", "활", "지팡이"]
const ACCESSORY_SLOT_NAMES := ["팔찌", "반지", "펜던트"]

const STARTING_ITEM_IDS: Array[StringName] = [&"rusty_sword", &"wooden_shield"]
## 시작 시 지급하는 포션 { id: 개수 }
const STARTING_POTIONS := {&"small_potion": 2}
## 포션 종류별 최대 보유 개수
const POTION_MAX_STACK := 5
const BASE_MAX_HP := 1000
const STARTING_GOLD := 100

var difficulty: Difficulty = Difficulty.NORMAL

var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var is_player_dead: bool = false
var player_status: String = ""

var dash_cooldown_remaining: float = 0.0
var dash_cooldown_total: float = 1.0

var guard: float = 0.0
var max_guard: float = 0.0

var gold: int = 0
## 가지고 있는 모든 장비 (장착 여부와 무관)
var items: Array[ItemData] = []
## 무기 칸 3개 (WeaponSlot 순서). 빈 칸은 null
var weapon_slots: Array[WeaponData] = [null, null, null]
var active_weapon_slot: int = WeaponSlot.MELEE
## 지금 손에 든 무기 (= weapon_slots[active_weapon_slot])
var equipped_weapon: WeaponData
var equipped_shield: ShieldData
var equipped_helmet: HelmetData
var equipped_armor: ArmorData
var equipped_boots: BootsData
## 체력 재생 누적값 (1 이 쌓일 때마다 1 회복)
var _regen_buffer: float = 0.0
## 장신구 칸 3개 (AccessoryData.SlotType 순서: 팔찌 / 반지 / 펜던트). 빈 칸은 null
var accessory_slots: Array[AccessoryData] = [null, null, null]
## 회복 포션 보유 개수 { 포션 id: 개수 } (소모품이라 items 와 따로 보관)
var potions: Dictionary = {}
## [G] 로 고른 포션 (&"" = 자동: 잃은 체력에 맞는 것). 고른 포션이 다 떨어지면 자동으로
var selected_potion: StringName = &""
## 플레이어 쪽 공격력 배율 (반지 공격력 보너스 반영)
var damage_multiplier: float = 1.0
## 신앙 게이지로 오르는 공격력 (37스테이지 아스타로트, Player 가 매 프레임 갱신)
var faith_damage_bonus: float = 0.0

var stage: int = 1
var stage_name: String = ""
var location_name: String = ""
var kills: int = 0
var kill_target: int = 0
## 보스방 해방 시련 진행 글 (처치 시련이면 "")
var gate_text: String = ""
var is_boss_active: bool = false

# --- 엔딩용 기록 ---
## 모든 스테이지의 보스를 쓰러뜨렸는지
var is_game_cleared: bool = false
## 히든 던전: 30~35스테이지 사냥터에 숨겨진 「고대 용의 비늘」을 주운 스테이지 번호
const DRAGON_SCALE_STAGES: Array[int] = [30, 31, 32, 33, 34, 35]
var dragon_scales: Array[int] = []
## 히든 보스(고대 드래곤 아르케)를 쓰러뜨렸는지
var hidden_cleared: bool = false
## 100스테이지 보스를 쓰러뜨리면 true — 신화 장비의 봉인이 풀려 착용 가능
var mythic_unlocked: bool = false
## 켜진 세트 효과 합계 (ItemSets.total_bonus, 장비가 바뀔 때마다 다시 계산)
var _set_bonus: Dictionary = {}
## 신화 사용 아이템 (원초의 불꽃 · 최후의 나팔)과 남은 대기시간 { id: 초 }
var relics: Array[RelicData] = []
var relic_cooldowns: Dictionary = {}
## 개수가 있는 사용 아이템(원초의 불꽃)의 남은 개수 { id: 개 }
var relic_charges: Dictionary = {}
## 무기 액티브 스킬(Q) 남은 대기시간 { 무기 id: 초 }
var skill_cooldowns: Dictionary = {}
## 잠시 붙는 효과 (포션 · 원초의 불꽃) { 이름: {"effects": {...}, "left": 초, "total": 초} }
##   effects: attack(공격력 +%) · reduction(받는 피해 -%) · regen_pct(초당 최대 체력 %) · move(이속 +%) · burn_on_hit(맞힌 적 화상 비율) · burn_immune
var _buffs: Dictionary = {}
var _buff_regen_carry: float = 0.0
## 장비가 아닌 보물 (예: 49스테이지 프로메테우스의 「프로메테우스의 불씨」). 장비 조정 때 쓰임을 정할 예정
const KEY_ITEM_NAMES := {&"prometheus_ember": "프로메테우스의 불씨"}
var key_items: Array[StringName] = []
## 헤르메스(40스테이지)가 훔쳐 간 무기 — 돌려받기 전까지 무기 칸·가방에서 빠짐
var stolen_weapon: WeaponData
## 이번 모험에서 처치한 몬스터 수 (보스·소환된 졸개 포함)
var total_kills: int = 0
## 이번 모험의 플레이 시간(초). 일시정지(상점·인벤토리) 중에는 늘지 않음
var play_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_game()


## 타이틀에서 난이도를 고르고 새 게임 시작
## 플레이어가 지은 용사의 이름 (대본의 「용사」가 이 이름으로 바뀜). 새 게임에서도 그대로 유지
const DEFAULT_HERO_NAME := "용사"
const HERO_NAME_MAX := 12
var hero_name: String = DEFAULT_HERO_NAME


func set_hero_name(new_name: String) -> void:
	new_name = new_name.strip_edges().left(HERO_NAME_MAX)
	hero_name = new_name if new_name != "" else DEFAULT_HERO_NAME


func start_new_game(new_difficulty: Difficulty) -> void:
	difficulty = new_difficulty
	reset_game()
	Story.reset()  # 새 모험에서는 대사를 처음부터


## 새 게임 / 재시작 시 모든 데이터를 초기화합니다. (난이도는 유지)
func reset_game() -> void:
	max_hp = BASE_MAX_HP
	hp = max_hp
	is_player_dead = false
	player_status = ""
	dash_cooldown_remaining = 0.0
	gold = STARTING_GOLD
	damage_multiplier = 1.0
	faith_damage_bonus = 0.0
	stage = 1
	stage_name = ""
	location_name = ""
	kills = 0
	kill_target = 0
	gate_text = ""
	is_boss_active = false
	is_game_cleared = false
	dragon_scales.clear()
	hidden_cleared = false
	mythic_unlocked = false
	_set_bonus = {}
	relics.clear()
	relic_cooldowns.clear()
	relic_charges.clear()
	skill_cooldowns.clear()
	_buffs.clear()
	_buff_regen_carry = 0.0
	stolen_weapon = null
	key_items.clear()
	total_kills = 0
	play_time = 0.0
	items.clear()
	weapon_slots = [null, null, null]
	accessory_slots = [null, null, null]
	active_weapon_slot = WeaponSlot.MELEE
	equipped_weapon = null
	equipped_shield = null
	equipped_helmet = null
	equipped_armor = null
	equipped_boots = null
	_regen_buffer = 0.0
	for item_id in STARTING_ITEM_IDS:
		var item := ItemDB.get_item(item_id)
		add_item(item)
		equip_item(item)
	potions = STARTING_POTIONS.duplicate()
	selected_potion = &""
	_recalculate_stats()
	hp = max_hp
	emit_all()


## 현재 값 전체를 한 번에 재발행 (UI 초기 동기화용)
func emit_all() -> void:
	player_hp_changed.emit(hp, max_hp)
	dash_cooldown_changed.emit(dash_cooldown_remaining, dash_cooldown_total)
	guard_changed.emit(guard, max_guard)
	gold_changed.emit(gold)
	inventory_changed.emit()
	equipment_changed.emit()
	weapon_equipped.emit(equipped_weapon)
	shield_equipped.emit(equipped_shield)
	helmet_equipped.emit(equipped_helmet)
	armor_equipped.emit(equipped_armor)
	boots_equipped.emit(equipped_boots)
	stats_changed.emit()
	potions_changed.emit()
	stage_changed.emit(stage)
	kill_progress_changed.emit(kills, kill_target)


# ============================================================ 저장 / 불러오기 (Profile 이 파일로 씀)
## 튜토리얼 중이면 true — 저장 불가, 끝나면 타이틀로
var tutorial_mode: bool = false


## 지금 저장할 수 있는지 (살아 있고 · 튜토리얼이 아니고 · 엔딩 전)
func can_save() -> bool:
	return not is_player_dead and not tutorial_mode and not is_game_cleared and not Net.is_online()


static func _ids(list: Array) -> Array:
	return list.map(func(it: ItemData) -> String: return String(it.id) if it != null and not it.admin_only else "")  # 운영자 장비는 저장하지 않음


## 저장할 내용 — 장비는 id 로. 불러오면 그 스테이지 야영지에서 체력을 가득 채운 채 이어함
func to_save_data() -> Dictionary:
	var potion_counts := {}
	for potion_id in potions:
		potion_counts[String(potion_id)] = int(potions[potion_id])
	var bag := items.duplicate()
	if stolen_weapon != null and not bag.has(stolen_weapon):
		bag.append(stolen_weapon)  # 헤르메스가 훔쳐 간 무기는 불러올 때 돌려줌
	return {
		"version": 1,
		"hero_name": hero_name,
		"difficulty": int(difficulty),
		"stage": stage,
		"gold": gold,
		"items": _ids(bag),
		"weapon_slots": _ids(weapon_slots),
		"active_weapon_slot": active_weapon_slot,
		"accessory_slots": _ids(accessory_slots),
		"shield": _ids([equipped_shield])[0],
		"helmet": _ids([equipped_helmet])[0],
		"armor": _ids([equipped_armor])[0],
		"boots": _ids([equipped_boots])[0],
		"potions": potion_counts,
		"selected_potion": String(selected_potion),
		"relics": relics.map(func(r: RelicData) -> String: return String(r.id)),
		"relic_charges": relic_charges.duplicate(),
		"dragon_scales": dragon_scales.duplicate(),
		"hidden_cleared": hidden_cleared,
		"mythic_unlocked": mythic_unlocked,
		"faith_damage_bonus": faith_damage_bonus,
		"key_items": key_items.map(func(k: StringName) -> String: return String(k)),
		"total_kills": total_kills,
		"play_time": play_time,
		"story_played": Story.get_played_marks(),
	}


## 저장 내용 적용 (모르는 id 는 건너뜀). 성공하면 true
func apply_save_data(data: Dictionary) -> bool:
	if not data.has("stage") or not data.has("items"):
		return false
	difficulty = clampi(int(data.get("difficulty", 0)), 0, Difficulty.size() - 1) as Difficulty
	reset_game()
	items.clear()
	weapon_slots = [null, null, null]
	equipped_shield = null
	for item_id in data.get("items", []):
		if ItemDB.has_item(StringName(item_id)):
			var item := ItemDB.get_item(StringName(item_id))
			if not (item is PotionData) and not owns_item(item.id):
				items.append(item)
	stage = maxi(1, int(data.get("stage", 1)))
	gold = maxi(0, int(data.get("gold", 0)))
	dragon_scales.assign((data.get("dragon_scales", []) as Array).map(func(v: Variant) -> int: return int(v)))
	hidden_cleared = bool(data.get("hidden_cleared", false))
	mythic_unlocked = bool(data.get("mythic_unlocked", false))
	faith_damage_bonus = float(data.get("faith_damage_bonus", 0.0))
	key_items.assign((data.get("key_items", []) as Array).map(func(v: Variant) -> StringName: return StringName(v)))
	total_kills = int(data.get("total_kills", 0))
	play_time = float(data.get("play_time", 0.0))
	potions = {}
	selected_potion = StringName(data.get("selected_potion", ""))
	var saved_potions: Dictionary = data.get("potions", {})
	for potion_id in saved_potions:
		if ItemDB.has_item(StringName(potion_id)):
			potions[StringName(potion_id)] = clampi(int(saved_potions[potion_id]), 0, 99)
	relics.clear()
	for relic_id in data.get("relics", []):
		var relic := ItemDB.get_relic(StringName(relic_id)) if ItemDB.has_item(StringName(relic_id)) else null
		if relic != null:
			relics.append(relic)
	relic_charges.clear()
	var saved_charges: Dictionary = data.get("relic_charges", {})
	for relic in relics:
		if relic.charges > 0:
			relic_charges[relic.id] = int(saved_charges.get(String(relic.id), saved_charges.get(relic.id, relic.charges)))
	for list_key in ["weapon_slots", "accessory_slots"]:
		for item_id in data.get(list_key, []):
			_equip_saved(String(item_id))
	for key in ["shield", "helmet", "armor", "boots"]:
		_equip_saved(String(data.get(key, "")))
	if weapon_slots.all(func(w: WeaponData) -> bool: return w == null):
		var fallback := get_weapons()
		if fallback.is_empty():
			add_item(ItemDB.get_item(STARTING_ITEM_IDS[0]))
			fallback = get_weapons()
		equip_item(fallback[0])
	var slot := int(data.get("active_weapon_slot", 0))
	if slot >= 0 and slot < weapon_slots.size() and weapon_slots[slot] != null:
		_set_active_weapon_slot(slot)
	Story.set_played_marks(data.get("story_played", []))
	_recalculate_stats()
	hp = max_hp
	emit_all()
	return true


func _equip_saved(item_id: String) -> void:
	if item_id != "" and owns_item(StringName(item_id)):
		var item := ItemDB.get_item(StringName(item_id))
		if not item.is_sealed():
			equip_item(item)


func get_difficulty_info() -> Dictionary:
	var hp_mult := Net.get_enemy_hp_multiplier()
	if hp_mult == 1.0:
		return DIFFICULTY_INFO[difficulty]
	# 멀티플레이: 같이 하는 사람이 많을수록 몬스터 체력이 늘어남
	var info: Dictionary = DIFFICULTY_INFO[difficulty].duplicate()
	info["enemy_hp"] = float(info["enemy_hp"]) * hp_mult
	return info


## 멀티플레이 부활 (동료가 살아 있으면 야영지에서, 전멸하면 다 같이)
func revive_player() -> void:
	is_player_dead = false
	hp = max_hp
	player_hp_changed.emit(hp, max_hp)


func get_difficulty_name() -> String:
	return get_difficulty_info()["name"]


# ============================================================ 체력
## 몬스터의 공격 한 번으로 잃을 수 있는 최대 체력 (난이도별 — 노멀 35% · 하드 50% · 베리하드 75%). 한 방에 쓰러지지 않게
## 보스 기믹의 「최대 체력 비율 피해」(take_unblockable_hit 등)는 이 상한과 상관없이 그대로
func get_hit_cap() -> int:
	return maxi(1, roundi(max_hp * float(get_difficulty_info().get("hit_cap", 1.0))))


func damage_player(amount: int) -> void:
	if is_player_dead or amount <= 0 or is_invincible():
		return
	var reduction := get_damage_reduction()
	if reduction > 0.0:
		amount = maxi(1, roundi(amount * (1.0 - reduction)))
	hp = maxi(hp - amount, 0)
	player_damaged.emit(amount)
	player_hp_changed.emit(hp, max_hp)
	if hp == 0:
		is_player_dead = true
		player_died.emit()


## 무적: 운영자 장비 착용 중 · 개발자의 보호막
func is_invincible() -> bool:
	return AdminGear.is_admin_armor(equipped_armor) or get_buff_value("invincible") > 0.0


func heal_player(amount: int) -> void:
	if is_player_dead or amount <= 0:
		return
	hp = mini(hp + amount, max_hp)
	player_hp_changed.emit(hp, max_hp)


func set_player_status(text: String) -> void:
	if text == player_status:
		return
	player_status = text
	player_status_changed.emit(text)


func heal_full() -> void:
	heal_player(max_hp)


# ============================================================ 대시 / 가드
## Player 가 매 프레임 호출. 값이 실제로 변했을 때만 시그널을 보냅니다.
func set_dash_cooldown(remaining: float, total: float) -> void:
	remaining = maxf(remaining, 0.0)
	total = maxf(total, 0.001)
	if is_equal_approx(remaining, dash_cooldown_remaining) and is_equal_approx(total, dash_cooldown_total):
		return
	dash_cooldown_remaining = remaining
	dash_cooldown_total = total
	dash_cooldown_changed.emit(dash_cooldown_remaining, dash_cooldown_total)


func is_dash_ready() -> bool:
	return dash_cooldown_remaining <= 0.0


## GuardController 가 호출. 값이 실제로 변했을 때만 시그널을 보냅니다.
func set_guard(current: float, maximum: float) -> void:
	current = clampf(current, 0.0, maximum)
	if is_equal_approx(current, guard) and is_equal_approx(maximum, max_guard):
		return
	guard = current
	max_guard = maximum
	guard_changed.emit(guard, max_guard)


func report_guard_broken() -> void:
	guard_broken.emit()


# ============================================================ 능력치
## 방패 + 투구 + 갑옷 + 신발 방어력 합계. 모든 피해에서 이만큼 빠집니다 (최소 1은 들어감).
## 화상 같은 지속 피해도 방어력이 높을수록 덜 들어옵니다 (get_dot_multiplier).
func get_total_defense() -> int:
	var total := 0
	if equipped_shield != null:
		total += equipped_shield.defense
	if equipped_helmet != null:
		total += equipped_helmet.defense
	if equipped_armor != null:
		total += equipped_armor.defense
	if equipped_boots != null:
		total += equipped_boots.defense
	total += roundi(get_set_value("defense"))
	return roundi(total * (1.0 + get_buff_value("defense_pct")))  # 운영자의 가호


## 신발로 더해지는 이동 속도 (0.1 = +10%)
func get_move_speed_bonus() -> float:
	return (equipped_boots.move_bonus if equipped_boots != null else 0.0) + get_set_value("move") + get_buff_value("move")


## 신발로 줄어드는 대시 대기시간 비율
func get_dash_cooldown_reduction() -> float:
	return clampf(equipped_boots.dash_cooldown_reduction if equipped_boots != null else 0.0, 0.0, 0.8)


## 세트 효과 · 잠깐 붙는 효과로 줄어드는 받는 피해 비율
func get_damage_reduction() -> float:
	var normal := clampf(get_set_value("reduction") + get_buff_value("reduction"), 0.0, 0.7)
	var admin := clampf(get_buff_value("admin_reduction"), 0.0, 0.95)  # 운영자의 가호 (따로 곱함)
	return 1.0 - (1.0 - normal) * (1.0 - admin)


## 멀티버스의 주인에게 주는 피해 보너스 (신화의 유산 10세트 「억제의 권능」)
func get_master_damage_bonus() -> float:
	return get_set_value("master_damage")


# ============================================================ 세트
## 지금 장착한 모든 장비 (무기 칸 3 + 방패 · 투구 · 갑옷 · 신발 + 장신구 3)
func get_equipped_items() -> Array[ItemData]:
	var list: Array[ItemData] = []
	for item in weapon_slots:
		if item != null:
			list.append(item)
	for item in [equipped_shield, equipped_helmet, equipped_armor, equipped_boots]:
		if item != null:
			list.append(item as ItemData)
	for item in accessory_slots:
		if item != null:
			list.append(item)
	return list


## { set_id: 장착 개수 }
func get_set_counts() -> Dictionary:
	return ItemSets.count_equipped(get_equipped_items())


func get_set_value(key: String) -> float:
	return float(_set_bonus.get(key, 0.0))


## 펜던트로 얻는 초당 체력 재생
func get_hp_regen() -> float:
	var total := get_set_value("regen")
	for accessory in accessory_slots:
		if accessory != null:
			total += accessory.hp_regen
	return total


## Player 가 매 프레임 호출. 재생량이 1 이상 쌓이면 회복
func tick_regen(delta: float) -> void:
	var regen := get_hp_regen()
	if regen <= 0.0 or is_player_dead or hp >= max_hp:
		_regen_buffer = 0.0
		return
	_regen_buffer += regen * delta
	if _regen_buffer >= 1.0:
		var amount := int(_regen_buffer)
		_regen_buffer -= amount
		heal_player(amount)


## 지속 피해(화상 등) 배율: 방어력 150 에서 절반, 높을수록 덜 들어옴
const DOT_DEFENSE_HALF := 150.0
## 포션 회복량 배율 (독 0.5 — 바실리스크 / 부패 0 — 헬리시온 / 성흔 -1 = 회복이 피해로 — 세라핀)
var potion_heal_multiplier: float = 1.0


func get_dot_multiplier() -> float:
	var defense := float(get_total_defense())
	return DOT_DEFENSE_HALF / (DOT_DEFENSE_HALF + maxf(defense, 0.0))


func get_bonus_max_hp() -> int:
	var total := roundi(get_set_value("max_hp"))
	if equipped_helmet != null:
		total += equipped_helmet.bonus_max_hp
	if equipped_armor != null:
		total += equipped_armor.bonus_max_hp
	for accessory in accessory_slots:
		if accessory != null:
			total += accessory.bonus_max_hp
	return total


## 반지로 더해지는 치명타 확률 (0.1 = +10%)
func get_crit_chance_bonus() -> float:
	var total := get_set_value("crit_chance")
	for accessory in accessory_slots:
		if accessory != null:
			total += accessory.crit_chance_bonus
	return total


## 팔찌로 더해지는 치명타 피해 배율
func get_crit_damage_bonus() -> float:
	var total := get_set_value("crit_damage")
	for accessory in accessory_slots:
		if accessory != null:
			total += accessory.crit_damage_bonus
	return total


## 반지로 더해지는 공격력 (0.1 = +10%)
func get_attack_bonus() -> float:
	var total := get_set_value("attack")
	for accessory in accessory_slots:
		if accessory != null:
			total += accessory.attack_bonus
	return total


## 팔찌로 더해지는 방어력 관통(방깍)
func get_armor_pen_bonus() -> int:
	var total := roundi(get_set_value("armor_pen"))
	for accessory in accessory_slots:
		if accessory != null:
			total += accessory.armor_pen
	return total


## 무기 + 팔찌를 합친 최종 방어력 관통
func get_armor_pen(weapon: WeaponData = null) -> int:
	if weapon == null:
		weapon = equipped_weapon
	var base := weapon.armor_pen if weapon != null else 0
	return base + get_armor_pen_bonus()


## 무기 + 반지를 합친 최종 치명타 확률
func get_crit_chance(weapon: WeaponData = null) -> float:
	if weapon == null:
		weapon = equipped_weapon
	var base := weapon.crit_chance if weapon != null else 0.0
	return minf(base + get_crit_chance_bonus(), 1.0)


## 장착 무기로 1타 데미지 굴리기 (반지·팔찌 반영). 결과에 방어력 관통("armor_pen")도 담아 줍니다.
func roll_weapon_damage(weapon: WeaponData) -> Dictionary:
	var roll := weapon.roll_damage(damage_multiplier * (1.0 + faith_damage_bonus + get_buff_value("attack")), get_crit_chance_bonus(), get_crit_damage_bonus())
	roll["armor_pen"] = get_armor_pen(weapon)
	return roll


func _recalculate_stats() -> void:
	_set_bonus = ItemSets.total_bonus(get_equipped_items())
	damage_multiplier = 1.0 + get_attack_bonus()
	var new_max := roundi((BASE_MAX_HP + get_bonus_max_hp()) * (1.0 + get_set_value("max_hp_pct") + get_buff_value("max_hp_pct")))
	if new_max != max_hp:
		var diff := new_max - max_hp
		max_hp = new_max
		# 늘어난 만큼은 현재 체력도 늘리고, 줄어들면 최대치에 맞춰 자름
		hp = clampi(hp + maxi(diff, 0), 1 if not is_player_dead else 0, max_hp)
		player_hp_changed.emit(hp, max_hp)
	stats_changed.emit()


# ============================================================ 골드
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func can_afford(price: int) -> bool:
	return gold >= price


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# ============================================================ 보유 아이템
func owns_item(item_id: StringName) -> bool:
	for item in items:
		if item.id == item_id:
			return true
	return false


func get_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for item in items:
		if item is WeaponData:
			result.append(item as WeaponData)
	return result


func get_shields() -> Array[ShieldData]:
	var result: Array[ShieldData] = []
	for item in items:
		if item is ShieldData:
			result.append(item as ShieldData)
	return result


func get_helmets() -> Array[HelmetData]:
	var result: Array[HelmetData] = []
	for item in items:
		if item is HelmetData:
			result.append(item as HelmetData)
	return result


func get_boots_list() -> Array[BootsData]:
	var result: Array[BootsData] = []
	for item in items:
		if item is BootsData:
			result.append(item as BootsData)
	return result


func get_armors() -> Array[ArmorData]:
	var result: Array[ArmorData] = []
	for item in items:
		if item is ArmorData:
			result.append(item as ArmorData)
	return result


func get_accessories() -> Array[AccessoryData]:
	var result: Array[AccessoryData] = []
	for item in items:
		if item is AccessoryData:
			result.append(item as AccessoryData)
	return result


## 새 장비를 가방에 추가. null 이거나 이미 가지고 있으면 false.
func add_item(item: ItemData) -> bool:
	if item is PotionData:
		return add_potion(item as PotionData, 1) > 0  # 포션은 개수로 보관
	if item == null or owns_item(item.id):
		return false
	items.append(item)
	inventory_changed.emit()
	return true


## 상점 구매: 골드 차감 + 가방 추가 + 자동 장착
func buy_item(item: ItemData) -> bool:
	if item is PotionData:
		return buy_potion(item as PotionData)
	if item == null or owns_item(item.id) or not can_afford(item.price):
		return false
	if stage < item.get_unlock_stage():
		return false
	spend_gold(item.price)
	add_item(item)
	equip_item(item)
	return true


## 장착 중이 아닌 장비만 팔 수 있습니다. 신화 장비는 팔 수 없음
func can_sell(item: ItemData) -> bool:
	return item != null and items.has(item) and not is_equipped(item) and not item.is_mythic() and not item.admin_only


## 상인에게 판매. 받은 골드를 반환 (실패하면 0)
func sell_item(item: ItemData) -> int:
	if not can_sell(item):
		return 0
	items.erase(item)
	var value := item.get_sell_value()
	add_gold(value)
	inventory_changed.emit()
	return value


## 버릴 수 있는 장비인지 (포션 · 사용 아이템은 안 됨, 장착 중이면 먼저 해제 — 마지막 무기는 못 버림)
func can_drop(item: ItemData) -> bool:
	if item == null or item is PotionData or item is RelicData or item.admin_only or not owns_item(item.id):
		return false
	if item is WeaponData and is_equipped(item) and _equipped_weapon_count() <= 1:
		return false
	return true


## 인벤토리에서 장비를 버림. 바닥에 떨어져서 나나 동료가 다시 주울 수 있음
func drop_item(item: ItemData, at_global: Vector2) -> bool:
	if not can_drop(item):
		if item is WeaponData:
			show_notice("무기를 하나는 장착하고 있어야 합니다.", Color(1.0, 0.6, 0.5))
		return false
	if is_equipped(item) and not unequip_item(item):
		return false
	items.erase(item)
	inventory_changed.emit()
	show_notice("버림: %s — 바닥에서 다시 주울 수 있음" % item.display_name, item.get_rarity_color())
	if Net.is_client():
		Net.request_drop(item.id, at_global)
	else:
		item_dropped.emit(item, Net.my_id(), at_global)
	return true


# ============================================================ 회복 포션
func get_potion_count(potion_id: StringName) -> int:
	return int(potions.get(potion_id, 0))


## [H] 로 마시는 포션 개수 (고대 용의 피 제외)
func get_total_potions() -> int:
	var total := 0
	for potion_id in potions:
		var potion := ItemDB.get_potion(potion_id)
		if potion != null and potion.auto_use:
			total += int(potions[potion_id])
	return total


## 보유 중인 포션 목록 (회복량 작은 순)
func get_owned_potions() -> Array[PotionData]:
	var result: Array[PotionData] = []
	for potion_id in potions:
		if int(potions[potion_id]) > 0:
			var potion := ItemDB.get_potion(potion_id)
			if potion != null:
				result.append(potion)
	result.sort_custom(func(a: PotionData, b: PotionData) -> bool: return a.get_heal(max_hp) < b.get_heal(max_hp))
	return result


## [H] 로 마실 포션: [G] 로 고른 것이 있으면 그것, 아니면(자동) 잃은 체력을 다 채우는 것 중 가장 작은 것, 없으면 가장 큰 것
func choose_potion() -> PotionData:
	var owned := get_owned_potions().filter(func(p: PotionData) -> bool: return p.auto_use)
	if owned.is_empty():
		return null
	for potion in owned:
		if potion.id == selected_potion:
			return potion
	var missing := max_hp - hp
	for potion in owned:
		if potion.get_heal(max_hp) >= missing:
			return potion
	return owned[owned.size() - 1]


## 지금 [H] 가 자동으로 고르는 중인지 (고른 포션이 없거나 다 떨어짐)
func is_potion_auto() -> bool:
	return selected_potion == &"" or get_potion_count(selected_potion) <= 0


## [G] 포션 바꾸기: 자동 → 가진 포션(회복량 작은 순) → 자동 …
func cycle_potion() -> StringName:
	var options: Array[StringName] = [&""]
	for potion in get_owned_potions():
		if potion.auto_use:
			options.append(potion.id)
	var current := selected_potion if not is_potion_auto() else &""
	select_potion(options[(options.find(current) + 1) % options.size()])
	return selected_potion


func select_potion(potion_id: StringName) -> void:
	selected_potion = potion_id
	potions_changed.emit()
	var potion := ItemDB.get_potion(potion_id) if potion_id != &"" else null
	if potion == null:
		show_notice("[H] 포션: 자동 (잃은 체력에 맞는 것)", Color(0.7, 1.0, 0.7))
	else:
		show_notice("[H] 포션: %s (%d개)" % [potion.display_name, get_potion_count(potion_id)], potion.get_rarity_color())


func can_buy_potion(potion: PotionData) -> bool:
	return potion != null and stage >= potion.get_unlock_stage() \
		and get_potion_count(potion.id) < POTION_MAX_STACK and can_afford(potion.price)


func buy_potion(potion: PotionData) -> bool:
	if not can_buy_potion(potion):
		return false
	spend_gold(potion.price)
	add_potion(potion, 1)
	return true


func add_potion(potion: PotionData, count: int = 1) -> int:
	var before := get_potion_count(potion.id)
	var after := mini(before + count, POTION_MAX_STACK)
	potions[potion.id] = after
	potions_changed.emit()
	return after - before


## 포션 마시기. potion 을 지정하지 않으면 choose_potion() 으로 자동 선택. 실제로 마셨으면 true.
func use_potion(potion: PotionData = null) -> bool:
	if is_player_dead:
		return false
	if potion == null:
		potion = choose_potion()
	if potion == null or get_potion_count(potion.id) <= 0:
		show_notice("회복 포션이 없습니다! 야영지 상인에게서 구매하세요", Color(1.0, 0.6, 0.5))
		return false
	if potion.is_sealed():
		show_notice("[봉인] %s — 100스테이지를 클리어하면 쓸 수 있다" % potion.display_name, potion.get_rarity_color())
		return false
	if hp >= max_hp and potion.buff_duration <= 0.0 and not potion.cleanse:
		show_notice("체력이 가득 차 있습니다", Color(0.8, 0.9, 1.0))
		return false
	if potion_heal_multiplier < 0.0:
		# 성흔 (36스테이지 세라핀): 포션의 회복이 피해로 바뀜 (포션은 소모됨)
		potions[potion.id] = get_potion_count(potion.id) - 1
		potions_changed.emit()
		show_notice("성흔! 포션의 회복이 피해로 바뀌었다", Color(1.0, 0.85, 0.5))
		damage_player(maxi(1, roundi(potion.get_heal(max_hp) * -potion_heal_multiplier)))
		return true
	if potion_heal_multiplier <= 0.0:
		show_notice("부패! 지금은 포션으로 회복할 수 없다", Color(0.7, 0.9, 0.6))
		return false
	var before := hp
	heal_player(maxi(1, roundi(potion.get_heal(max_hp) * potion_heal_multiplier)))
	potions[potion.id] = get_potion_count(potion.id) - 1
	if potion.buff_duration > 0.0:
		add_buff(potion.display_name, {"attack": potion.buff_attack, "reduction": potion.buff_reduction, "regen_pct": potion.regen_percent}, potion.buff_duration)
	potions_changed.emit()
	potion_used.emit(potion, hp - before)
	return true


# ============================================================ 잠깐 붙는 효과
func add_buff(buff_name: String, effects: Dictionary, duration: float) -> void:
	_buffs[buff_name] = {"effects": effects, "left": duration, "total": duration}
	_recalculate_stats()


func has_buff(buff_name: String) -> bool:
	return _buffs.has(buff_name)


func get_buff_left(buff_name: String) -> float:
	return float((_buffs.get(buff_name, {}) as Dictionary).get("left", 0.0))


func get_buff_value(key: String) -> float:
	var total := 0.0
	for buff in _buffs.values():
		total += float((buff["effects"] as Dictionary).get(key, 0.0))
	return total


## 「원초의 불꽃 12초 · 고대 용의 피 8초」 (HUD 상태 줄)
func get_buff_text() -> String:
	var parts := PackedStringArray()
	for buff_name in _buffs:
		parts.append("%s %.0f초" % [buff_name, ceilf(float(_buffs[buff_name]["left"]))])
	return " · ".join(parts)


## Player 가 매 프레임 호출: 효과 시간 줄이기 + 재생
func tick_buffs(delta: float) -> void:
	for id in relic_cooldowns.keys():
		relic_cooldowns[id] = maxf(float(relic_cooldowns[id]) - delta, 0.0)
	for id in skill_cooldowns.keys():
		skill_cooldowns[id] = maxf(float(skill_cooldowns[id]) - delta, 0.0)
	if _buffs.is_empty():
		return
	var regen := get_buff_value("regen_pct")
	if regen > 0.0 and not is_player_dead and hp < max_hp:
		_buff_regen_carry += max_hp * regen * delta
		if _buff_regen_carry >= 1.0:
			var amount := int(_buff_regen_carry)
			_buff_regen_carry -= amount
			heal_player(amount)
	var ended := false
	for buff_name in _buffs.keys():
		_buffs[buff_name]["left"] = float(_buffs[buff_name]["left"]) - delta
		if float(_buffs[buff_name]["left"]) <= 0.0:
			_buffs.erase(buff_name)
			ended = true
	if ended:
		_recalculate_stats()


# ============================================================ 신화 사용 아이템
## 사용 아이템 얻기. 개수가 있는 것(원초의 불꽃)은 이미 있으면 개수를 다시 채움
func add_relic(relic: RelicData) -> bool:
	if relic == null:
		return false
	if has_relic(relic.id):
		if relic.charges <= 0 or get_relic_charges(relic) >= relic.charges:
			return false
		relic_charges[relic.id] = relic.charges
		inventory_changed.emit()
		return true
	relics.append(relic)
	if relic.charges > 0:
		relic_charges[relic.id] = relic.charges
	inventory_changed.emit()
	return true


## 남은 개수 (소모되지 않는 것은 -1)
func get_relic_charges(relic: RelicData) -> int:
	if relic == null or relic.charges <= 0:
		return -1
	return int(relic_charges.get(relic.id, 0))


func has_relic(relic_id: StringName) -> bool:
	return relics.any(func(r: RelicData) -> bool: return r.id == relic_id)


## 무기 액티브 스킬(Q)의 남은 대기시간
func get_skill_cooldown(weapon: WeaponData) -> float:
	return float(skill_cooldowns.get(weapon.id, 0.0)) if weapon != null else 0.0


func start_skill_cooldown(weapon: WeaponData) -> void:
	skill_cooldowns[weapon.id] = weapon.get_skill_cooldown()


func get_relic_cooldown(relic: RelicData) -> float:
	return float(relic_cooldowns.get(relic.id, 0.0))


## 사용 아이템 쓰기 (효과는 relic_used 를 받은 Player 가 냄). 실제로 썼으면 true
func use_relic(relic: RelicData) -> bool:
	if relic == null or is_player_dead or not has_relic(relic.id):
		return false
	if relic.is_sealed():
		show_notice("[봉인] %s — 100스테이지를 클리어하면 쓸 수 있다" % relic.display_name, relic.get_rarity_color())
		return false
	if get_relic_cooldown(relic) > 0.0:
		show_notice("%s — %.0f초 뒤에 다시 쓸 수 있다" % [relic.display_name, ceilf(get_relic_cooldown(relic))], Color(0.8, 0.8, 0.9))
		return false
	relic_cooldowns[relic.id] = relic.cooldown
	if relic.charges > 0:
		relic_charges[relic.id] = get_relic_charges(relic) - 1
		if get_relic_charges(relic) <= 0:
			# 마지막 하나를 쓰면 사라짐 (효과는 그대로 남)
			relics.erase(relic)
			relic_charges.erase(relic.id)
			show_notice("%s — 마지막 하나를 썼다" % relic.display_name, relic.get_rarity_color())
	if relic.effect == RelicData.Effect.PRIMAL_FLAME:
		add_buff(relic.display_name, {"attack": relic.attack_bonus, "move": relic.move_bonus, "burn_on_hit": relic.burn_ratio, "burn_immune": 1.0}, relic.duration)
	relic_used.emit(relic)
	inventory_changed.emit()
	return true


# ============================================================ 장비 칸
## 무기 종류 → 무기 칸 (검·단검은 같은 칸)
func weapon_slot_of(weapon: WeaponData) -> int:
	match weapon.weapon_type:
		WeaponData.WeaponType.BOW:
			return WeaponSlot.BOW
		WeaponData.WeaponType.STAFF:
			return WeaponSlot.STAFF
	return WeaponSlot.MELEE


func is_equipped(item: ItemData) -> bool:
	# 타입이 지정된 배열(Array[WeaponData] 등)에 다른 타입을 넣어 검색하면 엔진 에러가 나므로 먼저 종류를 확인
	if item is WeaponData:
		return weapon_slots.has(item)
	if item is AccessoryData:
		return accessory_slots.has(item)
	return item != null and (item == equipped_shield or item == equipped_helmet or item == equipped_armor or item == equipped_boots)


## 장비를 알맞은 칸에 장착 (같은 칸의 기존 장비는 가방으로).
## 무기는 장착하면서 바로 손에 듭니다. 장신구는 종류(팔찌/반지/펜던트)에 맞는 칸에 들어갑니다.
func equip_item(item: ItemData) -> bool:
	if item == null or not owns_item(item.id):
		return false
	if item.is_sealed():
		show_notice("[봉인] %s — 100스테이지를 클리어하면 착용할 수 있다" % item.display_name, item.get_rarity_color())
		return false
	if item is WeaponData:
		var weapon := item as WeaponData
		var slot := weapon_slot_of(weapon)
		weapon_slots[slot] = weapon
		_set_active_weapon_slot(slot)
	elif item is ShieldData:
		equipped_shield = item as ShieldData
		shield_equipped.emit(equipped_shield)
	elif item is HelmetData:
		equipped_helmet = item as HelmetData
		helmet_equipped.emit(equipped_helmet)
	elif item is ArmorData:
		equipped_armor = item as ArmorData
		armor_equipped.emit(equipped_armor)
	elif item is BootsData:
		equipped_boots = item as BootsData
		boots_equipped.emit(equipped_boots)
	elif item is AccessoryData:
		var accessory := item as AccessoryData
		accessory_slots[accessory.slot_type] = accessory
	else:
		return false
	_recalculate_stats()
	equipment_changed.emit()
	return true


## 장착 해제 (가방으로). 손에 든 무기가 마지막 무기라면 해제할 수 없습니다.
func unequip_item(item: ItemData) -> bool:
	if not is_equipped(item):
		return false
	if item is WeaponData:
		var slot := weapon_slots.find(item)
		if _equipped_weapon_count() <= 1:
			show_notice("무기를 하나는 장착하고 있어야 합니다.", Color(1.0, 0.6, 0.5))
			return false
		weapon_slots[slot] = null
		if slot == active_weapon_slot:
			cycle_weapon(1)
	elif item == equipped_shield:
		equipped_shield = null
		shield_equipped.emit(null)
	elif item == equipped_helmet:
		equipped_helmet = null
		helmet_equipped.emit(null)
	elif item == equipped_armor:
		equipped_armor = null
		armor_equipped.emit(null)
	elif item == equipped_boots:
		equipped_boots = null
		boots_equipped.emit(null)
	elif item is AccessoryData:
		accessory_slots[accessory_slots.find(item)] = null
	_recalculate_stats()
	equipment_changed.emit()
	return true


## 1/2/3 키: 해당 무기 칸의 무기를 손에 듦
func select_weapon_slot(slot: int) -> bool:
	if slot < 0 or slot >= weapon_slots.size() or weapon_slots[slot] == null:
		return false
	_set_active_weapon_slot(slot)
	equipment_changed.emit()
	return true


## 장착된 무기 칸을 순서대로 순환 (키는 1/2/3 직접 선택만 — 테스트 · 내부용)
func cycle_weapon(step: int) -> void:
	for i in range(1, weapon_slots.size() + 1):
		var slot := wrapi(active_weapon_slot + step * i, 0, weapon_slots.size())
		if weapon_slots[slot] != null:
			select_weapon_slot(slot)
			return


## 헤르메스의 「도둑의 손」: 손에 든 무기를 빼앗김 (무기가 하나뿐이면 훔치지 않음). 훔친 무기를 돌려줌
func steal_active_weapon() -> WeaponData:
	if stolen_weapon != null or equipped_weapon == null or _equipped_weapon_count() <= 1:
		return null
	var weapon := equipped_weapon
	weapon_slots[weapon_slots.find(weapon)] = null
	items.erase(weapon)
	stolen_weapon = weapon
	cycle_weapon(1)
	_recalculate_stats()
	inventory_changed.emit()
	equipment_changed.emit()
	return weapon


## 훔쳐 간 무기를 돌려받음 (빈 무기 칸이면 다시 장착). 돌려받았으면 true
func return_stolen_weapon() -> bool:
	if stolen_weapon == null:
		return false
	var weapon := stolen_weapon
	stolen_weapon = null
	if not items.has(weapon):
		items.append(weapon)
	var slot := weapon_slot_of(weapon)
	if weapon_slots[slot] == null:
		weapon_slots[slot] = weapon
	_recalculate_stats()
	inventory_changed.emit()
	equipment_changed.emit()
	return true


func _equipped_weapon_count() -> int:
	var count := 0
	for w in weapon_slots:
		if w != null:
			count += 1
	return count


func _set_active_weapon_slot(slot: int) -> void:
	active_weapon_slot = slot
	var weapon := weapon_slots[slot]
	if weapon != equipped_weapon:
		equipped_weapon = weapon
		weapon_equipped.emit(equipped_weapon)


# ============================================================ 스테이지
func set_stage(value: int, new_stage_name: String = "") -> void:
	stage = value
	stage_name = new_stage_name
	stage_changed.emit(stage)


func set_location(new_location: String) -> void:
	location_name = new_location
	location_changed.emit(location_name)


## text: 처치 말고 다른 해방 시련일 때 HUD 에 보일 글 (예: 「봉인 코어 파괴 1 / 3」) — 비우면 「처치 k / t」
func set_kill_progress(current_kills: int, target: int, text: String = "") -> void:
	kills = current_kills
	kill_target = target
	gate_text = text
	kill_progress_changed.emit(kills, kill_target)


## 플레이어가 공격을 내보냄 (AttackController 가 호출 · 도플갱어가 따라 함)
func report_player_attacked(weapon: WeaponData, aim: Vector2) -> void:
	player_attacked.emit(weapon, aim)


func report_boss_spawned(boss_name: String, boss_max_hp: int) -> void:
	is_boss_active = true
	boss_spawned.emit(boss_name, boss_max_hp)


func report_boss_hp(current: int, boss_max_hp: int) -> void:
	boss_hp_changed.emit(current, boss_max_hp)


## 몬스터 1마리 처치 기록 (엔딩 통계)
func report_kill() -> void:
	total_kills += 1


## 마지막 스테이지 보스 토벌 → 엔딩
## 고대 용의 비늘 줍기 (새로 주웠으면 true)
func collect_dragon_scale(at_stage: int) -> bool:
	if dragon_scales.has(at_stage) or not DRAGON_SCALE_STAGES.has(at_stage):
		return false
	dragon_scales.append(at_stage)
	return true


func has_dragon_scale(at_stage: int) -> bool:
	return dragon_scales.has(at_stage)


func get_dragon_scale_count() -> int:
	return dragon_scales.size()


func has_all_dragon_scales() -> bool:
	return dragon_scales.size() >= DRAGON_SCALE_STAGES.size()


func report_game_cleared() -> void:
	is_game_cleared = true
	Achievements.unlock(&"GAME_CLEAR")
	if difficulty == Difficulty.VERY_HARD:
		Achievements.unlock(&"HARD_CLEAR")
	game_cleared.emit()


## 플레이 시간을 "mm:ss" (1시간 이상이면 "h:mm:ss") 로
func get_play_time_text() -> String:
	var total := int(play_time)
	@warning_ignore("integer_division")
	var hours := total / 3600
	@warning_ignore("integer_division")
	var minutes := (total % 3600) / 60
	var seconds := total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func report_boss_defeated() -> void:
	is_boss_active = false
	boss_defeated.emit()


## 100스테이지 보스 토벌: 신화 장비의 봉인이 풀림
func unlock_mythic() -> void:
	if mythic_unlocked:
		return
	mythic_unlocked = true
	inventory_changed.emit()
	equipment_changed.emit()


## 가지고 있는 신화 장비
func get_mythic_items() -> Array[ItemData]:
	var list: Array[ItemData] = []
	for item in items:
		if item.is_mythic():
			list.append(item)
	return list


# ============================================================ UI 요청
func show_notice(text: String, color: Color = Color.WHITE) -> void:
	notice_requested.emit(text, color)


func request_shop(shop_name: String, stock_ids: Array) -> void:
	if is_player_dead:
		return
	if is_boss_active:
		show_notice("보스전 중에는 상점을 이용할 수 없습니다!", Color(1, 0.5, 0.5))
		return
	shop_open_requested.emit(shop_name, stock_ids)
