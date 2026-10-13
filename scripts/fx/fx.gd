class_name Fx
## 일회성 시각 효과 헬퍼 (파티클 폭발 / 빛 번쩍임 / 충격파 링).
## 모두 현재 씬에 추가되고 스스로 사라집니다. context 에는 트리 안의 아무 노드나 넘기면 됩니다.

const SPARK_TEXTURE: Texture2D = preload("res://assets/sprites/effects/spark.png")
const GLOW_TEXTURE: Texture2D = preload("res://assets/sprites/effects/glow.png")
const RING_TEXTURE: Texture2D = preload("res://assets/sprites/effects/ring.png")

static var _additive: CanvasItemMaterial


## 가산 합성 머티리얼 (빛나는 이펙트용)
static func additive_material() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


static func _root_of(context: Node) -> Node:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root


## 사방으로 튀는 파티클 한 번.
static func burst(context: Node, at_global: Vector2, color: Color, amount: int, speed: float = 70.0,
		lifetime: float = 0.4, gravity: Vector2 = Vector2.ZERO, size: float = 1.0) -> void:
	if amount <= 0:
		return
	var root := _root_of(context)
	if root == null:
		return
	var p := CPUParticles2D.new()
	p.texture = SPARK_TEXTURE
	p.material = additive_material()
	p.z_index = 60
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.6
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.2 * size
	p.color_ramp = fade_ramp(color)
	root.add_child(p)
	p.global_position = at_global
	p.emitting = true
	p.get_tree().create_timer(lifetime + 0.2, false).timeout.connect(p.queue_free)


## 빛이 번쩍 퍼졌다가 사라짐.
static func flash(context: Node, at_global: Vector2, color: Color, radius: float, duration: float = 0.25) -> void:
	var root := _root_of(context)
	if root == null:
		return
	var s := Sprite2D.new()
	s.texture = GLOW_TEXTURE
	s.material = additive_material()
	s.z_index = 55
	s.modulate = color
	root.add_child(s)
	s.global_position = at_global
	var start_scale := Vector2.ONE * (radius / 16.0) * 0.4
	s.scale = start_scale
	var tween := s.create_tween()
	tween.set_parallel(true)
	tween.tween_property(s, "scale", start_scale * 2.5, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(s, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(s.queue_free)


## 충격파 링이 radius 까지 퍼짐.
static func shockwave(context: Node, at_global: Vector2, color: Color, radius: float, duration: float = 0.3) -> void:
	var root := _root_of(context)
	if root == null:
		return
	var s := Sprite2D.new()
	s.texture = RING_TEXTURE
	s.material = additive_material()
	s.z_index = 55
	s.modulate = color
	root.add_child(s)
	s.global_position = at_global
	s.scale = Vector2.ONE * 0.1
	var tween := s.create_tween()
	tween.set_parallel(true)
	tween.tween_property(s, "scale", Vector2.ONE * (radius / 15.0), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(s, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(s.queue_free)


## 폭발 = 번쩍임 + 링 + 파티클 (level 0~3 이 높을수록 화려)
static func explosion(context: Node, at_global: Vector2, color: Color, radius: float, level: int = 1, gravity: Vector2 = Vector2.ZERO) -> void:
	flash(context, at_global, color, radius, 0.25 + 0.05 * level)
	shockwave(context, at_global, color, radius, 0.3)
	burst(context, at_global, color, 10 + 10 * level, radius * 3.0, 0.45, gravity, 1.0 + 0.2 * level)
	if level >= 3:
		shockwave(context, at_global, Color.WHITE, radius * 0.6, 0.2)


## 몸에 계속 붙어 있는 오라 파티클 (몬스터 화염 오라, 무기 잔불 등)
static func make_aura(color: Color, amount: int, radius: float, gravity: Vector2, lifetime: float = 0.6) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = SPARK_TEXTURE
	p.material = additive_material()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector2.UP
	p.spread = 30.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 20.0
	p.gravity = gravity
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color_ramp = fade_ramp(color)
	return p


## 밝은 색에서 시작해 투명하게 사라지는 색 변화 (파티클 color_ramp 용)
static func fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(color.lightened(0.4), 1.0))
	g.set_color(1, Color(color, 0.0))
	return g
