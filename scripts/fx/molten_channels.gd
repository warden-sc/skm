class_name MoltenChannels
extends Node2D
## 헤파이스토스의 용광로 (50스테이지 기믹): 보스방 바닥의 홈(가로 또는 세로 줄)을 따라 쇳물이 흐름.
## - warn(lanes, vertical, time): 그 홈들이 붉게 달아오름 (예고)
## - pour(time): 예고한 홈에 쇳물이 흐름 → 그 위에 있으면 0.5초마다 최대 체력의 tick_ratio 피해 (가드·대시 불가)
## 홈 사이의 빈 땅에 서 있어야 함. 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const LANES := 5
const WIDTH := 30.0

var area: Rect2 = Rect2()
var tick_ratio: float = 0.12
var vertical: bool = false
var lanes: Array[int] = []
var hits: int = 0
var _warn_left: float = 0.0
var _warn_total: float = 1.0
var _pour_left: float = 0.0
var _tick: float = 0.0
var _time: float = 0.0


static func spawn(context: Node, arena: Rect2) -> MoltenChannels:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var ch := MoltenChannels.new()
	ch.area = arena
	ch.z_index = -4
	root.add_child(ch)
	ch.global_position = Vector2.ZERO
	return ch


func _ready() -> void:
	add_to_group(&"storm_fields")


func lane_rect(i: int, is_vertical: bool) -> Rect2:
	if is_vertical:
		var step := area.size.x / LANES
		return Rect2(Vector2(area.position.x + step * (i + 0.5) - WIDTH * 0.5, area.position.y), Vector2(WIDTH, area.size.y))
	var step_y := area.size.y / LANES
	return Rect2(Vector2(area.position.x, area.position.y + step_y * (i + 0.5) - WIDTH * 0.5), Vector2(area.size.x, WIDTH))


func is_in_flow(point: Vector2) -> bool:
	if _pour_left <= 0.0:
		return false
	for i in lanes:
		if lane_rect(i, vertical).has_point(point):
			return true
	return false


func is_warning() -> bool:
	return _warn_left > 0.0


func is_pouring() -> bool:
	return _pour_left > 0.0


func warn(new_lanes: Array[int], is_vertical: bool, time: float) -> void:
	lanes = new_lanes
	vertical = is_vertical
	_warn_left = time
	_warn_total = maxf(time, 0.01)
	_pour_left = 0.0


func pour(time: float) -> void:
	_warn_left = 0.0
	_pour_left = time
	_tick = 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	_warn_left = maxf(_warn_left - delta, 0.0)
	if _pour_left > 0.0:
		_pour_left -= delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.5
			for player in Player.get_all(get_tree()):
				if is_in_flow(player.global_position) and player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * tick_ratio)), player.global_position + Vector2(0, -6), false) == Player.HitResult.DAMAGED:
					hits += 1
					player.apply_burn(10, 2.0)
	queue_redraw()


func _draw() -> void:
	for i in LANES:  # 바닥의 홈
		var r := lane_rect(i, vertical if (_warn_left > 0.0 or _pour_left > 0.0) else false)
		draw_rect(r, Color(0.15, 0.1, 0.08, 0.35))
	if _warn_left > 0.0:
		var t := 1.0 - _warn_left / _warn_total
		for i in lanes:
			draw_rect(lane_rect(i, vertical), Color(1.0, 0.4, 0.1, 0.12 + 0.25 * absf(sin(_time * (6.0 + 12.0 * t)))))
	if _pour_left > 0.0:
		for i in lanes:
			var r := lane_rect(i, vertical)
			draw_rect(r, Color(1.0, 0.45, 0.08, 0.85))
			var flow := fmod(_time * 80.0, 24.0)
			var length := r.size.y if vertical else r.size.x
			var k := 0.0
			while k < length:
				var p := r.position + (Vector2(r.size.x * 0.5, k + flow) if vertical else Vector2(k + flow, r.size.y * 0.5))
				if r.has_point(p):
					draw_circle(p, 3.0, Color(1.0, 0.9, 0.4, 0.8))
				k += 24.0
