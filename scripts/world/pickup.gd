class_name Pickup
extends Area2D
## 몬스터 드랍 아이템 (골드 / 장비)
##
## 사용 순서 (StageManager):
##   var p := pickup_scene.instantiate() as Pickup
##   p.setup_gold(10)   또는   p.setup_item(item_data)   # 모든 장비 공통
##   entities.add_child(p)
##
## 플레이어가 가까이 오면 끌려가고(magnet), 닿으면 GameManager 에 반영됩니다.
## 이미 가진 장비를 주우면 판매가만큼 골드로 자동 환전됩니다.

enum Kind { GOLD, ITEM }

@export var gold_texture: Texture2D
@export var magnet_radius: float = 56.0
@export var magnet_speed: float = 260.0
## 드랍 직후 바로 먹히지 않도록 하는 지연 (흩뿌려지는 연출용)
@export var pickup_delay: float = 0.35

var kind: Kind = Kind.GOLD
var gold_amount: int = 0
var item: ItemData

var _delay_left: float = 0.0
var _scatter_velocity: Vector2 = Vector2.ZERO
var _anim_time: float = 0.0
var _collected: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


func setup_gold(amount: int) -> void:
	kind = Kind.GOLD
	gold_amount = maxi(amount, 1)


func setup_item(item_data: ItemData) -> void:
	kind = Kind.ITEM
	item = item_data


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	monitorable = false
	_delay_left = pickup_delay
	_anim_time = randf() * TAU
	_scatter_velocity = Vector2.from_angle(randf() * TAU) * randf_range(40.0, 90.0)

	if kind == Kind.ITEM and item != null:
		_sprite.texture = item.icon
		# 등급 색으로 은은하게 빛나도록
		var glow := create_tween().set_loops()
		glow.tween_property(_sprite, "self_modulate", item.get_rarity_color().lightened(0.3), 0.5)
		glow.tween_property(_sprite, "self_modulate", Color.WHITE, 0.5)
	else:
		_sprite.texture = gold_texture


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_anim_time += delta
	_delay_left -= delta

	# 흩뿌려짐 감속
	_scatter_velocity = _scatter_velocity.move_toward(Vector2.ZERO, 260.0 * delta)
	global_position += _scatter_velocity * delta

	# 둥실둥실
	_sprite.position.y = -6.0 + sin(_anim_time * 5.0) * 1.5

	if _delay_left > 0.0:
		return

	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or GameManager.is_player_dead:
		return

	var to_player := player.global_position - global_position
	if to_player.length() < magnet_radius:
		var pull := 1.0 - to_player.length() / magnet_radius
		global_position += to_player.normalized() * magnet_speed * (0.3 + pull) * delta

	for body in get_overlapping_bodies():
		if body is Player:
			_collect()
			return


## 즉시 획득 (스테이지 이동 시 남은 전리품 자동 회수 등)
func collect() -> void:
	if not _collected:
		_collect()


func _collect() -> void:
	_collected = true
	match kind:
		Kind.GOLD:
			GameManager.add_gold(gold_amount)
			FloatingText.spawn(self, global_position, "+%dG" % gold_amount, Color(1.0, 0.85, 0.3))
		Kind.ITEM:
			if item == null:
				pass
			elif GameManager.add_item(item):
				var hint := "I: 인벤토리에서 장착"
				GameManager.show_notice("획득: %s  (%s)" % [item.display_name, hint], item.get_rarity_color())
				FloatingText.spawn(self, global_position, item.display_name, item.get_rarity_color(), true)
			else:
				var value := item.get_sell_value()
				GameManager.add_gold(value)
				FloatingText.spawn(self, global_position, "중복 → +%dG" % value, Color(1.0, 0.85, 0.3))
	queue_free()
