class_name AdminSkills
## 운영자 장비(AdminGear) 전용 [Q] 스킬 — 신에 가까운 성기사의 화려한 기술. WeaponSkills.cast 가 부름.
##   천상낙하참(운영자의 검)    빛의 날개로 하늘 높이 → 거대한 빛의 검이 되어 보스(없으면 가장 가까운 적 · 조준한 곳)에게 내리꽂힘
##   천벌의 빛화살(운영자의 활) 하늘로 올라 모든 적에게 빛의 화살비 → 하늘에서 거대한 천벌의 화살이 꿰뚫음
##   창세의 빛(운영자의 지팡이) 겹겹의 마법진 → 모든 적 머리 위로 빛기둥 → 세상이 하얗게 타오르는 대폭발
## 이펙트는 모두 Fx(방장이 쓰면 참가자 화면에도), 피해는 WeaponSkills.strike / Spells.damage_area.
## 시인성: 화면 전체를 덮는 색(screen_tint)은 쓰지 않고, 넓은 빛은 반투명(SOFT) · 밝은 심지는 가늘게 — 화려해도 바닥 · 적 · 탄이 보이게.

const LIGHT := Color(1.0, 0.92, 0.6)
const HOLY_WHITE := Color(1.0, 1.0, 0.95)
const SKY := Color(0.6, 0.9, 1.0)
## 넓게 퍼지는 빛(번쩍임 · 굵은 빛기둥 · 폭발)은 반투명으로 — 화면 전체가 노랗게 바래서 바닥 · 적 · 탄이 안 보이지 않게
const SOFT := Color(1.0, 0.9, 0.55, 0.45)
const SOFT_WHITE := Color(1.0, 1.0, 0.95, 0.5)
const SERAPH: Texture2D = preload("res://assets/sprites/effects/seraph.png")
const DIVINE_SWORD: Texture2D = preload("res://assets/sprites/effects/divine_sword.png")
const LIGHT_SWORD: Texture2D = preload("res://assets/sprites/effects/light_sword.png")
const MAGIC_CIRCLE: Texture2D = preload("res://assets/sprites/effects/magic_circle.png")
const SUN_ARROW: Texture2D = preload("res://assets/sprites/projectiles/sun_arrow.png")
## 하늘로 오르는 높이
const RISE := 150.0
## 노릴 수 있는 거리
const SEEK_RANGE := 420.0


## 노릴 적: 보스 우선 → 가장 가까운 적 (없으면 null)
static func pick_target(player: Player) -> Enemy:
	var best: Enemy = null
	var best_score := INF
	for node in player.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var d := enemy.global_position.distance_to(player.global_position)
		if d > SEEK_RANGE:
			continue
		var score := d - (10000.0 if enemy.is_boss else 0.0)
		if score < best_score:
			best_score = score
			best = enemy
	return best


static func living_enemies(player: Player, center: Vector2, radius: float) -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node in player.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead() and enemy.global_position.distance_to(center) <= radius:
			list.append(enemy)
	return list


## 날개를 펼치고 하늘로 오름 (용사는 잠깐 사라지고 날개 달린 모습이 위로) — 그동안 무적
static func ascend(player: Player, duration: float) -> Vector2:
	var at := player.global_position
	player._invincible_left = maxf(player._invincible_left, duration + 1.2)
	player.modulate.a = 0.0
	Fx.flash(player, at, SOFT, 26.0, 0.35)
	Fx.burst(player, at, HOLY_WHITE, 30, 110.0, 0.8, Vector2(0, 40), 1.4)  # 흩날리는 깃털
	Fx.shockwave(player, at, LIGHT, 60.0, 0.4)
	Fx.sprite_pop(player, at + Vector2(0, -8), SERAPH, Color.WHITE, 1.6, 2.2, duration + 0.35, Vector2(0, -RISE))
	Fx.pillar(player, at, SOFT, 12.0, RISE + 40.0, duration)
	Sfx.play(&"ascend", 0.7)
	return at + Vector2(0, -RISE)


static func reappear(player: Player) -> void:
	if is_instance_valid(player):
		player.modulate.a = 1.0
		Fx.burst(player, player.global_position, HOLY_WHITE, 20, 70.0, 0.7, Vector2(0, 30), 1.2)


# ============================================================ 검
## 천상낙하참: 날개로 하늘 높이 → 빛의 검이 되어 보스에게 내리꽂힘 → 착지 대폭발 + 빛의 검 열두 자루
static func seraph_dive(player: Player, weapon: WeaponData) -> void:
	var start := player.global_position
	var target := pick_target(player)
	var land := target.global_position if target != null else player.get_aim_point(220.0)
	if target != null:
		land += target.global_position.direction_to(start) * 22.0  # 보스 몸에 겹치지 않게 바로 앞
	var sky := ascend(player, 0.55)
	player.shake_camera(3.0)
	await WeaponSkills.wait(player, 0.6)
	if not WeaponSkills.alive(player):
		reappear(player)
		return
	# 하늘에서 반짝 → 거대한 빛의 검으로 바뀌어 내리꽂힘
	Fx.cross_glint(player, sky, HOLY_WHITE, 70.0, 0.4)
	Fx.flash(player, sky, SOFT, 30.0, 0.3)
	var drop_from := land + Vector2(0, -RISE - 40.0)
	Fx.beam(player, sky, drop_from, LIGHT, 14.0, 0.3)
	Fx.sprite_pop(player, drop_from, DIVINE_SWORD, Color.WHITE, 2.4, 2.8, 0.45, land - drop_from + Vector2(0, -20), 0.0, true)
	Fx.beam(player, drop_from, land, SOFT, 18.0, 0.3)
	Fx.beam(player, drop_from, land, HOLY_WHITE, 10.0, 0.3)
	await WeaponSkills.wait(player, 0.18)
	if not WeaponSkills.alive(player):
		reappear(player)
		return
	# 착지: 용사가 그 자리에 · 대폭발
	player.global_position = land
	reappear(player)
	Sfx.play(&"descent", 0.6)
	Fx.explosion(player, land, SOFT, 80.0, 2, Vector2(0, -30))
	Fx.shockwave(player, land, HOLY_WHITE, 150.0, 0.5)
	Fx.shockwave(player, land, SKY, 110.0, 0.45)
	Fx.pillar(player, land, SOFT, 34.0, 300.0, 0.7)
	Fx.pillar(player, land, HOLY_WHITE, 10.0, 320.0, 0.5)
	Fx.cross_glint(player, land, HOLY_WHITE, 120.0, 0.4)
	if target != null and is_instance_valid(target) and not target.is_dead():
		WeaponSkills.strike(player, weapon, target, 2.0, target.global_position - start)
	WeaponSkills.hit_around(player, weapon, land, 130.0, Enemy.HitKind.MAGIC, 1.0)
	player.shake_camera(10.0)
	await WeaponSkills.wait(player, 0.25)
	if not WeaponSkills.alive(player):
		return
	# 빛의 검 열두 자루가 둘레에 쏟아짐
	for i in 12:
		var spot := land + Vector2.RIGHT.rotated(TAU * i / 12.0) * 90.0
		Fx.sprite_pop(player, spot + Vector2(0, -90), LIGHT_SWORD, Color.WHITE, 1.6, 1.8, 0.35, Vector2(0, 80), 0.0, true)
		Fx.flash(player, spot, SOFT, 14.0, 0.25)
	await WeaponSkills.wait(player, 0.2)
	if not WeaponSkills.alive(player):
		return
	for i in 12:
		var spot := land + Vector2.RIGHT.rotated(TAU * i / 12.0) * 90.0
		Fx.shockwave(player, spot, LIGHT, 34.0, 0.3)
		WeaponSkills.hit_around(player, weapon, spot, 34.0, Enemy.HitKind.MAGIC, 0.5)
	Fx.shockwave(player, land, SOFT_WHITE, 170.0, 0.5)
	player.shake_camera(6.0)


# ============================================================ 활
## 천벌의 빛화살: 하늘로 올라 모든 적에게 빛의 화살비 → 거대한 천벌의 화살
static func heaven_judgement(player: Player, weapon: WeaponData) -> void:
	var sky := ascend(player, 0.5)
	await WeaponSkills.wait(player, 0.5)
	if not WeaponSkills.alive(player):
		reappear(player)
		return
	Fx.sprite_pop(player, sky, MAGIC_CIRCLE, Color(1.0, 0.95, 0.7, 0.55), 0.5, 2.2, 1.6, Vector2.ZERO, TAU, true)
	Fx.cross_glint(player, sky, HOLY_WHITE, 90.0, 0.5)
	var center := player.global_position
	var enemies := living_enemies(player, center, SEEK_RANGE)
	# 적마다 빛화살 셋 + 빈자리에도 흩뿌림
	var spots: Array[Vector2] = []
	for enemy in enemies:
		for k in 3:
			spots.append(enemy.global_position + Vector2.from_angle(randf() * TAU) * randf() * 10.0)
	for i in 18:
		spots.append(center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 200.0)
	for i in spots.size():
		Fx.beam(player, sky, spots[i], Color(LIGHT, 0.3), 2.0, 0.2)
		var arrow := SkyStrike.spawn(player, spots[i], SkyStrike.Kind.ARROW, weapon, WeaponSkills.roll(weapon, 0.6), 0.05 + 0.025 * i)
		if arrow != null:
			arrow.radius = 22.0
			arrow.fall_time = 0.25
			arrow.splash_damage = arrow.damage
			arrow.color = LIGHT
	player.shake_camera(4.0)
	await WeaponSkills.wait(player, 0.9)
	if not WeaponSkills.alive(player):
		reappear(player)
		return
	# 하늘에서 거대한 천벌의 화살: 가장 센 적(보스)을 꿰뚫고 땅에 박혀 터짐
	var target := pick_target(player)
	var hit_at := target.global_position if target != null else player.get_aim_point(220.0)
	var from := hit_at + Vector2(-60, -RISE - 60.0)
	Fx.beam(player, from, hit_at, SOFT, 20.0, 0.45)
	Fx.beam(player, from, hit_at, HOLY_WHITE, 12.0, 0.45)
	Fx.sprite_pop(player, from, SUN_ARROW, Color.WHITE, 3.0, 3.6, 0.4, hit_at - from, 0.0, true)
	WeaponSkills.hit_line(player, weapon, from, hit_at, 18.0, 2.0)
	Fx.explosion(player, hit_at, SOFT, 80.0, 2)
	Fx.shockwave(player, hit_at, HOLY_WHITE, 140.0, 0.5)
	Spells.damage_area(player, hit_at, 110.0, WeaponSkills.roll(weapon, 2.0)["amount"], WeaponSkills.roll(weapon, 1.0)["amount"], int(GameManager.get_armor_pen(weapon)), weapon.knockback)
	reappear(player)
	player.shake_camera(9.0)


# ============================================================ 지팡이
## 창세의 빛: 겹겹의 마법진 → 모든 적 머리 위로 빛기둥 → 세상이 하얗게 타오름
static func genesis_light(player: Player, weapon: WeaponData) -> void:
	var at := player.get_aim_point(weapon.projectile_range * 1.3)
	var center := player.global_position
	player.play_attack_feedback()
	Fx.sprite_pop(player, center, MAGIC_CIRCLE, Color(LIGHT, 0.5), 0.4, 1.6, 2.6, Vector2.ZERO, TAU, true)
	Fx.sprite_pop(player, at, MAGIC_CIRCLE, Color(1, 1, 1, 0.5), 0.5, 4.0, 2.8, Vector2.ZERO, -TAU, true)
	Fx.sprite_pop(player, at, MAGIC_CIRCLE, Color(SKY, 0.45), 0.5, 2.8, 2.6, Vector2.ZERO, TAU * 1.5, true)
	player._invincible_left = maxf(player._invincible_left, 2.5)
	# 둘레 여섯 곳에서 빛기둥이 솟아 가운데로 모여듦
	for i in 6:
		var spot := at + Vector2.RIGHT.rotated(TAU * i / 6.0) * 120.0
		Fx.pillar(player, spot, SOFT, 12.0, 220.0, 0.9)
		Fx.beam(player, spot, at, Color(LIGHT, 0.45), 4.0, 0.5)
	player.shake_camera(3.0)
	await WeaponSkills.wait(player, 0.6)
	if not WeaponSkills.alive(player):
		return
	# 모든 적 머리 위로 빛기둥
	for enemy in living_enemies(player, center, SEEK_RANGE):
		Fx.pillar(player, enemy.global_position, SOFT, 16.0, 260.0, 0.6)
		Fx.pillar(player, enemy.global_position, HOLY_WHITE, 6.0, 280.0, 0.5)
		Fx.flash(player, enemy.global_position, SOFT, 18.0, 0.3)
		WeaponSkills.strike(player, weapon, enemy, 1.2)
	player.shake_camera(5.0)
	await WeaponSkills.wait(player, 0.5)
	if not WeaponSkills.alive(player):
		return
	# 하얗게 타오르는 대폭발
	Fx.explosion(player, at, SOFT_WHITE, 100.0, 2)
	Fx.shockwave(player, at, LIGHT, 200.0, 0.6)
	Fx.shockwave(player, at, SKY, 170.0, 0.6)
	Fx.cross_glint(player, at, HOLY_WHITE, 150.0, 0.5)
	var big := WeaponSkills.roll(weapon, 2.0)
	Spells.damage_area(player, at, 170.0, big["amount"], big["amount"], big["armor_pen"], weapon.knockback, null, 0.0, big["crit"])
	Sfx.play(&"descent", 0.6)
	player.shake_camera(10.0)
