class_name ItemRow
## 상점 / 인벤토리에서 쓰는 장비 한 줄 UI.
## [등급색 배경 패널 | 아이콘 | [등급] 이름 + 요약 | 버튼들]

const ICON_SIZE := Vector2(20, 20)


static func build(item: ItemData, buttons: Array[Button], on_hover: Callable, locked: bool = false, subtitle: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override(&"panel", rarity_style(item))
	if locked:
		panel.modulate = Color(0.55, 0.55, 0.6)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override(&"separation", 6)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var name_label := Label.new()
	var second_line := subtitle if subtitle != "" else item.get_summary()
	name_label.text = "[%s] %s\n%s" % [item.get_rarity_name(), item.display_name, second_line]
	name_label.add_theme_color_override(&"font_color", item.get_rarity_color().lightened(0.35))
	name_label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.08, 0.12))
	name_label.add_theme_constant_override(&"outline_size", 3)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	for button in buttons:
		row.add_child(button)
		if on_hover.is_valid():
			button.mouse_entered.connect(on_hover)
	if on_hover.is_valid():
		panel.mouse_entered.connect(on_hover)
	return panel


static func make_button(text: String, disabled: bool, on_pressed: Callable = Callable(), min_width: float = 52.0) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(min_width, 0)
	if on_pressed.is_valid() and not disabled:
		button.pressed.connect(on_pressed)
	return button


## 등급색 배경 (일반 회색 / 희귀 파랑 / 레어 보라 / 전설 노랑)
static func rarity_style(item: ItemData, highlight: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = item.get_rarity_bg_color() if item != null else Color(0.12, 0.13, 0.18, 0.9)
	style.border_color = Color(1.0, 0.95, 0.6) if highlight else (item.get_rarity_color() if item != null else Color(0.35, 0.36, 0.45))
	var common := item == null or item.rarity == ItemData.Rarity.COMMON
	style.set_border_width_all(3 if highlight else (1 if common else 2))
	style.set_corner_radius_all(3)
	style.set_content_margin_all(3)
	return style
