class_name Mushroom
extends Enemy
## 포자 버섯 (4스테이지): 느릿느릿 다가오다가 몸을 움츠린 뒤 사방으로 독 포자를 뿜는다.
## 포자에 맞으면 피해 + 잠깐 느려짐.

enum State { WALK, PUFF_WINDUP, RECOVER }

@export var spore_texture: Texture2D
@export var spore_damage: int = 16
@export var spore_count: int = 8
@export var spore_speed: float = 80.0
@export var spore_slow: float = 0.8
@export var puff_interval: float = 2.6
@export var puff_windup: float = 0.5
@export var puff_range: float = 170.0

var _state: State = State.WALK
var _state_timer: float = 0.0
var _base_sprite_y: float = 0.0


func _ready() -> void:
	super._ready()
	_base_sprite_y = sprite.position.y
	_state_timer = randf_range(1.0, puff_interval)


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.WALK:
			if _state_timer <= 0.0 and distance_to_player() <= puff_range:
				_state = State.PUFF_WINDUP
				_state_timer = puff_windup
				return Vector2.ZERO
			return global_position.direction_to(_player.global_position) * move_speed
		State.PUFF_WINDUP:
			if _state_timer <= 0.0:
				_puff()
				_state = State.RECOVER
				_state_timer = 0.4
			return Vector2.ZERO
		State.RECOVER:
			if _state_timer <= 0.0:
				_state = State.WALK
				_state_timer = puff_interval
			return Vector2.ZERO
	return Vector2.ZERO


func _puff() -> void:
	var offset := randf() * TAU
	for i in spore_count:
		shoot(Vector2.RIGHT.rotated(offset + TAU * i / spore_count), spore_speed, spore_damage, spore_texture, spore_slow, Elements.Type.NATURE)
	Fx.burst(self, get_hit_center(), Color(0.75, 0.55, 0.95), 12, 50.0, 0.6, Vector2(0, -20))


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	match _state:
		State.PUFF_WINDUP:
			var t := 1.0 - _state_timer / puff_windup
			sprite.scale = Vector2(1.0 + 0.25 * t, 1.0 - 0.2 * t)
			sprite.position.y = _base_sprite_y + 2.0 * t
		_:
			sprite.scale = Vector2.ONE
			sprite.position.y = _base_sprite_y - absf(sin(_anim_time * 6.0)) * 1.0
