class_name Sheep
extends Enemy
## 폴리페모스의 양 (42스테이지 기믹): 공격하지 않고 보스방을 어슬렁거림.
## 양 곁(HIDE_RADIUS)에 있으면 눈먼 폴리페모스가 플레이어의 소리를 듣지 못함.

const HIDE_RADIUS := 36.0

var _wander: Vector2 = Vector2.ZERO
var _wander_left: float = 0.0


func _ready() -> void:
	super._ready()
	collision_mask = 0  # 몸으로 부딪혀도 피해 없음
	add_to_group(&"sheep")


func hides(point: Vector2) -> bool:
	return point.distance_to(global_position) <= HIDE_RADIUS


func _get_move_velocity(delta: float) -> Vector2:
	_wander_left -= delta
	if _wander_left <= 0.0:
		_wander_left = randf_range(1.0, 2.5)
		_wander = Vector2.from_angle(randf() * TAU) * move_speed if randf() < 0.6 else Vector2.ZERO
	return _wander
