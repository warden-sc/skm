class_name AttackController
extends Node
## 공격 담당 컴포넌트 (Player 의 자식)
##
## ⚠️ 이 노드는 Node2D 가 아니라 "Node" 를 상속합니다.
##    따라서 self 에서 global_position, get_global_mouse_position(), look_at() 같은
##    Node2D/CanvasItem 전용 함수를 절대 호출하지 않습니다.
##    (호출하면 "Function 'get_global_mouse_position()' not found in base self" 에러)
##
##    위치/조준 정보는 Node2D 인 Player 에게 "타입이 지정된 참조" 로 물어봅니다:
##      player.get_muzzle_position()  → 무즐(Marker2D) 전역 좌표
##      player.get_aim_direction()    → 마우스 방향 단위 벡터

## 비워두면 부모 노드를 Player 로 사용합니다.
@export var player: Player

var _cooldown_left: float = 0.0
var _pool: ProjectilePool


func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	assert(player != null, "AttackController 는 Player(CharacterBody2D) 의 자식이어야 합니다.")


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if player == null or not player.can_attack():
		return
	if Input.is_action_pressed(&"attack") and _cooldown_left <= 0.0:
		fire()


## 현재 장착 무기로 1회 공격. 성공하면 true.
func fire() -> bool:
	var weapon := GameManager.equipped_weapon
	if weapon == null:
		return false
	var pool := _get_pool()
	if pool == null:
		push_warning("AttackController: 'projectile_pool' 그룹의 ProjectilePool 을 찾을 수 없습니다.")
		return false

	_cooldown_left = weapon.attack_cooldown

	var origin := player.get_muzzle_position()
	var base_dir := player.get_aim_direction()
	var count := maxi(weapon.projectiles_per_shot, 1)
	var spread := deg_to_rad(weapon.spread_degrees)

	for i in count:
		# count 가 1 이면 정면, 여러 발이면 -spread/2 ~ +spread/2 로 균등 분배
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var dir := base_dir.rotated(spread * t)
		var spec := ProjectileSpec.from_weapon(weapon, origin, dir, GameManager.damage_multiplier)
		pool.spawn(spec)

	player.play_attack_feedback()
	return true


func _get_pool() -> ProjectilePool:
	if _pool == null or not is_instance_valid(_pool):
		_pool = ProjectilePool.find(get_tree())
	return _pool
