class_name DragonScale
extends Area2D
## 고대 용의 비늘 (히든 던전 이스터에그): 30~35스테이지 사냥터 구석에 하나씩 숨겨져 있음.
## 희미하게 반짝일 뿐 안내는 없음. 닿으면 주워짐 → 6개를 모두 모으면 35스테이지 보스 토벌 뒤 히든 던전이 열림.
## 위치는 스테이지마다 정해져 있음 (StageManager.get_dragon_scale_spot). 사냥터를 떠나면 dragon_scales 그룹으로 정리.

const TEXTURE: Texture2D = preload("res://assets/sprites/world/dragon_scale.png")

signal collected(scale: DragonScale)

var _time: float = 0.0
var _sprite: Sprite2D
var _taken: bool = false


func _ready() -> void:
	add_to_group(&"dragon_scales")
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.position = Vector2(0, -4)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	# 평소엔 거의 안 보이다가 가끔 반짝
	var glint := pow(maxf(sin(_time * 1.7), 0.0), 12.0)
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.28 + 0.72 * glint)
	_sprite.position.y = -4.0 + sin(_time * 2.0) * 1.0


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	collected.emit(self)
	Fx.burst(self, global_position, Color(1.0, 0.9, 0.55), 20, 60.0, 0.5)
	queue_free()
