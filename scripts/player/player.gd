class_name Player
extends CharacterBody2D
## 플레이어 (CharacterBody2D = Node2D 계열)
##
## - Input.get_vector() 기반 8방향 이동 + 가속/마찰
## - 마우스 조준: get_global_mouse_position() 은 CanvasItem(Node2D) 의 함수이므로
##   "여기(Player)" 에서만 호출하고, 결과를 get_aim_direction() 으로 다른 노드에 제공합니다.
## - 쿨타임 대시 (대시 중 무적 + 잔상)
## - 공격은 AttackController, 방패 가드는 GuardController (둘 다 Node 컴포넌트) 가 담당
##
## 필요한 자식 노드 (player.tscn):
##   BodySprite(Sprite2D), CollisionShape2D,
##   WeaponPivot(Node2D)
##   ├ SwingPivot(Node2D) └ WeaponSprite(Sprite2D)
##   ├ SwingFx(Sprite2D)  ├ ShieldSprite(Sprite2D)  └ Muzzle(Marker2D)
##   AttackController(Node), GuardController(Node), Camera2D

## take_hit() 의 결과. 투사체는 이 값을 보고 소멸/통과/반사를 결정합니다.
enum HitResult { IGNORED, DAMAGED, BLOCKED, PARRIED }

const WEAPON_REST_ANGLE := PI / 4.0
const SWING_FX_RADIUS := 27.0   # swing_arc.png 의 바깥 반지름(px)
const SWING_FX_ARC := 124.0     # swing_arc.png 가 그리는 각도(도)

@export_group("Movement")
@export var max_speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1000.0

@export_group("Dash")
@export var dash_speed: float = 340.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.9
@export var dash_ghost_interval: float = 0.03

@export_group("Aim")
## 값이 클수록 조준이 빠르게 마우스를 따라갑니다.
@export var aim_turn_speed: float = 30.0
@export var weapon_orbit_radius: float = 6.0

@export_group("Hit")
@export var invincible_time: float = 0.6
@export var hit_knockback: float = 180.0
## 가드로 막았을 때 공격자를 밀어내는 힘 / 퍼펙트 가드 시 기절 시간
@export var block_push_force: float = 220.0
@export var parry_stun_time: float = 1.0

@onready var _body_sprite: Sprite2D = $BodySprite
@onready var _weapon_pivot: Node2D = $WeaponPivot
@onready var _swing_pivot: Node2D = $WeaponPivot/SwingPivot
@onready var _weapon_sprite: Sprite2D = $WeaponPivot/SwingPivot/WeaponSprite
@onready var _swing_fx: Sprite2D = $WeaponPivot/SwingFx
@onready var _shield_sprite: Sprite2D = $WeaponPivot/ShieldSprite
@onready var _muzzle: Marker2D = $WeaponPivot/Muzzle
@onready var _guard: GuardController = $GuardController
@onready var _camera: Camera2D = $Camera2D

var _aim_direction: Vector2 = Vector2.RIGHT
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _ghost_timer: float = 0.0
var _invincible_left: float = 0.0
var _anim_time: float = 0.0
var _shake_strength: float = 0.0
var _weapon_kick: float = 0.0
var _swing_sign: float = 1.0
var _swing_tween: Tween
var _is_dead: bool = false
var _body_base_y: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	_body_base_y = _body_sprite.position.y
	_swing_fx.modulate.a = 0.0
	GameManager.weapon_equipped.connect(_on_weapon_equipped)
	GameManager.shield_equipped.connect(_on_shield_equipped)
	GameManager.player_damaged.connect(_on_player_damaged)
	GameManager.player_died.connect(_on_player_died)
	GameManager.guard_broken.connect(_on_guard_broken)
	_on_weapon_equipped(GameManager.equipped_weapon)
	_on_shield_equipped(GameManager.equipped_shield)
	GameManager.set_dash_cooldown(0.0, dash_cooldown)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	_update_aim(delta)
	_update_timers(delta)

	if _dash_time_left > 0.0:
		velocity = _dash_direction * dash_speed
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = dash_ghost_interval
			_spawn_dash_ghost()
	else:
		# get_vector 는 이미 길이 1 이하로 정규화되어 대각선도 속도가 같습니다.
		var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		var speed := max_speed * _guard.get_move_multiplier()
		if input_dir != Vector2.ZERO:
			velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

		if Input.is_action_just_pressed(&"dash") and _dash_cooldown_left <= 0.0:
			_start_dash(input_dir)

	move_and_slide()
	_update_visuals(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event.is_action_pressed(&"weapon_next"):
		GameManager.cycle_weapon(1)
	elif event.is_action_pressed(&"weapon_prev"):
		GameManager.cycle_weapon(-1)


# ============================================================ 공개 API (컴포넌트들이 사용)
## 정규화된 조준 방향 (플레이어 손 → 마우스)
func get_aim_direction() -> Vector2:
	return _aim_direction


## 근접 공격 판정 중심 (무기 피벗 = 플레이어 손 위치)
func get_attack_origin() -> Vector2:
	return _weapon_pivot.global_position


## 투사체 발사 위치 (무즐 Marker2D 의 전역 좌표)
func get_muzzle_position() -> Vector2:
	return _muzzle.global_position


func can_attack() -> bool:
	return not _is_dead and _dash_time_left <= 0.0 and not _guard.is_guarding()


func can_guard() -> bool:
	return not _is_dead and _dash_time_left <= 0.0


func is_dashing() -> bool:
	return _dash_time_left > 0.0


func is_guarding() -> bool:
	return _guard.is_guarding()


func is_invincible() -> bool:
	return _invincible_left > 0.0 or _dash_time_left > 0.0


## 원거리 공격 시 무기를 살짝 튕기는 연출
func play_attack_feedback() -> void:
	_weapon_kick = 1.0


## 근접 휘두르기 연출: 무기가 부채꼴을 그리며 지나가고 베기 이펙트가 남습니다.
func play_melee_swing(weapon: WeaponData) -> void:
	var half_arc := deg_to_rad(weapon.melee_arc_degrees) * 0.5
	var duration := clampf(weapon.attack_cooldown * 0.45, 0.07, 0.16)
	_swing_sign = -_swing_sign  # 휘두를 때마다 방향을 번갈아

	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_pivot.rotation = -half_arc * _swing_sign
	_swing_tween = create_tween()
	_swing_tween.tween_property(_swing_pivot, "rotation", half_arc * _swing_sign, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(_swing_pivot, "rotation", 0.0, 0.12)

	var reach_scale := weapon.melee_range / SWING_FX_RADIUS
	var arc_scale := clampf(weapon.melee_arc_degrees / SWING_FX_ARC, 0.5, 1.4)
	_swing_fx.scale = Vector2(reach_scale, reach_scale * arc_scale * _swing_sign)
	_swing_fx.modulate = weapon.effect_color
	_swing_fx.modulate.a = 1.0
	var fx := create_tween()
	fx.tween_property(_swing_fx, "modulate:a", 0.0, duration + 0.08)


func shake_camera(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)


## 적/적 탄환에게 맞았을 때 호출.
## from_position: 공격이 날아온 지점 (가드 방향 판정에 사용)
## attacker: 근접 공격한 적 (막으면 밀려나고, 퍼펙트 가드면 기절)
func take_hit(amount: int, from_position: Vector2, attacker: Enemy = null) -> HitResult:
	if _is_dead or is_dashing():
		return HitResult.IGNORED  # 대시 중에는 공격이 통과

	var hit_dir := global_position.direction_to(from_position)
	if hit_dir == Vector2.ZERO:
		hit_dir = _aim_direction

	var block := _guard.evaluate_hit(amount, hit_dir)
	match block["result"]:
		GuardController.BlockResult.PARRIED:
			_on_parried(attacker)
			return HitResult.PARRIED
		GuardController.BlockResult.BLOCKED:
			_on_blocked(block["damage"], hit_dir, attacker)
			return HitResult.BLOCKED

	if _invincible_left > 0.0:
		return HitResult.IGNORED
	_invincible_left = invincible_time
	velocity = -hit_dir * hit_knockback
	_apply_damage(amount)
	return HitResult.DAMAGED


# ============================================================ 내부
func _apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	# 방패 상시 방어력 (최소 1은 들어감)
	GameManager.damage_player(maxi(1, amount - _guard.get_defense()))


func _on_blocked(leftover_damage: int, hit_dir: Vector2, attacker: Enemy) -> void:
	velocity = -hit_dir * hit_knockback * 0.4
	if attacker != null:
		attacker.apply_knockback(hit_dir * block_push_force)
	shake_camera(1.5)
	if leftover_damage > 0:
		_apply_damage(leftover_damage)
	else:
		FloatingText.spawn(self, global_position + Vector2(0, -16), "가드", Color(1.0, 0.85, 0.5))


func _on_parried(attacker: Enemy) -> void:
	if attacker != null:
		attacker.apply_knockback(global_position.direction_to(attacker.global_position) * block_push_force * 1.5)
		attacker.stun(parry_stun_time)
	shake_camera(3.0)
	FloatingText.spawn(self, global_position + Vector2(0, -18), "PERFECT!", Color(0.5, 1.0, 1.0), true)
	_shield_sprite.self_modulate = Color(3.0, 3.0, 3.0)
	create_tween().tween_property(_shield_sprite, "self_modulate", Color.WHITE, 0.25)


func _update_aim(delta: float) -> void:
	# Player 는 CharacterBody2D(=Node2D) 이므로 get_global_mouse_position() 을 안전하게 쓸 수 있습니다.
	var to_mouse := get_global_mouse_position() - _weapon_pivot.global_position
	if to_mouse.length_squared() > 4.0:
		_aim_direction = to_mouse.normalized()

	var weight := 1.0 - exp(-aim_turn_speed * delta)
	_weapon_pivot.rotation = lerp_angle(_weapon_pivot.rotation, _aim_direction.angle(), weight)
	# 왼쪽을 볼 때 무기가 뒤집혀 보이지 않도록 피벗의 Y 스케일을 반전
	_weapon_pivot.scale.y = -1.0 if _aim_direction.x < 0.0 else 1.0
	_body_sprite.flip_h = _aim_direction.x < 0.0


func _update_timers(delta: float) -> void:
	_invincible_left = maxf(_invincible_left - delta, 0.0)
	_dash_time_left = maxf(_dash_time_left - delta, 0.0)
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
		GameManager.set_dash_cooldown(_dash_cooldown_left, dash_cooldown)


func _start_dash(input_dir: Vector2) -> void:
	_dash_direction = input_dir.normalized() if input_dir != Vector2.ZERO else _aim_direction
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	_ghost_timer = 0.0
	GameManager.set_dash_cooldown(_dash_cooldown_left, dash_cooldown)


func _spawn_dash_ghost() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _body_sprite.texture
	ghost.flip_h = _body_sprite.flip_h
	ghost.modulate = Color(0.45, 0.8, 1.0, 0.55)
	parent.add_child(ghost)
	ghost.global_position = _body_sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)


func _update_visuals(delta: float) -> void:
	_anim_time += delta
	var moving := velocity.length() > 10.0
	var guarding := _guard.is_guarding()

	# 걷기 바운스 / 대시 늘어남
	var bob := absf(sin(_anim_time * 14.0)) * -1.5 if moving and not guarding else 0.0
	_body_sprite.position.y = _body_base_y + bob
	if is_dashing():
		_body_sprite.scale = Vector2(1.25, 0.8)
	else:
		_body_sprite.scale = _body_sprite.scale.lerp(Vector2.ONE, 1.0 - exp(-20.0 * delta))

	# 피격 무적 깜빡임
	if _invincible_left > 0.0:
		_body_sprite.modulate = Color(1, 0.5, 0.5, 0.45 if int(_anim_time * 20.0) % 2 == 0 else 1.0)
	else:
		_body_sprite.modulate = Color.WHITE

	# 무기: 원거리 반동 / 가드 중에는 뒤로 젖힘
	_weapon_kick = move_toward(_weapon_kick, 0.0, delta * 8.0)
	_weapon_sprite.position.x = weapon_orbit_radius - _weapon_kick * 3.0
	var weapon_rest := WEAPON_REST_ANGLE + (-1.3 if guarding else 0.0)
	_weapon_sprite.rotation = lerp_angle(_weapon_sprite.rotation, weapon_rest, 1.0 - exp(-25.0 * delta))

	# 방패: 평소엔 옆구리, 가드 중엔 정면으로
	var shield_pos := Vector2(9.0, 0.0) if guarding else Vector2(-1.0, 5.0)
	var shield_scale := Vector2.ONE if guarding else Vector2(0.7, 0.7)
	var w := 1.0 - exp(-30.0 * delta)
	_shield_sprite.position = _shield_sprite.position.lerp(shield_pos, w)
	_shield_sprite.scale = _shield_sprite.scale.lerp(shield_scale, w)
	_shield_sprite.modulate = Color(0.5, 0.5, 0.5, 0.6) if _guard.is_broken() else Color.WHITE

	# 카메라 흔들림
	_shake_strength = move_toward(_shake_strength, 0.0, delta * 20.0)
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength


func _on_weapon_equipped(weapon: WeaponData) -> void:
	_weapon_sprite.texture = weapon.icon if weapon != null else null


func _on_shield_equipped(shield: ShieldData) -> void:
	_shield_sprite.texture = shield.icon if shield != null else null
	_shield_sprite.visible = shield != null


func _on_player_damaged(_amount: int) -> void:
	shake_camera(4.0)


func _on_guard_broken() -> void:
	shake_camera(5.0)
	FloatingText.spawn(self, global_position + Vector2(0, -18), "가드 브레이크!", Color(1.0, 0.4, 0.4), true)


func _on_player_died() -> void:
	_is_dead = true
	_weapon_pivot.hide()
	var tween := create_tween()
	tween.tween_property(_body_sprite, "rotation", PI * 0.5, 0.3)
	tween.parallel().tween_property(_body_sprite, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.3)
