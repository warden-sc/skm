class_name NightmareIllusion
extends Enemy
## 몽마 나이트메어의 환영 (29스테이지 기믹). 진짜와 똑같이 생겼지만 그림자가 없습니다.
## 플레이어 주위를 맴돌며 진짜인 척하다가, 맞으면 「환영!」 하고 흩어집니다 (피해를 주지 않음).

var _orbit_angle: float = 0.0
var _orbit_radius: float = 110.0


func _ready() -> void:
	super._ready()
	collision_mask = 0  # 몸으로 부딪혀도 피해 없음
	var shadow := get_node_or_null(^"Shadow") as CanvasItem
	if shadow != null:
		shadow.hide()  # 진짜와의 유일한 차이: 그림자가 없음
	_orbit_angle = randf() * TAU


func set_orbit(angle: float, radius: float) -> void:
	_orbit_angle = angle
	_orbit_radius = radius


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_orbit_angle += delta * 0.7
	var target := _player.global_position + Vector2.from_angle(_orbit_angle) * _orbit_radius
	return global_position.direction_to(target) * move_speed if global_position.distance_to(target) > 4.0 else Vector2.ZERO


func take_damage(_hit_amount: int, _hit_knockback: Vector2 = Vector2.ZERO, _hit_crit: bool = false, _hit_pen: int = 0) -> void:
	vanish(true)


## 흩어짐 (맞았을 때 / 환영 시간이 끝났을 때)
func vanish(hit: bool) -> void:
	if is_dead():
		return
	if hit:
		FloatingText.spawn(self, global_position + Vector2(0, -40), "환영!", Color(0.85, 0.7, 1.0), true)
	Fx.burst(self, get_hit_center(), Color(0.6, 0.4, 0.9), 12, 50.0, 0.4)
	despawn()
