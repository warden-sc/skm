class_name Brazier
extends Node2D
## 성화대 (41스테이지 히드라 기믹): 불이 붙어 있을 때 다가가면 무기에 「불꽃 부여」 → 잘린 히드라 목을 지질 수 있음.
## 히드라의 물줄기에 맞으면 꺼졌다가 relight_time 초 뒤 다시 붙음.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const TEXTURE_LIT: Texture2D = preload("res://assets/sprites/world/brazier_lit.png")
const TEXTURE_OUT: Texture2D = preload("res://assets/sprites/world/brazier_out.png")
const REACH := 24.0

var enchant_time: float = 10.0
var relight_time: float = 8.0
var lit: bool = true
var _relight_left: float = 0.0
var _sprite: Sprite2D
var _flame: CPUParticles2D


static func spawn(context: Node, at_global: Vector2) -> Brazier:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var brazier := Brazier.new()
	parent.add_child(brazier)
	brazier.global_position = at_global
	return brazier


func _ready() -> void:
	add_to_group(&"storm_fields")
	add_to_group(&"braziers")
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE_LIT
	_sprite.position = Vector2(0, -12)
	add_child(_sprite)
	_flame = Fx.make_aura(Color(1.0, 0.55, 0.15), 18, 5.0, Vector2(0, -70), 0.6)
	_flame.position = Vector2(0, -22)
	add_child(_flame)
	_flame.emitting = true


func douse() -> void:
	if not lit:
		return
	lit = false
	_relight_left = relight_time
	_sprite.texture = TEXTURE_OUT
	_flame.emitting = false
	Fx.burst(self, global_position + Vector2(0, -20), Color(0.8, 0.9, 1.0), 16, 50.0, 0.6, Vector2(0, -50))


func relight() -> void:
	lit = true
	_relight_left = 0.0
	_sprite.texture = TEXTURE_LIT
	_flame.emitting = true


func _physics_process(delta: float) -> void:
	if not lit:
		_relight_left -= delta
		if _relight_left <= 0.0:
			relight()
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.global_position.distance_to(global_position) <= REACH:
		player.apply_fire_enchant(enchant_time)
