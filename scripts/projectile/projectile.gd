class_name Projectile
extends Area2D
## 풀링되는 투사체 (Area2D)
##
## - activate(spec) 로 활성화, release() 로 비활성화 후 finished 시그널 → 풀로 반환
## - 충돌 콜백(area_entered/body_entered) 안에서는 물리 상태를 직접 바꾸면 안 되므로
##   monitoring / disabled / collision_layer 변경은 전부 set_deferred() 로 처리합니다.
## - 적 탄은 플레이어의 퍼펙트 가드에 맞으면 반사되어 플레이어 편 탄이 됩니다.

## 퍼펙트 가드로 반사된 탄의 데미지 / 속도 배율
const REFLECT_DAMAGE_MULTIPLIER := 2.0
const REFLECT_SPEED_MULTIPLIER := 1.3

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


func _ready() -> void:
	_default_texture = _sprite.texture
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
	_hit_ids[id] = true

	enemy.take_damage(_spec.damage, _velocity.normalized() * _spec.knockback, _spec.is_crit)

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
			Player.HitResult.DAMAGED, Player.HitResult.BLOCKED:
				release()
			Player.HitResult.PARRIED:
				_reflect()
			_:
				pass  # IGNORED: 대시 무적 → 탄이 그대로 통과
		return
	# 그 외 바디 = 벽(StaticBody2D / TileMap)
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
	_velocity = Vector2.ZERO
	set_deferred(&"monitoring", false)
	_shape.set_deferred(&"disabled", true)
