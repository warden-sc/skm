class_name Goblin
extends Enemy
## 고블린: 지그재그로 접근하다가 가까워지면 잠깐 멈칫(예고) 후 돌진합니다.

enum State { CHASE, WINDUP, LUNGE, RECOVER }

@export var lunge_range: float = 70.0
@export var windup_time: float = 0.4
@export var lunge_time: float = 0.25
@export var lunge_speed_multiplier: float = 4.0
@export var recover_time: float = 0.6

var _state: State = State.CHASE
var _state_timer: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	var to_player := _player.global_position - global_position
	_state_timer -= delta

	match _state:
		State.CHASE:
			if to_player.length() < lunge_range:
				_enter(State.WINDUP, windup_time)
				_lunge_dir = to_player.normalized()
				return Vector2.ZERO
			# 옆으로 흔들리며 접근 (탄을 피하는 느낌)
			var side := to_player.normalized().orthogonal() * sin(_anim_time * 5.0) * 0.6
			return (to_player.normalized() + side).normalized() * move_speed
		State.WINDUP:
			if _state_timer <= 0.0:
				_enter(State.LUNGE, lunge_time)
			return Vector2.ZERO
		State.LUNGE:
			if _state_timer <= 0.0:
				_enter(State.RECOVER, recover_time)
			return _lunge_dir * move_speed * lunge_speed_multiplier
		State.RECOVER:
			if _state_timer <= 0.0:
				_enter(State.CHASE, 0.0)
			return Vector2.ZERO
	return Vector2.ZERO


func _enter(state: State, duration: float) -> void:
	_state = state
	_state_timer = duration


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	match _state:
		State.WINDUP:
			sprite.position = Vector2(randf_range(-1.0, 1.0), -8.0)
			sprite.modulate = Color(1.0, 0.6, 0.6, sprite.modulate.a)
		State.LUNGE:
			sprite.position = Vector2(0.0, -8.0)
			sprite.modulate = Color(1, 1, 1, sprite.modulate.a)
		_:
			sprite.position = Vector2(0.0, -8.0 - absf(sin(_anim_time * 12.0)) * 1.5)
			sprite.modulate = Color(1, 1, 1, sprite.modulate.a)
