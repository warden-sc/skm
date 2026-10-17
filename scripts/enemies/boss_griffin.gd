class_name BossGriffin
extends PatternBoss
## 16스테이지 보스: 천공의 수호자 그리핀 — 바람의 봉우리 꼭대기에 둥지를 튼 독수리 머리·사자 몸의 맹수.
## 지상에서
##   CHARGE  : 돌진 — 낮게 웅크렸다가(예고선) 플레이어 쪽으로 일직선 돌진 (2페이즈 2연속)
##   ROAR    : 포효 — 플레이어 방어력 감소 → 곧바로 강한 앞발톱 할퀴기 (큰 예고 장판 3줄)
##   FEATHER : 날갯짓 — 깃털 부채꼴
##
## [기믹] 비행: flight_interval 마다 공중으로 날아오름 (flight_time 동안)
##   - 공중에서는 활로만 맞힐 수 있음 (날개도 마찬가지)
##   - 공중에서 플레이어 주위를 돌며 깃털을 흩뿌리고, 끝나면 급강하
## [기믹] 날개: 양쪽 날개는 몸통과 체력이 따로 (날개마다 작은 체력 바)
##   - 양쪽 날개를 모두 부수면 땅에 처박히며 그로기 (groggy_time 동안 아무것도 못 함, 날 수도 없음)
##   - wing_regrow_time 뒤 날개가 다시 돋아남
## 체력 50% 이하: 더 자주 날고, 돌진 2연속

enum Pattern { CHARGE, ROAR, FEATHER }

const FLIGHT_HEIGHT := 44.0
const WING_OFFSET := Vector2(24, -40)

@export var wing_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var feather_texture: Texture2D
@export var charge_damage: int = 52
@export var claw_damage: int = 72
@export var feather_damage: int = 32
@export var dive_damage: int = 56
@export var roar_armor_break: int = 15
@export var roar_break_time: float = 6.0
@export var wing_hp_ratio: float = 0.07
@export var flight_interval: float = 13.0
@export var flight_time: float = 6.0
@export var groggy_time: float = 5.0
@export var wing_regrow_time: float = 16.0

var _wings: Array[BossPart] = []
var _wings_requested: bool = false
var _wings_broken: bool = false
var _regrow_left: float = -1.0
var _groggy_left: float = 0.0
var _groggies: int = 0
var _flight_cooldown: float = 0.0
var _flight_left: float = 0.0
var _feather_timer: float = 0.0
var _orbit_angle: float = 0.0
var _height: float = 0.0
var _diving: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_windup: float = 0.0
var _charge_left: float = 0.0
var _charges_queued: int = 0
var _base_shape_pos: Vector2
var _base_scale: Vector2


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.CHARGE, Pattern.FEATHER, Pattern.ROAR, Pattern.CHARGE, Pattern.FEATHER, Pattern.ROAR]
	_flight_cooldown = flight_interval * 0.6
	_base_shape_pos = _hit_shape.position
	_base_scale = sprite.scale


func is_flying() -> bool:
	return airborne


func is_groggy() -> bool:
	return _groggy_left > 0.0


func get_groggy_count() -> int:
	return _groggies


func get_wings() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for w in _wings:
		if is_instance_valid(w) and not w.is_dead():
			alive.append(w)
	return alive


func _get_move_velocity(delta: float) -> Vector2:
	if not _wings_requested:
		_wings_requested = true
		grow_wings()
	_update_wings()
	if _regrow_left > 0.0 and not is_groggy():
		_regrow_left -= delta
		if _regrow_left <= 0.0:
			grow_wings()
	if _groggy_left > 0.0:
		_groggy_left -= delta
		if _groggy_left <= 0.0:
			set_status("", Color.WHITE)
			base_tint = Color.WHITE
		return Vector2.ZERO
	if not has_target():
		return Vector2.ZERO
	if airborne:
		return _flight_velocity(delta)
	_flight_cooldown -= delta
	if _flight_cooldown <= 0.0 and not is_casting() and not _wings_broken:
		take_off()
		return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 날개
func grow_wings() -> void:
	if is_dead() or wing_scene == null:
		return
	_regrow_left = -1.0
	_wings_broken = false
	for side in [-1.0, 1.0]:
		request_summon(wing_scene, global_position + Vector2(WING_OFFSET.x * side, WING_OFFSET.y))
	if _groggies > 0:
		GameManager.show_notice("그리핀의 날개가 다시 돋아났다!", Color(0.85, 0.9, 1.0))


func register_minion(minion: Enemy) -> void:
	if minion is BossPart:
		var wing := minion as BossPart
		var side := -1.0 if get_wings().size() % 2 == 0 else 1.0
		wing.boss = self
		wing.anchor_offset = Vector2(WING_OFFSET.x * side, WING_OFFSET.y)
		wing.set_meta(&"side", side)
		wing.max_hp = maxi(1, roundi(max_hp * wing_hp_ratio))
		wing.died.connect(_on_wing_broken)
		_wings.append(wing)


## 날개 위치·비행 상태를 몸에 맞춤 (공중에서는 날개도 활로만 맞음)
func _update_wings() -> void:
	for w in get_wings():
		if not w.is_node_ready():
			continue  # 방금 소환되어 아직 트리에 들어오지 않은 날개
		var side: float = w.get_meta(&"side", 1.0)
		w.anchor_offset = Vector2(WING_OFFSET.x * side, WING_OFFSET.y - _height)
		w.airborne = airborne
		w.sprite.flip_h = side < 0.0
		w.sprite.rotation = side * (0.15 + sin(_anim_time * (9.0 if airborne else 3.0)) * (0.35 if airborne else 0.08))


func _on_wing_broken(_enemy: Enemy) -> void:
	_wings = get_wings()
	if not _wings.is_empty() or is_dead():
		GameManager.show_notice("그리핀의 한쪽 날개가 꺾였다!", Color(0.85, 0.9, 1.0))
		return
	_wings_broken = true
	crash()


## 양쪽 날개가 부서짐 → 땅에 처박히며 그로기
func crash() -> void:
	_groggies += 1
	airborne = false
	_diving = false
	_flight_left = 0.0
	_charge_left = 0.0
	_charge_windup = 0.0
	_bstate = BossState.CHASE
	_btimer = chase_time
	_groggy_left = groggy_time
	_regrow_left = wing_regrow_time
	base_tint = Color(0.75, 0.75, 0.85)
	set_status("그로기! 땅에 처박혔다", Color(1.0, 0.85, 0.45))
	GameManager.show_notice("양쪽 날개가 부서져 그리핀이 땅에 처박혔다! 지금이 기회다", Color(1.0, 0.85, 0.45))
	Fx.explosion(self, global_position, Color(0.75, 0.7, 0.6), 50.0, 3, Vector2(0, 120))
	if _player != null:
		_player.shake_camera(6.0)


# ============================================================ 기믹: 비행
func take_off() -> void:
	if airborne or is_dead() or _wings_broken or is_groggy():
		return
	airborne = true
	_charge_left = 0.0
	_flight_left = flight_time * (1.25 if phase_two else 1.0)
	_feather_timer = 0.8
	_orbit_angle = randf() * TAU
	set_status("비행 중: 활로만 공격 가능!", Color(0.7, 0.85, 1.0))
	GameManager.show_notice("그리핀이 날아올랐다! 공중에서는 활로만 공격할 수 있다", Color(0.7, 0.85, 1.0))
	Fx.burst(self, global_position, Color(0.85, 0.85, 0.8), 20, 60.0, 0.6, Vector2(0, 40), 1.3)


func _flight_velocity(delta: float) -> Vector2:
	if _diving:
		return Vector2.ZERO
	_flight_left -= delta
	_feather_timer -= delta
	if _feather_timer <= 0.0:
		_feather_timer = 0.8 if phase_two else 1.1
		var aim := get_hit_center().direction_to(_player.global_position)
		for i in 3:
			shoot(aim.rotated((i - 1) * 0.25), 150.0, feather_damage, feather_texture, 0.0, Elements.Type.NONE)
	if _flight_left <= 0.0:
		_dive()
		return Vector2.ZERO
	_orbit_angle += delta * 1.1
	var target := _player.global_position + Vector2.from_angle(_orbit_angle) * 100.0
	return global_position.direction_to(target) * move_speed * 2.2


func _dive() -> void:
	var at := _player.global_position if has_target() else global_position
	if arena_rect.has_area():
		at = at.clamp(arena_rect.position, arena_rect.end)
	telegraph_strike(at, 40.0, 0.8, dive_damage, Elements.Type.NONE)
	global_position = at
	_flight_left = 0.0
	_diving = true
	_after(0.8, _land)
	set_status("급강하!", Color(1.0, 0.6, 0.4))


func _land() -> void:
	if not _diving:
		return
	airborne = false
	_diving = false
	_flight_cooldown = flight_interval * (0.75 if phase_two else 1.0)
	set_status("", Color.WHITE)
	if _player != null:
		_player.shake_camera(4.0)


# ============================================================ 패턴 (지상)
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.CHARGE:
			_charges_queued = 2 if phase_two else 1
			_start_charge()
			return 0.6 + 0.9 * _charges_queued
		Pattern.ROAR:
			return roar()
		Pattern.FEATHER:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.18), 140.0, feather_damage, feather_texture, 0.0, Elements.Type.NONE)
			return 0.9
	return 1.0


## 포효: 방어력 감소 → 강한 앞발톱 할퀴기 (테스트에서도 직접 호출)
func roar() -> float:
	set_status("포효: 방어력 감소!", Color(1.0, 0.55, 0.45))
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.85, 0.7), 90.0, 0.45)
	if has_target():
		_player.apply_armor_break(roar_armor_break, roar_break_time)
		_player.shake_camera(3.0)
		FloatingText.spawn(_player, _player.global_position + Vector2(0, -24), "방어력 -%d" % roar_armor_break, Color(1.0, 0.55, 0.45), true)
	_after(0.45, _claw)
	return 1.6


func _claw() -> void:
	if is_dead() or not has_target():
		return
	set_status("앞발톱 할퀴기!", Color(1.0, 0.55, 0.45))
	var dir := direction_to_player()
	var side := dir.orthogonal()
	for k in [-1, 0, 1]:
		for i in 4:
			telegraph_strike(get_hit_center() + side * 18.0 * k + dir * (26.0 + 22.0 * i), 14.0, 0.6 + 0.04 * i, claw_damage, Elements.Type.NONE)
	_after(0.9, set_status.bind("", Color.WHITE))


func _start_charge() -> void:
	_charge_windup = 0.55
	_charge_left = 0.0
	_charge_dir = direction_to_player()
	for i in 5:
		telegraph_strike(get_hit_center() + _charge_dir * (30.0 + 30.0 * i), 18.0, 0.55 + 0.07 * i, charge_damage, Elements.Type.NONE)


func _casting_velocity(delta: float) -> Vector2:
	if _charge_windup > 0.0:
		_charge_windup -= delta
		if _charge_windup <= 0.0:
			_charge_left = 0.4
		return Vector2.ZERO
	if _charge_left > 0.0:
		_charge_left -= delta
		if _charge_left <= 0.0:
			_charges_queued -= 1
			if _charges_queued > 0 and not is_dead():
				_start_charge()
		return _charge_dir * 370.0
	return Vector2.ZERO


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	var target := FLIGHT_HEIGHT if airborne else 0.0
	_height = move_toward(_height, target, delta * 120.0)
	sprite.position.y = _base_sprite_pos.y - _height
	_hit_shape.position = _base_shape_pos - Vector2(0, _height)
	sprite.scale = _base_scale * (1.0 + _height / FLIGHT_HEIGHT * 0.12)
	sprite.rotation = 0.35 if is_groggy() else 0.0


func _on_phase_two() -> void:
	GameManager.show_notice("그리핀이 사납게 울부짖는다! 더 자주 날아오른다", Color(1.0, 0.6, 0.45))
