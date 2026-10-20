class_name Room
extends Node2D
## 벽으로 둘러싸인 방 하나 (야영지 / 사냥터 / 보스방).
## 바닥 스프라이트와 벽(StaticBody2D + 충돌 4개 + 벽 그림)을 size 에 맞춰 코드로 만듭니다.
## 스테이지가 바뀌면 apply_theme() 로 바닥 텍스처와 벽 색을 바꿉니다.

@export var size: Vector2 = Vector2(960, 640)
@export var wall_thickness: float = 16.0
@export var floor_texture: Texture2D
@export var wall_texture: Texture2D
## 바닥 밝기 (보스방은 조금 어둡게)
@export var floor_tint: Color = Color.WHITE

var _floor: Sprite2D
var _walls: StaticBody2D


func _ready() -> void:
	_floor = Sprite2D.new()
	_floor.z_index = -10
	_floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_floor.region_enabled = true
	_floor.region_rect = Rect2(Vector2.ZERO, size)
	_floor.texture = floor_texture
	_floor.modulate = floor_tint
	add_child(_floor)

	_walls = StaticBody2D.new()
	_walls.collision_layer = Layers.WORLD
	_walls.collision_mask = 0
	add_child(_walls)
	var half := size * 0.5
	var t := wall_thickness
	_add_wall(Vector2(0, -half.y + t * 0.5), Vector2(size.x, t))
	_add_wall(Vector2(0, half.y - t * 0.5), Vector2(size.x, t))
	_add_wall(Vector2(-half.x + t * 0.5, 0), Vector2(t, size.y))
	_add_wall(Vector2(half.x - t * 0.5, 0), Vector2(t, size.y))


func apply_theme(new_floor: Texture2D, wall_tint: Color) -> void:
	Net.room_theme(self, new_floor, wall_tint)  # 멀티플레이: 참가자 화면의 방도 같은 모습으로
	if new_floor != null:
		_floor.texture = new_floor
	_walls.modulate = wall_tint


## 방 전체 영역 (카메라 경계용, 전역 좌표)
func get_bounds() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


## 벽 안쪽에서 margin 만큼 더 들어온 영역 (몬스터 이동/스폰용, 전역 좌표)
func get_arena_rect(margin: float = 24.0) -> Rect2:
	return get_bounds().grow(-(wall_thickness + margin))


func _add_wall(center: Vector2, wall_size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = wall_size
	shape.shape = rect
	shape.position = center
	_walls.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = wall_texture
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, wall_size)
	sprite.position = center
	_walls.add_child(sprite)
