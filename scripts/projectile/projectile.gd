class_name Projectile
extends Area2D
## 풀링되는 투사체 (Area2D)
##
## - activate(spec) 로 활성화, release() 로 비활성화 후 finished 시그널 → 풀로 반환
## - 충돌 콜백(area_entered/body_entered) 안에서는 물리 상태를 직접 바꾸면 안 되므로
##   monitoring / disabled / collision_layer 변경은 전부 set_deferred() 로 처리합니다.
## - 적 탄은 플레이어의 퍼펙트 가드에 맞으면 반사되어 플레이어 편 탄이 됩니다.
## - fx_level(무기 등급)이 높을수록 꼬리 잔상 / 빛 / 명중 파티클이 화려해지고,
##   explosion_radius 가 있으면 명중·소멸 지점에서 폭발해 주변 적에게도 피해를 줍니다.

## 퍼펙트 가드로 반사된 탄의 데미지 / 속도 배율
const REFLECT_DAMAGE_MULTIPLIER := 2.0
const REFLECT_SPEED_MULTIPLIER := 1.3
## 등급별(0~3) 꼬리 파티클 수 / 명중 파티클 수
const TRAIL_AMOUNT := [0, 8, 16, 30]
const IMPACT_AMOUNT := [4, 7, 12, 20]

signal finished(projectile: Projectile)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

var is_active: bool = false

var _spec: ProjectileSpec
var _velocity: Vector2 = Vector2.ZERO
var _travelled: float = 0.0
var _pierce_left: int = 0
## 관통 투사체가 같은 적을 여러 번 때리지 않도록 기록
var _hit_ids: Dictionary = {}
var _default_texture: Texture2D
var _trail: CPUParticles2D
var _glow: Sprite2D


func _ready() -> void:
	_default_texture = _sprite.texture
	_create_fx_nodes()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_apply_inactive_state()


func activate(spec: ProjectileSpec) -> void:
	_spec = spec
	is_active = true
	_travelled = 0.0
	_pierce_left = spec.pierce
	_hit_ids.clear()

	var dir := spec.direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_velocity = dir * spec.speed
	global_position = spec.origin
	rotation = dir.angle()
	scale = Vector2.ONE * spec.scale

	_sprite.texture = spec.texture if spec.texture != null else _default_texture
	_sprite.modulate = spec.color
	_configure_fx(spec)

	_apply_team_layers(false)
	show()
	set_deferred(&"monitoring", true)
	_shape.set_deferred(&"disabled", false)


## 풀로 반환. 여러 번 호출돼도 안전합니다.
func release() -> void:
	if not is_active:
		return
	is_active = false
	_apply_inactive_state()
	finished.emit(self)


func get_team() -> int:
	return _spec.team if _spec != null else -1


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	var step := _velocity * delta
	global_position += step
	_travelled += step.length()

	# 사거리 끝부분에서 서서히 사라짐
	var remain := 1.0 - _travelled / maxf(_spec.max_distance, 1.0)
	_sprite.modulate.a = clampf(remain * 4.0, 0.0, 1.0) * _spec.color.a

	if _travelled >= _spec.max_distance:
		if _spec.explosion_radius > 0.0:
			_impact(global_position, null)
		release()


func _on_area_entered(area: Area2D) -> void:
	if not is_active or _spec.team != ProjectileSpec.Team.PLAYER:
		return
	var enemy := area as Enemy
	if enemy == null or enemy.is_dead():
		return
	var id := enemy.get_instance_id()
	if _hit_ids.has(id):
		return
	if not enemy.can_be_hit_by(_spec.hit_kind):
		enemy.show_immune()  # 공중의 적: 활이 아니면 그냥 지나감
		return
	_hit_ids[id] = true

	enemy.take_damage(_spec.damage, _velocity.normalized() * _spec.knockback, _spec.is_crit, _spec.armor_pen)
	if _spec.slow_duration > 0.0:
		enemy.apply_slow(0.45, _spec.slow_duration)
	_impact(enemy.get_hit_center(), enemy)

	if _pierce_left > 0:
		_pierce_left -= 1
	else:
		release()


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	var player := body as Player
	if player != null:
		if _spec.team != ProjectileSpec.Team.ENEMY:
			return
		match player.take_hit(_spec.damage, global_position):
			Player.HitResult.DAMAGED:
				if _spec.slow_duration > 0.0:
					player.apply_slow(0.5, _spec.slow_duration)
				if _spec.burn_damage > 0:
					player.apply_burn(_spec.burn_damage, _spec.burn_duration, _spec.burn_poison)
				if _spec.charm_duration > 0.0:
					player.apply_charm(_spec.charm_duration, _spec.charmer)
				if _spec.death_mark > 0:
					player.add_death_mark(_spec.death_mark)
				_impact(global_position, null)
				release()
			Player.HitResult.BLOCKED:
				_impact(global_position, null)
				release()
			Player.HitResult.PARRIED:
				_reflect()
			_:
				pass  # IGNORED: 대시 무적 → 탄이 그대로 통과
		return
	# 그 외 바디 = 벽(StaticBody2D / TileMap)
	_impact(global_position, null)
	release()


## 퍼펙트 가드: 진행 방향을 뒤집고 플레이어 편 탄으로 전환
func _reflect() -> void:
	_spec.team = ProjectileSpec.Team.PLAYER
	_spec.damage = roundi(_spec.damage * REFLECT_DAMAGE_MULTIPLIER)
	_spec.knockback = maxf(_spec.knockback, 120.0)
	_spec.pierce = 1
	_pierce_left = _spec.pierce
	_travelled = 0.0
	_hit_ids.clear()
	_velocity = -_velocity * REFLECT_SPEED_MULTIPLIER
	rotation = _velocity.angle()
	_spec.color = Color(0.6, 1.0, 1.0)
	_sprite.modulate = _spec.color
	_apply_team_layers(true)


## 명중 이펙트 + (있다면) 폭발 피해. direct_target 은 이미 직접 맞은 적이라 폭발 피해에서 제외.
func _impact(at_global: Vector2, direct_target: Enemy) -> void:
	if _spec.source_weapon != null and _spec.team == ProjectileSpec.Team.PLAYER and _spec.explosion_radius > 0.0:
		Spells.projectile_impact(self, _spec, at_global, direct_target)
		return
	var level := clampi(_spec.fx_level, 0, 3)
	var fx_gravity := Elements.gravity_of(_spec.element)
	if _spec.explosion_radius <= 0.0:
		Fx.burst(self, at_global, _spec.color, IMPACT_AMOUNT[level], 50.0 + 15.0 * level, 0.3, fx_gravity)
		return
	Fx.explosion(self, at_global, _spec.color, _spec.explosion_radius, level, fx_gravity)
	if _spec.team != ProjectileSpec.Team.PLAYER:
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy == direct_target or enemy.is_dead():
			continue
		var offset := enemy.get_hit_center() - at_global
		if offset.length() <= _spec.explosion_radius and enemy.can_be_hit_by(_spec.hit_kind):
			enemy.take_damage(_spec.explosion_damage, offset.normalized() * _spec.knockback * 0.5, false, _spec.armor_pen)


func _create_fx_nodes() -> void:
	_trail = CPUParticles2D.new()
	_trail.texture = Fx.SPARK_TEXTURE
	_trail.material = Fx.additive_material()
	_trail.local_coords = false
	_trail.emitting = false
	_trail.lifetime = 0.3
	_trail.spread = 180.0
	_trail.initial_velocity_min = 2.0
	_trail.initial_velocity_max = 10.0
	_trail.scale_amount_min = 0.4
	_trail.scale_amount_max = 1.0
	_trail.show_behind_parent = true
	add_child(_trail)

	_glow = Sprite2D.new()
	_glow.texture = Fx.GLOW_TEXTURE
	_glow.material = Fx.additive_material()
	_glow.show_behind_parent = true
	_glow.visible = false
	add_child(_glow)


func _configure_fx(spec: ProjectileSpec) -> void:
	var level := clampi(spec.fx_level, 0, 3)
	var trail_amount: int = TRAIL_AMOUNT[level]
	_trail.emitting = false
	if trail_amount > 0:
		_trail.amount = trail_amount
		_trail.color_ramp = Fx.fade_ramp(spec.color)
		_trail.gravity = Elements.gravity_of(spec.element) * 0.5
		_trail.scale_amount_max = 0.8 + 0.25 * level
		_trail.restart()
		_trail.emitting = true
	_glow.visible = level >= 2
	if _glow.visible:
		_glow.modulate = Color(spec.color, 0.55 + 0.15 * level)
		_glow.scale = Vector2.ONE * (0.35 + 0.15 * level)


func _apply_team_layers(deferred: bool) -> void:
	var layer := Layers.PLAYER_PROJECTILE
	var mask := Layers.ENEMY | Layers.WORLD
	if _spec.team == ProjectileSpec.Team.ENEMY:
		layer = Layers.ENEMY_PROJECTILE
		mask = Layers.PLAYER | Layers.WORLD
	if deferred:
		set_deferred(&"collision_layer", layer)
		set_deferred(&"collision_mask", mask)
	else:
		collision_layer = layer
		collision_mask = mask


func _apply_inactive_state() -> void:
	hide()
	if _trail != null:
		_trail.emitting = false
	_velocity = Vector2.ZERO
	set_deferred(&"monitoring", false)
	_shape.set_deferred(&"disabled", true)
