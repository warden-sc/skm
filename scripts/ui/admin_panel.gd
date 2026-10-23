class_name AdminPanel
extends PanelContainer
## 운영자 패널 (운영자 모드에서 [F11]) — Admin 이 열고 닫음. 열려 있는 동안 게임은 멈춤.
##   스테이지 이동 · 보스문 바로 열기 · 운영자 장비 한 벌(날개 · 무적 · 즉사급) · 채팅 공지
##   개발자 강림: 대사 · 운영자의 가호(능력치를 직접 정함) · 보호막 · 골드 · 아이템(상점 · 드랍 · 신화 · 운영자 장비 전부 중 하나)

const ACCENT := Color(1.0, 0.45, 0.4)
const SUB := Color(0.8, 0.8, 0.85)

var stage_spin: SpinBox
var gear_check: CheckButton
var notice_edit: LineEdit
var lines_edit: TextEdit
var heal_check: CheckBox
var invincible_check: CheckBox
var shield_spin: SpinBox
## 가호 능력치 (Admin.BLESSING_STATS 의 키 + "time")
var blessing_spins: Dictionary = {}
var gold_spin: SpinBox
var item_filter: LineEdit
var item_option: OptionButton
var count_spin: SpinBox
var _item_ids: Array[String] = [""]
var _all_items: Array[ItemData] = []


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
	offset_left = -290.0
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
	box.add_child(_label("개발자 본인 전용 · 이 PC 코드 %s%s" % [Admin.machine_code(), "" if not Admin.DEV_MACHINE_CODES.is_empty() else " (admin.gd 의 DEV_MACHINE_CODES 에 넣으면 이 PC 에서만)"], 8, Color(0.6, 0.6, 0.65)))
	box.add_child(_label("스테이지 · 장비 · 공지", 9, SUB))
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
	stage_row.add_child(_button("보스문 열기", func() -> void:
		Admin.close_panel()
		Admin.open_boss_gate()))
	gear_check = CheckButton.new()
	gear_check.text = "운영자 장비 한 벌 (날개 · 무적 · 즉사급 · 전용 스킬)"
	gear_check.add_theme_font_size_override(&"font_size", 9)
	gear_check.button_pressed = Admin.god
	gear_check.toggled.connect(func(on: bool) -> void: Admin.set_gear(on))
	box.add_child(gear_check)
	var notice_row := HBoxContainer.new()
	box.add_child(notice_row)
	notice_edit = LineEdit.new()
	notice_edit.placeholder_text = "채팅으로 공지 (모든 참가자)"
	notice_edit.add_theme_font_size_override(&"font_size", 9)
	notice_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice_edit.text_submitted.connect(func(_t: String) -> void: send_notice())
	notice_row.add_child(notice_edit)
	HangulInput.attach(notice_edit)
	notice_row.add_child(_button("보내기", send_notice))
	var hangul_toggle := HangulInput.make_toggle_button()
	hangul_toggle.add_theme_font_size_override(&"font_size", 9)
	notice_row.add_child(hangul_toggle)

	box.add_child(HSeparator.new())
	box.add_child(_label("개발자 강림 — 대사 (한 줄에 하나, 최대 %d줄 · 채팅창에도 남음)" % Admin.MAX_LINES, 9, SUB))
	lines_edit = TextEdit.new()
	lines_edit.custom_minimum_size = Vector2(0, 40)
	lines_edit.add_theme_font_size_override(&"font_size", 9)
	lines_edit.text = "\n".join(PackedStringArray(Admin.preset.get("lines", [])))
	box.add_child(lines_edit)
	HangulInput.attach(lines_edit)
	var flags := HBoxContainer.new()
	box.add_child(flags)
	heal_check = _check(flags, "체력 회복 · 부활", bool(Admin.preset.get("heal", false)))
	invincible_check = _check(flags, "무적 보호막", bool(Admin.preset.get("invincible", false)))
	shield_spin = _spin(flags, 1, Admin.BLESSING_MAX_TIME, float(Admin.preset.get("shield_time", 15.0)), 1, "초")

	box.add_child(_label("%s — 능력치를 직접 정함 (0 이면 없음)" % Admin.BLESSING_NAME, 9, Color(1.0, 0.85, 0.4)))
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var blessing: Dictionary = Admin.preset.get("blessing", {})
	for key in Admin.BLESSING_STATS:
		var row := HBoxContainer.new()
		grid.add_child(row)
		var name_label := _label(String(Admin.BLESSING_STATS[key][0]).trim_suffix("%").trim_suffix(" +").trim_suffix(" -"), 8, SUB)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.custom_minimum_size = Vector2(62, 0)
		row.add_child(name_label)
		blessing_spins[key] = _spin(row, 0, float(Admin.BLESSING_STATS[key][1]), float(blessing.get(key, 0.0)), 1, "%")
	var time_row := HBoxContainer.new()
	box.add_child(time_row)
	time_row.add_child(_label("가호 시간", 8, SUB, false))
	blessing_spins["time"] = _spin(time_row, 1, Admin.BLESSING_MAX_TIME, float(blessing.get("time", 60.0)), 10, "초")
	time_row.add_child(_label("선물 골드", 8, Color(1.0, 0.85, 0.4), false))
	gold_spin = _spin(time_row, 0, Admin.MAX_GOLD, float(Admin.preset.get("gold", 0)), 100, "")

	box.add_child(_label("선물 아이템 — 상점 · 드랍 · 신화 · 운영자 장비 전부 (이름으로 찾기)", 9, SUB))
	item_filter = LineEdit.new()
	item_filter.placeholder_text = "찾기: 예) 운영자, 검, 포션"
	item_filter.add_theme_font_size_override(&"font_size", 9)
	item_filter.text_changed.connect(func(_t: String) -> void: _fill_items())
	box.add_child(item_filter)
	var item_row := HBoxContainer.new()
	box.add_child(item_row)
	item_option = OptionButton.new()
	item_option.custom_minimum_size = Vector2(190, 0)
	item_option.add_theme_font_size_override(&"font_size", 9)
	item_row.add_child(item_option)
	count_spin = _spin(item_row, 1, 99, float(Admin.preset.get("count", 1)), 1, "개")
	count_spin.tooltip_text = "포션 개수"
	_all_items = get_gift_items()
	_fill_items()
	var target := "모든 참가자에게 (멀티플레이)" if Net.is_host() else "나에게"
	box.add_child(_button("개발자 강림!  — " + target + "  [Ctrl+Shift+D]", func() -> void:
		save_preset()
		Admin.close_panel()
		Admin.descend(Admin.preset)))
	box.add_child(_label("운영자 모드가 켜져 있는 동안 업적은 달성되지 않음 · [Ctrl+Shift+A] 끄기", 8, Color(0.6, 0.6, 0.65)))


## 선물할 수 있는 모든 아이템: 운영자 장비 → 신화 → 전설 … (같은 등급은 이름 순)
static func get_gift_items() -> Array[ItemData]:
	var list: Array[ItemData] = []
	list.append_array(AdminGear.get_all())
	var normal := ItemDB.get_all()
	normal.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.display_name < b.display_name if a.rarity == b.rarity else a.rarity > b.rarity)
	list.append_array(normal)
	return list


static func item_label(item: ItemData) -> String:
	var where := "운영자" if item.admin_only else ("상점" if item.in_shop else ("보스" if item.is_mythic() else "드랍"))
	return "[%s · %s] %s" % [item.get_rarity_name(), where, item.display_name]


func _fill_items() -> void:
	var keep := get_selected_item_id()
	if keep == "":
		keep = String(Admin.preset.get("item", ""))
	var filter := item_filter.text.strip_edges()
	item_option.clear()
	_item_ids = [""]
	item_option.add_item("선물 아이템 없음")
	for item in _all_items:
		var label := item_label(item)
		if filter != "" and not label.contains(filter):
			continue
		item_option.add_item(label)
		_item_ids.append(String(item.id))
	item_option.select(maxi(_item_ids.find(keep), 0))


func get_selected_item_id() -> String:
	if item_option == null or item_option.selected < 0 or item_option.selected >= _item_ids.size():
		return ""
	return _item_ids[item_option.selected]


func select_item(item_id: String) -> bool:
	var index := _item_ids.find(item_id)
	if index < 0:
		return false
	item_option.select(index)
	return true


func send_notice() -> void:
	if Chat.send_admin(notice_edit.text):
		notice_edit.text = ""


## 지금 패널에 적힌 내용을 다음 강림(단축키 포함)에 씀
func save_preset() -> void:
	var lines: Array = []
	for line in lines_edit.text.split("\n", false):
		lines.append(line)
	var blessing := {}
	for key in blessing_spins:
		blessing[key] = (blessing_spins[key] as SpinBox).value
	Admin.preset = {
		"lines": lines,
		"heal": heal_check.button_pressed,
		"invincible": invincible_check.button_pressed,
		"shield_time": shield_spin.value,
		"blessing": blessing,
		"gold": int(gold_spin.value),
		"item": get_selected_item_id(),
		"count": int(count_spin.value),
		"chat": true,
	}


func _exit_tree() -> void:
	if lines_edit != null:
		save_preset()


func _label(text: String, size: int, color: Color, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 9)
	button.pressed.connect(callback)
	return button


func _check(parent: Control, text: String, on: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.add_theme_font_size_override(&"font_size", 9)
	check.button_pressed = on
	parent.add_child(check)
	return check


func _spin(parent: Control, lo: float, hi: float, value: float, step: float, suffix: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.value = value
	spin.suffix = suffix
	spin.custom_minimum_size = Vector2(64, 0)
	spin.get_line_edit().add_theme_font_size_override(&"font_size", 9)
	parent.add_child(spin)
	return spin
