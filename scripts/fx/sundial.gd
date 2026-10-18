class_name Sundial
extends Node2D
## 아폴론의 해시계 (70스테이지): 보스방 위를 도는 태양과 돌기둥의 그림자.
## 태양 반대쪽으로 기둥 그림자가 길게 드리우고, 그림자 속은 햇빛을 피할 수 있음.
## 「정오」에는 그림자가 기둥 바로 아래(NOON_SHADE)로 줄어듦.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리 (기둥은 cover_rocks 로 따로 정리).

const SHADOW_LENGTH := 110.0
const SHADOW_HALF_WIDTH := 16.0
const NOON_SHADE := 26.0

var pillars: Array[StonePillar] = []
var sun_angle: float = 0.0
var noon: bool = false
var area: Rect2 = Rect2()


static func spawn(context: Node, bounds: Rect2, pillar_spots: Array) -> Sundial:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var dial := Sundial.new()
	dial.area = bounds
	parent.add_child(dial)
	dial.global_position = Vector2.ZERO
	for spot in pillar_spots:
		var pillar := StonePillar.raise(context, bounds.get_center() + spot)
		if pillar != null:
			pillar.hits = 999999  # 해시계 기둥은 부서지지 않음
			dial.pillars.append(pillar)
	return dial


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = -4


## 해가 있는 쪽 (보스방 가운데에서 해를 향하는 방향)
func sun_dir() -> Vector2:
	return Vector2.from_angle(sun_angle)


func is_in_shade(at: Vector2) -> bool:
	for p in pillars:
		if not is_instance_valid(p):
			continue
		var v := at - p.global_position
		if noon:
			if v.length() <= NOON_SHADE:
				return true
			continue
		var away := -sun_dir()
		var along := v.dot(away)
		var side := absf(v.cross(away))
		if along >= -8.0 and along <= SHADOW_LENGTH and side <= SHADOW_HALF_WIDTH:
			return true
	return false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var away := -sun_dir()
	for p in pillars:
		if not is_instance_valid(p):
			continue
		var base := p.global_position
		if noon:
			draw_circle(base, NOON_SHADE, Color(0.1, 0.08, 0.15, 0.45))
			continue
		var side := away.orthogonal() * SHADOW_HALF_WIDTH
		var tip := base + away * SHADOW_LENGTH
		draw_colored_polygon(PackedVector2Array([base + side, tip + side * 0.8, tip - side * 0.8, base - side]), Color(0.1, 0.08, 0.15, 0.4))
	# 태양: 보스방 가장자리를 도는 빛
	var sun := area.get_center() + sun_dir() * Vector2(area.size.x * 0.48, area.size.y * 0.46)
	draw_circle(sun, 10.0 if not noon else 16.0, Color(1.0, 0.85, 0.3, 0.9))
	draw_circle(sun, 16.0 if not noon else 26.0, Color(1.0, 0.9, 0.5, 0.25))
