class_name Orc
extends Enemy
## 오크 (2스테이지): 느리고 튼튼하다. 가까이 오면 곤봉을 치켜들고(장판 예고) 내려찍는다.

enum State { CHASE, SMASH, RECOVER }

@export var smash_trigger_range: float = 36.0
@export var smash_damage: int = 24
@export var smash_radius: float = 26.0
@export var smash_windup: float = 0.75
@export var recover_time: float = 0.7
## 내려찍기 장판 속성 / 맞으면 감속 시간 (트렌트: 자연 · 뿌리 휘감기)
@export var smash_element: Elements.Type = Elements.Type.EARTH
@export var smash_slow: float = 0.0

var _state: State = State.CHASE
var _state_timer: float = 0.0
var _base_sprite_y: float = 0.0


func _ready() -> void:
	super._ready()
	_base_sprite_y = sprite.position.y


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.CHASE:
			if distance_to_player() <= smash_trigger_range:
				_state = State.SMASH
				_state_timer = smash_windup
				var dir := direction_to_player()
				telegraph_strike(global_position + dir * 18.0, smash_radius, smash_windup, smash_damage, smash_element, smash_slow)
				return Vector2.ZERO
			return global_position.direction_to(_player.global_position) * move_speed
		State.SMASH:
			if _state_timer <= 0.0:
				_state = State.RECOVER
				_state_timer = recover_time
				if _player != null:
					_player.shake_camera(3.0)
			return Vector2.ZERO
		State.RECOVER:
			if _state_timer <= 0.0:
				_state = State.CHASE
			return Vector2.ZERO
	return Vector2.ZERO


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	match _state:
		State.SMASH:
			# 곤봉을 치켜드는 느낌으로 몸을 늘림
			var t := 1.0 - _state_timer / smash_windup
			sprite.position.y = _base_sprite_y - 3.0 * t
		State.RECOVER:
			sprite.position.y = _base_sprite_y + 1.0
		_:
			sprite.position.y = _base_sprite_y - absf(sin(_anim_time * 7.0)) * 1.0
