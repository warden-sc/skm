class_name ItemData
extends Resource
## 장비 아이템 공통 데이터 (무기 / 방패의 부모 클래스).
## 상점·드랍·인벤토리는 이 타입만 알면 되므로, 새 장비 종류를 추가해도 UI 코드가 그대로 동작합니다.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_COLORS := {
	Rarity.COMMON: Color(0.85, 0.85, 0.85),
	Rarity.RARE: Color(0.35, 0.65, 1.0),
	Rarity.EPIC: Color(0.75, 0.45, 1.0),
	Rarity.LEGENDARY: Color(1.0, 0.75, 0.25),
}
const RARITY_NAMES := {
	Rarity.COMMON: "일반",
	Rarity.RARE: "희귀",
	Rarity.EPIC: "영웅",
	Rarity.LEGENDARY: "전설",
}

@export var id: StringName = &""
@export var display_name: String = "아이템"
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D

@export_group("Shop")
@export var price: int = 50


func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func get_rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "?")


func get_sell_value() -> int:
	@warning_ignore("integer_division")
	return maxi(5, price / 4)


## 상점 목록 한 줄 요약 (자식 클래스에서 오버라이드)
func get_summary() -> String:
	return ""


## 상점 상세 정보 (자식 클래스에서 오버라이드)
func get_stat_text() -> String:
	return "[%s]" % get_rarity_name()
