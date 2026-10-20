class_name GoldenHind
extends Node2D
## 아르테미스의 황금 사슴 (55스테이지 알로아다이 기믹): 플레이어가 다가가면 반대쪽으로 달아나고, 아니면 천천히 거닒.
## 플레이어가 사슴을 거인 형제 사이로 몰아넣으면 형제가 사슴을 노린 창으로 서로를 찌릅니다 (판정은 보스가).
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

const TEXTURE: Texture2D = preload("res://assets/sprites/characters/golden_hind.png")
const FLEE_RANGE := 100.0
const FLEE_SPEED := 120.0
const WANDER_SPEED := 22.0

var area: Rect2 = Rect2()
var _wander_dir: Vector2 = Vector2.RIGHT
var _wander_left: float = 0.0
var _sprite: Sprite2D


static func spawn(context: Node, at_global: Vector2, bounds: Rect2) -> GoldenHind:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var hind := GoldenHind.new()
	hind.area = bounds.grow(-24.0)
	parent.add_child(hind)
	hind.global_position = at_global
	Fx.burst(hind, at_global, Color(1.0, 0.9, 0.5), 14, 50.0, 0.6, Vector2(0, -40))
	return hind


func _ready() -> void:
	add_to_group(&"storm_fields")
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.position = Vector2(0, -9)
	add_child(_sprite)
	var aura := Fx.make_aura(Color(1.0, 0.9, 0.5), 6, 8.0, Vector2(0, -30), 0.6)
	aura.position = Vector2(0, -8)
	add_child(aura)
	aura.emitting = true


func _physics_process(delta: float) -> void:
	var player := Player.find_nearest(get_tree(), global_position)
	var velocity := Vector2.ZERO
	if player != null and player.global_position.distance_to(global_position) < FLEE_RANGE:
		velocity = player.global_position.direction_to(global_position) * FLEE_SPEED
	else:
		_wander_left -= delta
		if _wander_left <= 0.0:
			_wander_left = randf_range(1.0, 2.5)
			_wander_dir = Vector2.from_angle(randf() * TAU)
		velocity = _wander_dir * WANDER_SPEED
	global_position += velocity * delta
	if area.has_area():
		global_position = global_position.clamp(area.position, area.end)
	if absf(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0.0
	_sprite.position.y = -9.0 - absf(sin(Time.get_ticks_msec() * 0.012)) * (2.0 if velocity.length() > 60.0 else 0.5)
