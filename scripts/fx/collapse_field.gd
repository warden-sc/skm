class_name CollapseField
extends Node2D
## 대정령 가이아의 「대지의 숨결」 (30스테이지 기믹): 보스방 바닥을 3×3 구역으로 나눠, 몇 구역씩 무너뜨립니다.
##   1) warn(구역들, 시간) — 그 구역 바닥에 금이 가며 붉게 깜빡임
##   2) collapse() — 그 구역이 무너져 내림 (연출), 판정은 BossGaia 가 is_in_tile() 로
## 스테이지가 바뀌면 StageManager 가 storm_fields 그룹을 정리합니다.

const COLS := 3
const ROWS := 3

var area: Rect2 = Rect2()
var _warn: Array[int] = []
var _warn_left: float = 0.0
var _warn_total: float = 1.0
var _fallen: Array[int] = []
var _fallen_left: float = 0.0
var _time: float = 0.0


static func spawn(context: Node, arena: Rect2) -> CollapseField:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var field := CollapseField.new()
	field.area = arena
	field.z_index = -4
	field.add_to_group(&"storm_fields")
	root.add_child(field)
	field.global_position = Vector2.ZERO
	return field


func get_tile_rect(index: int) -> Rect2:
	var w := area.size.x / COLS
	var h := area.size.y / ROWS
	@warning_ignore("integer_division")
	var row := index / COLS
	return Rect2(area.position + Vector2(w * (index % COLS), h * row), Vector2(w, h))


func tile_of(point: Vector2) -> int:
	for i in COLS * ROWS:
		if get_tile_rect(i).has_point(point):
			return i
	return -1


func is_in_tile(point: Vector2, tiles: Array[int]) -> bool:
	return tiles.has(tile_of(point))


func get_warned() -> Array[int]:
	return _warn


func warn(tiles: Array[int], time: float) -> void:
	_warn = tiles
	_warn_left = time
	_warn_total = maxf(time, 0.01)


func collapse() -> void:
	_fallen = _warn.duplicate()
	_fallen_left = 2.5
	for i in _fallen:
		var r := get_tile_rect(i)
		for k in 6:
			Fx.burst(self, r.position + Vector2(randf() * r.size.x, randf() * r.size.y), Color(0.45, 0.35, 0.25), 6, 60.0, 0.4, Vector2(0, 150))
	_warn = []
	_warn_left = 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	_warn_left = maxf(_warn_left - delta, 0.0)
	_fallen_left = maxf(_fallen_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	for i in COLS * ROWS:
		var r := get_tile_rect(i)
		draw_rect(r, Color(0.3, 0.25, 0.15, 0.25), false, 1.0)
	if _warn_left > 0.0:
		var t := 1.0 - _warn_left / _warn_total
		for i in _warn:
			var r := get_tile_rect(i)
			draw_rect(r, Color(1.0, 0.3, 0.15, 0.12 + 0.18 * absf(sin(_time * (8.0 + 12.0 * t)))))
			for k in 5:   # 갈라지는 금
				var a := r.position + Vector2(r.size.x * (0.15 + 0.17 * k), r.size.y * 0.1)
				draw_line(a, a + Vector2(sin(k * 1.7) * 14.0, r.size.y * 0.8 * t), Color(0.25, 0.15, 0.08, 0.8), 2.0)
	if _fallen_left > 0.0:
		for i in _fallen:
			draw_rect(get_tile_rect(i), Color(0.05, 0.03, 0.02, 0.6 * clampf(_fallen_left / 1.0, 0.0, 1.0)))
