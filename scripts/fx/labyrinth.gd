class_name Labyrinth
extends Node2D
## 미노타우로스의 움직이는 미궁 (39스테이지 기믹): 보스방에 돌벽(몸·탄을 막음)이 서고, 일정 시간마다 자리가 바뀜.
## - rebuild(): 새 벽 배치 (플레이어·보스 근처에는 세우지 않음)
## - warn(time): 바뀔 자리를 점선으로 미리 보여 줌 → time 뒤 rebuild
## - hits_wall(point, margin): 돌진하던 미노타우로스가 벽에 부딪혔는지
## 스테이지가 바뀌면 storm_fields 그룹으로 정리 (벽은 자식이라 함께 사라짐).

const THICKNESS := 10.0

var area: Rect2 = Rect2()
var wall_count: int = 7
var walls: Array[Rect2] = []
var _next: Array[Rect2] = []
var _warn_left: float = 0.0
var _bodies: Array[StaticBody2D] = []
var _time: float = 0.0
var _rebuilds: int = 0


static func spawn(context: Node, arena: Rect2, count: int) -> Labyrinth:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var maze := Labyrinth.new()
	maze.area = arena
	maze.wall_count = count
	maze.z_index = -3
	root.add_child(maze)
	maze.global_position = Vector2.ZERO
	return maze


func _ready() -> void:
	add_to_group(&"storm_fields")


func get_rebuild_count() -> int:
	return _rebuilds


func is_warning() -> bool:
	return _warn_left > 0.0


## avoid: 벽을 세우지 않을 지점들 (플레이어 · 보스)
func plan(avoid: Array[Vector2]) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var tries := 0
	while result.size() < wall_count and tries < 200:
		tries += 1
		var horizontal := randf() < 0.5
		var length := randf_range(80.0, 150.0)
		var size := Vector2(length, THICKNESS) if horizontal else Vector2(THICKNESS, length * 0.7)
		var pos := Vector2(randf_range(area.position.x + 20.0, area.end.x - size.x - 20.0), randf_range(area.position.y + 30.0, area.end.y - size.y - 20.0))
		var r := Rect2(pos, size)
		var ok := true
		for p in avoid:
			if r.grow(28.0).has_point(p):
				ok = false
		for other in result:
			if r.grow(26.0).intersects(other):
				ok = false
		if ok:
			result.append(r)
	return result


func rebuild(avoid: Array[Vector2]) -> void:
	_apply(plan(avoid))


func warn(time: float, avoid: Array[Vector2]) -> void:
	_next = plan(avoid)
	_warn_left = time


func _apply(new_walls: Array[Rect2]) -> void:
	for body in _bodies:
		if is_instance_valid(body):
			body.queue_free()
	_bodies.clear()
	walls = new_walls
	_rebuilds += 1
	for r in walls:
		var body := StaticBody2D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		body.add_child(shape)
		add_child(body)
		body.global_position = r.get_center()
		_bodies.append(body)
		Fx.burst(self, r.get_center(), Color(0.6, 0.55, 0.45), 8, 40.0, 0.3, Vector2(0, 60))


func hits_wall(point: Vector2, margin: float = 6.0) -> bool:
	for r in walls:
		if r.grow(margin).has_point(point):
			return true
	return false


func _physics_process(delta: float) -> void:
	_time += delta
	if _warn_left > 0.0:
		_warn_left -= delta
		if _warn_left <= 0.0:
			_apply(_next)
			_next = []
	queue_redraw()


func _draw() -> void:
	for r in walls:
		draw_rect(r, Color(0.42, 0.36, 0.3))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), Color(0.6, 0.53, 0.45))
		draw_rect(r, Color(0.2, 0.16, 0.12), false, 1.0)
		if _warn_left > 0.0:
			draw_rect(r, Color(1, 1, 1, 0.25 * absf(sin(_time * 12.0))))
	for r in _next:  # 새로 설 자리 (점선)
		var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], Color(1.0, 0.85, 0.4, 0.8), 1.0, 4.0)
