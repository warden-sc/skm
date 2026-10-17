class_name BossLegion
extends PatternBoss
## 12스테이지 보스: 폭주한 마도기신 레기온 — 마도 공장이 만든 거대 마도 병기. 제어 회로가 타 버려 폭주 중.
##   LASER   : 회전 레이저 — 가슴의 마도코어에서 레이저 한 줄기를 쏜 뒤, 그 레이저가 360도 회전 (쿨타임마다)
##   MISSILE : 마력 포탄 — 플레이어 주변에 예고 장판 여러 개
##   SLAM    : 양 주먹 내려찍기 — 앞쪽 일직선 충격파
##   VOLLEY  : 마력탄 고리
##   SUMMON  : 마도 인형 · 마도 드론 출격
##
## [기믹] 마도코어: 가슴에 박힌 마도코어(약점)를 맞히면 피해 1.5배.
##   코어는 따로 체력이 없고, 맞은 공격을 1.5배로 레기온에게 넘깁니다 (BossPart.relay_ratio).
##   한 번의 공격이 몸과 코어에 함께 닿아도 두 번 들어가지 않고 1.5배만 들어갑니다.
## 체력 50% 이하: 레이저가 더 빨리 돌고, 도는 방향이 번갈아 바뀜

enum Pattern { LASER, MISSILE, SLAM, VOLLEY, SUMMON }

const CORE_MULTIPLIER := 1.5

@export var core_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var bolt_texture: Texture2D
@export var laser_damage: int = 46
@export var laser_time: float = 3.2
@export var laser_interval: float = 11.0
@export var missile_damage: int = 42
@export var slam_damage: int = 50
@export var volley_damage: int = 30
## 코어 위치 (몸 기준)
@export var core_offset: Vector2 = Vector2(0, -32)

var core: BossPart
var _core_requested: bool = false
var _laser: LaserSweep
var _laser_cooldown: float = 4.0
var _laser_dir_sign: float = 1.0
var _body_hit_frame: int = -1
var _core_hit_frame: int = -1
var _core_hits: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.MISSILE, Pattern.SLAM, Pattern.VOLLEY, Pattern.SUMMON, Pattern.MISSILE, Pattern.SLAM]


func get_core() -> BossPart:
	return core if core != null and is_instance_valid(core) else null


func get_laser() -> LaserSweep:
	return _laser if _laser != null and is_instance_valid(_laser) else null


func get_core_hits() -> int:
	return _core_hits


func _get_move_velocity(delta: float) -> Vector2:
	if not _core_requested and core_scene != null:
		_core_requested = true
		request_summon(core_scene, global_position + core_offset)
	# 회전 레이저는 패턴 순서와 상관없이 쿨타임마다 (다른 패턴 시전 중이 아닐 때)
	if not is_casting() and has_target():
		_laser_cooldown -= delta
		if _laser_cooldown <= 0.0:
			cast(Pattern.LASER)
			return Vector2.ZERO
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and core == null:
		core = minion as BossPart
		core.boss = self
		core.anchor_offset = core_offset
		core.relay_ratio = CORE_MULTIPLIER
		core.z_index = 2  # 몸 위로 보이도록 (y 정렬로는 몸 뒤에 그려짐)


# ============================================================ 기믹: 마도코어
## 코어(약점)에 맞은 공격: 1.5배 (같은 공격이 몸에도 닿았다면 차액만)
func take_weak_point_hit(amount: int, knockback: Vector2, is_crit: bool, armor_pen: int, ratio: float) -> void:
	if is_dead():
		return
	var frame := Engine.get_physics_frames()
	if frame == _core_hit_frame:
		return
	_core_hit_frame = frame
	var full := calc_damage(roundi(amount * ratio), armor_pen)
	if frame == _body_hit_frame:
		full -= calc_damage(amount, armor_pen)
	_core_hits += 1
	FloatingText.spawn(self, get_hit_center() + Vector2(0, -36), "약점!", Color(0.5, 0.9, 1.0), true)
	if core != null:
		Fx.burst(self, core.get_hit_center(), Color(0.6, 0.9, 1.0), 6, 40.0, 0.25)
	if full > 0:
		super.take_damage(full, knockback, is_crit, 999999)  # 이미 방어력을 반영한 값


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _core_hit_frame:
		return  # 같은 공격이 코어에 이미 1.5배로 들어감
	_body_hit_frame = frame
	super.take_damage(amount, knockback, is_crit, armor_pen)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.LASER:
			return fire_laser()
		Pattern.MISSILE:
			set_status("마력 포탄 발사", Color(1.0, 0.6, 0.4))
			if has_target():
				var center := _player.global_position
				telegraph_strike(center, 24.0, 1.0, missile_damage, Elements.Type.FIRE)
				for i in (6 if phase_two else 4):
					telegraph_strike(center + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0), 22.0, randf_range(0.9, 1.4), missile_damage, Elements.Type.FIRE)
			_after(1.0, set_status.bind("", Color.WHITE))
			return 1.4
		Pattern.SLAM:
			var dir := direction_to_player()
			for i in 6:
				telegraph_strike(get_hit_center() + dir * (36.0 + 28.0 * i), 22.0, 0.75 + 0.07 * i, slam_damage, Elements.Type.LIGHTNING)
			if _player != null:
				_after(0.75, _player.shake_camera.bind(4.0))
			return 1.4
		Pattern.VOLLEY:
			for w in (2 if phase_two else 1):
				_after(0.35 * w, _volley.bind(w))
			return 1.2
		Pattern.SUMMON:
			set_status("마도 병기 출격", Color(0.6, 0.85, 1.0))
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-70.0 + 140.0 * i, 30.0))
			_after(1.0, set_status.bind("", Color.WHITE))
			return 1.0
	return 1.0


## 회전 레이저 발사 (반환값 = 시전 시간). 테스트에서도 직접 호출
func fire_laser() -> float:
	_laser_cooldown = laser_interval * (0.8 if phase_two else 1.0)
	var spin := laser_time * (0.8 if phase_two else 1.0)
	if phase_two:
		_laser_dir_sign = -_laser_dir_sign
	set_status("마도코어 과부하: 회전 레이저!", Color(1.0, 0.4, 0.4))
	GameManager.show_notice("레기온의 회전 레이저! 레이저를 따라 돌거나 대시로 넘어라", Color(1.0, 0.5, 0.5))
	var start := direction_to_player().angle() if has_target() else 0.0
	_laser = LaserSweep.spawn(self, start, TAU * _laser_dir_sign, spin, laser_damage, 280.0, Color(1.0, 0.3, 0.35), get_core())
	_after(spin + 0.8, set_status.bind("", Color.WHITE))
	return spin + 1.0


func _volley(wave: int) -> void:
	if is_dead():
		return
	for i in 16:
		shoot(Vector2.RIGHT.rotated(TAU * i / 16.0 + wave * 0.2), 110.0, volley_damage, bolt_texture, 0.0, Elements.Type.ARCANE)


func _on_phase_two() -> void:
	GameManager.show_notice("레기온 폭주 가속! 레이저가 더 빨라지고 방향이 바뀐다", Color(1.0, 0.45, 0.45))
	base_tint = Color(1.2, 0.85, 0.85)
