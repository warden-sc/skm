class_name PuppetSwitch
extends Node2D
## 마리오네트 보스방 가장자리의 실 끊기 스위치 (18스테이지 기믹).
## 꼭두각시 조종이 시작되면 활성화되고, 플레이어가 밟으면 눌려 실이 하나 끊어집니다 (BossMarionette 가 처리).
## 조종이 끝나면 다시 올라와 다음 조종 때 또 쓸 수 있습니다.
## 스테이지가 바뀌면 StageManager 가 puppet_switches 그룹을 정리합니다.

signal pressed(switch: PuppetSwitch)

const OFF_TEXTURE: Texture2D = preload("res://assets/sprites/world/switch_off.png")
const ON_TEXTURE: Texture2D = preload("res://assets/sprites/world/switch_on.png")
const PRESS_RADIUS := 16.0

var active: bool = false
var is_pressed: bool = false
var _sprite: Sprite2D
var _time: float = 0.0


static func spawn(context: Node, at_global: Vector2) -> PuppetSwitch:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var sw := PuppetSwitch.new()
	sw.z_index = -4
	root.add_child(sw)
	sw.global_position = at_global
	return sw


func _ready() -> void:
	add_to_group(&"puppet_switches")
	_sprite = Sprite2D.new()
	_sprite.texture = OFF_TEXTURE
	_sprite.scale = Vector2.ONE * 1.5
	add_child(_sprite)


## 조종이 시작될 때 켜짐 (눌린 상태 초기화)
func activate() -> void:
	active = true
	is_pressed = false
	_sprite.texture = OFF_TEXTURE


func deactivate() -> void:
	active = false
	is_pressed = false
	_sprite.texture = OFF_TEXTURE


func press() -> void:
	if not active or is_pressed:
		return
	is_pressed = true
	_sprite.texture = ON_TEXTURE
	Fx.burst(self, global_position, Color(1.0, 0.9, 0.5), 14, 60.0, 0.4)
	pressed.emit(self)


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not active or is_pressed:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.global_position.distance_to(global_position) <= PRESS_RADIUS:
		press()


func _draw() -> void:
	if active and not is_pressed:
		var pulse := 0.5 + 0.5 * sin(_time * 8.0)
		draw_arc(Vector2.ZERO, 14.0 + pulse * 3.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.5 + 0.4 * pulse), 2.0)
