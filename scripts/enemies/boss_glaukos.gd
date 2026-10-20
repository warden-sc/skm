class_name BossGlaukos
extends PatternBoss
## 78스테이지 보스: 아테나의 올빼미 글라우크스 — 밤에도 모든 것을 꿰뚫어 보는 지혜의 여신의 새.
##   DIVE     : 표식이 붙은 플레이어에게 급강하 (큰 장판)
##   FEATHERS : 깃털 탄 — 들켰으면 플레이어를, 아니면 사방으로
##   HOOT     : 울음 — 몸 주위 고리
##   SUMMON   : 밤올빼미 · 그림자 정찰병 호출
##
## [기믹] 올빼미의 눈: 어두운 보스방, 올빼미의 시선(원뿔, gaze_range · gaze_half_angle)이 천천히 돌며 훑음
##   시선 안에 spot_time 초 넘게 있으면 들킴 → mark_time 초 동안 「표식」: 급강하가 따라옴
##   돌기둥 뒤에 숨으면 시선이 가려짐
## [기믹] 기습: 들키지 않은 채(표식 없음 · 시선 밖) 올빼미를 때리면 피해 x ambush_multiplier + 놀라서 휘청 (ambush_cooldown 초마다 한 번)
## 체력 50% 이하: 시선이 더 빨리 돌고 더 멀리 봄

enum Pattern { DIVE, FEATHERS, HOOT, SUMMON }

const PILLAR_SPOTS := [Vector2(-170, -80), Vector2(170, -80), Vector2(-170, 90), Vector2(170, 90), Vector2(0, 10)]
const PILLAR_RADIUS := 14.0

@export var minion_scenes: Array[PackedScene] = []
@export var feather_texture: Texture2D
@export var dive_damage: int = 100
@export var feather_damage: int = 62
@export var hoot_damage: int = 84
@export var gaze_range: float = 230.0
@export var gaze_half_angle: float = 0.45
@export var gaze_turn: float = 0.6
@export var spot_time: float = 0.5
@export var mark_time: float = 6.0
@export var ambush_multiplier: float = 2.0
@export var ambush_cooldown: float = 6.0

var pillars: Array[StonePillar] = []
var gaze: Vector2 = Vector2.DOWN
var _spot: float = 0.0
var _mark_left: float = 0.0
var _ambush_cd: float = 0.0
var _ambushes: int = 0
var _spotted: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.FEATHERS, Pattern.DIVE, Pattern.HOOT, Pattern.FEATHERS, Pattern.SUMMON]


func is_player_marked() -> bool:
	return _mark_left > 0.0


func get_ambush_count() -> int:
	return _ambushes


func get_spotted_count() -> int:
	return _spotted


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


## 올빼미 시선 안에 있고 돌기둥에 가려지지 않았는지
func can_see(at: Vector2) -> bool:
	var to := at - global_position
	if to.length() > gaze_range * (1.2 if phase_two else 1.0):
		return false
	if absf(gaze.angle_to(to)) > gaze_half_angle:
		return false
	for p in pillars:
		if is_instance_valid(p):
			var c := Geometry2D.get_closest_point_to_segment(p.global_position, global_position, at)
			if c.distance_to(p.global_position) < PILLAR_RADIUS:
				return false
	return true


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for spot in PILLAR_SPOTS:
			var pillar := StonePillar.raise(self, _area().get_center() + spot)
			if pillar != null:
				pillar.hits = 999999
				pillars.append(pillar)
		Net.announce("어둠 속에서 올빼미의 눈이 빛난다! 시선을 피해 돌기둥 뒤로", Color(1.0, 0.9, 0.5))
	if is_player_marked():
		return super._get_move_velocity(delta)
	# 들키지 않았으면 보스방 가운데 위쪽을 천천히 맴돎
	var perch := _area().get_center() + Vector2(cos(_anim_time * 0.4) * 120.0, -40.0 + sin(_anim_time * 0.6) * 30.0)
	super._get_move_velocity(delta)
	return global_position.direction_to(perch) * move_speed * 0.6


func _physics_process(delta: float) -> void:
	if not is_dead() and _started and has_target():
		_ambush_cd = maxf(_ambush_cd - delta, 0.0)
		if is_player_marked():
			_mark_left -= delta
			gaze = gaze.rotated(clampf(gaze.angle_to(direction_to_player()), -3.0 * delta, 3.0 * delta))
			_player.mark_floor_status("올빼미의 표식 %.0f초" % _mark_left)
		else:
			gaze = gaze.rotated(gaze_turn * (1.4 if phase_two else 1.0) * delta)
			if can_see(_player.global_position):
				_spot += delta
				if _spot >= spot_time:
					mark()
			else:
				_spot = maxf(_spot - delta, 0.0)
		set_status("표식 — 쫓는 중!" if is_player_marked() else "어둠 속을 살핌", Color(1.0, 0.85, 0.4) if is_player_marked() else Color(0.75, 0.75, 0.9))
		queue_redraw()
	super._physics_process(delta)


## 들킴 (테스트에서도 직접 호출)
func mark() -> void:
	_spot = 0.0
	_spotted += 1
	_mark_left = mark_time
	FloatingText.spawn(_player, _player.global_position + Vector2(0, -28), "들켰다!", Color(1.0, 0.85, 0.3), true)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and _started and has_target() and not is_player_marked() and not can_see(_player.global_position) and _ambush_cd <= 0.0:
		_ambushes += 1
		_ambush_cd = ambush_cooldown
		amount = roundi(amount * ambush_multiplier)
		FloatingText.spawn(self, global_position + Vector2(0, -50), "기습!", Color(1.0, 0.6, 0.4), true)
		super.take_damage(amount, knockback, is_crit, armor_pen)
		super.stun(3.0)
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.DIVE:
			if is_player_marked():
				telegraph_strike(_player.global_position, 34.0, 0.8, dive_damage, Elements.Type.NONE)
				return 1.1
			return _run_pattern(Pattern.FEATHERS)
		Pattern.FEATHERS:
			if is_player_marked():
				var dir := direction_to_player()
				for i in 7:
					shoot(dir.rotated((i - 3) * 0.14), 170.0, feather_damage, feather_texture)
			else:
				for i in 12:
					shoot(Vector2.from_angle(TAU * i / 12.0 + randf()), 120.0, feather_damage, feather_texture)
			return 1.0
		Pattern.HOOT:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 50.0, 20.0, 0.85, hoot_damage, Elements.Type.DARK)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


## 올빼미의 시선 (원뿔)
func _draw() -> void:
	if is_dead() or not _started:
		return
	var r := gaze_range * (1.2 if phase_two else 1.0)
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 9:
		pts.append(gaze.rotated(-gaze_half_angle + gaze_half_angle * 2.0 * i / 8.0) * r)
	draw_colored_polygon(pts, Color(1.0, 0.9, 0.4, 0.16 if not is_player_marked() else 0.28))


func _on_phase_two() -> void:
	Net.announce("글라우크스의 눈이 더 밝게 빛난다! 시선이 더 빨리, 더 멀리 닿는다", Color(1.0, 0.9, 0.5))
