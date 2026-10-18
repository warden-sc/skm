class_name BossPython
extends PatternBoss
## 62스테이지 보스: 델포이의 거대 뱀 피톤 — 아폴론이 델포이를 차지하기 전 그 땅을 지키던 대지의 뱀.
##   COIL    : 몸 주위를 휘감는 고리
##   VENOM   : 독액 탄막 (부채꼴)
##   STRIKE  : 일직선 물기
##   SUMMON  : 피톤의 새끼 · 델포이 독사 호출
##
## [기믹] 갈라진 땅 틈: 보스방의 틈 5곳 — 피톤은 out_time 초 동안 싸운 뒤 가까운 틈으로 들어가 숨음 (틈 속에서는 무적)
##   hide_time 초 뒤 다른 틈에서 땅을 가르며 솟아오름 (솟는 자리 주위가 터짐)
## [기믹] 월계수 가지: 보스방에 놓인 가지를 집어 틈에 꽂으면 그 틈이 막힘 (드나들 수 없음)
##   틈이 모두 막히면 숨을 곳을 잃고 크게 휘청임 → 그 뒤로는 숨지 못함
## 체력 50% 이하: 숨는 시간이 짧아지고 더 자주 숨음

enum Pattern { COIL, VENOM, STRIKE, SUMMON }

const FISSURE_SPOTS := [Vector2(-220, -100), Vector2(220, -100), Vector2(0, 0), Vector2(-220, 110), Vector2(220, 110)]
const BRANCH_SPOTS := [Vector2(-110, -130), Vector2(110, 130), Vector2(110, -130), Vector2(-110, 130), Vector2(0, -140), Vector2(0, 140)]

@export var minion_scenes: Array[PackedScene] = []
@export var branch_texture: Texture2D
@export var venom_texture: Texture2D
@export var coil_damage: int = 88
@export var venom_damage: int = 58
@export var strike_damage: int = 94
@export var emerge_damage: int = 84
@export var out_time: float = 7.0
@export var hide_time: float = 3.0
@export var branch_respawn: float = 4.0

var fissures: Array[Fissure] = []
var branch: CarryItem
var _hiding: bool = false
var _hide_left: float = 0.0
var _out_left: float = 7.0
var _current: int = -1
var _plugs: int = 0
var _cornered: bool = false
var _branch_spot: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.COIL, Pattern.VENOM, Pattern.STRIKE, Pattern.VENOM, Pattern.SUMMON]
	immune_text = "틈 속에 숨음 — 무적"


func is_hiding() -> bool:
	return _hiding


func get_plug_count() -> int:
	return _plugs


func open_fissures() -> Array[int]:
	var open: Array[int] = []
	for i in fissures.size():
		if is_instance_valid(fissures[i]) and not fissures[i].plugged:
			open.append(i)
	return open


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for spot in FISSURE_SPOTS:
			fissures.append(Fissure.spawn(self, _area().get_center() + spot))
		branch = CarryItem.spawn(self, _area().get_center() + BRANCH_SPOTS[0], branch_texture, "월계수 가지", Color(0.5, 0.9, 0.4))
		_update_status()
	if _hiding:
		return Vector2.ZERO
	return super._get_move_velocity(delta)


func can_be_hit_by(kind: HitKind) -> bool:
	return not _hiding and super.can_be_hit_by(kind)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _hiding:
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


## 틈에 숨는 시간 · 싸우는 시간은 기절 중에도 흐름
func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _hiding:
			_hide_left -= delta
			if _hide_left <= 0.0:
				emerge()
		elif not _cornered and _stun_left <= 0.0:
			_out_left -= delta
			if _out_left <= 0.0:
				dive()
		if branch != null and is_instance_valid(branch) and branch.is_carried():
			for i in open_fissures():
				if branch.global_position.distance_to(fissures[i].global_position + Vector2(0, -26)) <= 26.0:
					plug(i)
					break
	super._physics_process(delta)


## 가까운 열린 틈으로 들어가 숨음 (테스트에서도 직접 호출)
func dive() -> bool:
	var open := open_fissures()
	if open.is_empty() or _hiding or is_dead():
		_out_left = out_time
		return false
	var best := open[0]
	for i in open:
		if fissures[i].global_position.distance_to(global_position) < fissures[best].global_position.distance_to(global_position):
			best = i
	_current = best
	_hiding = true
	_hide_left = hide_time * (0.7 if phase_two else 1.0)
	airborne = true  # 땅속: 몸통 접촉 피해 없음
	Fx.burst(self, global_position, Color(0.5, 0.4, 0.3), 20, 70.0, 0.5)
	global_position = fissures[best].global_position
	sprite.modulate.a = 0.0
	(get_node(^"Shadow") as CanvasItem).visible = false
	_update_status()
	return true


## 다른 열린 틈에서 솟아오름 (테스트에서도 직접 호출)
func emerge() -> void:
	if not _hiding:
		return
	var open := open_fissures()
	open.erase(_current)
	var to: int = _current if open.is_empty() else open.pick_random()
	_current = to
	_hiding = false
	airborne = false
	_out_left = out_time * (0.75 if phase_two else 1.0)
	global_position = fissures[to].global_position
	sprite.modulate.a = 1.0
	(get_node(^"Shadow") as CanvasItem).visible = true
	for i in 8:
		telegraph_strike(global_position + Vector2.from_angle(TAU * i / 8.0) * 34.0, 18.0, 0.5, emerge_damage, Elements.Type.EARTH)
	Fx.burst(self, global_position, Color(0.5, 0.4, 0.3), 24, 90.0, 0.6, Vector2(0, -60))
	if open_fissures().is_empty():
		_corner()
	_update_status()


## 틈을 막음 (테스트에서도 직접 호출)
func plug(index: int) -> void:
	if index < 0 or index >= fissures.size() or fissures[index].plugged:
		return
	fissures[index].plug()
	_plugs += 1
	if branch != null and is_instance_valid(branch):
		if open_fissures().is_empty():
			branch.hide_for(9999.0)
		else:
			_branch_spot = (_branch_spot + 1) % BRANCH_SPOTS.size()
			branch.home = _area().get_center() + BRANCH_SPOTS[_branch_spot]
			branch.hide_for(branch_respawn)
	GameManager.show_notice("월계수 가지로 틈을 막았다! (남은 틈 %d)" % open_fissures().size(), Color(0.6, 1.0, 0.5))
	if open_fissures().is_empty() and not _hiding:
		_corner()
	_update_status()


func _corner() -> void:
	if _cornered:
		return
	_cornered = true
	super.stun(8.0)
	GameManager.show_notice("모든 틈이 막혔다! 피톤이 숨을 곳을 잃고 휘청인다", Color(0.7, 1.0, 0.6))


func _update_status() -> void:
	if _hiding:
		set_status("틈 속에 숨음 — 무적", Color(0.75, 0.7, 0.9))
	elif _cornered:
		set_status("숨을 곳이 없다!", Color(1.0, 0.6, 0.5))
	else:
		set_status("열린 틈 %d곳 — 월계수 가지로 막아라" % open_fissures().size(), Color(0.7, 0.95, 0.6))


func _run_pattern(pattern: int) -> float:
	if not has_target() or _hiding:
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.COIL:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 54.0, 22.0, 0.85, coil_damage, Elements.Type.NATURE)
			return 1.2
		Pattern.VENOM:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead() or _hiding or not has_target():
						return
					var aim := direction_to_player()
					for i in 7:
						shoot(aim.rotated((i - 3) * 0.17), 140.0, venom_damage, venom_texture, 0.0, Elements.Type.NATURE))
			return 1.1
		Pattern.STRIKE:
			for i in 10:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 16.0, 0.6 + 0.03 * i, strike_damage, Elements.Type.NONE)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	sprite.modulate.a = 1.0
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("피톤이 땅을 울리며 몸부림친다! 더 자주 틈으로 숨는다", Color(0.7, 0.9, 0.5))
