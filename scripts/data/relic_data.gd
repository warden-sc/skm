class_name RelicData
extends ItemData
## 신화 사용 아이템 — 장착하지 않고 키를 눌러 사용, 쓰고 나면 cooldown 초 뒤에 다시 쓸 수 있음 (소모되지 않음)
##   원초의 불꽃 [Z]: 49스테이지 프로메테우스의 불씨를 50스테이지 헤파이스토스가 제련 (헤파이스토스 토벌 때)
##     duration 초 동안 공격력 +attack_bonus · 이동 속도 +move_bonus · 화상 면역
##     내 공격에 맞은 적이 불탐 — 0.5초마다 (그 일격 피해 × burn_ratio), burn_duration 초
##   최후의 나팔 [X]: 100스테이지 대천사 가브리엘 토벌 때 반지와 함께
##     나팔을 불면 하늘의 심판 — 모든 적 기절 stun_time 초 · 일반 몬스터는 최대 체력의 normal_damage_ratio,
##     보스는 boss_damage_ratio 만큼 피해 (방어력 무시) · 적의 탄 모두 사라짐 · 용사는 무적 invincible_time 초 + 체력 heal_ratio 회복

enum Effect { PRIMAL_FLAME, LAST_TRUMPET }

@export var effect: Effect = Effect.PRIMAL_FLAME
@export var cooldown: float = 60.0
## 입력 액션 이름과 화면에 보일 키
@export var input_action: StringName = &""
@export var key_label: String = ""

@export_group("원초의 불꽃")
@export var duration: float = 15.0
@export var attack_bonus: float = 0.3
@export var move_bonus: float = 0.1
@export var burn_ratio: float = 0.15
@export var burn_duration: float = 4.0

@export_group("최후의 나팔")
@export var normal_damage_ratio: float = 0.6
@export var boss_damage_ratio: float = 0.04
@export var stun_time: float = 3.0
@export var invincible_time: float = 3.0
@export var heal_ratio: float = 0.25


func get_summary() -> String:
	if effect == Effect.PRIMAL_FLAME:
		return "사용 [%s] · 공격 +%d%% · 적 화상 · 대기 %d초" % [key_label, roundi(attack_bonus * 100.0), roundi(cooldown)]
	return "사용 [%s] · 하늘의 심판 · 대기 %d초" % [key_label, roundi(cooldown)]


func get_stat_text() -> String:
	var lines := PackedStringArray(["[%s] 사용 아이템  ([%s] 키 · 소모되지 않고 %d초마다 다시 사용)" % [get_grade_text(), key_label, roundi(cooldown)]])
	if effect == Effect.PRIMAL_FLAME:
		lines.append("%d초 동안 공격력 +%d%% · 이동 속도 +%d%% · 화상 면역" % [roundi(duration), roundi(attack_bonus * 100.0), roundi(move_bonus * 100.0)])
		lines.append("내 공격에 맞은 적이 불탐: 0.5초마다 그 일격의 %d%% (%.0f초, 방어력 무시)" % [roundi(burn_ratio * 100.0), burn_duration])
	else:
		lines.append("모든 적 %.0f초 기절 · 일반 몬스터 최대 체력의 %d%% · 보스 %d%% 피해 (방어력 무시)" % [stun_time, roundi(normal_damage_ratio * 100.0), roundi(boss_damage_ratio * 100.0)])
		lines.append("적의 탄이 모두 사라지고, 용사는 %.0f초 무적 + 체력 %d%% 회복" % [invincible_time, roundi(heal_ratio * 100.0)])
	return "\n".join(lines)
