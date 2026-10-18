class_name JudgementScale
extends Node2D
## 세라핀의 「천칭」 (36스테이지 기믹): 보스방을 왼쪽·오른쪽으로 나눠, 플레이어가 각 쪽에서 준 피해를 저울에 올립니다.
## - 보스방 위쪽에 천칭(두 접시 + 기울어진 막대)을 그림
## - warn(side, time): 그쪽 절반이 붉게 깜빡임 (심판 예고) → 판정은 BossSeraphine 이 is_in_side() 로
## 스테이지가 바뀌면 StageManager 가 storm_fields 그룹을 정리합니다.

enum Side { LEFT, RIGHT }

var area: Rect2 = Rect2()
var weights: Array[float] = [0.0, 0.0]
## 이만큼 차이가 나면 완전히 기울어짐 (그림용)
var limit: float = 1.0
var _warn_side: int = -1
var _warn_left: float = 0.0
var _warn_total: float = 1.0
var _time: float = 0.0
var _tilt: float = 0.0


static func spawn(context: Node, arena: Rect2, tilt_limit: float) -> JudgementScale:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var scale_node := JudgementScale.new()
	scale_node.area = arena
	scale_node.limit = maxf(tilt_limit, 1.0)
	scale_node.z_index = -4
	root.add_child(scale_node)
	scale_node.global_position = Vector2.ZERO
	return scale_node


func _ready() -> void:
	add_to_group(&"storm_fields")


func side_of(point: Vector2) -> int:
	return Side.LEFT if point.x < area.get_center().x else Side.RIGHT


func is_in_side(point: Vector2, side: int) -> bool:
	return side_of(point) == side


func add_weight(side: int, amount: float) -> void:
	weights[side] += amount


## 오른쪽이 무거우면 +, 왼쪽이 무거우면 - (limit 이 1)
func get_tilt() -> float:
	return clampf((weights[Side.RIGHT] - weights[Side.LEFT]) / limit, -1.0, 1.0)


func reset() -> void:
	weights = [0.0, 0.0]


func warn(side: int, time: float) -> void:
	_warn_side = side
	_warn_left = time
	_warn_total = maxf(time, 0.01)


func clear_warn() -> void:
	_warn_side = -1
	_warn_left = 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	_warn_left = maxf(_warn_left - delta, 0.0)
	_tilt = lerpf(_tilt, get_tilt(), minf(delta * 6.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var c := area.get_center()
	# 가운데 경계선
	for y in range(int(area.position.y), int(area.end.y), 8):
		draw_line(Vector2(c.x, y), Vector2(c.x, y + 4), Color(1.0, 0.95, 0.7, 0.25), 1.0)
	if _warn_left > 0.0 and _warn_side >= 0:
		var t := 1.0 - _warn_left / _warn_total
		var half := Rect2(area.position, Vector2(area.size.x * 0.5, area.size.y))
		if _warn_side == Side.RIGHT:
			half.position.x = c.x
		draw_rect(half, Color(1.0, 0.85, 0.3, 0.1 + 0.2 * absf(sin(_time * (6.0 + 14.0 * t)))))
	# 천칭 (보스방 위쪽 가운데)
	var top := Vector2(c.x, area.position.y + 22)
	draw_line(top + Vector2(0, -14), top + Vector2(0, 10), Color(0.95, 0.85, 0.5), 2.0)
	var arm := Vector2(46, 0).rotated(_tilt * 0.35)
	draw_line(top - arm, top + arm, Color(0.95, 0.85, 0.5), 2.0)
	for k in 2:
		var end := top - arm if k == 0 else top + arm
		draw_line(end, end + Vector2(-8, 10), Color(0.9, 0.8, 0.5, 0.8), 1.0)
		draw_line(end, end + Vector2(8, 10), Color(0.9, 0.8, 0.5, 0.8), 1.0)
		draw_arc(end + Vector2(0, 10), 9.0, 0.0, PI, 10, Color(1.0, 0.9, 0.55), 2.0)
