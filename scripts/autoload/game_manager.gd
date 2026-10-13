extends Node
## 전역 게임 상태 관리자 (Autoload 이름: GameManager)
##
## - 난이도 / 플레이어 체력 / 대시 쿨타임 / 가드 게이지 / 골드 / 인벤토리 / 장비 칸 / 스테이지 진행 데이터를 보관합니다.
## - 값이 바뀌면 항상 시그널을 발행하므로 HUD/상점/인벤토리 UI 는 시그널만 구독하면 실시간으로 갱신됩니다.
##
## 장비 칸
##   무기 3칸   : 검(단검 포함) / 활 / 지팡이 — 종류별로 1개씩. 1/2/3·Q 로 사용할 무기를 고릅니다.
##   방어구 3칸 : 방패 / 투구 / 갑옷
##   보석 3칸   : 치명타 확률·치명타 피해·공격력 보너스 (합산)
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
## 방어력 / 최대 체력 / 치명타 등 파생 능력치가 바뀌었을 때
signal stats_changed

# --- 스테이지 / 보스 ---
signal stage_changed(stage: int)
signal location_changed(location_name: String)
signal kill_progress_changed(kills: int, target: int)
signal boss_spawned(boss_name: String, max_hp: int)
signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated

# --- UI ---
signal notice_requested(text: String, color: Color)
signal shop_open_requested(shop_name: String, stock_ids: Array)

enum Difficulty { NORMAL, HARD, VERY_HARD }
enum WeaponSlot { MELEE, BOW, STAFF }

## 난이도별 몬스터 배율
const DIFFICULTY_INFO := {
	Difficulty.NORMAL: {
		"name": "노멀", "color": Color(0.55, 1.0, 0.6),
		"enemy_hp": 1.0, "enemy_damage": 1.0, "enemy_speed": 1.0, "gold": 1.0, "max_alive_bonus": 0,
		"desc": "처음 모험을 떠나는 분께 추천합니다.",
	},
	Difficulty.HARD: {
		"name": "하드", "color": Color(1.0, 0.75, 0.35),
		"enemy_hp": 1.5, "enemy_damage": 1.4, "enemy_speed": 1.1, "gold": 1.25, "max_alive_bonus": 2,
		"desc": "몬스터 체력 x1.5 · 공격력 x1.4 · 골드 x1.25",
	},
	Difficulty.VERY_HARD: {
		"name": "베리하드", "color": Color(1.0, 0.35, 0.4),
		"enemy_hp": 2.2, "enemy_damage": 1.9, "enemy_speed": 1.2, "gold": 1.6, "max_alive_bonus": 4,
		"desc": "몬스터 체력 x2.2 · 공격력 x1.9 · 더 많고 빠름 · 골드 x1.6",
	},
}
const WEAPON_SLOT_NAMES := ["검", "활", "지팡이"]
const GEM_SLOT_COUNT := 3

const STARTING_ITEM_IDS: Array[StringName] = [&"rusty_sword", &"wooden_shield"]
const BASE_MAX_HP := 100
const STARTING_GOLD := 60

var difficulty: Difficulty = Difficulty.NORMAL

var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var is_player_dead: bool = false

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
## 보석 칸 3개. 빈 칸은 null
var gem_slots: Array[GemData] = [null, null, null]
## 플레이어 쪽 공격력 배율 (보석 공격력 보너스 반영)
var damage_multiplier: float = 1.0

var stage: int = 1
var stage_name: String = ""
var location_name: String = ""
var kills: int = 0
var kill_target: int = 0
var is_boss_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_game()


## 타이틀에서 난이도를 고르고 새 게임 시작
func start_new_game(new_difficulty: Difficulty) -> void:
	difficulty = new_difficulty
	reset_game()


## 새 게임 / 재시작 시 모든 데이터를 초기화합니다. (난이도는 유지)
func reset_game() -> void:
	max_hp = BASE_MAX_HP
	hp = max_hp
	is_player_dead = false
	dash_cooldown_remaining = 0.0
	gold = STARTING_GOLD
	damage_multiplier = 1.0
	stage = 1
	stage_name = ""
	location_name = ""
	kills = 0
	kill_target = 0
	is_boss_active = false
	items.clear()
	weapon_slots = [null, null, null]
	gem_slots = [null, null, null]
	active_weapon_slot = WeaponSlot.MELEE
	equipped_weapon = null
	equipped_shield = null
	equipped_helmet = null
	equipped_armor = null
	for item_id in STARTING_ITEM_IDS:
		var item := ItemDB.get_item(item_id)
		add_item(item)
		equip_item(item)
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
	stats_changed.emit()
	stage_changed.emit(stage)
	kill_progress_changed.emit(kills, kill_target)


func get_difficulty_info() -> Dictionary:
	return DIFFICULTY_INFO[difficulty]


func get_difficulty_name() -> String:
	return get_difficulty_info()["name"]


# ============================================================ 체력
func damage_player(amount: int) -> void:
	if is_player_dead or amount <= 0:
		return
	hp = maxi(hp - amount, 0)
	player_damaged.emit(amount)
	player_hp_changed.emit(hp, max_hp)
	if hp == 0:
		is_player_dead = true
		player_died.emit()


func heal_player(amount: int) -> void:
	if is_player_dead or amount <= 0:
		return
	hp = mini(hp + amount, max_hp)
	player_hp_changed.emit(hp, max_hp)


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
## 방패 + 투구 + 갑옷 방어력 합계. 모든 피해에서 이만큼 빠집니다 (최소 1은 들어감).
func get_total_defense() -> int:
	var total := 0
	if equipped_shield != null:
		total += equipped_shield.defense
	if equipped_helmet != null:
		total += equipped_helmet.defense
	if equipped_armor != null:
		total += equipped_armor.defense
	return total


func get_bonus_max_hp() -> int:
	var total := 0
	if equipped_helmet != null:
		total += equipped_helmet.bonus_max_hp
	if equipped_armor != null:
		total += equipped_armor.bonus_max_hp
	return total


## 보석으로 더해지는 치명타 확률 (0.1 = +10%)
func get_crit_chance_bonus() -> float:
	var total := 0.0
	for gem in gem_slots:
		if gem != null:
			total += gem.crit_chance_bonus
	return total


func get_crit_damage_bonus() -> float:
	var total := 0.0
	for gem in gem_slots:
		if gem != null:
			total += gem.crit_damage_bonus
	return total


func get_attack_bonus() -> float:
	var total := 0.0
	for gem in gem_slots:
		if gem != null:
			total += gem.attack_bonus
	return total


## 무기 + 보석을 합친 최종 치명타 확률
func get_crit_chance(weapon: WeaponData = null) -> float:
	if weapon == null:
		weapon = equipped_weapon
	var base := weapon.crit_chance if weapon != null else 0.0
	return minf(base + get_crit_chance_bonus(), 1.0)


## 장착 무기로 1타 데미지 굴리기 (공격력·치명타 보석 반영)
func roll_weapon_damage(weapon: WeaponData) -> Dictionary:
	return weapon.roll_damage(damage_multiplier, get_crit_chance_bonus(), get_crit_damage_bonus())


func _recalculate_stats() -> void:
	damage_multiplier = 1.0 + get_attack_bonus()
	var new_max := BASE_MAX_HP + get_bonus_max_hp()
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


func get_armors() -> Array[ArmorData]:
	var result: Array[ArmorData] = []
	for item in items:
		if item is ArmorData:
			result.append(item as ArmorData)
	return result


func get_gems() -> Array[GemData]:
	var result: Array[GemData] = []
	for item in items:
		if item is GemData:
			result.append(item as GemData)
	return result


## 새 장비를 가방에 추가. null 이거나 이미 가지고 있으면 false.
func add_item(item: ItemData) -> bool:
	if item == null or owns_item(item.id):
		return false
	items.append(item)
	inventory_changed.emit()
	return true


## 상점 구매: 골드 차감 + 가방 추가 + 자동 장착
func buy_item(item: ItemData) -> bool:
	if item == null or owns_item(item.id) or not can_afford(item.price):
		return false
	if stage < item.get_unlock_stage():
		return false
	spend_gold(item.price)
	add_item(item)
	equip_item(item)
	return true


## 장착 중이 아닌 장비만 팔 수 있습니다.
func can_sell(item: ItemData) -> bool:
	return item != null and items.has(item) and not is_equipped(item)


## 상인에게 판매. 받은 골드를 반환 (실패하면 0)
func sell_item(item: ItemData) -> int:
	if not can_sell(item):
		return 0
	items.erase(item)
	var value := item.get_sell_value()
	add_gold(value)
	inventory_changed.emit()
	return value


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
	if item is GemData:
		return gem_slots.has(item)
	return item != null and (item == equipped_shield or item == equipped_helmet or item == equipped_armor)


## 장비를 알맞은 칸에 장착 (같은 칸의 기존 장비는 가방으로).
## 무기는 장착하면서 바로 손에 듭니다. 보석은 gem_slot(0~2)을 지정하지 않으면 빈 칸 → 없으면 1번 칸을 교체.
func equip_item(item: ItemData, gem_slot: int = -1) -> bool:
	if item == null or not owns_item(item.id):
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
	elif item is GemData:
		if gem_slots.has(item):
			return true
		if gem_slot < 0:
			gem_slot = gem_slots.find(null)
		gem_slots[clampi(gem_slot, 0, GEM_SLOT_COUNT - 1)] = item as GemData
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
	elif item is GemData:
		gem_slots[gem_slots.find(item)] = null
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


## Q / 마우스 휠: 장착된 무기 칸을 순서대로 순환
func cycle_weapon(step: int) -> void:
	for i in range(1, weapon_slots.size() + 1):
		var slot := wrapi(active_weapon_slot + step * i, 0, weapon_slots.size())
		if weapon_slots[slot] != null:
			select_weapon_slot(slot)
			return


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


func set_kill_progress(current_kills: int, target: int) -> void:
	kills = current_kills
	kill_target = target
	kill_progress_changed.emit(kills, kill_target)


func report_boss_spawned(boss_name: String, boss_max_hp: int) -> void:
	is_boss_active = true
	boss_spawned.emit(boss_name, boss_max_hp)


func report_boss_hp(current: int, boss_max_hp: int) -> void:
	boss_hp_changed.emit(current, boss_max_hp)


func report_boss_defeated() -> void:
	is_boss_active = false
	boss_defeated.emit()


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
