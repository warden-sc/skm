class_name AbyssPit
extends Node2D
## 바닥 없는 구덩이 (90스테이지 아바돈): 보스방 가운데의 무저갱. 시간이 갈수록 넓어짐 (min_radius → max_radius).
## 빠지면 큰 피해를 입고 가장자리 밖으로 튕겨 나옴 (판정은 이 노드가, 피해는 fall_callback 으로).
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

var radius: float = 24.0
var min_radius: float = 24.0
var max_radius: float = 110.0
var grow_rate: float = 1.0
var fall_callback: Callable
var _fall_cd: float = 0.0


static func spawn(context: Node, at_global: Vector2) -> AbyssPit:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var pit := AbyssPit.new()
	parent.add_child(pit)
	pit.global_position = at_global
	return pit


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = -4
	radius = min_radius


func contains(at: Vector2) -> bool:
	return at.distance_to(global_position) <= radius


## 구덩이 가장자리 밖의 가장 가까운 자리
func rim_point(at: Vector2, margin: float = 30.0) -> Vector2:
	var dir := global_position.direction_to(at)
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	return global_position + dir * (radius + margin)


func _physics_process(delta: float) -> void:
	radius = minf(radius + grow_rate * delta, max_radius)
	_fall_cd = maxf(_fall_cd - delta, 0.0)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and _fall_cd <= 0.0 and not player.is_dashing() and contains(player.global_position):
		_fall_cd = 1.0
		if fall_callback.is_valid():
			fall_callback.call(player)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 6.0, Color(0.3, 0.08, 0.05, 0.6))
	draw_circle(Vector2.ZERO, radius, Color(0.02, 0.0, 0.02, 0.95))
	var t := Time.get_ticks_msec() * 0.002
	for i in 18:
		var a := TAU * i / 18.0 + t * 0.3
		draw_line(Vector2.from_angle(a) * radius * 0.6, Vector2.from_angle(a + 0.2) * radius, Color(1.0, 0.35, 0.1, 0.35), 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.4, 0.15, 0.85), 2.0)
