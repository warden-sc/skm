class_name ShopKeeper
extends Area2D
## 월드에 서 있는 상인 NPC. 범위 안에서 [E] 를 누르면 상점 UI 를 엽니다.
## 실제 UI 는 ShopUI 가 GameManager.shop_open_requested 시그널을 받아서 띄웁니다.

@export var shop_name: String = "떠돌이 대장장이"
## 판매 목록 (ItemDB 의 무기/방패/투구 id). 등급에 따라 스테이지가 올라야 구매 가능해집니다.
@export var stock_ids: Array[StringName] = [
	&"iron_sword", &"flame_blade", &"holy_sword",
	&"hunter_bow", &"rapid_crossbow", &"windrunner_bow", &"solaris_bow",
	&"apprentice_staff", &"frost_staff", &"ignis_staff", &"arcana_staff",
	&"iron_shield", &"royal_aegis", &"colossus_bulwark",
	&"leather_cap", &"iron_helm", &"orc_warhelm", &"gatekeeper_horns",
]

var _player_inside: bool = false

@onready var _hint: Label = $Hint


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_hint.hide()


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside and event.is_action_pressed(&"interact"):
		# 같은 E 입력이 ShopUI 의 "닫기" 로 다시 처리되지 않도록 먼저 소비
		get_viewport().set_input_as_handled()
		GameManager.request_shop(shop_name, stock_ids)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = true
		_hint.show()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
		_hint.hide()
