class_name AbyssTorch
extends Node2D
## 심연의 군주 보스방의 횃불 (27스테이지 기믹). 처음엔 꺼져 있고, 플레이어가 밟으면 불이 붙어 주변이 밝아집니다.
## 녹스가 그림자 손으로 주기적으로 꺼 버립니다. 스테이지가 바뀌면 StageManager 가 abyss_torches 그룹을 정리합니다.

signal lit_changed(torch: AbyssTorch, lit: bool)

const OFF_TEXTURE: Texture2D = preload("res://assets/sprites/world/torch_off.png")
const ON_TEXTURE: Texture2D = preload("res://assets/sprites/world/torch_on.png")
const LIGHT_RADIUS := 95.0
const TOUCH_RADIUS := 18.0

var lit: bool = false
var _sprite: Sprite2D
var _flame: CPUParticles2D


static func spawn(context: Node, at_global: Vector2) -> AbyssTorch:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var t := AbyssTorch.new()
	t.z_index = 95  # 어둠 위로 보이도록
	root.add_child(t)
	t.global_position = at_global
	return t


func _ready() -> void:
	add_to_group(&"abyss_torches")
	_sprite = Sprite2D.new()
	_sprite.texture = OFF_TEXTURE
	_sprite.scale = Vector2.ONE * 1.5
	_sprite.position = Vector2(0, -16)
	add_child(_sprite)
	_flame = Fx.make_aura(Color(1.0, 0.6, 0.2), 10, 4.0, Vector2(0, -40), 0.5)
	_flame.position = Vector2(0, -24)
	add_child(_flame)
	_flame.emitting = false


func set_lit(value: bool) -> void:
	if lit == value:
		return
	lit = value
	_sprite.texture = ON_TEXTURE if lit else OFF_TEXTURE
	_flame.emitting = lit
	Fx.burst(self, global_position + Vector2(0, -20), Color(1.0, 0.6, 0.2) if lit else Color(0.3, 0.2, 0.4), 10, 40.0, 0.35)
	lit_changed.emit(self, lit)


func _physics_process(_delta: float) -> void:
	if lit:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.global_position.distance_to(global_position) <= TOUCH_RADIUS:
		set_lit(true)
