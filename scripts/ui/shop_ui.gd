class_name ShopUI
extends CanvasLayer
## 상점 UI. 열려 있는 동안 게임을 일시정지하고(get_tree().paused), 이 노드만 PROCESS_MODE_ALWAYS 로 동작합니다.
##
## - 왼쪽 「구매」: 회복 포션(여러 개 구매, 종류별 최대 5개) / 골드로 장비 구매 → 가방 추가 + 자동 장착
##   · 스테이지별 입고: 1스테이지 일반·희귀 / 2스테이지 레어 / 3스테이지 전설 (그 전에는 잠김 표시)
##   · 등급별 배경색: 일반 회색 / 희귀 파랑 / 레어 보라 / 전설 노랑
## - 오른쪽 「보유 장비 · 판매」: 장착 / 판매 (장착 중인 장비는 팔 수 없음 — 인벤토리에서 해제 후 판매)
## - 행에 마우스를 올리면 아래 상세 정보에 스탯 표시

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
	GameManager.equipment_changed.connect(_on_data_changed)
	GameManager.potions_changed.connect(_on_data_changed)
	_close_button.pressed.connect(close)


func open(shop_name: String, stock_ids: Array) -> void:
	_stock.clear()
	for item_id in stock_ids:
		var item := ItemDB.get_item(StringName(item_id))
		if item != null:
			_stock.append(item)
	_title.text = shop_name
	_detail.text = "장비에 마우스를 올리면 상세 정보가 표시됩니다.  장착 중인 장비는 인벤토리[I]에서 해제한 뒤 팔 수 있습니다."
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
		var locked := GameManager.stage < item.get_unlock_stage()
		if item is PotionData:
			_buy_list.add_child(_make_potion_row(item as PotionData, locked))
			continue
		var button: Button
		if GameManager.owns_item(item.id):
			button = ItemRow.make_button("보유중", true)
		elif locked:
			button = ItemRow.make_button("%d스테이지" % item.get_unlock_stage(), true)
		else:
			button = ItemRow.make_button("%d G" % item.price, not GameManager.can_afford(item.price), _on_buy_pressed.bind(item))
		_buy_list.add_child(ItemRow.build(item, [button], _show_detail.bind(item, locked), locked))

	for item in GameManager.items:
		var equipped := GameManager.is_equipped(item)
		var equip_button := ItemRow.make_button("장착중" if equipped else "장착", equipped, _on_equip_pressed.bind(item), 40.0)
		var sell_button := ItemRow.make_button("판매불가" if equipped else "판매 %dG" % item.get_sell_value(), equipped, _on_sell_pressed.bind(item), 58.0)
		_inventory_list.add_child(ItemRow.build(item, [equip_button, sell_button], _show_detail.bind(item, false)))


## 포션 줄: 여러 번 살 수 있고 보유 개수를 표시
func _make_potion_row(potion: PotionData, locked: bool) -> Control:
	var count := GameManager.get_potion_count(potion.id)
	var button: Button
	if locked:
		button = ItemRow.make_button("%d스테이지" % potion.get_unlock_stage(), true)
	elif count >= GameManager.POTION_MAX_STACK:
		button = ItemRow.make_button("가득 참", true)
	else:
		button = ItemRow.make_button("%d G" % potion.price, not GameManager.can_afford(potion.price), _on_buy_pressed.bind(potion))
	var subtitle := "체력 +%d · 보유 %d / %d" % [potion.get_heal(GameManager.max_hp), count, GameManager.POTION_MAX_STACK]
	return ItemRow.build(potion, [button], _show_detail.bind(potion, locked), locked, subtitle)


func _show_detail(item: ItemData, locked: bool) -> void:
	var lock_text := "※ %d스테이지부터 구매 가능" % item.get_unlock_stage() if locked else ""
	_detail.text = ItemRow.detail_text(item, "  (판매가 %dG)" % item.get_sell_value(), lock_text)
	(_detail.get_parent() as ScrollContainer).scroll_vertical = 0


func _on_buy_pressed(item: ItemData) -> void:
	if GameManager.buy_item(item):
		GameManager.show_notice("구매 완료: %s" % item.display_name, item.get_rarity_color())
	else:
		GameManager.show_notice("골드가 부족합니다!", Color(1.0, 0.5, 0.5))


func _on_equip_pressed(item: ItemData) -> void:
	GameManager.equip_item(item)


func _on_sell_pressed(item: ItemData) -> void:
	var gained := GameManager.sell_item(item)
	if gained > 0:
		GameManager.show_notice("판매: %s  +%dG" % [item.display_name, gained], Color(1.0, 0.85, 0.3))
