class_name AttackController
extends Node
## 공격 담당 컴포넌트 (Player 의 자식)
##
## ⚠️ 이 노드는 Node2D 가 아니라 "Node" 를 상속합니다.
##    따라서 self 에서 global_position, get_global_mouse_position(), get_world_2d() 같은
##    Node2D/CanvasItem 전용 함수를 절대 호출하지 않습니다.
##    (호출하면 "Function 'get_global_mouse_position()' not found in base self" 에러)
##
##    위치/조준/물리 공간 정보는 Node2D 인 Player 에게 "타입이 지정된 참조" 로 물어봅니다:
##      player.get_attack_origin()   → 무기 피벗(플레이어 손) 전역 좌표
##      player.get_muzzle_position() → 무즐(Marker2D) 전역 좌표 (원거리)
##      player.get_aim_direction()   → 마우스 방향 단위 벡터
##      player.get_world_2d()        → 근접 판정용 물리 공간 (Player 는 Node2D 라 안전)
##
## 무기 종류별 동작:
##   - 근접(검/단검): 투사체 없음. 조준 방향 부채꼴(melee_range, melee_arc_degrees) 안의 적을 즉시 타격
##   - 활    : 좌클릭 유지 → windup_time 동안 시위를 당김 → 다 당기면 발사 (중간에 떼면 취소)
##   - 지팡이: 좌클릭 유지 → windup_time 동안 영창, 구슬에 마력이 모이고 조준한 곳에 범위 원 표시 → 시전
##             (지팡이마다 마법이 다름: 마력 폭발 / 서리 폭발 / 점액 웅덩이 / 업화 / 거대 슬라임 / 별똥별)
##   - 등급(fx level 0~3)이 높을수록 베기 잔상 / 파티클 / 폭발 이펙트가 화려해집니다.

## 근접 판정 시 적의 몸 크기를 감안해 사거리에 더해 주는 여유(px)
const MELEE_BODY_MARGIN := 6.0
## 이 거리 안에 붙은 적은 각도와 상관없이 맞습니다 (몸에 겹친 적이 빗나가지 않도록)
const MELEE_POINT_BLANK := 14.0
## 시위 당기기 / 영창 중 이동속도 배율
const WINDUP_MOVE_MULTIPLIER := 0.6
## 등급별(0~3) 근접 명중 파티클 수
const HIT_SPARKS := [4, 8, 14, 22]

## 비워두면 부모 노드를 Player 로 사용합니다.
@export var player: Player

var _cooldown_left: float = 0.0
var _pool: ProjectilePool
var _melee_shape := CircleShape2D.new()
var _windup_weapon: WeaponData
var _windup_elapsed: float = 0.0


func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	assert(player != null, "AttackController 는 Player(CharacterBody2D) 의 자식이어야 합니다.")


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _windup_weapon != null:
		_update_windup(delta)
		return
	if player == null or not player.can_attack():
		return
	if Input.is_action_pressed(&"attack") and _cooldown_left <= 0.0:
		var weapon := GameManager.equipped_weapon
		if weapon == null:
			return
		if not weapon.is_melee() and weapon.windup_time > 0.0:
			_start_windup(weapon)
		else:
			perform_attack(weapon)


func is_winding_up() -> bool:
	return _windup_weapon != null


func get_move_multiplier() -> float:
	return WINDUP_MOVE_MULTIPLIER if _windup_weapon != null else 1.0


## 준비 동작 없이 즉시 1회 공격. 공격이 나갔으면 true. (근접은 빗나가도 true)
func perform_attack(weapon: WeaponData = null) -> bool:
	if weapon == null:
		weapon = GameManager.equipped_weapon
	if weapon == null:
		return false
	var did_attack := _melee_attack(weapon) if weapon.is_melee() else _ranged_attack(weapon)
	if did_attack:
		_cooldown_left = weapon.attack_cooldown
	return did_attack


## 진행 중인 시위 당기기 / 영창 취소
func cancel_windup() -> void:
	if _windup_weapon == null:
		return
	_windup_weapon = null
	player.end_windup(false)


# ============================================================ 시위 당기기 / 영창
func _start_windup(weapon: WeaponData) -> void:
	_windup_weapon = weapon
	_windup_elapsed = 0.0
	player.begin_windup(weapon)


func _update_windup(delta: float) -> void:
	var weapon := _windup_weapon
	var still_valid := GameManager.equipped_weapon == weapon and player.can_attack() and Input.is_action_pressed(&"attack")
	if not still_valid:
		cancel_windup()
		return
	_windup_elapsed += delta
	var progress := clampf(_windup_elapsed / maxf(weapon.windup_time, 0.01), 0.0, 1.0)
	player.set_windup_progress(progress)
	if progress >= 1.0:
		_windup_weapon = null
		player.end_windup(true)
		perform_attack(weapon)


# ============================================================ 근접
func _melee_attack(weapon: WeaponData) -> bool:
	var origin := player.get_attack_origin()
	var aim := player.get_aim_direction()
	var half_arc := deg_to_rad(weapon.melee_arc_degrees) * 0.5
	var reach := weapon.melee_range + MELEE_BODY_MARGIN

	player.play_melee_swing(weapon)
	_play_swing_fx(weapon, origin, aim, half_arc)

	# 1) 원형 범위 안의 적 Area2D 를 물리 엔진에 즉시 질의
	_melee_shape.radius = reach
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _melee_shape
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = Layers.ENEMY
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results := player.get_world_2d().direct_space_state.intersect_shape(query, 32)

	# 2) 그 중 조준 방향 부채꼴 안에 있는 적만 타격 (한 번 휘두르면 적마다 1회)
	var hit_ids: Dictionary = {}
	var hit_count := 0
	for result in results:
		var enemy := result.get("collider") as Enemy
		if enemy == null or enemy.is_dead() or hit_ids.has(enemy.get_instance_id()):
			continue
		if not enemy.can_be_hit_by(Enemy.HitKind.MELEE):
			enemy.show_immune()
			continue
		var to_enemy := enemy.get_hit_center() - origin
		if to_enemy.length() > MELEE_POINT_BLANK and absf(aim.angle_to(to_enemy)) > half_arc:
			continue
		hit_ids[enemy.get_instance_id()] = true
		var roll := GameManager.roll_weapon_damage(weapon)
		var push := to_enemy.normalized() if to_enemy != Vector2.ZERO else aim
		enemy.take_damage(roll["amount"], push * weapon.knockback, roll["crit"], roll["armor_pen"])
		var level := weapon.get_fx_level()
		Fx.burst(player, enemy.get_hit_center(), weapon.effect_color, HIT_SPARKS[clampi(level, 0, 3)], 60.0 + 20.0 * level, 0.35, Elements.gravity_of(weapon.element))
		hit_count += 1

	if hit_count > 0:
		player.shake_camera(1.5 + 0.5 * hit_count)
	return true


## 등급이 높을수록 화려한 베기 이펙트 (희귀: 불티 / 레어: 원소 파티클 / 전설: 빛의 폭발 + 충격파)
func _play_swing_fx(weapon: WeaponData, origin: Vector2, aim: Vector2, half_arc: float) -> void:
	var level := weapon.get_fx_level()
	if level <= 0:
		return
	var color := weapon.effect_color
	var gravity := Elements.gravity_of(weapon.element)
	var points := 1 + level * 2
	for i in points:
		var t := 0.0 if points == 1 else float(i) / float(points - 1) - 0.5
		var pos := origin + aim.rotated(half_arc * 2.0 * t) * weapon.melee_range * 0.85
		Fx.burst(player, pos, color, 2 + level * 2, 30.0 + 15.0 * level, 0.3 + 0.1 * level, gravity, 0.8 + 0.2 * level)
	if level >= 2:
		Fx.flash(player, origin + aim * weapon.melee_range * 0.6, color, weapon.melee_range * 0.6, 0.18)
	if level >= 3:
		Fx.shockwave(player, origin, color, weapon.melee_range * 1.2, 0.25)
		player.shake_camera(2.0)


# ============================================================ 원거리
func _ranged_attack(weapon: WeaponData) -> bool:
	var pool := _get_pool()
	if pool == null:
		push_warning("AttackController: 'projectile_pool' 그룹의 ProjectilePool 을 찾을 수 없습니다.")
		return false

	var origin := player.get_muzzle_position()
	if weapon.is_staff():
		# 지팡이: 조준한 곳을 향해 지팡이별 마법 시전 (Spells 참고)
		Spells.cast_staff(player, weapon, player.get_aim_point(weapon.projectile_range))
		var staff_level := weapon.get_fx_level()
		if staff_level >= 2:
			Fx.flash(player, origin, weapon.effect_color, 6.0 + 4.0 * staff_level, 0.15)
		player.play_attack_feedback()
		return true

	var base_dir := player.get_aim_direction()
	var count := maxi(weapon.projectiles_per_shot, 1)
	var spread := deg_to_rad(weapon.spread_degrees)

	for i in count:
		# count 가 1 이면 정면, 여러 발이면 -spread/2 ~ +spread/2 로 균등 분배
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var dir := base_dir.rotated(spread * t)
		pool.spawn(ProjectileSpec.from_weapon(weapon, origin, dir, GameManager.roll_weapon_damage(weapon)))

	var level := weapon.get_fx_level()
	if level >= 2:
		Fx.flash(player, origin, weapon.effect_color, 6.0 + 4.0 * level, 0.15)
	player.play_attack_feedback()
	return true


func _get_pool() -> ProjectilePool:
	if _pool == null or not is_instance_valid(_pool):
		_pool = ProjectilePool.find(get_tree())
	return _pool
