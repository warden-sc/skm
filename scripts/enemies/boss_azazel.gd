class_name BossAzazel
extends PatternBoss
## 87스테이지 보스: 광야의 타락천사 아자젤 — 사람들에게 칼 벼리는 법을 가르치다 광야에 묶인 감시자 천사. 속죄일에 죄를 짊어진 염소가 그에게 보내졌습니다.
##   BLADES  : 벼린 칼날 탄막 (부채꼴)
##   SANDS   : 광야의 모래 폭풍 — 플레이어 주변 장판
##   WINGS   : 검은 날개 휘두르기 — 몸 주위 고리
##   SUMMON  : 사막의 진 · 감시자 천사 · 네피림 호출
##
## [기믹] 속죄양: 곁의 검은 염소가 아자젤이 받을 피해를 대신 떠안음 — 아자젤에게는 피해의 shield_ratio 만 들어가고 나머지는 염소의 「죄」로 쌓임
##   염소를 보스방 가장자리의 「광야의 문」까지 몰아내면(염소는 플레이어에게서 달아남) 쌓인 죄가 한꺼번에 아자젤에게 돌아가고 크게 휘청
##   염소는 goat_return 초 뒤 새로 나타남
## 체력 50% 이하: 염소가 더 빨리 돌아옴

enum Pattern { BLADES, SANDS, WINGS, SUMMON }

const GATE_SPOT := Vector2(0, -150)

@export var minion_scenes: Array[PackedScene] = []
@export var gate_texture: Texture2D
@export var blade_texture: Texture2D
@export var blade_damage: int = 64
@export var sand_damage: int = 90
@export var wing_damage: int = 96
@export var shield_ratio: float = 0.1
@export var goat_return: float = 12.0

var goat: Scapegoat
var gate: FieldProp
var _goat_left: float = 0.0
var _exiles: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BLADES, Pattern.SANDS, Pattern.WINGS, Pattern.BLADES, Pattern.SUMMON]


func has_goat() -> bool:
	return goat != null and is_instance_valid(goat)


func get_exile_count() -> int:
	return _exiles


func gate_position() -> Vector2:
	return gate.global_position if gate != null and is_instance_valid(gate) else _area().get_center() + GATE_SPOT


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		gate = FieldProp.spawn(self, _area().get_center() + GATE_SPOT, gate_texture, Color(1.0, 0.85, 0.5))
		summon_goat()
	return super._get_move_velocity(delta)


func summon_goat() -> void:
	if is_dead():
		return
	goat = Scapegoat.spawn(self, global_position + Vector2(30, 20), _area())
	_update_status()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if has_goat() and amount > 0:
		var real := calc_damage(amount, armor_pen)
		var kept := maxi(1, roundi(real * shield_ratio))
		goat.add_sins(real - kept)
		super.take_damage(kept, knockback, is_crit, 999999)
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


## 염소를 광야로 내보냄 (테스트에서도 직접 호출)
func exile_goat() -> void:
	if not has_goat() or is_dead():
		return
	var sins := goat.sins
	_exiles += 1
	Fx.burst(goat, goat.global_position, Color(1.0, 0.85, 0.5), 24, 70.0, 0.6, Vector2(0, -50))
	goat.queue_free()
	goat = null
	_goat_left = goat_return * (0.7 if phase_two else 1.0)
	Net.announce("속죄양이 광야로 떠났다! 짊어진 죄 %d 가 아자젤에게 돌아간다" % sins, Color(1.0, 0.85, 0.5))
	super.take_damage(sins, Vector2.ZERO, true, 999999)
	if not is_dead():
		super.stun(6.0)
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if has_goat():
			goat.home = global_position + Vector2(30, 20)
			if goat.global_position.distance_to(gate_position()) <= 30.0:
				exile_goat()
		else:
			_goat_left -= delta
			if _goat_left <= 0.0:
				summon_goat()
	super._physics_process(delta)


func _update_status() -> void:
	if has_goat():
		set_status("속죄양이 피해를 떠안음 — 광야의 문으로 몰아내라", Color(1.0, 0.75, 0.5))
	else:
		set_status("속죄양 없음 — 피해가 그대로", Color(1.0, 0.55, 0.45))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.BLADES:
			for i in 9:
				shoot(dir.rotated((i - 4) * 0.13), 190.0, blade_damage, blade_texture)
			return 0.9
		Pattern.SANDS:
			for i in 5:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 60.0)
				telegraph_strike(at, 26.0, 0.9 + 0.08 * i, sand_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.WINGS:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 54.0, 20.0, 0.85, wing_damage, Elements.Type.DARK)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if has_goat():
		goat.queue_free()
	super._die()


func _on_phase_two() -> void:
	Net.announce("아자젤: 광야는 나의 것이다! 염소가 더 빨리 돌아온다", Color(1.0, 0.75, 0.5))
