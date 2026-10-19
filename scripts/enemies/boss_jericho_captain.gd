class_name BossJerichoCaptain
extends PatternBoss
## 95스테이지 보스: 여리고 성의 수비대장 — 굳게 닫힌 여리고 성벽 위에서 성을 지키는 장수.
##   VOLLEY   : 화살 비 — 플레이어 주변 장판
##   OIL      : 끓는 기름 붓기 — 성벽 둘레 불 장판
##   STONES   : 돌 던지기 (사방 탄)
##   SUMMON   : 여리고 궁수 · 방패병 · 성벽 경비견 호출
##
## [기믹] 성벽 위의 수비대장: 성벽이 서 있는 동안 수비대장은 성벽 위(보스방 가운데)에서 움직이지 않고, 피해는 wall_ratio 만 들어감
##   성벽 위의 궁수 4명(각각 보스 체력의 archer_hp_ratio)이 화살을 쏨
## [기믹] 일곱 바퀴: 성벽 바깥 행진 길(반경 lap_radius 밖)을 한 바퀴 돌 때마다 성벽에 금이 감 — 길 안쪽으로 들어서면 지금 바퀴는 처음부터
##   laps_needed 바퀴를 채우면 성벽이 무너지며 궁수들이 떨어지고, 수비대장이 collapse_stun 초 동안 쓰러짐 (그 뒤로는 땅에서 싸움)

enum Pattern { VOLLEY, OIL, STONES, SUMMON }

const ARCHER_SPOTS := [Vector2(0, -58), Vector2(58, 0), Vector2(0, 58), Vector2(-58, 0)]

@export var archer_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var arrow_texture: Texture2D
@export var rock_texture: Texture2D
@export var volley_damage: int = 98
@export var oil_damage: int = 94
@export var rock_damage: int = 64
@export var arrow_damage: int = 60
@export var wall_ratio: float = 0.2
@export var lap_radius: float = 120.0
@export var laps_needed: int = 7
@export var collapse_stun: float = 10.0
@export var archer_hp_ratio: float = 0.015
@export var archer_interval: float = 2.6

var wall: JerichoWall
var archers: Array[BossPart] = []
var laps: int = 0
var center: Vector2 = Vector2.ZERO
var _walled: bool = true
var _lap_progress: float = 0.0
var _last_angle: float = 0.0
var _archer_left: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.VOLLEY, Pattern.STONES, Pattern.OIL, Pattern.VOLLEY, Pattern.SUMMON]


func is_walled() -> bool:
	return _walled


func living_archers() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for a in archers:
		if is_instance_valid(a) and not a.is_dead():
			alive.append(a)
	return alive


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		center = _area().get_center()
		global_position = center + Vector2(0, 6)
		wall = JerichoWall.spawn(self, center)
		if wall != null:
			wall.lap_radius = lap_radius
		if archer_scene != null:
			for spot in ARCHER_SPOTS:
				request_summon(archer_scene, center + spot)
		_last_angle = (_player.global_position - center).angle()
		_archer_left = archer_interval
		GameManager.show_notice("굳게 닫힌 여리고 성 — 성벽 바깥 길을 일곱 바퀴 돌아라", Color(1.0, 0.9, 0.6))
		_update_status()
	if _walled:
		return Vector2.ZERO
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if archer_scene != null and minion.scene_file_path == archer_scene.resource_path:
		var a := minion as BossPart
		a.boss = self
		a.follow_boss = false
		a.max_hp = maxi(1, roundi(max_hp * archer_hp_ratio))
		a.hp = a.max_hp
		archers.append(a)


## 한 바퀴를 채움 (테스트에서도 직접 호출)
func add_lap() -> void:
	if not _walled or is_dead():
		return
	laps += 1
	_lap_progress = 0.0
	if wall != null:
		wall.cracks = laps
	Fx.shockwave(self, center, Color(1.0, 0.9, 0.6), 80.0, 0.4)
	if laps >= laps_needed:
		collapse_walls()
	else:
		GameManager.show_notice("%d바퀴 — 성벽에 금이 간다 (%d/%d)" % [laps, laps, laps_needed], Color(1.0, 0.9, 0.6))
	_update_status()


## 성벽이 무너짐 (테스트에서도 직접 호출)
func collapse_walls() -> void:
	if not _walled:
		return
	_walled = false
	if wall != null:
		wall.collapsed = true
		wall.progress = 0.0
	for a in living_archers():
		a.despawn()
	super.stun(collapse_stun)
	Fx.explosion(self, center, Color(0.75, 0.6, 0.45), 90.0, 2)
	GameManager.show_notice("일곱 바퀴를 채우자 여리고 성벽이 무너졌다! 수비대장이 성벽에서 떨어진다", Color(1.0, 0.85, 0.5))
	_update_status()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and _walled:
		amount = maxi(1, roundi(amount * wall_ratio))
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started and has_target():
		if _walled:
			var rel := _player.global_position - center
			var angle := rel.angle()
			if rel.length() < lap_radius:
				if _lap_progress != 0.0:
					_lap_progress = 0.0
					_player.mark_floor_status("행진 길 안쪽 — 이번 바퀴는 처음부터")
			else:
				_lap_progress += wrapf(angle - _last_angle, -PI, PI)
				if absf(_lap_progress) >= TAU:
					add_lap()
			_last_angle = angle
			if wall != null:
				wall.progress = absf(_lap_progress) / TAU
			_archer_left -= delta
			if _archer_left <= 0.0:
				_archer_left = archer_interval * (0.7 if phase_two else 1.0)
				for a in living_archers():
					var from := a.get_hit_center()
					shoot(from.direction_to(_player.global_position), 170.0, arrow_damage, arrow_texture, 0.0, Elements.Type.NONE, from)
	super._physics_process(delta)


func _update_status() -> void:
	if _walled:
		set_status("성벽 위 (피해 %d%%) · %d/%d바퀴" % [roundi(wall_ratio * 100.0), laps, laps_needed], Color(1.0, 0.85, 0.55))
	else:
		set_status("성벽이 무너짐", Color(1.0, 0.7, 0.5))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.VOLLEY:
			for i in 7:
				telegraph_strike(_player.global_position + Vector2.from_angle(TAU * i / 7.0) * randf_range(0.0, 60.0), 20.0, 0.9 + 0.05 * i, volley_damage, Elements.Type.NONE)
			return 1.1
		Pattern.OIL:
			var base := center if _walled else global_position
			for i in 16:
				telegraph_strike(base + Vector2.from_angle(TAU * i / 16.0) * 80.0, 18.0, 0.85, oil_damage, Elements.Type.FIRE)
			for i in 3:
				GroundZone.spawn_hostile(self, base + Vector2.from_angle(TAU * i / 3.0 + randf()) * 84.0, GroundZone.Kind.FIRE, 22.0, 5.0, 1.0, roundi(8 * power), 2.0)
			return 1.2
		Pattern.STONES:
			for i in 14:
				shoot(Vector2.from_angle(TAU * i / 14.0 + dir.angle()), 120.0, rock_damage, rock_texture, 0.0, Elements.Type.EARTH)
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), center + Vector2(-140.0 + 280.0 * i, 90.0))
			return 0.9
	return 1.0
