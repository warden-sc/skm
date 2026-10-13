class_name Portal
extends Interactable
## 텔레포트. [E] 로 사용하면 interacted 시그널 → StageManager 가 목적지로 이동시킵니다.
## enabled 가 false 면 숨겨집니다 (예: 보스 처치 전의 다음 스테이지 텔레포트).

@export var portal_color: Color = Color(0.4, 0.75, 1.0)
## 비워두면 씬의 기본(파란) 텍스처 사용
@export var portal_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite2D
var _glow: Sprite2D
var _particles: CPUParticles2D
var _time: float = 0.0


func _ready() -> void:
	super._ready()
	if portal_texture != null:
		_sprite.texture = portal_texture
	_glow = Sprite2D.new()
	_glow.texture = Fx.GLOW_TEXTURE
	_glow.material = Fx.additive_material()
	_glow.modulate = Color(portal_color, 0.7)
	_glow.scale = Vector2(1.6, 1.9)
	_glow.position = _sprite.position
	_glow.show_behind_parent = true
	add_child(_glow)
	_particles = Fx.make_aura(portal_color, 16, 12.0, Vector2(0, -30), 0.8)
	_particles.position = _sprite.position
	add_child(_particles)
	_particles.emitting = true
	_apply_enabled_visual()


func set_enabled(value: bool) -> void:
	super.set_enabled(value)
	if is_node_ready():
		_apply_enabled_visual()


func _process(delta: float) -> void:
	_time += delta
	_sprite.rotation = _time * 1.5
	_sprite.scale = Vector2(1.0 + sin(_time * 3.0) * 0.04, 1.0 + cos(_time * 3.0) * 0.04)


func _apply_enabled_visual() -> void:
	visible = enabled
	set_deferred(&"monitoring", enabled)
	if not enabled:
		_player_inside = false
