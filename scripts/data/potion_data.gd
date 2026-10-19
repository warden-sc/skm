class_name PotionData
extends ItemData
## 회복 포션 (소모품). 장비와 달리 여러 개를 가질 수 있고(GameManager.potions 에 개수로 보관),
## 사용하면 사라집니다. 회복량 = heal_amount + 최대 체력 x heal_percent

@export_group("Heal")
@export var heal_amount: int = 300
@export_range(0.0, 1.0) var heal_percent: float = 0.0
## 상점에서 살 수 있게 되는 스테이지 (포션은 등급 구간과 따로)
@export var unlock_stage: int = 1


func get_unlock_stage() -> int:
	return unlock_stage


func get_heal(max_hp: int) -> int:
	return heal_amount + roundi(max_hp * heal_percent)


func _heal_text() -> String:
	var parts := PackedStringArray()
	if heal_amount > 0:
		parts.append("+%d" % heal_amount)
	if heal_percent > 0.0:
		parts.append("최대 체력의 %d%%" % roundi(heal_percent * 100.0))
	return " ".join(parts)


func get_summary() -> String:
	return "포션 · 체력 회복 %s" % _heal_text()


func get_stat_text() -> String:
	return "[%s] 회복 포션  ([H] 사용 · 종류별 최대 %d개)\n체력 회복 %s" % [get_rarity_name(), GameManager.POTION_MAX_STACK, _heal_text()]
