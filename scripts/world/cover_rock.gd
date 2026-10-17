class_name CoverRock
extends StaticBody2D
## 땅에 박힌 바위 (17스테이지 티탄 기믹): 티탄이 바닥을 내려찍으면 돌이 튀어 나와 경기장 곳곳에 박힙니다.
## - 벽처럼 플레이어 몸을 막고(WORLD 레이어), 티탄이 던진 바위(ThrownBoulder)를 대신 맞아 줍니다 → 뒤에 숨어 엄폐
## - 던진 바위를 hits 번 막으면 부서집니다.
## 스테이지가 바뀌면 StageManager 가 cover_rocks 그룹을 정리합니다.

const TEXTURE: Texture2D = preload("res://assets/sprites/characters/cover_rock.png")
const RADIUS := 11.0

var hits: int = 2


## at_global 에 바위가 박힘. from_global 이 있으면 그곳에서 포물선으로 날아와 박히는 연출
static func spawn(context: Node, at_global: Vector2, from_global: Vector2 = Vector2.INF) -> CoverRock:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var scene_root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var parent: Node = scene_root.get_node_or_null(^"Entities")
	if parent == null:
		parent = scene_root
	var rock := CoverRock.new()
	parent.add_child(rock)
	rock.global_position = at_global
	if from_global != Vector2.INF:
		rock.fly_in(from_global)
	return rock


func _ready() -> void:
	add_to_group(&"cover_rocks")
	collision_layer = Layers.WORLD
	collision_mask = 0
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = TEXTURE
	sprite.position = Vector2(0, -9)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	shape.position = Vector2(0, -5)
	add_child(shape)


## 판정 중심 (던진 바위와의 거리 계산용)
func get_center() -> Vector2:
	return global_position + Vector2(0, -7)


## 날아와 박히는 연출 (판정은 처음부터 제자리)
func fly_in(from_global: Vector2) -> void:
	var sprite := get_node(^"Sprite2D") as Sprite2D
	var start := from_global - global_position + Vector2(0, -9)
	sprite.position = start
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		sprite.position = start.lerp(Vector2(0, -9), t) + Vector2(0, -sin(t * PI) * 50.0), 0.0, 1.0, 0.5)
	tween.tween_callback(func() -> void:
		Fx.burst(self, global_position, Color(0.6, 0.55, 0.5), 10, 50.0, 0.35))


## 그 자리에서 무너짐 (바위가 너무 많을 때)
func crumble() -> void:
	hits = 1
	absorb_hit()


## 던진 바위를 대신 맞음. 부서지면 true
func absorb_hit() -> bool:
	hits -= 1
	Fx.burst(self, get_center(), Color(0.65, 0.6, 0.55), 12, 70.0, 0.4)
	if hits <= 0:
		remove_from_group(&"cover_rocks")
		queue_free()
		return true
	(get_node(^"Sprite2D") as Sprite2D).modulate = Color(0.8, 0.75, 0.7)
	return false
