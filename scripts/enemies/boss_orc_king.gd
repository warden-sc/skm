class_name BossOrcKing
extends PatternBoss
## 6스테이지 보스: 오크킹 — 머리에 금관을 쓴 거대 오크.
##   SLAM    : 도끼를 치켜든 뒤 땅을 내려찍어 주변 큰 장판 + 돌 파편 고리
##   AXE     : 손도끼 투척 (2페이즈 3개)
##   CHARGE  : 몸을 웅크렸다가 플레이어에게 돌진
##   WAR_CRY : [기믹] 족장의 함성
##
## [기믹] 족장의 함성: "전군, 돌격!" 오크 전사 · 홉고블린을 부르고, 오크킹이 부른 부하 전원을 강화
##   (공격력 x1.4 · 이동 속도 x1.3 · 방어력 +8, 붉게 빛남) → 부하를 먼저 정리하면 효과가 사라짐
## [기믹] 광폭화: 잃은 체력에 비례해 오크킹의 공격력·이동 속도가 오름 (빈사 직전 공격력 최대 +80%)
## 체력 50% 이하: 도끼 수 증가

enum Pattern { SLAM, AXE, CHARGE, WAR_CRY }

@export var axe_texture: Texture2D
@export var rock_texture: Texture2D
@export var minion_scenes: Array[PackedScene] = []
@export var slam_damage: int = 44
@export var axe_damage: int = 30

const WAR_CRY_POWER := 1.4
const WAR_CRY_SPEED := 1.3
const WAR_CRY_DEFENSE := 8
## 광폭화: 체력이 0 에 가까울 때의 최대 공격력 증가율
const BERSERK_MAX := 0.8

var _charge_dir: Vector2 = Vector2.ZERO
var _charging: bool = false
var _minions: Array[Enemy] = []
var _base_power: float = 1.0
var _base_speed: float = 0.0
var _base_chase: float = 0.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SLAM, Pattern.AXE, Pattern.CHARGE, Pattern.WAR_CRY, Pattern.AXE, Pattern.SLAM, Pattern.CHARGE]
	_base_power = power
	_base_speed = move_speed
	_base_chase = chase_time


# ============================================================ 기믹: 광폭화
## 잃은 체력 비율 (0 = 멀쩡, 1 = 빈사)
func get_rage() -> float:
	return clampf(1.0 - float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)


func _update_berserk() -> void:
	var rage := get_rage()
	power = _base_power * (1.0 + BERSERK_MAX * rage)
	move_speed = _base_speed * (1.0 + 0.4 * rage)
	chase_time = _base_chase * (1.0 - 0.4 * rage)
	base_tint = Color(1.0, 1.0 - 0.45 * rage, 1.0 - 0.45 * rage)
	if rage >= 0.1 and (get_status_text().is_empty() or get_status_text().begins_with("광폭화")):
		set_status("광폭화: 공격력 +%d%%" % roundi(BERSERK_MAX * rage * 100.0), Color(1.0, 0.45, 0.35))


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if not is_dead():
		_update_berserk()


func _get_move_velocity(delta: float) -> Vector2:
	_update_berserk()  # 함성 문구가 사라진 뒤에도 광폭화 표시가 다시 보이도록 매 프레임 갱신
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 족장의 함성
func register_minion(minion: Enemy) -> void:
	_minions.append(minion)


func get_minions() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for minion in _minions:
		if is_instance_valid(minion) and not minion.is_dead():
			alive.append(minion)
	_minions = alive
	return _minions


## 오크킹이 부른 부하 전원 강화 (한 번만)
func rally_minions() -> int:
	var count := 0
	for minion in get_minions():
		if minion.has_meta(&"war_cry"):
			continue
		minion.set_meta(&"war_cry", true)
		minion.power *= WAR_CRY_POWER
		minion.contact_damage = roundi(minion.contact_damage * WAR_CRY_POWER)
		minion.move_speed *= WAR_CRY_SPEED
		minion.defense += WAR_CRY_DEFENSE
		minion.base_tint = Color(1.3, 0.75, 0.7)
		var fire := Fx.make_aura(Color(1.0, 0.4, 0.25), 6, 6.0, Vector2(0, -40), 0.5)
		fire.position = Vector2(0, -8)
		minion.add_child(fire)
		fire.emitting = true
		count += 1
	return count


func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.SLAM:
			set_status("")
			telegraph_strike(get_hit_center(), 64.0, 1.0, slam_damage, Elements.Type.EARTH)
			_after(1.0, _slam_rocks)
			return 1.5
		Pattern.AXE:
			var count := 3 if phase_two else 1
			for i in count:
				_after(0.25 * i, _throw_axe)
			return 0.4 + 0.25 * count
		Pattern.CHARGE:
			_charging = false
			_after(0.7, _begin_charge)
			return 1.4
		Pattern.WAR_CRY:
			_war_cry()
			return 1.0
	return 1.0


func _casting_velocity(_delta: float) -> Vector2:
	if _charging:
		Fx.burst(self, get_hit_center() + Vector2(0, 14), Color(0.75, 0.55, 0.3), 3, 25.0, 0.4, Vector2(0, 60))
		return _charge_dir * move_speed * (6.0 if phase_two else 5.0)
	return Vector2.ZERO


func _begin_charge() -> void:
	if is_dead() or not has_target():
		return
	_charge_dir = direction_to_player()
	_charging = true
	_after(0.55, func() -> void: _charging = false)


func _slam_rocks() -> void:
	if is_dead():
		return
	for i in 16:
		shoot(Vector2.RIGHT.rotated(TAU * i / 16.0), 110.0, axe_damage - 8, rock_texture, 0.0, Elements.Type.EARTH)
	if _player != null:
		_player.shake_camera(6.0)


func _throw_axe() -> void:
	if is_dead() or not has_target():
		return
	shoot(direction_to_player().rotated(randf_range(-0.12, 0.12)), 170.0, axe_damage, axe_texture)


func _war_cry() -> void:
	set_status("족장의 함성: 전군, 돌격!", Color(1.0, 0.75, 0.4))
	_after(1.4, set_status.bind("", Color.WHITE))
	if not minion_scenes.is_empty():
		for i in (3 if phase_two else 2):
			request_summon(minion_scenes.pick_random(), global_position + Vector2.from_angle(TAU * i / 3.0) * 50.0)
	var rallied := rally_minions()
	if rallied > 0:
		Net.announce("족장의 함성! 오크킹의 부하 %d명이 강해졌다" % rallied, Color(1.0, 0.55, 0.35))
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.7, 0.3), 70.0, 0.4)
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.4, 0.25), 110.0, 0.5)
	if _player != null:
		_player.shake_camera(3.0)


func _on_phase_two() -> void:
	Net.announce("오크킹이 분노했다!", Color(1.0, 0.5, 0.3))
	Fx.explosion(self, get_hit_center(), Color(1.0, 0.5, 0.3), 70.0, 3)
