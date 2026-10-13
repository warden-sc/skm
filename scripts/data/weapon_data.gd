class_name WeaponData
extends ItemData
## 무기 데이터.
## - 근접 무기(검/단검): 투사체 없이 조준 방향 부채꼴(melee_range, melee_arc_degrees) 안의 적을 즉시 타격
## - 원거리 무기(활/지팡이): ProjectilePool 에서 투사체 발사

enum WeaponType { SWORD, BOW, STAFF, DAGGER }

const TYPE_NAMES := {
	WeaponType.SWORD: "검",
	WeaponType.BOW: "활",
	WeaponType.STAFF: "지팡이",
	WeaponType.DAGGER: "단검",
}

@export var weapon_type: WeaponType = WeaponType.SWORD
## 휘두르기 이펙트 / 투사체 색
@export var effect_color: Color = Color.WHITE

@export_group("Damage")
@export var damage: int = 5
@export_range(0.0, 1.0) var crit_chance: float = 0.05
@export var crit_multiplier: float = 1.5
@export var knockback: float = 120.0
## 다음 공격까지의 대기 시간(초)
@export var attack_cooldown: float = 0.35

@export_group("Melee")
## 근접 공격이 닿는 거리(px, 플레이어 중심 기준)
@export var melee_range: float = 26.0
## 근접 공격 부채꼴 전체 각도(도)
@export var melee_arc_degrees: float = 110.0

@export_group("Ranged")
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


func is_melee() -> bool:
	return weapon_type == WeaponType.SWORD or weapon_type == WeaponType.DAGGER


## 실제 1타의 데미지를 굴립니다. (치명타 포함)
func roll_damage(multiplier: float = 1.0) -> Dictionary:
	var amount := float(damage) * multiplier
	var is_crit := randf() < crit_chance
	if is_crit:
		amount *= crit_multiplier
	return {"amount": maxi(1, roundi(amount)), "crit": is_crit}


## 대략적인 단일 대상 초당 데미지 (상점 비교용)
func get_dps() -> float:
	var avg_hit := float(damage) * (1.0 + crit_chance * (crit_multiplier - 1.0))
	var hits := 1 if is_melee() else maxi(projectiles_per_shot, 1)
	return avg_hit * hits / maxf(attack_cooldown, 0.01)


func get_summary() -> String:
	return "%s · ATK %d · DPS %.0f" % [TYPE_NAMES.get(weapon_type, "?"), damage, get_dps()]


func get_stat_text() -> String:
	var lines := PackedStringArray()
	lines.append("[%s] %s (%s)" % [get_rarity_name(), TYPE_NAMES.get(weapon_type, "?"), "근접" if is_melee() else "원거리"])
	lines.append("공격력 %d  쿨타임 %.2fs  치명타 %d%% (x%.1f)" % [damage, attack_cooldown, roundi(crit_chance * 100.0), crit_multiplier])
	if is_melee():
		lines.append("리치 %d  범위 %d°  (범위 안의 모든 적 타격)" % [roundi(melee_range), roundi(melee_arc_degrees)])
	else:
		lines.append("x%d발  관통 %d  사거리 %d" % [maxi(projectiles_per_shot, 1), pierce, roundi(projectile_range)])
	lines.append("DPS 약 %.1f" % get_dps())
	return "\n".join(lines)
