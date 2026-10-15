class_name Hellhound
extends Enemy
## 헬하운드 (2스테이지): 플레이어 주위를 빙빙 돌다가 불꽃을 흩뿌리며 물어뜯기 돌진.

enum State { CIRCLE, WINDUP, LUNGE, RECOVER }

@export var circle_distance: float = 70.0
@export var windup_time: float = 0.35
@export var lunge_time: float = 0.3
@export var lunge_speed_multiplier: float = 4.2
@export var recover_time: float = 0.45
## 돌진할 때 흩뿌리는 불티 속성 (NONE 이면 없음 — 숲 늑대)
@export var trail_element: Elements.Type = Elements.Type.FIRE

var _state: State = State.CIRCLE
var _state_timer: float = 0.0
var _orbit_sign: float = 1.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _trail_timer: float = 0.0


func _ready() -> void:
	super._ready()
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0
	_state_timer = randf_range(1.0, 2.0)


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.CIRCLE:
			if _state_timer <= 0.0:
				_state = State.WINDUP
				_state_timer = windup_time
				return Vector2.ZERO
			# 플레이어를 중심으로 원을 그리며 거리 유지
			var from_player := _player.global_position.direction_to(global_position)
			var target := _player.global_position + from_player.rotated(0.7 * _orbit_sign) * circle_distance
			return global_position.direction_to(target) * move_speed
		State.WINDUP:
			if _state_timer <= 0.0:
				_state = State.LUNGE
				_state_timer = lunge_time
				_lunge_dir = direction_to_player()
			return Vector2.ZERO
		State.LUNGE:
			_trail_timer -= delta
			if _trail_timer <= 0.0 and trail_element != Elements.Type.NONE:
				_trail_timer = 0.05
				Fx.burst(self, get_hit_center(), Elements.color_of(trail_element), 3, 25.0, 0.4, Elements.gravity_of(trail_element))
			if _state_timer <= 0.0:
				_state = State.RECOVER
				_state_timer = recover_time
			return _lunge_dir * move_speed * lunge_speed_multiplier
		State.RECOVER:
			if _state_timer <= 0.0:
				_state = State.CIRCLE
				_state_timer = randf_range(1.2, 2.2)
				_orbit_sign = -_orbit_sign
			return Vector2.ZERO
	return Vector2.ZERO


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	match _state:
		State.WINDUP:
			sprite.position = Vector2(randf_range(-1.0, 1.0), -8.0)
			sprite.scale = Vector2(1.1, 0.9)
		State.LUNGE:
			sprite.position = Vector2(0.0, -8.0)
			sprite.scale = Vector2(1.25, 0.85)
		_:
			sprite.position = Vector2(0.0, -8.0 - absf(sin(_anim_time * 16.0)) * 1.5)
			sprite.scale = Vector2.ONE
