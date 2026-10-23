class_name ItemData
extends Resource
## 장비 아이템 공통 데이터 (무기 / 방패 / 투구 / 갑옷 / 장신구 / 포션의 부모 클래스).
## 상점·드랍·인벤토리는 이 타입만 알면 되므로, 새 장비 종류를 추가해도 UI 코드가 그대로 동작합니다.
##
## 등급(rarity) 안에서도 tier 로 하급 · 중하급 · 중급 · 중상급 · 상급이 나뉨 — 같은 등급이라도 윗 단계가 더 세고 비쌈.
## 화면에는 등급(일반 · 희귀 · 레어 · 전설 · 신화)만 보여 주고 단계는 숨김 — 유저는 능력치를 보고 고름.
## in_shop = false 인 「드랍 전용」 장비는 상점에 없고 몬스터 · 보스 상자에서만 나옴.
## 신화(MYTHIC): 10스테이지마다 보스가 떨어뜨리는 단 하나의 장비. 상점에 없고, 100스테이지를 깨기 전에는 봉인되어 착용 불가.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }

const RARITY_COLORS := {
	Rarity.COMMON: Color(0.85, 0.85, 0.85),
	Rarity.RARE: Color(0.35, 0.65, 1.0),
	Rarity.EPIC: Color(0.75, 0.45, 1.0),
	Rarity.LEGENDARY: Color(1.0, 0.75, 0.25),
	Rarity.MYTHIC: Color(1.0, 0.32, 0.38),
}
const RARITY_NAMES := {
	Rarity.COMMON: "일반",
	Rarity.RARE: "희귀",
	Rarity.EPIC: "레어",
	Rarity.LEGENDARY: "전설",
	Rarity.MYTHIC: "신화",
}
## 상점에서 아이템 줄 뒤에 깔리는 배경색 (희귀=파랑, 레어=보라, 전설=노랑, 신화=진홍)
const RARITY_BG_COLORS := {
	Rarity.COMMON: Color(0.22, 0.23, 0.28, 0.9),
	Rarity.RARE: Color(0.13, 0.27, 0.6, 0.9),
	Rarity.EPIC: Color(0.38, 0.16, 0.58, 0.9),
	Rarity.LEGENDARY: Color(0.62, 0.48, 0.08, 0.9),
	Rarity.MYTHIC: Color(0.55, 0.06, 0.14, 0.92),
}
## 상점에서 구매할 수 있게 되는 스테이지 (1~10 일반 / 11~40 희귀 / 41~70 레어 / 71~100 전설). 신화는 상점에 없음
const RARITY_UNLOCK_STAGE := {
	Rarity.COMMON: 1,
	Rarity.RARE: 11,
	Rarity.EPIC: 41,
	Rarity.LEGENDARY: 71,
}
## 등급 안의 단계
enum Tier { LOW, MID_LOW, MID, MID_HIGH, HIGH }
const TIER_NAMES := ["하급", "중하급", "중급", "중상급", "상급"]
## 단계별로 「제 실력」을 내는 스테이지 (등급이 열린 스테이지 + 단계 × 간격) — 드랍 · 보물상자가 이 순서로 풀림
const TIER_STEP := {
	Rarity.COMMON: 1.5,
	Rarity.RARE: 5.0,
	Rarity.EPIC: 5.0,
	Rarity.LEGENDARY: 5.0,
}
## 신화 장비를 떨어뜨리는 보스의 스테이지 (10스테이지마다)
const MYTHIC_STAGE_STEP := 10

@export var id: StringName = &""
@export var display_name: String = "아이템"
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
## 등급 안의 단계 (하급 · 중하급 · 중급 · 중상급 · 상급 — 화면에는 안 보임)
@export var tier: Tier = Tier.LOW
@export var icon: Texture2D
## 세트 (ItemSets 의 id). 같은 세트를 여러 개 장착하면 세트 효과
@export var set_id: StringName = &""
## false 면 상점에 없고 몬스터 드랍 · 보스 상자로만 (드랍 전용 장비)
@export var in_shop: bool = true
## 운영자 장비 (Admin) — 저장 · 판매 · 버리기 · 선물 불가, 봉인 없음
var admin_only: bool = false

@export_group("Shop")
@export var price: int = 50

## 상인에게 팔 때 받는 비율
const SELL_RATIO := 0.2


func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func get_rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "?")


func get_tier_name() -> String:
	return TIER_NAMES[clampi(int(tier), 0, TIER_NAMES.size() - 1)]


## 화면에 보이는 등급 — 「전설」처럼 등급만 (단계는 숨기고, 드랍 전용은 「전설 · 드랍」)
func get_grade_text() -> String:
	if not in_shop and not is_mythic() and not (self is PotionData or self is RelicData):
		return "%s · 드랍" % get_rarity_name()
	return get_rarity_name()


func is_drop_only() -> bool:
	return not in_shop and not is_mythic() and not (self is PotionData or self is RelicData)


func is_mythic() -> bool:
	return rarity == Rarity.MYTHIC


## 신화 장비는 100스테이지를 깨기 전에는 봉인 (착용 불가)
func is_sealed() -> bool:
	return is_mythic() and not admin_only and not GameManager.mythic_unlocked


## 이 장비가 제 실력을 내는 스테이지 (드랍 · 보물상자 순서)
func get_fit_stage() -> int:
	if is_mythic():
		return 101
	return get_unlock_stage() + roundi(int(tier) * float(TIER_STEP.get(rarity, 5.0)))


func get_rarity_bg_color() -> Color:
	return RARITY_BG_COLORS.get(rarity, Color(0.2, 0.2, 0.2, 0.9))


## 상점에서 이 아이템을 살 수 있는 최소 스테이지 (신화는 상점에 없음)
func get_unlock_stage() -> int:
	return RARITY_UNLOCK_STAGE.get(rarity, 999)


## 해당 스테이지의 몬스터가 떨어뜨리는 등급 (= 그 스테이지 상점의 최고 등급, 신화 제외)
static func max_rarity_for_stage(stage: int) -> Rarity:
	var best := Rarity.COMMON
	for r in RARITY_UNLOCK_STAGE:
		if RARITY_UNLOCK_STAGE[r] <= stage and r > best:
			best = r
	return best


## 이펙트 화려함 단계 0(일반) ~ 3(전설 · 신화)
func get_fx_level() -> int:
	return mini(int(rarity), 3)


## 상인에게 팔 때 / 중복 획득 시 받는 골드
func get_sell_value() -> int:
	return maxi(5, roundi(price * SELL_RATIO))


## 상점 목록 한 줄 요약 (자식 클래스에서 오버라이드)
func get_summary() -> String:
	return ""


## 상점 상세 정보 (자식 클래스에서 오버라이드)
func get_stat_text() -> String:
	return "[%s]" % get_grade_text()


## 상세 정보 끝에 붙는 세트 · 봉인 안내
func get_extra_text() -> String:
	var lines := PackedStringArray()
	if set_id != &"":
		lines.append(ItemSets.describe(set_id))
	if is_mythic():
		var verb := "사용" if (self is PotionData or self is RelicData) else "착용"
		lines.append("신화 — 판매 불가" + ("  ·  [봉인] 100스테이지를 클리어하면 %s 가능" % verb if is_sealed() else "  ·  봉인 해제됨"))
	return "\n".join(lines)
