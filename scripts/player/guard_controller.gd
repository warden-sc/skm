class_name GuardController
extends Node
## 방패 가드 담당 컴포넌트 (Player 의 자식)
##
## ⚠️ AttackController 와 마찬가지로 "Node" 상속입니다.
##    방향 정보는 player.get_aim_direction() 으로만 얻고, self 에서 Node2D 함수를 호출하지 않습니다.
##
## 우클릭(guard)을 누르고 있는 동안 정면(block_arc_degrees) 공격을 막습니다.
##   - 일반 가드  : 피해의 block_ratio 만큼을 가드 게이지가 대신 받음
##   - 퍼펙트 가드 : 가드를 올린 직후 perfect_guard_window 초 안에 맞으면 피해 0 (Player 가 탄 반사/적 기절 처리)
##   - 가드 게이지가 바닥나면 가드 브레이크 → guard_break_time 동안 가드 불가

enum BlockResult { NONE, BLOCKED, PARRIED }

## 가드로 막은 직후 연속 피격(접촉 데미지 등)을 무료로 막아주는 시간
const BLOCK_GRACE_TIME := 0.25
## 마지막으로 막은 뒤 게이지가 다시 차기 시작하기까지의 대기 시간
const REGEN_DELAY := 0.6

## 비워두면 부모 노드를 Player 로 사용합니다.
@export var player: Player

var guard: float = 0.0

var _guarding: bool = false
var _guard_time: float = 0.0
var _broken_left: float = 0.0
var _grace_left: float = 0.0
var _regen_delay_left: float = 0.0
var _shield: ShieldData


func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	assert(player != null, "GuardController 는 Player(CharacterBody2D) 의 자식이어야 합니다.")
	GameManager.shield_equipped.connect(_on_shield_equipped)
	_on_shield_equipped(GameManager.equipped_shield)


func _physics_process(delta: float) -> void:
	_grace_left = maxf(_grace_left - delta, 0.0)
	_broken_left = maxf(_broken_left - delta, 0.0)
	if _shield == null:
		_guarding = false
		return

	var wants_guard := Input.is_action_pressed(&"guard") and player.can_guard() and _broken_left <= 0.0
	if wants_guard and not _guarding:
		_guarding = true
		_guard_time = 0.0
	elif not wants_guard:
		_guarding = false

	if _guarding:
		_guard_time += delta
	else:
		_regen_delay_left = maxf(_regen_delay_left - delta, 0.0)
		if _regen_delay_left <= 0.0:
			guard = minf(guard + _shield.guard_regen * delta, _shield.max_guard)

	GameManager.set_guard(guard, _shield.max_guard)


func is_guarding() -> bool:
	return _guarding


func is_broken() -> bool:
	return _broken_left > 0.0


## 퍼펙트 가드 판정 시간 안인지 (연출용)
func is_in_perfect_window() -> bool:
	return _guarding and _shield != null and _guard_time <= _shield.perfect_guard_window


func get_move_multiplier() -> float:
	return _shield.guard_move_multiplier if _guarding and _shield != null else 1.0


## 방패의 상시 방어력 (가드를 하지 않아도 적용)
func get_defense() -> int:
	return _shield.defense if _shield != null else 0


## Player.take_hit() 에서 호출.
## hit_dir: 플레이어 → 공격 지점 방향 (단위 벡터)
## 반환: { "result": BlockResult, "damage": 실제로 들어갈 피해 }
func evaluate_hit(amount: int, hit_dir: Vector2) -> Dictionary:
	var unblocked := {"result": BlockResult.NONE, "damage": amount}
	if not _guarding or _shield == null:
		return unblocked
	var half_arc := deg_to_rad(_shield.block_arc_degrees) * 0.5
	if absf(player.get_aim_direction().angle_to(hit_dir)) > half_arc:
		return unblocked  # 옆/뒤에서 맞음

	if _guard_time <= _shield.perfect_guard_window:
		_grace_left = BLOCK_GRACE_TIME
		return {"result": BlockResult.PARRIED, "damage": 0}

	if _grace_left > 0.0:
		return {"result": BlockResult.BLOCKED, "damage": 0}

	_grace_left = BLOCK_GRACE_TIME
	_regen_delay_left = REGEN_DELAY
	var wanted_block := float(amount) * _shield.block_ratio
	var absorbed := minf(wanted_block, guard)
	guard -= absorbed
	var damage := amount - roundi(absorbed)

	if guard <= 0.0:
		guard = 0.0
		_guarding = false
		_broken_left = _shield.guard_break_time
		GameManager.report_guard_broken()
	GameManager.set_guard(guard, _shield.max_guard)
	return {"result": BlockResult.BLOCKED, "damage": damage}


func _on_shield_equipped(shield: ShieldData) -> void:
	_shield = shield
	_guarding = false
	if shield == null:
		guard = 0.0
		GameManager.set_guard(0.0, 0.0)
		return
	guard = shield.max_guard
	GameManager.set_guard(guard, shield.max_guard)
