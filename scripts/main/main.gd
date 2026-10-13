extends Node2D
## 메인 씬 루트. 재시작 입력만 처리합니다.


func _ready() -> void:
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart") and GameManager.is_player_dead:
		GameManager.reset_game()
		get_tree().reload_current_scene()
