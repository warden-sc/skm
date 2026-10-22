class_name AdminGear
## 운영자 장비 10종 — 신에 가까운 성기사. 신화 장비를 바탕으로 실행 중에 만들어짐 (ItemDB 의 목록 · 상점 · 드랍 · 저장에는 없음).
## 모든 컴퓨터가 같은 id 로 같은 장비를 만들 수 있어서, 운영자가 멀티플레이 참가자에게 선물해도 그대로 받음.
##   무기   운영자의 검 · 활 · 지팡이 — 공격력 99,999,999 · 치명타 100% · 방어 관통 · 운영자 전용 스킬
##   방어구 운영자의 방패 · 투구 · 갑옷(앞에 운영자의 문양, 등 뒤에 날개 — 입고 있으면 무적) · 신발
##   장신구 운영자의 반지 · 팔찌 · 펜던트

const COLOR := Color(1.0, 0.92, 0.6)
const WEAPON_DAMAGE := 99999999
const SPRITES := "res://assets/sprites/"
const WINGS: Texture2D = preload("res://assets/sprites/effects/admin_wings.png")

## [id, 이름, 바탕 장비 id, 그림, 착용 그림(또는 손에 든 그림)]
const SPECS := [
	[&"admin_sword", "운영자의 검", &"abaddon_sword", "weapons/admin_sword.png", ""],
	[&"admin_bow", "운영자의 활", &"apollo_bow", "weapons/admin_bow.png", "weapons/admin_bow_held.png"],
	[&"admin_staff", "운영자의 지팡이", &"archmage_staff", "weapons/admin_staff.png", ""],
	[&"admin_shield", "운영자의 방패", &"mars_shield", "shields/admin_shield.png", ""],
	[&"admin_helmet", "운영자의 투구", &"athena_helmet", "helmets/admin_helmet.png", "helmets/admin_helmet_worn.png"],
	[&"admin_armor", "운영자의 갑옷", &"hephaestus_armor", "armors/admin_armor.png", "armors/admin_armor_worn.png"],
	[&"admin_boots", "운영자의 신발", &"hermes_boots", "boots/admin_boots.png", "boots/admin_boots_worn.png"],
	[&"admin_ring", "운영자의 반지", &"gabriel_ring", "accessories/admin_ring.png", ""],
	[&"admin_bracelet", "운영자의 팔찌", &"spirit_bracelet", "accessories/admin_bracelet.png", ""],
	[&"admin_pendant", "운영자의 펜던트", &"king_pendant", "accessories/admin_pendant.png", ""],
]
const DESCRIPTIONS := {
	&"admin_sword": "운영자 전용 — 즉사급 공격력. [Q] 천상낙하참: 날개를 펼쳐 하늘로 올랐다가 보스를 향해 내리꽂힘",
	&"admin_bow": "운영자 전용 — 즉사급 공격력. [Q] 천벌의 빛화살: 하늘로 올라 전장에 빛의 화살비를 퍼부음",
	&"admin_staff": "운영자 전용 — 즉사급 공격력. [Q] 창세의 빛: 하늘의 마법진에서 모든 적에게 빛기둥이 내리꽂힘",
	&"admin_shield": "운영자 전용 — 무엇이든 막아내는 성스러운 방패. 운영자의 문양이 새겨져 있다",
	&"admin_helmet": "운영자 전용 — 양옆에 작은 날개가 달린 성기사의 투구",
	&"admin_armor": "운영자 전용 — 가슴에 운영자의 문양, 등 뒤에 빛의 날개. 입고 있는 동안 무적",
	&"admin_boots": "운영자 전용 — 이동 속도 +60% · 대시 대기시간 -80%",
	&"admin_ring": "운영자 전용 — 공격력 +1000% · 치명타 확률 +100%",
	&"admin_bracelet": "운영자 전용 — 치명타 피해 +1000% · 방어 관통",
	&"admin_pendant": "운영자 전용 — 최대 체력 +9,999,999 · 체력 재생",
}

static var _items: Array[ItemData] = []
static var _by_id: Dictionary = {}


static func get_all() -> Array[ItemData]:
	if _items.is_empty():
		for spec in SPECS:
			var item := _make(spec)
			if item != null:
				_items.append(item)
				_by_id[item.id] = item
	return _items


static func has(item_id: StringName) -> bool:
	get_all()
	return _by_id.has(item_id)


static func get_item(item_id: StringName) -> ItemData:
	get_all()
	return _by_id.get(item_id) as ItemData


## ItemDB 에 있으면 그것, 없으면 운영자 장비 (선물 · 강림 RPC 용)
static func find(item_id: StringName) -> ItemData:
	if item_id == &"":
		return null
	if ItemDB.has_item(item_id):
		return ItemDB.get_item(item_id)
	return get_item(item_id)


static func is_admin_armor(armor: ArmorData) -> bool:
	return armor != null and armor.admin_only


static func _make(spec: Array) -> ItemData:
	var base := ItemDB.get_item(spec[2]) if ItemDB.has_item(spec[2]) else null
	if base == null:
		return null
	var item := base.duplicate() as ItemData
	item.id = spec[0]
	item.display_name = spec[1]
	item.description = DESCRIPTIONS.get(item.id, "운영자 전용")
	item.icon = load(SPRITES + spec[3]) as Texture2D
	item.set_id = &""
	item.price = 0
	item.in_shop = false
	item.admin_only = true
	var extra: String = spec[4]
	if item is WeaponData:
		var weapon := item as WeaponData
		weapon.damage = WEAPON_DAMAGE
		weapon.crit_chance = 1.0
		weapon.armor_pen = 999999
		weapon.effect_color = COLOR
		if extra != "":
			weapon.held_texture = load(SPRITES + extra) as Texture2D
	elif item is ShieldData:
		var shield := item as ShieldData
		shield.defense = 999999
		shield.max_guard = 999999.0
		shield.guard_regen = 999999.0
		shield.perfect_guard_window = 0.6
		shield.block_arc_degrees = 360.0
	elif item is HelmetData:
		(item as HelmetData).defense = 999999
		(item as HelmetData).bonus_max_hp = 999999
		(item as HelmetData).worn_texture = load(SPRITES + extra) as Texture2D
	elif item is ArmorData:
		(item as ArmorData).defense = 999999
		(item as ArmorData).bonus_max_hp = 999999
		(item as ArmorData).worn_texture = load(SPRITES + extra) as Texture2D
	elif item is BootsData:
		var boots := item as BootsData
		boots.defense = 999999
		boots.move_bonus = 0.6
		boots.dash_cooldown_reduction = 0.8
		boots.worn_texture = load(SPRITES + extra) as Texture2D
	elif item is AccessoryData:
		var acc := item as AccessoryData
		match item.id:
			&"admin_ring":
				acc.attack_bonus = 10.0
				acc.crit_chance_bonus = 1.0
			&"admin_bracelet":
				acc.crit_damage_bonus = 10.0
				acc.armor_pen = 999999
			&"admin_pendant":
				acc.bonus_max_hp = 9999999
				acc.hp_regen = 99999.0
	return item
