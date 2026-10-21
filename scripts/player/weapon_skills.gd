class_name WeaponSkills
## 무기 액티브 스킬 [Q] 의 실제 동작 · 연출 (AttackController.use_skill 이 부름).
## 스킬 id · 이름 · 배율 · 대기시간은 WeaponData.SKILLS, 무기 → 스킬은 WeaponData.get_skill_id.
##
##   레어(기본형)  whirlwind 회전 베기 · flurry 그림자 난무 · volley 화살비 · blast 대폭발
##   전설(진화형)  holy_tempest 성검 폭풍 · shadow_dance 그림자 무도 · meteor_rain 유성 화살비 · cataclysm 원소 붕괴
##   신화(전용)    abyss_descent 마왕강림(아바돈의 검) · helios 헬리오스의 심판(아폴론의 활) · meteor_swarm 메테오 스웜(대마법사의 지팡이)
##
## 피해는 모두 Enemy.hit / Spells.damage_area / 플레이어 투사체로 — 멀티플레이 참가자가 써도 방장 세계의 적이 맞음.
## 이펙트는 Fx (방장이 쓰면 참가자 화면에도). 화면 어둡게(Fx.screen_tint)도 같은 방 모두에게.

## 회전 베기 · 그림자 난무가 닿는 거리 (무기 리치에 곱함, 최소 MIN_REACH)
const REACH_MULTIPLIER := 1.8
const MIN_REACH := 44.0
## 대폭발 반경 (무기 폭발 반경에 곱함, 최소 MIN_BLAST)
const BLAST_MULTIPLIER := 2.2
const MIN_BLAST := 48.0
const FLURRY_INTERVAL := 0.08
## 근접 판정에서 적의 몸 크기 여유
const BODY_MARGIN := 6.0

const CRESCENT := preload("res://assets/sprites/projectiles/skill_crescent.png")
const ABYSS_SLASH := preload("res://assets/sprites/projectiles/abyss_slash.png")
const SUN_ARROW := preload("res://assets/sprites/projectiles/sun_arrow.png")
const HELL_HAND := preload("res://assets/sprites/effects/hell_hand.png")
const MAGIC_CIRCLE := preload("res://assets/sprites/effects/magic_circle.png")
const SUN_DISC := preload("res://assets/sprites/effects/sun_disc.png")

const ABYSS_COLOR := Color(0.75, 0.05, 0.2)
const HOLY_COLOR := Color(1.0, 0.88, 0.45)
const SUN_COLOR := Color(1.0, 0.8, 0.3)
const ARCANE_COLOR := Color(0.8, 0.55, 1.0)


## 스킬 실행. 실제로 나갔으면 true
static func cast(player: Player, weapon: WeaponData) -> bool:
	match weapon.get_skill_id():
		&"whirlwind":
			whirlwind(player, weapon)
		&"holy_tempest":
			holy_tempest(player, weapon)
		&"abyss_descent":
			abyss_descent(player, weapon)
		&"flurry":
			flurry(player, weapon)
		&"shadow_dance":
			shadow_dance(player, weapon)
		&"volley":
			return volley(player, weapon)
		&"meteor_rain":
			meteor_rain(player, weapon)
		&"helios":
			helios(player, weapon)
		&"blast":
			blast(player, weapon)
		&"cataclysm":
			cataclysm(player, weapon)
		&"meteor_swarm":
			meteor_swarm(player, weapon)
		_:
			return false
	return true


# ============================================================ 공통
static func reach_of(weapon: WeaponData) -> float:
	return maxf(weapon.melee_range * REACH_MULTIPLIER, MIN_REACH)


## 스킬 한 타 — 무기 공격력(장비 · 버프 포함) × 스킬 배율 × extra
static func roll(weapon: WeaponData, extra: float = 1.0) -> Dictionary:
	var r := GameManager.roll_weapon_damage(weapon)
	r["amount"] = maxi(1, roundi(float(r["amount"]) * weapon.get_skill_multiplier() * extra))
	return r


## 원 안의 적을 한 번씩 벰. 맞힌 적 목록
static func hit_around(player: Player, weapon: WeaponData, origin: Vector2, reach: float, kind: Enemy.HitKind, extra: float = 1.0) -> Array[Enemy]:
	var hit: Array[Enemy] = []
	for node in player.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var to_enemy := enemy.get_hit_center() - origin
		if to_enemy.length() > reach + BODY_MARGIN:
			continue
		if not enemy.can_be_hit_by(kind):
			enemy.show_immune()
			continue
		strike(player, weapon, enemy, extra, to_enemy)
		hit.append(enemy)
	return hit


## 적 하나를 스킬로 때림 (+ 명중 파티클)
static func strike(player: Player, weapon: WeaponData, enemy: Enemy, extra: float = 1.0, push_dir: Vector2 = Vector2.ZERO) -> void:
	var r := roll(weapon, extra)
	var push := push_dir.normalized() if push_dir != Vector2.ZERO else player.get_aim_direction()
	Enemy.hit(enemy, r["amount"], push * weapon.knockback * 1.5, r["crit"], r["armor_pen"])
	Enemy.on_player_hit(enemy, r["amount"])
	Fx.burst(player, enemy.get_hit_center(), weapon.effect_color, 12, 90.0, 0.4, Elements.gravity_of(weapon.element))


## 선분 근처(width)의 적을 모두 때림 (태양 광선)
static func hit_line(player: Player, weapon: WeaponData, from: Vector2, to: Vector2, width: float, extra: float) -> int:
	var count := 0
	for node in player.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var c := enemy.get_hit_center()
		var closest := Geometry2D.get_closest_point_to_segment(c, from, to)
		if c.distance_to(closest) <= width + BODY_MARGIN and enemy.can_be_hit_by(Enemy.HitKind.BOW):
			strike(player, weapon, enemy, extra, to - from)
			count += 1
	return count


## 스킬 투사체 (꿰뚫는 참격 · 태양의 창 …)
static func shoot(player: Player, weapon: WeaponData, origin: Vector2, dir: Vector2, texture: Texture2D, extra: float,
		speed: float, max_range: float, pierce: int = 99, scale: float = 1.0, grow: float = 1.0, kind: Enemy.HitKind = Enemy.HitKind.MAGIC) -> void:
	var pool := ProjectilePool.find(player.get_tree())
	if pool == null:
		return
	var spec := ProjectileSpec.from_weapon(weapon, origin, dir, roll(weapon, extra))
	spec.texture = texture
	spec.color = Color.WHITE
	spec.speed = speed
	spec.max_distance = max_range
	spec.pierce = pierce
	spec.scale = scale
	spec.grow = grow
	spec.fx_level = 3
	spec.explosion_radius = 0.0
	spec.source_weapon = null
	spec.hit_kind = kind
	pool.spawn(spec)


## 플레이어가 살아서 계속 쓸 수 있는지 (연속 동작 중간 확인)
static func alive(player: Player) -> bool:
	return is_instance_valid(player) and player.is_inside_tree() and not GameManager.is_player_dead


static func wait(player: Player, seconds: float) -> void:
	await player.get_tree().create_timer(seconds, false).timeout


# ============================================================ 검
## 레어 — 회전 베기: 몸을 한 바퀴 돌리며 주위 360° 를 벰
static func whirlwind(player: Player, weapon: WeaponData) -> void:
	var origin := player.get_attack_origin()
	var reach := reach_of(weapon)
	player.play_melee_swing(weapon)
	for i in 12:
		Fx.burst(player, origin + Vector2.RIGHT.rotated(TAU * i / 12.0) * reach * 0.8, weapon.effect_color, 4, 50.0, 0.4, Elements.gravity_of(weapon.element))
	Fx.shockwave(player, origin, weapon.effect_color, reach * 1.1, 0.35)
	Fx.flash(player, origin, weapon.effect_color, reach * 0.7, 0.2)
	var hits := hit_around(player, weapon, origin, reach, Enemy.HitKind.MELEE)
	player.shake_camera(3.0 + 0.5 * hits.size())


## 전설 — 성검 폭풍: 두 바퀴 회전 베기 → 빛의 초승달 참격 8개가 사방으로 날아가 꿰뚫음
static func holy_tempest(player: Player, weapon: WeaponData) -> void:
	var reach := reach_of(weapon) * 1.15
	for spin in 2:
		if spin > 0:
			await wait(player, 0.22)
			if not alive(player):
				return
		var origin := player.get_attack_origin()
		player.play_melee_swing(weapon)
		Fx.shockwave(player, origin, HOLY_COLOR, reach * (1.1 + 0.3 * spin), 0.35)
		for i in 10:
			Fx.burst(player, origin + Vector2.RIGHT.rotated(TAU * i / 10.0 + spin * 0.3) * reach * 0.85, HOLY_COLOR, 5, 60.0, 0.45)
		hit_around(player, weapon, origin, reach, Enemy.HitKind.MELEE)
	await wait(player, 0.18)
	if not alive(player):
		return
	var center := player.get_attack_origin()
	Fx.pillar(player, center, HOLY_COLOR, 26.0, 120.0, 0.5)
	Fx.cross_glint(player, center, Color(1.0, 0.97, 0.8), 70.0, 0.4)
	for i in 8:
		shoot(player, weapon, center, Vector2.RIGHT.rotated(TAU * i / 8.0), CRESCENT, 0.7, 230.0, 180.0, 99, 1.0, 1.7)
	player.shake_camera(5.0)


## 신화(아바돈의 검) — 마왕강림: 화면이 어두워지고 핏빛 암흑 참격이 사방으로 터짐 →
## 땅에서 마계의 손아귀가 솟아 적을 붙잡고(기절) → 암흑 기둥이 솟구침 → 무저갱의 폭발로 마무리
static func abyss_descent(player: Player, weapon: WeaponData) -> void:
	var center := player.get_attack_origin()
	Fx.screen_tint(player, Color(0.12, 0.0, 0.04, 0.6), 2.2)
	Fx.flash(player, center, ABYSS_COLOR, 60.0, 0.4)
	Fx.shockwave(player, center, Color(0.9, 0.1, 0.25), 90.0, 0.45)
	Fx.burst(player, center, Color(0.5, 0.0, 0.1), 40, 160.0, 0.6, Vector2(0, -40), 1.3)
	player.play_melee_swing(weapon)
	player.shake_camera(6.0)
	for i in 12:
		shoot(player, weapon, center, Vector2.RIGHT.rotated(TAU * i / 12.0 + 0.13), ABYSS_SLASH, 0.8, 210.0, 200.0, 99, 1.1, 1.8)
	await wait(player, 0.35)
	if not alive(player):
		return
	# 마계의 손아귀: 둘레의 적 발밑에서 손이 솟아 붙잡음 (기절 1.6초)
	var grabbed: Array[Enemy] = []
	for node in player.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead() and enemy.global_position.distance_to(center) <= 170.0:
			grabbed.append(enemy)
	for enemy in grabbed:
		Fx.sprite_pop(player, enemy.global_position + Vector2(0, -6), HELL_HAND, Color.WHITE, 0.3, 1.4, 1.1, Vector2(0, -8))
		Fx.burst(player, enemy.global_position, Color(0.4, 0.0, 0.1), 10, 50.0, 0.5, Vector2(0, -60))
		if enemy.has_method(&"stun"):
			enemy.stun(1.6)
	await wait(player, 0.4)
	if not alive(player):
		return
	for enemy in grabbed:
		if is_instance_valid(enemy) and not enemy.is_dead():
			Fx.pillar(player, enemy.global_position, Color(0.55, 0.0, 0.15), 18.0, 110.0, 0.55)
			Fx.pillar(player, enemy.global_position, Color(0.1, 0.0, 0.05), 8.0, 130.0, 0.5)
			strike(player, weapon, enemy, 1.3)
	player.shake_camera(5.0)
	await wait(player, 0.35)
	if not alive(player):
		return
	var finale := player.get_attack_origin()
	Fx.explosion(player, finale, ABYSS_COLOR, 90.0, 3, Vector2(0, -30))
	Fx.shockwave(player, finale, Color(1.0, 0.2, 0.3), 140.0, 0.5)
	hit_around(player, weapon, finale, 120.0, Enemy.HitKind.MAGIC, 1.2)
	player.shake_camera(8.0)


# ============================================================ 단검
## 레어 — 그림자 난무: 짧은 간격으로 다섯 번 주위를 벰
static func flurry(player: Player, weapon: WeaponData) -> void:
	var count := int(WeaponData.SKILLS[&"flurry"]["hits"])
	var reach := reach_of(weapon)
	for i in count:
		if i > 0:
			await wait(player, FLURRY_INTERVAL)
			if not alive(player):
				return
		var origin := player.get_attack_origin()
		player.play_melee_swing(weapon)
		Fx.cross_glint(player, origin + Vector2.RIGHT.rotated(TAU * i / float(count)) * reach * 0.5, weapon.effect_color, reach * 0.8, 0.2)
		hit_around(player, weapon, origin, reach, Enemy.HitKind.MELEE)
	player.shake_camera(3.0)


## 전설 — 그림자 무도: 가까운 적들을 차례로 골라 그림자 베기 여덟 번 (그동안 무적)
static func shadow_dance(player: Player, weapon: WeaponData) -> void:
	var count := int(WeaponData.SKILLS[&"shadow_dance"]["hits"])
	player._invincible_left = maxf(player._invincible_left, count * 0.09 + 0.2)
	for i in count:
		if i > 0:
			await wait(player, 0.09)
			if not alive(player):
				return
		var origin := player.get_attack_origin()
		var targets: Array = player.get_tree().get_nodes_in_group(&"enemies").filter(func(n: Node) -> bool:
			return n is Enemy and not (n as Enemy).is_dead() and (n as Enemy).global_position.distance_to(origin) <= 150.0)
		player.play_melee_swing(weapon)
		if targets.is_empty():
			Fx.cross_glint(player, origin, Color(0.7, 0.6, 1.0), 30.0, 0.2)
			continue
		var target := targets[i % targets.size()] as Enemy
		Fx.cross_glint(player, target.get_hit_center(), Color(0.75, 0.6, 1.0), 34.0, 0.22)
		Fx.burst(player, target.get_hit_center(), Color(0.25, 0.15, 0.4), 8, 60.0, 0.35)
		strike(player, weapon, target)
	player.shake_camera(4.0)


# ============================================================ 활
## 레어 — 화살비: 꿰뚫는 화살 9발을 부채꼴로
static func volley(player: Player, weapon: WeaponData) -> bool:
	var pool := ProjectilePool.find(player.get_tree())
	if pool == null:
		return false
	var origin := player.get_muzzle_position()
	var base_dir := player.get_aim_direction()
	for i in 9:
		var t := float(i) / 8.0 - 0.5
		var spec := ProjectileSpec.from_weapon(weapon, origin, base_dir.rotated(deg_to_rad(60.0) * t), roll(weapon))
		spec.pierce = weapon.pierce + 3
		spec.max_distance = weapon.projectile_range * 1.3
		spec.fx_level = 3
		pool.spawn(spec)
	Fx.flash(player, origin, weapon.effect_color, 18.0, 0.2)
	player.play_attack_feedback()
	player.shake_camera(2.0)
	return true


## 전설 — 유성 화살비: 조준한 곳 하늘에서 불붙은 화살 14발이 쏟아져 터짐
static func meteor_rain(player: Player, weapon: WeaponData) -> void:
	var at := player.get_aim_point(weapon.projectile_range * 1.2)
	player.play_attack_feedback()
	Fx.flash(player, player.get_muzzle_position(), Color(1.0, 0.7, 0.3), 20.0, 0.25)
	Fx.shockwave(player, at, Color(1.0, 0.6, 0.25), 60.0, 0.6)
	for i in 14:
		var spot := at + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 58.0
		var strike_node := SkyStrike.spawn(player, spot, SkyStrike.Kind.ARROW, weapon, roll(weapon), 0.1 + 0.06 * i)
		if strike_node != null:
			strike_node.radius = 18.0
			strike_node.fall_time = 0.3
			strike_node.splash_damage = strike_node.damage
			strike_node.color = Color(1.0, 0.65, 0.3)
	player.shake_camera(2.5)


## 신화(아폴론의 활) — 헬리오스의 심판: 모든 것을 꿰뚫는 태양의 창 → 그 끝에 태양이 떠올라 사방으로 햇살이 내리꽂힘
static func helios(player: Player, weapon: WeaponData) -> void:
	var origin := player.get_muzzle_position()
	var dir := player.get_aim_direction()
	var length := weapon.projectile_range * 1.6
	var end := origin + dir * length
	player.play_attack_feedback()
	Fx.screen_tint(player, Color(1.0, 0.85, 0.4, 0.28), 1.6)
	Fx.beam(player, origin, end, SUN_COLOR, 22.0, 0.5)
	Fx.beam(player, origin, end, Color(1.0, 1.0, 0.9), 8.0, 0.4)
	shoot(player, weapon, origin, dir, SUN_ARROW, 1.0, 380.0, length, 999, 1.5, 1.0, Enemy.HitKind.BOW)
	hit_line(player, weapon, origin, end, 12.0, 0.6)
	player.shake_camera(4.0)
	await wait(player, 0.45)
	if not alive(player):
		return
	Fx.sprite_pop(player, end, SUN_DISC, Color.WHITE, 0.4, 2.6, 1.4, Vector2(0, -10), 0.6, true)
	Fx.flash(player, end, SUN_COLOR, 80.0, 0.6)
	Spells.damage_area(player, end, 64.0, roll(weapon, 1.2)["amount"], roll(weapon, 0.9)["amount"], int(GameManager.get_armor_pen(weapon)), weapon.knockback)
	await wait(player, 0.25)
	if not alive(player):
		return
	for i in 10:
		var ray_end := end + Vector2.RIGHT.rotated(TAU * i / 10.0 + 0.15) * 130.0
		Fx.beam(player, end, ray_end, SUN_COLOR, 10.0, 0.45)
		hit_line(player, weapon, end, ray_end, 9.0, 0.5)
	Fx.shockwave(player, end, Color(1.0, 0.95, 0.7), 140.0, 0.5)
	player.shake_camera(6.0)
	return


# ============================================================ 지팡이
## 레어 — 대폭발: 조준한 곳에 거대한 마력 폭발
static func blast(player: Player, weapon: WeaponData) -> void:
	var radius := maxf(weapon.explosion_radius * BLAST_MULTIPLIER, MIN_BLAST)
	var at := player.get_aim_point(weapon.projectile_range)
	var r := roll(weapon)
	Fx.explosion(player, at, weapon.effect_color, radius, 3, Elements.gravity_of(weapon.element))
	Fx.shockwave(player, at, weapon.effect_color, radius * 1.15, 0.4)
	Fx.pillar(player, at, weapon.effect_color, radius * 0.5, radius * 2.0, 0.45)
	Spells.damage_area(player, at, radius, r["amount"], r["amount"], r["armor_pen"], weapon.knockback, null, weapon.slow_duration, r["crit"])
	player.play_attack_feedback()
	player.shake_camera(5.0)


## 전설 — 원소 붕괴: 조준한 곳까지 화염 → 냉기(감속) → 번개 → 비전 폭발이 차례로, 마지막에 거대한 붕괴
static func cataclysm(player: Player, weapon: WeaponData) -> void:
	var origin := player.get_muzzle_position()
	var at := player.get_aim_point(weapon.projectile_range * 1.2)
	var radius := maxf(weapon.explosion_radius * 1.4, 32.0)
	var colors := [Color(1.0, 0.5, 0.2), Color(0.6, 0.85, 1.0), Color(1.0, 0.95, 0.4), ARCANE_COLOR]
	player.play_attack_feedback()
	for i in 4:
		if i > 0:
			await wait(player, 0.16)
			if not alive(player):
				return
		var spot := origin.lerp(at, 0.3 + 0.2 * i)
		var r := roll(weapon)
		Fx.explosion(player, spot, colors[i], radius, 2)
		if i == 2:
			Fx.beam(player, spot + Vector2(0, -120), spot, Color(1.0, 1.0, 0.7), 10.0, 0.3)
		Spells.damage_area(player, spot, radius, r["amount"], r["amount"], r["armor_pen"], weapon.knockback * 0.5, null, 1.5 if i == 1 else 0.0, r["crit"])
		player.shake_camera(2.5)
	await wait(player, 0.22)
	if not alive(player):
		return
	var big := roll(weapon, 1.6)
	Fx.explosion(player, at, ARCANE_COLOR, radius * 1.8, 3)
	Fx.shockwave(player, at, Color(1.0, 0.9, 1.0), radius * 2.4, 0.5)
	Fx.pillar(player, at, ARCANE_COLOR, radius * 0.8, radius * 3.0, 0.5)
	Spells.damage_area(player, at, radius * 1.8, big["amount"], big["amount"], big["armor_pen"], weapon.knockback, null, 0.0, big["crit"])
	player.shake_camera(6.0)


## 신화(대마법사의 지팡이) — 메테오 스웜: 하늘에 거대한 마법진 → 별 열여섯 개 → 마지막에 거대한 운석
static func meteor_swarm(player: Player, weapon: WeaponData) -> void:
	var at := player.get_aim_point(weapon.projectile_range * 1.3)
	player.play_attack_feedback()
	Fx.screen_tint(player, Color(0.25, 0.1, 0.45, 0.35), 2.6)
	Fx.sprite_pop(player, at, MAGIC_CIRCLE, Color(1.0, 1.0, 1.0, 0.95), 0.4, 4.0, 2.4, Vector2.ZERO, TAU, true)
	Fx.sprite_pop(player, player.global_position, MAGIC_CIRCLE, Color(ARCANE_COLOR, 0.8), 0.3, 1.4, 1.2, Vector2.ZERO, -TAU, true)
	for i in 16:
		var spot := at + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 90.0
		var star := SkyStrike.spawn(player, spot, SkyStrike.Kind.STAR, weapon, roll(weapon), 0.3 + 0.07 * i)
		if star != null:
			star.radius = 24.0
			star.splash_damage = star.damage
	var meteor := SkyStrike.spawn(player, at, SkyStrike.Kind.METEOR, weapon, roll(weapon, 3.0), 1.65)
	if meteor != null:
		meteor.radius = 66.0
		meteor.fall_time = 0.6
		meteor.splash_damage = maxi(1, roundi(meteor.damage * 0.7))
		meteor.color = ARCANE_COLOR
	player.shake_camera(3.0)
