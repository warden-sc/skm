class_name ItemDB
## 모든 장비 리소스(무기/방패)를 id(StringName)로 조회하는 정적 데이터베이스.
## 새 장비를 추가하려면 .tres 를 만들고 ITEM_PATHS 에 경로만 추가하세요.

const ITEM_PATHS: Array[String] = [
	# 무기 - 근접
	"res://data/weapons/rusty_sword.tres",
	"res://data/weapons/iron_sword.tres",
	"res://data/weapons/flame_blade.tres",
	"res://data/weapons/goblin_dagger.tres",
	# 무기 - 원거리
	"res://data/weapons/hunter_bow.tres",
	"res://data/weapons/rapid_crossbow.tres",
	"res://data/weapons/apprentice_staff.tres",
	"res://data/weapons/slime_staff.tres",
	"res://data/weapons/king_scepter.tres",
	# 방패
	"res://data/shields/wooden_shield.tres",
	"res://data/shields/iron_shield.tres",
	"res://data/shields/goblin_buckler.tres",
	"res://data/shields/royal_aegis.tres",
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
