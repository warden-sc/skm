class_name BossPolyphemus
extends PatternBoss
## 42스테이지 보스: 외눈 거인 폴리페모스 — 동굴에서 양을 치는 거대한 키클롭스.
##   BOULDER : 바위 던지기 — 노리는 곳으로 큰 바위 (떨어진 자리 장판)
##   CLUB    : 몽둥이 휘두르기 — 앞쪽 부채꼴 장판
##   STOMP   : 발 구르기 — 몸 주위 고리 장판
##   SUMMON  : 어린 키클롭스 · 동굴 늑대 호출
##
## [기믹 1] 외눈: 이마의 눈(체력 따로)이 약점. 눈이 성한 동안 몸 방어력 +eye_armor
##   눈을 부수면 「실명!」 — 큰 피해 + 기절, 방어력 보너스가 사라지고 그 뒤로는 앞을 보지 못함
## [기믹 2] 소리 추적: 눈이 먼 뒤에는 플레이어가 공격하거나 대시할 때 나는 소리로만 위치를 알아챔
##   (패턴도 마지막으로 들은 곳을 노림) — 소리가 없으면 두리번거리며 몸 주위를 더듬음
## [기믹 3] 양떼: 보스방의 양 곁에 있으면 양털에 소리가 묻혀 들키지 않음
## 체력 50% 이하: 더 자주 더듬고 소리에 더 빨리 반응

enum Pattern { BOULDER, CLUB, STOMP, SUMMON }

@export var eye_scene: PackedScene
@export var sheep_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var boulder_texture: Texture2D
@export var boulder_damage: int = 84
@export var club_damage: int = 82
@export var stomp_damage: int = 76
@export var eye_armor: int = 40
@export var eye_hp_ratio: float = 0.04
@export var blind_burst_ratio: float = 0.05
@export var sheep_count: int = 5

var eye: BossPart
var blind: bool = false
var heard_at: Vector2 = Vector2.ZERO
var _base_defense: int = 0
var _started: bool = false
var _heard: int = 0
var _muffled: int = 0
var _grope_timer: float = 2.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.CLUB, Pattern.BOULDER, Pattern.STOMP, Pattern.SUMMON, Pattern.BOULDER, Pattern.CLUB]
	_base_defense = defense
	GameManager.player_attacked.connect(_on_player_attacked)


func get_eye() -> BossPart:
	return eye if eye != null and is_instance_valid(eye) and not eye.is_dead() else null


func get_heard_count() -> int:
	return _heard


func get_muffled_count() -> int:
	return _muffled


func get_sheep() -> Array[Sheep]:
	var list: Array[Sheep] = []
	for node in get_tree().get_nodes_in_group(&"sheep"):
		var sh := node as Sheep
		if sh != null and not sh.is_dead():
			list.append(sh)
	return list


## 패턴이 노리는 곳: 볼 수 있으면 플레이어, 눈이 멀었으면 마지막으로 들은 곳
func aim_point() -> Vector2:
	if not blind and has_target():
		return _player.global_position
	return heard_at


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		heard_at = _player.global_position
		if eye_scene != null:
			request_summon(eye_scene, global_position + Vector2(0, -60))
		defense = _base_defense + eye_armor
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
		if sheep_scene != null:
			for i in sheep_count:
				request_summon(sheep_scene, Vector2(randf_range(area.position.x + 40, area.end.x - 40), randf_range(area.position.y + 60, area.end.y - 30)))
	if blind and has_target():
		if _player.is_dashing():
			hear(_player.global_position)
		_grope_timer -= delta
		if _grope_timer <= 0.0 and not is_casting():
			_grope_timer = 2.2 if phase_two else 3.0
			for i in 8:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 8.0) * 40.0, 18.0, 0.8, club_damage - 20, Elements.Type.EARTH)
	return super._get_move_velocity(delta)


func _chase_velocity(delta: float) -> Vector2:
	if not blind:
		return super._chase_velocity(delta)
	if global_position.distance_to(heard_at) < 10.0:
		return Vector2.ZERO
	return global_position.direction_to(heard_at) * move_speed * (1.2 if phase_two else 1.0)


# ============================================================ 기믹 1: 외눈 · 실명
func register_minion(minion: Enemy) -> void:
	if minion is BossPart and get_eye() == null and not blind:
		eye = minion as BossPart
		eye.boss = self
		eye.follow_boss = true
		eye.anchor_offset = Vector2(0, -60)
		eye.max_hp = maxi(1, roundi(max_hp * eye_hp_ratio))
		eye.died.connect(_on_eye_broken)


func _on_eye_broken(_enemy: Enemy) -> void:
	if is_dead():
		return
	blind = true
	eye = null
	defense = _base_defense
	heard_at = global_position
	super.take_damage(maxi(1, roundi(max_hp * blind_burst_ratio)), Vector2.ZERO, true, 999999)
	_stun_left = 3.0
	set_status("눈이 멀었다 — 소리로 찾는다", Color(0.9, 0.85, 0.7))
	GameManager.show_notice("폴리페모스의 눈을 찔렀다! 이제 소리로만 찾는다 — 공격·대시 소리를 조심하고, 양 곁에 숨어라", Color(1.0, 0.9, 0.6))
	if _player != null:
		_player.shake_camera(6.0)


# ============================================================ 기믹 2·3: 소리 추적 · 양떼
func _on_player_attacked(_weapon: WeaponData, _aim: Vector2) -> void:
	if blind and has_target() and not is_dead():
		hear(_player.global_position)


## 소리가 남 — 양 곁이면 묻힘 (테스트에서도 직접 호출)
func hear(at: Vector2) -> bool:
	for sh in get_sheep():
		if sh.hides(at):
			_muffled += 1
			return false
	heard_at = at
	_heard += 1
	return true


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var target := aim_point()
	match pattern:
		Pattern.BOULDER:
			telegraph_strike(target, 30.0, 1.0, boulder_damage, Elements.Type.EARTH)
			shoot(get_hit_center().direction_to(target), 120.0, boulder_damage - 30, boulder_texture, 0.0, Elements.Type.EARTH)
			return 1.2
		Pattern.CLUB:
			var dir := get_hit_center().direction_to(target)
			for i in 5:
				telegraph_strike(get_hit_center() + dir.rotated((i - 2) * 0.35) * 48.0, 22.0, 0.8, club_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.STOMP:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 54.0, 20.0, 0.85, stomp_damage, Elements.Type.EARTH)
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	for sh in get_sheep():
		sh.despawn()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("폴리페모스가 분노해 몸부림친다!", Color(1.0, 0.6, 0.4))
