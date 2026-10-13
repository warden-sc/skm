class_name Player
extends CharacterBody2D
## 플레이어 (CharacterBody2D = Node2D 계열)
##
## - Input.get_vector() 기반 8방향 이동 + 가속/마찰
## - 마우스 조준: get_global_mouse_position() 은 CanvasItem(Node2D) 의 함수이므로
##   "여기(Player)" 에서만 호출하고, 결과를 get_aim_direction() 으로 다른 노드에 제공합니다.
## - 쿨타임 대시 (대시 중 무적 + 잔상)
##
## 필요한 자식 노드 (player.tscn):
##   BodySprite(Sprite2D), CollisionShape2D, WeaponPivot(Node2D)
##   ├ WeaponSprite(Sprite2D)  └ Muzzle(Marker2D),  AttackController(Node), Camera2D

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

@onready var _body_sprite: Sprite2D = $BodySprite
@onready var _weapon_pivot: Node2D = $WeaponPivot
@onready var _weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite
@onready var _muzzle: Marker2D = $WeaponPivot/Muzzle
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
var _is_dead: bool = false
var _body_base_y: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	_body_base_y = _body_sprite.position.y
	GameManager.weapon_equipped.connect(_on_weapon_equipped)
	GameManager.player_damaged.connect(_on_player_damaged)
	GameManager.player_died.connect(_on_player_died)
	_on_weapon_equipped(GameManager.equipped_weapon)
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
		if input_dir != Vector2.ZERO:
			velocity = velocity.move_toward(input_dir * max_speed, acceleration * delta)
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


# ============================================================ 공개 API (AttackController 등이 사용)
## 정규화된 조준 방향 (플레이어 중심 → 마우스)
func get_aim_direction() -> Vector2:
	return _aim_direction


## 투사체 발사 위치 (무즐 Marker2D 의 전역 좌표)
func get_muzzle_position() -> Vector2:
	return _muzzle.global_position


func can_attack() -> bool:
	return not _is_dead and _dash_time_left <= 0.0


func is_dashing() -> bool:
	return _dash_time_left > 0.0


func is_invincible() -> bool:
	return _invincible_left > 0.0 or _dash_time_left > 0.0


## 공격 시 무기를 살짝 튕기는 연출
func play_attack_feedback() -> void:
	_weapon_kick = 1.0


func shake_camera(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)


## 적/적 탄환에게 맞았을 때. 실제로 피해를 받았으면 true.
func take_hit(amount: int, from_position: Vector2) -> bool:
	if _is_dead or is_invincible():
		return false
	_invincible_left = invincible_time
	var away := from_position.direction_to(global_position)
	if away == Vector2.ZERO:
		away = -_aim_direction
	velocity = away * hit_knockback
	GameManager.damage_player(amount)
	return true


# ============================================================ 내부
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

	# 걷기 바운스 / 대시 늘어남
	var bob := absf(sin(_anim_time * 14.0)) * -1.5 if moving else 0.0
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

	# 공격 반동
	_weapon_kick = move_toward(_weapon_kick, 0.0, delta * 8.0)
	_weapon_sprite.position.x = weapon_orbit_radius - _weapon_kick * 3.0

	# 카메라 흔들림
	_shake_strength = move_toward(_shake_strength, 0.0, delta * 20.0)
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength


func _on_weapon_equipped(weapon: WeaponData) -> void:
	if weapon == null:
		_weapon_sprite.texture = null
		return
	_weapon_sprite.texture = weapon.icon


func _on_player_damaged(_amount: int) -> void:
	shake_camera(4.0)


func _on_player_died() -> void:
	_is_dead = true
	_weapon_pivot.hide()
	var tween := create_tween()
	tween.tween_property(_body_sprite, "rotation", PI * 0.5, 0.3)
	tween.parallel().tween_property(_body_sprite, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.3)
