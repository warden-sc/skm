class_name Fx
## 일회성 시각 효과 헬퍼 (파티클 폭발 / 빛 번쩍임 / 충격파 링).
## 모두 현재 씬에 추가되고 스스로 사라집니다. context 에는 트리 안의 아무 노드나 넘기면 됩니다.

const SPARK_TEXTURE: Texture2D = preload("res://assets/sprites/effects/spark.png")
const GLOW_TEXTURE: Texture2D = preload("res://assets/sprites/effects/glow.png")
const RING_TEXTURE: Texture2D = preload("res://assets/sprites/effects/ring.png")
const ICE_SHARD_TEXTURE: Texture2D = preload("res://assets/sprites/projectiles/ice_shard.png")
const STAR_TEXTURE: Texture2D = preload("res://assets/sprites/projectiles/star.png")

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
	Net.fx_event(&"burst", [at_global, color, amount, speed, lifetime, gravity, size])
	var p := CPUParticles2D.new()
	p.set_meta(&"net_local", true)
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
	Net.fx_event(&"flash", [at_global, color, radius, duration])
	var s := Sprite2D.new()
	s.set_meta(&"net_local", true)
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
	Net.fx_event(&"shockwave", [at_global, color, radius, duration])
	var s := Sprite2D.new()
	s.set_meta(&"net_local", true)
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


## 몸에서 피어오르는 검은 안개 (가산 합성이 아닌 일반 합성 → 어둡게 보임). 사신 · 옥좌 잃은 왕
static func make_dark_mist(amount: int, radius: float, lifetime: float = 1.6) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = GLOW_TEXTURE
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector2(0, -6)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.03, 0.08, 0.0))
	g.add_point(0.25, Color(0.06, 0.04, 0.1, 0.55))
	g.set_color(g.get_point_count() - 1, Color(0.05, 0.03, 0.08, 0.0))
	p.color_ramp = g
	return p


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


# ============================================================ 지팡이 마법 이펙트
## 마력 폭발 (견습 지팡이): 보랏빛 링 두 겹 + 반짝이
static func arcane_burst(context: Node, at_global: Vector2, color: Color, radius: float, level: int = 0) -> void:
	flash(context, at_global, color, radius, 0.22)
	shockwave(context, at_global, color, radius, 0.28)
	shockwave(context, at_global, Color(1, 1, 1, 0.8), radius * 0.55, 0.2)
	burst(context, at_global, color.lightened(0.3), 10 + 6 * level, radius * 2.5, 0.4, Vector2.ZERO, 0.9)


## 서리 폭발 (서리 지팡이): 얼음 파편이 사방으로 튀고, 눈가루가 천천히 내려앉음
static func frost_nova(context: Node, at_global: Vector2, radius: float, level: int = 1) -> void:
	var ice := Color(0.65, 0.9, 1.0)
	flash(context, at_global, ice, radius, 0.3)
	shockwave(context, at_global, Color(0.85, 0.97, 1.0), radius, 0.35)
	flying_sprites(context, at_global, ICE_SHARD_TEXTURE, 8 + 2 * level, radius, ice, 0.35, true)
	burst(context, at_global, Color(0.92, 0.98, 1.0), 14 + 6 * level, radius * 1.4, 0.9, Vector2(0, 14), 0.8)


## 점액 폭발 (슬라임 지팡이 / 거대 슬라임 착지): 초록 점액 방울이 튀었다가 떨어짐
static func slime_splash(context: Node, at_global: Vector2, radius: float, level: int = 1) -> void:
	var slime := Color(0.45, 0.95, 0.4)
	flash(context, at_global, slime, radius, 0.25)
	shockwave(context, at_global, slime.lightened(0.2), radius, 0.3)
	burst(context, at_global, slime, 14 + 8 * level, radius * 3.0, 0.55, Vector2(0, 160), 1.3)
	burst(context, at_global, Color(0.75, 1.0, 0.6), 6 + 4 * level, radius * 1.5, 0.4, Vector2(0, 80), 0.8)


## 업화 폭발 (이그니스): 큰 번쩍임 + 두 겹 충격파 + 하늘로 솟는 불기둥 + 불티
static func fire_blast(context: Node, at_global: Vector2, radius: float, level: int = 2) -> void:
	var fire := Color(1.0, 0.5, 0.15)
	flash(context, at_global, Color(1.0, 0.75, 0.3), radius * 1.2, 0.35)
	shockwave(context, at_global, fire, radius, 0.35)
	shockwave(context, at_global, Color(1.0, 0.9, 0.5), radius * 0.6, 0.25)
	burst(context, at_global, fire, 24 + 10 * level, radius * 2.2, 0.6, Vector2(0, -90), 1.4)
	burst(context, at_global, Color(0.35, 0.3, 0.3), 10, radius * 1.2, 0.9, Vector2(0, -30), 1.6)
	pillar(context, at_global, fire, radius * 0.5, radius * 1.6, 0.45)


## 별 폭발 (아르카나 별똥별): 금빛 번쩍임 + 보랏빛 링 + 십자 섬광
static func star_burst(context: Node, at_global: Vector2, radius: float) -> void:
	flash(context, at_global, Color(1.0, 0.9, 0.55), radius, 0.3)
	shockwave(context, at_global, Color(0.85, 0.6, 1.0), radius, 0.3)
	shockwave(context, at_global, Color(1.0, 0.95, 0.7), radius * 0.6, 0.22)
	burst(context, at_global, Color(1.0, 0.9, 0.6), 18, radius * 2.4, 0.5, Vector2.ZERO, 1.0)
	cross_glint(context, at_global, Color(1.0, 0.95, 0.8), radius * 1.3, 0.3)


## 텍스처 조각들이 중심에서 바깥으로 날아가며 사라짐 (얼음 파편 등)
static func flying_sprites(context: Node, at_global: Vector2, texture: Texture2D, count: int, distance: float,
		color: Color, duration: float = 0.35, point_outward: bool = true) -> void:
	var root := _root_of(context)
	if root == null:
		return
	Net.fx_event(&"flying_sprites", [at_global, texture.resource_path if texture != null else "", count, distance, color, duration, point_outward])
	for i in count:
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(count) + randf_range(-0.2, 0.2))
		var s := Sprite2D.new()
		s.set_meta(&"net_local", true)
		s.texture = texture
		s.modulate = color
		s.z_index = 56
		if point_outward:
			s.rotation = dir.angle()
		root.add_child(s)
		s.global_position = at_global
		var tween := s.create_tween()
		tween.set_parallel(true)
		tween.tween_property(s, "global_position", at_global + dir * distance * randf_range(0.8, 1.1), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(s, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
		tween.chain().tween_callback(s.queue_free)


## 위로 길게 솟았다 사라지는 빛기둥 (업화의 불기둥)
static func pillar(context: Node, at_global: Vector2, color: Color, width: float, height: float, duration: float = 0.4) -> void:
	var root := _root_of(context)
	if root == null:
		return
	Net.fx_event(&"pillar", [at_global, color, width, height, duration])
	var s := Sprite2D.new()
	s.set_meta(&"net_local", true)
	s.texture = GLOW_TEXTURE
	s.material = additive_material()
	s.modulate = color
	s.z_index = 57
	s.offset = Vector2(0, -16)
	root.add_child(s)
	s.global_position = at_global
	s.scale = Vector2(width / 32.0, 0.1)
	var tween := s.create_tween()
	tween.set_parallel(true)
	tween.tween_property(s, "scale", Vector2(width / 32.0, height / 32.0), duration * 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(s, "modulate:a", 0.0, duration).set_delay(duration * 0.3)
	tween.chain().tween_callback(s.queue_free)


## 가로·세로로 번쩍이는 십자 섬광 (별)
static func cross_glint(context: Node, at_global: Vector2, color: Color, length: float, duration: float = 0.3) -> void:
	var root := _root_of(context)
	if root == null:
		return
	Net.fx_event(&"cross_glint", [at_global, color, length, duration])
	for angle in [0.0, PI / 2.0]:
		var s := Sprite2D.new()
		s.set_meta(&"net_local", true)
		s.texture = GLOW_TEXTURE
		s.material = additive_material()
		s.modulate = color
		s.z_index = 58
		s.rotation = angle
		root.add_child(s)
		s.global_position = at_global
		s.scale = Vector2(length / 16.0, 0.12)
		var tween := s.create_tween()
		tween.set_parallel(true)
		tween.tween_property(s, "scale", Vector2(length / 32.0, 0.04), duration)
		tween.tween_property(s, "modulate:a", 0.0, duration)
		tween.chain().tween_callback(s.queue_free)
