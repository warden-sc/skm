class_name PoisonFog
extends Node2D
## 바실리스크의 독안개 (24스테이지 기믹): 보스방 가장자리부터 독안개가 점점 안쪽으로 차올라 결국 보스방 전체를 덮습니다.
## - 안전한 원(가운데)이 fill_time 동안 처음 크기에서 0 까지 줄어듦
## - 원 밖(안개 속)에 있으면 0.5초마다 독 (화상과 같은 지속 피해, 독에 걸리면 포션 회복량도 줄어듦)
## - recede() 로 안개가 걷힘 (독샘이 부서졌을 때)
## 판정은 거리 계산이라 물리 콜백 문제가 없습니다.

const TICK := 0.5

var area: Rect2 = Rect2()
var fill_time: float = 45.0
var poison_tick: int = 8
var _elapsed: float = 0.0
var _tick_left: float = TICK
var _max_radius: float = 1.0
var _receding: bool = false
var _recede_t: float = 0.0
var _radius_at_recede: float = 0.0


static func spawn(context: Node, arena: Rect2, time_to_fill: float, tick_damage: int) -> PoisonFog:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var fog := PoisonFog.new()
	fog.area = arena
	fog.fill_time = time_to_fill
	fog.poison_tick = tick_damage
	fog.z_index = 45
	fog.add_to_group(&"storm_fields")  # 스테이지가 바뀌면 함께 정리
	root.add_child(fog)
	fog.global_position = Vector2.ZERO
	return fog


func _ready() -> void:
	_max_radius = area.size.length() * 0.5 + 10.0


## 지금 안전한 원의 반지름
func get_safe_radius() -> float:
	if _receding:
		return lerpf(_radius_at_recede, _max_radius, clampf(_recede_t / 1.5, 0.0, 1.0))
	return _max_radius * clampf(1.0 - _elapsed / maxf(fill_time, 0.01), 0.0, 1.0)


## 안개가 덮은 비율 (0 ~ 1)
func get_coverage() -> float:
	return 1.0 - get_safe_radius() / _max_radius


func is_receding() -> bool:
	return _receding


func is_in_fog(point: Vector2) -> bool:
	return area.has_point(point) and point.distance_to(area.get_center()) > get_safe_radius()


## 안개를 지금 시점까지 진행시킴 (테스트용)
func advance(seconds: float) -> void:
	_elapsed += seconds


func recede() -> void:
	if _receding:
		return
	_radius_at_recede = get_safe_radius()
	_receding = true


func _physics_process(delta: float) -> void:
	if _receding:
		_recede_t += delta
		modulate.a = clampf(1.0 - _recede_t / 1.5, 0.0, 1.0)
		queue_redraw()
		if _recede_t >= 1.5:
			queue_free()
		return
	_elapsed += delta
	queue_redraw()
	_tick_left -= delta
	var tick_now := _tick_left <= 0.0
	if tick_now:
		_tick_left = TICK
	for player in Player.get_all(get_tree()):
		if not is_in_fog(player.global_position):
			continue
		player.mark_floor_status("독안개 속")
		if tick_now:
			player.apply_burn(poison_tick, 1.2, true)


func _draw() -> void:
	var c := area.get_center()
	var r := get_safe_radius()
	var outer := _max_radius + 20.0
	if r >= outer:
		return
	var width := outer - r
	var t := sin(_elapsed * 2.0) * 0.03
	draw_arc(c, r + width * 0.5, 0.0, TAU, 72, Color(0.35, 0.7, 0.2, 0.32 + t), width)
	draw_arc(c, r + 6.0, 0.0, TAU, 72, Color(0.5, 0.95, 0.3, 0.35), 12.0)
	draw_arc(c, r, 0.0, TAU, 72, Color(0.75, 1.0, 0.5, 0.8), 1.5)
