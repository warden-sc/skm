class_name Interactable
extends Area2D
## 플레이어가 범위 안에서 [E](interact)를 누르면 반응하는 오브젝트의 공통 부모.
## 상인(ShopKeeper) / 텔레포트(Portal) / 보스문(BossGate) / 보물상자(Chest) 가 상속합니다.
##
## - 범위 안에 들어오면 머리 위에 prompt_text 안내가 뜹니다 (자식 "Hint" Label 이 없으면 자동 생성).
## - enabled 가 false 면 안내도, 상호작용도 하지 않습니다.
## - 자식 클래스는 _interact() 를 오버라이드하거나 interacted 시그널을 연결해서 씁니다.

signal interacted

@export var prompt_text: String = "[E] 상호작용"
@export var enabled: bool = true:
	set = set_enabled
## 안내 문구 위치 (오브젝트 기준)
@export var hint_offset: Vector2 = Vector2(0, -34)

var _player_inside: bool = false
var _hint: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_hint = get_node_or_null("Hint") as Label
	if _hint == null:
		_hint = _create_hint()
	_hint.text = prompt_text
	_refresh_hint()


func set_enabled(value: bool) -> void:
	enabled = value
	if is_node_ready():
		_refresh_hint()


func set_prompt(text: String) -> void:
	prompt_text = text
	if _hint != null:
		_hint.text = text


func is_player_inside() -> bool:
	return _player_inside


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _player_inside or GameManager.is_player_dead:
		return
	if event.is_action_pressed(&"interact"):
		# 같은 E 입력이 다른 곳(상점 닫기 등)에서 또 처리되지 않도록 먼저 소비
		get_viewport().set_input_as_handled()
		_interact()


## 자식 클래스에서 오버라이드 가능
func _interact() -> void:
	interacted.emit()


func _refresh_hint() -> void:
	if _hint != null:
		_hint.visible = enabled and _player_inside


func _create_hint() -> Label:
	var label := Label.new()
	label.name = "Hint"
	label.z_index = 50
	label.size = Vector2(120, 12)
	label.position = hint_offset - Vector2(60, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 8)
	label.add_theme_constant_override(&"outline_size", 3)
	label.add_theme_color_override(&"font_outline_color", Color(0.1, 0.1, 0.17))
	add_child(label)
	return label


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = true
		_refresh_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
		_refresh_hint()
