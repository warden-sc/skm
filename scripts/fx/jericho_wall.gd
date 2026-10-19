class_name JerichoWall
extends Node2D
## 여리고 성벽 (95스테이지): 보스방 가운데의 둥근 성벽 + 바깥쪽 행진 길(lap_radius) 표시.
## 금(cracks)이 갈수록 성벽에 틈이 늘고, collapsed 면 무너진 돌무더기. 판정은 BossJerichoCaptain 이 직접 합니다.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const SEGMENTS := 28

var radius: float = 58.0
var lap_radius: float = 120.0
var cracks: int = 0
var collapsed: bool = false
var progress: float = 0.0  # 지금 도는 바퀴의 진행 (0~1)


static func spawn(context: Node, at_global: Vector2) -> JerichoWall:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var wall := JerichoWall.new()
	parent.add_child(wall)
	wall.global_position = at_global
	return wall


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = -3


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, lap_radius, 0.0, TAU, 64, Color(1.0, 0.9, 0.6, 0.18), 6.0)
	if progress > 0.0:
		draw_arc(Vector2.ZERO, lap_radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(1.0, 0.9, 0.55, 0.6), 3.0)
	if collapsed:
		for i in SEGMENTS:
			var a := TAU * i / SEGMENTS
			draw_circle(Vector2.from_angle(a) * (radius + sin(i * 7.0) * 8.0), 5.0, Color(0.55, 0.45, 0.35))
		return
	for i in SEGMENTS:
		if (i * 5) % SEGMENTS < cracks * 2:  # 금이 갈수록 비는 칸이 늘어남
			continue
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS - 0.03
		draw_arc(Vector2.ZERO, radius, a0, a1, 4, Color(0.62, 0.5, 0.36), 10.0)
		draw_arc(Vector2.ZERO, radius + 4.0, a0, a1, 4, Color(0.78, 0.66, 0.5), 2.0)
