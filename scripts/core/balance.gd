class_name Balance
## 전투 수치 배율 (딜 인플레). 몬스터 씬에 적힌 체력 · 방어력 · 공격력은 예전 단위 그대로 두고,
## 전투가 일어나는 곳에서 K 배로 키웁니다 — 보스 기믹의 방어력 ± · 화상 · 피해 수치를 하나하나 고치지 않아도 됩니다.
##   몬스터 체력        : Enemy.apply_difficulty 에서 max_hp × K
##   몬스터 방어력      : Enemy.calc_damage 에서 defense × K (방어력 ± 기믹도 그대로 K 배)
##   몬스터 → 용사 피해 : Player.take_hit · apply_burn 에서 × K (최대 체력 비율 피해는 이미 새 단위라 그대로)
##   장비 · 포션 · 용사 체력은 데이터 자체가 새 단위 (기본 체력 1000)

const K := 10


## 예전 단위의 몬스터 수치 → 실제 전투 수치
static func scale(value: int) -> int:
	return value * K


## 화면에 보여 줄 방어력 (예전 단위 → 실제)
static func defense_text(value: int) -> String:
	return str(value * K)


# ============================================================ 경제 (골드 · 값)
## 노멀 · 혼자 기준으로 스테이지 하나에서 버는 골드 목표: INCOME_BASE × 스테이지^INCOME_EXP
##   (1스테이지 220 · 10스테이지 약 3100 · 50스테이지 약 19800 · 100스테이지 약 43900)
## 그중 사냥터 몬스터 45% · 보스 25% · 보물상자 30%. 신화 보상 스테이지(10·20…90)는 보스 골드 · 상자 대신 신화 장비.
const INCOME_BASE := 220.0
const INCOME_EXP := 1.15
const MOB_SHARE := 0.45
const BOSS_SHARE := 0.25
const CHEST_SHARE := 0.30
## 보스가 부른 졸개는 사냥터 몬스터 골드의 이만큼 (보스방에서 졸개만 잡아 버는 것 방지)
const SUMMON_RATIO := 0.15
## 한 마리 골드의 위아래 폭 (±)
const GOLD_SPREAD := 0.2
## 멀티플레이: 같이 하는 사람이 한 명 늘 때마다 떨어지는 골드 총량 + (먼저 주운 사람이 가짐 — 4명이면 2.8배를 나눔)
const PARTY_GOLD_PER_PLAYER := 0.6

## 장비 값 = 그 장비가 「제 실력」을 내는 스테이지(get_fit_stage)의 한 스테이지 수입 × 종류 비중 × 등급 비중
##   (× PRICE_MULT 2) 무기 하나 ≈ 2.8스테이지 수입, 방어구 · 장신구 하나 ≈ 1.4~1.6 — 등급 안에서 단계마다 5스테이지 간격이라
##   그 사이 수입으로는 주무기 + 방어구 한두 개 — 다 사기는 어렵고 골라서 (나머지는 몬스터 드랍 · 보물상자)
const PRICE_STAGES := {
	"sword": 1.4, "bow": 1.4, "staff": 1.4, "dagger": 1.2,
	"shield": 0.7, "helmet": 0.7, "armor": 0.8, "boots": 0.7,
	"bracelet": 0.8, "ring": 0.8, "pendant": 0.8,
}
## 일반 등급은 단계 간격이 1.5스테이지로 짧아서 값도 낮게
const COMMON_PRICE_MULT := 0.6
## 상점에 없는 드랍 전용 장비 (팔 때 값)
const DROP_ONLY_PRICE_MULT := 1.15
## 전체 값 올림 — 처음 플레이 테스트에서 엔딩 때 골드가 200만 넘게 남음 (판매가 비율은 그만큼 낮춰 파는 돈은 그대로)
const PRICE_MULT := 2.0


## 노멀 · 혼자 기준 스테이지 수입
static func stage_income(stage: int) -> float:
	return INCOME_BASE * pow(float(maxi(stage, 1)), INCOME_EXP)


## 사냥터 몬스터 한 마리 골드 (가운데 값, 노멀)
static func mob_gold(stage: int, kill_target: int) -> float:
	return stage_income(stage) * MOB_SHARE / float(maxi(kill_target, 1))


static func boss_gold(stage: int) -> float:
	return stage_income(stage) * BOSS_SHARE


## 보물상자 골드 (노멀 · 혼자, 무작위 폭 · 히든 3배 · 빈 상자 2배 적용 전)
static func chest_gold(stage: int) -> float:
	return stage_income(stage) * CHEST_SHARE


## 같이 하는 사람 수에 따른 골드 총량 배율
static func party_gold_multiplier(players: int) -> float:
	return 1.0 + PARTY_GOLD_PER_PLAYER * float(maxi(players, 1) - 1)


## 1000 이상은 10 단위, 10000 이상은 100 단위로 깔끔하게
static func nice_price(value: float) -> int:
	if value >= 10000.0:
		return roundi(value / 100.0) * 100
	if value >= 100.0:
		return roundi(value / 10.0) * 10
	return maxi(roundi(value), 1)


## 장비 값 (신화는 0 — 팔 수 없고 상점에도 없음)
static func item_price(category: String, rarity: int, fit_stage: int, in_shop: bool) -> int:
	if rarity >= ItemData.Rarity.MYTHIC:
		return 0
	var value := stage_income(fit_stage) * float(PRICE_STAGES.get(category, 0.8))
	if rarity == ItemData.Rarity.COMMON:
		value *= COMMON_PRICE_MULT
	if not in_shop:
		value *= DROP_ONLY_PRICE_MULT
	return nice_price(value * PRICE_MULT)


## 포션 값 = 그 포션이 풀리는 스테이지 수입 × 등급 비중 × POTION_PRICE_MULT
const POTION_PRICE_STAGES := {ItemData.Rarity.COMMON: 0.12, ItemData.Rarity.RARE: 0.08, ItemData.Rarity.EPIC: 0.06, ItemData.Rarity.LEGENDARY: 0.1}
const POTION_PRICE_MULT := 1.5


static func potion_price(rarity: int, unlock_stage: int) -> int:
	if not POTION_PRICE_STAGES.has(rarity):
		return 0
	return nice_price(stage_income(unlock_stage) * float(POTION_PRICE_STAGES[rarity]) * POTION_PRICE_MULT)
