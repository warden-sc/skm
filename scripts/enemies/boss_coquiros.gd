class_name BossCoquiros
extends PatternBoss
## 33스테이지 보스: 얼음의 드래곤 코퀴로스 — 얼어붙은 호수 밑에서 잠들어 있던 서리의 용.
##   BREATH  : 서리 브레스 — 얼음 안개를 원뿔로 뿜고(맞으면 감속) 사이사이 얼음 조각 + 그 앞에 빙판
##   ICICLE  : 고드름 낙하 — 플레이어 주변 장판 (맞으면 감속)
##   TAIL    : 꼬리 휩쓸기 — 몸 주위 고리 장판
##   SUMMON  : 서리 정령 · 얼음 비룡 호출
##
## [기믹 1] 빙판: 숨결이 닿은 바닥이 얼어붙음 → 밟으면 미끄러져 멈추거나 방향을 틀기 어려움 (오래 남음)
## [기믹 2] 절대영도: zero_interval 마다 zero_time 초 동안 힘을 모으며 서리 결정 3개(체력 따로)를 세움
##   → 시간 안에 결정을 모두 부수면 취소 + 코퀴로스가 휘청임(기절)
##   → 못 부수면 보스방 전체에 절대영도: 최대 체력의 zero_ratio 피해(가드·대시 불가) + 빙결
## 체력 50% 이하: 결정 4개, 빙판이 더 넓게

enum Pattern { BREATH, ICICLE, TAIL, SUMMON }

const BREATH_TEXTURE := preload("res://assets/sprites/projectiles/breath_frost.png")

const MAX_ICE := 9

@export var crystal_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var shard_texture: Texture2D
@export var breath_damage: int = 48
@export var icicle_damage: int = 70
@export var tail_damage: int = 74
@export var zero_interval: float = 24.0
@export var zero_time: float = 9.0
@export var zero_ratio: float = 0.6
@export var crystal_hp_ratio: float = 0.025

var _zero_cooldown: float = 12.0
var _zero_left: float = 0.0
var _crystals: Array[BossPart] = []
var _zero_hits: int = 0
var _zero_cancels: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BREATH, Pattern.ICICLE, Pattern.TAIL, Pattern.SUMMON, Pattern.BREATH, Pattern.ICICLE]


func is_charging_zero() -> bool:
	return _zero_left > 0.0


func get_crystals() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for c in _crystals:
		if is_instance_valid(c) and not c.is_dead():
			alive.append(c)
	return alive


func get_zero_hits() -> int:
	return _zero_hits


func get_zero_cancels() -> int:
	return _zero_cancels


func get_ice_floors() -> Array[IceFloor]:
	var list: Array[IceFloor] = []
	for node in get_tree().get_nodes_in_group(&"ice_floors"):
		var ice := node as IceFloor
		if ice != null and not ice.is_queued_for_deletion():
			list.append(ice)
	return list


func _get_move_velocity(delta: float) -> Vector2:
	if _zero_left > 0.0:
		_zero_left -= delta
		set_status("절대영도 %.1f초 — 서리 결정 %d개를 부숴라!" % [maxf(_zero_left, 0.0), get_crystals().size()], Color(0.7, 0.9, 1.0))
		if get_crystals().is_empty():
			_cancel_zero()
		elif _zero_left <= 0.0:
			_release_zero()
		return Vector2.ZERO
	if has_target():
		_zero_cooldown -= delta
		if _zero_cooldown <= 0.0 and not is_casting():
			begin_absolute_zero()
			return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹 1: 빙판
func freeze_floor(at: Vector2, size: float) -> void:
	var ices := get_ice_floors()
	if ices.size() >= MAX_ICE:
		ices[0].queue_free()
	if arena_rect.has_area():
		at = at.clamp(arena_rect.position, arena_rect.end)
	IceFloor.spawn(self, at, size * (1.25 if phase_two else 1.0), 20.0)


# ============================================================ 기믹 2: 절대영도
func begin_absolute_zero() -> void:
	if _zero_left > 0.0 or is_dead() or crystal_scene == null:
		return
	_zero_left = zero_time
	_zero_cooldown = zero_interval
	_crystals.clear()
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
	var count := 4 if phase_two else 3
	for i in count:
		var a := TAU * i / count + randf_range(-0.3, 0.3)
		var at := (area.get_center() + Vector2(cos(a) * area.size.x * 0.36, sin(a) * area.size.y * 0.34)).clamp(area.position + Vector2(20, 20), area.end - Vector2(20, 10))
		request_summon(crystal_scene, at)
	Net.announce("코퀴로스가 절대영도를 모은다! %d초 안에 서리 결정을 모두 부숴라" % roundi(zero_time), Color(0.7, 0.9, 1.0))
	Fx.frost_nova(self, get_hit_center(), 60.0, 2)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and _zero_left > 0.0:
		var c := minion as BossPart
		c.boss = self
		c.follow_boss = false
		c.max_hp = maxi(1, roundi(max_hp * crystal_hp_ratio))
		_crystals.append(c)


func _cancel_zero() -> void:
	_zero_left = 0.0
	_zero_cancels += 1
	_crystals.clear()
	_stun_left = 2.5
	set_status("절대영도가 흩어졌다!", Color(0.8, 1.0, 1.0))
	Net.announce("서리 결정을 모두 부쉈다! 코퀴로스가 휘청인다", Color(0.8, 1.0, 1.0))
	_after(1.5, func() -> void:
		if _zero_left <= 0.0 and get_status_text().begins_with("절대영도가"):
			set_status("", Color.WHITE))


func _release_zero() -> void:
	_zero_left = 0.0
	for c in get_crystals():
		c.despawn()
	_crystals.clear()
	set_status("", Color.WHITE)
	Fx.frost_nova(self, get_hit_center(), 200.0, 3)
	Net.announce("절대영도! 모든 것이 얼어붙었다", Color(0.6, 0.85, 1.0))
	if has_target():
		if _player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * zero_ratio)), get_hit_center(), false) == Player.HitResult.DAMAGED:
			_zero_hits += 1
			_player.apply_charm(2.0, null, "빙결")
		_player.shake_camera(8.0)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.BREATH:
			var aim := direction_to_player()
			breathe(aim, {"texture": BREATH_TEXTURE, "damage": breath_damage, "element": Elements.Type.ICE, "slow": 0.8,
				"speed": 130.0, "range": 165.0, "cone": 0.55, "sweep": 0.6, "duration": 1.0, "rate": 24.0, "grow": 2.8, "windup": 0.35})
			for w in 3:
				_after(0.4 + 0.25 * w, func() -> void:
					if is_dead():
						return
					for i in 2:
						shoot(aim.rotated((i - 0.5) * 0.35 + randf_range(-0.1, 0.1)), 150.0, breath_damage, shard_texture, 0.8, Elements.Type.ICE))
			for i in 3:
				freeze_floor(get_hit_center() + aim * (60.0 + 55.0 * i), 30.0 + 6.0 * i)
			return 1.5
		Pattern.ICICLE:
			for i in (8 if phase_two else 6):
				var at := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(28.0, 95.0))
				telegraph_strike(at, 18.0, 0.85 + 0.08 * i, icicle_damage, Elements.Type.ICE, 1.2)
			return 1.4
		Pattern.TAIL:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 52.0, 20.0, 0.85, tail_damage, Elements.Type.ICE)
			freeze_floor(global_position, 46.0)
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	for c in get_crystals():
		c.despawn()
	for ice in get_ice_floors():
		ice.queue_free()
	super._die()


func _on_phase_two() -> void:
	Net.announce("코퀴로스: 호수의 밑바닥처럼 차갑게 잠들어라… 서리 결정이 늘어난다", Color(0.7, 0.9, 1.0))
