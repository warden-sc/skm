extends Node2D
## 메인 씬 루트. 사망 후 재시작 / 타이틀 복귀 입력만 처리합니다.

const TITLE_SCENE := "res://scenes/title/title.tscn"


func _ready() -> void:
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_player_dead:
		return
	if event.is_action_pressed(&"restart"):
		GameManager.reset_game()  # 같은 난이도로 1스테이지부터
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"to_title"):
		GameManager.reset_game()
		get_tree().change_scene_to_file(TITLE_SCENE)
