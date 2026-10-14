class_name ProjectileSpec
extends RefCounted
## ProjectilePool.spawn() 에 넘기는 "발사 명세서".
## 딕셔너리 대신 타입이 있는 객체를 써서 오타/타입 에러를 컴파일 단계에서 잡습니다.

enum Team { PLAYER, ENEMY }

var team: Team = Team.PLAYER
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: int = 1
var is_crit: bool = false
## 적 방어력을 이만큼 무시 (무기 + 팔찌 방어력 관통)
var armor_pen: int = 0
var max_distance: float = 200.0
var pierce: int = 0
var knockback: float = 0.0
var texture: Texture2D
var color: Color = Color.WHITE
var scale: float = 1.0
var element: Elements.Type = Elements.Type.NONE
## 이펙트 화려함 0(일반) ~ 3(전설): 꼬리 잔상 / 빛 / 명중 파티클 양
var fx_level: int = 0
## 0 보다 크면 명중/소멸 지점에서 폭발
var explosion_radius: float = 0.0
var explosion_damage: int = 0
## 0 보다 크면 맞은 대상 감속 (초)
var slow_duration: float = 0.0
## 플레이어 지팡이 투사체면 그 지팡이 (터질 때 마법별 이펙트·장판은 Spells.projectile_impact 가 처리)
var source_weapon: WeaponData


## 플레이어 무기 데이터로부터 1발 분량의 명세를 만듭니다.
## roll: { "amount", "crit", "armor_pen"(선택) } — 보통 GameManager.roll_weapon_damage(weapon)
static func from_weapon(weapon: WeaponData, from: Vector2, dir: Vector2, roll: Dictionary) -> ProjectileSpec:
	var spec := ProjectileSpec.new()
	spec.team = Team.PLAYER
	spec.origin = from
	spec.direction = dir
	spec.speed = weapon.projectile_speed
	spec.damage = roll["amount"]
	spec.is_crit = roll["crit"]
	spec.armor_pen = int(roll.get("armor_pen", weapon.armor_pen))
	spec.max_distance = weapon.projectile_range
	spec.pierce = weapon.pierce
	spec.knockback = weapon.knockback
	spec.texture = weapon.projectile_texture
	spec.color = weapon.effect_color
	spec.scale = weapon.projectile_scale
	spec.element = weapon.element
	spec.fx_level = weapon.get_fx_level()
	spec.explosion_radius = weapon.explosion_radius
	spec.explosion_damage = maxi(1, roundi(spec.damage * weapon.explosion_damage_ratio))
	spec.slow_duration = weapon.slow_duration
	if weapon.is_staff():
		spec.source_weapon = weapon
	return spec


## 적(보스 등) 탄막용 명세.
## slow: 맞으면 플레이어 감속 시간(빙결탄) / bullet_element: 명중 이펙트 색
static func enemy_bullet(from: Vector2, dir: Vector2, bullet_speed: float, bullet_damage: int, tex: Texture2D,
		slow: float = 0.0, bullet_element: Elements.Type = Elements.Type.NONE) -> ProjectileSpec:
	var spec := ProjectileSpec.new()
	spec.team = Team.ENEMY
	spec.origin = from
	spec.direction = dir
	spec.speed = bullet_speed
	spec.damage = bullet_damage
	spec.max_distance = 420.0
	spec.texture = tex
	spec.slow_duration = slow
	spec.element = bullet_element
	spec.fx_level = 1 if bullet_element != Elements.Type.NONE else 0
	if bullet_element != Elements.Type.NONE:
		spec.color = Elements.color_of(bullet_element).lightened(0.4)
	return spec
