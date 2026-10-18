class_name Whirlpool
extends Node2D
## 카립디스의 소용돌이 (44스테이지 기믹): 보스방 한가운데에서 플레이어를 빨아들임.
## - 평소엔 약하게, swallow(time) 동안은 강하게 끌어당김
## - 중심(core_radius) 안에 있으면 0.5초마다 최대 체력의 core_ratio 피해 (가드·대시 불가)
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

var radius: float = 230.0
var core_radius: float = 34.0
var calm_pull: float = 26.0
var swallow_pull: float = 85.0
var core_ratio: float = 0.08
var _swallow_left: float = 0.0
var _tick: float = 0.0
var _time: float = 0.0
var core_hits: int = 0


static func spawn(context: Node, at_global: Vector2) -> Whirlpool:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var pool := Whirlpool.new()
	pool.z_index = -5
	root.add_child(pool)
	pool.global_position = at_global
	return pool


func _ready() -> void:
	add_to_group(&"storm_fields")


func swallow(time: float) -> void:
	_swallow_left = time


func is_swallowing() -> bool:
	return _swallow_left > 0.0


func in_core(point: Vector2) -> bool:
	return point.distance_to(global_position) <= core_radius


func _physics_process(delta: float) -> void:
	_time += delta
	_swallow_left = maxf(_swallow_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and not GameManager.is_player_dead:
		var to_center := player.global_position - global_position
		var dist := to_center.length()
		if dist < radius and dist > 2.0 and not player.is_dashing():
			var strength := (swallow_pull if is_swallowing() else calm_pull) * (1.0 - dist / radius * 0.5)
			player.apply_push(-to_center.normalized() * strength)
		_tick -= delta
		if in_core(player.global_position) and _tick <= 0.0:
			_tick = 0.5
			if player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * core_ratio)), global_position, false) == Player.HitResult.DAMAGED:
				core_hits += 1
	queue_redraw()


func _draw() -> void:
	var spin := _time * (4.0 if is_swallowing() else 1.6)
	draw_circle(Vector2.ZERO, radius * 0.55, Color(0.1, 0.3, 0.45, 0.25))
	for i in 5:
		var r := radius * (0.12 + 0.11 * i)
		draw_arc(Vector2.ZERO, r, spin + i, spin + i + PI * 1.4, 28, Color(0.6, 0.85, 1.0, 0.5 - i * 0.07), 2.0)
	draw_circle(Vector2.ZERO, core_radius, Color(0.02, 0.06, 0.12, 0.85))
	draw_arc(Vector2.ZERO, core_radius, 0.0, TAU, 24, Color(0.8, 0.95, 1.0, 0.7), 1.5)
