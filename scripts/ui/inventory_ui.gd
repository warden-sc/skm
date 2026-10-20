class_name InventoryUI
extends CanvasLayer
## 인벤토리 [I] / [Tab]. 열려 있는 동안 게임이 일시정지됩니다.
##
## 왼쪽: 장비 칸
##   무기 3칸 (검 / 활 / 지팡이) — 손에 든 무기는 노란 테두리
##   방어구 4칸 (방패 / 투구 / 갑옷 / 신발)
##   장신구 3칸 (팔찌 / 반지 / 펜던트)
##   → 칸을 클릭하면 장착 해제 (마지막 무기는 해제 불가)
## 오른쪽: 가방 (회복 포션 + 보유 장비 전체) — 포션 사용 / 장비 장착·해제 버튼
## 아래: 마우스를 올린 장비의 상세 정보

const SLOT_SIZE := Vector2(28, 28)
const ARMOR_SLOT_NAMES := ["방패", "투구", "갑옷", "신발"]

@onready var _gold_label: Label = %InvGold
@onready var _weapon_slots: HBoxContainer = %WeaponSlots
@onready var _armor_slots: HBoxContainer = %ArmorSlots
@onready var _accessory_slots: HBoxContainer = %AccessorySlots
@onready var _stats: Label = %Stats
@onready var _bag_list: VBoxContainer = %BagList
@onready var _detail: Label = %InvDetail
@onready var _close_button: Button = %InvCloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	GameManager.inventory_changed.connect(_on_data_changed)
	GameManager.equipment_changed.connect(_on_data_changed)
	GameManager.stats_changed.connect(_on_data_changed)
	GameManager.potions_changed.connect(_on_data_changed)
	GameManager.gold_changed.connect(_on_data_changed.unbind(1))
	_close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		if visible:
			close()
			get_viewport().set_input_as_handled()
		elif not get_tree().paused and not GameManager.is_player_dead:
			open()
			get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_detail.text = "장비에 마우스를 올리면 상세 정보가 표시됩니다."
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


func _on_data_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_gold_label.text = "보유 골드: %d G" % GameManager.gold
	for container in [_weapon_slots, _armor_slots, _accessory_slots, _bag_list]:
		for child in (container as Node).get_children():
			(container as Node).remove_child(child)  # 바로 빼서 개수가 정확하게 (같은 프레임에 여러 번 갱신돼도)
			child.queue_free()

	for i in GameManager.weapon_slots.size():
		var caption := "%d %s" % [i + 1, GameManager.WEAPON_SLOT_NAMES[i]]
		_weapon_slots.add_child(_make_slot(GameManager.weapon_slots[i], caption, i == GameManager.active_weapon_slot))
	var armors: Array[ItemData] = [GameManager.equipped_shield, GameManager.equipped_helmet, GameManager.equipped_armor, GameManager.equipped_boots]
	for i in armors.size():
		_armor_slots.add_child(_make_slot(armors[i], ARMOR_SLOT_NAMES[i], false))
	for i in GameManager.accessory_slots.size():
		_accessory_slots.add_child(_make_slot(GameManager.accessory_slots[i], GameManager.ACCESSORY_SLOT_NAMES[i], false))

	_stats.text = _stats_text()

	for relic in GameManager.relics:
		var cd := GameManager.get_relic_cooldown(relic)
		var relic_button := ItemRow.make_button("봉인" if relic.is_sealed() else ("%d초" % ceili(cd) if cd > 0.0 else "사용"), cd > 0.0 or relic.is_sealed(), _on_use_relic_pressed.bind(relic), 40.0)
		_bag_list.add_child(ItemRow.build(relic, [relic_button], _show_detail.bind(relic), false, relic.get_summary()))
	for potion in GameManager.get_owned_potions():
		var count := GameManager.get_potion_count(potion.id)
		var use_button := ItemRow.make_button("봉인" if potion.is_sealed() else "사용", potion.is_sealed() or (GameManager.hp >= GameManager.max_hp and potion.buff_duration <= 0.0), _on_use_potion_pressed.bind(potion), 40.0)
		var potion_line := "보유 %d개 · 체력 +%d  (%s)" % [count, potion.get_heal(GameManager.max_hp), "[H] 자동 사용" if potion.auto_use else "[C] 사용"]
		_bag_list.add_child(ItemRow.build(potion, [use_button], _show_detail.bind(potion), false, potion_line))

	for item in _sorted_items():
		var equipped := GameManager.is_equipped(item)
		var sealed := item.is_sealed()
		var button := ItemRow.make_button("봉인" if sealed else ("해제" if equipped else "장착"), sealed,
			_on_unequip_pressed.bind(item) if equipped else _on_equip_pressed.bind(item), 40.0)
		var drop_button := ItemRow.make_button("버리기", not GameManager.can_drop(item), _on_drop_pressed.bind(item), 40.0)
		drop_button.tooltip_text = "바닥에 떨어뜨림 — 나나 동료가 주울 수 있음"
		var subtitle := ("장착중 · " if equipped else "") + ("[봉인] " if sealed else "") + item.get_summary()
		_bag_list.add_child(ItemRow.build(item, [button, drop_button], _show_detail.bind(item), false, subtitle))


func _make_slot(item: ItemData, caption: String, highlight: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style := ItemRow.rarity_style(item, highlight)
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		button.add_theme_stylebox_override(state, style)
	if item != null:
		button.icon = item.icon
		button.tooltip_text = "%s (클릭: 해제)" % item.display_name
		button.pressed.connect(_on_unequip_pressed.bind(item))
		button.mouse_entered.connect(_show_detail.bind(item))
	else:
		button.disabled = true
	box.add_child(button)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 8)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.6) if highlight else Color(0.75, 0.75, 0.8))
	box.add_child(label)
	return box


func _stats_text() -> String:
	var weapon := GameManager.equipped_weapon
	var lines := PackedStringArray()
	if weapon != null:
		lines.append("손에 든 무기: %s (ATK %d) · 치명 %d%% x%.1f" % [weapon.display_name, roundi(weapon.damage * GameManager.damage_multiplier), roundi(GameManager.get_crit_chance(weapon) * 100.0), weapon.crit_multiplier + GameManager.get_crit_damage_bonus()])
		lines.append("방깍 %d · 공격력 +%d%% · 방어력 %d · 최대 HP %d" % [GameManager.get_armor_pen(weapon), roundi(GameManager.get_attack_bonus() * 100.0), GameManager.get_total_defense(), GameManager.max_hp])
	else:
		lines.append("방어력 %d · 최대 HP %d" % [GameManager.get_total_defense(), GameManager.max_hp])
	var reduction := GameManager.get_damage_reduction()
	lines.append("이속 +%d%% · 재생 %.1f/s%s" % [roundi(GameManager.get_move_speed_bonus() * 100.0), GameManager.get_hp_regen(), " · 받는 피해 -%d%%" % roundi(reduction * 100.0) if reduction > 0.0 else ""])
	# 세트는 한 줄로 (자세한 효과는 장비에 마우스를 올리면 설명칸에)
	var counts := GameManager.get_set_counts()
	var sets := PackedStringArray()
	for set_id in counts:
		if int(counts[set_id]) >= 2:
			sets.append("%s %d/%d" % [ItemSets.get_set_name(set_id), int(counts[set_id]), ItemSets.get_piece_count(set_id)])
	if not sets.is_empty():
		lines.append("세트: " + " · ".join(sets))
	if not GameManager.key_items.is_empty():
		var treasures := PackedStringArray()
		for key in GameManager.key_items:
			treasures.append(str(GameManager.KEY_ITEM_NAMES.get(key, key)))
		lines.append("보물: " + ", ".join(treasures))
	return "\n".join(lines)


## 가방 정렬: 무기 → 방패 → 투구 → 갑옷 → 장신구(팔찌·반지·펜던트), 같은 종류는 등급 높은 순
func _sorted_items() -> Array[ItemData]:
	var sorted: Array[ItemData] = GameManager.items.duplicate()
	sorted.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		var ka := _type_order(a)
		var kb := _type_order(b)
		return ka < kb if ka != kb else a.rarity > b.rarity)
	return sorted


func _type_order(item: ItemData) -> int:
	if item is WeaponData:
		return GameManager.weapon_slot_of(item as WeaponData)
	if item is ShieldData:
		return 3
	if item is HelmetData:
		return 4
	if item is ArmorData:
		return 5
	if item is BootsData:
		return 6
	if item is AccessoryData:
		return 7 + (item as AccessoryData).slot_type
	return 10


func _show_detail(item: ItemData) -> void:
	_detail.text = ItemRow.detail_text(item)
	(_detail.get_parent() as ScrollContainer).scroll_vertical = 0


func _on_equip_pressed(item: ItemData) -> void:
	GameManager.equip_item(item)


## 버리기: 용사 발밑에 떨어뜨림
func drop(item: ItemData) -> bool:
	var player: Player = null
	for p in Player.get_all(get_tree()):
		if p.is_local():
			player = p
	return GameManager.drop_item(item, player.global_position if player != null else Vector2.ZERO)


func _on_drop_pressed(item: ItemData) -> void:
	drop(item)


func _on_use_potion_pressed(potion: PotionData) -> void:
	GameManager.use_potion(potion)


func _on_use_relic_pressed(relic: RelicData) -> void:
	close()
	GameManager.use_relic(relic)


func _on_unequip_pressed(item: ItemData) -> void:
	GameManager.unequip_item(item)
