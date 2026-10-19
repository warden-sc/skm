class_name ArmorData
extends ItemData
## 갑옷 데이터. 방패·투구와 별개의 방어구 칸입니다.
## - defense      : 모든 피해에서 고정 수치 감소 (방패·투구 방어력과 합산)
## - bonus_max_hp : 최대 체력 증가
## - worn_texture : 플레이어 몸통에 겹쳐 그리는 그림 (player.png 와 같은 16x16 좌표)

@export_group("Defense")
@export var defense: int = 1
@export var bonus_max_hp: int = 15
@export var worn_texture: Texture2D


func get_summary() -> String:
	return "갑옷 · 방어 %d · HP +%d" % [defense, bonus_max_hp]


func get_stat_text() -> String:
	return "[%s] 갑옷\n방어력 %d  (모든 피해 감소)\n최대 체력 +%d" % [get_grade_text(), defense, bonus_max_hp]
