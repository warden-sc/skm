extends Node2D
## 메인 씬 루트. 사망 후 재시작 / 타이틀 복귀 입력, ESC 설정창(PauseMenu), 튜토리얼(TutorialDirector)을 붙입니다.

const TITLE_SCENE := "res://scenes/title/title.tscn"

var pause_menu: PauseMenu
var tutorial: TutorialDirector


func _ready() -> void:
	get_tree().paused = false
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	if GameManager.tutorial_mode:
		tutorial = TutorialDirector.new()
		tutorial.name = "Tutorial"
		tutorial.player = get_node_or_null(^"Entities/Player") as Player
		add_child(tutorial)
		pause_menu.tutorial_skip_requested.connect(tutorial.finish)
	if Net.is_online() and Net.in_game:
		Net.bind_main(self)


func _unhandled_input(event: InputEvent) -> void:
	if Net.is_client() and event.is_action_pressed(&"interact") and not Net.ui_blocks_input() and not get_tree().paused:
		if Net.client_interact():
			get_viewport().set_input_as_handled()
		return
	if not GameManager.is_player_dead or Net.is_online():
		return  # 멀티플레이: 쓰러지면 동료를 기다림 (모두 쓰러지면 야영지에서 다 같이 부활)
	if event.is_action_pressed(&"restart"):
		GameManager.reset_game()  # 같은 난이도로 1스테이지부터 (튜토리얼이면 튜토리얼 처음부터)
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"to_title"):
		GameManager.tutorial_mode = false
		GameManager.reset_game()
		get_tree().change_scene_to_file(TITLE_SCENE)
