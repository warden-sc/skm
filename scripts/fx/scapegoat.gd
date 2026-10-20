class_name Scapegoat
extends Node2D
## 속죄양 (87스테이지 아자젤): 아자젤이 받을 피해를 대신 떠안는 검은 염소. 플레이어가 다가가면 반대쪽으로 달아남.
## 플레이어가 염소를 「광야의 문」까지 몰아내면 떠안은 피해가 아자젤에게 돌아감 (판정은 아자젤이).
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const TEXTURE: Texture2D = preload("res://assets/sprites/characters/scapegoat.png")
const FLEE_RANGE := 90.0
const FLEE_SPEED := 105.0
const HOME_SPEED := 30.0

var area: Rect2 = Rect2()
var home: Vector2 = Vector2.ZERO
var sins: int = 0
var _sprite: Sprite2D
var _label: Label


static func spawn(context: Node, at_global: Vector2, bounds: Rect2) -> Scapegoat:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var goat := Scapegoat.new()
	goat.area = bounds.grow(-16.0)
	goat.home = at_global
	parent.add_child(goat)
	goat.global_position = at_global
	Fx.burst(goat, at_global, Color(0.3, 0.25, 0.3), 14, 50.0, 0.5)
	return goat


func _ready() -> void:
	add_to_group(&"storm_fields")
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.scale = Vector2(1.3, 1.3)
	_sprite.position = Vector2(0, -10)
	add_child(_sprite)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.4))
	_label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.03, 0.03))
	_label.add_theme_constant_override(&"outline_size", 3)
	_label.position = Vector2(-30, -34)
	_label.size = Vector2(60, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func add_sins(amount: int) -> void:
	sins += amount
	_label.text = "죄 %d" % sins


func _physics_process(delta: float) -> void:
	var player := Player.find_nearest(get_tree(), global_position)
	var velocity := Vector2.ZERO
	if player != null and player.global_position.distance_to(global_position) < FLEE_RANGE:
		velocity = player.global_position.direction_to(global_position) * FLEE_SPEED
	elif global_position.distance_to(home) > 6.0:
		velocity = global_position.direction_to(home) * HOME_SPEED  # 쫓기지 않으면 아자젤 곁으로 돌아감
	global_position += velocity * delta
	if area.has_area():
		global_position = global_position.clamp(area.position, area.end)
	if absf(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0.0
