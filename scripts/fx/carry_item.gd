class_name CarryItem
extends Node2D
## 집어 들 수 있는 물건 (51~60스테이지 기믹): 스파르토이의 돌 · 콜키스의 황금 양털 · 멜레아그로스의 생명의 장작.
## 플레이어가 reach 안으로 다가가면 집어 듭니다 (한 번에 하나만).
##   follow_player = true  : 머리 위에 들고 다님 → 보스가 목적지(아르고호 · 화로)에 닿았는지 확인
##   follow_player = false : 집는 순간 picked_up 만 알리고 보스가 알아서 처리 (던지는 돌)
## 들고 있는 동안 피해를 입으면 떨어뜨리고 제자리(home)로 돌아갑니다.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

signal picked_up(item: CarryItem)
signal dropped(item: CarryItem)

const REACH := 16.0

var texture: Texture2D
var item_name: String = "물건"
var follow_player: bool = true
var home: Vector2 = Vector2.ZERO
var available: bool = true
var _carried: bool = false
var _hidden_left: float = 0.0
var _sprite: Sprite2D
var _glow: CPUParticles2D


static func spawn(context: Node, at_global: Vector2, item_texture: Texture2D, display_name: String, glow: Color = Color(1.0, 0.9, 0.5)) -> CarryItem:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var item := CarryItem.new()
	item.texture = item_texture
	item.item_name = display_name
	item.home = at_global
	parent.add_child(item)
	item.global_position = at_global
	item._glow.color = glow
	return item


## 던진 물건이 날아가는 연출 (판정 없음)
static func fly(context: Node, from: Vector2, to: Vector2, item_texture: Texture2D, duration: float = 0.35) -> void:
	if context == null or not context.is_inside_tree():
		return
	var s := Sprite2D.new()
	s.texture = item_texture
	s.z_index = 56
	context.get_tree().current_scene.add_child(s)
	s.global_position = from
	var tween := s.create_tween()
	tween.tween_property(s, "global_position", to, duration).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(s, "rotation", TAU, duration)
	tween.tween_callback(s.queue_free)


func _ready() -> void:
	add_to_group(&"storm_fields")
	add_to_group(&"carry_items")
	z_index = 4
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.position = Vector2(0, -6)
	add_child(_sprite)
	_glow = Fx.make_aura(Color(1.0, 0.9, 0.5), 6, 6.0, Vector2(0, -30), 0.6)
	_glow.position = Vector2(0, -6)
	add_child(_glow)
	_glow.emitting = true
	GameManager.player_damaged.connect(_on_player_damaged)


func is_carried() -> bool:
	return _carried


## 잠시 사라졌다가 seconds 뒤 제자리에 다시 나타남
func hide_for(seconds: float) -> void:
	_carried = false
	available = false
	visible = false
	_hidden_left = seconds
	global_position = home


func reappear(at_global: Vector2 = Vector2.INF) -> void:
	if at_global != Vector2.INF:
		home = at_global
	_hidden_left = 0.0
	available = true
	visible = true
	global_position = home
	Fx.burst(self, global_position, _glow.color, 10, 40.0, 0.5, Vector2(0, -40))


func drop(notice: bool = true) -> void:
	if not _carried:
		return
	_carried = false
	global_position = home
	if notice:
		var player := get_tree().get_first_node_in_group(&"player") as Player
		if player != null:
			FloatingText.spawn(player, player.global_position + Vector2(0, -28), "%s을(를) 떨어뜨렸다!" % item_name, Color(1.0, 0.6, 0.5), true)
	dropped.emit(self)


func _on_player_damaged(_amount: int) -> void:
	if _carried:
		drop()


func _physics_process(delta: float) -> void:
	if not available:
		_hidden_left -= delta
		if _hidden_left <= 0.0:
			reappear()
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	if _carried:
		global_position = player.global_position + Vector2(0, -26)
		return
	if player.global_position.distance_to(global_position) > REACH:
		return
	for other in get_tree().get_nodes_in_group(&"carry_items"):
		if other != self and (other as CarryItem).is_carried():
			return
	if follow_player:
		_carried = true
		FloatingText.spawn(player, player.global_position + Vector2(0, -28), "%s을(를) 들었다" % item_name, Color(1.0, 0.95, 0.6), true)
	picked_up.emit(self)
