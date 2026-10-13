class_name ShieldData
extends ItemData
## 방패 데이터. 무기와 별도 칸에 장착합니다.
##
## - defense        : 항상 적용되는 고정 피해 감소 (방패를 들고만 있어도)
## - 가드(우클릭)    : 정면 block_arc_degrees 안에서 오는 공격의 block_ratio 만큼을 가드 게이지로 대신 받음
## - 퍼펙트 가드     : 가드를 올린 직후 perfect_guard_window 초 안에 맞으면 피해 0 + 적 기절 + 탄 반사
## - 가드 게이지가 0 이 되면 가드 브레이크 (guard_break_time 동안 가드 불가)

@export_group("Defense")
@export var defense: int = 0
@export_range(0.0, 1.0) var block_ratio: float = 0.7
@export var block_arc_degrees: float = 110.0

@export_group("Guard")
@export var max_guard: float = 40.0
## 초당 가드 게이지 회복량 (가드를 내리고 있을 때)
@export var guard_regen: float = 14.0
@export var perfect_guard_window: float = 0.15
## 가드 중 이동속도 배율
@export_range(0.1, 1.0) var guard_move_multiplier: float = 0.55
@export var guard_break_time: float = 1.2


func get_summary() -> String:
	return "방패 · 막기 %d%% · 방어 %d" % [roundi(block_ratio * 100.0), defense]


func get_stat_text() -> String:
	var lines := PackedStringArray()
	lines.append("[%s] 방패  (우클릭: 가드)" % get_rarity_name())
	lines.append("막기 %d%%  방어 %d  가드 범위 %d°" % [roundi(block_ratio * 100.0), defense, roundi(block_arc_degrees)])
	lines.append("가드 게이지 %d (초당 +%d)  가드 중 이동 x%.2f" % [roundi(max_guard), roundi(guard_regen), guard_move_multiplier])
	lines.append("퍼펙트 가드 %.2f초 (탄 반사 + 적 기절)" % perfect_guard_window)
	return "\n".join(lines)
