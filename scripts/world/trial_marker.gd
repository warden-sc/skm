class_name TrialMarker
extends Node2D
## 보스방 해방 시련의 자리 표시 (GateTrials 의 COLLECT · IGNITE).
##   COLLECT — 떠 있는 빛나는 조각. 용사가 닿으면 주워짐 (StageManager 가 판정하고 done 을 켬)
##   IGNITE  — 돌 받침 + 둘레 원. 원 안에 서 있으면 둘레 호가 차오르고, 다 차면 불이 켜짐 (불꽃 · 빛)
## 판정 · 진행은 StageManager 가 하고 여기는 그림만 — 멀티플레이 참가자 화면에는 변수째 복제됨 (NetVisual).

enum Kind { COLLECT, IGNITE }

const PICK_RADIUS := 14.0
const IGNITE_RADIUS := 20.0

var kind: int = Kind.COLLECT
var color: Color = Color(1.0, 0.9, 0.5)
## IGNITE: 0 ~ 1 (불 켜기까지)
var progress: float = 0.0
## 주워졌거나(COLLECT) 불이 켜짐(IGNITE)
var done: bool = false
var index: int = 0
var _time: float = 0.0


func _ready() -> void:
	z_index = -4 if kind == Kind.IGNITE else 0
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if kind == Kind.COLLECT:
		_draw_collect()
	else:
		_draw_ignite()


func _draw_collect() -> void:
	if done:
		return
	var bob := sin(_time * 3.0) * 2.5
	var c := Vector2(0, -8 + bob)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	draw_circle(Vector2(0, 2), 5.0, Color(0, 0, 0, 0.25))
	draw_circle(c, 9.0 + pulse * 2.0, Color(color, 0.12 + 0.08 * pulse))
	var pts := PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 0), c + Vector2(0, 6), c + Vector2(-4, 0)])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.08, 0.06, 0.9), 1.0)
	draw_line(c + Vector2(-1, -4), c + Vector2(1.5, -1), Color(1, 1, 1, 0.85), 1.0)
	for i in 3:
		var a := _time * 1.5 + TAU * i / 3.0
		draw_circle(c + Vector2.from_angle(a) * 8.0, 0.9, Color(color.lightened(0.5), 0.8))


func _draw_ignite() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * (5.0 if progress > 0.0 and not done else 2.0))
	if not done:
		draw_circle(Vector2.ZERO, IGNITE_RADIUS, Color(color, 0.05 + 0.04 * pulse))
		draw_arc(Vector2.ZERO, IGNITE_RADIUS, 0.0, TAU, 40, Color(color, 0.35 + 0.2 * pulse), 1.0)
		if progress > 0.0:
			draw_arc(Vector2.ZERO, IGNITE_RADIUS - 2.5, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0), 40, Color(color.lightened(0.4), 0.95), 2.5)
	# 돌 받침
	draw_rect(Rect2(-6, -6, 12, 8), Color(0.32, 0.3, 0.34))
	draw_rect(Rect2(-6, -6, 12, 8), Color(0.08, 0.07, 0.08), false, 1.0)
	draw_rect(Rect2(-4, -9, 8, 3), Color(0.42, 0.4, 0.44))
	if done:
		# 불이 켜짐: 빛 + 흔들리는 불꽃
		draw_circle(Vector2(0, -14), 16.0 + pulse * 3.0, Color(color, 0.12))
		var flick := sin(_time * 13.0) * 1.2
		var flame := PackedVector2Array([Vector2(-4, -9), Vector2(-2 + flick, -17), Vector2(0, -23 + flick), Vector2(2 + flick, -17), Vector2(4, -9)])
		draw_colored_polygon(flame, color)
		var core := PackedVector2Array([Vector2(-2, -9), Vector2(0, -17 + flick), Vector2(2, -9)])
		draw_colored_polygon(core, Color(1, 1, 0.9, 0.95))
	else:
		draw_circle(Vector2(0, -10), 1.5, Color(color, 0.4 + 0.4 * pulse))
