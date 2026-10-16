class_name Player
extends CharacterBody2D
## 플레이어 (CharacterBody2D = Node2D 계열)
##
## - Input.get_vector() 기반 8방향 이동 + 가속/마찰
## - 마우스 조준: get_global_mouse_position() 은 CanvasItem(Node2D) 의 함수이므로
##   "여기(Player)" 에서만 호출하고, 결과를 get_aim_direction() 으로 다른 노드에 제공합니다.
## - 쿨타임 대시 (대시 중 무적 + 잔상)
## - 공격은 AttackController, 방패 가드는 GuardController (둘 다 Node 컴포넌트) 가 담당
## - 활 시위 당기기 / 지팡이 영창(구슬에 마력이 모임) 연출은 AttackController 가 begin_windup() 등으로 요청
##
## 필요한 자식 노드 (player.tscn):
##   BodySprite(Sprite2D) ├ ArmorSprite(Sprite2D) ├ HelmetSprite(Sprite2D) └ BootsSprite(Sprite2D)
##   CollisionShape2D, ChantLabel(Label)
##   WeaponPivot(Node2D)
##   ├ SwingPivot(Node2D) ├ WeaponSprite(Sprite2D) ├ BowString(Line2D) └ NockedArrow(Sprite2D)
##   ├ SwingFx(Sprite2D)  ├ ShieldSprite(Sprite2D)  ├ Muzzle(Marker2D) └ ChargeOrb(Sprite2D)
##   AttackController(Node), GuardController(Node), Camera2D

## take_hit() 의 결과. 투사체는 이 값을 보고 소멸/통과/반사를 결정합니다.
enum HitResult { IGNORED, DAMAGED, BLOCKED, PARRIED }

const WEAPON_REST_ANGLE := PI / 4.0
## *_held.png 활 그림에서 시위가 걸리는 양 끝 (WeaponSprite 기준 좌표)
const BOW_TIP_TOP := Vector2(-2.5, -6.5)
const BOW_TIP_BOTTOM := Vector2(-2.5, 6.5)
const BOW_MAX_PULL := 7.0
## 등급별(0~3) 영창 시 구슬로 모이는 마력 입자 수
const CHARGE_PARTICLES := [8, 14, 26, 44]
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

@export_group("Potion")
## 포션을 연달아 마실 수 없는 대기 시간
@export var potion_cooldown: float = 0.8

@onready var _body_sprite: Sprite2D = $BodySprite
@onready var _helmet_sprite: Sprite2D = $BodySprite/HelmetSprite
@onready var _armor_sprite: Sprite2D = $BodySprite/ArmorSprite
@onready var _boots_sprite: Sprite2D = $BodySprite/BootsSprite
@onready var _chant_label: Label = $ChantLabel
@onready var _bow_string: Line2D = $WeaponPivot/SwingPivot/BowString
@onready var _nocked_arrow: Sprite2D = $WeaponPivot/SwingPivot/NockedArrow
@onready var _charge_orb: Sprite2D = $WeaponPivot/ChargeOrb
@onready var _attack: AttackController = $AttackController
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
var _weapon_rest_angle: float = WEAPON_REST_ANGLE
var _slow_left: float = 0.0
var _slow_multiplier: float = 1.0
## 화상 (지속 피해): 남은 시간 / 0.5초마다의 기본 피해 (방어력에 따라 줄어듦)
var _burn_left: float = 0.0
var _burn_tick_damage: int = 0
var _burn_tick_timer: float = 0.0
var _burn_particles: CPUParticles2D
## 지금 서 있는 적 장판 (점액 바닥 등) 표시용
var _floor_status: String = ""
## 매혹: 남은 시간 동안 조작 불가 (매혹한 적 쪽으로 홀린 듯 걸어감)
var _charm_left: float = 0.0
var _charmer: Node2D
var _charm_particles: CPUParticles2D
## 죽음의 낙인 (사신): 쌓이면 사형 선고 → 잠시 후 큰 피해 (대시로 피할 수 있음)
const DEATH_MARK_MAX := 5
const DEATH_MARK_KEEP_TIME := 8.0
const EXECUTION_DELAY := 1.5
const EXECUTION_RATIO := 0.35
var death_marks: int = 0
var _mark_timer: float = 0.0
var _execution_left: float = -1.0
## 마지막 대시 후 지난 시간 (사형 선고는 대시 직후 잠깐 동안도 회피로 인정)
var _since_dash: float = 99.0
const EXECUTION_DODGE_GRACE := 0.3
## 마지막 사형 선고를 대시로 피했는지 (UI·테스트용)
var last_execution_dodged: bool = false
var _floor_status_left: float = 0.0
var _status_text: String = ""
var _windup_weapon: WeaponData
var _potion_cooldown_left: float = 0.0
var _charge_particles: CPUParticles2D
## 지팡이 영창 중 조준한 곳의 범위 표시
var _target_ring: TargetRing


func _ready() -> void:
	add_to_group(&"player")
	_body_base_y = _body_sprite.position.y
	_swing_fx.modulate.a = 0.0
	_setup_windup_visuals()
	GameManager.weapon_equipped.connect(_on_weapon_equipped)
	GameManager.shield_equipped.connect(_on_shield_equipped)
	GameManager.helmet_equipped.connect(_on_helmet_equipped)
	GameManager.armor_equipped.connect(_on_armor_equipped)
	GameManager.boots_equipped.connect(_on_boots_equipped)
	GameManager.player_damaged.connect(_on_player_damaged)
	GameManager.player_died.connect(_on_player_died)
	GameManager.guard_broken.connect(_on_guard_broken)
	GameManager.potion_used.connect(_on_potion_used)
	_on_weapon_equipped(GameManager.equipped_weapon)
	_on_shield_equipped(GameManager.equipped_shield)
	_on_helmet_equipped(GameManager.equipped_helmet)
	_on_armor_equipped(GameManager.equipped_armor)
	_on_boots_equipped(GameManager.equipped_boots)
	GameManager.set_dash_cooldown(0.0, dash_cooldown)


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	_update_aim(delta)
	_update_timers(delta)
	_update_status(delta)
	GameManager.tick_regen(delta)

	if _dash_time_left > 0.0:
		velocity = _dash_direction * dash_speed
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = dash_ghost_interval
			_spawn_dash_ghost()
	else:
		# get_vector 는 이미 길이 1 이하로 정규화되어 대각선도 속도가 같습니다.
		var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if is_charmed():
			# 매혹: 조작 불가, 매혹한 적에게 천천히 끌려감
			input_dir = Vector2.ZERO
			if _charmer != null and is_instance_valid(_charmer):
				input_dir = global_position.direction_to(_charmer.global_position) * 0.35
		var speed := max_speed * (1.0 + GameManager.get_move_speed_bonus()) * _guard.get_move_multiplier() * _attack.get_move_multiplier()
		if _slow_left > 0.0:
			speed *= _slow_multiplier
		if input_dir != Vector2.ZERO:
			velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

		if Input.is_action_just_pressed(&"dash") and _dash_cooldown_left <= 0.0 and not is_charmed():
			_start_dash(input_dir)

	move_and_slide()
	_update_visuals(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead or is_charmed():
		return
	if event.is_action_pressed(&"use_potion"):
		if _potion_cooldown_left <= 0.0 and GameManager.use_potion():
			_potion_cooldown_left = potion_cooldown
	elif event.is_action_pressed(&"weapon_next"):
		GameManager.cycle_weapon(1)
	elif event.is_action_pressed(&"weapon_prev"):
		GameManager.cycle_weapon(-1)
	else:
		for slot in 3:
			if event.is_action_pressed(StringName("weapon_slot_%d" % (slot + 1))):
				if not GameManager.select_weapon_slot(slot):
					GameManager.show_notice("%s 칸이 비어 있습니다." % GameManager.WEAPON_SLOT_NAMES[slot], Color(1.0, 0.7, 0.5))


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


## 마우스로 조준한 지점 (무즐에서 max_range 이내로 제한). 지팡이 마법이 터질 곳.
func get_aim_point(max_range: float) -> Vector2:
	var origin := get_muzzle_position()
	var offset := get_global_mouse_position() - origin
	if offset.length() < 1.0:
		offset = _aim_direction * max_range
	return origin + offset.limit_length(max_range)


func can_attack() -> bool:
	return not _is_dead and _dash_time_left <= 0.0 and not _guard.is_guarding() and not is_charmed()


func can_guard() -> bool:
	return not _is_dead and _dash_time_left <= 0.0 and not is_charmed()


## 매혹 (서큐버스): duration 동안 이동·공격·가드·대시·포션 불가. charmer 쪽으로 천천히 끌려감
func apply_charm(duration: float, charmer: Node2D = null) -> void:
	if _is_dead:
		return
	_charm_left = maxf(_charm_left, duration)
	_charmer = charmer
	if _windup_weapon != null:
		end_windup(false)
	FloatingText.spawn(self, global_position + Vector2(0, -20), "매혹!", Color(1.0, 0.45, 0.8), true)


func is_charmed() -> bool:
	return _charm_left > 0.0


## 「죽음의 낙인」 추가. DEATH_MARK_MAX 개가 되면 사형 선고 (EXECUTION_DELAY 뒤 최대 체력의 35% 피해, 그 순간 대시 중이면 회피)
## 낙인은 마지막으로 쌓인 뒤 DEATH_MARK_KEEP_TIME 이 지나면 하나씩 사라짐
func add_death_mark(count: int = 1) -> void:
	if _is_dead or count <= 0 or _execution_left >= 0.0:
		return
	death_marks = mini(death_marks + count, DEATH_MARK_MAX)
	_mark_timer = DEATH_MARK_KEEP_TIME
	if death_marks >= DEATH_MARK_MAX:
		_execution_left = EXECUTION_DELAY
		FloatingText.spawn(self, global_position + Vector2(0, -22), "사형 선고!", Color(0.75, 0.4, 1.0), true)
		GameManager.show_notice("죽음의 낙인 %d개 — 사형 선고! 대시로 피하라!" % DEATH_MARK_MAX, Color(0.75, 0.45, 1.0))
	else:
		FloatingText.spawn(self, global_position + Vector2(0, -22), "낙인 %d/%d" % [death_marks, DEATH_MARK_MAX], Color(0.7, 0.5, 0.95))


func is_sentenced() -> bool:
	return _execution_left >= 0.0


func _update_death_marks(delta: float) -> void:
	if _execution_left >= 0.0:
		_execution_left -= delta
		if _execution_left < 0.0:
			death_marks = 0
			_execution_left = -1.0
			Fx.explosion(self, global_position + Vector2(0, -6), Color(0.5, 0.25, 0.8), 30.0, 2)
			last_execution_dodged = is_dashing() or _since_dash <= EXECUTION_DODGE_GRACE
			if last_execution_dodged:
				FloatingText.spawn(self, global_position + Vector2(0, -22), "회피!", Color(0.7, 1.0, 1.0), true)
			else:
				var dmg := roundi(GameManager.max_hp * EXECUTION_RATIO)
				GameManager.damage_player(dmg)
				FloatingText.spawn(self, global_position + Vector2(0, -22), str(dmg), Color(0.75, 0.4, 1.0), true)
				shake_camera(5.0)
		return
	if death_marks > 0:
		_mark_timer -= delta
		if _mark_timer <= 0.0:
			death_marks -= 1
			_mark_timer = 2.0


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


## 활 시위 당기기 / 지팡이 영창 시작
func begin_windup(weapon: WeaponData) -> void:
	_windup_weapon = weapon
	_swing_pivot.rotation = 0.0
	if weapon.is_bow():
		_nocked_arrow.texture = weapon.projectile_texture
		_nocked_arrow.modulate = weapon.effect_color
		_nocked_arrow.show()
	elif weapon.is_staff():
		var level := weapon.get_fx_level()
		_charge_orb.modulate = weapon.effect_color
		_charge_orb.scale = Vector2.ZERO
		_charge_orb.show()
		_charge_particles.amount = CHARGE_PARTICLES[clampi(level, 0, 3)]
		_charge_particles.color = weapon.effect_color
		_charge_particles.emitting = true
		_chant_label.text = weapon.chant_text
		_chant_label.add_theme_color_override(&"font_color", weapon.effect_color.lightened(0.3))
		_chant_label.visible_ratio = 0.0
		_chant_label.show()
		_target_ring.radius = weapon.get_target_radius()
		_target_ring.color = weapon.effect_color
		_target_ring.progress = 0.0
		_target_ring.global_position = get_aim_point(weapon.projectile_range)
		_target_ring.show()
	set_windup_progress(0.0)


## progress: 0(시작) ~ 1(발사 직전)
func set_windup_progress(progress: float) -> void:
	if _windup_weapon == null:
		return
	if _windup_weapon.is_bow():
		_update_bow_string(progress)
	elif _windup_weapon.is_staff():
		var level := _windup_weapon.get_fx_level()
		var pulse := 1.0 + sin(_anim_time * 30.0) * 0.08 * progress
		_charge_orb.scale = Vector2.ONE * (0.15 + 0.35 * progress + 0.08 * level) * pulse
		_chant_label.visible_ratio = clampf(progress * 1.3, 0.0, 1.0)
		_target_ring.progress = progress
		_target_ring.global_position = get_aim_point(_windup_weapon.projectile_range)


## fired: true 면 발사(시위가 튕겨 돌아감 / 구슬이 터짐), false 면 취소
func end_windup(fired: bool) -> void:
	if _windup_weapon == null:
		return
	var weapon := _windup_weapon
	_windup_weapon = null
	_nocked_arrow.hide()
	_target_ring.hide()
	_charge_particles.emitting = false
	_chant_label.hide()
	if weapon.is_bow():
		var snap := create_tween()
		snap.tween_method(_update_bow_string, 0.6 if fired else 0.3, 0.0, 0.08)
	if weapon.is_staff():
		if fired:
			var level := weapon.get_fx_level()
			Fx.flash(self, _charge_orb.global_position, weapon.effect_color, 8.0 + 4.0 * level, 0.2)
			Fx.burst(self, _charge_orb.global_position, weapon.effect_color, 4 + 4 * level, 50.0, 0.3, Elements.gravity_of(weapon.element))
		_charge_orb.hide()


func is_winding_up() -> bool:
	return _windup_weapon != null


## 텔레포트: 즉시 이동 + 카메라를 새 방의 경계에 맞춤
func teleport_to(at_global: Vector2, camera_bounds: Rect2) -> void:
	if _windup_weapon != null:
		end_windup(false)
	global_position = at_global
	velocity = Vector2.ZERO
	death_marks = 0
	_execution_left = -1.0
	set_camera_bounds(camera_bounds)


func set_camera_bounds(bounds: Rect2) -> void:
	_camera.limit_left = floori(bounds.position.x)
	_camera.limit_top = floori(bounds.position.y)
	_camera.limit_right = ceili(bounds.end.x)
	_camera.limit_bottom = ceili(bounds.end.y)
	_camera.reset_smoothing()


## 빙결 등으로 이동속도 감소
func apply_slow(multiplier: float, duration: float) -> void:
	_slow_multiplier = minf(multiplier, _slow_multiplier) if _slow_left > 0.0 else multiplier
	_slow_left = maxf(_slow_left, duration)


func is_slowed() -> bool:
	return _slow_left > 0.0


const BURN_TICK_TIME := 0.5


## 화상: duration 동안 0.5초마다 tick_damage 의 지속 피해.
## 실제 피해 = tick_damage × GameManager.get_dot_multiplier() (방어력이 높을수록 덜 들어옴, 최소 1).
## 가드·대시 무적으로 막을 수 없고, 펜던트의 체력 재생으로 버팁니다.
func apply_burn(tick_damage: int, duration: float) -> void:
	if _is_dead or tick_damage <= 0:
		return
	if _burn_left <= 0.0:
		_burn_tick_timer = BURN_TICK_TIME
	_burn_tick_damage = maxi(_burn_tick_damage if _burn_left > 0.0 else 0, tick_damage)
	_burn_left = maxf(_burn_left, duration)


func is_burning() -> bool:
	return _burn_left > 0.0


## 화상 1회분 실제 피해 (방어력 반영)
func get_burn_tick_damage() -> int:
	return maxi(1, roundi(_burn_tick_damage * GameManager.get_dot_multiplier()))


## 적 장판(점액 바닥 등) 위에 있는 동안 매 프레임 호출 → 상태 표시
func mark_floor_status(text: String) -> void:
	_floor_status = text
	_floor_status_left = 0.15


func _update_status(delta: float) -> void:
	if _burn_left > 0.0:
		_burn_left = maxf(_burn_left - delta, 0.0)
		_burn_tick_timer -= delta
		if _burn_tick_timer <= 0.0:
			_burn_tick_timer += BURN_TICK_TIME
			var dmg := get_burn_tick_damage()
			GameManager.damage_player(dmg)
			FloatingText.spawn(self, global_position + Vector2(randf_range(-6, 6), -18), str(dmg), Color(1.0, 0.55, 0.2))
	_floor_status_left = maxf(_floor_status_left - delta, 0.0)
	_charm_left = maxf(_charm_left - delta, 0.0)
	_since_dash += delta
	_update_death_marks(delta)
	if _charm_particles != null:
		_charm_particles.emitting = _charm_left > 0.0
	if _burn_particles != null:
		_burn_particles.emitting = _burn_left > 0.0
	var parts := PackedStringArray()
	if _execution_left >= 0.0:
		parts.append("사형 선고 %.1f초! (대시로 회피)" % _execution_left)
	elif death_marks > 0:
		parts.append("죽음의 낙인 %d/%d" % [death_marks, DEATH_MARK_MAX])
	if _charm_left > 0.0:
		parts.append("매혹 %.1f초 (조작 불가)" % _charm_left)
	if _burn_left > 0.0:
		parts.append("화상 %.1f초 (0.5초마다 -%d)" % [_burn_left, get_burn_tick_damage()])
	if _floor_status_left > 0.0:
		parts.append(_floor_status)
	elif _slow_left > 0.0:
		parts.append("감속")
	var text := "  ·  ".join(parts)
	if text != _status_text:
		_status_text = text
		GameManager.set_player_status(text)


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
	# 방패 + 투구 방어력 (최소 1은 들어감)
	GameManager.damage_player(maxi(1, amount - GameManager.get_total_defense()))


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
	_helmet_sprite.flip_h = _body_sprite.flip_h
	_armor_sprite.flip_h = _body_sprite.flip_h
	_boots_sprite.flip_h = _body_sprite.flip_h


func _update_timers(delta: float) -> void:
	_invincible_left = maxf(_invincible_left - delta, 0.0)
	_potion_cooldown_left = maxf(_potion_cooldown_left - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	_dash_time_left = maxf(_dash_time_left - delta, 0.0)
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
		GameManager.set_dash_cooldown(_dash_cooldown_left, dash_cooldown)


func _start_dash(input_dir: Vector2) -> void:
	_since_dash = 0.0
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
	elif _execution_left >= 0.0:
		_body_sprite.modulate = Color(0.75, 0.5, 1.0) if int(_anim_time * 12.0) % 2 == 0 else Color(0.4, 0.3, 0.6)  # 사형 선고
	elif _charm_left > 0.0:
		_body_sprite.modulate = Color(1.0, 0.6, 0.9)  # 매혹
	elif _burn_left > 0.0:
		_body_sprite.modulate = Color(1.0, 0.7, 0.5)  # 화상
	elif _floor_status_left > 0.0:
		_body_sprite.modulate = Color(0.7, 1.0, 0.6)  # 점액 바닥
	elif _slow_left > 0.0:
		_body_sprite.modulate = Color(0.6, 0.85, 1.0)  # 빙결 감속
	else:
		_body_sprite.modulate = Color.WHITE

	# 무기: 원거리 반동 / 가드 중에는 뒤로 젖힘
	_weapon_kick = move_toward(_weapon_kick, 0.0, delta * 8.0)
	_weapon_sprite.position.x = weapon_orbit_radius - _weapon_kick * 3.0
	var weapon_rest := _weapon_rest_angle + (-1.3 if guarding else 0.0)
	_weapon_sprite.rotation = lerp_angle(_weapon_sprite.rotation, weapon_rest, 1.0 - exp(-25.0 * delta))

	# 방패: 평소엔 옆구리, 가드 중엔 정면으로
	var shield_pos := Vector2(9.0, 0.0) if guarding else Vector2(-1.0, 5.0)
	var shield_scale := Vector2.ONE if guarding else Vector2(0.7, 0.7)
	var w := 1.0 - exp(-30.0 * delta)
	_shield_sprite.position = _shield_sprite.position.lerp(shield_pos, w)
	_shield_sprite.scale = _shield_sprite.scale.lerp(shield_scale, w)
	# 퍼펙트 가드(패링) 판정 중에는 방패가 금빛으로 빛나서 타이밍을 알려 줌
	if _guard.is_broken():
		_shield_sprite.modulate = Color(0.5, 0.5, 0.5, 0.6)
	elif _guard.is_in_perfect_window():
		_shield_sprite.modulate = Color(1.6, 1.5, 0.9)
	else:
		_shield_sprite.modulate = Color.WHITE
	# 평소엔 몸 뒤(무기·활을 가리지 않게), 가드 중엔 몸 앞
	_shield_sprite.z_index = 0 if guarding else -1

	# 카메라 흔들림
	_shake_strength = move_toward(_shake_strength, 0.0, delta * 20.0)
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength


func _setup_windup_visuals() -> void:
	_burn_particles = Fx.make_aura(Elements.color_of(Elements.Type.FIRE), 10, 5.0, Vector2(0, -60), 0.5)
	_burn_particles.position = Vector2(0, -6)
	_burn_particles.z_index = 3
	_burn_particles.emitting = false
	add_child(_burn_particles)
	_charm_particles = Fx.make_aura(Color(1.0, 0.45, 0.8), 8, 6.0, Vector2(0, -30), 0.7)
	_charm_particles.position = Vector2(0, -14)
	_charm_particles.z_index = 3
	_charm_particles.emitting = false
	add_child(_charm_particles)
	_target_ring = TargetRing.new()
	_target_ring.name = "TargetRing"
	add_child(_target_ring)
	_bow_string.hide()
	_nocked_arrow.hide()
	_charge_orb.hide()
	_charge_orb.material = Fx.additive_material()
	_chant_label.hide()
	# 지팡이 구슬로 빨려 들어가는 마력 입자 (구슬 위치 기준 로컬 좌표)
	_charge_particles = CPUParticles2D.new()
	_charge_particles.texture = Fx.SPARK_TEXTURE
	_charge_particles.material = Fx.additive_material()
	_charge_particles.emitting = false
	_charge_particles.local_coords = true
	_charge_particles.lifetime = 0.35
	_charge_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_charge_particles.emission_sphere_radius = 14.0
	_charge_particles.spread = 180.0
	_charge_particles.gravity = Vector2.ZERO
	_charge_particles.radial_accel_min = -220.0
	_charge_particles.radial_accel_max = -160.0
	_charge_particles.scale_amount_min = 0.4
	_charge_particles.scale_amount_max = 0.9
	_charge_orb.add_sibling.call_deferred(_charge_particles)
	_charge_particles.position = _charge_orb.position


func _update_bow_string(progress: float) -> void:
	if _windup_weapon != null and not _windup_weapon.is_bow() and progress > 0.0:
		return
	var base := _weapon_sprite.position
	var top := base + BOW_TIP_TOP
	var bottom := base + BOW_TIP_BOTTOM
	var nock := Vector2(top.x - BOW_MAX_PULL * progress, 0.0)
	_bow_string.points = PackedVector2Array([top, nock, bottom])
	# arrow.png 는 꼬리가 텍스처 중심에서 -6.5px 에 있음
	_nocked_arrow.position = Vector2(nock.x + 6.5, 0.0)


func _on_weapon_equipped(weapon: WeaponData) -> void:
	if _windup_weapon != null:
		end_windup(false)
	if weapon == null:
		_weapon_sprite.texture = null
		_bow_string.hide()
		return
	var uses_held := weapon.held_texture != null
	_weapon_sprite.texture = weapon.held_texture if uses_held else weapon.icon
	_weapon_rest_angle = 0.0 if uses_held else WEAPON_REST_ANGLE
	_weapon_sprite.rotation = _weapon_rest_angle
	_bow_string.visible = weapon.is_bow()
	if weapon.is_bow():
		_update_bow_string(0.0)


func _on_boots_equipped(boots: BootsData) -> void:
	_boots_sprite.texture = boots.worn_texture if boots != null else null
	_boots_sprite.visible = boots != null


func _on_armor_equipped(armor: ArmorData) -> void:
	_armor_sprite.texture = armor.worn_texture if armor != null else null
	_armor_sprite.visible = armor != null


func _on_helmet_equipped(helmet: HelmetData) -> void:
	_helmet_sprite.texture = helmet.worn_texture if helmet != null else null
	_helmet_sprite.visible = helmet != null


func _on_shield_equipped(shield: ShieldData) -> void:
	_shield_sprite.texture = shield.icon if shield != null else null
	_shield_sprite.visible = shield != null


func _on_player_damaged(_amount: int) -> void:
	shake_camera(4.0)


func _on_potion_used(_potion: PotionData, healed: int) -> void:
	var heal_color := Color(0.45, 1.0, 0.5)
	FloatingText.spawn(self, global_position + Vector2(0, -18), "+%d HP" % healed, heal_color, true)
	Fx.burst(self, global_position + Vector2(0, -8), heal_color, 16, 40.0, 0.6, Vector2(0, -60))
	Fx.flash(self, global_position + Vector2(0, -8), heal_color, 14.0, 0.3)


func _on_guard_broken() -> void:
	shake_camera(5.0)
	FloatingText.spawn(self, global_position + Vector2(0, -18), "가드 브레이크!", Color(1.0, 0.4, 0.4), true)


func _on_player_died() -> void:
	_is_dead = true
	_weapon_pivot.hide()
	var tween := create_tween()
	tween.tween_property(_body_sprite, "rotation", PI * 0.5, 0.3)
	tween.parallel().tween_property(_body_sprite, "modulate", Color(0.5, 0.5, 0.5, 1.0), 0.3)
