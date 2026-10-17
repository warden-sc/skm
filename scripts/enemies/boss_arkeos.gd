class_name BossArkeos
extends PatternBoss
## 14스테이지 보스: 모래시계의 파수꾼 아르케오스 — 시간의 회랑을 지키는 파수꾼. 거대한 모래시계로 시간을 다룬다.
##   SPIKES : 모래 가시 — 플레이어를 향해 일직선 예고 장판
##   HANDS  : 시곗바늘 — 시계방향으로 도는 탄 줄기 3개
##   SAND   : 시간의 모래 — 플레이어 발밑에 밟으면 느려지는 모래 장판 + 장판
##   SUMMON : 태엽 병정 · 시간의 망령 호출
##
## [기믹] 시간 역행 (rewind_interval 마다):
##   1) 「모래시계가 뒤집힌다」 예고 — 보스는 rewind_seconds 초 전 플레이어가 서 있던 자리를 알고 미리 그곳에 장판을 깐다
##   2) rewind_delay 뒤 시간이 되감김: 보스 체력이 rewind_seconds 초 전 값으로 회복 (그동안 준 피해가 사라짐)
##      + 플레이어가 그때 있던 자리로 강제 전이 → 미리 깔린 장판이 곧 터지므로 대시로 빠져나와야 함
##   공략: 역행 직전엔 딜을 아끼고, 역행 직후 몰아서 딜. 전이된 뒤엔 바로 대시.
## 체력 50% 이하: 역행 주기가 짧아지고 전이 지점 주변에도 장판

enum Pattern { SPIKES, HANDS, SAND, SUMMON }

const SNAPSHOT_STEP := 0.2

@export var minion_scenes: Array[PackedScene] = []
@export var sand_texture: Texture2D
@export var spike_damage: int = 46
@export var hand_damage: int = 30
@export var rewind_damage: int = 56
@export var rewind_interval: float = 15.0
@export var rewind_seconds: float = 5.0
## 예고 → 실제 역행까지
@export var rewind_delay: float = 0.9
## 전이된 뒤 장판이 터지기까지
@export var rewind_strike_after: float = 0.6

## [{t, hp, pos}] 최근 rewind_seconds + 1초 분량
var _history: Array[Dictionary] = []
var _clock: float = 0.0
var _snap_timer: float = 0.0
var _rewind_cooldown: float = 8.0
var _rewind_pending: bool = false
var _rewinds: int = 0
var _last_rewind_target: Vector2 = Vector2.INF
var _last_rewind_heal: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPIKES, Pattern.HANDS, Pattern.SAND, Pattern.SUMMON, Pattern.SPIKES, Pattern.HANDS]


func get_rewind_count() -> int:
	return _rewinds


func get_last_rewind_target() -> Vector2:
	return _last_rewind_target


func get_last_rewind_heal() -> int:
	return _last_rewind_heal


func is_rewind_pending() -> bool:
	return _rewind_pending


func _get_move_velocity(delta: float) -> Vector2:
	_clock += delta
	_snap_timer -= delta
	if _snap_timer <= 0.0 and has_target():
		_snap_timer = SNAPSHOT_STEP
		_history.append({"t": _clock, "hp": hp, "pos": _player.global_position})
		while not _history.is_empty() and _clock - float(_history[0]["t"]) > rewind_seconds + 1.0:
			_history.pop_front()
	if not _rewind_pending and has_target():
		_rewind_cooldown -= delta
		if _rewind_cooldown <= 0.0 and not is_casting():
			begin_rewind()
	return super._get_move_velocity(delta)


## rewind_seconds 초 전 기록 (없으면 가장 오래된 기록)
func get_past_snapshot() -> Dictionary:
	if _history.is_empty():
		return {"t": _clock, "hp": hp, "pos": _player.global_position if has_target() else global_position}
	var want := _clock - rewind_seconds
	for snap in _history:
		if float(snap["t"]) >= want:
			return snap
	return _history[_history.size() - 1]


# ============================================================ 기믹: 시간 역행
func begin_rewind() -> void:
	if _rewind_pending or is_dead() or not has_target():
		return
	_rewind_pending = true
	_rewind_cooldown = rewind_interval * (0.75 if phase_two else 1.0)
	var snap := get_past_snapshot()
	var target: Vector2 = snap["pos"]
	set_status("모래시계가 뒤집힌다: 시간 역행!", Color(1.0, 0.85, 0.45))
	GameManager.show_notice("아르케오스가 시간을 되감는다! %d초 전 자리로 끌려간다 — 도착하면 바로 대시!" % roundi(rewind_seconds), Color(1.0, 0.85, 0.45))
	# 보스는 플레이어가 끌려갈 자리를 알고 있다
	telegraph_strike(target, 30.0, rewind_delay + rewind_strike_after, rewind_damage, Elements.Type.EARTH)
	if phase_two:
		for i in 4:
			telegraph_strike(target + Vector2.from_angle(TAU * i / 4.0 + 0.4) * 52.0, 22.0, rewind_delay + rewind_strike_after + 0.25, rewind_damage, Elements.Type.EARTH)
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.85, 0.45), 60.0, 0.5)
	_after(rewind_delay, _do_rewind.bind(snap))


func _do_rewind(snap: Dictionary) -> void:
	_rewind_pending = false
	if is_dead():
		return
	_rewinds += 1
	var past_hp: int = snap["hp"]
	_last_rewind_heal = maxi(past_hp - hp, 0)
	if _last_rewind_heal > 0:
		hp = past_hp
		health_changed.emit(hp, max_hp)
		FloatingText.spawn(self, global_position + Vector2(0, -40), "+%d (되감기)" % _last_rewind_heal, Color(1.0, 0.85, 0.45), true)
	_last_rewind_target = snap["pos"]
	if has_target():
		Fx.burst(self, _player.global_position, Color(1.0, 0.85, 0.45), 12, 60.0, 0.4)
		_player.global_position = _last_rewind_target
		_player.velocity = Vector2.ZERO
		Fx.flash(self, _last_rewind_target, Color(1.0, 0.9, 0.6), 30.0, 0.3)
	set_status("", Color.WHITE)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.SPIKES:
			var dir := direction_to_player()
			for side in ([-0.25, 0.0, 0.25] if phase_two else [0.0]):
				for i in 6:
					telegraph_strike(get_hit_center() + dir.rotated(side) * (30.0 + 26.0 * i), 15.0, 0.7 + 0.06 * i, spike_damage, Elements.Type.EARTH)
			return 1.3
		Pattern.HANDS:
			set_status("시곗바늘", Color(1.0, 0.9, 0.6))
			for k in 16:
				_after(0.09 * k, _hands.bind(k))
			_after(1.5, set_status.bind("", Color.WHITE))
			return 1.7
		Pattern.SAND:
			if has_target():
				GroundZone.spawn_hostile(self, _player.global_position, GroundZone.Kind.SAND, 40.0, 4.5, 0.5)
				telegraph_strike(_player.global_position, 24.0, 1.1, spike_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 30.0))
			return 0.9
	return 1.0


func _hands(step: int) -> void:
	if is_dead():
		return
	for arm in 3:
		var angle := step * 0.2 + TAU * arm / 3.0
		shoot(Vector2.from_angle(angle), 120.0, hand_damage, sand_texture, 0.0, Elements.Type.EARTH)


func _on_phase_two() -> void:
	GameManager.show_notice("아르케오스: 시간은 나의 편이다… 역행이 더 잦아진다", Color(1.0, 0.85, 0.45))
