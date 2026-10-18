class_name BossLupus
extends PatternBoss
## 59스테이지 보스: 마르스의 늑대 루푸스 — 군신 마르스를 따르는 늑대 무리의 우두머리.
##   BITE    : 달려들어 물기 (앞쪽 장판 셋)
##   HOWL    : 울부짖음 — 몸 주위 충격파 + 무리를 pack_max 마리까지 다시 불러 모음
##   PECK    : 마르스의 딱따구리가 플레이어를 쪼아 「표식」 → 표식이 남은 동안 무리 전체가 플레이어에게 돌격
##   SUMMON  : 늑대 전사 호출
##
## [기믹] 무리의 힘: 살아 있는 무리 늑대 1마리마다 우두머리의 방어력 +pack_defense · 공격력 +pack_power
## [기믹] 무리를 흩어라: 무리가 한 마리도 남지 않으면 우두머리가 크게 휘청이고(기절), 다음 울부짖음까지 힘이 빠짐
## 체력 50% 이하: 울부짖음이 잦아짐

enum Pattern { BITE, HOWL, PECK, SUMMON }

@export var wolf_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var bite_damage: int = 92
@export var howl_damage: int = 70
@export var peck_damage: int = 40
@export var start_pack: int = 4
@export var pack_max: int = 6
@export var pack_defense: int = 6
@export var pack_power: float = 0.05
@export var mark_time: float = 5.0

var pack: Array[Enemy] = []
var _scatters: int = 0
var _mark_left: float = 0.0
var _base_defense: int = 0
var _base_power: float = 1.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.BITE, Pattern.PECK, Pattern.BITE, Pattern.HOWL, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power
	_base_defense = defense


func get_pack() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for w in pack:
		if is_instance_valid(w) and not w.is_dead():
			alive.append(w)
	return alive


func get_scatter_count() -> int:
	return _scatters


func is_player_marked() -> bool:
	return _mark_left > 0.0


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		call_pack(start_pack)
	return super._get_move_velocity(delta)


## 무리를 n 마리까지 불러 모음
func call_pack(target_count: int) -> void:
	if wolf_scene == null or is_dead():
		return
	var need := mini(target_count, pack_max) - get_pack().size()
	for i in need:
		request_summon(wolf_scene, global_position + Vector2.from_angle(TAU * i / maxf(need, 1)) * 60.0)


func register_minion(minion: Enemy) -> void:
	if wolf_scene != null and minion.scene_file_path == wolf_scene.resource_path:
		pack.append(minion)
		minion.died.connect(_on_wolf_died)


func _on_wolf_died(wolf: Enemy) -> void:
	pack.erase(wolf)
	if get_pack().is_empty() and not is_dead():
		_scatters += 1
		super.stun(5.0)
		Fx.burst(self, get_hit_center(), Color(0.7, 0.7, 0.75), 20, 70.0, 0.6)
		GameManager.show_notice("무리가 흩어졌다! 루푸스가 홀로 남아 휘청인다", Color(0.85, 0.85, 0.9))


func _physics_process(delta: float) -> void:
	if not is_dead():
		var n := get_pack().size()
		defense = _base_defense + pack_defense * n
		power = _base_power * (1.0 + pack_power * n)
		if _mark_left > 0.0:
			_mark_left -= delta
			if Engine.get_physics_frames() % 20 == 0:
				for w in get_pack():
					w.give_command(Enemy.Command.CHARGE)
		if n > 0:
			set_status("무리의 힘 ×%d (방어력 +%d)" % [n, pack_defense * n], Color(0.9, 0.75, 0.7))
		else:
			set_status("무리가 흩어짐 — 힘이 빠짐", Color(0.7, 0.85, 1.0))
	super._physics_process(delta)


## 딱따구리의 표식 (테스트에서도 직접 호출)
func mark_player() -> void:
	if not has_target():
		return
	_mark_left = mark_time
	_player.mark_floor_status("딱따구리의 표식")
	FloatingText.spawn(_player, _player.global_position + Vector2(0, -28), "표식! 늑대들이 몰려온다", Color(1.0, 0.5, 0.4), true)
	for w in get_pack():
		w.give_command(Enemy.Command.CHARGE)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.BITE:
			for i in 3:
				telegraph_strike(get_hit_center() + dir * (36.0 + 28.0 * i), 24.0, 0.6 + 0.08 * i, bite_damage, Elements.Type.NONE)
			return 1.0
		Pattern.HOWL:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 52.0, 20.0, 0.9, howl_damage, Elements.Type.NONE)
			Fx.shockwave(self, get_hit_center(), Color(0.9, 0.5, 0.4), 90.0, 0.6)
			call_pack(pack_max)
			GameManager.show_notice("루푸스가 울부짖는다! 늑대 무리가 다시 모여든다", Color(0.9, 0.7, 0.6))
			return 1.3
		Pattern.PECK:
			var at := _player.global_position
			var strike := telegraph_strike(at, 22.0, 0.8, peck_damage, Elements.Type.NONE)
			if strike != null:
				strike.color = Color(0.95, 0.95, 1.0)
			_after(0.8, func() -> void:
				if not is_dead() and has_target() and _player.global_position.distance_to(at) <= 24.0 and not _player.is_dashing():
					mark_player())
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				request_summon(minion_scenes.pick_random(), global_position + Vector2(0, 40))
			return 0.8
	return 1.0


func _die() -> void:
	for w in get_pack():
		w.despawn()
	super._die()


func _on_phase_two() -> void:
	pattern_order = [Pattern.BITE, Pattern.HOWL, Pattern.PECK, Pattern.BITE, Pattern.HOWL, Pattern.SUMMON]
	GameManager.show_notice("루푸스의 눈이 붉게 타오른다! 울부짖음이 잦아진다", Color(1.0, 0.5, 0.4))
