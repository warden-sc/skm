class_name BossMinotaur
extends PatternBoss
## 39스테이지 보스: 미궁의 미노타우로스 — 크노소스 미궁 깊은 곳에 갇힌 황소 머리의 괴물.
##   CHARGE : 돌진 — 예고선을 따라 들이받음 (기믹의 핵심)
##   AXE    : 양날 도끼 — 앞쪽 부채꼴 장판
##   STOMP  : 발 구르기 — 몸 주위 고리 장판 + 돌 파편
##   SUMMON : 황소 전사 · 미궁 망령 호출
##
## [기믹 1] 움직이는 미궁: 보스방에 돌벽(몸·탄을 막음)이 서고, maze_interval 초마다 점선으로 예고한 자리로 옮겨 감
## [기믹 2] 뿔 박힘: 돌진하다 벽에 들이받으면 뿔이 박혀 stuck_time 초 무방비 (받는 피해 stuck_multiplier 배)
##   → 벽을 등지고 서서 돌진을 벽으로 유도
## [기믹 3] 아리아드네의 실: trap_interval 초마다 미궁의 함정 — 바닥에 금빛 실이 깔리고 trap_warn 초 뒤
##   실 위에 서 있지 않으면 최대 체력의 trap_ratio 피해 (가드·대시 불가)
## 체력 50% 이하: 미궁이 더 자주 바뀌고 벽이 늘어남

enum Pattern { CHARGE, AXE, STOMP, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var rock_texture: Texture2D
@export var charge_damage: int = 84
@export var axe_damage: int = 80
@export var stomp_damage: int = 74
@export var charge_windup: float = 0.9
@export var charge_speed: float = 360.0
@export var stuck_time: float = 3.0
@export var stuck_multiplier: float = 1.5
@export var maze_interval: float = 16.0
@export var trap_interval: float = 24.0
@export var trap_warn: float = 2.5
@export var trap_ratio: float = 0.35

var maze: Labyrinth
var thread: AriadneThread
var _charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _stuck_left: float = 0.0
var _stucks: int = 0
var _maze_left: float = 0.0
var _trap_cooldown: float = 14.0
var _trap_hits: int = 0
var _trap_dodges: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.CHARGE, Pattern.AXE, Pattern.STOMP, Pattern.CHARGE, Pattern.SUMMON, Pattern.AXE]


func get_maze() -> Labyrinth:
	return maze if maze != null and is_instance_valid(maze) else null


func get_thread() -> AriadneThread:
	return thread if thread != null and is_instance_valid(thread) else null


func is_charging() -> bool:
	return _charging


func is_stuck() -> bool:
	return _stuck_left > 0.0


func get_stuck_count() -> int:
	return _stucks


func get_trap_hits() -> int:
	return _trap_hits


func get_trap_dodges() -> int:
	return _trap_dodges


func _avoid_points() -> Array[Vector2]:
	var list: Array[Vector2] = [global_position, get_hit_center()]
	if has_target():
		list.append(_player.global_position)
	return list


func _get_move_velocity(delta: float) -> Vector2:
	if get_maze() == null and has_target():
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))
		maze = Labyrinth.spawn(self, area, 6)
		maze.rebuild(_avoid_points())
		_maze_left = maze_interval
	if get_maze() != null and has_target():
		_maze_left -= delta
		if _maze_left <= 0.0 and not maze.is_warning():
			shift_maze()
	if has_target() and get_thread() == null:
		_trap_cooldown -= delta
		if _trap_cooldown <= 0.0:
			begin_trap()
	return super._get_move_velocity(delta)


func _physics_process(delta: float) -> void:
	if _stuck_left > 0.0:
		_stuck_left -= delta
		if _stuck_left <= 0.0:
			set_status("", Color.WHITE)
	super._physics_process(delta)


# ============================================================ 기믹 1: 움직이는 미궁
func shift_maze() -> void:
	if get_maze() == null:
		return
	maze.wall_count = 8 if phase_two else 6
	maze.warn(1.6, _avoid_points())
	_maze_left = maze_interval * (0.75 if phase_two else 1.0)
	GameManager.show_notice("미궁이 움직인다! 점선 자리에 새 벽이 선다", Color(0.95, 0.85, 0.6))


# ============================================================ 기믹 2: 돌진 · 뿔 박힘
func begin_charge(dir: Vector2 = Vector2.ZERO) -> void:
	_charge_dir = dir.normalized() if dir != Vector2.ZERO else direction_to_player()
	_charging = false
	set_status("돌진 준비!", Color(1.0, 0.6, 0.4))
	for i in 10:
		var at := get_hit_center() + _charge_dir * (24.0 + 26.0 * i)
		if arena_rect.has_area() and not arena_rect.has_point(at):
			break
		telegraph_strike(at, 14.0, charge_windup, charge_damage, Elements.Type.EARTH)
	_after(charge_windup, func() -> void:
		if not is_dead() and not is_stunned():
			_charging = true
			_charge_left = 1.3
			set_status("돌진!", Color(1.0, 0.5, 0.3)))


func _casting_velocity(delta: float) -> Vector2:
	if not _charging:
		return Vector2.ZERO
	_charge_left -= delta
	if get_maze() != null and maze.hits_wall(global_position + _charge_dir * 10.0, 4.0):
		_get_stuck()
		return Vector2.ZERO
	var next := global_position + _charge_dir * charge_speed * delta
	if _charge_left <= 0.0 or (arena_rect.has_area() and not arena_rect.has_point(next)):
		_charging = false
		set_status("", Color.WHITE)
		_btimer = minf(_btimer, 0.3)
		return Vector2.ZERO
	return _charge_dir * charge_speed


func _get_stuck() -> void:
	_charging = false
	_stucks += 1
	_stun_left = stuck_time
	_stuck_left = stuck_time
	_btimer = 0.2
	set_status("뿔이 벽에 박혔다! (받는 피해 x%.1f)" % stuck_multiplier, Color(1.0, 0.85, 0.5))
	GameManager.show_notice("미노타우로스의 뿔이 벽에 박혔다! 지금 몰아쳐라", Color(1.0, 0.85, 0.5))
	Fx.explosion(self, global_position + _charge_dir * 12.0, Color(0.7, 0.6, 0.5), 30.0, 2)
	if _player != null:
		_player.shake_camera(6.0)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _stuck_left > 0.0:
		amount = roundi(amount * stuck_multiplier)
	super.take_damage(amount, knockback, is_crit, armor_pen)


# ============================================================ 기믹 3: 아리아드네의 실
func begin_trap() -> void:
	if get_thread() != null or is_dead() or not has_target():
		return
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))
	var start := _player.global_position + Vector2.from_angle(randf() * TAU) * 60.0
	thread = AriadneThread.spawn(self, area, AriadneThread.make_path(area, start.clamp(area.position, area.end)), trap_warn)
	_trap_cooldown = trap_interval
	GameManager.show_notice("미궁의 함정이 깨어난다! 금빛 실 위로 피하라", Color(1.0, 0.9, 0.5))
	_after(trap_warn, _resolve_trap)


func _resolve_trap() -> void:
	var t := get_thread()
	if t == null:
		return
	if has_target() and not is_dead():
		if t.is_on_thread(_player.global_position):
			_trap_dodges += 1
		elif _player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * trap_ratio)), _player.global_position + Vector2(0, -10), false) == Player.HitResult.DAMAGED:
			_trap_hits += 1
	for i in 10:
		Fx.burst(self, Vector2(randf_range(t.area.position.x, t.area.end.x), randf_range(t.area.position.y, t.area.end.y)), Color(0.75, 0.7, 0.6), 6, 50.0, 0.35, Vector2(0, 80))
	t.queue_free()
	thread = null


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.CHARGE:
			begin_charge()
			return charge_windup + 1.4
		Pattern.AXE:
			var dir := direction_to_player()
			for i in 5:
				telegraph_strike(get_hit_center() + dir.rotated((i - 2) * 0.35) * 44.0, 22.0, 0.75, axe_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.STOMP:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 50.0, 20.0, 0.85, stomp_damage, Elements.Type.EARTH)
			for i in 8:
				shoot(Vector2.from_angle(TAU * i / 8.0 + 0.2), 110.0, stomp_damage - 24, rock_texture, 0.0, Elements.Type.EARTH)
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if get_maze() != null:
		maze.queue_free()
	if get_thread() != null:
		thread.queue_free()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("미노타우로스가 포효한다! 미궁이 더 자주, 더 복잡하게 바뀐다", Color(1.0, 0.6, 0.4))
