class_name FlySwarm
extends Node2D
## 파리 떼 (83스테이지 바알제붑): 플레이어를 느릿하게 따라다니는 검은 구름. 구름 안에 있으면 시야가 가려지고 느려짐.
## 대시로 빠르게 벗어날 수 있음. 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const RADIUS := 56.0
const SPEED := 55.0

var _dots: Array[Vector2] = []


static func spawn(context: Node, at_global: Vector2) -> FlySwarm:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var swarm := FlySwarm.new()
	parent.add_child(swarm)
	swarm.global_position = at_global
	return swarm


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = 45
	for i in 70:
		_dots.append(Vector2.from_angle(randf() * TAU) * randf_range(0.0, RADIUS))


func covers(at: Vector2) -> bool:
	return at.distance_to(global_position) <= RADIUS * 0.8


func _physics_process(delta: float) -> void:
	var player := Player.find_nearest(get_tree(), global_position)
	if player == null:
		return
	global_position = global_position.move_toward(player.global_position, SPEED * delta)
	for p in Player.get_all(get_tree()):
		if covers(p.global_position):
			p.apply_slow(0.75, 0.15)
			p.mark_floor_status("파리 떼 — 시야가 가려짐 (대시로 벗어나기)")
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.08, 0.1, 0.05, 0.55))
	var t := Time.get_ticks_msec() * 0.004
	for i in _dots.size():
		var d := _dots[i] + Vector2(sin(t + i), cos(t * 1.3 + i * 0.7)) * 4.0
		draw_rect(Rect2(d, Vector2(2, 2)), Color(0.05, 0.05, 0.04, 0.9))
