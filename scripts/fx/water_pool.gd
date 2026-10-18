class_name WaterPool
extends Node2D
## 물웅덩이 (38스테이지 탈로스 기믹): 달궈진 탈로스를 여기로 유인하면 몸이 식음.
## 판정은 BossTalos 가 contains() 로. 스테이지가 바뀌면 storm_fields 그룹으로 정리.

var radius: float = 34.0
var _time: float = 0.0
var _steam: float = 0.0


static func spawn(context: Node, at_global: Vector2, size: float) -> WaterPool:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var pool := WaterPool.new()
	pool.radius = size
	pool.z_index = -5
	root.add_child(pool)
	pool.global_position = at_global
	return pool


func _ready() -> void:
	add_to_group(&"storm_fields")
	add_to_group(&"water_pools")


func contains(point: Vector2) -> bool:
	var d := point - global_position
	return (d.x * d.x) / (radius * radius) + (d.y * d.y) / (radius * radius * 0.49) <= 1.0


## 탈로스가 들어와 식을 때 김 연출
func steam() -> void:
	_steam = 1.2
	Fx.burst(self, global_position + Vector2(0, -6), Color(0.9, 0.95, 1.0), 26, 50.0, 0.8, Vector2(0, -60), 1.6)


func _physics_process(delta: float) -> void:
	_time += delta
	_steam = maxf(_steam - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.45, 0.75, 0.55))
	draw_circle(Vector2(-radius * 0.2, -radius * 0.15), radius * 0.6, Color(0.4, 0.7, 0.95, 0.35))
	for i in 3:
		var r := fmod(_time * 10.0 + i * radius / 3.0, radius)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0.8, 0.95, 1.0, 0.35 * (1.0 - r / radius)), 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.75, 0.9, 1.0, 0.8), 1.5)
	if _steam > 0.0:
		draw_circle(Vector2.ZERO, radius * 0.9, Color(1, 1, 1, 0.3 * _steam))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
