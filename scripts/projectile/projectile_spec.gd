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
var max_distance: float = 200.0
var pierce: int = 0
var knockback: float = 0.0
var texture: Texture2D
var color: Color = Color.WHITE
var scale: float = 1.0


## 플레이어 무기 데이터로부터 1발 분량의 명세를 만듭니다.
static func from_weapon(weapon: WeaponData, from: Vector2, dir: Vector2, damage_multiplier: float) -> ProjectileSpec:
	var spec := ProjectileSpec.new()
	var roll := weapon.roll_damage(damage_multiplier)
	spec.team = Team.PLAYER
	spec.origin = from
	spec.direction = dir
	spec.speed = weapon.projectile_speed
	spec.damage = roll["amount"]
	spec.is_crit = roll["crit"]
	spec.max_distance = weapon.projectile_range
	spec.pierce = weapon.pierce
	spec.knockback = weapon.knockback
	spec.texture = weapon.projectile_texture
	spec.color = weapon.projectile_color
	spec.scale = weapon.projectile_scale
	return spec


## 적(보스 등) 탄막용 명세.
static func enemy_bullet(from: Vector2, dir: Vector2, bullet_speed: float, bullet_damage: int, tex: Texture2D) -> ProjectileSpec:
	var spec := ProjectileSpec.new()
	spec.team = Team.ENEMY
	spec.origin = from
	spec.direction = dir
	spec.speed = bullet_speed
	spec.damage = bullet_damage
	spec.max_distance = 420.0
	spec.texture = tex
	return spec
