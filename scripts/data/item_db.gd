class_name ItemDB
## 모든 장비 리소스(무기/방패/투구/갑옷/장신구/포션)를 id(StringName)로 조회하는 정적 데이터베이스.
## 새 장비를 추가하려면 .tres 를 만들고 ITEM_PATHS 에 경로만 추가하세요.

const ITEM_PATHS: Array[String] = [
	# 검 / 단검 (근접)
	"res://data/weapons/rusty_sword.tres",
	"res://data/weapons/traveler_sword.tres",
	"res://data/weapons/bronze_sword.tres",
	"res://data/weapons/iron_sword.tres",
	"res://data/weapons/knight_sword.tres",
	"res://data/weapons/mithril_sword.tres",
	"res://data/weapons/flame_blade.tres",
	"res://data/weapons/dragonscale_sword.tres",
	"res://data/weapons/rune_sword.tres",
	"res://data/weapons/holy_sword.tres",
	"res://data/weapons/seraph_sword.tres",
	"res://data/weapons/genesis_sword.tres",
	"res://data/weapons/abaddon_sword.tres",
	"res://data/weapons/goblin_dagger.tres",
	# 활
	"res://data/weapons/hunter_bow.tres",
	"res://data/weapons/traveler_bow.tres",
	"res://data/weapons/bronze_bow.tres",
	"res://data/weapons/rapid_crossbow.tres",
	"res://data/weapons/knight_crossbow.tres",
	"res://data/weapons/mithril_bow.tres",
	"res://data/weapons/windrunner_bow.tres",
	"res://data/weapons/dragonscale_bow.tres",
	"res://data/weapons/rune_bow.tres",
	"res://data/weapons/solaris_bow.tres",
	"res://data/weapons/seraph_bow.tres",
	"res://data/weapons/genesis_bow.tres",
	"res://data/weapons/apollo_bow.tres",
	# 마법 지팡이
	"res://data/weapons/apprentice_staff.tres",
	"res://data/weapons/traveler_staff.tres",
	"res://data/weapons/bronze_staff.tres",
	"res://data/weapons/slime_staff.tres",
	"res://data/weapons/frost_staff.tres",
	"res://data/weapons/knight_staff.tres",
	"res://data/weapons/mithril_staff.tres",
	"res://data/weapons/ignis_staff.tres",
	"res://data/weapons/dragonscale_staff.tres",
	"res://data/weapons/rune_staff.tres",
	"res://data/weapons/arcana_staff.tres",
	"res://data/weapons/king_scepter.tres",
	"res://data/weapons/seraph_staff.tres",
	"res://data/weapons/genesis_staff.tres",
	"res://data/weapons/archmage_staff.tres",
	# 방패
	"res://data/shields/wooden_shield.tres",
	"res://data/shields/traveler_shield.tres",
	"res://data/shields/bronze_shield.tres",
	"res://data/shields/goblin_buckler.tres",
	"res://data/shields/iron_shield.tres",
	"res://data/shields/knight_shield.tres",
	"res://data/shields/mithril_shield.tres",
	"res://data/shields/royal_aegis.tres",
	"res://data/shields/dragonscale_shield.tres",
	"res://data/shields/rune_shield.tres",
	"res://data/shields/colossus_bulwark.tres",
	"res://data/shields/seraph_shield.tres",
	"res://data/shields/genesis_shield.tres",
	"res://data/shields/mars_shield.tres",
	# 투구
	"res://data/helmets/leather_cap.tres",
	"res://data/helmets/traveler_helmet.tres",
	"res://data/helmets/bronze_helmet.tres",
	"res://data/helmets/iron_helm.tres",
	"res://data/helmets/knight_helmet.tres",
	"res://data/helmets/mithril_helmet.tres",
	"res://data/helmets/orc_warhelm.tres",
	"res://data/helmets/dragonscale_helmet.tres",
	"res://data/helmets/rune_helmet.tres",
	"res://data/helmets/gatekeeper_horns.tres",
	"res://data/helmets/seraph_helmet.tres",
	"res://data/helmets/genesis_helmet.tres",
	"res://data/helmets/athena_helmet.tres",
	# 갑옷
	"res://data/armors/leather_armor.tres",
	"res://data/armors/traveler_armor.tres",
	"res://data/armors/bronze_armor.tres",
	"res://data/armors/chain_mail.tres",
	"res://data/armors/knight_armor.tres",
	"res://data/armors/mithril_armor.tres",
	"res://data/armors/hellsteel_plate.tres",
	"res://data/armors/dragonscale_armor.tres",
	"res://data/armors/rune_armor.tres",
	"res://data/armors/paladin_plate.tres",
	"res://data/armors/seraph_armor.tres",
	"res://data/armors/genesis_armor.tres",
	"res://data/armors/hephaestus_armor.tres",
	# 신발
	"res://data/boots/leather_boots.tres",
	"res://data/boots/traveler_boots.tres",
	"res://data/boots/bronze_boots.tres",
	"res://data/boots/iron_greaves.tres",
	"res://data/boots/knight_boots.tres",
	"res://data/boots/mithril_boots.tres",
	"res://data/boots/shadow_boots.tres",
	"res://data/boots/dragonscale_boots.tres",
	"res://data/boots/rune_boots.tres",
	"res://data/boots/windwalker_boots.tres",
	"res://data/boots/seraph_boots.tres",
	"res://data/boots/genesis_boots.tres",
	"res://data/boots/hermes_boots.tres",
	# 장신구 (팔찌 / 반지 / 펜던트)
	"res://data/accessories/leather_bracelet.tres",
	"res://data/accessories/traveler_bracelet.tres",
	"res://data/accessories/bronze_bracelet.tres",
	"res://data/accessories/silver_bracelet.tres",
	"res://data/accessories/knight_bracelet.tres",
	"res://data/accessories/mithril_bracelet.tres",
	"res://data/accessories/obsidian_bracelet.tres",
	"res://data/accessories/dragonscale_cuff.tres",
	"res://data/accessories/rune_bracelet.tres",
	"res://data/accessories/dragonscale_bracelet.tres",
	"res://data/accessories/seraph_bracelet.tres",
	"res://data/accessories/genesis_bracelet.tres",
	"res://data/accessories/copper_ring.tres",
	"res://data/accessories/traveler_ring.tres",
	"res://data/accessories/bronze_ring.tres",
	"res://data/accessories/ruby_ring.tres",
	"res://data/accessories/knight_ring.tres",
	"res://data/accessories/mithril_ring.tres",
	"res://data/accessories/blood_ruby_ring.tres",
	"res://data/accessories/dragonscale_ring.tres",
	"res://data/accessories/rune_ring.tres",
	"res://data/accessories/star_ring.tres",
	"res://data/accessories/seraph_ring.tres",
	"res://data/accessories/genesis_ring.tres",
	"res://data/accessories/wooden_pendant.tres",
	"res://data/accessories/traveler_pendant.tres",
	"res://data/accessories/bronze_pendant.tres",
	"res://data/accessories/sapphire_pendant.tres",
	"res://data/accessories/knight_pendant.tres",
	"res://data/accessories/mithril_pendant.tres",
	"res://data/accessories/guardian_pendant.tres",
	"res://data/accessories/dragonscale_pendant.tres",
	"res://data/accessories/rune_pendant.tres",
	"res://data/accessories/life_pendant.tres",
	"res://data/accessories/seraph_pendant.tres",
	"res://data/accessories/genesis_pendant.tres",
	"res://data/accessories/spirit_bracelet.tres",
	"res://data/accessories/gabriel_ring.tres",
	"res://data/accessories/king_pendant.tres",
	# 회복 포션 (소모품) — 고대 용의 피는 히든 보스 보상
	"res://data/potions/small_potion.tres",
	"res://data/potions/potion.tres",
	"res://data/potions/greater_potion.tres",
	"res://data/potions/elixir.tres",
	"res://data/potions/dragon_blood.tres",
	# 신화 사용 아이템 (원초의 불꽃 · 최후의 나팔)
	"res://data/relics/primal_flame.tres",
	"res://data/relics/last_trumpet.tres",
]

## 10스테이지마다 보스가 넘겨주는 신화 장비
const MYTHIC_BY_STAGE := {
	10: &"king_pendant", 20: &"archmage_staff", 30: &"spirit_bracelet", 40: &"hermes_boots", 50: &"hephaestus_armor",
	60: &"mars_shield", 70: &"apollo_bow", 80: &"athena_helmet", 90: &"abaddon_sword", 100: &"gabriel_ring",
}

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


## 보스 상자용: 해당 등급에서 단계(하급 · 중급 · 상급)가 이미 풀린(get_fit_stage ≤ up_to_stage) 장비 — 상점 장비만, 신화 · 포션 제외
static func get_chest_candidates(rarity: ItemData.Rarity, up_to_stage: int = 999) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in get_all():
		if item.rarity != rarity or item is PotionData or item.is_mythic() or not item.in_shop:
			continue
		if item.get_fit_stage() <= up_to_stage:
			result.append(item)
	return result


## 일반 몬스터가 떨어뜨리는 장비: 그 스테이지 등급의, 이미 풀린 단계 장비 (+ 그 몬스터만의 드랍 전용 장비)
static func get_drop_pool(stage: int, own_ids: Array[StringName] = []) -> Array[ItemData]:
	var rarity := ItemData.max_rarity_for_stage(stage)
	var result := get_chest_candidates(rarity, stage + 2)
	for item_id in own_ids:
		var own := get_item(item_id) if has_item(item_id) else null
		if own != null and not own.in_shop and not own.is_mythic() and own.rarity <= rarity and not result.has(own):
			result.append(own)
	return result


## 상점에 진열되는 장비 (포션 → 검 → 활 → … 순서, 신화 · 드랍 전용 제외)
static func get_shop_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for path in ITEM_PATHS:
		var item := get_item(StringName(path.get_file().get_basename()))
		if item != null and item.in_shop and not item.is_mythic():
			result.append(item)
	return result


## 그 스테이지 보스가 넘겨주는 신화 장비 (10스테이지마다, 없으면 null)
static func get_mythic_for_stage(stage: int) -> ItemData:
	if stage <= 0 or stage % ItemData.MYTHIC_STAGE_STEP != 0:
		return null
	var item_id: StringName = MYTHIC_BY_STAGE.get(stage, &"")
	return get_item(item_id) if item_id != &"" else null


static func get_accessory(item_id: StringName) -> AccessoryData:
	return get_item(item_id) as AccessoryData


static func get_relic(item_id: StringName) -> RelicData:
	return get_item(item_id) as RelicData


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
