class_name PotionData
extends ItemData
## 회복 포션 (소모품). 장비와 달리 여러 개를 가질 수 있고(GameManager.potions 에 개수로 보관),
## 사용하면 사라집니다. 회복량 = heal_amount + 최대 체력 x heal_percent

@export_group("Heal")
@export var heal_amount: int = 300
@export_range(0.0, 1.0) var heal_percent: float = 0.0
## 상점에서 살 수 있게 되는 스테이지 (포션은 등급 구간과 따로)
@export var unlock_stage: int = 1
## false 면 [H] 자동 선택에서 빠짐 (고대 용의 피 — 따로 [C] 키)
@export var auto_use: bool = true
## 마신 뒤 붙는 효과 (duration 초): 초당 최대 체력의 regen_percent 회복 · 공격력 +buff_attack · 받는 피해 -buff_reduction
@export var buff_duration: float = 0.0
@export var regen_percent: float = 0.0
@export var buff_attack: float = 0.0
@export var buff_reduction: float = 0.0
## true 면 화상 · 독 · 감속 · 방어력 감소 같은 상태 이상을 모두 씻어 냄
@export var cleanse: bool = false
@export var input_action: StringName = &""


func get_unlock_stage() -> int:
	return unlock_stage


func get_heal(max_hp: int) -> int:
	return heal_amount + roundi(max_hp * heal_percent)


func _heal_text() -> String:
	var parts := PackedStringArray()
	if heal_amount > 0:
		parts.append("+%d" % heal_amount)
	if heal_percent >= 1.0:
		parts.append("체력 전부")
	elif heal_percent > 0.0:
		parts.append("최대 체력의 %d%%" % roundi(heal_percent * 100.0))
	return " ".join(parts)


func _buff_text() -> String:
	if buff_duration <= 0.0:
		return ""
	var parts := PackedStringArray()
	if regen_percent > 0.0:
		parts.append("초당 최대 체력의 %d%% 재생" % roundi(regen_percent * 100.0))
	if buff_attack > 0.0:
		parts.append("공격력 +%d%%" % roundi(buff_attack * 100.0))
	if buff_reduction > 0.0:
		parts.append("받는 피해 -%d%%" % roundi(buff_reduction * 100.0))
	return "%d초 동안 %s" % [roundi(buff_duration), " · ".join(parts)]


func get_summary() -> String:
	var extra := _buff_text()
	return "포션 · 체력 회복 %s%s" % [_heal_text(), " · " + extra if extra != "" else ""]


func get_stat_text() -> String:
	var key := "[C] 사용" if not auto_use else "[H] 사용"
	var text := "[%s] 회복 포션  (%s · 종류별 최대 %d개)\n체력 회복 %s" % [get_rarity_name(), key, GameManager.POTION_MAX_STACK, _heal_text()]
	if _buff_text() != "":
		text += "\n" + _buff_text()
	if cleanse:
		text += "\n화상 · 독 · 감속 · 방어력 감소 등 상태 이상을 모두 씻어 냄"
	return text
