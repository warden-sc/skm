class_name Slime
extends Enemy
## 슬라임: 잠시 쉬었다가 플레이어 쪽으로 통통 튀어 이동합니다.

@export var rest_time: float = 0.55
@export var hop_time: float = 0.35
@export var hop_speed_multiplier: float = 2.4

var _hop_timer: float = 0.0
var _hopping: bool = false
var _hop_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	_hop_timer = randf() * rest_time


func _get_move_velocity(delta: float) -> Vector2:
	_hop_timer -= delta
	if _hop_timer <= 0.0:
		_hopping = not _hopping
		_hop_timer = hop_time if _hopping else rest_time
		if _hopping and has_target():
			_hop_dir = global_position.direction_to(_player.global_position).rotated(randf_range(-0.3, 0.3))
	if not _hopping or not has_target():
		return Vector2.ZERO
	return _hop_dir * move_speed * hop_speed_multiplier


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if _hopping:
		var t := 1.0 - _hop_timer / hop_time
		sprite.position.y = -8.0 - sin(t * PI) * 5.0
		sprite.scale = Vector2(0.9, 1.15)
	else:
		sprite.position.y = -8.0
		var squash := 1.0 + sin(_anim_time * 8.0) * 0.06
		sprite.scale = Vector2(squash, 2.0 - squash)
