class_name WebPatch
extends Node2D
## 아라크네의 거미줄 (46스테이지 기믹): 바닥에 깔린 거미줄. 밟으면 느려지고, bind_time 초 넘게 서 있으면 묶임.
## fade() 로 서서히 사라짐 (베틀이 부서졌을 때). 스테이지가 바뀌면 storm_fields 그룹으로 정리.

var radius: float = 30.0
var bind_time: float = 1.2
var _stand: float = 0.0
## 멀티플레이: 용사마다 거미줄 위에 서 있던 시간
var _stands: Dictionary = {}
var _fade_left: float = -1.0
var _time: float = 0.0


static func spawn(context: Node, at_global: Vector2, size: float) -> WebPatch:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var web := WebPatch.new()
	web.radius = size
	web.z_index = -5
	root.add_child(web)
	web.global_position = at_global
	return web


func _ready() -> void:
	add_to_group(&"storm_fields")
	add_to_group(&"webs")


func contains(point: Vector2) -> bool:
	return point.distance_to(global_position) <= radius


func fade(time: float = 1.5) -> void:
	if _fade_left < 0.0:
		_fade_left = time


func _physics_process(delta: float) -> void:
	_time += delta
	if _fade_left >= 0.0:
		_fade_left -= delta
		if _fade_left <= 0.0:
			queue_free()
			return
	var anyone := false
	for player in Player.get_all(get_tree()):
		var stand: float = _stands.get(player.get_instance_id(), 0.0)
		if contains(player.global_position) and not player.is_dashing():
			anyone = true
			player.apply_slow(0.5, 0.2)
			player.mark_floor_status("거미줄 (이동 속도 -50%, 오래 서 있으면 묶임)")
			stand += delta
			if stand >= bind_time and not player.is_rooted():
				stand = 0.0
				player.apply_root(1.5, "거미줄에 묶임! (1.5초)")
		else:
			stand = maxf(stand - delta * 2.0, 0.0)
		_stands[player.get_instance_id()] = stand
	_stand = _stands.values().max() if anyone and not _stands.is_empty() else maxf(_stand - delta * 2.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var a := 0.75 if _fade_left < 0.0 else clampf(_fade_left / 1.5, 0.0, 1.0) * 0.75
	for k in 8:
		draw_line(Vector2.ZERO, Vector2.from_angle(TAU * k / 8.0) * radius, Color(0.95, 0.95, 1.0, a), 1.0)
	for r in [0.35, 0.65, 0.95]:
		var pts := PackedVector2Array()
		for k in 9:
			pts.append(Vector2.from_angle(TAU * k / 8.0) * radius * float(r))
		draw_polyline(pts, Color(0.95, 0.95, 1.0, a * 0.8), 1.0)
