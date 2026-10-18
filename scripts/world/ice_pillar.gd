class_name IcePillar
extends StaticBody2D
## 빙결의 여왕 보스방의 얼음 기둥 (26스테이지 기믹).
## - 벽처럼 플레이어 몸을 막음 (WORLD 레이어) → 눈보라가 부는 쪽을 등지고 기둥 뒤에 서면 바람을 피함
## - 여왕이 냉기를 쏘면 기둥이 사방으로 얼음 파편을 반사함 (BossGlacia 가 처리)
## 스테이지가 바뀌면 StageManager 가 ice_pillars 그룹을 정리합니다.

const TEXTURE: Texture2D = preload("res://assets/sprites/characters/ice_pillar.png")


static func spawn(context: Node, at_global: Vector2) -> IcePillar:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var pillar := IcePillar.new()
	parent.add_child(pillar)
	pillar.global_position = at_global
	return pillar


func _ready() -> void:
	add_to_group(&"ice_pillars")
	collision_layer = Layers.WORLD
	collision_mask = 0
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.scale = Vector2.ONE * 1.3
	sprite.position = Vector2(0, -19)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	shape.position = Vector2(0, -6)
	add_child(shape)


## 눈보라(바람 방향 wind)를 이 기둥이 막아 주는 자리인지
func shelters(point: Vector2, wind: Vector2) -> bool:
	var to := point - global_position
	var along := to.dot(wind.normalized())
	return along > 0.0 and along < 80.0 and absf(to.cross(wind.normalized())) < 18.0
