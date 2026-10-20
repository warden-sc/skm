class_name BossEnceladus
extends PatternBoss
## 58스테이지 보스: 불의 거인 엔켈라도스 — 신들과 싸운 기간테스. 아테나가 던진 시칠리아 섬 아래 묻혀 지금도 에트나 화산으로 불을 뿜습니다.
##   ERUPTION   : 땅속 화산 분화 — 보스방 곳곳이 터지고 용암 장판이 남음
##   LAVA_FIST  : 용암 주먹 — 몸 주위 고리
##   MAGMA_RAIN : 마그마 덩어리 탄막
##   SUMMON     : 용암 거인병 · 불 뱀 호출
##
## [기믹] 시칠리아의 바위: 보스방 가장자리의 바위 rock_count 개 중 하나를 공격하면 그 순간 거인이 서 있던 자리로 바위가 떨어짐 (drop_delay 초 예고)
##   떨어질 때 거인이 그 자리(drop_radius)에 있으면 「묻힘」: 최대 체력의 bury_ratio 피해 + 오래 기절 + 그동안 방어력 -bury_defense
##   거인이 피하면 빗나감. 바위는 rock_respawn 초 뒤 다시 솟음. 플레이어도 떨어지는 자리에 있으면 피해
## 체력 50% 이하: 분화가 늘어남

enum Pattern { ERUPTION, LAVA_FIST, MAGMA_RAIN, SUMMON }

const ROCK_SPOTS := [Vector2(-240, -120), Vector2(240, -120), Vector2(0, 130)]

@export var rock_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var magma_texture: Texture2D
@export var eruption_damage: int = 86
@export var fist_damage: int = 90
@export var magma_damage: int = 58
@export var rock_damage: int = 70
@export var bury_ratio: float = 0.1
@export var bury_time: float = 10.0
@export var bury_defense: int = 20
@export var rock_respawn: float = 15.0
@export var drop_delay: float = 1.0
@export var drop_radius: float = 46.0

var rocks: Array[BossPart] = [null, null, null]
var _rock_left: Array[float] = [0.0, 0.0, 0.0]
var _pending_slot: int = -1
var _buried_left: float = 0.0
var _buries: int = 0
var _misses: int = 0
var _base_defense: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.ERUPTION, Pattern.LAVA_FIST, Pattern.MAGMA_RAIN, Pattern.ERUPTION, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_defense = defense


func get_rocks() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for r in rocks:
		if r != null and is_instance_valid(r) and not r.is_dead():
			alive.append(r)
	return alive


func is_buried() -> bool:
	return _buried_left > 0.0


func get_bury_count() -> int:
	return _buries


func get_miss_count() -> int:
	return _misses


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for i in ROCK_SPOTS.size():
			_raise_rock(i)
		set_status("가장자리의 바위를 쳐서 거인 위로 떨어뜨려라", Color(1.0, 0.75, 0.5))
	return super._get_move_velocity(delta)


func _raise_rock(slot: int) -> void:
	if rock_scene == null or is_dead():
		return
	_pending_slot = slot
	request_summon(rock_scene, _area().get_center() + ROCK_SPOTS[slot])
	_pending_slot = -1


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart or _pending_slot < 0:
		return
	var rock := minion as BossPart
	rock.boss = self
	rock.follow_boss = false
	rock.show_bar = false
	rock.relay_ratio = 0.001 * (_pending_slot + 1)  # 몇 번째 바위인지 구분용 (피해는 넘기지 않음)
	rocks[_pending_slot] = rock


func _physics_process(delta: float) -> void:
	if not is_dead():
		for i in _rock_left.size():
			if _rock_left[i] > 0.0:
				_rock_left[i] -= delta
				if _rock_left[i] <= 0.0:
					_raise_rock(i)
		if _buried_left > 0.0:
			_buried_left -= delta
			if _buried_left <= 0.0:
				defense = _base_defense
				set_status("가장자리의 바위를 쳐서 거인 위로 떨어뜨려라", Color(1.0, 0.75, 0.5))
				Net.announce("엔켈라도스가 바위를 밀쳐 내고 일어선다!", Color(1.0, 0.6, 0.3))
	super._physics_process(delta)


## 바위를 때리면 BossPart 가 여기로 알려 줌 (ratio 로 몇 번째 바위인지 구분)
func take_weak_point_hit(_amount: int, _kb: Vector2, _is_crit: bool, _armor_pen: int, ratio: float) -> void:
	drop_rock(clampi(roundi(ratio * 1000.0) - 1, 0, rocks.size() - 1))


## 바위를 거인이 지금 서 있는 자리로 떨어뜨림 (테스트에서도 직접 호출)
func drop_rock(slot: int) -> bool:
	var rock := rocks[slot]
	if rock == null or not is_instance_valid(rock) or rock.is_dead() or is_dead():
		return false
	rocks[slot] = null
	_rock_left[slot] = rock_respawn
	var from := rock.get_hit_center()
	rock.despawn()
	var target := global_position
	var warn := AoeStrike.spawn(self, target, drop_radius, drop_delay, roundi(rock_damage * power), Color(0.75, 0.7, 0.6))
	if warn != null:
		warn.fx_gravity = Vector2(0, 40)
	CarryItem.fly(self, from, target + Vector2(0, -40), rock.sprite.texture, drop_delay * 0.8)
	_after(drop_delay, func() -> void: _land_rock(target))
	return true


func _land_rock(target: Vector2) -> void:
	if is_dead():
		return
	Fx.burst(self, target, Color(0.7, 0.65, 0.55), 30, 90.0, 0.6)
	if global_position.distance_to(target) <= drop_radius:
		_buries += 1
		_buried_left = bury_time
		defense = maxi(_base_defense - bury_defense, 0)
		take_damage(roundi(max_hp * bury_ratio), Vector2.ZERO, false, 999999)
		super.stun(bury_time)
		set_status("시칠리아 섬에 묻힘! 방어력 -%d" % Balance.scale(bury_defense), Color(1.0, 0.85, 0.5))
		Net.announce("떨어진 바위산이 엔켈라도스를 짓눌렀다!", Color(1.0, 0.85, 0.5))
	else:
		_misses += 1
		FloatingText.spawn(self, target + Vector2(0, -20), "빗나갔다!", Color(0.8, 0.8, 0.7), true)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.ERUPTION:
			var area := _area().grow(-20.0)
			for i in (9 if phase_two else 6):
				var at := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
				if i < 2:
					at = _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 40.0)
				telegraph_strike(at, 26.0, 1.0 + 0.08 * i, eruption_damage, Elements.Type.FIRE)
				var zone_at := at
				_after(1.0 + 0.08 * i, func() -> void:
					if not is_dead():
						GroundZone.spawn_hostile(self, zone_at, GroundZone.Kind.FIRE, 22.0, 4.0, 1.0, roundi(8 * power), 2.0))
			return 1.3
		Pattern.LAVA_FIST:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 58.0, 22.0, 0.85, fist_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.MAGMA_RAIN:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2), 110.0, magma_damage, magma_texture, 0.0, Elements.Type.FIRE))
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("엔켈라도스: 섬 하나로 나를 묻을 수는 없다! 화산이 더 거세게 터진다", Color(1.0, 0.5, 0.3))
