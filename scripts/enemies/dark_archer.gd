class_name DarkArcher
extends Enemy
## 궁수 (5스테이지): 거리를 벌리며 옆으로 움직이다가, 활을 당겨(빨간 조준선 예고) 빠른 화살을 쏜다.
## 세 번째 사격마다 3발 부채꼴. 너무 가까워지면 뒤로 물러남.

enum State { STRAFE, DRAW, RECOVER }

@export var arrow_texture: Texture2D
@export var arrow_damage: int = 24
@export var arrow_speed: float = 230.0
@export var keep_distance: float = 130.0
@export var draw_time: float = 0.7
@export var shot_interval: float = 1.6

var _state: State = State.STRAFE
var _state_timer: float = 0.0
var _orbit_sign: float = 1.0
var _shots: int = 0
var _aim: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super._ready()
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0
	_state_timer = randf_range(0.8, shot_interval)


func _get_move_velocity(delta: float) -> Vector2:
	queue_redraw()
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.STRAFE:
			if _state_timer <= 0.0:
				_state = State.DRAW
				_state_timer = draw_time
				return Vector2.ZERO
			var away := _player.global_position.direction_to(global_position)
			var dist := distance_to_player()
			var radial := away * (1.0 if dist < keep_distance else -1.0) * (0.0 if absf(dist - keep_distance) < 15.0 else 1.0)
			return (radial + away.orthogonal() * _orbit_sign * 0.7).normalized() * move_speed
		State.DRAW:
			_aim = direction_to_player()
			if _state_timer <= 0.0:
				_fire()
				_state = State.RECOVER
				_state_timer = 0.35
			return Vector2.ZERO
		State.RECOVER:
			if _state_timer <= 0.0:
				_state = State.STRAFE
				_state_timer = shot_interval
				_orbit_sign = -_orbit_sign if randf() < 0.4 else _orbit_sign
			return Vector2.ZERO
	return Vector2.ZERO


func is_drawing() -> bool:
	return _state == State.DRAW


func _fire() -> void:
	_shots += 1
	var spread := [0.0] if _shots % 3 != 0 else [-0.22, 0.0, 0.22]
	for a in spread:
		shoot(_aim.rotated(a), arrow_speed, arrow_damage, arrow_texture, 0.0, Elements.Type.DARK)


## 활을 당기는 동안 조준선 예고
func _draw() -> void:
	if _state != State.DRAW or is_dead():
		return
	var t := 1.0 - _state_timer / maxf(draw_time, 0.01)
	var from := to_local(get_hit_center())
	draw_line(from, from + _aim * 160.0, Color(1.0, 0.25, 0.35, 0.15 + 0.45 * t), 1.0)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if _state == State.DRAW:
		sprite.flip_h = _aim.x < 0.0
