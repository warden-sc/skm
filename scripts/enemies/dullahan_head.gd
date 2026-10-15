class_name DullahanHead
extends Enemy
## 듀라한이 던진 머리 (5스테이지 보스 기믹). 듀라한의 약점.
## - 플레이어 주위를 떠다니며 암흑탄을 쏜다
## - 방어력이 없어 잘 맞지만, 체력이 다 닳기 전에 제한 시간이 지나면 몸으로 돌아가 듀라한을 회복시킴
## - 쓰러뜨리면 듀라한이 무릎을 꿇고 약점이 드러남 (BossDullahan 이 처리)

@export var bolt_texture: Texture2D
@export var bolt_damage: int = 20
@export var orbit_distance: float = 80.0
@export var fire_interval: float = 1.2

var _fire_timer: float = 0.8
var _orbit_angle: float = 0.0


func _ready() -> void:
	super._ready()
	_orbit_angle = randf() * TAU


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_orbit_angle += delta * 1.4
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		var aim := direction_to_player()
		for a in [-0.18, 0.0, 0.18]:
			shoot(aim.rotated(a), 130.0, bolt_damage, bolt_texture, 0.0, Elements.Type.DARK)
	var target := _player.global_position + Vector2.from_angle(_orbit_angle) * orbit_distance
	return global_position.direction_to(target) * move_speed


func _update_visual(_delta: float, _move: Vector2) -> void:
	sprite.position = Vector2(0.0, -14.0 - sin(_anim_time * 4.0) * 3.0)
	sprite.rotation = sin(_anim_time * 2.0) * 0.15
