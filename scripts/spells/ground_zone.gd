class_name GroundZone
extends Node2D
## 바닥 장판 (점액 웅덩이 / 불타는 땅 / 크라켄의 먹물 / 아르케오스의 시간 모래 / 아스타로트의 저주의 땅).
## - 플레이어 지팡이 마법이 남기면 적에게 피해·감속
## - hostile = true 이면 적(보스)이 깐 장판: 밟은 플레이어가 느려지거나(점액) 화상을 입음(불)
##
## - duration 동안 TICK_TIME 마다 반경 안의 적에게 tick_damage 피해 (+ 점액은 감속)
## - 바닥 위 · 캐릭터 아래(z_index -5)에 그려지고, 끝나기 직전에 서서히 사라집니다.
## - 적 판정은 거리 계산이라 물리 콜백 타이밍 문제가 없습니다.

enum Kind { SLIME, FIRE, INK, SAND, CURSE }

const TICK_TIME := 0.5
## 밟았을 때 상태 표시 이름
const FLOOR_NAMES := {Kind.SLIME: "점액 바닥", Kind.FIRE: "불바다", Kind.INK: "먹물 바닥", Kind.SAND: "시간의 모래", Kind.CURSE: "저주의 땅"}
const FADE_TIME := 0.4

var kind: Kind = Kind.SLIME
var radius: float = 24.0
var duration: float = 2.0
var tick_damage: int = 0
var armor_pen: int = 0
var slow_duration: float = 0.0
## 적이 깐 장판이면 true → 플레이어에게 작용
var hostile: bool = false
## (hostile) 밟으면 이동 속도 배율 / 화상 피해(0.5초마다) / 화상 지속시간
var player_slow: float = 1.0
var player_burn: int = 0
var player_burn_duration: float = 2.0

var _elapsed: float = 0.0
var _tick_left: float = 0.0
var _particles: CPUParticles2D


static func spawn(context: Node, at_global: Vector2, zone_kind: Kind, zone_radius: float, zone_duration: float,
		damage_per_tick: int, pen: int = 0, slow: float = 0.0) -> GroundZone:
	if context == null or not context.is_inside_tree() or zone_duration <= 0.0:
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var zone := GroundZone.new()
	zone.kind = zone_kind
	zone.radius = zone_radius
	zone.duration = zone_duration
	zone.tick_damage = damage_per_tick
	zone.armor_pen = pen
	zone.slow_duration = slow
	zone.z_index = -5
	root.add_child(zone)
	zone.global_position = at_global
	return zone


## 보스가 까는 장판 (슬라임 킹의 점액 바닥 / 수문장의 불바다). 밟은 플레이어에게 작용
static func spawn_hostile(context: Node, at_global: Vector2, zone_kind: Kind, zone_radius: float, zone_duration: float,
		slow_multiplier: float = 1.0, burn_tick: int = 0, burn_time: float = 2.0) -> GroundZone:
	var zone := spawn(context, at_global, zone_kind, zone_radius, zone_duration, 0)
	if zone != null:
		zone.hostile = true
		zone.player_slow = slow_multiplier
		zone.player_burn = burn_tick
		zone.player_burn_duration = burn_time
		zone.add_to_group(&"hostile_zones")
	return zone


func _ready() -> void:
	add_to_group(&"ground_zones")
	_tick_left = TICK_TIME * 0.5
	var color := get_color()
	if kind == Kind.FIRE:
		_particles = Fx.make_aura(color, 18, radius * 0.85, Vector2(0, -45), 0.7)
	else:
		_particles = Fx.make_aura(color.lightened(0.3), 8, radius * 0.8, Vector2(0, -8), 0.9)
	_particles.z_index = 6
	add_child(_particles)
	_particles.emitting = true


func get_color() -> Color:
	match kind:
		Kind.FIRE:
			return Color(1.0, 0.45, 0.12)
		Kind.INK:
			return Color(0.32, 0.22, 0.42)
		Kind.SAND:
			return Color(0.95, 0.8, 0.45)
		Kind.CURSE:
			return Color(0.5, 0.15, 0.45)
	return Color(0.35, 0.85, 0.3)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_tick_left -= delta
	if hostile:
		if _elapsed < duration:
			_affect_player()
		queue_redraw()
		if _elapsed >= duration:
			_particles.emitting = false
			if _elapsed >= duration + FADE_TIME:
				queue_free()
		return
	if _tick_left <= 0.0 and _elapsed < duration:
		_tick_left = TICK_TIME
		_tick()
	queue_redraw()
	if _elapsed >= duration:
		_particles.emitting = false
		if _elapsed >= duration + FADE_TIME:
			queue_free()


func _affect_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.is_dashing() or player.global_position.distance_to(global_position) > radius:
		return
	if player_slow < 1.0:
		player.apply_slow(player_slow, 0.25)
		player.mark_floor_status("%s (이동 속도 -%d%%)" % [FLOOR_NAMES[kind], roundi((1.0 - player_slow) * 100.0)])
	if player_burn > 0:
		player.apply_burn(player_burn, player_burn_duration)


func _tick() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		if enemy.get_hit_center().distance_to(global_position) > radius or enemy.airborne:
			continue
		if tick_damage > 0:
			enemy.take_damage(tick_damage, Vector2.ZERO, false, armor_pen)
		if slow_duration > 0.0 and not enemy.is_dead():
			enemy.apply_slow(0.45, slow_duration)


func _draw() -> void:
	var alpha := 1.0 if _elapsed < duration else clampf(1.0 - (_elapsed - duration) / FADE_TIME, 0.0, 1.0)
	var grow := clampf(_elapsed / 0.15, 0.0, 1.0)
	var r := radius * grow
	var color := get_color()
	var wobble := 1.0 + sin(_elapsed * 6.0) * 0.03
	if kind == Kind.FIRE:
		draw_circle(Vector2.ZERO, r * wobble, Color(0.45, 0.08, 0.02, 0.45 * alpha))
		draw_circle(Vector2.ZERO, r * 0.7 * wobble, Color(1.0, 0.35, 0.05, 0.35 * alpha))
		draw_circle(Vector2.ZERO, r * 0.35, Color(1.0, 0.8, 0.3, 0.3 * alpha))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.6, 0.2, 0.8 * alpha), 1.0)
	elif kind == Kind.INK:
		draw_circle(Vector2.ZERO, r * wobble, Color(0.04, 0.02, 0.08, 0.7 * alpha))
		draw_circle(Vector2(r * 0.2, -r * 0.1), r * 0.55, Color(color, 0.4 * alpha))
		draw_arc(Vector2.ZERO, r * wobble, 0.0, TAU, 40, Color(0.5, 0.35, 0.65, 0.6 * alpha), 1.0)
	elif kind == Kind.SAND:
		draw_circle(Vector2.ZERO, r, Color(0.5, 0.4, 0.2, 0.35 * alpha))
		for i in 3:
			draw_arc(Vector2.ZERO, r * (0.35 + 0.3 * i), _elapsed * (1.5 - i * 0.6), _elapsed * (1.5 - i * 0.6) + PI * 1.3, 24, Color(color, 0.6 * alpha), 1.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, 0.8 * alpha), 1.0)
	elif kind == Kind.CURSE:
		draw_circle(Vector2.ZERO, r * wobble, Color(0.12, 0.02, 0.1, 0.6 * alpha))
		for i in 5:  # 저주 문양
			var a := _elapsed * 0.6 + i * TAU / 5.0
			draw_line(Vector2.from_angle(a) * r * 0.3, Vector2.from_angle(a + 0.9) * r * 0.8, Color(color.lightened(0.3), 0.6 * alpha), 1.0)
		draw_arc(Vector2.ZERO, r * wobble, 0.0, TAU, 40, Color(0.75, 0.3, 0.7, 0.7 * alpha), 1.0)
	else:
		draw_circle(Vector2.ZERO, r * wobble, Color(0.15, 0.45, 0.12, 0.55 * alpha))
		draw_circle(Vector2(-r * 0.15, -r * 0.1), r * 0.65, Color(color, 0.45 * alpha))
		for i in 4:
			var spot := Vector2.RIGHT.rotated(i * 1.7 + 0.4) * r * 0.5
			draw_circle(spot, 1.5, Color(0.8, 1.0, 0.7, 0.7 * alpha))
		draw_arc(Vector2.ZERO, r * wobble, 0.0, TAU, 40, Color(0.6, 1.0, 0.5, 0.7 * alpha), 1.0)
