class_name GemData
extends ItemData
## 보석 데이터. 인벤토리의 보석 칸(3개)에 박아 넣어 능력치를 올립니다.
## 모든 무기에 공통으로 적용됩니다.

@export_group("Bonus")
## 치명타 확률 증가 (0.05 = +5%)
@export_range(0.0, 1.0) var crit_chance_bonus: float = 0.05
## 치명타 피해 배율 증가 (0.3 = 치명타 피해 +30%)
@export var crit_damage_bonus: float = 0.0
## 공격력 증가 (0.1 = +10%)
@export var attack_bonus: float = 0.0


func get_summary() -> String:
	var parts := PackedStringArray()
	if crit_chance_bonus > 0.0:
		parts.append("치명 +%d%%" % roundi(crit_chance_bonus * 100.0))
	if crit_damage_bonus > 0.0:
		parts.append("치피 +%d%%" % roundi(crit_damage_bonus * 100.0))
	if attack_bonus > 0.0:
		parts.append("공격 +%d%%" % roundi(attack_bonus * 100.0))
	return "보석 · " + " · ".join(parts)


func get_stat_text() -> String:
	var lines := PackedStringArray(["[%s] 보석  (보석 칸에 장착, 모든 무기에 적용)" % get_rarity_name()])
	if crit_chance_bonus > 0.0:
		lines.append("치명타 확률 +%d%%" % roundi(crit_chance_bonus * 100.0))
	if crit_damage_bonus > 0.0:
		lines.append("치명타 피해 +%d%%" % roundi(crit_damage_bonus * 100.0))
	if attack_bonus > 0.0:
		lines.append("공격력 +%d%%" % roundi(attack_bonus * 100.0))
	return "\n".join(lines)
