class_name DragonRunes
extends Node2D
## 고대 용 아르케의 「고대 용언」 (히든 기믹): 보스방에 네 원소의 룬 원이 나타나고,
## 아르케가 외친 원소의 원 안에 있어야만 용언의 폭발을 피할 수 있습니다.
## 판정은 BossArche 가 safe_contains() 로 합니다. 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const NAMES := ["바람", "대지", "얼음", "화염"]
const COLORS := [Color(0.6, 1.0, 0.8), Color(0.85, 0.65, 0.35), Color(0.6, 0.85, 1.0), Color(1.0, 0.45, 0.2)]
const RADIUS := 30.0

var centers: Array[Vector2] = []
var safe_index: int = -1
var _left: float = 0.0
var _total: float = 1.0
var _time: float = 0.0
var _labels: Array[Label] = []


static func spawn(context: Node, points: Array[Vector2], safe: int, warn_time: float) -> DragonRunes:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var runes := DragonRunes.new()
	runes.centers = points
	runes.safe_index = safe
	runes._left = warn_time
	runes._total = maxf(warn_time, 0.01)
	runes.z_index = -4
	root.add_child(runes)
	runes.global_position = Vector2.ZERO
	return runes


func _ready() -> void:
	add_to_group(&"storm_fields")
	for i in centers.size():
		var label := Label.new()
		label.text = NAMES[i % 4]
		label.add_theme_font_size_override(&"font_size", 10)
		label.add_theme_color_override(&"font_color", COLORS[i % 4])
		label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.03, 0.02))
		label.add_theme_constant_override(&"outline_size", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(60, 14)
		label.position = centers[i] + Vector2(-30, -RADIUS - 16)
		label.z_index = 60
		add_child(label)
		_labels.append(label)


func safe_contains(point: Vector2) -> bool:
	return safe_index >= 0 and safe_index < centers.size() and point.distance_to(centers[safe_index]) <= RADIUS


func get_time_left() -> float:
	return _left


func _physics_process(delta: float) -> void:
	_time += delta
	_left = maxf(_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var t := 1.0 - _left / _total
	for i in centers.size():
		var col: Color = COLORS[i % 4]
		draw_circle(centers[i], RADIUS, Color(col, 0.16 + 0.1 * sin(_time * 6.0 + i)))
		draw_arc(centers[i], RADIUS, 0.0, TAU, 32, Color(col, 0.9), 2.0)
		draw_arc(centers[i], RADIUS * (1.0 - t), 0.0, TAU, 24, Color(col, 0.5), 1.0)
		for k in 6:  # 룬 문양
			var a := _time * 0.8 + k * TAU / 6.0
			draw_line(centers[i] + Vector2.from_angle(a) * RADIUS * 0.55, centers[i] + Vector2.from_angle(a + 0.5) * RADIUS * 0.8, Color(col, 0.7), 1.0)
