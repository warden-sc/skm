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
