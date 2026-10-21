class_name Spectator
extends Camera2D
## 멀티플레이에서 쓰러진 용사의 관전 카메라 (유령 모드).
## 살아 있는 동료를 따라다니며 보여 주고, [Q] / 마우스 휠 / 좌클릭으로 다른 동료로 바꿉니다.
## 동료가 보스를 쓰러뜨리고 다음 스테이지 야영지에 도착하면 부활 → 이 카메라는 사라지고 내 카메라로 돌아감.
## 모두 쓰러지면(전멸) 게임 오버 — 그대로 남아 마지막 장면을 보여 줌.

## Callable() -> Array: [[이름, Node2D], …] 살아 있는 동료 목록 (Net 이 줌)
var candidates: Callable
var target_name: String = ""
## 방 경계(카메라 한계)를 따라 할 카메라 (내 용사의 카메라 — 순간이동하면 바뀜)
var limits_from: Camera2D

var _index: int = 0
var _target: Node2D
var _layer: CanvasLayer
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -240.0
	_label.offset_right = 240.0
	_label.offset_top = 96.0
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override(&"font_size", 10)
	_label.add_theme_color_override(&"font_color", Color(0.75, 0.88, 1.0))
	_label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.12))
	_label.add_theme_constant_override(&"outline_size", 4)
	_layer.add_child(_label)
	make_current()
	_pick(0)


## 지금 따라다니는 동료 (없으면 null)
func get_target() -> Node2D:
	return _target if _target != null and is_instance_valid(_target) else null


## 다음 / 이전 동료로
func cycle(step: int = 1) -> void:
	_pick(_index + step)


func _list() -> Array:
	return candidates.call() if candidates.is_valid() else []


func _pick(index: int) -> void:
	var list := _list()
	if list.is_empty():
		_target = null
		target_name = ""
		return
	_index = posmod(index, list.size())
	target_name = String(list[_index][0])
	_target = list[_index][1]
	if _target != null:
		global_position = _target.global_position
		reset_smoothing()


func _process(_delta: float) -> void:
	var target := get_target()
	var list := _list()
	# 따라다니던 동료가 쓰러지거나 사라지면 다른 동료로
	if target == null or not list.any(func(entry: Array) -> bool: return entry[1] == target):
		_pick(_index)
		target = get_target()
	if target != null:
		global_position = target.global_position
	if limits_from != null and is_instance_valid(limits_from):
		limit_left = limits_from.limit_left
		limit_top = limits_from.limit_top
		limit_right = limits_from.limit_right
		limit_bottom = limits_from.limit_bottom
	if Net.party_wiped:
		_label.text = ""
	elif target != null:
		_label.text = "유령 — 관전 중: %s   ([Q] · 휠 · 클릭: 다른 동료)\n동료가 보스를 쓰러뜨리면 다음 스테이지 야영지에서 장비 · 골드 그대로 부활합니다" % target_name
	else:
		_label.text = "유령 — 살아 있는 동료가 없습니다"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"weapon_next") or event.is_action_pressed(&"attack"):
		cycle(1)
	elif event.is_action_pressed(&"weapon_prev"):
		cycle(-1)
