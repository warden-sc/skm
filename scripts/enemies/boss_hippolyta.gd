class_name BossHippolyta
extends PatternBoss
## 54스테이지 보스: 아마존 여왕 히폴리테 — 아레스의 딸, 아버지에게 받은 「전쟁의 허리띠」를 찬 여전사들의 여왕.
##   AXE     : 양날 도끼 — 앞쪽 넓게 휘두름 + 몸 주위 고리
##   ARROWS  : 아마존 화살 세례
##   CHARGE  : 말을 탄 듯 일직선 돌격 (예고선 뒤 빠르게 돌진)
##   SUMMON  : 아마존 기마병 · 궁수 호출
##
## [기믹] 전쟁의 허리띠: 허리에 찬 허리띠(체력 따로)가 있는 동안 공격력 +girdle_power · 방어력 +girdle_defense · 기절하지 않음
##   허리띠를 끊으면 효과가 사라지고 크게 휘청임 (기절)
## 체력 50% 이하: 「아마존의 함성」 — 기마병 3명이 한꺼번에 달려옴

enum Pattern { AXE, ARROWS, CHARGE, SUMMON }

@export var girdle_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var rider_scene: PackedScene
@export var arrow_texture: Texture2D
@export var axe_damage: int = 88
@export var arrow_damage: int = 56
@export var charge_damage: int = 92
@export var girdle_hp_ratio: float = 0.04
@export var girdle_power: float = 0.25
@export var girdle_defense: int = 20

var girdle: BossPart
var _girdle_broken: bool = false
var _base_power: float = 1.0
var _base_defense: int = 0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_windup: float = 0.0
var _charge_left: float = 0.0
var _charge_hit: bool = false
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.AXE, Pattern.ARROWS, Pattern.CHARGE, Pattern.AXE, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power
	_base_defense = defense


func get_girdle() -> BossPart:
	return girdle if girdle != null and is_instance_valid(girdle) and not girdle.is_dead() else null


func has_girdle() -> bool:
	return get_girdle() != null


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if girdle_scene != null:
			request_summon(girdle_scene, global_position + Vector2(0, -16))
	if _charge_windup > 0.0 or _charge_left > 0.0:
		return _charge_velocity(delta)
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and girdle == null and not _girdle_broken:
		girdle = minion as BossPart
		girdle.boss = self
		girdle.follow_boss = true
		girdle.anchor_offset = Vector2(0, -16)
		girdle.max_hp = maxi(1, roundi(max_hp * girdle_hp_ratio))
		girdle.hp = girdle.max_hp
		girdle.died.connect(_on_girdle_broken)
		power = _base_power * (1.0 + girdle_power)
		defense = _base_defense + girdle_defense
		set_status("전쟁의 허리띠 — 공격력·방어력 상승 · 기절하지 않음", Color(1.0, 0.8, 0.4))


## 허리띠를 찬 동안에는 기절하지 않음
func stun(duration: float) -> void:
	if has_girdle():
		FloatingText.spawn(self, global_position + Vector2(0, -40), "허리띠의 가호!", Color(1.0, 0.8, 0.4))
		return
	super.stun(duration)


func _on_girdle_broken(_enemy: Enemy) -> void:
	girdle = null
	_girdle_broken = true
	power = _base_power
	defense = _base_defense
	set_status("허리띠가 끊어짐", Color(1.0, 0.6, 0.5))
	super.stun(4.0)
	Fx.burst(self, get_hit_center(), Color(1.0, 0.8, 0.3), 24, 80.0, 0.6)
	Net.announce("전쟁의 허리띠를 끊었다! 히폴리테가 크게 휘청인다", Color(1.0, 0.85, 0.5))


func _charge_velocity(delta: float) -> Vector2:
	if _charge_windup > 0.0:
		_charge_windup -= delta
		return Vector2.ZERO
	_charge_left -= delta
	if not _charge_hit and has_target() and global_position.distance_to(_player.global_position) < 26.0:
		_charge_hit = true
		_player.take_hit(roundi(charge_damage * power), global_position, self)
	return _charge_dir * 330.0


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.AXE:
			for i in 7:
				telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.3) * 50.0, 22.0, 0.7, axe_damage, Elements.Type.NONE)
			for i in 8:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 8.0) * 30.0, 16.0, 1.0, axe_damage - 12, Elements.Type.NONE)
			return 1.3
		Pattern.ARROWS:
			for w in 3:
				_after(0.25 * w, func() -> void:
					if is_dead() or not has_target():
						return
					var aim := direction_to_player()
					for i in 5:
						shoot(aim.rotated((i - 2) * 0.12), 190.0, arrow_damage, arrow_texture))
			return 1.1
		Pattern.CHARGE:
			_charge_dir = dir
			_charge_windup = 0.55
			_charge_left = 0.6
			_charge_hit = false
			for i in 10:
				Fx.flash(self, global_position + dir * (20.0 + 20.0 * i), Color(1.0, 0.5, 0.4), 10.0, 0.55)  # 돌격 예고선
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("히폴리테: 아마존이여, 달려라! 기마병이 몰려온다", Color(1.0, 0.6, 0.5))
	if rider_scene != null:
		for i in 3:
			request_summon(rider_scene, global_position + Vector2.from_angle(TAU * i / 3.0) * 60.0)
