class_name AriadneThread
extends Node2D
## 아리아드네의 실 (39스테이지 기믹): 미궁의 함정이 터지기 전, 바닥에 금빛 실이 깔림.
## 실 위(width 이내)에 서 있어야 함정을 피함 — 판정은 BossMinotaur 가 is_on_thread() 로.

var points: PackedVector2Array = PackedVector2Array()
var area: Rect2 = Rect2()
var width: float = 16.0
var _left: float = 0.0
var _total: float = 1.0
var _time: float = 0.0


static func spawn(context: Node, arena: Rect2, path: PackedVector2Array, warn_time: float) -> AriadneThread:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var thread := AriadneThread.new()
	thread.area = arena
	thread.points = path
	thread._left = warn_time
	thread._total = maxf(warn_time, 0.01)
	thread.z_index = -4
	root.add_child(thread)
	thread.global_position = Vector2.ZERO
	return thread


## start 에서 시작해 이리저리 꺾이며 뻗어 가는 실
static func make_path(arena: Rect2, start: Vector2, segments: int = 6, step: float = 70.0) -> PackedVector2Array:
	var path := PackedVector2Array([start])
	var p := start
	var dir := Vector2.from_angle(randf() * TAU)
	for i in segments:
		dir = dir.rotated(randf_range(-1.2, 1.2))
		var next := (p + dir * step).clamp(arena.position + Vector2(16, 16), arena.end - Vector2(16, 16))
		if next.distance_to(p) < step * 0.5:
			dir = (arena.get_center() - p).normalized()
			next = (p + dir * step).clamp(arena.position + Vector2(16, 16), arena.end - Vector2(16, 16))
		path.append(next)
		p = next
	return path


func _ready() -> void:
	add_to_group(&"storm_fields")


func is_on_thread(point: Vector2) -> bool:
	for i in points.size() - 1:
		if Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1]).distance_to(point) <= width:
			return true
	return false


func _physics_process(delta: float) -> void:
	_time += delta
	_left = maxf(_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var t := 1.0 - _left / _total
	draw_rect(area, Color(0.8, 0.15, 0.1, 0.08 + 0.12 * absf(sin(_time * (5.0 + 10.0 * t)))))
	if points.size() >= 2:
		draw_polyline(points, Color(1.0, 0.85, 0.35, 0.35), width * 2.0)
		draw_polyline(points, Color(1.0, 0.92, 0.5), 2.0)
