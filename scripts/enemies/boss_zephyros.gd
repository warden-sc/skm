class_name BossZephyros
extends PatternBoss
## 31스테이지 보스: 바람의 드래곤 제피로스 — 폭풍의 협곡을 다스리는 비취빛 용.
##   BLADES : 폭풍 브레스 — 초승달 바람 덩어리를 넓게 뿜고 그 사이로 바람 칼날 (모두 바람에 휨)
##   GUST   : 돌풍 — 플레이어 쪽 일직선 장판
##   CLAW   : 할퀴기 — 앞쪽 장판 세 개
##   SUMMON : 실프 · 하피 호출
##
## [기믹 1] 돌풍: 보스방 전체에 바람이 불고, wind_interval 마다 무작위 방향으로 바뀜
##   → 모든 투사체(플레이어의 화살·마법 포함)가 바람 쪽으로 휘어 날아감, 플레이어도 조금 밀림
## [기믹 2] 비상: soar_interval 마다 soar_time 동안 하늘로 날아오름 → 활로만 맞음 (바람을 읽고 쏴야 함)
##   하늘에서 깃털 칼날을 흩뿌리다가, 플레이어 자리로 급강하
## [기믹 3] 회오리: 2페이즈부터 tornado_interval 마다 회오리 2개 — 바람을 타고 플레이어를 쫓음
##   닿으면 휘말려 피해 + 내던져짐 (대시로 통과)

enum Pattern { BLADES, GUST, CLAW, SUMMON }

const FLIGHT_HEIGHT := 34.0
const BREATH_TEXTURE := preload("res://assets/sprites/projectiles/breath_gust.png")
const DIRECTIONS := [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]

@export var minion_scenes: Array[PackedScene] = []
@export var blade_texture: Texture2D
@export var blade_damage: int = 46
@export var gust_damage: int = 70
@export var claw_damage: int = 74
@export var dive_damage: int = 80
@export var tornado_damage: int = 60
@export var wind_interval: float = 7.0
@export var wind_strength: float = 260.0
@export var soar_interval: float = 17.0
@export var soar_time: float = 6.0
@export var tornado_interval: float = 12.0

var wind: WindField
var _wind_left: float = 1.5
var _wind_changes: int = 0
var _soar_cooldown: float = 9.0
var _soar_left: float = 0.0
var _feather_timer: float = 0.0
var _orbit_angle: float = 0.0
var _diving: bool = false
var _height: float = 0.0
var _base_shape_pos: Vector2
var _base_scale: Vector2
var _tornado_left: float = 3.0
var _soars: int = 0
var _base_contact: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BLADES, Pattern.GUST, Pattern.CLAW, Pattern.SUMMON, Pattern.BLADES, Pattern.CLAW]
	immune_text = "하늘 위! 활만 닿음"
	_base_shape_pos = _hit_shape.position
	_base_scale = sprite.scale
	_base_contact = contact_damage


func get_wind() -> WindField:
	return wind if wind != null and is_instance_valid(wind) else null


func get_wind_change_count() -> int:
	return _wind_changes


func is_soaring() -> bool:
	return airborne


func get_soar_count() -> int:
	return _soars


func _get_move_velocity(delta: float) -> Vector2:
	if get_wind() == null and has_target():
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))
		wind = WindField.spawn(self, area.grow(40.0))
		change_wind()
	if get_wind() != null:
		_wind_left -= delta
		if _wind_left <= 0.0:
			change_wind()
	if phase_two and has_target():
		_tornado_left -= delta
		if _tornado_left <= 0.0:
			summon_tornadoes()
	if not has_target():
		return Vector2.ZERO
	if airborne:
		return _soar_velocity(delta)
	_soar_cooldown -= delta
	if _soar_cooldown <= 0.0 and not is_casting():
		soar()
		return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹 1: 돌풍
## 바람 방향을 무작위로 바꿈 (테스트에서도 직접 호출)
func change_wind() -> void:
	if get_wind() == null:
		return
	var current := wind.direction
	# 지금과 확실히 다른 방향 중에서 고름 (같은 방향이 다시 나오지 않게)
	var choices: Array[Vector2] = []
	for d in DIRECTIONS:
		if (d as Vector2).normalized().dot(current) < 0.6:
			choices.append((d as Vector2).normalized())
	var dir: Vector2 = choices.pick_random() if not choices.is_empty() else (DIRECTIONS.pick_random() as Vector2).normalized()
	wind.set_wind(dir, wind_strength * (1.2 if phase_two else 1.0))
	_wind_changes += 1
	_wind_left = wind_interval * (0.7 if phase_two else 1.0)
	Net.announce("바람의 방향이 바뀐다 %s  — 화살과 마법이 바람에 휜다" % wind.get_arrow(), Color(0.7, 1.0, 0.85))


# ============================================================ 기믹 2: 비상
func soar() -> void:
	if airborne or is_dead():
		return
	airborne = true
	_soars += 1
	_soar_left = soar_time
	_feather_timer = 0.6
	_orbit_angle = randf() * TAU
	contact_damage = 0
	set_status("하늘 위: 활로만 공격 가능 — 바람을 읽어라!", Color(0.7, 1.0, 0.85))
	Net.announce("제피로스가 폭풍 위로 날아올랐다! 활로만 닿는다 — 바람에 휘는 걸 감안해 쏴라", Color(0.7, 1.0, 0.85))
	Fx.burst(self, global_position, Color(0.8, 1.0, 0.9), 24, 70.0, 0.6, Vector2(0, 40), 1.4)


func _soar_velocity(delta: float) -> Vector2:
	if _diving:
		return Vector2.ZERO
	_soar_left -= delta
	_feather_timer -= delta
	if _feather_timer <= 0.0:
		_feather_timer = 0.7 if phase_two else 0.95
		var aim := direction_to_player()
		for i in 3:
			shoot(aim.rotated((i - 1) * 0.3), 130.0, blade_damage, blade_texture, 0.0, Elements.Type.NATURE)
	if _soar_left <= 0.0:
		_dive()
		return Vector2.ZERO
	_orbit_angle += delta * 1.1
	var target := _player.global_position + Vector2.from_angle(_orbit_angle) * 110.0
	return global_position.direction_to(target) * move_speed * 2.4


func _dive() -> void:
	var at := _player.global_position if has_target() else global_position
	if arena_rect.has_area():
		at = at.clamp(arena_rect.position, arena_rect.end)
	telegraph_strike(at, 42.0, 0.85, dive_damage, Elements.Type.NATURE)
	global_position = at
	_diving = true
	set_status("급강하!", Color(1.0, 0.8, 0.5))
	_after(0.85, _land)


func _land() -> void:
	airborne = false
	_diving = false
	contact_damage = _base_contact
	_soar_cooldown = soar_interval * (0.75 if phase_two else 1.0)
	set_status("", Color.WHITE)
	for i in 12:
		shoot(Vector2.from_angle(TAU * i / 12.0), 120.0, blade_damage, blade_texture, 0.0, Elements.Type.NATURE)
	if _player != null:
		_player.shake_camera(5.0)


# ============================================================ 기믹 3: 회오리
func summon_tornadoes() -> void:
	_tornado_left = tornado_interval
	if not has_target():
		return
	for i in 2:
		var at := global_position + Vector2.from_angle(randf() * TAU) * 60.0
		if arena_rect.has_area():
			at = at.clamp(arena_rect.position, arena_rect.end)
		Tornado.spawn(self, at, roundi(tornado_damage * power), 9.0)
	Net.announce("회오리가 일어난다! 닿으면 휘말려 날아간다 (대시로 통과)", Color(0.7, 1.0, 0.85))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.BLADES:
			var aim := direction_to_player()
			breathe(aim, {"texture": BREATH_TEXTURE, "damage": blade_damage, "element": Elements.Type.NATURE,
				"speed": 165.0, "range": 170.0, "cone": 0.9, "duration": 0.8, "rate": 22.0, "grow": 2.2, "windup": 0.35})
			_after(0.75, func() -> void:
				if is_dead():
					return
				for i in 5:
					shoot(aim.rotated((i - 2) * 0.22), 150.0, blade_damage, blade_texture, 0.0, Elements.Type.NATURE))
			return 1.4
		Pattern.GUST:
			var dir := direction_to_player()
			for i in 9:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 15.0, 0.6 + 0.04 * i, gust_damage, Elements.Type.NATURE)
			return 1.2
		Pattern.CLAW:
			var dir2 := direction_to_player()
			for i in 3:
				telegraph_strike(get_hit_center() + dir2.rotated((i - 1) * 0.6) * 40.0, 20.0, 0.75, claw_damage, Elements.Type.NATURE)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	var target := FLIGHT_HEIGHT if airborne else 0.0
	_height = move_toward(_height, target, delta * 120.0)
	sprite.position.y = _base_sprite_pos.y - _height
	_hit_shape.position = _base_shape_pos - Vector2(0, _height)
	sprite.scale = _base_scale * (1.0 + _height / FLIGHT_HEIGHT * 0.12)


func _die() -> void:
	if get_wind() != null:
		wind.queue_free()
	for t in get_tree().get_nodes_in_group(&"tornadoes"):
		t.queue_free()
	super._die()


func _on_phase_two() -> void:
	Net.announce("제피로스: 폭풍이여, 모두 쓸어버려라! 회오리가 일어난다", Color(0.7, 1.0, 0.85))
	_tornado_left = 1.0
