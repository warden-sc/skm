class_name BossGate
extends Interactable
## 사냥터의 보스방 문.
## - 봉인 상태: 사슬로 잠겨 있고 "봉인됨 (처치 7/16)" 처럼 해방 조건 진행도를 항상 표시
## - 해방(open): 웅장한 연출 — 땅이 울리며 문이 떨리고(굉음) → 사슬이 끊어져 흩어지고 → 빛기둥과 충격파 속에
##   붉은 소용돌이가 열림. 근처 용사들의 카메라가 잠깐 문을 비춤. 그 뒤 [E] 로 보스방 입장 → interacted 시그널

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


## text 가 있으면 그대로 (처치 말고 다른 해방 시련), 없으면 「처치 k / t」
func update_progress(kills: int, target: int, text: String = "") -> void:
	if _is_open:
		return
	if text != "":
		_status.text = "보스방 봉인 — " + text
	else:
		_status.text = "보스방 봉인 — 처치 %d / %d" % [kills, target] if target > 0 else "보스방 봉인"
	_status.add_theme_color_override(&"font_color", Color(0.85, 0.8, 0.9))


## cinematic: 웅장한 연출 (카메라 · 굉음 · 사슬 · 빛기둥). false 면 바로 열림 (스테이지 이동 직후 등)
func open(cinematic: bool = true) -> void:
	if _is_open:
		return
	_is_open = true
	set_enabled(true)
	_status.text = "보스방 해방!"
	_status.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.45))
	if not cinematic or not is_inside_tree():
		_finish_open()
		return
	var center := global_position + Vector2(0, -18)
	# 1) 땅이 울리고 문이 떨림 + 굉음, 근처 용사들의 카메라가 문을 비춤
	Sfx.play(&"gate_open")
	Net.gate_cinematic(center, 1.3)
	for player in Player.get_all(get_tree()):
		player.shake_camera(4.0)
	Fx.burst(self, global_position + Vector2(0, 2), Color(0.55, 0.45, 0.35), 24, 70.0, 0.8, Vector2(0, 30), 1.4)
	var shake := create_tween()
	for i in 10:
		shake.tween_property(_sprite, "offset", Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0)), 0.05)
	shake.tween_property(_sprite, "offset", Vector2.ZERO, 0.05)
	# 2) 사슬이 끊어져 흩어짐
	shake.tween_callback(func() -> void:
		Sfx.play(&"chain_break")
		Fx.flying_sprites(self, center, Fx.ICE_SHARD_TEXTURE, 10, 46.0, Color(0.7, 0.7, 0.78), 0.5)
		Fx.cross_glint(self, center, Color(1.0, 0.9, 0.8), 60.0, 0.35)
		for p in Player.get_all(get_tree()):
			p.shake_camera(6.0))
	shake.tween_interval(0.25)
	# 3) 빛기둥 · 충격파 속에 문이 열림
	shake.tween_callback(_finish_open.bind(true))


func _finish_open(dramatic: bool = false) -> void:
	_sprite.texture = open_texture
	_sprite.offset = Vector2.ZERO
	_aura.emitting = true
	var center := global_position + Vector2(0, -18)
	Fx.explosion(self, center, Color(1.0, 0.4, 0.3), 40.0, 2)
	if dramatic:
		Fx.pillar(self, global_position, Color(1.0, 0.5, 0.35), 40.0, 220.0, 0.9)
		Fx.pillar(self, global_position + Vector2(-26, 0), Color(1.0, 0.75, 0.4), 12.0, 150.0, 0.8)
		Fx.pillar(self, global_position + Vector2(26, 0), Color(1.0, 0.75, 0.4), 12.0, 150.0, 0.8)
		Fx.shockwave(self, center, Color(1.0, 0.6, 0.4), 120.0, 0.7)
		Fx.shockwave(self, center, Color(1.0, 0.9, 0.7), 70.0, 0.5)
		Fx.flash(self, center, Color(1.0, 0.7, 0.5), 90.0, 0.6)
		var pop := create_tween()
		_sprite.scale = Vector2.ONE * 1.25
		pop.tween_property(_sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_open() -> bool:
	return _is_open
