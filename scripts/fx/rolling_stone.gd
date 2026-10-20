class_name RollingStone
extends Node2D
## 손대지 않고 뜨인 돌 (93스테이지 금 신상): warn_time 초 동안 굴러갈 길을 보여 준 뒤 from → to 로 굴러감.
## 닿은 플레이어는 피해, 길 위의 대상은 hit_callback(돌 위치) 로 보스가 직접 판정합니다.
## 스테이지가 바뀌면 storm_fields 그룹으로 정리.

var from: Vector2
var to: Vector2
var speed: float = 260.0
var warn_time: float = 2.5
var radius: float = 16.0
var damage: int = 100
var texture: Texture2D
var hit_callback: Callable
var _warn_left: float = 0.0
var _hit_player: bool = false
var _hit_players: Array[Player] = []
var _sprite: Sprite2D


static func spawn(context: Node, start: Vector2, end: Vector2, stone_texture: Texture2D, stone_damage: int, warn: float = 2.5) -> RollingStone:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var stone := RollingStone.new()
	stone.from = start
	stone.to = end
	stone.texture = stone_texture
	stone.damage = stone_damage
	stone.warn_time = warn
	parent.add_child(stone)
	stone.global_position = start
	return stone


func _ready() -> void:
	add_to_group(&"storm_fields")
	z_index = 1
	_warn_left = warn_time
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.position = Vector2(0, -10)
	_sprite.modulate.a = 0.35
	add_child(_sprite)


func is_rolling() -> bool:
	return _warn_left <= 0.0


func _physics_process(delta: float) -> void:
	if _warn_left > 0.0:
		_warn_left -= delta
		if _warn_left <= 0.0:
			_sprite.modulate.a = 1.0
		queue_redraw()
		return
	global_position = global_position.move_toward(to, speed * delta)
	_sprite.rotation += delta * 8.0 * signf(to.x - from.x + 0.01)
	for player in Player.get_all(get_tree()):
		if not _hit_players.has(player) and player.global_position.distance_to(global_position) < radius + 6.0:
			_hit_players.append(player)
			_hit_player = true
			player.take_hit(damage, global_position)
	if hit_callback.is_valid():
		hit_callback.call(global_position)
	queue_redraw()
	if global_position.distance_to(to) < 1.0:
		queue_free()


func _draw() -> void:
	if _warn_left > 0.0:
		var a := to_local(from)
		var b := to_local(to)
		var pulse := 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
		draw_line(a, b, Color(0.9, 0.85, 0.75, pulse * 0.5), radius * 2.0)
		draw_line(a, b, Color(1.0, 0.95, 0.85, pulse), 1.5)
