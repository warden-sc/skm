class_name StormField
extends Node2D
## 레비아탄 보스방의 상단(구름 지대) / 하단(폭풍우 지대) 구분 (19스테이지 기믹).
## - 보스방을 가로로 반 나눠 위는 구름, 아래는 비바람으로 그림 (바닥 위 · 캐릭터 아래)
## - warn(zone, time) 으로 한쪽에 공격을 예고(붉게 깜빡임 + 안내 문구), strike(zone) 로 그쪽에 공격 연출
## 실제 피해 판정은 BossLeviathan 이 is_in_zone() 으로 합니다.

enum Zone { UPPER, LOWER }

const ICICLE_TEXTURE: Texture2D = preload("res://assets/sprites/projectiles/icicle.png")

var area: Rect2 = Rect2()
var _time: float = 0.0
var _warn_zone: int = -1
var _warn_left: float = 0.0
var _warn_total: float = 1.0
var _rain: CPUParticles2D


static func spawn(context: Node, arena: Rect2) -> StormField:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var field := StormField.new()
	field.area = arena
	field.z_index = -4
	root.add_child(field)
	field.global_position = Vector2.ZERO
	return field


func _ready() -> void:
	add_to_group(&"storm_fields")
	_rain = CPUParticles2D.new()
	_rain.amount = 90
	_rain.lifetime = 0.6
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(area.size.x * 0.5, 4.0)
	_rain.position = Vector2(area.get_center().x, get_divider_y())
	_rain.direction = Vector2(-0.25, 1.0)
	_rain.spread = 4.0
	_rain.gravity = Vector2(-40, 500)
	_rain.initial_velocity_min = 200.0
	_rain.initial_velocity_max = 260.0
	_rain.scale_amount_min = 0.5
	_rain.scale_amount_max = 1.0
	_rain.color = Color(0.7, 0.8, 1.0, 0.55)
	_rain.z_index = 50
	add_child(_rain)
	_rain.emitting = true


func get_divider_y() -> float:
	return area.get_center().y


func is_in_zone(point: Vector2, zone: int) -> bool:
	return point.y < get_divider_y() if zone == Zone.UPPER else point.y >= get_divider_y()


func get_zone_rect(zone: int) -> Rect2:
	var half := area.size.y * 0.5
	return Rect2(area.position, Vector2(area.size.x, half)) if zone == Zone.UPPER else Rect2(Vector2(area.position.x, area.position.y + half), Vector2(area.size.x, half))


func get_warn_zone() -> int:
	return _warn_zone if _warn_left > 0.0 else -1


func warn(zone: int, time: float) -> void:
	_warn_zone = zone
	_warn_left = time
	_warn_total = maxf(time, 0.01)


## 공격 연출: 상단은 고드름이 떨어지고, 하단은 번개가 내리침
func strike(zone: int) -> void:
	_warn_left = 0.0
	var rect := get_zone_rect(zone)
	for i in 14:
		var at := Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y + 8.0, rect.end.y - 4.0))
		if zone == Zone.UPPER:
			_drop_icicle(at, randf() * 0.25)
		else:
			Fx.pillar(self, at, Color(1.0, 0.95, 0.5), 10.0, 160.0, 0.35)
			Fx.burst(self, at, Color(0.7, 0.8, 1.0), 6, 50.0, 0.3)


func _drop_icicle(at: Vector2, delay: float) -> void:
	var ice := Sprite2D.new()
	ice.texture = ICICLE_TEXTURE
	ice.scale = Vector2.ONE * 1.6
	ice.z_index = 55
	add_child(ice)
	ice.global_position = at + Vector2(0, -140)
	ice.modulate.a = 0.0
	var tween := ice.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(ice, "modulate:a", 1.0, 0.05)
	tween.tween_property(ice, "global_position", at, 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Fx.burst(ice, at, Color(0.8, 0.95, 1.0), 6, 50.0, 0.3))
	tween.tween_callback(ice.queue_free)


func _physics_process(delta: float) -> void:
	_time += delta
	_warn_left = maxf(_warn_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var upper := get_zone_rect(Zone.UPPER)
	var lower := get_zone_rect(Zone.LOWER)
	draw_rect(upper, Color(0.85, 0.9, 1.0, 0.13))      # 구름 지대
	for i in 6:
		var cx := upper.position.x + fmod(_time * 12.0 + i * upper.size.x / 6.0, upper.size.x)
		draw_circle(Vector2(cx, upper.position.y + 18.0 + (i % 3) * 22.0), 22.0, Color(1, 1, 1, 0.08))
	draw_rect(lower, Color(0.15, 0.2, 0.35, 0.22))     # 폭풍우 지대
	draw_line(Vector2(area.position.x, get_divider_y()), Vector2(area.end.x, get_divider_y()), Color(0.8, 0.9, 1.0, 0.5), 2.0)
	if _warn_left > 0.0 and _warn_zone >= 0:
		var t := 1.0 - _warn_left / _warn_total
		var blink := 0.15 + 0.2 * absf(sin(_time * (8.0 + 10.0 * t)))
		var rect := get_zone_rect(_warn_zone)
		draw_rect(rect, Color(1.0, 0.25, 0.2, blink))
		draw_rect(rect, Color(1.0, 0.4, 0.3, 0.8), false, 2.0)
