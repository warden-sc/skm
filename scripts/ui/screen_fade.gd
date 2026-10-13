class_name ScreenFade
extends CanvasLayer
## 텔레포트할 때 화면을 잠깐 어둡게 했다가 밝히는 전환 효과.
## transition(callable): 어두워짐 → callable 실행(이동) → 밝아짐

@export var fade_time: float = 0.22

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 40
	_rect = ColorRect.new()
	_rect.color = Color(0.02, 0.02, 0.05, 1.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.modulate.a = 0.0
	add_child(_rect)


func is_busy() -> bool:
	return _busy


func transition(on_dark: Callable) -> void:
	if _busy:
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 1.0, fade_time)
	tween.tween_callback(on_dark)
	tween.tween_interval(0.08)
	tween.tween_property(_rect, "modulate:a", 0.0, fade_time)
	tween.tween_callback(func() -> void: _busy = false)
