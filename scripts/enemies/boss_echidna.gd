class_name BossEchidna
extends PatternBoss
## 47스테이지 보스: 괴물의 어머니 에키드나 — 상반신은 여인, 하반신은 뱀인 모든 괴물의 어머니.
##   COIL   : 똬리 — 몸 주위 고리 장판
##   VENOM  : 독 침 — 독액 탄 부채꼴
##   TAIL   : 꼬리 후려치기 — 플레이어 쪽 장판 세 개
##   LAY    : 알 낳기 — 괴물의 알(체력 따로) egg_count 개
##
## [기믹 1] 괴물의 알: 알은 hatch_time 초 뒤 부화 → 지금까지 나온 보스의 새끼(꼬마 키메라 · 꼬마 히드라 · 꼬마 케르베로스) 중 하나
## [기믹 2] 어미의 분노: 알을 부술 때마다 에키드나의 공격력 +rage_step (최대 rage_max 중첩)
##   → 알을 다 부수면 어미가 사나워지고, 놔두면 새끼가 늘어남 — 무엇을 부술지 고르는 것이 공략
## 체력 50% 이하: 알을 하나 더 낳고 더 빨리 부화

enum Pattern { COIL, VENOM, TAIL, LAY }

@export var egg_scene: PackedScene
@export var baby_scenes: Array[PackedScene] = []
@export var venom_texture: Texture2D
@export var coil_damage: int = 82
@export var venom_damage: int = 56
@export var tail_damage: int = 86
@export var egg_count: int = 3
@export var hatch_time: float = 8.0
@export var egg_hp_ratio: float = 0.02
@export var rage_step: float = 0.06
@export var rage_max: int = 6

var rage: int = 0
var _eggs: Dictionary = {}   # BossPart → 남은 시간
var _egg_queue: int = 0
var _hatched: int = 0
var _base_power: float = 1.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.LAY, Pattern.VENOM, Pattern.COIL, Pattern.TAIL, Pattern.VENOM, Pattern.COIL]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func get_eggs() -> Array[BossPart]:
	var list: Array[BossPart] = []
	for e in _eggs:
		if is_instance_valid(e) and not (e as BossPart).is_dead():
			list.append(e as BossPart)
	return list


func get_hatched_count() -> int:
	return _hatched


## 부화 시간은 에키드나가 기절해 있어도 흐름
func _physics_process(delta: float) -> void:
	if not is_dead():
		for e in _eggs.keys():
			if not is_instance_valid(e) or (e as BossPart).is_dead():
				_eggs.erase(e)
				continue
			_eggs[e] = float(_eggs[e]) - delta
			if float(_eggs[e]) <= 0.0:
				_hatch(e as BossPart)
	super._physics_process(delta)


# ============================================================ 기믹 1: 괴물의 알
func lay_eggs() -> void:
	if egg_scene == null:
		return
	var a := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
	var count := egg_count + (1 if phase_two else 0)
	for i in count:
		_egg_queue += 1
		var at := (global_position + Vector2.from_angle(TAU * i / count + randf_range(-0.3, 0.3)) * randf_range(70.0, 120.0)).clamp(a.position + Vector2(20, 30), a.end - Vector2(20, 20))
		request_summon(egg_scene, at)
	GameManager.show_notice("에키드나가 괴물의 알을 낳았다! 부화하기 전에 부술지, 어미의 분노를 피할지…", Color(0.9, 0.7, 1.0))


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and _egg_queue > 0:
		_egg_queue -= 1
		var egg := minion as BossPart
		egg.boss = self
		egg.follow_boss = false
		egg.max_hp = maxi(1, roundi(max_hp * egg_hp_ratio))
		egg.died.connect(_on_egg_broken)
		_eggs[egg] = hatch_time * (0.75 if phase_two else 1.0)


func _hatch(egg: BossPart) -> void:
	_eggs.erase(egg)
	var at := egg.global_position
	egg.despawn()
	_hatched += 1
	Fx.burst(self, at, Color(0.85, 0.75, 0.95), 18, 60.0, 0.4)
	if not baby_scenes.is_empty():
		request_summon(baby_scenes.pick_random(), at)
	FloatingText.spawn(self, at + Vector2(0, -20), "부화!", Color(0.9, 0.7, 1.0), true)


# ============================================================ 기믹 2: 어미의 분노
func _on_egg_broken(_enemy: Enemy) -> void:
	if is_dead() or rage >= rage_max:
		return
	rage += 1
	power = _base_power * (1.0 + rage_step * rage)
	set_status("어미의 분노 %d (공격력 +%d%%)" % [rage, roundi(rage_step * rage * 100.0)], Color(1.0, 0.6, 0.8))
	FloatingText.spawn(self, global_position + Vector2(0, -60), "내 아이를…!", Color(1.0, 0.5, 0.7), true)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.COIL:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 50.0, 20.0, 0.85, coil_damage, Elements.Type.NATURE)
			return 1.3
		Pattern.VENOM:
			var keep := burn_damage
			burn_damage = 9
			burn_is_poison = true
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.16), 140.0, venom_damage, venom_texture, 0.0, Elements.Type.NATURE)
			burn_damage = keep
			return 1.0
		Pattern.TAIL:
			var dir := direction_to_player()
			for i in 3:
				telegraph_strike(get_hit_center() + dir * (40.0 + 30.0 * i), 24.0, 0.75 + 0.1 * i, tail_damage, Elements.Type.NATURE)
			return 1.2
		Pattern.LAY:
			lay_eggs()
			return 1.0
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("에키드나: 아이들아, 깨어나라! 알이 더 빨리 부화한다", Color(0.9, 0.7, 1.0))
