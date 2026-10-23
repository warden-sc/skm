extends CanvasLayer
## 게임 안 채팅 (오토로드 Chat) — 싱글 · 멀티플레이 모두. 화면 왼쪽 아래.
##   [Enter] 채팅 입력 열기 → 글을 쓰고 [Enter] 보내기 · [Esc] 취소 (입력 중에는 용사가 움직이지 않음)
##   새 글은 잠깐 보였다가 흐려지고, 입력창을 열면 최근 글이 모두 보임.
##   멀티플레이: 참가자 → 방장에게 보내면 방장이 이름을 붙여(보낸 사람 확인) 모두에게 다시 보냄 — 이름을 속일 수 없음.
##   운영자 모드인 방장의 글 · 개발자 강림 대사는 금빛 [운영자] 글로 보임.

enum Kind { PLAYER, ADMIN, SYSTEM }

const MAX_CHARS := 100
const MAX_HISTORY := 50
const SHOWN := 7
const SHOW_TIME := 10.0
## 같은 사람이 너무 빨리 연달아 보내지 못하게 (초)
const MIN_INTERVAL := 0.35
const COLORS := {Kind.PLAYER: Color(0.92, 0.94, 1.0), Kind.ADMIN: Color(1.0, 0.85, 0.35), Kind.SYSTEM: Color(0.6, 0.9, 1.0)}

signal message_added(entry: Dictionary)

## [{"name", "text", "kind", "time"}]
var history: Array[Dictionary] = []
var _box: VBoxContainer
var _line: LineEdit
var _line_row: HBoxContainer
var _panel: PanelContainer
var _last_sent: Dictionary = {}


func _ready() -> void:
	layer = 95  # HUD 위 · 대화창(100) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.0)
	style.set_content_margin_all(3)
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 4.0
	_panel.offset_right = 250.0
	_panel.offset_top = -170.0
	_panel.offset_bottom = -64.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override(&"separation", 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_box)
	_line_row = HBoxContainer.new()
	_line_row.visible = false
	column.add_child(_line_row)
	var toggle := HangulInput.make_toggle_button()
	toggle.add_theme_font_size_override(&"font_size", 9)
	_line_row.add_child(toggle)
	_line = LineEdit.new()
	_line.placeholder_text = "채팅 — [Enter] 보내기 · [Esc] 취소 · 한/영: Shift+Space"
	_line.add_theme_font_size_override(&"font_size", 9)
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.max_length = 0  # 한글 입력과 부딪히지 않게 제한은 보낼 때 자름
	_line.text_submitted.connect(func(_t: String) -> void: submit())
	_line_row.add_child(_line)
	# 한글은 게임이 직접 조합 (윈도우 한글 입력기가 한 글자만 들어가는 문제를 피함)
	HangulInput.attach(_line)
	visible = false


## 게임(메인 씬) 안에서만 보임
func _in_game() -> bool:
	return get_tree().get_first_node_in_group(&"stage_manager") != null


func _process(_delta: float) -> void:
	var show := _in_game()
	if visible != show:
		visible = show
		if not show:
			close()
	if not show:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var typing := is_typing()
	(_panel.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0.45 if typing else 0.0)
	for label in _box.get_children():
		var age: float = now - float(label.get_meta(&"time", now))
		(label as Label).modulate.a = 1.0 if typing else clampf((SHOW_TIME - age) / 1.5, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or is_typing() or Story.is_playing() or get_tree().paused or Net.ui_blocks_input():
		return
	if event.is_action_pressed(&"dialogue_next") or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ENTER and not event.is_echo()):
		get_viewport().set_input_as_handled()
		open()


func _input(event: InputEvent) -> void:
	if is_typing() and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_line_row.visible = true
	_line.text = ""
	_line.grab_focus()


func close() -> void:
	if _line == null:
		return
	_line.release_focus()
	_line_row.visible = false


## 채팅 입력 중 — 용사 조작을 막음 (Net.ui_blocks_input)
func is_typing() -> bool:
	return _line_row != null and _line_row.visible


## 입력창의 글 보내기
func submit() -> void:
	var text := _line.text
	close()
	send(text)


static func clean(text: String) -> String:
	var out := ""
	for c in text.strip_edges():
		if c.unicode_at(0) >= 32:
			out += c
	return out.left(MAX_CHARS)


## 내 글 보내기 (운영자 모드인 방장 · 혼자 할 때 운영자면 [운영자] 글)
func send(text: String) -> bool:
	text = clean(text)
	if text.begins_with("/한 "):
		text = Hangul.from_qwerty(text.substr(3))  # 한글 입력기가 말썽일 때: 「/한 dkssud」 → 「안녕」
	if text == "":
		return false
	var kind := Kind.ADMIN if Admin.can_act() else Kind.PLAYER
	var my_name := GameManager.hero_name
	if Net.is_client():
		Net.chat_request(text)
	elif Net.is_host():
		Net.chat_broadcast(my_name, text, kind)
		add_message(my_name, text, kind)
	else:
		add_message(my_name, text, kind)
	return true


## 운영자 공지 (패널) — 이름은 「개발자」
func send_admin(text: String) -> bool:
	text = clean(text)
	if text == "" or not Admin.can_act():
		return false
	if Net.is_host():
		Net.chat_broadcast(Admin.DEV_NAME, text, Kind.ADMIN)
	add_message(Admin.DEV_NAME, text, Kind.ADMIN)
	return true


## 방장: 참가자가 보낸 글 (이름은 방장이 붙임). 너무 빨리 보내면 무시
func receive_from_peer(peer_id: int, text: String) -> void:
	text = clean(text)
	var now := Time.get_ticks_msec() / 1000.0
	if text == "" or now - float(_last_sent.get(peer_id, -10.0)) < MIN_INTERVAL:
		return
	_last_sent[peer_id] = now
	var sender := Net.get_player_name(peer_id)
	Net.chat_broadcast(sender, text, Kind.PLAYER)
	add_message(sender, text, Kind.PLAYER)


func system(text: String) -> void:
	add_message("", clean(text), Kind.SYSTEM)


func add_message(sender: String, text: String, kind: int) -> void:
	if text == "":
		return
	var entry := {"name": sender, "text": text, "kind": kind, "time": Time.get_ticks_msec() / 1000.0}
	history.append(entry)
	if history.size() > MAX_HISTORY:
		history.pop_front()
	var label := Label.new()
	var prefix := ""
	match kind:
		Kind.ADMIN:
			prefix = "[운영자] %s: " % sender
		Kind.SYSTEM:
			prefix = "· "
		_:
			prefix = "%s: " % sender
	label.text = prefix + text
	label.add_theme_font_size_override(&"font_size", 9)
	label.add_theme_color_override(&"font_color", COLORS.get(kind, Color.WHITE))
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(240, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta(&"time", entry["time"])
	_box.add_child(label)
	while _box.get_child_count() > SHOWN:
		var old := _box.get_child(0)
		_box.remove_child(old)
		old.queue_free()
	message_added.emit(entry)


func get_last() -> Dictionary:
	return history.back() if not history.is_empty() else {}


func clear() -> void:
	history.clear()
	for child in _box.get_children():
		child.queue_free()
