class_name BossSpartoi
extends PatternBoss
## 52스테이지 보스: 용의 이빨 전사 스파르토이 — 카드모스가 뿌린 아레스의 용의 이빨에서 솟아난 전사들과 그 대장 에키온.
##   PHALANX   : 방진 — 전사들이 일제히 돌격, 대장은 앞으로 창을 내지름
##   SPEARS    : 창 세례 (부채꼴)
##   TEETH     : 용의 이빨을 흩뿌림 — 떨어진 자리가 터지고, 쓰러진 전사가 있으면 그 자리에서 바로 솟아남
##   SUMMON    : 테베 창병 호출
##
## [기믹] 방진: 살아 있는 전사 1명마다 대장의 방어력 +phalanx_defense
## [기믹] 다시 일어남: 쓰러진 전사는 revive_time 초 뒤 용의 이빨에서 다시 솟아남
## [기믹] 던지는 돌: 보스방의 돌을 주우면 전사들 한가운데로 던짐 → 「불화」: 전사들이 서로를 의심하며 싸움
##   전사 1명마다 대장이 최대 체력의 discord_ratio 만큼 피해 · 전사들은 체력 30%를 잃고 기절 · discord_time 동안 되살아나지 않음
##   돌은 stone_respawn 초 뒤 다시 놓임
## 체력 50% 이하: 전사가 더 빨리 되살아남

enum Pattern { PHALANX, SPEARS, TEETH, SUMMON }

const STONE_SPOTS := [Vector2(-200, -100), Vector2(200, -100), Vector2(-200, 110), Vector2(200, 110)]

@export var warrior_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var stone_texture: Texture2D
@export var spear_texture: Texture2D
@export var spear_damage: int = 60
@export var thrust_damage: int = 86
@export var tooth_damage: int = 70
@export var warrior_count: int = 4
@export var phalanx_defense: int = 10
@export var revive_time: float = 6.0
@export var discord_time: float = 6.0
@export var discord_ratio: float = 0.04
@export var stone_respawn: float = 14.0

var warriors: Array[Enemy] = []
var stones: Array[CarryItem] = []
var _revives: Array[Dictionary] = []   # {left, at}
var _revived: int = 0
var _raised: int = 0
var _discord_left: float = 0.0
var _discords: int = 0
var _base_defense: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.PHALANX, Pattern.SPEARS, Pattern.TEETH, Pattern.PHALANX, Pattern.SUMMON]


func get_warriors() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for w in warriors:
		if is_instance_valid(w) and not w.is_dead():
			alive.append(w)
	return alive


func get_revived_count() -> int:
	return _revived


func get_discord_count() -> int:
	return _discords


func is_in_discord() -> bool:
	return _discord_left > 0.0


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for i in warrior_count:
			_raise_warrior(global_position + Vector2.from_angle(TAU * i / warrior_count) * 50.0)
		for spot in STONE_SPOTS:
			var stone := CarryItem.spawn(self, _area().get_center() + spot, stone_texture, "돌", Color(0.85, 0.85, 0.8))
			if stone != null:
				stone.follow_player = false
				stone.picked_up.connect(_on_stone_picked)
				stones.append(stone)
	return super._get_move_velocity(delta)


func _physics_process(delta: float) -> void:
	if not is_dead():
		if _discord_left > 0.0:
			_discord_left -= delta
			if _discord_left <= 0.0:
				set_status("", Color.WHITE)
		else:
			for r in _revives:
				r["left"] -= delta * (1.4 if phase_two else 1.0)
			for r in _revives.duplicate():
				if r["left"] <= 0.0:
					_revives.erase(r)
					_raise_warrior(r["at"])
		defense = _base_defense + phalanx_defense * get_warriors().size()
	super._physics_process(delta)


func _raise_warrior(at: Vector2) -> void:
	if warrior_scene == null or is_dead():
		return
	Fx.burst(self, at, Color(0.85, 0.8, 0.6), 14, 60.0, 0.5, Vector2(0, -50))
	request_summon(warrior_scene, at)


func register_minion(minion: Enemy) -> void:
	if warrior_scene != null and minion.scene_file_path == warrior_scene.resource_path:
		warriors.append(minion)
		minion.died.connect(_on_warrior_died)
		_raised += 1
		if _raised > warrior_count:
			_revived += 1


func _on_warrior_died(warrior: Enemy) -> void:
	warriors.erase(warrior)
	if not is_dead():
		_revives.append({"left": revive_time, "at": warrior.global_position})


func _on_stone_picked(stone: CarryItem) -> void:
	if is_dead():
		return
	stone.hide_for(stone_respawn)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var from := player.global_position if player != null else stone.global_position
	CarryItem.fly(self, from, get_hit_center(), stone_texture)
	_after(0.35, discord)


## 「불화」: 던진 돌이 전사들 사이에 떨어짐 (테스트에서도 직접 호출)
func discord() -> void:
	if is_dead():
		return
	var alive := get_warriors()
	_discords += 1
	_discord_left = discord_time
	for w in alive:
		w.take_damage(roundi(w.max_hp * 0.3), Vector2.ZERO, false, 999999)
		if not w.is_dead():
			w.stun(3.0)
			Fx.cross_glint(w, w.get_hit_center(), Color(1.0, 0.4, 0.3), 14.0)
	take_damage(roundi(max_hp * discord_ratio * maxi(alive.size(), 1)), Vector2.ZERO, false, 999999)
	stun(2.0)
	set_status("불화! 전사들이 서로를 겨눔", Color(1.0, 0.5, 0.4))
	GameManager.show_notice("돌이 날아들자 스파르토이들이 서로를 의심하며 칼을 겨눈다!", Color(1.0, 0.75, 0.5))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.PHALANX:
			if not is_in_discord():
				for w in get_warriors():
					w.give_command(Enemy.Command.CHARGE)
			for i in 8:
				telegraph_strike(get_hit_center() + dir * (24.0 + 22.0 * i), 15.0, 0.65 + 0.03 * i, thrust_damage, Elements.Type.NONE)
			return 1.2
		Pattern.SPEARS:
			for i in 7:
				shoot(dir.rotated((i - 3) * 0.16), 170.0, spear_damage, spear_texture)
			return 1.0
		Pattern.TEETH:
			for i in 5:
				var at := _player.global_position + Vector2.from_angle(TAU * i / 5.0 + randf()) * randf_range(30.0, 80.0)
				telegraph_strike(at, 20.0, 0.9, tooth_damage, Elements.Type.EARTH)
			if not _revives.is_empty() and not is_in_discord():
				var r: Dictionary = _revives.pop_front()
				_after(0.9, func() -> void: _raise_warrior(r["at"]))
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				request_summon(minion_scenes.pick_random(), global_position + Vector2(0, 40))
			return 0.8
	return 1.0


func _die() -> void:
	for w in get_warriors():
		w.despawn()
	_revives.clear()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("에키온: 용의 이빨은 다시 솟는다! 전사들이 더 빨리 되살아난다", Color(0.9, 0.85, 0.6))
