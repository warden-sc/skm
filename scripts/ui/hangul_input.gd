class_name HangulInput
extends Node
## 게임 안 한글 입력기 — LineEdit 에 붙이면 윈도우 한글 입력기(IME) 대신 게임이 직접 두벌식으로 조합함.
## 윈도우 IME 와 Godot 입력 칸이 맞지 않아 한 글자만 들어가는 문제를 피하려고, 입력 칸에 들어가면 IME 를 끄고
## 자판 위치(physical key)대로 받은 글자를 Hangul.from_qwerty 로 조합해서 보여 줌.
##   [한/영] 바꾸기: Shift + Space · 오른쪽 Alt · 한/영 키 · 입력 칸 옆 「한/영」 버튼 (모든 입력 칸이 같은 상태를 씀)
##   Backspace 는 조합 중이면 자모 하나씩 지움 (실제 입력기처럼)
##   스페이스 · 숫자 · 기호 · 방향키 · 마우스 클릭 · Enter 에서 조합이 끝남
## 사용: HangulInput.attach(line_edit 또는 text_edit)  (+ HangulInput.make_toggle_button() 을 옆에 두면 지금 상태가 보임)

signal mode_changed(korean: bool)

## 한글 조합을 쓸지 (꺼지면 영문 그대로)
static var korean: bool = true
static var _instances: Array = []
static var _buttons: Array = []

## 붙은 입력 칸 (LineEdit 또는 TextEdit)
var line: Control
var _raw: String = ""      # 지금 조합 중인 글자의 영문 자판 키들
var _shown: int = 0        # 입력 칸에 넣어 둔 조합 글자 수 (다음 키에서 지우고 다시 넣음)


static func attach(target: Control) -> HangulInput:
	var helper := HangulInput.new()
	helper.name = "HangulInput"
	helper.line = target
	target.add_child(helper)
	return helper


static func set_korean(on: bool) -> void:
	korean = on
	for inst in _instances:
		if is_instance_valid(inst):
			(inst as HangulInput).commit()
			(inst as HangulInput).mode_changed.emit(on)
	for b in _buttons:
		if is_instance_valid(b):
			(b as Button).text = "한" if on else "영"


static func toggle() -> void:
	set_korean(not korean)


## 「한/영」 버튼 — 누르면 바꾸고, 글자로 지금 상태를 보여 줌
static func make_toggle_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "한글 / 영문 바꾸기 (Shift+Space · 오른쪽 Alt · 한/영 키)"
	button.text = "한" if korean else "영"
	button.custom_minimum_size = Vector2(22, 0)
	button.pressed.connect(toggle)
	_buttons.append(button)
	return button


func _ready() -> void:
	_instances.append(self)
	line.gui_input.connect(_on_gui_input)
	line.focus_entered.connect(_on_focus_entered)
	line.focus_exited.connect(commit)
	if line is LineEdit:
		(line as LineEdit).text_submitted.connect(func(_t: String) -> void: commit())


func _exit_tree() -> void:
	_instances.erase(self)


func is_composing() -> bool:
	return _raw != ""


## 조합 끝 (글자는 이미 입력 칸에 들어가 있음)
func commit() -> void:
	_raw = ""
	_shown = 0


func _on_focus_entered() -> void:
	commit()
	# LineEdit 가 포커스를 받으며 IME 를 켠 뒤에 끔
	(func() -> void:
		if is_instance_valid(line) and line.has_focus():
			DisplayServer.window_set_ime_active(false)).call_deferred()


## 한/영 키 · 오른쪽 Alt · Shift+Space
static func is_toggle_key(key: InputEventKey) -> bool:
	if key.keycode == KEY_SPACE and key.shift_pressed:
		return true
	if (key.keycode == KEY_ALT or key.physical_keycode == KEY_ALT) and key.location == KEY_LOCATION_RIGHT:
		return true
	# 한/영 키는 Godot 에 이름이 없어 OS 코드(VK_HANGUL 0x15)로만 들어올 수 있음
	return key.keycode == 0x15 or key.physical_keycode == 0x15


## 자판 위치로 영문자 (한글 IME 상태여도 같은 자리면 같은 글자) — 영문자 키가 아니면 ""
static func latin_of(key: InputEventKey) -> String:
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code >= KEY_A and code <= KEY_Z:
		var c := String.chr(code).to_lower()
		return c.to_upper() if key.shift_pressed else c
	return ""


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		commit()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if is_toggle_key(key):
		toggle()
		line.accept_event()
		return
	if not korean or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		if key.keycode != KEY_SHIFT:
			commit()
		return
	if key.keycode == KEY_BACKSPACE and _raw != "":
		_raw = _raw.left(-1)
		_apply()
		if _raw == "":
			commit()
		line.accept_event()
		return
	var c := latin_of(key)
	if c == "":
		if key.keycode != KEY_SHIFT:
			commit()
		return
	if _raw == "":
		_delete_selection()
	_raw += c
	_apply()
	line.accept_event()


func _delete_selection() -> void:
	if line is LineEdit:
		var le := line as LineEdit
		if le.has_selection():
			var from := le.get_selection_from_column()
			le.delete_text(from, le.get_selection_to_column())
			le.caret_column = from
	elif line is TextEdit and (line as TextEdit).has_selection():
		(line as TextEdit).delete_selection()


## 넣어 둔 조합 글자를 지우고 새로 조합한 글자를 넣음
func _apply() -> void:
	var composed := Hangul.from_qwerty(_raw)
	if line is LineEdit:
		var le := line as LineEdit
		var col := le.caret_column
		if _shown > 0:
			le.delete_text(col - _shown, col)
		le.insert_text_at_caret(composed)
		le.text_changed.emit(le.text)
	elif line is TextEdit:
		var te := line as TextEdit
		var row := te.get_caret_line()
		var col := te.get_caret_column()
		if _shown > 0:
			te.remove_text(row, col - _shown, row, col)
			te.set_caret_column(col - _shown)
		te.insert_text_at_caret(composed)
	_shown = composed.length()


## 테스트용: 자판 위치로 글자를 친 것처럼 (" " = 스페이스, "<" = Backspace)
func type_keys(keys: String) -> void:
	for c in keys:
		var ev := InputEventKey.new()
		ev.pressed = true
		if c == " ":
			ev.keycode = KEY_SPACE
			ev.physical_keycode = KEY_SPACE
			_on_gui_input(ev)
			line.call(&"insert_text_at_caret", " ")
		elif c == "<":
			ev.keycode = KEY_BACKSPACE
			ev.physical_keycode = KEY_BACKSPACE
			_on_gui_input(ev)
		else:
			var code := c.to_upper().unicode_at(0)
			ev.keycode = code as Key
			ev.physical_keycode = code as Key
			ev.shift_pressed = c != c.to_lower()
			_on_gui_input(ev)
