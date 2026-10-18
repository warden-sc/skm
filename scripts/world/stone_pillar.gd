class_name StonePillar
extends CoverRock
## 테라곤(32스테이지)이 솟아오르게 한 돌기둥. 엄폐 바위처럼 몸과 탄을 막고,
## 테라곤이 돌진하다 부딪히면 부서지며 테라곤이 기절합니다.

const PILLAR_TEXTURE: Texture2D = preload("res://assets/sprites/characters/stone_pillar.png")


static func raise(context: Node, at_global: Vector2) -> StonePillar:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var pillar := StonePillar.new()
	pillar.hits = 3
	parent.add_child(pillar)
	pillar.global_position = at_global
	Fx.burst(pillar, at_global, Color(0.6, 0.5, 0.4), 16, 60.0, 0.4, Vector2(0, 80))
	return pillar


func _ready() -> void:
	super._ready()
	add_to_group(&"stone_pillars")
	var sprite := get_node(^"Sprite2D") as Sprite2D
	sprite.texture = PILLAR_TEXTURE
	sprite.position = Vector2(0, -19)
	sprite.scale = Vector2(1.4, 0.3)
	create_tween().tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.25)
