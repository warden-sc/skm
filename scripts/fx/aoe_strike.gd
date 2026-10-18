class_name AoeStrike
extends Node2D
## 예고 후 폭발하는 장판 공격 (오크의 내려찍기, 수문장의 화염 기둥, 골렘의 낙뢰/지진 등).
##
## 1) delay 동안 빨간 원이 점점 차오르며 위치를 예고
## 2) 시간이 되면 반경 안의 플레이어에게 피해 (가드로 막을 수 있음) + 폭발 이펙트
## 플레이어 판정은 물리 쿼리 없이 거리로 계산하므로 콜백 타이밍 문제가 없습니다.

var radius: float = 24.0
var delay: float = 0.8
var damage: int = 10
var color: Color = Color(1.0, 0.3, 0.2)
var slow_duration: float = 0.0
var fx_gravity: Vector2 = Vector2.ZERO
## 맞으면 화상 (0.5초마다 피해 / 지속 시간)
var burn_damage: int = 0
var burn_duration: float = 0.0
var burn_poison: bool = false
## 맞으면 쌓이는 「죽음의 낙인」 수
var death_mark: int = 0
## 맞으면 「부패」(포션 회복 불가) 시간 — 헬리시온
var decay_duration: float = 0.0

var _elapsed: float = 0.0
var _done: bool = false


static func spawn(context: Node, at_global: Vector2, strike_radius: float, strike_delay: float, strike_damage: int,
		strike_color: Color, slow_time: float = 0.0, gravity: Vector2 = Vector2.ZERO) -> AoeStrike:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var strike := AoeStrike.new()
	strike.radius = strike_radius
	strike.delay = strike_delay
	strike.damage = strike_damage
	strike.color = strike_color
	strike.slow_duration = slow_time
	strike.fx_gravity = gravity
	strike.z_index = -5  # 바닥 위, 캐릭터 아래
	strike.add_to_group(&"aoe_strikes")
	root.add_child(strike)
	strike.global_position = at_global
	return strike


func _physics_process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= delay:
		_detonate()


func _draw() -> void:
	var t := clampf(_elapsed / maxf(delay, 0.01), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.12))
	draw_circle(Vector2.ZERO, radius * t, Color(color, 0.28))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.8), 1.0)


func _detonate() -> void:
	_done = true
	Fx.explosion(self, global_position, color, radius, 2, fx_gravity)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.global_position.distance_to(global_position) <= radius + 4.0:
		var result := player.take_hit(damage, global_position)
		if result == Player.HitResult.DAMAGED and slow_duration > 0.0:
			player.apply_slow(0.5, slow_duration)
		if result == Player.HitResult.DAMAGED and burn_damage > 0:
			player.apply_burn(burn_damage, burn_duration, burn_poison)
		if result == Player.HitResult.DAMAGED and death_mark > 0:
			player.add_death_mark(death_mark)
		if result == Player.HitResult.DAMAGED and decay_duration > 0.0:
			player.apply_decay(decay_duration)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
