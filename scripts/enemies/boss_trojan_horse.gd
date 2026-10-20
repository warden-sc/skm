class_name BossTrojanHorse
extends PatternBoss
## 72스테이지 보스: 트로이 목마 — 아테나의 지혜를 빌린 오디세우스의 꾀. 배 속에 그리스 병사들을 숨긴 거대한 나무 말.
##   TRAMPLE : 바퀴를 굴려 돌진 (붉은 예고선)
##   SPEARS  : 등 위에 숨은 병사들의 창 세례
##   STOMP   : 받침대를 내려찍는 고리
##   TORCH   : 횃불 투척 — 떨어진 자리에 불 장판
##
## [기믹] 배 속의 해치: hatch_interval 초마다 배 아래 해치가 hatch_time 초 동안 열리며 그리스 병사가 쏟아짐
##   열려 있는 해치(체력 따로 없음)를 때리면 목마가 받은 피해 x hatch_multiplier
## [기믹] 바퀴 4개: 바퀴(체력 따로)를 부술수록 느려지고, 4개를 모두 부수면 멈춰 섬 → 크게 휘청 + 방어력 -stop_defense
## 체력 50% 이하: 해치가 더 자주 열림

enum Pattern { TRAMPLE, SPEARS, STOMP, TORCH }

const WHEEL_OFFSETS := [Vector2(-26, 2), Vector2(-12, 4), Vector2(12, 4), Vector2(26, 2)]

@export var wheel_scene: PackedScene
@export var hatch_scene: PackedScene
@export var soldier_scenes: Array[PackedScene] = []
@export var spear_texture: Texture2D
@export var trample_damage: int = 100
@export var spear_damage: int = 62
@export var stomp_damage: int = 88
@export var torch_damage: int = 70
@export var wheel_hp_ratio: float = 0.025
@export var hatch_interval: float = 9.0
@export var hatch_time: float = 3.5
@export var hatch_multiplier: float = 2.5
@export var stop_defense: int = 20

var wheels: Array[BossPart] = []
var hatch: BossPart
var _hatch_left: float = 5.0
var _hatch_open_left: float = 0.0
var _hatches: int = 0
var _stopped: bool = false
var _base_defense: int = 0
var _base_speed: float = 30.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_windup: float = 0.0
var _charge_left: float = 0.0
var _charge_hit: bool = false
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	_base_speed = move_speed
	pattern_order = [Pattern.TRAMPLE, Pattern.SPEARS, Pattern.STOMP, Pattern.TORCH]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_defense = defense
	_base_speed = move_speed


func get_wheels() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for w in wheels:
		if is_instance_valid(w) and not w.is_dead():
			alive.append(w)
	return alive


func is_hatch_open() -> bool:
	return _hatch_open_left > 0.0


func get_hatch_count() -> int:
	return _hatches


func is_stopped() -> bool:
	return _stopped


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if wheel_scene != null:
			for off in WHEEL_OFFSETS:
				request_summon(wheel_scene, global_position + off)
		_update_status()
	if _stopped:
		super._get_move_velocity(delta)
		return Vector2.ZERO
	if _charge_windup > 0.0 or _charge_left > 0.0:
		return _charge_velocity(delta)
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if wheel_scene != null and minion.scene_file_path == wheel_scene.resource_path:
		var wheel := minion as BossPart
		wheel.boss = self
		wheel.follow_boss = true
		wheel.anchor_offset = WHEEL_OFFSETS[wheels.size() % WHEEL_OFFSETS.size()]
		wheel.max_hp = maxi(1, roundi(max_hp * wheel_hp_ratio))
		wheel.hp = wheel.max_hp
		wheel.died.connect(_on_wheel_broken)
		wheels.append(wheel)
	elif hatch_scene != null and minion.scene_file_path == hatch_scene.resource_path:
		hatch = minion as BossPart
		hatch.boss = self
		hatch.follow_boss = true
		hatch.anchor_offset = Vector2(0, -6)
		hatch.relay_ratio = hatch_multiplier  # 열린 해치를 때리면 목마가 몇 배로 피해


func take_weak_point_hit(amount: int, knockback: Vector2, is_crit: bool, armor_pen: int, ratio: float) -> void:
	if is_hatch_open():
		FloatingText.spawn(self, global_position + Vector2(0, -50), "해치 명중!", Color(1.0, 0.8, 0.4))
		take_damage(roundi(amount * ratio), knockback, is_crit, armor_pen)


## 이동 속도: 남은 바퀴 수만큼
func _wheel_speed() -> float:
	return _base_speed * (0.25 + 0.1875 * get_wheels().size())


func _on_wheel_broken(_wheel: Enemy) -> void:
	if is_dead():
		return
	move_speed = _wheel_speed()
	if get_wheels().is_empty() and not _stopped:
		_stopped = true
		defense = maxi(_base_defense - stop_defense, 0)
		_charge_windup = 0.0
		_charge_left = 0.0
		super.stun(10.0)
		Net.announce("바퀴가 모두 부서졌다! 트로이 목마가 멈춰 선다", Color(1.0, 0.85, 0.5))
	else:
		Net.announce("바퀴 하나를 부쉈다! 목마가 느려진다 (남은 바퀴 %d)" % get_wheels().size(), Color(1.0, 0.85, 0.5))
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _hatch_open_left > 0.0:
			_hatch_open_left -= delta
			if _hatch_open_left <= 0.0:
				close_hatch()
		else:
			_hatch_left -= delta
			if _hatch_left <= 0.0:
				open_hatch()
	super._physics_process(delta)


## 해치가 열리며 병사가 쏟아짐 (테스트에서도 직접 호출)
func open_hatch() -> void:
	if is_dead() or is_hatch_open():
		return
	_hatches += 1
	_hatch_open_left = hatch_time
	if hatch_scene != null:
		request_summon(hatch_scene, global_position + Vector2(0, -6))
	for i in 3:
		if not soldier_scenes.is_empty():
			request_summon(soldier_scenes.pick_random(), global_position + Vector2(-30.0 + 30.0 * i, 30.0))
	Net.announce("목마의 해치가 열렸다! 쏟아지는 병사 사이로 해치를 노려라", Color(1.0, 0.8, 0.4))
	_update_status()


func close_hatch() -> void:
	_hatch_open_left = 0.0
	_hatch_left = hatch_interval * (0.7 if phase_two else 1.0)
	if hatch != null and is_instance_valid(hatch):
		hatch.despawn()
	hatch = null
	_update_status()


func _update_status() -> void:
	var text := "바퀴 %d개" % get_wheels().size()
	if _stopped:
		text = "멈춰 섬 (방어력 -%d)" % Balance.scale(stop_defense)
	if is_hatch_open():
		text += " · 해치 열림!"
	set_status(text, Color(1.0, 0.8, 0.5))


func _charge_velocity(delta: float) -> Vector2:
	if _charge_windup > 0.0:
		_charge_windup -= delta
		return Vector2.ZERO
	_charge_left -= delta
	if not _charge_hit and has_target() and global_position.distance_to(_player.global_position) < 40.0:
		_charge_hit = true
		_player.take_hit(roundi(trample_damage * power), global_position, self)
	return _charge_dir * (90.0 + 50.0 * get_wheels().size())


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	if pattern == Pattern.TRAMPLE and _stopped:
		pattern = Pattern.SPEARS
	match pattern:
		Pattern.TRAMPLE:
			_charge_dir = dir
			_charge_windup = 0.7
			_charge_left = 1.0
			_charge_hit = false
			for i in 12:
				Fx.flash(self, global_position + dir * (24.0 + 22.0 * i), Color(1.0, 0.55, 0.3), 14.0, 0.7)
			return 1.8
		Pattern.SPEARS:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead() or not has_target():
						return
					var aim := direction_to_player()
					for i in 7:
						shoot(aim.rotated((i - 3) * 0.15), 190.0, spear_damage, spear_texture, 0.0, Elements.Type.NONE, get_hit_center() + Vector2(0, -20)))
			return 1.0
		Pattern.STOMP:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 58.0, 22.0, 0.85, stomp_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.TORCH:
			for i in 4:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 60.0)
				telegraph_strike(at, 22.0, 0.9 + 0.1 * i, torch_damage, Elements.Type.FIRE)
				_after(0.9 + 0.1 * i, func() -> void:
					if not is_dead():
						GroundZone.spawn_hostile(self, at, GroundZone.Kind.FIRE, 20.0, 4.0, 1.0, roundi(9 * power), 2.0))
			return 1.2
	return 1.0


func _on_phase_two() -> void:
	Net.announce("목마 속에서 함성이 터져 나온다! 해치가 더 자주 열린다", Color(1.0, 0.7, 0.4))
