class_name AdminPanel
extends PanelContainer
## 운영자 패널 (운영자 모드에서 [F11]) — Admin 이 열고 닫음. 열려 있는 동안 게임은 멈춤.
##   스테이지 이동 · 보스문 바로 열기 · 운영자 장비(무적 + 즉사급) · 개발자 강림(대사 · 버프 · 골드 · 아이템 선물)

const ACCENT := Color(1.0, 0.45, 0.4)

var stage_spin: SpinBox
var gear_check: CheckButton
var lines_edit: TextEdit
var heal_check: CheckBox
var attack_check: CheckBox
var guard_check: CheckBox
var invincible_check: CheckBox
var gold_spin: SpinBox
var item_option: OptionButton
var count_spin: SpinBox
var _item_ids: Array[String] = [""]


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.06, 0.95)
	style.set_border_width_all(1)
	style.border_color = ACCENT
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	add_theme_stylebox_override(&"panel", style)
	# 화면 오른쪽에 꽉 차게 (작은 화면에서도 위아래가 잘리지 않게 스크롤)
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -280.0
	offset_right = -4.0
	offset_top = 4.0
	offset_bottom = -4.0
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 2)
	scroll.add_child(box)

	box.add_child(_label("운영자 패널  [F11] 닫기", 11, ACCENT))
	box.add_child(_label("스테이지 이동 · 장비", 9, Color(0.8, 0.8, 0.85)))
	var stage_row := HBoxContainer.new()
	box.add_child(stage_row)
	stage_spin = SpinBox.new()
	var manager := get_tree().get_first_node_in_group(&"stage_manager") as StageManager
	stage_spin.min_value = 1
	stage_spin.max_value = manager.get_final_stage() if manager != null else 100
	stage_spin.value = GameManager.stage
	stage_spin.custom_minimum_size = Vector2(70, 0)
	stage_row.add_child(stage_spin)
	stage_row.add_child(_button("스테이지로 이동", func() -> void:
		Admin.close_panel()
		Admin.teleport_to_stage(int(stage_spin.value))))
	box.add_child(_button("보스방 문 바로 열기", func() -> void:
		Admin.close_panel()
		Admin.open_boss_gate()))
	gear_check = CheckButton.new()
	gear_check.text = "운영자 장비 (운영자의 검 · 활 · 지팡이 + 무적)"
	gear_check.add_theme_font_size_override(&"font_size", 9)
	gear_check.button_pressed = Admin.god
	gear_check.toggled.connect(func(on: bool) -> void: Admin.set_gear(on))
	box.add_child(gear_check)

	box.add_child(HSeparator.new())
	box.add_child(_label("개발자 강림 — 대사 (한 줄에 하나, 최대 %d줄)" % Admin.MAX_LINES, 9, Color(0.8, 0.8, 0.85)))
	lines_edit = TextEdit.new()
	lines_edit.custom_minimum_size = Vector2(0, 40)
	lines_edit.add_theme_font_size_override(&"font_size", 9)
	lines_edit.text = "\n".join(PackedStringArray(Admin.preset.get("lines", [])))
	box.add_child(lines_edit)
	var buffs := GridContainer.new()
	buffs.columns = 2
	box.add_child(buffs)
	heal_check = _check(buffs, "체력 회복 · 부활", "heal")
	attack_check = _check(buffs, "공격 +100%% %d초" % int(Admin.BUFF_ATTACK["time"]), "attack")
	guard_check = _check(buffs, "받는 피해 -50%% %d초" % int(Admin.BUFF_GUARD["time"]), "guard")
	invincible_check = _check(buffs, "무적 %d초" % int(Admin.BUFF_SHIELD["time"]), "invincible")
	var gold_row := HBoxContainer.new()
	box.add_child(gold_row)
	var gold_label := _label("선물 골드", 9, Color(1.0, 0.85, 0.4))
	gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	gold_row.add_child(gold_label)
	gold_spin = SpinBox.new()
	gold_spin.max_value = Admin.MAX_GOLD
	gold_spin.step = 100
	gold_spin.value = int(Admin.preset.get("gold", 0))
	gold_spin.custom_minimum_size = Vector2(110, 0)
	gold_row.add_child(gold_spin)
	var item_row := HBoxContainer.new()
	box.add_child(item_row)
	item_option = OptionButton.new()
	item_option.custom_minimum_size = Vector2(170, 0)
	item_option.add_theme_font_size_override(&"font_size", 9)
	item_option.add_item("선물 아이템 없음")
	var all := ItemDB.get_all().filter(func(it: ItemData) -> bool: return not it.admin_only)
	all.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.display_name < b.display_name if a.rarity == b.rarity else a.rarity > b.rarity)
	for item in all:
		item_option.add_item("[%s] %s" % [item.get_rarity_name(), item.display_name])
		_item_ids.append(String(item.id))
	var preset_index := _item_ids.find(String(Admin.preset.get("item", "")))
	item_option.select(maxi(preset_index, 0))
	item_row.add_child(item_option)
	count_spin = SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 99
	count_spin.value = int(Admin.preset.get("count", 1))
	count_spin.tooltip_text = "포션 개수"
	item_row.add_child(count_spin)
	var target := "모든 참가자에게 (멀티플레이)" if Net.is_host() else "나에게"
	box.add_child(_button("개발자 강림!  — " + target + "  [Ctrl+Shift+D]", func() -> void:
		save_preset()
		Admin.close_panel()
		Admin.descend(Admin.preset)))
	box.add_child(_label("운영자 모드가 켜져 있는 동안 업적은 달성되지 않음 · [Ctrl+Shift+A] 끄기", 8, Color(0.6, 0.6, 0.65)))


## 지금 패널에 적힌 내용을 다음 강림(단축키 포함)에 씀
func save_preset() -> void:
	var lines: Array = []
	for line in lines_edit.text.split("\n", false):
		lines.append(line)
	Admin.preset = {
		"lines": lines,
		"heal": heal_check.button_pressed,
		"attack": attack_check.button_pressed,
		"guard": guard_check.button_pressed,
		"invincible": invincible_check.button_pressed,
		"gold": int(gold_spin.value),
		"item": _item_ids[clampi(item_option.selected, 0, _item_ids.size() - 1)],
		"count": int(count_spin.value),
	}


func _exit_tree() -> void:
	if lines_edit != null:
		save_preset()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 9)
	button.pressed.connect(callback)
	return button


func _check(parent: Control, text: String, key: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.add_theme_font_size_override(&"font_size", 9)
	check.button_pressed = bool(Admin.preset.get(key, false))
	parent.add_child(check)
	return check
