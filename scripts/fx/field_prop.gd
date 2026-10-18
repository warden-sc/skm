class_name FieldProp
extends Node2D
## 보스방에 놓이는 장식 겸 목적지 (아르고호 뱃머리 · 멜레아그로스의 화로 등). 판정은 보스가 거리로 직접 계산합니다.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

var texture: Texture2D
var _sprite: Sprite2D


static func spawn(context: Node, at_global: Vector2, prop_texture: Texture2D, glow: Color = Color(0, 0, 0, 0)) -> FieldProp:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var prop := FieldProp.new()
	prop.texture = prop_texture
	parent.add_child(prop)
	prop.global_position = at_global
	if glow.a > 0.0:
		var aura := Fx.make_aura(glow, 14, 8.0, Vector2(0, -60), 0.7)
		aura.position = Vector2(0, -10)
		prop.add_child(aura)
		aura.emitting = true
	return prop


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = -2
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.position = Vector2(0, -texture.get_height() * 0.5 if texture != null else 0.0)
	add_child(_sprite)
