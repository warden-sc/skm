class_name TargetRing
extends Node2D
## 지팡이 영창 중 조준한 곳에 그려지는 범위 표시 원.
## 터질 위치와 범위를 미리 보여 줘서 범위 공격임을 알 수 있게 합니다.
## Player 가 코드로 만들어 자식으로 두며, top_level 이라 플레이어를 따라 움직이지 않습니다.

var radius: float = 24.0
var color: Color = Color.WHITE
## 영창 진행도 0~1 (원이 차오름)
var progress: float = 0.0

var _time: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = -4
	hide()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color, 0.07 + 0.08 * progress))
	draw_circle(Vector2.ZERO, radius * progress, Color(color, 0.12))
	# 돌아가는 점선 테두리
	var segments := 16
	for i in segments:
		var a := TAU * float(i) / float(segments) + _time * 1.5
		draw_arc(Vector2.ZERO, radius, a, a + TAU / float(segments) * 0.6, 4, Color(color.lightened(0.3), 0.45 + 0.45 * progress), 1.0)
	draw_line(Vector2(-3, 0), Vector2(3, 0), Color(color.lightened(0.5), 0.8), 1.0)
	draw_line(Vector2(0, -3), Vector2(0, 3), Color(color.lightened(0.5), 0.8), 1.0)
