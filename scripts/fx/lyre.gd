class_name Lyre
extends Node2D
## 오르페우스의 리라 (43스테이지 케르베로스 기믹): 리라 곁에 서 있으면 연주가 쌓이고,
## 다 차면 song_finished → 케르베로스의 머리 하나가 잠듦. 그 뒤 cooldown 초 동안은 쉼.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

signal song_finished

const TEXTURE: Texture2D = preload("res://assets/sprites/world/lyre.png")
const REACH := 24.0

var play_time: float = 3.0
var cooldown: float = 5.0
var progress: float = 0.0
var _cool_left: float = 0.0
var _notes: CPUParticles2D
var _time: float = 0.0


static func spawn(context: Node, at_global: Vector2) -> Lyre:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var lyre := Lyre.new()
	parent.add_child(lyre)
	lyre.global_position = at_global
	return lyre


func _ready() -> void:
	add_to_group(&"storm_fields")
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.position = Vector2(0, -10)
	add_child(sprite)
	_notes = Fx.make_aura(Color(1.0, 0.9, 0.5), 8, 6.0, Vector2(0, -30), 1.0)
	_notes.position = Vector2(0, -20)
	add_child(_notes)


func is_ready() -> bool:
	return _cool_left <= 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	_cool_left = maxf(_cool_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var playing := is_ready() and player != null and player.global_position.distance_to(global_position) <= REACH
	_notes.emitting = playing
	if playing:
		progress += delta / play_time
		if progress >= 1.0:
			progress = 0.0
			_cool_left = cooldown
			song_finished.emit()
	else:
		progress = maxf(progress - delta * 0.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var col := Color(1.0, 0.9, 0.5) if is_ready() else Color(0.6, 0.6, 0.6)
	draw_arc(Vector2(0, -2), REACH, 0.0, TAU, 32, Color(col, 0.35), 1.0)
	if progress > 0.0:
		draw_arc(Vector2(0, -2), REACH, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, Color(1.0, 0.95, 0.6, 0.9), 2.5)
