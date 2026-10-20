class_name BossMars
extends PatternBoss
## 60스테이지 보스: 전쟁의 신 마르스 — 전장의 함성과 피 냄새를 따라 걷는 군신.
##   SPEAR      : 군신의 창 — 일직선 셋 (부채꼴)
##   CHARIOT    : 포보스와 데이모스의 전차 — 예고선을 따라 돌진, 부딪히면 큰 피해 + 「공포」(행동불능)
##   PILUM_RAIN : 필룸 비 — 플레이어 주변에 창이 쏟아짐
##   WAR_CRY    : 전쟁의 함성 — 충격파 + 분노 게이지 상승
##   SUMMON     : 로마 군단병 · 투창병 · 백인대장 호출
##
## [기믹 1] 앙킬레 (12개의 방패): 보스방을 둘러싼 방패 12개 중 진짜는 하나뿐 — 진짜가 서 있는 동안 방어력 +sacred_defense
##   진짜 방패는 가끔 희미하게 반짝임. 진짜를 부수면 가호가 사라지고 크게 휘청임 (기절)
##   가짜를 부수면 그 자리에서 필룸이 플레이어에게 날아옴 (반격)
## [기믹 2] 포보스와 데이모스의 전차: 전차에 치이면 「공포」 — fear_time 초 동안 움직이지도, 공격·가드·대시·포션도 못함
## [기믹 3] 전쟁의 광기: 누가 피를 흘리든 분노 게이지가 참 (플레이어가 맞을 때 · 마르스가 맞을 때 · 졸개가 쓰러질 때)
##   가득 차면 frenzy_time 초 동안 「광기」 — 공격력 · 이동 속도 상승, 패턴이 빨라짐. 끝나면 게이지가 비워짐
## 체력 50% 이하: 전차가 두 번 연달아 달림

enum Pattern { SPEAR, CHARIOT, PILUM_RAIN, WAR_CRY, SUMMON }

const SHIELD_RX := 250.0
const SHIELD_RY := 140.0

@export var shield_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var pilum_texture: Texture2D
@export var spear_damage: int = 96
@export var chariot_damage: int = 100
@export var pilum_damage: int = 62
@export var cry_damage: int = 84
@export var shield_count: int = 12
@export var shield_hp_ratio: float = 0.01
@export var sacred_defense: int = 40
@export var fear_time: float = 1.6
@export var frenzy_max: float = 100.0
@export var frenzy_time: float = 10.0
@export var frenzy_power: float = 0.3

var shields: Array[BossPart] = []
var true_shield: BossPart
var _sacred_broken: bool = false
var _fakes_broken: int = 0
var _frenzy: float = 0.0
var _frenzy_left: float = 0.0
var _frenzies: int = 0
var _fears: int = 0
var _base_defense: int = 0
var _base_power: float = 1.0
var _base_speed: float = 40.0
var _base_chase: float = 2.0
var _glint_left: float = 3.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_windup: float = 0.0
var _charge_left: float = 0.0
var _charge_hit: bool = false
var _charges_queued: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	_base_speed = move_speed
	_base_chase = chase_time
	pattern_order = [Pattern.SPEAR, Pattern.CHARIOT, Pattern.PILUM_RAIN, Pattern.SPEAR, Pattern.WAR_CRY, Pattern.CHARIOT, Pattern.SUMMON]
	if not has_meta(&"net_mirror"):  # 멀티플레이 참가자 화면의 복제본은 반응하지 않음
		GameManager.player_damaged.connect(_on_player_damaged)


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power
	_base_defense = defense
	_base_speed = move_speed


func get_shields() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for s in shields:
		if is_instance_valid(s) and not s.is_dead():
			alive.append(s)
	return alive


func has_sacred_shield() -> bool:
	return true_shield != null and is_instance_valid(true_shield) and not true_shield.is_dead()


func get_frenzy() -> float:
	return _frenzy


func is_frenzied() -> bool:
	return _frenzy_left > 0.0


func get_fear_count() -> int:
	return _fears


func get_fakes_broken() -> int:
	return _fakes_broken


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if shield_scene != null:
			for i in shield_count:
				var a := TAU * i / shield_count
				request_summon(shield_scene, _area().get_center() + Vector2(cos(a) * SHIELD_RX, sin(a) * SHIELD_RY))
		_pick_true_shield()
	if _charge_windup > 0.0 or _charge_left > 0.0:
		return _charge_velocity(delta)
	return super._get_move_velocity(delta)


func _pick_true_shield() -> void:
	var alive := get_shields()
	if alive.is_empty():
		return
	true_shield = alive.pick_random()
	defense = _base_defense + sacred_defense
	_update_status()


func register_minion(minion: Enemy) -> void:
	if minion is BossPart:
		var shield := minion as BossPart
		shield.boss = self
		shield.follow_boss = false
		shield.max_hp = maxi(1, roundi(max_hp * shield_hp_ratio))
		shield.hp = shield.max_hp
		shield.died.connect(_on_shield_broken)
		shields.append(shield)
	else:
		minion.died.connect(func(_e: Enemy) -> void: add_frenzy(5.0))


func _on_shield_broken(shield: Enemy) -> void:
	if is_dead():
		return
	if shield == true_shield:
		true_shield = null
		_sacred_broken = true
		defense = _base_defense
		super.stun(5.0)
		Fx.explosion(self, shield.get_hit_center(), Color(1.0, 0.85, 0.4), 40.0, 2)
		Net.announce("진짜 앙킬레를 부쉈다! 마르스의 가호가 사라진다", Color(1.0, 0.85, 0.5))
	else:
		_fakes_broken += 1
		var from := shield.get_hit_center()
		if has_target():
			var aim := from.direction_to(_player.global_position)
			for i in 5:
				shoot(aim.rotated((i - 2) * 0.12), 210.0, pilum_damage, pilum_texture, 0.0, Elements.Type.NONE, from)
		FloatingText.spawn(shield, from + Vector2(0, -16), "가짜 방패!", Color(1.0, 0.5, 0.4), true)
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead():
		if has_sacred_shield():
			_glint_left -= delta
			if _glint_left <= 0.0:
				_glint_left = randf_range(3.5, 5.5)
				Fx.cross_glint(true_shield, true_shield.get_hit_center(), Color(1.0, 0.95, 0.7), 10.0, 0.4)
		if _frenzy_left > 0.0:
			_frenzy_left -= delta
			if _frenzy_left <= 0.0:
				_end_frenzy()
		elif has_target():
			add_frenzy(1.0 * delta)  # 전장의 피 냄새 — 가만히 있어도 조금씩 참
		if Engine.get_physics_frames() % 15 == 0:
			_update_status()
	super._physics_process(delta)


func _update_status() -> void:
	var guard := "앙킬레의 가호 (방패 %d개 중 진짜 하나)" % get_shields().size() if has_sacred_shield() else "가호 없음"
	if is_frenzied():
		set_status("광기! %.0f초 · %s" % [_frenzy_left, guard], Color(1.0, 0.35, 0.3))
	else:
		set_status("분노 %d%% · %s" % [roundi(_frenzy / frenzy_max * 100.0), guard], Color(1.0, 0.75, 0.5))


# ============================================================ 기믹 3: 전쟁의 광기
func add_frenzy(amount: float) -> void:
	if is_dead() or is_frenzied() or amount <= 0.0:
		return
	_frenzy = minf(_frenzy + amount, frenzy_max)
	if _frenzy >= frenzy_max:
		_begin_frenzy()


func _on_player_damaged(_amount: int) -> void:
	add_frenzy(6.0)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	var before := hp
	super.take_damage(amount, knockback, is_crit, armor_pen)
	add_frenzy(float(before - hp) / max_hp * 100.0)


func _begin_frenzy() -> void:
	_frenzies += 1
	_frenzy_left = frenzy_time
	power = _base_power * (1.0 + frenzy_power)
	move_speed = _base_speed * 1.3
	chase_time = _base_chase * 0.6
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.3, 0.2), 120.0, 0.6)
	Net.announce("전쟁의 광기! 마르스가 피에 취해 날뛴다", Color(1.0, 0.4, 0.3))
	_update_status()


func _end_frenzy() -> void:
	_frenzy_left = 0.0
	_frenzy = 0.0
	power = _base_power
	move_speed = _base_speed
	chase_time = _base_chase
	_update_status()


# ============================================================ 기믹 2: 포보스와 데이모스의 전차
## 「공포」: 행동불능 (테스트에서도 직접 호출)
func fear_player() -> void:
	if not has_target():
		return
	_fears += 1
	_player.apply_charm(fear_time, null, "공포")


func _start_charge() -> void:
	if not has_target():
		return
	_charge_dir = direction_to_player()
	_charge_windup = 0.6
	_charge_left = 0.65
	_charge_hit = false
	for i in 14:
		Fx.flash(self, global_position + _charge_dir * (20.0 + 20.0 * i), Color(1.0, 0.35, 0.3), 12.0, 0.6)  # 전차 예고선


func _charge_velocity(delta: float) -> Vector2:
	if _charge_windup > 0.0:
		_charge_windup -= delta
		return Vector2.ZERO
	_charge_left -= delta
	if Engine.get_physics_frames() % 3 == 0:
		Fx.burst(self, global_position, Color(0.6, 0.4, 0.3), 4, 40.0, 0.4)
	if not _charge_hit and has_target() and global_position.distance_to(_player.global_position) < 40.0:  # 전차는 몸보다 넓음 (몸통 접촉보다 먼저 판정)
		_charge_hit = true
		if _player.take_hit(roundi(chariot_damage * power), global_position, self) == Player.HitResult.DAMAGED:
			fear_player()
	if _charge_left <= 0.0 and _charges_queued > 0:
		_charges_queued -= 1
		_start_charge()
	return _charge_dir * 340.0


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SPEAR:
			for k in 3:
				var d := dir.rotated((k - 1) * 0.28)
				for i in 10:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.NONE)
			return 1.1
		Pattern.CHARIOT:
			_charges_queued = 1 if phase_two else 0
			_start_charge()
			Net.announce("포보스와 데이모스의 전차가 달려든다! 치이면 공포에 질려 움직일 수 없다", Color(1.0, 0.5, 0.4))
			return 1.4 if phase_two else 1.3
		Pattern.PILUM_RAIN:
			for i in 8:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 80.0)
				telegraph_strike(at, 18.0, 0.8 + 0.08 * i, pilum_damage + 10, Elements.Type.NONE)
			for i in 6:
				shoot(dir.rotated((i - 2.5) * 0.15), 200.0, pilum_damage, pilum_texture)
			return 1.2
		Pattern.WAR_CRY:
			for i in 14:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0) * 60.0, 22.0, 0.9, cry_damage, Elements.Type.NONE)
			Fx.shockwave(self, get_hit_center(), Color(1.0, 0.4, 0.3), 100.0, 0.6)
			add_frenzy(15.0)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 3:
					request_summon(minion_scenes.pick_random(), global_position + Vector2.from_angle(TAU * i / 3.0) * 50.0)
			return 0.9
	return 1.0


func _die() -> void:
	if has_target() and _player.is_charmed():
		_player.release_charm()  # 쓰러지면 전차의 공포도 풀림
	super._die()


func _on_phase_two() -> void:
	Net.announce("마르스: 전쟁은 이제부터다! 전차가 두 번 연달아 달린다", Color(1.0, 0.45, 0.35))
