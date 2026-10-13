class_name ShopUI
extends CanvasLayer
## 상점 UI. 열려 있는 동안 게임을 일시정지하고(get_tree().paused), 이 노드만 PROCESS_MODE_ALWAYS 로 동작합니다.
##
## - 왼쪽: 판매 목록 (무기/방패를 골드로 구매 → 인벤토리 추가 + 자동 장착)
## - 오른쪽: 보유 장비 (장착 버튼으로 무기/방패 교체 → 데미지·방어 변화 확인)
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
		if GameManager.owns_item(item.id):
			button.text = "보유중"
			button.disabled = true
		else:
			button.text = "%d G" % item.price
			button.disabled = not GameManager.can_afford(item.price)
			button.pressed.connect(_on_buy_pressed.bind(item))
		_buy_list.add_child(_make_row(item, button))

	var owned: Array[ItemData] = []
	owned.append_array(GameManager.weapons)
	owned.append_array(GameManager.shields)
	for item in owned:
		var button := Button.new()
		if GameManager.is_equipped(item):
			button.text = "장착중"
			button.disabled = true
		else:
			button.text = "장착"
			button.pressed.connect(_on_equip_pressed.bind(item))
		_inventory_list.add_child(_make_row(item, button))


func _make_row(item: ItemData, button: Button) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override(&"separation", 6)

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = "%s\n%s" % [item.display_name, item.get_summary()]
	name_label.add_theme_color_override(&"font_color", item.get_rarity_color())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	button.custom_minimum_size = Vector2(56, 0)
	button.focus_mode = Control.FOCUS_NONE
	row.add_child(button)

	var show_detail := func() -> void:
		_detail.text = "%s\n%s\n%s" % [item.display_name, item.get_stat_text(), item.description]
	row.mouse_entered.connect(show_detail)
	button.mouse_entered.connect(show_detail)
	return row


func _on_buy_pressed(item: ItemData) -> void:
	if GameManager.buy_item(item):
		GameManager.show_notice("구매 완료: %s" % item.display_name, item.get_rarity_color())
	else:
		GameManager.show_notice("골드가 부족합니다!", Color(1.0, 0.5, 0.5))


func _on_equip_pressed(item: ItemData) -> void:
	GameManager.equip_item(item)
