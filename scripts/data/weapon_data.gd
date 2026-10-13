class_name WeaponData
extends Resource
## 무기 1종의 모든 수치를 담는 데이터 리소스.
## res://data/weapons/*.tres 로 저장하고 인스펙터에서 바로 밸런싱합니다.

enum WeaponType { SWORD, BOW, STAFF, DAGGER }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_COLORS := {
	Rarity.COMMON: Color(0.85, 0.85, 0.85),
	Rarity.RARE: Color(0.35, 0.65, 1.0),
	Rarity.EPIC: Color(0.75, 0.45, 1.0),
	Rarity.LEGENDARY: Color(1.0, 0.75, 0.25),
}
const RARITY_NAMES := {
	Rarity.COMMON: "일반",
	Rarity.RARE: "희귀",
	Rarity.EPIC: "영웅",
	Rarity.LEGENDARY: "전설",
}
const TYPE_NAMES := {
	WeaponType.SWORD: "검",
	WeaponType.BOW: "활",
	WeaponType.STAFF: "지팡이",
	WeaponType.DAGGER: "단검",
}

@export var id: StringName = &""
@export var display_name: String = "무기"
@export_multiline var description: String = ""
@export var weapon_type: WeaponType = WeaponType.SWORD
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D
@export var projectile_texture: Texture2D
@export var projectile_color: Color = Color.WHITE

@export_group("Damage")
@export var damage: int = 5
@export_range(0.0, 1.0) var crit_chance: float = 0.05
@export var crit_multiplier: float = 1.5
@export var knockback: float = 120.0

@export_group("Fire")
## 다음 공격까지의 대기 시간(초)
@export var attack_cooldown: float = 0.35
@export var projectile_speed: float = 300.0
## 투사체가 날아가는 최대 거리(px) - 검기는 짧게, 활은 길게
@export var projectile_range: float = 160.0
@export var projectiles_per_shot: int = 1
## 여러 발 발사 시 퍼지는 전체 각도(도)
@export var spread_degrees: float = 0.0
## 관통 횟수 (0 = 첫 적에 맞으면 소멸)
@export var pierce: int = 0
@export var projectile_scale: float = 1.0

@export_group("Shop")
@export var price: int = 50


## 실제 1발의 데미지를 굴립니다. (치명타 포함)
func roll_damage(multiplier: float = 1.0) -> Dictionary:
	var amount := float(damage) * multiplier
	var is_crit := randf() < crit_chance
	if is_crit:
		amount *= crit_multiplier
	return {"amount": maxi(1, roundi(amount)), "crit": is_crit}


## 대략적인 초당 데미지 (상점 비교용)
func get_dps() -> float:
	var avg_hit := float(damage) * (1.0 + crit_chance * (crit_multiplier - 1.0))
	return avg_hit * maxi(projectiles_per_shot, 1) / maxf(attack_cooldown, 0.01)


func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func get_sell_value() -> int:
	@warning_ignore("integer_division")
	return maxi(5, price / 4)


func get_stat_text() -> String:
	var lines := PackedStringArray()
	lines.append("[%s] %s" % [RARITY_NAMES.get(rarity, "?"), TYPE_NAMES.get(weapon_type, "?")])
	lines.append("공격력 %d  x%d발  쿨타임 %.2fs" % [damage, maxi(projectiles_per_shot, 1), attack_cooldown])
	lines.append("치명타 %d%% (x%.1f)  관통 %d  사거리 %d" % [roundi(crit_chance * 100.0), crit_multiplier, pierce, roundi(projectile_range)])
	lines.append("DPS 약 %.1f" % get_dps())
	return "\n".join(lines)
