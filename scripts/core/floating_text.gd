class_name FloatingText
extends Node2D
## 데미지 숫자 / 획득 알림처럼 위로 떠오르며 사라지는 텍스트.
## 사용법: FloatingText.spawn(self, global_position, "12", Color.WHITE)

const RISE_DISTANCE := 18.0
const LIFETIME := 0.7

var _label: Label


## context 는 씬 트리 안에 있는 아무 노드나 넘기면 됩니다 (Node 여도 OK).
static func spawn(context: Node, at_global: Vector2, text: String, color: Color = Color.WHITE, big: bool = false) -> void:
	if context == null or not context.is_inside_tree():
		return
	var tree := context.get_tree()
	var parent: Node = tree.current_scene
	if parent == null:
		parent = tree.root
	var ft := FloatingText.new()
	parent.add_child(ft)
	ft.global_position = at_global + Vector2(randf_range(-4.0, 4.0), -10.0)
	ft._setup(text, color, big)


func _setup(text: String, color: Color, big: bool) -> void:
	z_index = 100
	_label = Label.new()
	var settings := LabelSettings.new()
	settings.font_size = 12 if big else 9
	settings.font_color = color
	settings.outline_size = 3
	settings.outline_color = Color(0.1, 0.1, 0.17)
	_label.label_settings = settings
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 16)
	_label.position = Vector2(-40, -8)
	add_child(_label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tween.chain().tween_callback(queue_free)
