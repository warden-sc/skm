class_name HydraStump
extends BossPart
## 잘린 히드라의 목 (41스테이지 기믹). 체력이 없고, 맞으면 히드라에게 알림 →
## 「불꽃 부여」 중인 공격이면 지져져서 다시 자라지 않음 (BossHydra.on_stump_hit).


func take_damage(_hit_amount: int, _hit_knockback: Vector2 = Vector2.ZERO, _hit_crit: bool = false, _hit_pen: int = 0) -> void:
	if is_dead():
		return
	_hit_flash = 0.08
	if boss != null and is_instance_valid(boss) and boss.has_method(&"on_stump_hit"):
		boss.call(&"on_stump_hit", self)
