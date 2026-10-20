class_name BossPythia
extends PatternBoss
## 69스테이지 보스: 델포이의 여사제 피티아 — 삼발이 위에서 땅의 연기를 마시고 아폴론의 신탁을 전하는 무녀.
##   BOLTS  : 신탁의 구슬 (부채꼴)
##   VAPOR  : 땅의 증기 — 몸 주위 고리
##   PUFF   : 연기 구름 — 플레이어 주변에 신탁의 연기를 피움 (puff_time 초)
##   SUMMON : 신탁 수호병 · 연기 무녀 호출
##
## [기믹] 신탁의 삼발이: 보스방의 삼발이 3개(체력 따로) — oracle_interval 초마다 그중 하나에 「신탁이 내림」(빛남)
##   신탁이 내린 삼발이가 서 있는 동안 피티아는 보호막 — 받는 피해 shield_ratio 배
##   신탁이 내린 삼발이를 부수면 보호막이 걷히고 휘청임 (다음 신탁까지). 다른 삼발이를 부수면 그 삼발이만 없어짐
##   삼발이가 모두 부서지면 보호막이 영영 사라짐
## [기믹] 신탁의 연기: 삼발이 곁(smoke_radius)과 연기 구름 속에서는 조준이 크게 흔들림
## 체력 50% 이하: 신탁이 더 자주 옮겨 감

enum Pattern { BOLTS, VAPOR, PUFF, SUMMON }

const TRIPOD_SPOTS := [Vector2(-210, -100), Vector2(210, -100), Vector2(0, 120)]

@export var tripod_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var orb_texture: Texture2D
@export var bolt_damage: int = 60
@export var vapor_damage: int = 86
@export var tripod_hp_ratio: float = 0.03
@export var oracle_interval: float = 8.0
@export var shield_ratio: float = 0.1
@export var smoke_radius: float = 60.0
@export var puff_time: float = 4.0

var tripods: Array[BossPart] = []
var oracle: BossPart
var _oracle_left: float = 0.0
var _breaks: int = 0
var _puffs: Array[Dictionary] = []   # {at, left}
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BOLTS, Pattern.PUFF, Pattern.VAPOR, Pattern.BOLTS, Pattern.SUMMON]


func get_tripods() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for t in tripods:
		if is_instance_valid(t) and not t.is_dead():
			alive.append(t)
	return alive


func is_shielded() -> bool:
	return oracle != null and is_instance_valid(oracle) and not oracle.is_dead()


func get_break_count() -> int:
	return _breaks


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if tripod_scene != null:
			for spot in TRIPOD_SPOTS:
				request_summon(tripod_scene, _area().get_center() + spot)
		choose_oracle()
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart:
		return
	var tripod := minion as BossPart
	tripod.boss = self
	tripod.follow_boss = false
	tripod.max_hp = maxi(1, roundi(max_hp * tripod_hp_ratio))
	tripod.hp = tripod.max_hp
	tripod.died.connect(_on_tripod_broken)
	tripods.append(tripod)
	var smoke := Fx.make_aura(Color(0.85, 0.8, 1.0), 14, 18.0, Vector2(0, -20), 1.2)
	smoke.position = Vector2(0, -16)
	tripod.add_child(smoke)
	smoke.emitting = true


## 신탁을 다른 삼발이로 옮김 (테스트에서도 직접 호출)
func choose_oracle() -> void:
	_oracle_left = oracle_interval * (0.7 if phase_two else 1.0)
	if oracle != null and is_instance_valid(oracle):
		oracle.base_tint = Color.WHITE
	var alive := get_tripods()
	oracle = alive.pick_random() if not alive.is_empty() else null
	if oracle != null:
		oracle.base_tint = Color(1.4, 1.2, 1.8)
		if oracle.is_inside_tree():
			Fx.shockwave(oracle, oracle.get_hit_center(), Color(0.85, 0.75, 1.0), 40.0, 0.5)
	_update_status()


func _on_tripod_broken(tripod: Enemy) -> void:
	if is_dead():
		return
	if tripod == oracle:
		oracle = null
		_breaks += 1
		super.stun(6.0)
		Fx.burst(self, get_hit_center(), Color(0.85, 0.75, 1.0), 24, 70.0, 0.6)
		Net.announce("신탁이 내린 삼발이를 부쉈다! 피티아의 보호막이 걷힌다", Color(0.85, 0.8, 1.0))
		_oracle_left = 10.0
	_update_status()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_shielded() and amount > 0:
		amount = maxi(1, roundi(amount * shield_ratio))
		if _immune_text_cooldown <= 0.0:
			_immune_text_cooldown = 0.8
			FloatingText.spawn(self, global_position + Vector2(0, -44), "신탁의 보호막!", Color(0.85, 0.8, 1.0))
	super.take_damage(amount, knockback, is_crit, armor_pen)


func is_in_smoke(at: Vector2) -> bool:
	for t in get_tripods():
		if t.global_position.distance_to(at) <= smoke_radius:
			return true
	for p in _puffs:
		if (p["at"] as Vector2).distance_to(at) <= 40.0:
			return true
	return false


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if not get_tripods().is_empty():
			_oracle_left -= delta
			if _oracle_left <= 0.0:
				choose_oracle()
		for p in _puffs:
			p["left"] -= delta
		for p in _puffs.duplicate():
			if p["left"] <= 0.0:
				_puffs.erase(p)
		if has_target() and is_in_smoke(_player.global_position):
			_player.mark_smoke()
	super._physics_process(delta)


func _update_status() -> void:
	if is_shielded():
		set_status("신탁의 보호막 — 빛나는 삼발이를 부숴라", Color(0.85, 0.8, 1.0))
	elif get_tripods().is_empty():
		set_status("신탁이 끊김", Color(1.0, 0.6, 0.5))
	else:
		set_status("보호막 없음 — 다음 신탁까지", Color(1.0, 0.85, 0.6))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.BOLTS:
			for i in 7:
				shoot(dir.rotated((i - 3) * 0.16), 140.0, bolt_damage, orb_texture, 0.0, Elements.Type.ARCANE)
			return 0.9
		Pattern.VAPOR:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 50.0, 20.0, 0.85, vapor_damage, Elements.Type.ARCANE)
			return 1.2
		Pattern.PUFF:
			for i in 3:
				var at := _player.global_position + Vector2.from_angle(TAU * i / 3.0 + randf()) * randf_range(10.0, 50.0)
				_puffs.append({"at": at, "left": puff_time})
				Fx.burst(self, at, Color(0.85, 0.8, 1.0), 26, 30.0, puff_time * 0.5, Vector2(0, -10))
			return 0.9
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("피티아: 아폴론의 목소리가 들린다…! 신탁이 더 자주 옮겨 간다", Color(0.85, 0.8, 1.0))
