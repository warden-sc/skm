class_name WeaponData
extends ItemData
## 무기 데이터.
## - 근접 무기(검/단검): 투사체 없이 조준 방향 부채꼴(melee_range, melee_arc_degrees) 안의 적을 즉시 타격
## - 원거리 무기(활/지팡이): ProjectilePool 에서 투사체 발사
##   · 활      : windup_time 동안 시위를 당긴 뒤 발사
##   · 지팡이  : windup_time 동안 영창(chant_text) → 지팡이 구슬에 마력이 모인 뒤 시전
## - 무기 특화: 검 = 가장 높은 공격력 / 활 = 낮은 공격력 대신 빠른 공속 + 방어력 관통(방깍) / 지팡이 = 폭발 범위 공격
## - 등급이 높을수록(get_fx_level) 잔상 / 파티클 / 폭발 이펙트가 화려해집니다.

enum WeaponType { SWORD, BOW, STAFF, DAGGER }

const SPECIALTY_TEXT := {
	WeaponType.SWORD: "특화: 강력한 한 방 (가장 높은 공격력)",
	WeaponType.BOW: "특화: 빠른 공속 · 방어력 관통(방깍)",
	WeaponType.STAFF: "특화: 범위 공격 (명중 지점 폭발)",
	WeaponType.DAGGER: "특화: 빠른 연타 · 방어력 관통(방깍)",
}

const TYPE_NAMES := {
	WeaponType.SWORD: "검",
	WeaponType.BOW: "활",
	WeaponType.STAFF: "지팡이",
	WeaponType.DAGGER: "단검",
}

@export var weapon_type: WeaponType = WeaponType.SWORD
@export var element: Elements.Type = Elements.Type.NONE
## 휘두르기 이펙트 / 투사체 색
@export var effect_color: Color = Color.WHITE
## 손에 들었을 때의 그림 (활처럼 아이콘과 다른 모양일 때). 비워두면 icon 을 45° 돌려서 사용
@export var held_texture: Texture2D

@export_group("Damage")
@export var damage: int = 5
@export_range(0.0, 1.0) var crit_chance: float = 0.05
@export var crit_multiplier: float = 1.5
@export var knockback: float = 120.0
## 방어력 관통(방깍): 적 방어력을 이만큼 무시합니다.
@export var armor_pen: int = 0
## 다음 공격까지의 대기 시간(초)
@export var attack_cooldown: float = 0.35

@export_group("Melee")
## 근접 공격이 닿는 거리(px, 플레이어 중심 기준)
@export var melee_range: float = 26.0
## 근접 공격 부채꼴 전체 각도(도)
@export var melee_arc_degrees: float = 110.0

@export_group("Ranged")
## 발사 전 준비 시간: 활 = 시위 당기기, 지팡이 = 영창 (0 이면 즉시)
@export var windup_time: float = 0.0
## 지팡이 영창 대사 (머리 위에 표시)
@export var chant_text: String = ""
@export var projectile_texture: Texture2D
@export var projectile_speed: float = 300.0
## 투사체가 날아가는 최대 거리(px)
@export var projectile_range: float = 160.0
@export var projectiles_per_shot: int = 1
## 여러 발 발사 시 퍼지는 전체 각도(도)
@export var spread_degrees: float = 0.0
## 관통 횟수 (0 = 첫 적에 맞으면 소멸)
@export var pierce: int = 0
@export var projectile_scale: float = 1.0
## 0 보다 크면 명중/소멸 지점에서 폭발 (반경 안 모든 적에게 damage x explosion_damage_ratio)
@export var explosion_radius: float = 0.0
@export var explosion_damage_ratio: float = 0.6
## 0 보다 크면 맞은 적을 이 시간 동안 감속 (빙결)
@export var slow_duration: float = 0.0


func is_melee() -> bool:
	return weapon_type == WeaponType.SWORD or weapon_type == WeaponType.DAGGER


func is_bow() -> bool:
	return weapon_type == WeaponType.BOW


func is_staff() -> bool:
	return weapon_type == WeaponType.STAFF


## 실제 1타의 데미지를 굴립니다. (치명타 포함)
## crit_bonus / crit_damage_bonus: 반지·팔찌 등으로 더해지는 치명타 확률 / 치명타 배율
func roll_damage(multiplier: float = 1.0, crit_bonus: float = 0.0, crit_damage_bonus: float = 0.0) -> Dictionary:
	var amount := float(damage) * multiplier
	var is_crit := randf() < crit_chance + crit_bonus
	if is_crit:
		amount *= crit_multiplier + crit_damage_bonus
	return {"amount": maxi(1, roundi(amount)), "crit": is_crit}


## 대략적인 단일 대상 초당 데미지 (상점 비교용)
func get_dps() -> float:
	var avg_hit := float(damage) * (1.0 + crit_chance * (crit_multiplier - 1.0))
	var hits := 1 if is_melee() else maxi(projectiles_per_shot, 1)
	return avg_hit * hits / maxf(attack_cooldown + windup_time, 0.01)


func get_summary() -> String:
	var extra := ""
	if armor_pen > 0:
		extra += " · 방깍 %d" % armor_pen
	if explosion_radius > 0.0:
		extra += " · 범위"
	return "%s · ATK %d · DPS %.0f%s" % [TYPE_NAMES.get(weapon_type, "?"), damage, get_dps(), extra]


func get_stat_text() -> String:
	var lines := PackedStringArray()
	var element_text := "" if element == Elements.Type.NONE else " · %s 속성" % Elements.name_of(element)
	lines.append("[%s] %s (%s)%s" % [get_rarity_name(), TYPE_NAMES.get(weapon_type, "?"), "근접" if is_melee() else "원거리", element_text])
	lines.append(SPECIALTY_TEXT.get(weapon_type, ""))
	lines.append("공격력 %d  쿨타임 %.2fs  치명타 %d%% (x%.1f)" % [damage, attack_cooldown, roundi(crit_chance * 100.0), crit_multiplier])
	if armor_pen > 0:
		lines.append("방어력 관통(방깍) %d" % armor_pen)
	if is_melee():
		lines.append("리치 %d  범위 %d°  (범위 안의 모든 적 타격)" % [roundi(melee_range), roundi(melee_arc_degrees)])
	else:
		var prep := "시위 당기기" if is_bow() else "영창"
		lines.append("x%d발  관통 %d  사거리 %d  %s %.2fs" % [maxi(projectiles_per_shot, 1), pierce, roundi(projectile_range), prep, windup_time])
		if explosion_radius > 0.0:
			lines.append("범위 공격: 명중 지점 폭발 반경 %d (주변 적에게 %d%% 피해)" % [roundi(explosion_radius), roundi(explosion_damage_ratio * 100.0)])
		if slow_duration > 0.0:
			lines.append("적 감속 %.1f초" % slow_duration)
	lines.append("DPS 약 %.1f" % get_dps())
	return "\n".join(lines)
