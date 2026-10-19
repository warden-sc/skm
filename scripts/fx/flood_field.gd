class_name FloodField
extends Node2D
## 홍수 (96스테이지 네피림 왕): 보스방 전체를 덮는 물(level 0~1)과 물 위를 떠다니는 방주 판자.
## 물에 잠기는지 · 판자 위인지 판정은 BossNephilimKing 이 is_on_plank() 로. 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const PLANK_RADIUS := 24.0

var area: Rect2 = Rect2()
var level: float = 0.0
var planks: Array[Vector2] = []
var plank_texture: Texture2D
var _plank_vel: Array[Vector2] = []
var _time: float = 0.0


static func spawn(context: Node, bounds: Rect2, plank_count: int, texture: Texture2D) -> FloodField:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var flood := FloodField.new()
	flood.area = bounds
	flood.plank_texture = texture
	for i in plank_count:
		var at := bounds.get_center() + Vector2(cos(TAU * i / plank_count) * bounds.size.x * 0.3, sin(TAU * i / plank_count) * bounds.size.y * 0.28)
		flood.planks.append(at)
		flood._plank_vel.append(Vector2.from_angle(TAU * i / plank_count + 1.3) * 14.0)
	parent.add_child(flood)
	flood.global_position = bounds.get_center()
	return flood


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = -3


func is_on_plank(at: Vector2) -> bool:
	for p in planks:
		if at.distance_to(p) <= PLANK_RADIUS:
			return true
	return false


func _physics_process(delta: float) -> void:
	_time += delta
	var bounds := area.grow(-30.0)
	for i in planks.size():
		var p := planks[i] + _plank_vel[i] * delta * (0.4 + level)
		if p.x < bounds.position.x or p.x > bounds.end.x:
			_plank_vel[i].x = -_plank_vel[i].x
		if p.y < bounds.position.y or p.y > bounds.end.y:
			_plank_vel[i].y = -_plank_vel[i].y
		planks[i] = p.clamp(bounds.position, bounds.end)
	queue_redraw()


func _draw() -> void:
	if level > 0.0:
		var r := Rect2(area.position - global_position, area.size)
		draw_rect(r, Color(0.2, 0.4, 0.7, 0.5 * level))
		for i in 6:
			var y := r.position.y + fmod(_time * 12.0 + i * r.size.y / 6.0, r.size.y)
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.7, 0.85, 1.0, 0.18 * level), 1.0)
	if plank_texture != null:
		for p in planks:
			var at := to_local(p) - plank_texture.get_size() * 0.5
			draw_texture(plank_texture, at, Color(1, 1, 1, 0.55 + 0.45 * level))
