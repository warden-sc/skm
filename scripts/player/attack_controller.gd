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
##   - 원거리(활/지팡이): ProjectilePool 에서 투사체 발사

## 근접 판정 시 적의 몸 크기를 감안해 사거리에 더해 주는 여유(px)
const MELEE_BODY_MARGIN := 6.0
## 이 거리 안에 붙은 적은 각도와 상관없이 맞습니다 (몸에 겹친 적이 빗나가지 않도록)
const MELEE_POINT_BLANK := 10.0

## 비워두면 부모 노드를 Player 로 사용합니다.
@export var player: Player

var _cooldown_left: float = 0.0
var _pool: ProjectilePool
var _melee_shape := CircleShape2D.new()


func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	assert(player != null, "AttackController 는 Player(CharacterBody2D) 의 자식이어야 합니다.")


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if player == null or not player.can_attack():
		return
	if Input.is_action_pressed(&"attack") and _cooldown_left <= 0.0:
		attack()


## 현재 장착 무기로 1회 공격. 공격이 나갔으면 true. (근접은 빗나가도 true)
func attack() -> bool:
	var weapon := GameManager.equipped_weapon
	if weapon == null:
		return false
	var did_attack := _melee_attack(weapon) if weapon.is_melee() else _ranged_attack(weapon)
	if did_attack:
		_cooldown_left = weapon.attack_cooldown
	return did_attack


# ============================================================ 근접
func _melee_attack(weapon: WeaponData) -> bool:
	var origin := player.get_attack_origin()
	var aim := player.get_aim_direction()
	var half_arc := deg_to_rad(weapon.melee_arc_degrees) * 0.5
	var reach := weapon.melee_range + MELEE_BODY_MARGIN

	player.play_melee_swing(weapon)

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
		var to_enemy := enemy.get_hit_center() - origin
		if to_enemy.length() > MELEE_POINT_BLANK and absf(aim.angle_to(to_enemy)) > half_arc:
			continue
		hit_ids[enemy.get_instance_id()] = true
		var roll := weapon.roll_damage(GameManager.damage_multiplier)
		var push := to_enemy.normalized() if to_enemy != Vector2.ZERO else aim
		enemy.take_damage(roll["amount"], push * weapon.knockback, roll["crit"])
		hit_count += 1

	if hit_count > 0:
		player.shake_camera(1.5 + 0.5 * hit_count)
	return true


# ============================================================ 원거리
func _ranged_attack(weapon: WeaponData) -> bool:
	var pool := _get_pool()
	if pool == null:
		push_warning("AttackController: 'projectile_pool' 그룹의 ProjectilePool 을 찾을 수 없습니다.")
		return false

	var origin := player.get_muzzle_position()
	var base_dir := player.get_aim_direction()
	var count := maxi(weapon.projectiles_per_shot, 1)
	var spread := deg_to_rad(weapon.spread_degrees)

	for i in count:
		# count 가 1 이면 정면, 여러 발이면 -spread/2 ~ +spread/2 로 균등 분배
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var dir := base_dir.rotated(spread * t)
		pool.spawn(ProjectileSpec.from_weapon(weapon, origin, dir, GameManager.damage_multiplier))

	player.play_attack_feedback()
	return true


func _get_pool() -> ProjectilePool:
	if _pool == null or not is_instance_valid(_pool):
		_pool = ProjectilePool.find(get_tree())
	return _pool
