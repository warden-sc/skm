class_name DialogueBox
extends CanvasLayer
## 대화창: 화면 아래 패널에 초상화 · 이름 · 대사를 한 줄씩 보여 줌 (글자가 한 자씩 나옴).
## Enter 키로만 넘김 → 글자가 다 나오지 않았으면 한 번에 보여 주고, 다 나왔으면 다음 줄.
## 오른쪽 위 [스킵] 버튼 → 이 대화를 끝까지 건너뜀 (@연출 장면은 그대로 틀어짐).
## 일시정지 중에도 움직이도록 PROCESS_MODE_ALWAYS. 마지막 줄을 넘기면 done.

signal done

const CHARS_PER_SECOND := 40.0
const PORTRAIT_SIZE := 56.0
## 표정이 바뀔 때(이름[표정]) 평소 얼굴을 보여 주는 시간
const FACE_CHANGE_TIME := 0.45

## @연출 장면을 보는 동안 남은 시간 (대화창 숨김)
var _cue_wait: float = 0.0
var _lines: Array = []
var _index: int = 0
var _typed: float = 0.0
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _hint: Label
var skip_button: Button
var _face: String = ""
var _face_left: float = 0.0
var _face_texture: Texture2D


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
	# 대화창 오른쪽 위 모서리에 걸친 [스킵] 버튼
	skip_button = Button.new()
	skip_button.text = "스킵 ▶▶"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.anchor_left = 1.0
	skip_button.anchor_right = 1.0
	skip_button.anchor_top = 1.0
	skip_button.anchor_bottom = 1.0
	skip_button.offset_left = -96.0
	skip_button.offset_right = -30.0
	skip_button.offset_top = -112.0
	skip_button.offset_bottom = -92.0
	skip_button.add_theme_font_size_override(&"font_size", 9)
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color(0.14, 0.11, 0.2, 0.97)
	skip_style.border_color = Color(0.95, 0.8, 0.45)
	skip_style.set_border_width_all(1)
	skip_style.set_corner_radius_all(3)
	skip_style.set_content_margin_all(2)
	var skip_hover := skip_style.duplicate() as StyleBoxFlat
	skip_hover.bg_color = Color(0.3, 0.24, 0.4, 0.97)
	skip_button.add_theme_stylebox_override(&"normal", skip_style)
	skip_button.add_theme_stylebox_override(&"hover", skip_hover)
	skip_button.add_theme_stylebox_override(&"pressed", skip_hover)
	skip_button.add_theme_color_override(&"font_color", Color(1.0, 0.88, 0.55))
	skip_button.pressed.connect(skip_all)
	root.add_child(skip_button)
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
	_hint.text = "▼ [Enter] 다음"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override(&"font_size", 8)
	_hint.add_theme_color_override(&"font_color", Color(0.8, 0.78, 0.7))
	column.add_child(_hint)


## lines: [{"name": 이름, "text": 대사}, …]
func start(lines: Array) -> void:
	_lines = lines
	_index = 0
	_face = ""
	visible = true
	_show_line()


func is_typing() -> bool:
	return _text.visible_characters >= 0 and _text.visible_characters < _text.text.length()


func current_line() -> Dictionary:
	return _lines[_index] if _index < _lines.size() else {}


func _show_line() -> void:
	# @연출 줄: 장면을 틀고 다음 대사로 (장면을 먼저 봐야 하는 것은 그동안 대화창을 숨기고 기다림 — StoryCues.WAIT)
	var wait := 0.0
	while _index < _lines.size() and (_lines[_index] as Dictionary).has("cue"):
		Story.run_cue(_lines[_index]["cue"])
		wait = maxf(wait, StoryCues.wait_time(_lines[_index]["cue"]))
		_index += 1
	if wait > 0.0 and _index < _lines.size():
		_cue_wait = wait
		_set_panel_shown(false)
		return
	_display_line()


## 대화창이 숨어 있는 동안 (@연출 장면을 보는 중) — 엔터로 넘기지 않음
func is_waiting_cue() -> bool:
	return _cue_wait > 0.0


func _set_panel_shown(on: bool) -> void:
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = on


func _display_line() -> void:
	_set_panel_shown(true)
	if _index >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_index]
	var speaker: String = line.get("name", "")
	var face: String = line.get("face", speaker)
	_name.text = speaker
	_name.visible = speaker != ""
	var tex: Texture2D = Story.portrait_for(face) if face != "" else null
	_face_left = 0.0
	# 표정이 바뀌는 줄: 평소 얼굴을 잠깐 보였다가 표정으로 (예: 상인[미소] — 입꼬리가 올라감)
	if face != _face and face.ends_with("]") and Story.portraits.has(face):
		var plain := Story.portrait_for(speaker)
		if plain != null and plain != tex:
			_face_texture = tex
			_face_left = FACE_CHANGE_TIME
			tex = plain
	_face = face
	_portrait.texture = tex
	_portrait_frame.visible = tex != null
	_text.text = line.get("text", "")
	_text.visible_characters = 0
	_typed = 0.0
	_hint.visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if _cue_wait > 0.0:
		_cue_wait -= delta
		if _cue_wait <= 0.0:
			_cue_wait = 0.0
			_display_line()
		return
	if _face_left > 0.0:
		_face_left -= delta
		if _face_left <= 0.0:
			_portrait.texture = _face_texture
	if is_typing():
		_typed += delta * CHARS_PER_SECOND * float(Profile.get_setting("text_speed"))
		_text.visible_characters = mini(int(_typed), _text.text.length())
	else:
		_hint.visible = true
		_hint.text = "▼ [Enter] 다음" if _index < _lines.size() - 1 else "■ [Enter] 닫기"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"dialogue_next"):
		get_viewport().set_input_as_handled()
		advance()
	elif event is InputEventMouseButton or event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack"):
		get_viewport().set_input_as_handled()  # 다른 키 · 클릭은 넘기지 않음 (뒤의 게임으로도 새지 않게)


## 다음으로 (테스트에서도 직접 호출)
func advance() -> void:
	if not visible or is_waiting_cue():
		return
	if is_typing():
		_text.visible_characters = -1
		return
	_index += 1
	Sfx.play_local(&"dialogue_next")
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


## [스킵] — 남은 대사를 모두 건너뛰고 닫음
func skip_all() -> void:
	while visible:
		if is_waiting_cue():
			_cue_wait = 0.0
			_display_line()
		advance()


func _finish() -> void:
	visible = false
	done.emit()


## 지금 초상화 (테스트용)
func current_portrait() -> Texture2D:
	return _portrait.texture
