class_name WeaponDB
## 모든 무기 리소스를 id(StringName)로 조회하는 정적 데이터베이스.
## 새 무기를 추가하려면 .tres 를 만들고 WEAPON_PATHS 에 경로만 추가하세요.

const WEAPON_PATHS: Array[String] = [
	"res://data/weapons/rusty_sword.tres",
	"res://data/weapons/iron_sword.tres",
	"res://data/weapons/flame_blade.tres",
	"res://data/weapons/goblin_dagger.tres",
	"res://data/weapons/hunter_bow.tres",
	"res://data/weapons/rapid_crossbow.tres",
	"res://data/weapons/apprentice_staff.tres",
	"res://data/weapons/slime_staff.tres",
	"res://data/weapons/king_scepter.tres",
]

static var _cache: Dictionary = {}


static func get_weapon(weapon_id: StringName) -> WeaponData:
	_ensure_loaded()
	if not _cache.has(weapon_id):
		push_error("WeaponDB: 알 수 없는 무기 id '%s'" % weapon_id)
		return null
	return _cache[weapon_id] as WeaponData


static func has_weapon(weapon_id: StringName) -> bool:
	_ensure_loaded()
	return _cache.has(weapon_id)


static func get_all() -> Array[WeaponData]:
	_ensure_loaded()
	var result: Array[WeaponData] = []
	for w in _cache.values():
		result.append(w as WeaponData)
	return result


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	for path in WEAPON_PATHS:
		var weapon := load(path) as WeaponData
		if weapon == null:
			push_error("WeaponDB: '%s' 를 WeaponData 로 불러오지 못했습니다." % path)
			continue
		if weapon.id == &"":
			push_error("WeaponDB: '%s' 의 id 가 비어 있습니다." % path)
			continue
		_cache[weapon.id] = weapon
