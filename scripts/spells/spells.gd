class_name Spells
## 지팡이 마법 공용 헬퍼 (정적 함수만 있음).
##
## - cast_staff()      : 지팡이 종류(WeaponData.spell)에 맞게 마법 시전
##     · BOLT / FROST_NOVA / SLIME_POOL / FIREBALL : 조준한 곳까지 날아가 터지는 투사체 (적에 먼저 맞으면 그 자리에서)
##     · SLIME_METEOR : 조준한 곳에 거대 슬라임 낙하 (SkyStrike)
##     · STARFALL     : 조준한 곳 주변에 별똥별 여러 개 낙하 (첫 별은 정확히 조준점)
## - projectile_impact(): 지팡이 투사체가 터질 때 마법별 이펙트 + 범위 피해 + 장판
## - damage_area()     : 반경 안 적에게 범위 피해 (중심부는 100%, 바깥은 splash)
##
## 범위 피해(주변 피해)는 모든 지팡이가 explosion_damage_ratio(80%)로 같습니다.

## 중심부로 치는 반경 비율 (이 안은 100% 피해)
const CORE_RATIO := 0.4
## 조준점이 너무 가까울 때의 최소 사거리
const MIN_CAST_DISTANCE := 16.0


static func cast_staff(caster: Player, weapon: WeaponData, target: Vector2) -> bool:
	if caster == null or weapon == null:
		return false
	match weapon.spell:
		WeaponData.Spell.SLIME_METEOR:
			SkyStrike.spawn(caster, target, SkyStrike.Kind.SLIME, weapon, GameManager.roll_weapon_damage(weapon))
			return true
		WeaponData.Spell.STARFALL:
			var star_count := maxi(weapon.strike_count, 1)
			for i in star_count:
				var at := target
				if i > 0:
					at += Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf()) * weapon.strike_scatter
				SkyStrike.spawn(caster, at, SkyStrike.Kind.STAR, weapon, GameManager.roll_weapon_damage(weapon), weapon.strike_interval * i)
			return true
	var pool := ProjectilePool.find(caster.get_tree())
	if pool == null:
		return false
	var origin := caster.get_muzzle_position()
	var distance := clampf(origin.distance_to(target), MIN_CAST_DISTANCE, weapon.projectile_range)
	var base_dir := origin.direction_to(target)
	if base_dir == Vector2.ZERO:
		base_dir = caster.get_aim_direction()
	var count := maxi(weapon.projectiles_per_shot, 1)
	var spread := deg_to_rad(weapon.spread_degrees)
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var spec := ProjectileSpec.from_weapon(weapon, origin, base_dir.rotated(spread * t), GameManager.roll_weapon_damage(weapon))
		spec.max_distance = distance
		pool.spawn(spec)
	return true


## 지팡이 투사체가 터질 때 (적 명중 / 조준점 도착 / 벽). direct_target 은 이미 직격 피해를 받은 적.
static func projectile_impact(context: Node, spec: ProjectileSpec, at_global: Vector2, direct_target: Enemy) -> void:
	var weapon := spec.source_weapon
	var r := spec.explosion_radius
	var level := clampi(spec.fx_level, 0, 3)
	var slow := 0.0
	match weapon.spell:
		WeaponData.Spell.FROST_NOVA:
			Fx.frost_nova(context, at_global, r, level)
			slow = spec.slow_duration
		WeaponData.Spell.SLIME_POOL:
			Fx.slime_splash(context, at_global, r, level)
			GroundZone.spawn(context, at_global, GroundZone.Kind.SLIME, r, weapon.zone_duration, _tick_damage(spec, weapon), spec.armor_pen, 0.8)
		WeaponData.Spell.FIREBALL:
			Fx.fire_blast(context, at_global, r, level)
			GroundZone.spawn(context, at_global, GroundZone.Kind.FIRE, r * 0.75, weapon.zone_duration, _tick_damage(spec, weapon), spec.armor_pen)
			shake(context, 3.5)
		_:
			Fx.arcane_burst(context, at_global, spec.color, r, level)
	damage_area(context, at_global, r, spec.explosion_damage, spec.explosion_damage, spec.armor_pen, spec.knockback * 0.5, direct_target, slow)
	if direct_target != null and slow > 0.0 and not direct_target.is_dead():
		direct_target.apply_slow(0.45, slow)


## 반경 안의 적에게 피해. 중심부(CORE_RATIO) 안은 core_damage, 바깥은 splash_damage. 맞은 적 수를 반환.
static func damage_area(context: Node, center: Vector2, radius: float, core_damage: int, splash_damage: int,
		armor_pen: int, knockback: float, exclude: Enemy = null, slow_duration: float = 0.0, is_crit: bool = false) -> int:
	if context == null or not context.is_inside_tree():
		return 0
	var hits := 0
	for node in context.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy == exclude or enemy.is_dead():
			continue
		var offset := enemy.get_hit_center() - center
		if offset.length() > radius:
			continue
		var core := offset.length() <= radius * CORE_RATIO
		var push := offset.normalized() if offset != Vector2.ZERO else Vector2.ZERO
		enemy.take_damage(core_damage if core else splash_damage, push * knockback, is_crit and core, armor_pen)
		if slow_duration > 0.0 and not enemy.is_dead():
			enemy.apply_slow(0.45, slow_duration)
		hits += 1
	return hits


static func shake(context: Node, strength: float) -> void:
	if context == null or not context.is_inside_tree():
		return
	var player := context.get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.shake_camera(strength)


static func _tick_damage(spec: ProjectileSpec, weapon: WeaponData) -> int:
	if weapon.zone_tick_ratio <= 0.0:
		return 0
	return maxi(1, roundi(spec.damage * weapon.zone_tick_ratio))
