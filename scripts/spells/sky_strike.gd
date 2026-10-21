class_name SkyStrike
extends Node2D
## 하늘에서 떨어지는 지팡이 마법 (아르카나의 별똥별 / 슬라임 왕의 홀의 거대 슬라임)
## + 무기 스킬: 유성 화살비의 불화살(ARROW) · 메테오 스웜의 거대 운석(METEOR).
##
## 1) start_delay 만큼 기다렸다가
## 2) 착지 지점에 조준 원이 차오르고 그림자가 커지는 동안 하늘에서 떨어짐 (fall_time)
## 3) 착지: 반경 안의 적에게 범위 피해 (중심부 100% / 바깥 explosion_damage_ratio) + 종류별 이펙트
##    거대 슬라임은 점액 웅덩이(GroundZone)를 남깁니다.

enum Kind { STAR, SLIME, ARROW, METEOR }

const STAR_FALL_OFFSET := Vector2(-90.0, -190.0)
const SLIME_FALL_OFFSET := Vector2(0.0, -230.0)
const SLIME_TEXTURE: Texture2D = preload("res://assets/sprites/characters/slime_king.png")
const ARROW_TEXTURE: Texture2D = preload("res://assets/sprites/projectiles/sky_arrow.png")
const ARROW_FALL_OFFSET := Vector2(-30.0, -220.0)
const METEOR_FALL_OFFSET := Vector2(-140.0, -260.0)
const SHADOW_TEXTURE: Texture2D = preload("res://assets/sprites/characters/shadow.png")

var kind: Kind = Kind.STAR
var radius: float = 30.0
var start_delay: float = 0.0
var fall_time: float = 0.45
var damage: int = 10
var splash_damage: int = 8
var armor_pen: int = 0
var knockback: float = 120.0
var is_crit: bool = false
var color: Color = Color(1.0, 0.9, 0.5)
var zone_duration: float = 0.0
var zone_tick_damage: int = 0

var _elapsed: float = 0.0
var _landed: bool = false
var _body: Sprite2D
var _shadow: Sprite2D
var _trail: CPUParticles2D


## weapon 의 수치로 낙하 마법 1개를 만듭니다. roll = GameManager.roll_weapon_damage(weapon)
static func spawn(context: Node, at_global: Vector2, strike_kind: Kind, weapon: WeaponData, roll: Dictionary,
		delay: float = 0.0) -> SkyStrike:
	if context == null or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var strike := SkyStrike.new()
	strike.kind = strike_kind
	strike.radius = weapon.explosion_radius
	strike.start_delay = delay
	strike.fall_time = weapon.strike_fall_time
	strike.damage = int(roll["amount"])
	strike.splash_damage = maxi(1, roundi(strike.damage * weapon.explosion_damage_ratio))
	strike.is_crit = bool(roll["crit"])
	strike.armor_pen = int(roll.get("armor_pen", weapon.armor_pen))
	strike.knockback = weapon.knockback
	strike.color = weapon.effect_color
	strike.zone_duration = weapon.zone_duration
	strike.zone_tick_damage = maxi(1, roundi(strike.damage * weapon.zone_tick_ratio)) if weapon.zone_tick_ratio > 0.0 else 0
	strike.z_index = -4
	root.add_child(strike)
	strike.global_position = at_global
	return strike


func _ready() -> void:
	add_to_group(&"sky_strikes")
	_shadow = Sprite2D.new()
	_shadow.texture = SHADOW_TEXTURE
	_shadow.modulate = Color(0, 0, 0, 0.0)
	add_child(_shadow)

	_body = Sprite2D.new()
	_body.z_as_relative = false
	_body.z_index = 50
	if kind == Kind.STAR:
		_body.texture = Fx.STAR_TEXTURE
		_body.scale = Vector2.ONE * 1.3
		_trail = Fx.make_aura(Color(1.0, 0.85, 0.5), 24, 3.0, Vector2.ZERO, 0.35)
	elif kind == Kind.ARROW:
		_body.texture = ARROW_TEXTURE
		_body.rotation = Vector2(-ARROW_FALL_OFFSET).angle() - PI / 2.0
		_trail = Fx.make_aura(Color(1.0, 0.6, 0.25), 14, 2.0, Vector2(0, -30), 0.3)
	elif kind == Kind.METEOR:
		_body.texture = Fx.STAR_TEXTURE
		_body.scale = Vector2.ONE * 4.0
		_body.modulate = Color(1.0, 0.7, 1.0)
		_trail = Fx.make_aura(Color(0.85, 0.55, 1.0), 60, 14.0, Vector2.ZERO, 0.6)
	else:
		_body.texture = SLIME_TEXTURE
		_body.scale = Vector2.ONE * 1.6
		_trail = Fx.make_aura(Color(0.5, 1.0, 0.45), 16, 8.0, Vector2(0, -60), 0.4)
	_trail.z_as_relative = false
	_trail.z_index = 49
	_body.add_child(_trail)
	add_child(_body)
	_body.hide()


func is_landed() -> bool:
	return _landed


func _physics_process(delta: float) -> void:
	if _landed:
		return
	_elapsed += delta
	var t := (_elapsed - start_delay) / maxf(fall_time, 0.01)
	if t < 0.0:
		return
	if not _body.visible:
		_body.show()
		_trail.emitting = true
	t = minf(t, 1.0)
	var offset := STAR_FALL_OFFSET
	match kind:
		Kind.SLIME:
			offset = SLIME_FALL_OFFSET
		Kind.ARROW:
			offset = ARROW_FALL_OFFSET
		Kind.METEOR:
			offset = METEOR_FALL_OFFSET
	_body.position = offset * (1.0 - t * t)
	if kind == Kind.STAR or kind == Kind.METEOR:
		_body.rotation += delta * 14.0
	var shadow_size := (radius / 12.0) * (0.3 + 0.7 * t)
	_shadow.scale = Vector2(shadow_size, shadow_size * 0.6)
	_shadow.modulate.a = 0.15 + 0.35 * t
	queue_redraw()
	if t >= 1.0:
		_land()


func _draw() -> void:
	if _landed:
		return
	var t := clampf((_elapsed - start_delay) / maxf(fall_time, 0.01), 0.0, 1.0)
	if _elapsed < start_delay:
		return
	draw_circle(Vector2.ZERO, radius, Color(color, 0.08))
	draw_circle(Vector2.ZERO, radius * t, Color(color, 0.16))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color.lightened(0.3), 0.75), 1.0)


func _land() -> void:
	_landed = true
	_body.hide()
	_trail.emitting = false
	_shadow.hide()
	queue_redraw()
	if kind == Kind.STAR:
		Fx.star_burst(self, global_position, radius)
		Spells.shake(self, 1.5)
	elif kind == Kind.ARROW:
		Fx.burst(self, global_position, Color(1.0, 0.6, 0.25), 10, 70.0, 0.35)
		Fx.flash(self, global_position, Color(1.0, 0.7, 0.3), radius, 0.2)
	elif kind == Kind.METEOR:
		Fx.explosion(self, global_position, color, radius, 3)
		Fx.shockwave(self, global_position, Color(1.0, 0.85, 1.0), radius * 1.6, 0.5)
		Fx.burst(self, global_position, Color(0.85, 0.6, 1.0), 40, radius * 3.0, 0.7)
		Spells.shake(self, 7.0)
	else:
		Fx.slime_splash(self, global_position, radius, 3)
		Fx.shockwave(self, global_position, Color(0.7, 1.0, 0.6), radius * 1.3, 0.4)
		Spells.shake(self, 4.0)
		GroundZone.spawn(self, global_position, GroundZone.Kind.SLIME, radius * 0.9, zone_duration, zone_tick_damage, armor_pen, 0.8)
	Spells.damage_area(self, global_position, radius, damage, splash_damage, armor_pen, knockback, null, 0.0, is_crit)
	get_tree().create_timer(0.6, false).timeout.connect(queue_free)
