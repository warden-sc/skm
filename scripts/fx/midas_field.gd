class_name MidasField
extends Node2D
## 미다스의 보스방 바닥 (67스테이지): 팍톨로스 강(아래쪽 띠) · 갈대밭(왼쪽 위) · 황금 웅덩이(미다스가 만듦).
## 판정은 BossMidas 가 이 노드의 is_in_river() / is_in_reeds() / is_on_gold() 로 합니다.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const PUDDLE_RADIUS := 22.0

var area: Rect2 = Rect2()
var river: Rect2 = Rect2()
var reeds: Rect2 = Rect2()
var puddles: Array[Dictionary] = []   # {at, left}
var reeds_cooldown: float = 0.0


static func spawn(context: Node, bounds: Rect2) -> MidasField:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var field := MidasField.new()
	field.area = bounds
	field.river = Rect2(bounds.position.x, bounds.end.y - 46.0, bounds.size.x, 34.0)
	field.reeds = Rect2(bounds.position.x + 20.0, bounds.position.y + 20.0, 110.0, 80.0)
	parent.add_child(field)
	field.global_position = Vector2.ZERO
	return field


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = -5


func add_puddle(at: Vector2, duration: float) -> void:
	puddles.append({"at": at, "left": duration})
	queue_redraw()


func is_in_river(at: Vector2) -> bool:
	return river.has_point(at)


func is_in_reeds(at: Vector2) -> bool:
	return reeds.has_point(at)


func is_on_gold(at: Vector2) -> bool:
	for p in puddles:
		if (p["at"] as Vector2).distance_to(at) <= PUDDLE_RADIUS:
			return true
	return false


func _physics_process(delta: float) -> void:
	reeds_cooldown = maxf(reeds_cooldown - delta, 0.0)
	var changed := false
	for p in puddles:
		p["left"] -= delta
	for p in puddles.duplicate():
		if p["left"] <= 0.0:
			puddles.erase(p)
			changed = true
	if changed or Engine.get_physics_frames() % 6 == 0:
		queue_redraw()


func _draw() -> void:
	# 팍톨로스 강: 금모래가 반짝이는 강물
	draw_rect(river, Color(0.25, 0.45, 0.75, 0.55))
	var t := Time.get_ticks_msec() * 0.001
	for i in 24:
		var x := river.position.x + fmod(i * 37.0 + t * 30.0, river.size.x)
		draw_line(Vector2(x, river.position.y + 8 + (i % 3) * 8), Vector2(x + 10, river.position.y + 8 + (i % 3) * 8), Color(1.0, 0.9, 0.5, 0.6), 1.0)
	# 갈대밭
	draw_rect(reeds, Color(0.45, 0.55, 0.25, 0.35 if reeds_cooldown <= 0.0 else 0.15))
	for i in 18:
		var x := reeds.position.x + 6.0 + (i % 6) * 18.0
		var y := reeds.position.y + 14.0 + floorf(i / 6.0) * 24.0
		draw_line(Vector2(x, y + 12), Vector2(x + sin(t * 2.0 + i) * 3.0, y - 6), Color(0.6, 0.7, 0.3, 0.9), 1.5)
	# 황금 웅덩이
	for p in puddles:
		var a := clampf(float(p["left"]), 0.0, 1.0)
		draw_circle(p["at"], PUDDLE_RADIUS, Color(1.0, 0.82, 0.25, 0.55 * a))
		draw_arc(p["at"], PUDDLE_RADIUS, 0.0, TAU, 24, Color(1.0, 0.95, 0.6, 0.8 * a), 1.0)
