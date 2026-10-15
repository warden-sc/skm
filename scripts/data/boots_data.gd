class_name BootsData
extends ItemData
## 신발 데이터. 방패·투구·갑옷과 별개의 방어구 칸입니다.
## - defense     : 모든 피해에서 고정 수치 감소 (다른 방어구와 합산)
## - move_bonus  : 이동 속도 증가 (0.1 = +10%)
## - worn_texture: 플레이어 발에 겹쳐 그리는 그림 (player.png 와 같은 16x16 좌표)

@export_group("Boots")
@export var defense: int = 1
@export var move_bonus: float = 0.05
@export var worn_texture: Texture2D


func get_summary() -> String:
	return "신발 · 방어 %d · 이속 +%d%%" % [defense, roundi(move_bonus * 100.0)]


func get_stat_text() -> String:
	return "[%s] 신발\n방어력 %d  (모든 피해 감소)\n이동 속도 +%d%%" % [get_rarity_name(), defense, roundi(move_bonus * 100.0)]
