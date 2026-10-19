class_name DialogueBox
extends CanvasLayer
## 대화창: 화면 아래 패널에 초상화 · 이름 · 대사를 한 줄씩 보여 줌 (글자가 한 자씩 나옴).
## [E] · 공격 · Enter · 마우스 클릭 → 글자가 다 나오지 않았으면 한 번에 보여 주고, 다 나왔으면 다음 줄.
## 일시정지 중에도 움직이도록 PROCESS_MODE_ALWAYS. 마지막 줄을 넘기면 done.

signal done

const CHARS_PER_SECOND := 40.0
const PORTRAIT_SIZE := 56.0

var _lines: Array = []
var _index: int = 0
var _typed: float = 0.0
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _hint: Label


func _ready() -> void:
	layer = 100  # HUD 보다 위
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24.0
	panel.offset_right = -24.0
	panel.offset_top = -96.0
	panel.offset_bottom = -10.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.97)
	style.border_color = Color(0.95, 0.8, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override(&"panel", style)
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	panel.add_child(row)
	_portrait_frame = PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.16, 0.13, 0.22)
	frame_style.border_color = Color(0.6, 0.5, 0.3)
	frame_style.set_border_width_all(1)
	frame_style.set_content_margin_all(2)
	_portrait_frame.add_theme_stylebox_override(&"panel", frame_style)
	_portrait_frame.custom_minimum_size = Vector2(PORTRAIT_SIZE + 4.0, PORTRAIT_SIZE + 4.0)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_frame.add_child(_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 2)
	row.add_child(column)
	_name = Label.new()
	_name.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.45))
	_name.add_theme_font_size_override(&"font_size", 12)
	column.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override(&"font_size", 11)
	column.add_child(_text)
	_hint = Label.new()
	_hint.text = "▼ [E] 다음"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override(&"font_size", 8)
	_hint.add_theme_color_override(&"font_color", Color(0.8, 0.78, 0.7))
	column.add_child(_hint)


## lines: [{"name": 이름, "text": 대사}, …]
func start(lines: Array) -> void:
	_lines = lines
	_index = 0
	visible = true
	_show_line()


func is_typing() -> bool:
	return _text.visible_characters >= 0 and _text.visible_characters < _text.text.length()


func current_line() -> Dictionary:
	return _lines[_index] if _index < _lines.size() else {}


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker: String = line.get("name", "")
	_name.text = speaker
	_name.visible = speaker != ""
	var tex: Texture2D = Story.portrait_for(speaker) if speaker != "" else null
	_portrait.texture = tex
	_portrait_frame.visible = tex != null
	_text.text = line.get("text", "")
	_text.visible_characters = 0
	_typed = 0.0
	_hint.visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if is_typing():
		_typed += delta * CHARS_PER_SECOND
		_text.visible_characters = mini(int(_typed), _text.text.length())
	else:
		_hint.visible = true
		_hint.text = "▼ [E] 다음" if _index < _lines.size() - 1 else "■ [E] 닫기"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed := event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept")
	if not pressed and event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if pressed:
		get_viewport().set_input_as_handled()
		advance()


## 다음으로 (테스트에서도 직접 호출)
func advance() -> void:
	if not visible:
		return
	if is_typing():
		_text.visible_characters = -1
		return
	_index += 1
	if _index >= _lines.size():
		visible = false
		done.emit()
	else:
		_show_line()
