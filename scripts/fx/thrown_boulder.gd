class_name ThrownBoulder
extends Node2D
## 티탄이 던지는 거대한 바위 (17스테이지 기믹).
##   1) warn_time 동안 티탄 손 위에서 들어 올린 채, 날아갈 길에 붉은 예고선
##   2) 일직선으로 날아감 — 땅에 박힌 바위(CoverRock)에 먼저 닿으면 그 바위가 대신 맞고 산산조각
##   3) 플레이어에게 닿으면 큰 피해 (방패로 막을 수 없음, 대시 중에는 통과)
## 판정은 거리 계산이라 물리 콜백 타이밍 문제가 없습니다.

const TEXTURE: Texture2D = preload("res://assets/sprites/projectiles/boulder.png")
const HIT_RADIUS := 13.0

var thrower: Enemy
var direction: Vector2 = Vector2.RIGHT
var speed: float = 240.0
var max_distance: float = 460.0
var warn_time: float = 0.9
## 맞으면 들어가는 피해 (방어력 무시 · 가드 불가)
var damage: int = 60

var _elapsed: float = 0.0
var _travelled: float = 0.0
var _sprite: Sprite2D
var _done: bool = false
var _hit_player: bool = false
var _blocked: bool = false


static func spawn(from: Enemy, at_global: Vector2, dir: Vector2, boulder_damage: int, warn: float = 0.9) -> ThrownBoulder:
	if from == null or not from.is_inside_tree():
		return null
	var tree := from.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var boulder := ThrownBoulder.new()
	boulder.thrower = from
	boulder.direction = dir.normalized()
	boulder.damage = boulder_damage
	boulder.warn_time = warn
	boulder.z_index = 20
	boulder.add_to_group(&"sky_strikes")  # 스테이지가 바뀌면 함께 정리
	root.add_child(boulder)
	boulder.global_position = at_global
	return boulder


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.scale = Vector2.ONE * 1.4
	add_child(_sprite)


func was_blocked() -> bool:
	return _blocked


func hit_player() -> bool:
	return _hit_player


func is_flying() -> bool:
	return _elapsed >= warn_time and not _done


func _physics_process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed < warn_time:
		_sprite.position = Vector2(0, -6.0 - sin(_elapsed * 20.0))
		return
	var step := speed * delta
	global_position += direction * step
	_travelled += step
	_sprite.rotation += delta * 9.0
	_sprite.position = Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"cover_rocks"):
		var rock := node as CoverRock
		if rock != null and rock.get_center().distance_to(global_position) <= CoverRock.RADIUS + HIT_RADIUS * 0.6:
			_blocked = true
			rock.absorb_hit()
			_shatter()
			return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and not player.is_dashing() and (player.global_position + Vector2(0, -5)).distance_to(global_position) <= HIT_RADIUS:
		_hit_player = true
		player.take_unblockable_hit(damage, global_position)
		_shatter()
		return
	if _travelled >= max_distance:
		_shatter()


func _shatter() -> void:
	_done = true
	Fx.explosion(self, global_position, Color(0.6, 0.55, 0.5), 22.0, 1, Vector2(0, 160))
	queue_free()


func _draw() -> void:
	if _elapsed >= warn_time:
		return
	var blink := 0.3 + 0.4 * absf(sin(_elapsed * 12.0))
	var end := direction * max_distance
	draw_line(Vector2.ZERO, end, Color(1.0, 0.35, 0.25, blink * 0.5), HIT_RADIUS * 2.0)
	draw_line(Vector2.ZERO, end, Color(1.0, 0.45, 0.3, blink), 1.0)
