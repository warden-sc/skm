class_name Tornado
extends Node2D
## 제피로스의 회오리 (31스테이지 기믹): 바람을 타고 떠돌며 천천히 플레이어 쪽으로 다가옵니다.
## 닿으면 휘말려(잠깐 조작 불가) 피해를 입고 멀리 내던져짐. 대시 중엔 통과. lifetime 뒤 흩어짐.

const RADIUS := 16.0

var damage: int = 60
var lifetime: float = 9.0
var speed: float = 34.0

var _age: float = 0.0
var _hit_cooldown: float = 0.0


static func spawn(context: Node, at_global: Vector2, hit_damage: int, life: float = 9.0) -> Tornado:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var t := Tornado.new()
	t.damage = hit_damage
	t.lifetime = life
	t.z_index = 4
	root.add_child(t)
	t.global_position = at_global
	return t


func _ready() -> void:
	add_to_group(&"storm_fields")
	add_to_group(&"tornadoes")


func _physics_process(delta: float) -> void:
	_age += delta
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	if _age >= lifetime:
		Fx.burst(self, global_position + Vector2(0, -14), Color(0.8, 1.0, 0.9), 14, 60.0, 0.4)
		queue_free()
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var drift := WindField.get_wind_at(global_position) * 0.12
	if player != null and not GameManager.is_player_dead:
		drift += global_position.direction_to(player.global_position) * speed
		# 이미 휘말려 있으면 다른 회오리가 겹쳐 때리지 않음 (두 개가 한꺼번에 들어오는 즉사 방지)
		if _hit_cooldown <= 0.0 and not player.is_dashing() and not player.is_charmed() and player.global_position.distance_to(global_position) <= RADIUS:
			_hit_cooldown = 1.2
			if player.take_unblockable_hit(Balance.scale(damage), global_position) == Player.HitResult.DAMAGED:
				player.apply_charm(0.7, null, "휘말림")
				player.velocity = global_position.direction_to(player.global_position).rotated(0.6) * 320.0
	global_position += drift * delta
	queue_redraw()


func _draw() -> void:
	var fade := clampf((lifetime - _age) / 0.6, 0.0, 1.0) * clampf(_age / 0.3, 0.0, 1.0)
	for i in 7:
		var y := -i * 5.0
		var w := 6.0 + i * 2.2
		var off := sin(_age * 9.0 + i * 0.9) * 2.5
		draw_arc(Vector2(off, y), w, 0.0, TAU, 14, Color(0.85, 1.0, 0.95, (0.55 - i * 0.05) * fade), 1.5)
	draw_circle(Vector2.ZERO, RADIUS * 0.8, Color(0.5, 0.7, 0.65, 0.15 * fade))
