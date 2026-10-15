class_name ItemDB
## 모든 장비 리소스(무기/방패/투구/갑옷/장신구/포션)를 id(StringName)로 조회하는 정적 데이터베이스.
## 새 장비를 추가하려면 .tres 를 만들고 ITEM_PATHS 에 경로만 추가하세요.

const ITEM_PATHS: Array[String] = [
	# 검 / 단검 (근접)
	"res://data/weapons/rusty_sword.tres",
	"res://data/weapons/iron_sword.tres",
	"res://data/weapons/flame_blade.tres",
	"res://data/weapons/holy_sword.tres",
	"res://data/weapons/goblin_dagger.tres",
	# 활
	"res://data/weapons/hunter_bow.tres",
	"res://data/weapons/rapid_crossbow.tres",
	"res://data/weapons/windrunner_bow.tres",
	"res://data/weapons/solaris_bow.tres",
	# 마법 지팡이
	"res://data/weapons/apprentice_staff.tres",
	"res://data/weapons/frost_staff.tres",
	"res://data/weapons/ignis_staff.tres",
	"res://data/weapons/arcana_staff.tres",
	"res://data/weapons/slime_staff.tres",
	"res://data/weapons/king_scepter.tres",
	# 방패
	"res://data/shields/wooden_shield.tres",
	"res://data/shields/iron_shield.tres",
	"res://data/shields/goblin_buckler.tres",
	"res://data/shields/royal_aegis.tres",
	"res://data/shields/colossus_bulwark.tres",
	# 투구
	"res://data/helmets/leather_cap.tres",
	"res://data/helmets/iron_helm.tres",
	"res://data/helmets/orc_warhelm.tres",
	"res://data/helmets/gatekeeper_horns.tres",
	# 갑옷
	"res://data/armors/leather_armor.tres",
	"res://data/armors/chain_mail.tres",
	"res://data/armors/hellsteel_plate.tres",
	"res://data/armors/paladin_plate.tres",
	# 신발
	"res://data/boots/leather_boots.tres",
	"res://data/boots/iron_greaves.tres",
	"res://data/boots/shadow_boots.tres",
	"res://data/boots/windwalker_boots.tres",
	# 장신구 (팔찌 / 반지 / 펜던트)
	"res://data/accessories/leather_bracelet.tres",
	"res://data/accessories/silver_bracelet.tres",
	"res://data/accessories/obsidian_bracelet.tres",
	"res://data/accessories/dragonscale_bracelet.tres",
	"res://data/accessories/copper_ring.tres",
	"res://data/accessories/ruby_ring.tres",
	"res://data/accessories/blood_ruby_ring.tres",
	"res://data/accessories/star_ring.tres",
	"res://data/accessories/wooden_pendant.tres",
	"res://data/accessories/sapphire_pendant.tres",
	"res://data/accessories/guardian_pendant.tres",
	"res://data/accessories/life_pendant.tres",
	# 회복 포션 (소모품)
	"res://data/potions/small_potion.tres",
	"res://data/potions/potion.tres",
	"res://data/potions/greater_potion.tres",
]

static var _cache: Dictionary = {}


static func get_item(item_id: StringName) -> ItemData:
	_ensure_loaded()
	if not _cache.has(item_id):
		push_error("ItemDB: 알 수 없는 아이템 id '%s'" % item_id)
		return null
	return _cache[item_id] as ItemData


static func get_weapon(item_id: StringName) -> WeaponData:
	return get_item(item_id) as WeaponData


static func get_shield(item_id: StringName) -> ShieldData:
	return get_item(item_id) as ShieldData


static func get_helmet(item_id: StringName) -> HelmetData:
	return get_item(item_id) as HelmetData


static func get_all() -> Array[ItemData]:
	_ensure_loaded()
	var result: Array[ItemData] = []
	for item in _cache.values():
		result.append(item as ItemData)
	return result


## 보스 상자용: 검 / 활 / 지팡이 / 방패 / 투구 / 갑옷 / 신발 중 해당 등급 장비 목록
static func get_chest_candidates(rarity: ItemData.Rarity) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in get_all():
		if item.rarity != rarity:
			continue
		var weapon := item as WeaponData
		var is_chest_weapon := weapon != null and weapon.weapon_type != WeaponData.WeaponType.DAGGER
		if is_chest_weapon or item is ShieldData or item is HelmetData or item is ArmorData or item is BootsData:
			result.append(item)
	return result


static func get_accessory(item_id: StringName) -> AccessoryData:
	return get_item(item_id) as AccessoryData


static func get_potion(item_id: StringName) -> PotionData:
	return get_item(item_id) as PotionData


static func has_item(item_id: StringName) -> bool:
	_ensure_loaded()
	return _cache.has(item_id)


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	for path in ITEM_PATHS:
		var item := load(path) as ItemData
		if item == null:
			push_error("ItemDB: '%s' 를 ItemData 로 불러오지 못했습니다." % path)
			continue
		if item.id == &"":
			push_error("ItemDB: '%s' 의 id 가 비어 있습니다." % path)
			continue
		_cache[item.id] = item
