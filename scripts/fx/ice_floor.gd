class_name IceFloor
extends Node2D
## 빙판 (33스테이지 코퀴로스 · 히든 아르케): 밟은 플레이어는 미끄러짐 (Player.mark_slippery).
## lifetime 뒤 녹아 사라짐. 스테이지가 바뀌면 StageManager 가 storm_fields 그룹을 정리합니다.

var radius: float = 34.0
var lifetime: float = 18.0
var _age: float = 0.0


static func spawn(context: Node, at_global: Vector2, size: float, life: float = 18.0) -> IceFloor:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var ice := IceFloor.new()
	ice.radius = size
	ice.lifetime = life
	ice.z_index = -5
	root.add_child(ice)
	ice.global_position = at_global
	return ice


func _ready() -> void:
	add_to_group(&"storm_fields")
	add_to_group(&"ice_floors")


func contains(point: Vector2) -> bool:
	var d := point - global_position
	return (d.x * d.x) / (radius * radius) + (d.y * d.y) / (radius * radius * 0.49) <= 1.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and contains(player.global_position):
		player.mark_slippery()
	queue_redraw()


func _draw() -> void:
	var fade := clampf((lifetime - _age) / 1.0, 0.0, 1.0) * clampf(_age / 0.25, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, radius, Color(0.7, 0.9, 1.0, 0.38 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.9, 0.97, 1.0, 0.7 * fade), 1.5)
	for i in 4:
		var a := i * 1.3 + 0.4
		draw_line(Vector2.from_angle(a) * radius * 0.2, Vector2.from_angle(a) * radius * 0.75, Color(1, 1, 1, 0.45 * fade), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
