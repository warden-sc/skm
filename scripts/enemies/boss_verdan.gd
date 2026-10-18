class_name BossVerdan
extends PatternBoss
## 34스테이지 보스: 화염의 드래곤 베르단 — 용암 화산의 심장에서 깨어난 붉은 용.
##   BREATH  : 화염 숨결 — 바라보는 쪽으로 길게 뿜는 불꽃 (뿜는 동안 방향 고정) + 그 앞에 용암 웅덩이
##   METEOR  : 분화 — 화산탄이 떨어지고 떨어진 자리에 용암 웅덩이
##   TAIL    : 꼬리 후려치기 — 등 뒤쪽 넓은 장판 (역린을 노리는 플레이어 견제)
##   SUMMON  : 살라만더 · 불꽃 술사 호출
##
## [기믹 1] 용암 웅덩이: 화염 공격이 떨어진 자리에 오래 남는 용암 (밟으면 화상) — 싸울수록 설 곳이 줄어듦
## [기믹 2] 역린: 등에 거꾸로 난 비늘 하나. 등 뒤에서 때리면 피해 back_multiplier 배 「역린!」
##   대신 역린을 rage_hits 번 맞으면 분노 폭발 — 몸 주위 큰 화염 폭발(예고 후) + 잠시 빨라짐
## 체력 50% 이하: 용암 웅덩이가 더 크고, 분노까지 필요한 역린 타격이 줄어듦

enum Pattern { BREATH, METEOR, TAIL, SUMMON }

const MAX_POOLS := 12

@export var minion_scenes: Array[PackedScene] = []
@export var fire_texture: Texture2D
@export var breath_damage: int = 50
@export var meteor_damage: int = 76
@export var tail_damage: int = 80
@export var nova_damage: int = 90
@export var pool_burn: int = 10
@export var pool_time: float = 22.0
@export var back_multiplier: float = 2.5
@export var rage_hits: int = 4

var _pools: Array[GroundZone] = []
var _rage: int = 0
var _rage_bursts: int = 0
var _enraged_left: float = 0.0
var _back_hits: int = 0
var _base_speed: float = 0.0
var _facing_right: bool = true


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BREATH, Pattern.METEOR, Pattern.TAIL, Pattern.SUMMON, Pattern.BREATH, Pattern.TAIL]
	_base_speed = move_speed


func get_pools() -> Array[GroundZone]:
	var alive: Array[GroundZone] = []
	for p in _pools:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			alive.append(p)
	return alive


func get_back_hits() -> int:
	return _back_hits


func get_rage() -> int:
	return _rage


func get_rage_bursts() -> int:
	return _rage_bursts


func is_enraged() -> bool:
	return _enraged_left > 0.0


func is_facing_right() -> bool:
	return _facing_right


## 등 뒤 = 바라보는 반대쪽
func is_behind(point: Vector2) -> bool:
	var dx := point.x - global_position.x
	return (dx < -6.0) if _facing_right else (dx > 6.0)


func _get_move_velocity(delta: float) -> Vector2:
	if _enraged_left > 0.0:
		_enraged_left -= delta
		if _enraged_left <= 0.0:
			move_speed = _base_speed
			chase_time = 2.0
			set_status("", Color.WHITE)
	return super._get_move_velocity(delta)


# ============================================================ 기믹 1: 용암 웅덩이
func leave_lava(at: Vector2, size: float = 24.0) -> void:
	var pools := get_pools()
	_pools = pools
	if pools.size() >= MAX_POOLS:
		pools[0].queue_free()
		_pools.remove_at(0)
	if arena_rect.has_area():
		at = at.clamp(arena_rect.position, arena_rect.end)
	var zone := GroundZone.spawn_hostile(self, at, GroundZone.Kind.FIRE, size * (1.25 if phase_two else 1.0), pool_time, 1.0, roundi(pool_burn * power), 2.0)
	if zone != null:
		_pools.append(zone)


# ============================================================ 기믹 2: 역린
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_dead() or amount <= 0:
		return
	if has_target() and is_behind(_player.global_position):
		_back_hits += 1
		_rage += 1
		FloatingText.spawn(self, global_position + Vector2(0, -56), "역린!", Color(1.0, 0.85, 0.3), true)
		super.take_damage(roundi(amount * back_multiplier), knockback, true, armor_pen)
		if not is_dead() and _rage >= rage_hits - (1 if phase_two else 0):
			rage_burst()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


## 분노 폭발 (역린을 너무 많이 맞음)
func rage_burst() -> void:
	_rage = 0
	_rage_bursts += 1
	_enraged_left = 6.0
	move_speed = _base_speed * 1.5
	chase_time = 1.0
	set_status("역린을 건드렸다! 분노", Color(1.0, 0.4, 0.2))
	GameManager.show_notice("베르단이 역린을 건드려 분노한다! 몸 주위가 폭발한다 — 물러서라", Color(1.0, 0.5, 0.25))
	for i in 12:
		telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 46.0, 26.0, 1.0, nova_damage, Elements.Type.FIRE)
	telegraph_strike(get_hit_center(), 34.0, 1.0, nova_damage, Elements.Type.FIRE)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.BREATH:
			# 바라보는 방향으로 뿜음 → 뿜는 동안 등 뒤가 빈다
			var aim := Vector2.RIGHT if _facing_right else Vector2.LEFT
			aim = aim.rotated(clampf(aim.angle_to(direction_to_player()), -0.6, 0.6))
			for w in 6:
				_after(0.2 * w, func() -> void:
					if is_dead():
						return
					for i in 5:
						shoot(aim.rotated((i - 2) * 0.14 + randf_range(-0.05, 0.05)), 160.0, breath_damage, fire_texture, 0.0, Elements.Type.FIRE))
			for i in 3:
				leave_lava(get_hit_center() + aim * (70.0 + 50.0 * i), 22.0)
			return 1.8
		Pattern.METEOR:
			for i in (7 if phase_two else 5):
				var at := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 120.0))
				telegraph_strike(at, 22.0, 0.9 + 0.1 * i, meteor_damage, Elements.Type.FIRE)
				_after(0.9 + 0.1 * i, leave_lava.bind(at, 18.0))
			return 1.6
		Pattern.TAIL:
			var back := Vector2.LEFT if _facing_right else Vector2.RIGHT
			for i in 5:
				telegraph_strike(get_hit_center() + back.rotated((i - 2) * 0.45) * 48.0, 24.0, 0.8, tail_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _update_visual(delta: float, move: Vector2) -> void:
	# 시전 중에는 방향을 바꾸지 않음 (숨결을 뿜는 동안 등 뒤를 노릴 수 있게)
	if not is_casting() and absf(move.x) > 1.0:
		_facing_right = move.x > 0.0
	sprite.flip_h = not _facing_right
	super._update_visual(delta, Vector2.ZERO)


func _die() -> void:
	for p in get_pools():
		p.queue_free()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("베르단: 화산이 깨어난다! 용암이 더 넓게 번진다", Color(1.0, 0.5, 0.25))
