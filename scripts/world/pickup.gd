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
## 멀티플레이: 가장 가까운 용사에게 끌려가고, 먼저 닿은 사람이 가짐 (방장 컴퓨터의 남의 용사가 주우면 그 사람에게 보냄).
## 인벤토리에서 버린 장비(dropped_by)는 버린 사람이 잠깐 다시 줍지 않음 — 동료가 주워 갈 수 있게.

enum Kind { GOLD, ITEM }

@export var gold_texture: Texture2D
@export var magnet_radius: float = 56.0
@export var magnet_speed: float = 260.0
## 드랍 직후 바로 먹히지 않도록 하는 지연 (흩뿌려지는 연출용)
@export var pickup_delay: float = 0.35

## 버린 사람이 다시 줍지 못하는 시간 (그 사람이 멀어졌다 오면 다시 주울 수 있음)
const DROP_OWNER_LOCK := 2.5

var kind: Kind = Kind.GOLD
## 인벤토리에서 버린 사람 (peer id, 0 이면 몬스터 드랍)
var dropped_by: int = 0
var _owner_lock: float = 0.0
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


## 인벤토리에서 버린 장비로 설정 (흩뿌려지지 않고 발밑에 떨어짐)
func setup_dropped(item_data: ItemData, by_peer: int) -> void:
	setup_item(item_data)
	dropped_by = by_peer
	_owner_lock = DROP_OWNER_LOCK


func _ready() -> void:
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	monitorable = false
	_delay_left = pickup_delay
	_anim_time = randf() * TAU
	_scatter_velocity = Vector2.from_angle(randf() * TAU) * randf_range(40.0, 90.0)
	if dropped_by != 0:
		_scatter_velocity *= 0.3

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

	_owner_lock = maxf(_owner_lock - delta, 0.0)
	var player := _nearest_collector()
	if player == null:
		return

	var to_player := player.global_position - global_position
	if to_player.length() < magnet_radius:
		var pull := 1.0 - to_player.length() / magnet_radius
		global_position += to_player.normalized() * magnet_speed * (0.3 + pull) * delta

	for body in get_overlapping_bodies():
		var collector := body as Player
		if collector != null and _can_collect(collector):
			_collect(collector)
			return


func _can_collect(player: Player) -> bool:
	if player.net_mode == Player.NetMode.MIRROR or player.is_net_dead():
		return false
	return not (_owner_lock > 0.0 and player.peer_id == dropped_by)


func _nearest_collector() -> Player:
	var best: Player = null
	var best_dist := INF
	for player in Player.get_all(get_tree()):
		if not _can_collect(player):
			continue
		var d := player.global_position.distance_squared_to(global_position)
		if d < best_dist:
			best_dist = d
			best = player
	return best


## 즉시 획득 (스테이지 이동 시 남은 전리품 자동 회수 등)
func collect() -> void:
	if _collected:
		return
	# 버린 장비는 버린 사람에게 되돌아감 (나가 버렸으면 방장에게)
	if dropped_by != 0 and dropped_by != Net.my_id() and Net.has_peer(dropped_by):
		_collected = true
		Net.grant_pickup(dropped_by, int(kind), gold_amount, String(item.id) if item != null else "")
		queue_free()
		return
	_collect(null)


func _collect(collector: Player) -> void:
	_collected = true
	if collector != null and collector.net_mode == Player.NetMode.PUPPET:
		Net.grant_pickup(collector.peer_id, int(kind), gold_amount, String(item.id) if item != null else "")
		var label := ("+%dG" % gold_amount) if kind == Kind.GOLD else (item.display_name if item != null else "")
		FloatingText.spawn(self, global_position, label, Color(1.0, 0.85, 0.3) if kind == Kind.GOLD else item.get_rarity_color(), kind == Kind.ITEM)
		queue_free()
		return
	Pickup.receive(kind, gold_amount, item)
	if kind == Kind.GOLD:
		FloatingText.spawn(self, global_position, "+%dG" % gold_amount, Color(1.0, 0.85, 0.3))
	elif item != null:
		FloatingText.spawn(self, global_position, item.display_name, item.get_rarity_color(), true)
	queue_free()


## 이 컴퓨터의 용사가 주운 것을 반영 (멀티플레이에서 방장이 보내 준 것도 여기로)
static func receive(pickup_kind: Kind, gold: int, picked: ItemData) -> void:
	match pickup_kind:
		Kind.GOLD:
			GameManager.add_gold(gold)
		Kind.ITEM:
			if picked == null:
				pass
			elif GameManager.add_item(picked):
				GameManager.show_notice("획득: %s  (I: 인벤토리에서 장착)" % picked.display_name, picked.get_rarity_color())
			else:
				var value := picked.get_sell_value()
				GameManager.add_gold(value)
				GameManager.show_notice("이미 가진 장비 %s → +%dG" % [picked.display_name, value], Color(1.0, 0.85, 0.3))
