class_name BossOphanim
extends PatternBoss
## 92스테이지 보스: 바퀴 천사 오파님 — 「바퀴 안에 바퀴가 있는 것 같고, 그 둘레에는 눈이 가득하더라」.
##   GAZE    : 눈들의 빛줄기 — 뜬 눈이 많을수록 줄기가 늘어남 (일직선)
##   ROLL    : 불바퀴 구르기 (돌진)
##   RIM     : 바퀴 테 — 몸 주위 고리
##   SUMMON  : 눈의 정령 · 불바퀴 · 보좌의 파수병 호출
##
## [기믹] 바퀴 안의 바퀴: 둘째 바퀴가 보스방을 따로 굴러다님 — mesh_interval 초마다 두 바퀴가 굴러와 mesh_time 초 동안 맞물림
##   맞물린 동안에만 피해가 제대로 들어가고, 그 밖에는 바퀴가 돌며 공격을 흘려 apart_ratio 만 들어감
## [기믹] 눈: 둘레의 눈 EYES 개 — 맞물리지 않았을 때 때리면 눈이 하나씩 eye_close_time 초 동안 감김 (뜬 눈만큼 빛줄기가 강해짐)

enum Pattern { GAZE, ROLL, RIM, SUMMON }
enum WheelState { APART, ROLLING_IN, MESHED }

const EYES := 10

@export var wheel_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var gaze_damage: int = 100
@export var roll_damage: int = 104
@export var rim_damage: int = 94
@export var mesh_interval: float = 9.0
@export var mesh_time: float = 3.5
@export var apart_ratio: float = 0.15
@export var eye_close_time: float = 6.0

var wheel: BossPart
var state: WheelState = WheelState.APART
var eyes: Array[float] = []
var _mesh_left: float = 0.0
var _orbit_time: float = 0.0
var _meshes: int = 0
var _body_frame: int = -1
var _wheel_frame: int = -1
var _relaying: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.GAZE, Pattern.ROLL, Pattern.GAZE, Pattern.RIM, Pattern.SUMMON]
	eyes.resize(EYES)
	eyes.fill(0.0)


func is_meshed() -> bool:
	return state == WheelState.MESHED


func get_mesh_count() -> int:
	return _meshes


func open_eyes() -> int:
	var n := 0
	for t in eyes:
		if t <= 0.0:
			n += 1
	return n


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		_mesh_left = mesh_interval
		if wheel_scene != null:
			request_summon(wheel_scene, _area().get_center() + Vector2(180, 0))
		_update_status()
	if state != WheelState.APART:
		return Vector2.ZERO
	if _charge_left > 0.0:
		_charge_left -= delta
		if has_target() and global_position.distance_to(_player.global_position) < 30.0:
			_player.take_hit(roundi(roll_damage * power), global_position, self)
			_charge_left = 0.0
		return _charge_dir * 290.0
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if wheel_scene != null and minion.scene_file_path == wheel_scene.resource_path:
		wheel = minion as BossPart
		wheel.boss = self
		wheel.follow_boss = false
		wheel.relay_ratio = 1.0
		wheel.bob_amount = 0.0


func has_wheel() -> bool:
	return wheel != null and is_instance_valid(wheel) and not wheel.is_dead()


## 두 바퀴가 곧장 맞물림 (테스트에서도 직접 호출)
func begin_mesh() -> void:
	if is_dead():
		return
	state = WheelState.MESHED
	_meshes += 1
	_mesh_left = mesh_time
	_charge_left = 0.0
	if has_wheel():
		wheel.global_position = global_position + Vector2(0, 2)
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.9, 0.5), 70.0, 0.4)
	GameManager.show_notice("두 바퀴가 맞물렸다! 지금 몰아쳐라", Color(1.0, 0.9, 0.5))
	_update_status()


func _end_mesh() -> void:
	state = WheelState.APART
	_mesh_left = mesh_interval * (0.7 if phase_two else 1.0)
	for i in 12:
		telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 64.0, 20.0, 0.6, rim_damage, Elements.Type.HOLY)
	_update_status()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if not _relaying:
		var frame := Engine.get_physics_frames()
		if frame == _wheel_frame:  # 같은 공격이 둘째 바퀴로 이미 들어감
			return
		_body_frame = frame
	if amount > 0 and not is_dead() and not is_meshed():
		amount = maxi(1, roundi(amount * apart_ratio))
		_close_eye()
	super.take_damage(amount, knockback, is_crit, armor_pen)


## 둘째 바퀴를 맞혔을 때 (같은 프레임에 본체와 함께 맞으면 한 번만)
func take_weak_point_hit(amount: int, knockback: Vector2, is_crit: bool, armor_pen: int, ratio: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _body_frame or frame == _wheel_frame:
		return
	_wheel_frame = frame
	_relaying = true
	take_damage(roundi(amount * ratio), knockback, is_crit, armor_pen)
	_relaying = false


func _close_eye() -> void:
	for i in EYES:
		if eyes[i] <= 0.0:
			eyes[i] = eye_close_time
			return


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		for i in EYES:
			eyes[i] = maxf(eyes[i] - delta, 0.0)
		_orbit_time += delta
		match state:
			WheelState.APART:
				_mesh_left -= delta
				if has_wheel():
					var area := _area()
					var target := area.get_center() + Vector2(cos(_orbit_time * 0.6) * area.size.x * 0.34, sin(_orbit_time * 0.9) * area.size.y * 0.3)
					wheel.global_position = wheel.global_position.move_toward(target, 120.0 * delta)
				if _mesh_left <= 0.0:
					state = WheelState.ROLLING_IN
					GameManager.show_notice("둘째 바퀴가 굴러온다…", Color(0.85, 0.85, 1.0))
			WheelState.ROLLING_IN:
				if not has_wheel():
					begin_mesh()
				else:
					wheel.global_position = wheel.global_position.move_toward(global_position, 260.0 * delta)
					if wheel.global_position.distance_to(global_position) < 6.0:
						begin_mesh()
			WheelState.MESHED:
				_mesh_left -= delta
				if has_wheel():
					wheel.global_position = global_position + Vector2(0, 2)
				if _mesh_left <= 0.0:
					_end_mesh()
		queue_redraw()
	super._physics_process(delta)


func _update_status() -> void:
	set_status("두 바퀴가 맞물림 — 지금!" if is_meshed() else "바퀴가 떨어져 돎 (피해 %d%%) · 뜬 눈 %d" % [roundi(apart_ratio * 100.0), open_eyes()], Color(1.0, 0.9, 0.55))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	_update_status()
	if is_meshed():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.GAZE:
			var beams := maxi(1, ceili(open_eyes() / 3.0))
			for k in beams:
				var d := dir.rotated((k - (beams - 1) * 0.5) * 0.3)
				for i in 12:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 13.0, 0.65 + 0.03 * i, gaze_damage, Elements.Type.HOLY)
			return 1.1
		Pattern.ROLL:
			_charge_dir = dir
			_charge_left = 0.7
			for i in 10:
				Fx.flash(self, global_position + dir * (20.0 + 20.0 * i), Color(1.0, 0.6, 0.3), 12.0, 0.4)
			return 1.2
		Pattern.RIM:
			for i in 14:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0) * 54.0, 20.0, 0.85, rim_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


## 둘레의 눈 (감긴 눈은 어둡게)
func _draw() -> void:
	if is_dead() or not _started:
		return
	var c := to_local(get_hit_center())
	for i in EYES:
		var at := c + Vector2.from_angle(TAU * i / EYES + _orbit_time * 0.8) * 34.0
		if eyes[i] > 0.0:
			draw_line(at - Vector2(2.5, 0), at + Vector2(2.5, 0), Color(0.3, 0.3, 0.4), 1.5)
		else:
			draw_circle(at, 2.5, Color(1, 1, 0.95))
			draw_circle(at, 1.2, Color(0.2, 0.4, 0.9))
	if is_meshed():
		draw_arc(c, 40.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, 0.8), 2.0)
