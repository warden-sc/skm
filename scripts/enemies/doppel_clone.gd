class_name DoppelClone
extends Enemy
## 도플갱어의 분신 (15스테이지 보스 2페이즈). 거울이 살아 있는 동안 도플갱어가 최대 5개까지 불러냅니다.
## 플레이어 주위를 맴돌며 가끔 거울 파편을 쏩니다. 진짜 도플갱어가 분신들 사이를 오가며 자리를 바꿉니다.
## 거울이 깨지면 모든 분신이 사라집니다.

@export var shard_texture: Texture2D
@export var shard_damage: int = 22
@export var orbit_distance: float = 90.0
@export var fire_interval: float = 2.6

var _orbit_angle: float = 0.0
var _fire_timer: float = 1.5


func _ready() -> void:
	super._ready()
	_orbit_angle = randf() * TAU
	_fire_timer = randf_range(1.0, fire_interval)
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 0.85, 0.3)


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_orbit_angle += delta * 0.8
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		shoot(direction_to_player(), 130.0, shard_damage, shard_texture, 0.0, Elements.Type.ARCANE)
	var target := _player.global_position + Vector2.from_angle(_orbit_angle) * orbit_distance
	return global_position.direction_to(target) * move_speed if global_position.distance_to(target) > 4.0 else Vector2.ZERO


## 거울이 깨지면 조각처럼 흩어지며 사라짐
func shatter() -> void:
	if is_dead():
		return
	Fx.burst(self, get_hit_center(), Color(0.8, 0.75, 1.0), 10, 60.0, 0.4)
	despawn()
