class_name BossGaia
extends PatternBoss
## 30스테이지 보스: 대정령 벨페르 가이아 — 세상의 모든 정령을 품은 대지의 어머니. 불·물·바람·대지를 모두 다룬다.
##   FIRE   : 불꽃 부채꼴
##   TIDE   : 물결 — 사방으로 퍼지는 물방울 두 겹
##   GALE   : 돌풍 — 플레이어 쪽 일직선 장판
##   QUAKE  : 지진 — 플레이어 주변 장판
##   SUMMON : 불꽃·물·바위 정령 호출
##
## [기믹 1] 네 원소의 정령핵: 보스방 네 귀퉁이에 불·물·바람·대지 정령핵 (핵마다 체력이 따로)
##   살아 있는 핵마다 가이아가 그 원소의 가호를 받음
##     불 = 공격에 화상 / 물 = 체력 재생 / 바람 = 이동 속도 1.5배 / 대지 = 방어력 +20 (실제 +200)
##   핵을 부술 때마다 가호가 하나씩 사라짐
## [기믹 2] 대지의 숨결: 핵이 모두 부서지면 가이아가 대지와 하나가 되어, collapse_interval 마다
##   보스방 바닥 구역 몇 곳에 금이 가고(예고) 무너짐 → 그 구역에 있으면 큰 피해 (가드 불가, 대시로 회피)
## [기믹 3] 생명의 순환: 체력이 seed_threshold 이하가 되면(한 번) 세계수의 씨앗을 심음
##   씨앗(체력 따로)이 seed_time 안에 부서지지 않으면 가이아가 최대 체력의 seed_heal 만큼 회복

enum Pattern { FIRE, TIDE, GALE, QUAKE, SUMMON }
enum Element { FIRE, WATER, WIND, EARTH }

const ELEMENT_NAMES := ["불", "물", "바람", "대지"]

@export var core_scenes: Array[PackedScene] = []
@export var seed_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var fire_texture: Texture2D
@export var water_texture: Texture2D
@export var fire_damage: int = 44
@export var tide_damage: int = 40
@export var gale_damage: int = 66
@export var quake_damage: int = 66
@export var core_hp_ratio: float = 0.05
@export var water_regen: float = 0.004
@export var collapse_interval: float = 4.5
@export var collapse_warn: float = 1.5
@export var collapse_ratio: float = 0.3
@export var seed_threshold: float = 0.1
@export var seed_time: float = 8.0
@export var seed_heal: float = 0.3
@export var seed_hp_ratio: float = 0.03

var _cores: Dictionary = {}   # Element → BossPart
var _core_queue: Array[int] = []
var _cores_requested: bool = false
var _base_defense: int = 0
var _base_speed: float = 0.0
var _regen_carry: float = 0.0
var field: CollapseField
var _collapse_timer: float = 2.0
var _collapses: int = 0
var _collapse_hits: int = 0
var _seed: BossPart
var _seed_planted: bool = false
var _seed_left: float = 0.0
var _seed_healed: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.FIRE, Pattern.QUAKE, Pattern.TIDE, Pattern.GALE, Pattern.SUMMON, Pattern.FIRE, Pattern.QUAKE]
	_base_defense = defense
	_base_speed = move_speed


func get_cores() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for e in _cores:
		var c: Variant = _cores[e]
		if is_instance_valid(c) and not (c as BossPart).is_dead():
			alive.append(c as BossPart)
	return alive


func has_blessing(element: int) -> bool:
	var c: Variant = _cores.get(element, null)  # 부서진 핵은 이미 해제됐을 수 있어 타입 없이 확인
	return is_instance_valid(c) and not (c as BossPart).is_dead()


func get_core(element: int) -> BossPart:
	return _cores.get(element, null) if has_blessing(element) else null


func is_earth_breath() -> bool:
	return field != null and is_instance_valid(field)


func get_collapse_count() -> int:
	return _collapses


func get_collapse_hits() -> int:
	return _collapse_hits


func get_seed() -> BossPart:
	return _seed if _seed != null and is_instance_valid(_seed) and not _seed.is_dead() else null


func is_seed_planted() -> bool:
	return _seed_planted


func did_seed_heal() -> bool:
	return _seed_healed


func _get_move_velocity(delta: float) -> Vector2:
	if not _cores_requested:
		_cores_requested = true
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(220, 60), Vector2(440, 300))
		var corners: Array[Vector2] = [area.position + Vector2(30, 40), Vector2(area.end.x - 30, area.position.y + 40),
				Vector2(area.position.x + 30, area.end.y - 20), area.end - Vector2(30, 20)]
		for i in mini(core_scenes.size(), 4):
			_core_queue.append(i)
			request_summon(core_scenes[i], corners[i])
		_update_blessings()
	# 물의 가호: 체력 재생
	if has_blessing(Element.WATER) and hp < max_hp:
		_regen_carry += max_hp * water_regen * delta
		if _regen_carry >= 1.0:
			var amount := mini(int(_regen_carry), max_hp - hp)
			_regen_carry -= int(_regen_carry)
			hp += amount
			health_changed.emit(hp, max_hp)
	if is_earth_breath() and has_target():
		_collapse_timer -= delta
		if _collapse_timer <= 0.0:
			begin_collapse()
	if _seed_planted and _seed_left > 0.0:
		_seed_left -= delta
		if get_seed() == null:
			_seed_left = 0.0
		elif _seed_left <= 0.0:
			_seed_grown()
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and not _core_queue.is_empty():
		var element: int = _core_queue.pop_front()
		var core := minion as BossPart
		core.boss = self
		core.follow_boss = false
		core.max_hp = maxi(1, roundi(max_hp * core_hp_ratio))
		core.died.connect(_on_core_broken.bind(element))
		_cores[element] = core
	elif minion is BossPart and _seed_planted and _seed == null:
		_seed = minion as BossPart
		_seed.boss = self
		_seed.follow_boss = false
		_seed.max_hp = maxi(1, roundi(max_hp * seed_hp_ratio))
		_seed.died.connect(_on_seed_broken)


# ============================================================ 기믹 1: 정령핵 · 가호
func _update_blessings() -> void:
	defense = _base_defense + (20 if has_blessing(Element.EARTH) else 0)
	move_speed = _base_speed * (1.5 if has_blessing(Element.WIND) else 1.0)
	burn_damage = 8 if has_blessing(Element.FIRE) else 0
	burn_duration = 2.5
	var names := PackedStringArray()
	for e in 4:
		if _cores.has(e) and has_blessing(e):
			names.append(ELEMENT_NAMES[e])
	if names.is_empty() and _cores_requested and not _core_queue.is_empty():
		names = PackedStringArray(ELEMENT_NAMES)  # 핵이 막 생기는 중
	set_status("가호: " + "·".join(names) if not names.is_empty() else "", Color(0.7, 1.0, 0.7))


func get_blessing_names() -> PackedStringArray:
	var names := PackedStringArray()
	for e in 4:
		if has_blessing(e):
			names.append(ELEMENT_NAMES[e])
	return names


func _on_core_broken(_enemy: Enemy, element: int) -> void:
	if is_dead():
		return
	_update_blessings()
	GameManager.show_notice("%s의 정령핵을 부쉈다! %s의 가호가 사라진다" % [ELEMENT_NAMES[element], ELEMENT_NAMES[element]], Color(0.7, 1.0, 0.7))
	if get_cores().is_empty():
		_begin_earth_breath()


# ============================================================ 기믹 2: 대지의 숨결
func _begin_earth_breath() -> void:
	if is_earth_breath():
		return
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(220, 60), Vector2(440, 300))
	field = CollapseField.spawn(self, area)
	_collapse_timer = 2.0
	set_status("대지의 숨결: 땅이 무너진다!", Color(1.0, 0.75, 0.4))
	GameManager.show_notice("정령핵이 모두 부서졌다! 가이아가 대지와 하나가 된다 — 금 간 바닥을 피하라", Color(1.0, 0.75, 0.4))


func begin_collapse() -> void:
	if not is_earth_breath() or is_dead():
		return
	_collapse_timer = collapse_interval * (0.8 if phase_two else 1.0)
	var tiles: Array[int] = []
	# 플레이어가 서 있는 구역은 반드시 포함 → 움직이게 만듦
	var here := field.tile_of(_player.global_position) if has_target() else -1
	if here >= 0:
		tiles.append(here)
	while tiles.size() < (4 if phase_two else 3):
		var t := randi() % (CollapseField.COLS * CollapseField.ROWS)
		if not tiles.has(t):
			tiles.append(t)
	field.warn(tiles, collapse_warn)
	_after(collapse_warn, _resolve_collapse.bind(tiles))


func _resolve_collapse(tiles: Array[int]) -> void:
	if is_dead() or not is_earth_breath():
		return
	_collapses += 1
	field.collapse()
	if has_target() and field.is_in_tile(_player.global_position, tiles):
		if _player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * collapse_ratio)), _player.global_position + Vector2(0, -10)) == Player.HitResult.DAMAGED:
			_collapse_hits += 1
	if _player != null:
		_player.shake_camera(5.0)


# ============================================================ 기믹 3: 생명의 순환
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if not _seed_planted and not is_dead() and float(hp) <= max_hp * seed_threshold:
		plant_seed()


func plant_seed() -> void:
	if _seed_planted or is_dead() or seed_scene == null:
		return
	_seed_planted = true
	_seed_left = seed_time
	request_summon(seed_scene, global_position + Vector2(0, 46))
	set_status("세계수의 씨앗: 다 자라기 전에 부숴라!", Color(0.6, 1.0, 0.5))
	GameManager.show_notice("가이아가 세계수의 씨앗을 심었다! %d초 안에 부수지 않으면 크게 회복한다" % roundi(seed_time), Color(0.6, 1.0, 0.5))


func _seed_grown() -> void:
	_seed_healed = true
	var heal := mini(roundi(max_hp * seed_heal), max_hp - hp)
	hp += heal
	health_changed.emit(hp, max_hp)
	FloatingText.spawn(self, global_position + Vector2(0, -50), "+%d (생명의 순환)" % heal, Color(0.6, 1.0, 0.5), true)
	if get_seed() != null:
		_seed.despawn()
	_seed = null
	set_status("", Color.WHITE)


func _on_seed_broken(_enemy: Enemy) -> void:
	_seed_left = 0.0
	_seed = null
	set_status("", Color.WHITE)
	GameManager.show_notice("세계수의 씨앗을 부쉈다!", Color(0.6, 1.0, 0.5))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.FIRE:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.16), 145.0, fire_damage, fire_texture, 0.0, Elements.Type.FIRE)
			return 1.0
		Pattern.TIDE:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2), 110.0, tide_damage, water_texture, 0.6, Elements.Type.ICE))
			return 1.1
		Pattern.GALE:
			var dir := direction_to_player()
			for i in 8:
				telegraph_strike(get_hit_center() + dir * (28.0 + 26.0 * i), 16.0, 0.7 + 0.04 * i, gale_damage, Elements.Type.NATURE)
			return 1.2
		Pattern.QUAKE:
			for i in 6:
				telegraph_strike(_player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 85.0)), 22.0, 0.85 + 0.08 * i, quake_damage, Elements.Type.EARTH)
			return 1.4
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if is_earth_breath():
		field.queue_free()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("벨페르 가이아: 모든 생명은 대지로 돌아간다…", Color(0.7, 1.0, 0.7))
