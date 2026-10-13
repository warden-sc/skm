class_name BossGate
extends Interactable
## 사냥터의 보스방 문.
## - 봉인 상태: 사슬로 잠겨 있고 "봉인됨 (처치 7/16)" 처럼 해방 조건 진행도를 항상 표시
## - 해방(open): 붉은 소용돌이가 열리고 [E] 로 보스방 입장 → interacted 시그널

@export var sealed_texture: Texture2D
@export var open_texture: Texture2D

@onready var _sprite: Sprite2D = $Sprite2D
var _status: Label
var _aura: CPUParticles2D
var _is_open: bool = false


func _ready() -> void:
	super._ready()
	_status = Label.new()
	_status.z_index = 50
	_status.size = Vector2(160, 12)
	_status.position = Vector2(-80, 8)  # 문 아래 (화면 위쪽 HUD 와 겹치지 않게)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override(&"font_size", 8)
	_status.add_theme_constant_override(&"outline_size", 3)
	_status.add_theme_color_override(&"font_outline_color", Color(0.1, 0.1, 0.17))
	add_child(_status)
	_aura = Fx.make_aura(Color(1.0, 0.35, 0.3), 20, 14.0, Vector2(0, -40), 0.7)
	_aura.position = Vector2(0, -18)
	add_child(_aura)
	seal(0, 0)


## 봉인 + 해방 조건 진행도 표시
func seal(kills: int, target: int) -> void:
	_is_open = false
	set_enabled(false)
	_sprite.texture = sealed_texture
	_aura.emitting = false
	update_progress(kills, target)


func update_progress(kills: int, target: int) -> void:
	if _is_open:
		return
	_status.text = "보스방 봉인 — 처치 %d / %d" % [kills, target] if target > 0 else "보스방 봉인"
	_status.add_theme_color_override(&"font_color", Color(0.85, 0.8, 0.9))


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_sprite.texture = open_texture
	_aura.emitting = true
	_status.text = "보스방 해방!"
	_status.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.45))
	set_enabled(true)
	Fx.explosion(self, global_position + Vector2(0, -18), Color(1.0, 0.4, 0.3), 40.0, 2)


func is_open() -> bool:
	return _is_open
