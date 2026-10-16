class_name CrownEnemy
extends Enemy
## 옥좌 잃은 왕의 왕관 (10스테이지 보스 기믹). 왕의 머리 위에 떠 있으며 왕과 따로 체력이 있습니다.
## 왕관이 살아 있는 동안 왕은 주기적으로 「왕관의 가호」를 둘러 모든 공격을 막습니다.

var king: Enemy
var anchor_offset: Vector2 = Vector2(0, -52)


func _ready() -> void:
	super._ready()
	knockback_resistance = 1.0


func _get_move_velocity(delta: float) -> Vector2:
	queue_redraw()
	if king == null or not is_instance_valid(king) or king.is_dead():
		return Vector2.ZERO
	return (king.global_position + anchor_offset - global_position) / maxf(delta, 0.001)


func _update_visual(_delta: float, _move: Vector2) -> void:
	sprite.position = Vector2(0.0, -2.0 - sin(_anim_time * 3.0) * 1.5)


## 머리 위 작은 체력 바 (왕 체력과 따로)
func _draw() -> void:
	if is_dead():
		return
	var w := 26.0
	var ratio := float(hp) / float(maxi(max_hp, 1))
	draw_rect(Rect2(-w * 0.5, -14.0, w, 3.0), Color(0.1, 0.08, 0.05, 0.85))
	draw_rect(Rect2(-w * 0.5, -14.0, w * ratio, 3.0), Color(1.0, 0.82, 0.3))
