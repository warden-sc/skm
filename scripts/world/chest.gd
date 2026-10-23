class_name Chest
extends Interactable
## 보스 처치 보상 상자. [E] 로 열면 opened 시그널 → StageManager 가 장비/골드를 쏟아냅니다.

signal opened(chest: Chest)

@export var closed_texture: Texture2D
@export var open_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite2D
var _glow: Sprite2D
var _is_opened: bool = false
var _time: float = 0.0


func _ready() -> void:
	super._ready()
	_glow = Sprite2D.new()
	_glow.texture = Fx.GLOW_TEXTURE
	_glow.material = Fx.additive_material()
	_glow.modulate = Color(1.0, 0.85, 0.4, 0.6)
	_glow.scale = Vector2(1.4, 1.0)
	_glow.position = _sprite.position
	_glow.show_behind_parent = true
	add_child(_glow)
	_sprite.texture = closed_texture
	# 등장 연출
	_sprite.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if not _is_opened:
		_glow.modulate.a = 0.45 + sin(_time * 4.0) * 0.2


func is_opened() -> bool:
	return _is_opened


func _interact() -> void:
	if _is_opened:
		return
	_is_opened = true
	set_enabled(false)
	_sprite.texture = open_texture
	Sfx.play(&"chest_open")
	_glow.modulate.a = 0.9
	create_tween().tween_property(_glow, "modulate:a", 0.0, 1.2)
	Fx.explosion(self, _sprite.global_position, Color(1.0, 0.85, 0.4), 30.0, 2, Vector2(0, -60))
	super._interact()
	opened.emit(self)
