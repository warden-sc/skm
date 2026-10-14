class_name GroundZone
extends Node2D
## 지팡이 마법이 남기는 바닥 장판 (점액 웅덩이 / 불타는 땅).
##
## - duration 동안 TICK_TIME 마다 반경 안의 적에게 tick_damage 피해 (+ 점액은 감속)
## - 바닥 위 · 캐릭터 아래(z_index -5)에 그려지고, 끝나기 직전에 서서히 사라집니다.
## - 적 판정은 거리 계산이라 물리 콜백 타이밍 문제가 없습니다.

enum Kind { SLIME, FIRE }

const TICK_TIME := 0.5
const FADE_TIME := 0.4

var kind: Kind = Kind.SLIME
var radius: float = 24.0
var duration: float = 2.0
var tick_damage: int = 0
var armor_pen: int = 0
var slow_duration: float = 0.0

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
	return Color(1.0, 0.45, 0.12) if kind == Kind.FIRE else Color(0.35, 0.85, 0.3)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_tick_left -= delta
	if _tick_left <= 0.0 and _elapsed < duration:
		_tick_left = TICK_TIME
		_tick()
	queue_redraw()
	if _elapsed >= duration:
		_particles.emitting = false
		if _elapsed >= duration + FADE_TIME:
			queue_free()


func _tick() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		if enemy.get_hit_center().distance_to(global_position) > radius:
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
	else:
		draw_circle(Vector2.ZERO, r * wobble, Color(0.15, 0.45, 0.12, 0.55 * alpha))
		draw_circle(Vector2(-r * 0.15, -r * 0.1), r * 0.65, Color(color, 0.45 * alpha))
		for i in 4:
			var spot := Vector2.RIGHT.rotated(i * 1.7 + 0.4) * r * 0.5
			draw_circle(spot, 1.5, Color(0.8, 1.0, 0.7, 0.7 * alpha))
		draw_arc(Vector2.ZERO, r * wobble, 0.0, TAU, 40, Color(0.6, 1.0, 0.5, 0.7 * alpha), 1.0)
