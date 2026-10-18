class_name BossStymphalian
extends PatternBoss
## 51스테이지 보스: 스팀팔로스의 괴조 — 아레스가 기르던, 청동 부리와 청동 깃털을 가진 식인 새.
##   FEATHERS  : 청동 깃털을 부채꼴로 흩뿌림
##   DIVE      : 플레이어 쪽으로 일직선 급강하 (줄지은 장판)
##   DROPPINGS : 독 오물 — 플레이어 주변에 독 장판
##   SUMMON    : 청동부리 새 호출
##
## [기믹] 하늘 높이: 날아 있는 동안은 활만 닿음
## [기믹] 청동 징: 보스방의 징 3개 중 하나를 공격해 울리면 놀란 괴조가 땅으로 떨어짐
##   → 기절 + ground_time 초 동안 땅에 내려와 근접 공격도 통함. 징은 한 번 울리면 gong_cooldown 초 동안 다시 울리지 않음
## 체력 50% 이하: 깃털이 한 번 더 쏟아지고, 땅에 머무는 시간이 짧아짐

enum Pattern { FEATHERS, DIVE, DROPPINGS, SUMMON }

const FLIGHT_HEIGHT := 16.0
## 보스방 가운데 기준 징 위치
const GONG_SPOTS := [Vector2(-150, -70), Vector2(150, -70), Vector2(0, 110)]

@export var gong_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var feather_texture: Texture2D
@export var feather_damage: int = 56
@export var dive_damage: int = 84
@export var dropping_damage: int = 68
@export var ground_time: float = 6.0
@export var gong_cooldown: float = 10.0

var gongs: Array[BossPart] = []
var _gong_cd: Array[float] = [0.0, 0.0, 0.0]
var _ground_left: float = 0.0
var _rings: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.FEATHERS, Pattern.DIVE, Pattern.DROPPINGS, Pattern.FEATHERS, Pattern.SUMMON]
	airborne = true
	immune_text = "하늘 높이! 활만 닿음 — 징을 울려라"


func get_ring_count() -> int:
	return _rings


func is_grounded() -> bool:
	return not airborne


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if gong_scene != null:
			for spot in GONG_SPOTS:
				request_summon(gong_scene, _area().get_center() + spot)
		set_status("하늘 높이 — 활만 닿음 · 징을 울려라", Color(1.0, 0.85, 0.5))
	return super._get_move_velocity(delta)


## 징 쿨타임 · 땅에 머무는 시간은 기절 중에도 흐름
func _physics_process(delta: float) -> void:
	if not is_dead():
		for i in _gong_cd.size():
			_gong_cd[i] = maxf(_gong_cd[i] - delta, 0.0)
		if _ground_left > 0.0:
			_ground_left -= delta
			if _ground_left <= 0.0:
				take_off()
	super._physics_process(delta)


## 날아 있을 땐 플레이어 주위를 맴돎
func _chase_velocity(delta: float) -> Vector2:
	if not airborne:
		return super._chase_velocity(delta) * 0.7
	var to_player := global_position - _player.global_position
	var orbit := to_player.normalized().rotated(0.9) * 110.0 + _player.global_position
	return global_position.direction_to(orbit) * move_speed * 1.6


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart or gongs.size() >= GONG_SPOTS.size():
		return
	var gong := minion as BossPart
	gong.boss = self
	gong.follow_boss = false
	gong.show_bar = false
	gong.relay_ratio = 0.001 * (gongs.size() + 1)  # 몇 번째 징인지 구분용 (피해는 넘기지 않음)
	gongs.append(gong)


## 징을 때리면 BossPart 가 여기로 알려 줌 (ratio 로 몇 번째 징인지 구분)
func take_weak_point_hit(_amount: int, _kb: Vector2, _is_crit: bool, _armor_pen: int, ratio: float) -> void:
	ring_gong(clampi(roundi(ratio * 1000.0) - 1, 0, gongs.size() - 1))


func ring_gong(index: int) -> bool:
	if index < 0 or index >= gongs.size() or is_dead():
		return false
	var gong := gongs[index]
	if _gong_cd[index] > 0.0:
		FloatingText.spawn(gong, gong.global_position + Vector2(0, -30), "아직 울림이 남아 있다 (%.0f초)" % _gong_cd[index], Color(0.8, 0.8, 0.7))
		return false
	_gong_cd[index] = gong_cooldown
	_rings += 1
	Fx.shockwave(gong, gong.get_hit_center(), Color(1.0, 0.85, 0.4), 120.0, 0.5)
	FloatingText.spawn(gong, gong.global_position + Vector2(0, -30), "댕—!", Color(1.0, 0.9, 0.5), true)
	land()
	return true


func land() -> void:
	var was_flying := airborne
	airborne = false
	_ground_left = ground_time * (0.75 if phase_two else 1.0)
	set_status("땅으로 떨어짐! 근접 공격도 통함", Color(1.0, 0.6, 0.4))
	if was_flying:
		super.stun(2.5)
		Fx.burst(self, global_position, Color(0.8, 0.6, 0.3), 20, 70.0, 0.5)
		GameManager.show_notice("징 소리에 놀란 괴조가 땅으로 떨어졌다! 지금이 기회", Color(1.0, 0.85, 0.5))


func take_off() -> void:
	_ground_left = 0.0
	airborne = true
	set_status("하늘 높이 — 활만 닿음 · 징을 울려라", Color(1.0, 0.85, 0.5))
	Fx.burst(self, global_position, Color(0.8, 0.6, 0.3), 14, 60.0, 0.5, Vector2(0, -60))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.FEATHERS:
			for w in (3 if phase_two else 2):
				_after(0.35 * w, func() -> void:
					if is_dead() or not has_target():
						return
					var aim := direction_to_player()
					for i in 9:
						shoot(aim.rotated((i - 4) * 0.13 + w * 0.06), 150.0, feather_damage, feather_texture))
			return 1.2
		Pattern.DIVE:
			for i in 9:
				telegraph_strike(get_hit_center() + dir * (26.0 + 26.0 * i), 18.0, 0.7 + 0.04 * i, dive_damage, Elements.Type.NONE)
			return 1.2
		Pattern.DROPPINGS:
			for i in 6:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0)
				var strike := telegraph_strike(at, 20.0, 0.9 + 0.1 * i, dropping_damage, Elements.Type.NATURE)
				if strike != null:
					strike.burn_poison = true
					strike.burn_damage = maxi(strike.burn_damage, 8)
					strike.burn_duration = 3.0
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if airborne:
		sprite.position.y += -FLIGHT_HEIGHT + sin(_anim_time * 5.0) * 2.0


func _on_phase_two() -> void:
	GameManager.show_notice("괴조가 날카롭게 운다! 청동 깃털이 더 쏟아진다", Color(1.0, 0.75, 0.4))
