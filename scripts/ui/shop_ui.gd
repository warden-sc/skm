class_name ShopUI
extends CanvasLayer
## 상점 UI. 열려 있는 동안 게임을 일시정지하고(get_tree().paused), 이 노드만 PROCESS_MODE_ALWAYS 로 동작합니다.
##
## - 위쪽 탭: 포션 · 검 · 활 · 지팡이 · 방패 · 투구 · 갑옷 · 신발 · 팔찌 · 반지 · 펜던트 — 고른 종류만 보여 줌 (구매 · 보유 목록 모두)
## - 왼쪽 「구매」: 회복 포션(여러 개 구매, 종류별 최대 5개) / 골드로 장비 구매 → 가방 추가 + 자동 장착
##   · 스테이지별 입고: 1~10 일반 / 11~40 희귀 / 41~70 레어 / 71~100 전설 (그 전에는 잠김 표시)
##   · 같은 등급 안에서도 하급 · 중급 · 상급 (상급일수록 강하고 비쌈)
##   · 등급별 배경색: 일반 회색 / 희귀 파랑 / 레어 보라 / 전설 노랑 / 신화 진홍
## - 오른쪽 「보유 장비 · 판매」: 장착 / 판매 (장착 중인 장비는 팔 수 없음 — 인벤토리에서 해제 후 판매)
## - 행에 마우스를 올리면 아래 상세 정보에 스탯 표시

@onready var _title: Label = %Title
@onready var _gold_label: Label = %ShopGold
@onready var _buy_list: VBoxContainer = %BuyList
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _detail: Label = %Detail
@onready var _close_button: Button = %CloseButton
@onready var _tabs: HFlowContainer = %CategoryTabs

enum Category { POTION, SWORD, BOW, STAFF, SHIELD, HELMET, ARMOR, BOOTS, BRACELET, RING, PENDANT }
const CATEGORY_NAMES := ["포션", "검", "활", "지팡이", "방패", "투구", "갑옷", "신발", "팔찌", "반지", "펜던트"]

var _stock: Array[ItemData] = []
var category: Category = Category.SWORD
var _tab_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	GameManager.shop_open_requested.connect(open)
	GameManager.gold_changed.connect(_on_data_changed.unbind(1))
	GameManager.inventory_changed.connect(_on_data_changed)
	GameManager.equipment_changed.connect(_on_data_changed)
	GameManager.potions_changed.connect(_on_data_changed)
	_close_button.pressed.connect(close)
	for i in CATEGORY_NAMES.size():
		var button := Button.new()
		button.text = CATEGORY_NAMES[i]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override(&"font_size", 9)
		button.custom_minimum_size = Vector2(34, 0)
		button.pressed.connect(set_category.bind(i))
		_tabs.add_child(button)
		_tab_buttons.append(button)


## 장비 종류 → 상점 탭
static func category_of(item: ItemData) -> Category:
	if item is PotionData:
		return Category.POTION
	if item is WeaponData:
		match (item as WeaponData).weapon_type:
			WeaponData.WeaponType.BOW:
				return Category.BOW
			WeaponData.WeaponType.STAFF:
				return Category.STAFF
		return Category.SWORD
	if item is ShieldData:
		return Category.SHIELD
	if item is HelmetData:
		return Category.HELMET
	if item is ArmorData:
		return Category.ARMOR
	if item is BootsData:
		return Category.BOOTS
	if item is AccessoryData:
		return [Category.BRACELET, Category.RING, Category.PENDANT][(item as AccessoryData).slot_type]
	return Category.POTION


func set_category(value: int) -> void:
	category = value as Category
	_refresh()


## 지금 탭에 보이는 판매 장비 (테스트용)
func get_visible_stock() -> Array[ItemData]:
	return _stock.filter(func(it: ItemData) -> bool: return category_of(it) == category)


func open(shop_name: String, stock_ids: Array) -> void:
	_stock.clear()
	if stock_ids.is_empty():
		stock_ids = ItemDB.get_shop_items().map(func(it: ItemData) -> StringName: return it.id)
	for item_id in stock_ids:
		var item := ItemDB.get_item(StringName(item_id))
		if item != null:
			_stock.append(item)
	_title.text = shop_name
	_detail.text = "장비에 마우스를 올리면 상세 정보가 표시됩니다.  장착 중인 장비는 인벤토리[I]에서 해제한 뒤 팔 수 있습니다."
	_refresh()
	show()
	Net.pause_tree(get_tree(), true)


func close() -> void:
	if not visible:
		return
	hide()
	Net.pause_tree(get_tree(), false)


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
	for list in [_buy_list, _inventory_list]:
		for child in (list as Node).get_children():
			(list as Node).remove_child(child)  # 바로 빼서 목록 개수가 정확하게
			child.queue_free()

	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == category)
	for item in get_visible_stock():
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
		if category_of(item) != category:
			continue
		var equipped := GameManager.is_equipped(item)
		var sealed := item.is_sealed()
		var equip_button := ItemRow.make_button("봉인" if sealed else ("장착중" if equipped else "장착"), equipped or sealed, _on_equip_pressed.bind(item), 40.0)
		var sellable := GameManager.can_sell(item)
		var sell_button := ItemRow.make_button("판매 %dG" % item.get_sell_value() if sellable else "판매불가", not sellable, _on_sell_pressed.bind(item), 58.0)
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
	_detail.text = ItemRow.detail_text(item, "" if item.is_mythic() else "  (판매가 %dG)" % item.get_sell_value(), lock_text)
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
