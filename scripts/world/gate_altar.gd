class_name GateAltar
extends Node2D
## 보스방 해방 시련 「정화 제단」: 용사가 원 안에 서 있는 동안 정화가 차오르고, 다 차면 보스방이 열림.
## 원 밖으로 나가면 멈춤 (줄지는 않음). 몬스터는 계속 몰려오므로 버티면서 지켜야 함.
## 진행은 StageManager 가 계산하고 progress(0~1)만 여기에 넣어 줌 — 그림은 진행에 따라 둘레 호가 차오름.

const TEXTURE := preload("res://assets/sprites/world/gate_altar.png")
const RADIUS := 34.0

var progress: float = 0.0
var active: bool = false  # 지금 누군가 원 안에 있음
var _time: float = 0.0
var _sprite: Sprite2D
var _glow: CPUParticles2D


func _ready() -> void:
	z_index = -5
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.position = Vector2(0, -10)
	_sprite.z_as_relative = false
	_sprite.z_index = 1
	add_child(_sprite)
	_glow = Fx.make_aura(Color(0.55, 0.9, 1.0), 14, 6.0, Vector2(0, -50), 0.7)
	_glow.position = Vector2(0, -16)
	add_child(_glow)
	_glow.emitting = false


func _process(delta: float) -> void:
	_time += delta
	_glow.emitting = active
	queue_redraw()


func _draw() -> void:
	var base := Color(0.45, 0.85, 1.0)
	var pulse := 0.5 + 0.5 * sin(_time * (6.0 if active else 2.0))
	draw_circle(Vector2.ZERO, RADIUS, Color(base, 0.08 + (0.08 * pulse if active else 0.0)))
	draw_arc(Vector2.ZERO, RADIUS + 1.0, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.5), 2.0)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(base, 0.45 + 0.25 * pulse), 1.0)
	if progress > 0.0:
		draw_arc(Vector2.ZERO, RADIUS - 3.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0), 48, Color(0.8, 1.0, 1.0, 0.95), 3.0)
	for i in 6:
		var a := _time * 0.6 + TAU * i / 6.0
		draw_circle(Vector2.from_angle(a) * (RADIUS - 8.0), 1.2, Color(base.lightened(0.4), 0.7))
