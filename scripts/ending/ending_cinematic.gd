class_name EndingCinematic
extends Control
## 엔딩 첫 장면 (상인 · 멀티버스의 주인을 쓰러뜨린 뒤) — 전부 직접 그림, 아무 키나 누르면 건너뜀(Ending 이 처리).
##   1 귀환   : 하늘의 포탈들로 각 세계(빛 구슬)가 원래 있던 곳으로 돌아감
##   2 안정화 : 하늘을 가르던 멀티버스의 균열이 하나둘 아물고 하늘빛이 차분해짐
##   3 닫힘   : 세계와 이어진 포탈이 하나씩 닫힘
##   4 새 관리자 : 어둠 속 빈 관리자의 자리(옥좌)에 누군가 앉음 — 두 눈이 빛남
##   5 다시 열림 : 닫혔던 포탈이 붉은빛으로 하나씩 다시 열림

signal finished

## 장면별 [시작 초, 끝 초, 자막]
const PHASES := [
	[0.0, 5.0, "쓰러진 상인의 손에서, 백 개의 세계를 묶던 사슬이 풀려 나갔다.\n세계들은 하나둘 원래 있던 곳으로 돌아갔다."],
	[5.0, 9.0, "찢어졌던 멀티버스의 균열이 하나둘 아물고,"],
	[9.0, 12.5, "세계와 세계를 잇던 문들이 조용히 닫혔다."],
	[12.5, 17.0, "…그리고 비어 있던 관리자의 자리에,\n누군가가 앉았다."],
	[17.0, 21.0, "닫혔던 문이 다시, 하나둘 열리기 시작했다."],
]
const DURATION := 22.5
const PORTALS := 9
const WORLD_COLORS := [
	Color(0.55, 1.0, 0.5), Color(1.0, 0.45, 0.25), Color(0.5, 0.85, 1.0), Color(0.85, 0.6, 1.0), Color(1.0, 0.9, 0.45),
	Color(0.45, 1.0, 0.85), Color(1.0, 0.55, 0.75), Color(0.75, 0.75, 0.85), Color(1.0, 0.98, 0.85),
]

var time: float = 0.0
var _done: bool = false
var _caption: Label
var _rng := RandomNumberGenerator.new()
var _cracks: Array = []   # [[점들], 아무는 시각]
var _stars: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 2025
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -70.0
	_caption.offset_bottom = -24.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override(&"font_size", 12)
	_caption.add_theme_constant_override(&"outline_size", 4)
	_caption.add_theme_color_override(&"font_outline_color", Color(0.02, 0.02, 0.05))
	add_child(_caption)
	for i in 90:
		_stars.append([Vector2(_rng.randf(), _rng.randf() * 0.8), _rng.randf_range(0.4, 1.2), _rng.randf() * TAU])
	for i in 6:
		var pts := PackedVector2Array()
		var p := Vector2(_rng.randf_range(0.05, 0.95), _rng.randf_range(0.05, 0.25))
		for k in 7:
			pts.append(p)
			p += Vector2(_rng.randf_range(-0.07, 0.07), _rng.randf_range(0.05, 0.1))
		_cracks.append([pts, 5.3 + i * 0.55])


func _process(delta: float) -> void:
	if _done:
		return
	time += delta
	_update_caption()
	queue_redraw()
	if time >= DURATION:
		finish()


## 지금 장면 번호 (0~4, 끝나면 5)
func phase() -> int:
	for i in PHASES.size():
		if time < PHASES[i][1]:
			return i
	return PHASES.size()


func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func is_done() -> bool:
	return _done


func _update_caption() -> void:
	var p := phase()
	if p >= PHASES.size():
		_caption.modulate.a = maxf(0.0, 1.0 - (time - PHASES[-1][1]) / 0.8)
		return
	var start: float = PHASES[p][0]
	var end: float = PHASES[p][1]
	_caption.text = PHASES[p][2]
	_caption.modulate.a = clampf(minf(time - start, end - time) / 0.6, 0.0, 1.0)
	_caption.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.65) if p == 4 else Color(1.0, 0.95, 0.85))


func _portal_pos(i: int) -> Vector2:
	var a := PI + PI * (float(i) + 0.5) / PORTALS
	return size * Vector2(0.5, 0.62) + Vector2(cos(a) * size.x * 0.42, sin(a) * size.y * 0.42)


## 포탈 크기 (0 = 닫힘, 1 = 열림) · 다시 열린 포탈은 붉은빛
func _portal_open(i: int) -> float:
	var close_at := 9.0 + i * 0.3
	var reopen_at := 17.3 + i * 0.35
	if time < close_at:
		return clampf(time / 0.8, 0.0, 1.0)
	if time < reopen_at:
		return clampf(1.0 - (time - close_at) / 0.6, 0.0, 1.0)
	return clampf((time - reopen_at) / 0.7, 0.0, 1.0)


func _draw() -> void:
	var calm := clampf((time - 5.0) / 4.0, 0.0, 1.0)      # 균열이 아물며 하늘이 차분해짐
	var dark := clampf((time - 11.5) / 1.5, 0.0, 1.0) * (1.0 - clampf((time - 18.0) / 3.0, 0.0, 0.6))
	var sky := Color(0.18, 0.06, 0.24).lerp(Color(0.05, 0.08, 0.18), calm).lerp(Color(0.01, 0.01, 0.02), dark)
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	for s in _stars:
		var tw := 0.5 + 0.5 * sin(time * 2.0 + float(s[2]))
		draw_circle(size * (s[0] as Vector2), float(s[1]), Color(1, 1, 1, (0.25 + 0.5 * tw) * (1.0 - dark * 0.7)))
	_draw_cracks()
	for i in PORTALS:
		_draw_portal(i)
	_draw_returning_worlds()
	_draw_throne()


## 균열: 처음엔 보라빛으로 일렁이다가 순서대로 아물어 사라짐
func _draw_cracks() -> void:
	for crack in _cracks:
		var heal_at: float = crack[1]
		var a := 1.0 - clampf((time - heal_at) / 0.8, 0.0, 1.0)
		if a <= 0.0:
			continue
		var pts := PackedVector2Array()
		for p in (crack[0] as PackedVector2Array):
			pts.append(p * size)
		var glow := 0.6 + 0.4 * sin(time * 9.0)
		draw_polyline(pts, Color(0.85, 0.4, 1.0, 0.35 * a * glow), 6.0)
		draw_polyline(pts, Color(1.0, 0.85, 1.0, 0.9 * a), 1.5)
		if time > heal_at and a > 0.0:
			for p in pts:
				draw_circle(p, 3.0 * a, Color(0.7, 0.95, 1.0, 0.6 * a))


func _draw_portal(i: int) -> void:
	var open := _portal_open(i)
	if open <= 0.01:
		return
	var reopened := time >= 17.3 + i * 0.35
	var c: Color = Color(1.0, 0.25, 0.3) if reopened else WORLD_COLORS[i % WORLD_COLORS.size()]
	var at := _portal_pos(i)
	var r := 16.0 * open
	var spin := time * (2.0 if not reopened else 3.5)
	draw_circle(at, r * 1.8, Color(c, 0.12))
	draw_circle(at, r, Color(0.02, 0.02, 0.05, 0.9))
	for k in 3:
		draw_arc(at, r - k * 3.0, spin + k, spin + k + PI * 1.4, 20, Color(c, 0.8 - k * 0.2), 2.0)


## 1장면: 각 세계(빛 구슬)가 가운데서 제 포탈로 날아가 들어감
func _draw_returning_worlds() -> void:
	if time > 6.0:
		return
	var center := size * Vector2(0.5, 0.62)
	for i in PORTALS:
		var start := 0.6 + i * 0.4
		var t := clampf((time - start) / 1.6, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var target := _portal_pos(i)
		var e := t * t * (3.0 - 2.0 * t)
		var p := center.lerp(target, e) + Vector2(0, -sin(t * PI) * 30.0)
		var c: Color = WORLD_COLORS[i % WORLD_COLORS.size()]
		for k in 5:
			var tail := center.lerp(target, maxf(e - k * 0.04, 0.0)) + Vector2(0, -sin(maxf(t - k * 0.03, 0.0) * PI) * 30.0)
			draw_circle(tail, 5.0 - k, Color(c, 0.5 - k * 0.09))
		draw_circle(p, 6.0, c)
		draw_circle(p, 3.0, Color(1, 1, 1, 0.9))


## 4장면: 어둠 속 빈 관리자의 자리 → 그림자가 앉고 두 눈이 빛남
func _draw_throne() -> void:
	var appear := clampf((time - 12.5) / 1.2, 0.0, 1.0)
	if appear <= 0.0:
		return
	var base := size * Vector2(0.5, 0.66)
	var stone := Color(0.25, 0.22, 0.3, appear)
	var edge := Color(0.75, 0.6, 1.0, 0.5 * appear)
	# 옥좌
	draw_rect(Rect2(base + Vector2(-30, -70), Vector2(60, 70)), stone)
	draw_rect(Rect2(base + Vector2(-38, -10), Vector2(76, 14)), stone)
	draw_rect(Rect2(base + Vector2(-30, -70), Vector2(60, 70)), edge, false, 1.5)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-30, -70), base + Vector2(0, -92), base + Vector2(30, -70)]), stone)
	draw_circle(base + Vector2(0, -78), 5.0, Color(0.85, 0.65, 1.0, 0.7 * appear))
	# 앉는 그림자
	var sit := clampf((time - 14.0) / 1.2, 0.0, 1.0)
	if sit > 0.0:
		var drop := (1.0 - sit) * -24.0
		var body := Color(0.02, 0.01, 0.04, sit)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-16, -8 + drop), base + Vector2(-12, -46 + drop), base + Vector2(12, -46 + drop), base + Vector2(16, -8 + drop)]), body)
		draw_circle(base + Vector2(0, -54 + drop), 9.0, body)
		var eyes := clampf((time - 15.4) / 0.4, 0.0, 1.0)
		if eyes > 0.0:
			var flick := 0.7 + 0.3 * sin(time * 7.0)
			for x in [-3.5, 3.5]:
				draw_circle(base + Vector2(x, -55 + drop), 1.6, Color(1.0, 0.25, 0.3, eyes * flick))
				draw_circle(base + Vector2(x, -55 + drop), 5.0, Color(1.0, 0.25, 0.3, 0.15 * eyes))
