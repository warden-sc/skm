class_name AccessoryData
extends ItemData
## 장신구 데이터. 인벤토리의 장신구 칸(팔찌 / 반지 / 펜던트 각 1칸)에 장착합니다.
## 모든 무기에 공통으로 적용됩니다.
##
## - 팔찌  : 치명타 피해 + 방어력 관통(방깍)
## - 반지  : 치명타 확률 + 공격력
## - 펜던트: 최대 체력 + 체력 재생 (화상 같은 지속 피해를 버티는 데 유용)

enum SlotType { BRACELET, RING, PENDANT }

const SLOT_NAMES := ["팔찌", "반지", "펜던트"]

@export var slot_type: SlotType = SlotType.RING

@export_group("Bracelet")
## 치명타 피해 배율 증가 (0.3 = 치명타 피해 +30%)
@export var crit_damage_bonus: float = 0.0
## 방어력 관통: 적 방어력을 이만큼 무시합니다.
@export var armor_pen: int = 0

@export_group("Ring")
## 치명타 확률 증가 (0.05 = +5%)
@export_range(0.0, 1.0) var crit_chance_bonus: float = 0.0
## 공격력 증가 (0.1 = +10%)
@export var attack_bonus: float = 0.0

@export_group("Pendant")
@export var bonus_max_hp: int = 0
## 초당 체력 재생량
@export var hp_regen: float = 0.0


func get_slot_name() -> String:
	return SLOT_NAMES[slot_type]


func _stat_parts(long_form: bool) -> PackedStringArray:
	var parts := PackedStringArray()
	if crit_damage_bonus > 0.0:
		parts.append(("치명타 피해 +%d%%" if long_form else "치피 +%d%%") % roundi(crit_damage_bonus * 100.0))
	if armor_pen > 0:
		parts.append(("방어력 관통(방깍) %d" if long_form else "방깍 %d") % armor_pen)
	if crit_chance_bonus > 0.0:
		parts.append(("치명타 확률 +%d%%" if long_form else "치확 +%d%%") % roundi(crit_chance_bonus * 100.0))
	if attack_bonus > 0.0:
		parts.append(("공격력 +%d%%" if long_form else "공격 +%d%%") % roundi(attack_bonus * 100.0))
	if bonus_max_hp > 0:
		parts.append(("최대 체력 +%d" if long_form else "HP +%d") % bonus_max_hp)
	if hp_regen > 0.0:
		parts.append(("체력 재생 초당 +%.1f" if long_form else "재생 %.1f/s") % hp_regen)
	return parts


func get_summary() -> String:
	return get_slot_name() + " · " + " · ".join(_stat_parts(false))


func get_stat_text() -> String:
	var lines := PackedStringArray(["[%s] %s  (장신구 칸에 장착, 모든 무기에 적용)" % [get_grade_text(), get_slot_name()]])
	lines.append_array(_stat_parts(true))
	return "\n".join(lines)
