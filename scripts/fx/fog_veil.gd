class_name FogVeil
extends Node2D
## 안개의 전장 (73스테이지 디오메데스): 보스방을 덮은 짙은 안개. 아테나의 등불 둘레(light_radius)만 걷혀 보임.
## 등불 위치는 매 프레임 light_at 으로 받음. 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const CELL := 20.0

var area: Rect2 = Rect2()
var light_at: Vector2 = Vector2.ZERO
var light_radius: float = 100.0


static func spawn(context: Node, bounds: Rect2) -> FogVeil:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var veil := FogVeil.new()
	veil.area = bounds
	parent.add_child(veil)
	veil.global_position = Vector2.ZERO
	return veil


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = 40


func is_lit(at: Vector2) -> bool:
	return at.distance_to(light_at) <= light_radius


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.0006
	var y := area.position.y
	while y < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			var c := Vector2(x + CELL * 0.5, y + CELL * 0.5)
			var d := c.distance_to(light_at)
			if d > light_radius - CELL:
				var a := clampf((d - light_radius + CELL) / (CELL * 2.0), 0.0, 1.0) * (0.62 + 0.08 * sin(t + x * 0.03 + y * 0.05))
				draw_rect(Rect2(x, y, CELL, CELL), Color(0.78, 0.8, 0.84, a))
			x += CELL
		y += CELL
