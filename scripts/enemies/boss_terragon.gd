class_name BossTerragon
extends PatternBoss
## 32스테이지 보스: 대지의 드래곤 테라곤 — 바위 비늘로 뒤덮인 거대한 땅의 용.
##   CHARGE : 돌진 — 예고선을 따라 일직선으로 들이받음 (기믹의 핵심)
##   QUAKE  : 낙석 — 플레이어 주변에 바위가 떨어짐
##   SPIKES : 대지의 가시 — 네 방향으로 뻗는 가시 장판
##   RAISE  : 돌기둥 솟구치기 (보스방에 돌기둥 2개) + 대지의 숨결 — 모래 · 자갈 브레스 (맞으면 잠깐 느려짐)
##   SUMMON : 바위 도마뱀 · 대지 골렘 호출
##
## [기믹 1] 암석 비늘: 평소 방어력 +scale_armor → 거의 피해가 들어가지 않음
## [기믹 2] 돌기둥 유도: 돌진하던 테라곤이 돌기둥에 부딪히면 기둥이 부서지고
##   crash_stun 초 기절 + 비늘이 깨져 break_time 초 동안 방어력 보너스가 사라짐 → 이때 몰아치기
##   기둥 뒤에 서서 돌진을 기둥으로 유도하는 것이 공략. 벽에 부딪히면 그냥 멈춤
## 체력 50% 이하: 돌진이 더 빠르고 두 번 연달아 함

enum Pattern { CHARGE, QUAKE, SPIKES, RAISE, SUMMON }

const BREATH_TEXTURE := preload("res://assets/sprites/projectiles/breath_sand.png")

const MAX_PILLARS := 5

@export var minion_scenes: Array[PackedScene] = []
@export var rock_texture: Texture2D
@export var charge_damage: int = 84
@export var quake_damage: int = 70
@export var spike_damage: int = 66
@export var charge_windup: float = 1.0
@export var charge_speed: float = 330.0
@export var scale_armor: int = 50
@export var crash_stun: float = 3.0
@export var break_time: float = 7.0

var _base_defense: int = 0
var _charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _break_left: float = 0.0
var _crashes: int = 0
var _started: bool = false
var _second_charge: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.CHARGE, Pattern.QUAKE, Pattern.RAISE, Pattern.CHARGE, Pattern.SPIKES, Pattern.SUMMON]
	_base_defense = defense
	defense = _base_defense + scale_armor


func is_armor_broken() -> bool:
	return _break_left > 0.0


func is_charging() -> bool:
	return _charging


func get_crash_count() -> int:
	return _crashes


func get_pillars() -> Array[StonePillar]:
	var list: Array[StonePillar] = []
	for node in get_tree().get_nodes_in_group(&"stone_pillars"):
		var p := node as StonePillar
		if p != null and is_instance_valid(p) and not p.is_queued_for_deletion():
			list.append(p)
	return list


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for i in 3:
			raise_pillar()
	return super._get_move_velocity(delta)


## 비늘이 깨진 시간은 기절 중에도 흐름 (_get_move_velocity 는 기절 중에 불리지 않음)
func _physics_process(delta: float) -> void:
	if _break_left > 0.0 and not is_dead():
		_break_left -= delta
		if _break_left <= 0.0:
			defense = _base_defense + scale_armor
			set_status("", Color.WHITE)
			Net.announce("테라곤의 바위 비늘이 다시 굳었다", Color(0.85, 0.7, 0.5))
	super._physics_process(delta)


# ============================================================ 기믹: 돌기둥 · 돌진
## 돌기둥 하나 솟구치기 (플레이어·보스와 너무 가깝지 않은 곳)
func raise_pillar(at: Vector2 = Vector2.INF) -> StonePillar:
	var pillars := get_pillars()
	if pillars.size() >= MAX_PILLARS:
		pillars[0].crumble()
	if at == Vector2.INF:
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
		at = area.get_center()
		for i in 16:
			at = Vector2(randf_range(area.position.x + 40, area.end.x - 40), randf_range(area.position.y + 40, area.end.y - 30))
			var ok := at.distance_to(global_position) > 70.0 and (not has_target() or at.distance_to(_player.global_position) > 40.0)
			for p in get_pillars():
				if p.global_position.distance_to(at) < 60.0:
					ok = false
			if ok:
				break
	return StonePillar.raise(self, at)


## 돌진 시작 (테스트에서도 직접 호출)
func begin_charge(dir: Vector2 = Vector2.ZERO) -> void:
	_charge_dir = dir.normalized() if dir != Vector2.ZERO else direction_to_player()
	_charging = false
	set_status("돌진 준비!", Color(1.0, 0.7, 0.4))
	for i in 10:
		var at := get_hit_center() + _charge_dir * (24.0 + 26.0 * i)
		if arena_rect.has_area() and not arena_rect.has_point(at):
			break
		telegraph_strike(at, 14.0, charge_windup, charge_damage, Elements.Type.EARTH)
	_after(charge_windup, func() -> void:
		if not is_dead() and not is_stunned():
			_charging = true
			_charge_left = 1.3
			set_status("돌진!", Color(1.0, 0.6, 0.35)))


func _casting_velocity(delta: float) -> Vector2:
	if not _charging:
		return Vector2.ZERO
	_charge_left -= delta
	for p in get_pillars():
		if p.global_position.distance_to(global_position) < 28.0:
			_crash(p)
			return Vector2.ZERO
	var next := global_position + _charge_dir * charge_speed * (1.2 if phase_two else 1.0) * delta
	if _charge_left <= 0.0 or (arena_rect.has_area() and not arena_rect.has_point(next)):
		_end_charge()
		return Vector2.ZERO
	if Engine.get_physics_frames() % 4 == 0:
		Fx.burst(self, global_position, Color(0.6, 0.5, 0.4), 4, 40.0, 0.3)
	return _charge_dir * charge_speed * (1.2 if phase_two else 1.0)


func _end_charge() -> void:
	_charging = false
	if _break_left <= 0.0:
		set_status("", Color.WHITE)
	if phase_two and not _second_charge and not is_dead():
		_second_charge = true
		_bstate = BossState.CASTING
		_btimer = charge_windup + 1.4
		begin_charge()
		return
	_second_charge = false
	_btimer = minf(_btimer, 0.3)


func _crash(pillar: StonePillar) -> void:
	_charging = false
	_second_charge = false
	_crashes += 1
	pillar.crumble()
	_stun_left = crash_stun
	_break_left = break_time
	defense = _base_defense
	_btimer = 0.2
	set_status("비늘이 깨졌다! 방어력 -%d" % Balance.scale(scale_armor), Color(1.0, 0.85, 0.5))
	Net.announce("테라곤이 돌기둥에 처박혔다! 바위 비늘이 깨졌다 — 지금 몰아쳐라", Color(1.0, 0.85, 0.5))
	Fx.explosion(self, global_position, Color(0.7, 0.6, 0.45), 50.0, 2, Vector2(0, 100))
	if _player != null:
		_player.shake_camera(7.0)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.CHARGE:
			begin_charge()
			return charge_windup + 1.4
		Pattern.QUAKE:
			for i in (9 if phase_two else 6):
				var at := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0))
				telegraph_strike(at, 22.0, 0.9 + 0.1 * i, quake_damage, Elements.Type.EARTH)
			if _player != null:
				_player.shake_camera(4.0)
			return 1.5
		Pattern.SPIKES:
			for d in 4:
				var dir := Vector2.from_angle(d * PI / 2.0 + (PI / 4.0 if phase_two else 0.0))
				for i in 7:
					telegraph_strike(get_hit_center() + dir * (28.0 + 24.0 * i), 14.0, 0.6 + 0.06 * i, spike_damage, Elements.Type.EARTH)
			return 1.3
		Pattern.RAISE:
			for i in 2:
				raise_pillar()
			if has_target():
				breathe(direction_to_player(), {"texture": BREATH_TEXTURE, "damage": quake_damage - 20, "element": Elements.Type.EARTH,
					"speed": 120.0, "range": 150.0, "cone": 0.6, "sweep": 0.5, "duration": 1.0, "rate": 22.0, "grow": 2.8, "slow": 0.5, "windup": 0.4})
				for i in 4:
					shoot(direction_to_player().rotated((i - 1.5) * 0.3), 110.0, quake_damage - 20, rock_texture, 0.0, Elements.Type.EARTH)
			return 1.6
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	for p in get_pillars():
		p.crumble()
	super._die()


func _on_phase_two() -> void:
	Net.announce("테라곤이 대지를 울린다! 돌진이 더 빨라지고 연달아 들이받는다", Color(0.9, 0.7, 0.5))
