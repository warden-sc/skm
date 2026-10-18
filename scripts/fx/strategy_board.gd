class_name StrategyBoard
extends Node2D
## 전략의 수 (80스테이지 아테나): 보스방 바닥을 COLS x ROWS 칸으로 나누고, 아테나가 둘 「다음 세 수」를 미리 보여 줌.
## 수마다 칸 몇 개가 번호와 함께 표시되고, 정해진 시간에 그 칸들이 차례로 터짐 (판정은 이 노드가, 피해는 hit_callback 으로).
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const COLS := 6
const ROWS := 4

var area: Rect2 = Rect2()
## {cells: Array[Vector2i], at: float(남은 시간), index: int}
var moves: Array[Dictionary] = []
var hit_callback: Callable
var _font: Font


static func spawn(context: Node, bounds: Rect2) -> StrategyBoard:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var board := StrategyBoard.new()
	board.area = bounds
	parent.add_child(board)
	board.global_position = Vector2.ZERO
	return board


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = -4
	_font = ThemeDB.fallback_font


func cell_size() -> Vector2:
	return Vector2(area.size.x / COLS, area.size.y / ROWS)


func cell_rect(cell: Vector2i) -> Rect2:
	var s := cell_size()
	return Rect2(area.position + Vector2(cell.x * s.x, cell.y * s.y), s)


func cell_of(at: Vector2) -> Vector2i:
	var s := cell_size()
	return Vector2i(clampi(int((at.x - area.position.x) / s.x), 0, COLS - 1), clampi(int((at.y - area.position.y) / s.y), 0, ROWS - 1))


## 세 수를 미리 둠: 수마다 cells_per_move 칸, first_delay 초 뒤부터 step 초 간격으로 터짐
func plan(move_count: int, cells_per_move: int, first_delay: float, step: float) -> void:
	moves.clear()
	for m in move_count:
		var cells: Array[Vector2i] = []
		while cells.size() < cells_per_move:
			var c := Vector2i(randi() % COLS, randi() % ROWS)
			if not cells.has(c):
				cells.append(c)
		moves.append({"cells": cells, "at": first_delay + step * m, "index": m + 1})
	queue_redraw()


func is_cell_marked(cell: Vector2i) -> bool:
	for mv in moves:
		if (mv["cells"] as Array).has(cell):
			return true
	return false


func _physics_process(delta: float) -> void:
	if moves.is_empty():
		return
	for mv in moves:
		mv["at"] -= delta
	for mv in moves.duplicate():
		if mv["at"] <= 0.0:
			moves.erase(mv)
			for cell in mv["cells"]:
				var r := cell_rect(cell)
				Fx.flash(self, r.get_center(), Color(0.6, 0.75, 1.0), r.size.x * 0.5, 0.35)
			if hit_callback.is_valid():
				hit_callback.call(mv["cells"])
	queue_redraw()


func _draw() -> void:
	var s := cell_size()
	for x in COLS + 1:
		draw_line(area.position + Vector2(x * s.x, 0), area.position + Vector2(x * s.x, area.size.y), Color(0.5, 0.6, 0.8, 0.18), 1.0)
	for y in ROWS + 1:
		draw_line(area.position + Vector2(0, y * s.y), area.position + Vector2(area.size.x, y * s.y), Color(0.5, 0.6, 0.8, 0.18), 1.0)
	for mv in moves:
		var urgent := clampf(1.0 - float(mv["at"]) / 3.0, 0.0, 1.0)
		for cell in mv["cells"]:
			var r := cell_rect(cell).grow(-3.0)
			draw_rect(r, Color(0.45, 0.6, 1.0, 0.12 + 0.3 * urgent))
			draw_rect(r, Color(0.7, 0.8, 1.0, 0.7), false, 1.0)
			if _font != null:
				draw_string(_font, r.get_center() + Vector2(-5, 6), str(mv["index"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 1.0, 0.9))
