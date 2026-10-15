class_name HeavyKnight
extends Enemy
## 중기사 (5스테이지): 거대한 방패를 든 느리고 단단한 기사.
## - 방패: 정면(플레이어를 바라보는 쪽)에서 들어오는 공격은 shield_block 만큼 막음 → 옆이나 뒤를 노려야 함
## - 가까이 오면 방패를 치켜든 뒤(예고) 짧게 돌진하는 방패 강타

enum State { ADVANCE, BASH_WINDUP, BASH, RECOVER }

@export var shield_block: float = 0.7
## 이 각도(도) 안쪽에서 들어온 공격을 막음 (정면 기준 전체 각도)
@export var shield_arc_degrees: float = 120.0
@export var bash_trigger_range: float = 46.0
@export var bash_windup: float = 0.6
@export var bash_time: float = 0.25
@export var bash_speed_multiplier: float = 6.0

var _state: State = State.ADVANCE
var _state_timer: float = 0.0
var _facing: Vector2 = Vector2.LEFT
var _bash_dir: Vector2 = Vector2.ZERO
var _base_sprite_pos: Vector2


func _ready() -> void:
	super._ready()
	_base_sprite_pos = sprite.position


func get_facing() -> Vector2:
	return _facing


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	if _state != State.BASH:
		_facing = _facing.slerp(direction_to_player(), 1.0 - exp(-6.0 * delta)).normalized()
	match _state:
		State.ADVANCE:
			if distance_to_player() <= bash_trigger_range:
				_state = State.BASH_WINDUP
				_state_timer = bash_windup
				return Vector2.ZERO
			return global_position.direction_to(_player.global_position) * move_speed
		State.BASH_WINDUP:
			if _state_timer <= 0.0:
				_state = State.BASH
				_state_timer = bash_time
				_bash_dir = direction_to_player()
			return Vector2.ZERO
		State.BASH:
			if _state_timer <= 0.0:
				_state = State.RECOVER
				_state_timer = 0.8
			return _bash_dir * move_speed * bash_speed_multiplier
		State.RECOVER:
			if _state_timer <= 0.0:
				_state = State.ADVANCE
			return Vector2.ZERO
	return Vector2.ZERO


## knockback 은 공격이 밀어내는 방향(공격자 → 나). 정면에서 온 공격이면 방패로 막음
func is_blocking_from(knockback: Vector2) -> bool:
	if knockback == Vector2.ZERO or _state == State.RECOVER or is_stunned():
		return false
	var from_dir := -knockback.normalized()
	return absf(_facing.angle_to(from_dir)) <= deg_to_rad(shield_arc_degrees) * 0.5


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_blocking_from(knockback) and not is_dead():
		amount = maxi(1, roundi(amount * (1.0 - shield_block)))
		knockback *= 0.2
		Fx.burst(self, get_hit_center() + _facing * 8.0, Color(0.85, 0.85, 1.0), 6, 40.0, 0.25)
		FloatingText.spawn(self, global_position + Vector2(0, -22), "막음", Color(0.7, 0.75, 0.9))
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _update_visual(_delta: float, _move: Vector2) -> void:
	sprite.flip_h = _facing.x < 0.0
	match _state:
		State.BASH_WINDUP:
			sprite.position = _base_sprite_pos + Vector2(-_facing.x * 2.0, 0.0)
		State.BASH:
			sprite.position = _base_sprite_pos + Vector2(_facing.x * 2.0, 0.0)
		_:
			sprite.position = _base_sprite_pos + Vector2(0.0, -absf(sin(_anim_time * 5.0)) * 1.0)
