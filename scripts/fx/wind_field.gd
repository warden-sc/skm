class_name WindField
extends Node2D
## 제피로스(31스테이지) · 아르케(히든)의 바람: 보스방 전체에 한 방향으로 바람이 붑니다.
## - 이 영역 안의 투사체(플레이어의 화살·마법, 적 탄 모두)는 바람 쪽으로 궤도가 휩니다 (속력은 그대로)
##   → Projectile 이 매 프레임 WindField.get_wind_at() 으로 물어봄
## - 플레이어도 바람에 조금 밀림 (apply_push)
## - set_wind() 로 방향·세기를 바꾸면 바람 줄기 그림이 그 방향으로 흐릅니다.
## 스테이지가 바뀌면 StageManager 가 storm_fields 그룹을 정리합니다.

## 지금 불고 있는 바람 (없으면 null). 투사체가 매 프레임 확인하므로 그룹 검색 대신 정적 참조를 씀
static var active: WindField

var area: Rect2 = Rect2()
var direction: Vector2 = Vector2.RIGHT
## 투사체를 휘게 하는 힘 (px/s²)
var strength: float = 260.0
## 플레이어를 미는 힘 (px/s)
var player_push: float = 22.0

var _streaks: Array[Vector2] = []
var _time: float = 0.0


static func spawn(context: Node, arena: Rect2) -> WindField:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var field := WindField.new()
	field.area = arena
	field.z_index = 5
	root.add_child(field)
	field.global_position = Vector2.ZERO
	return field


## pos 에서 투사체에 작용하는 바람 (가속도)
static func get_wind_at(pos: Vector2) -> Vector2:
	if active == null or not is_instance_valid(active) or not active.area.has_point(pos):
		return Vector2.ZERO
	return active.direction * active.strength


func _enter_tree() -> void:
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


func _ready() -> void:
	add_to_group(&"storm_fields")
	for i in 40:
		_streaks.append(Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)))


func set_wind(dir: Vector2, power: float = -1.0) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	if power >= 0.0:
		strength = power


## 화살표 문구 (안내용)
func get_arrow() -> String:
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	return arrows[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]


func _physics_process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and area.has_point(player.global_position) and not player.is_dashing():
		player.apply_push(direction * player_push)
	var flow := direction * (120.0 + strength * 0.3) * delta
	for i in _streaks.size():
		var p := _streaks[i] + flow
		if not area.grow(10.0).has_point(p):
			# 바람이 불어오는 쪽 가장자리에서 다시 시작
			p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)) - direction * minf(area.size.x, area.size.y) * 0.5
			p = p.clamp(area.position, area.end)
		_streaks[i] = p
	queue_redraw()


func _draw() -> void:
	var length := 10.0 + strength * 0.03
	for i in _streaks.size():
		var p := _streaks[i]
		var a := 0.18 + 0.12 * sin(_time * 3.0 + i)
		draw_line(p - direction * length, p, Color(0.85, 1.0, 0.95, a), 1.0)
