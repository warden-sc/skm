class_name ShopUI
extends CanvasLayer
## 상점 UI. 열려 있는 동안 게임을 일시정지하고(get_tree().paused), 이 노드만 PROCESS_MODE_ALWAYS 로 동작합니다.
##
## - 왼쪽: 판매 목록 (무기/방패/투구를 골드로 구매 → 인벤토리 추가 + 자동 장착)
##   · 스테이지별 입고: 1스테이지 일반·희귀 / 2스테이지 레어 / 3스테이지 전설 (그 전에는 잠김 표시)
##   · 등급별 배경색: 일반 회색 / 희귀 파랑 / 레어 보라 / 전설 노랑
## - 오른쪽: 보유 장비 (장착 버튼으로 무기/방패/투구 교체 → 데미지·방어 변화 확인)
## - 행에 마우스를 올리면 아래 상세 정보에 스탯 표시

const ICON_SIZE := Vector2(20, 20)

@onready var _title: Label = %Title
@onready var _gold_label: Label = %ShopGold
@onready var _buy_list: VBoxContainer = %BuyList
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _detail: Label = %Detail
@onready var _close_button: Button = %CloseButton

var _stock: Array[ItemData] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	GameManager.shop_open_requested.connect(open)
	GameManager.gold_changed.connect(_on_data_changed.unbind(1))
	GameManager.inventory_changed.connect(_on_data_changed)
	GameManager.weapon_equipped.connect(_on_data_changed.unbind(1))
	GameManager.shield_equipped.connect(_on_data_changed.unbind(1))
	GameManager.helmet_equipped.connect(_on_data_changed.unbind(1))
	_close_button.pressed.connect(close)


func open(shop_name: String, stock_ids: Array) -> void:
	_stock.clear()
	for item_id in stock_ids:
		var item := ItemDB.get_item(StringName(item_id))
		if item != null:
			_stock.append(item)
	_title.text = shop_name
	_detail.text = "장비에 마우스를 올리면 상세 정보가 표시됩니다."
	_refresh()
	show()
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_data_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_gold_label.text = "보유 골드: %d G" % GameManager.gold

	for child in _buy_list.get_children():
		child.queue_free()
	for child in _inventory_list.get_children():
		child.queue_free()

	for item in _stock:
		var button := Button.new()
		var locked := GameManager.stage < item.get_unlock_stage()
		if GameManager.owns_item(item.id):
			button.text = "보유중"
			button.disabled = true
		elif locked:
			button.text = "%d스테이지" % item.get_unlock_stage()
			button.disabled = true
		else:
			button.text = "%d G" % item.price
			button.disabled = not GameManager.can_afford(item.price)
			button.pressed.connect(_on_buy_pressed.bind(item))
		_buy_list.add_child(_make_row(item, button, locked))

	var owned: Array[ItemData] = []
	owned.append_array(GameManager.weapons)
	owned.append_array(GameManager.shields)
	owned.append_array(GameManager.helmets)
	for item in owned:
		var button := Button.new()
		if GameManager.is_equipped(item):
			button.text = "장착중"
			button.disabled = true
		else:
			button.text = "장착"
			button.pressed.connect(_on_equip_pressed.bind(item))
		_inventory_list.add_child(_make_row(item, button))


## 등급색 배경 패널 안에 [아이콘 | 이름·요약 | 버튼] 한 줄
func _make_row(item: ItemData, button: Button, locked: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = item.get_rarity_bg_color()
	style.border_color = item.get_rarity_color()
	style.set_border_width_all(1 if item.rarity == ItemData.Rarity.COMMON else 2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(3)
	panel.add_theme_stylebox_override(&"panel", style)
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
	name_label.text = "[%s] %s\n%s" % [item.get_rarity_name(), item.display_name, item.get_summary()]
	name_label.add_theme_color_override(&"font_color", item.get_rarity_color().lightened(0.35))
	name_label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.08, 0.12))
	name_label.add_theme_constant_override(&"outline_size", 3)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	button.custom_minimum_size = Vector2(56, 0)
	button.focus_mode = Control.FOCUS_NONE
	row.add_child(button)

	var show_detail := func() -> void:
		var lock_text := "\n※ %d스테이지부터 구매 가능" % item.get_unlock_stage() if locked else ""
		_detail.text = "%s\n%s\n%s%s" % [item.display_name, item.get_stat_text(), item.description, lock_text]
	panel.mouse_entered.connect(show_detail)
	button.mouse_entered.connect(show_detail)
	return panel


func _on_buy_pressed(item: ItemData) -> void:
	if GameManager.buy_item(item):
		GameManager.show_notice("구매 완료: %s" % item.display_name, item.get_rarity_color())
	else:
		GameManager.show_notice("골드가 부족합니다!", Color(1.0, 0.5, 0.5))


func _on_equip_pressed(item: ItemData) -> void:
	GameManager.equip_item(item)
