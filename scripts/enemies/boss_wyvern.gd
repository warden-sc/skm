class_name BossWyvern
extends PatternBoss
## 8스테이지 보스: 와이번
##   BREATH : 화염 브레스 — 입에 불이 모였다가 플레이어 쪽으로 불길을 뿜으며 고개를 휘두름 (맞으면 화상)
##   TAIL   : 꼬리 휘두르기 (자기 주변 큰 장판)
##   BITE   : 물어뜯기 돌진
##
## [기믹] 비행: flight_interval 마다 공중으로 날아오름 (flight_time 동안)
##   - 공중에서는 활로만 맞힐 수 있음 (근접·지팡이 마법은 닿지 않음 → "공중! 활만 닿음")
##   - 공중에서 플레이어 위를 돌며 화염탄을 떨어뜨림 (예고 장판)
##   - 끝나면 플레이어 자리로 급강하 (착지 예고 장판 후 내려찍기)
## 체력 50% 이하: 더 자주, 더 오래 날아오름

enum Pattern { BREATH, TAIL, BITE }

const BREATH_TEXTURE := preload("res://assets/sprites/projectiles/breath_fire.png")

const FLIGHT_HEIGHT := 46.0

@export var fireball_texture: Texture2D
@export var breath_damage: int = 30
@export var tail_damage: int = 42
@export var bomb_damage: int = 36
@export var dive_damage: int = 52
@export var flight_interval: float = 12.0
@export var flight_time: float = 6.0

var _flight_cooldown: float = 0.0
var _flight_left: float = 0.0
var _bomb_timer: float = 0.0
var _height: float = 0.0
var _orbit_angle: float = 0.0
var _bite_dir: Vector2 = Vector2.ZERO
var _biting: bool = false
var _diving: bool = false
var _base_shape_pos: Vector2


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BREATH, Pattern.TAIL, Pattern.BITE, Pattern.BREATH, Pattern.BITE]
	_flight_cooldown = flight_interval * 0.6
	_base_shape_pos = _hit_shape.position


func is_flying() -> bool:
	return airborne


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	if airborne:
		return _flight_velocity(delta)
	_flight_cooldown -= delta
	if _flight_cooldown <= 0.0 and not is_casting():
		take_off()
		return Vector2.ZERO
	return super._get_move_velocity(delta)


func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.BREATH:
			_breath()
			return 1.5
		Pattern.TAIL:
			telegraph_strike(get_hit_center(), 58.0, 0.85, tail_damage, Elements.Type.EARTH)
			return 1.3
		Pattern.BITE:
			_biting = false
			_after(0.5, func() -> void:
				if not is_dead() and has_target():
					_bite_dir = direction_to_player()
					_biting = true)
			_after(1.0, func() -> void: _biting = false)
			return 1.3
	return 1.0


func _casting_velocity(_delta: float) -> Vector2:
	return _bite_dir * move_speed * 5.5 if _biting else Vector2.ZERO


func _breath() -> void:
	if is_dead() or not has_target():
		return
	# 고개를 왼쪽 → 오른쪽으로 휘두르며 0.9초 동안 불길
	breathe(direction_to_player(), {"texture": BREATH_TEXTURE, "damage": breath_damage, "element": Elements.Type.FIRE,
		"speed": 150.0, "range": 140.0, "cone": 0.35, "sweep": 0.9, "duration": 0.9, "rate": 26.0, "grow": 2.6})


# ============================================================ 기믹: 비행
## 공중으로 날아오름 → 활로만 맞힐 수 있음
func take_off() -> void:
	if airborne or is_dead():
		return
	airborne = true
	_biting = false
	_flight_left = flight_time * (1.25 if phase_two else 1.0)
	_bomb_timer = 0.8
	_orbit_angle = randf() * TAU
	set_status("비행 중: 활로만 공격 가능!", Color(0.7, 0.85, 1.0))
	Net.announce("와이번이 날아올랐다! 공중에서는 활로만 공격할 수 있다", Color(0.7, 0.85, 1.0))
	Fx.burst(self, global_position, Color(0.8, 0.75, 0.6), 20, 60.0, 0.6, Vector2(0, 40), 1.3)


func _flight_velocity(delta: float) -> Vector2:
	if _diving:
		return Vector2.ZERO
	_flight_left -= delta
	_bomb_timer -= delta
	if _bomb_timer <= 0.0:
		_bomb_timer = 0.9 if phase_two else 1.2
		telegraph_strike(_player.global_position, 24.0, 0.9, bomb_damage, Elements.Type.FIRE)
	if _flight_left <= 0.0:
		_dive()
		return Vector2.ZERO
	_orbit_angle += delta * 1.2
	var target := _player.global_position + Vector2.from_angle(_orbit_angle) * 90.0
	return global_position.direction_to(target) * move_speed * 2.2


## 비행 끝: 플레이어 자리로 급강하
func _dive() -> void:
	var at := _player.global_position if has_target() else global_position
	if arena_rect.has_area():
		at = at.clamp(arena_rect.position, arena_rect.end)
	telegraph_strike(at, 40.0, 0.8, dive_damage, Elements.Type.EARTH)
	global_position = at
	_flight_left = 0.0
	_diving = true
	_after(0.8, _land)
	set_status("급강하!", Color(1.0, 0.6, 0.4))


func _land() -> void:
	airborne = false
	_diving = false
	_flight_cooldown = flight_interval * (0.75 if phase_two else 1.0)
	set_status("", Color.WHITE)
	cast(Pattern.TAIL)
	if _player != null:
		_player.shake_camera(5.0)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	var target := FLIGHT_HEIGHT if airborne else 0.0
	_height = move_toward(_height, target, delta * 120.0)
	sprite.position.y = _base_sprite_pos.y - _height
	_hit_shape.position = _base_shape_pos - Vector2(0, _height)  # 공중에 뜬 몸을 쏘면 맞도록 판정도 함께 이동
	sprite.scale = Vector2.ONE * (1.0 + _height / FLIGHT_HEIGHT * 0.15)


func _on_phase_two() -> void:
	Net.announce("와이번이 포효한다!", Color(1.0, 0.5, 0.35))
	take_off()
