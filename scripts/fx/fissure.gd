class_name Fissure
extends Node2D
## 델포이의 갈라진 땅 틈 (62스테이지 피톤 기믹): 피톤이 숨었다 나오는 구멍.
## 월계수 가지를 꽂으면 막혀서(plugged) 더는 드나들 수 없음.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const LAUREL: Texture2D = preload("res://assets/sprites/characters/laurel_branch.png")

var plugged: bool = false
var _fume: CPUParticles2D
var _laurel: Sprite2D


static func spawn(context: Node, at_global: Vector2) -> Fissure:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var fissure := Fissure.new()
	parent.add_child(fissure)
	fissure.global_position = at_global
	return fissure


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = -4
	_fume = Fx.make_aura(Color(0.8, 0.75, 0.95), 8, 10.0, Vector2(0, -30), 0.9)
	add_child(_fume)
	_fume.emitting = true
	_laurel = Sprite2D.new()
	_laurel.texture = LAUREL
	_laurel.position = Vector2(0, -6)
	_laurel.visible = false
	add_child(_laurel)


func plug() -> void:
	if plugged:
		return
	plugged = true
	_laurel.visible = true
	_fume.emitting = false
	Fx.burst(self, global_position, Color(0.5, 0.9, 0.4), 16, 50.0, 0.5, Vector2(0, -40))
	queue_redraw()


func _draw() -> void:
	var dark := Color(0.12, 0.08, 0.06, 0.9) if not plugged else Color(0.25, 0.3, 0.2, 0.8)
	var pts := PackedVector2Array([Vector2(-22, 0), Vector2(-10, -5), Vector2(0, -2), Vector2(12, -6), Vector2(22, 0), Vector2(10, 5), Vector2(-2, 3), Vector2(-12, 6)])
	draw_colored_polygon(pts, dark)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.4, 0.3, 0.25, 0.9), 1.0)
