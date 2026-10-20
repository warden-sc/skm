extends Node
## 멀티플레이 통합 테스트 — 두 개의 Godot 를 띄워서 (방장 / 참가자) 127.0.0.1 로 연결해 확인합니다.
##   godot --headless --path . res://tests/net_test.tscn -- --host
##   godot --headless --path . res://tests/net_test.tscn -- --client
## 씬이 바뀌어도(로비 → 메인) 살아 있도록 /root/NetTestDriver 노드를 만들어 그쪽에서 진행합니다.


func _ready() -> void:
	var driver := Node.new()
	driver.name = "NetTestDriver"
	driver.set_script(load("res://tests/net_test_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
