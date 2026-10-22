class_name PauseMenu
extends CanvasLayer
## 게임 도중 ESC → 일시정지 · 설정 창
##   계속하기 · 저장하기(살아 있을 때만) · 설정(화면 흔들림 · 전체 화면 · 대사 속도) · 타이틀로 · 게임 종료
## 상점 · 인벤토리 · 대화창이 열려 있을 때(게임이 이미 멈춰 있을 때)는 ESC 가 그 창을 닫는 데 쓰이므로 열리지 않음.
## 튜토리얼 중에는 「저장하기」 대신 「튜토리얼 건너뛰기」.

signal tutorial_skip_requested

const TITLE_SCENE := "res://scenes/title/title.tscn"
const TEXT_SPEEDS := [0.5, 1.0, 1.5, 2.5]
const TEXT_SPEED_NAMES := ["느리게", "보통", "빠르게", "아주 빠르게"]

var _panel: PanelContainer
var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _save_button: Button
var _status: Label
var _shake_check: CheckButton
var _fullscreen_check: CheckButton
var _story_check: CheckButton
var _voice_button: Button
var _sfx_button: Button
var _speed_button: Button
var _confirm_title: bool = false
var _title_button: Button


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if visible:
		if _settings_box.visible:
			_show_main()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and not Net.ui_blocks_input():
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_confirm_title = false
	_title_button.text = "타이틀로"
	_status.text = ""
	_refresh_save_button()
	_show_main()
	show()
	Net.pause_tree(get_tree(), true)
	(_main_box.get_child(1) as Button).grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	Net.pause_tree(get_tree(), false)


func is_open() -> bool:
	return visible


func is_settings_open() -> bool:
	return visible and _settings_box.visible


## 「저장하기」 — 성공하면 true
func save_now() -> bool:
	if GameManager.tutorial_mode:
		return false
	var ok := Profile.save_game()
	_status.text = ("저장했습니다 — 타이틀의 「싱글플레이 → 이어하기」로 %d스테이지 야영지부터 계속할 수 있습니다" % GameManager.stage) if ok else "지금은 저장할 수 없습니다 (쓰러진 상태)"
	_status.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.7) if ok else Color(1.0, 0.5, 0.45))
	return ok


func show_settings() -> void:
	_main_box.hide()
	_settings_box.show()
	_sync_settings()
	_shake_check.grab_focus()


func go_to_title() -> void:
	hide()
	get_tree().paused = false
	Net.leave()  # 멀티플레이면 방에서 나감
	GameManager.tutorial_mode = false
	GameManager.reset_game()
	get_tree().change_scene_to_file(TITLE_SCENE)


# ============================================================ 화면 구성
func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.96)
	style.set_border_width_all(2)
	style.border_color = Color(1, 0.8, 0.46)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(250, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var root := VBoxContainer.new()
	_panel.add_child(root)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override(&"separation", 4)
	root.add_child(_main_box)
	_main_box.add_child(_header("일시정지"))
	_add_button(_main_box, "계속하기", close)
	_save_button = _add_button(_main_box, "저장하기", save_now)
	_add_button(_main_box, "설정", show_settings)
	_title_button = _add_button(_main_box, "타이틀로", _on_title_pressed)
	if not OS.has_feature("web"):
		_add_button(_main_box, "게임 종료", func() -> void: get_tree().quit())
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 8)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(230, 0)
	_main_box.add_child(_status)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override(&"separation", 4)
	root.add_child(_settings_box)
	_settings_box.add_child(_header("설정"))
	_shake_check = CheckButton.new()
	_shake_check.text = "화면 흔들림"
	_shake_check.toggled.connect(func(on: bool) -> void: Profile.set_setting("screen_shake", on))
	_settings_box.add_child(_shake_check)
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "전체 화면"
	_fullscreen_check.toggled.connect(func(on: bool) -> void: Profile.set_setting("fullscreen", on))
	_settings_box.add_child(_fullscreen_check)
	_story_check = CheckButton.new()
	_story_check.text = "스토리 대사"
	_story_check.tooltip_text = "끄면 스테이지 · 보스 · 상인 대사가 나오지 않음"
	_story_check.toggled.connect(func(on: bool) -> void: Profile.set_setting("story", on))
	_settings_box.add_child(_story_check)
	_speed_button = _add_button(_settings_box, "", cycle_text_speed)
	_sfx_button = _add_button(_settings_box, "", cycle_sfx_volume)
	_sfx_button.visible = Sfx.has_sounds()  # 지금은 효과음 파일이 없어서 숨김
	_voice_button = _add_button(_settings_box, "", cycle_voice_mode)
	_voice_button.tooltip_text = "멀티플레이 음성 채팅 — 눌러서 말하기는 [T] 를 누르는 동안만 마이크가 켜짐"
	_add_button(_settings_box, "← 돌아가기", _show_main)
	_settings_box.hide()


## 대사 글자 속도: 느리게 → 보통 → 빠르게 → 아주 빠르게 → …
func cycle_text_speed() -> void:
	var current := float(Profile.get_setting("text_speed"))
	var index := 0
	for i in TEXT_SPEEDS.size():
		if is_equal_approx(TEXT_SPEEDS[i], current):
			index = i
	Profile.set_setting("text_speed", TEXT_SPEEDS[(index + 1) % TEXT_SPEEDS.size()])
	_sync_settings()


## 효과음 크기: 0% → 25% → 50% → 80% → 100% → …
const SFX_STEPS := [0.0, 0.25, 0.5, 0.8, 1.0]


func cycle_sfx_volume() -> void:
	var current := float(Profile.get_setting("sfx_volume"))
	var index := 0
	for i in SFX_STEPS.size():
		if is_equal_approx(SFX_STEPS[i], current):
			index = i
	Profile.set_setting("sfx_volume", SFX_STEPS[(index + 1) % SFX_STEPS.size()])
	Sfx.play(&"trial_clear", 0.6)
	_sync_settings()


## 음성 채팅: 끄기 → 눌러서 말하기 [T] → 항상 켜기 → …
func cycle_voice_mode() -> void:
	Profile.set_setting("voice", (VoiceChat.get_mode() + 1) % VoiceChat.MODE_NAMES.size())
	_sync_settings()


func _sync_settings() -> void:
	_shake_check.set_pressed_no_signal(bool(Profile.get_setting("screen_shake")))
	_fullscreen_check.set_pressed_no_signal(bool(Profile.get_setting("fullscreen")))
	_story_check.set_pressed_no_signal(bool(Profile.get_setting("story")))
	var speed := float(Profile.get_setting("text_speed"))
	var speed_name := "보통"
	for i in TEXT_SPEEDS.size():
		if is_equal_approx(TEXT_SPEEDS[i], speed):
			speed_name = TEXT_SPEED_NAMES[i]
	_speed_button.text = "대사 속도: %s" % speed_name
	_sfx_button.text = "효과음: %d%%" % roundi(float(Profile.get_setting("sfx_volume")) * 100.0)
	_voice_button.text = "음성 채팅: %s" % VoiceChat.MODE_NAMES[VoiceChat.get_mode()]
	_voice_button.visible = VoiceChat.is_supported()


func _show_main() -> void:
	_settings_box.hide()
	_main_box.show()


func _refresh_save_button() -> void:
	for connection in _save_button.pressed.get_connections():
		_save_button.pressed.disconnect(connection["callable"])
	if GameManager.tutorial_mode:
		_save_button.text = "튜토리얼 건너뛰기"
		_save_button.disabled = false
		_save_button.pressed.connect(func() -> void:
			close()
			tutorial_skip_requested.emit())
	else:
		_save_button.text = "저장하기" if not Net.is_online() else "저장하기 (멀티플레이는 저장 불가)"
		_save_button.disabled = not GameManager.can_save()
		_save_button.pressed.connect(save_now)


## 타이틀로: 한 번 더 눌러야 (저장 안 한 진행은 사라짐)
func _on_title_pressed() -> void:
	if _confirm_title or GameManager.tutorial_mode:
		go_to_title()
		return
	_confirm_title = true
	_title_button.text = "정말 타이틀로? (저장 안 한 진행은 사라짐)"


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 13)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.45))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 10)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
