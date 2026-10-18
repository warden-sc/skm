class_name UpdraftPad
extends Node2D
## 상승 기류 발판 (45스테이지 안타이오스 기믹): 안타이오스가 밟으면 공중으로 떠오름 (땅의 힘이 끊김).
## 판정은 BossAntaeus 가 contains() 로. 한 번 띄운 뒤 cooldown 초 동안 쉼.

var radius: float = 26.0
var cooldown: float = 8.0
var _cool_left: float = 0.0
var _time: float = 0.0


static func spawn(context: Node, at_global: Vector2) -> UpdraftPad:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var pad := UpdraftPad.new()
	pad.z_index = -5
	root.add_child(pad)
	pad.global_position = at_global
	return pad


func _ready() -> void:
	add_to_group(&"storm_fields")
	add_to_group(&"updraft_pads")


func is_ready() -> bool:
	return _cool_left <= 0.0


func contains(point: Vector2) -> bool:
	return point.distance_to(global_position) <= radius


func use() -> void:
	_cool_left = cooldown
	Fx.burst(self, global_position, Color(0.85, 1.0, 0.95), 26, 90.0, 0.6, Vector2(0, -120), 1.4)


func _physics_process(delta: float) -> void:
	_time += delta
	_cool_left = maxf(_cool_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var a := 0.8 if is_ready() else 0.25
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, radius, Color(0.7, 0.95, 0.9, 0.2 * a))
	for i in 3:
		var r := fmod(_time * 18.0 + i * radius / 3.0, radius)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(0.85, 1.0, 0.95, a * (1.0 - r / radius)), 1.5)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.85, 1.0, 0.95, a), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 3:
		var x := -10.0 + 10.0 * k
		var y := -fmod(_time * 30.0 + k * 9.0, 26.0)
		draw_line(Vector2(x, y), Vector2(x, y - 6), Color(0.9, 1.0, 1.0, 0.6 * a), 1.0)
