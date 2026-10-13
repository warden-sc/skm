extends Node
## 전역 게임 상태 관리자 (Autoload 이름: GameManager)
##
## - 플레이어 체력 / 대시 쿨타임 / 가드 게이지 / 골드 / 인벤토리 / 장착 무기·방패 / 스테이지 진행 데이터를 보관합니다.
## - 값이 바뀌면 항상 시그널을 발행하므로 HUD/상점 UI 는 시그널만 구독하면 실시간으로 갱신됩니다.
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
## 무기 또는 방패 인벤토리가 바뀌었을 때
signal inventory_changed
signal weapon_equipped(weapon: WeaponData)
signal shield_equipped(shield: ShieldData)

# --- 스테이지 / 보스 ---
signal stage_changed(stage: int)
signal kill_progress_changed(kills: int, target: int)
signal intermission_changed(seconds_left: int)
signal boss_spawned(boss_name: String, max_hp: int)
signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated

# --- UI ---
signal notice_requested(text: String, color: Color)
signal shop_open_requested(shop_name: String, stock_ids: Array)

const STARTING_WEAPON_ID: StringName = &"rusty_sword"
const STARTING_SHIELD_ID: StringName = &"wooden_shield"
const BASE_MAX_HP := 100
const STARTING_GOLD := 40

var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var is_player_dead: bool = false

var dash_cooldown_remaining: float = 0.0
var dash_cooldown_total: float = 1.0

var guard: float = 0.0
var max_guard: float = 0.0

var gold: int = 0
var weapons: Array[WeaponData] = []
var shields: Array[ShieldData] = []
var equipped_weapon: WeaponData
var equipped_shield: ShieldData
## 플레이어 쪽 공격력 배율 (버프/패시브 확장용)
var damage_multiplier: float = 1.0

var stage: int = 1
var kills: int = 0
var kill_target: int = 0
var is_boss_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_game()


## 새 게임 / 재시작 시 모든 데이터를 초기화합니다.
func reset_game() -> void:
	max_hp = BASE_MAX_HP
	hp = max_hp
	is_player_dead = false
	dash_cooldown_remaining = 0.0
	gold = STARTING_GOLD
	damage_multiplier = 1.0
	stage = 1
	kills = 0
	kill_target = 0
	is_boss_active = false
	weapons.clear()
	shields.clear()
	equipped_weapon = null
	equipped_shield = null
	add_item(ItemDB.get_item(STARTING_WEAPON_ID))
	add_item(ItemDB.get_item(STARTING_SHIELD_ID))
	equip_item(ItemDB.get_item(STARTING_WEAPON_ID))
	equip_item(ItemDB.get_item(STARTING_SHIELD_ID))
	emit_all()


## 현재 값 전체를 한 번에 재발행 (UI 초기 동기화용)
func emit_all() -> void:
	player_hp_changed.emit(hp, max_hp)
	dash_cooldown_changed.emit(dash_cooldown_remaining, dash_cooldown_total)
	guard_changed.emit(guard, max_guard)
	gold_changed.emit(gold)
	inventory_changed.emit()
	weapon_equipped.emit(equipped_weapon)
	shield_equipped.emit(equipped_shield)
	stage_changed.emit(stage)
	kill_progress_changed.emit(kills, kill_target)


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


# ============================================================ 대시
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


# ============================================================ 가드
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


# ============================================================ 장비 / 인벤토리
func owns_item(item_id: StringName) -> bool:
	for w in weapons:
		if w.id == item_id:
			return true
	for sh in shields:
		if sh.id == item_id:
			return true
	return false


## 새 장비를 인벤토리에 추가. null 이거나 이미 가지고 있으면 false.
func add_item(item: ItemData) -> bool:
	if item == null or owns_item(item.id):
		return false
	if item is WeaponData:
		weapons.append(item as WeaponData)
	elif item is ShieldData:
		shields.append(item as ShieldData)
	else:
		push_error("GameManager.add_item: 지원하지 않는 아이템 타입 (%s)" % item.id)
		return false
	inventory_changed.emit()
	return true


## 상점 구매: 골드 차감 + 인벤토리 추가 + 자동 장착
func buy_item(item: ItemData) -> bool:
	if item == null or owns_item(item.id) or not can_afford(item.price):
		return false
	spend_gold(item.price)
	add_item(item)
	equip_item(item)
	return true


## 무기면 무기 칸, 방패면 방패 칸에 장착
func equip_item(item: ItemData) -> void:
	if item == null or not owns_item(item.id):
		return
	if item is WeaponData:
		if equipped_weapon != item:
			equipped_weapon = item as WeaponData
			weapon_equipped.emit(equipped_weapon)
	elif item is ShieldData:
		if equipped_shield != item:
			equipped_shield = item as ShieldData
			shield_equipped.emit(equipped_shield)


func is_equipped(item: ItemData) -> bool:
	return item != null and (item == equipped_weapon or item == equipped_shield)


## Q / 마우스 휠로 장착 무기 순환
func cycle_weapon(step: int) -> void:
	if weapons.size() <= 1:
		return
	var index := weapons.find(equipped_weapon)
	index = wrapi(index + step, 0, weapons.size())
	equip_item(weapons[index])


# ============================================================ 스테이지
func set_stage(value: int) -> void:
	stage = value
	stage_changed.emit(stage)


func set_kill_progress(current_kills: int, target: int) -> void:
	kills = current_kills
	kill_target = target
	kill_progress_changed.emit(kills, kill_target)


func set_intermission(seconds_left: int) -> void:
	intermission_changed.emit(seconds_left)


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
