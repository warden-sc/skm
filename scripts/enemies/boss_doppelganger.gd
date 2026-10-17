class_name BossDoppelganger
extends PatternBoss
## 15스테이지 보스: 거울에 갇힌 미혹의 도플갱어 — 오래도록 거울 속에 갇혀 있던 그림자. 비춘 자의 모습과 기술을 훔친다.
## 보스방에 들어가면 뒤에 커다란 거울이 서 있고, 도플갱어가 거울 안에서 걸어 나옵니다 (그동안은 공격이 통하지 않음).
##   SHARDS : 거울 파편 부채꼴
##   BLINK  : 플레이어 등 뒤로 순간이동해 베기
##   RAIN   : 플레이어 주변에 거울 조각 낙하 장판
##   SUMMON : 거울 망령 호출
##
## [기믹 1페이즈] 따라하기: 플레이어가 공격하면 잠시 뒤 같은 종류의 공격으로 되갚음
##   검·단검 → 플레이어 쪽으로 파고들며 베기 / 활 → 화살 / 지팡이 → 플레이어 발밑에 마법 장판
## [기믹 2페이즈] 분신: 체력 50% 이하에서 분신을 최대 5개까지 불러내고, 진짜 도플갱어가 분신들 사이를 계속 옮겨 다님
##   (swap_interval 마다 무작위 분신과 자리를 바꿈)
##   거울은 따로 체력이 있음 → 거울을 부수면 분신이 모두 사라지고 다시 부를 수 없음

enum Pattern { SHARDS, BLINK, RAIN, SUMMON }
enum Mimic { NONE, SLASH, ARROW, SPELL }

const MAX_CLONES := 5
const EMERGE_TIME := 1.3
const EMERGE_DISTANCE := 38.0

@export var mirror_scene: PackedScene
@export var clone_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var shard_texture: Texture2D
@export var arrow_texture: Texture2D
@export var shard_damage: int = 30
@export var slash_damage: int = 50
@export var mirror_hp_ratio: float = 0.14
@export var clone_hp_ratio: float = 0.02
@export var swap_interval: float = 2.6
@export var clone_interval: float = 5.0

var mirror: BossPart
var _clones: Array[DoppelClone] = []
var _mirror_requested: bool = false
var _mirror_broken: bool = false
var _emerge_left: float = -1.0
var _mimic_cooldown: float = 0.0
var _last_mimic: Mimic = Mimic.NONE
var _mimics: int = 0
var _lunge_left: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _swap_timer: float = 0.0
var _clone_timer: float = 0.0
var _swaps: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SHARDS, Pattern.BLINK, Pattern.RAIN, Pattern.SUMMON, Pattern.SHARDS, Pattern.BLINK]
	GameManager.player_attacked.connect(_on_player_attacked)


func is_emerging() -> bool:
	return _emerge_left > 0.0


func has_mirror() -> bool:
	return mirror != null and is_instance_valid(mirror) and not mirror.is_dead()


func is_mirror_broken() -> bool:
	return _mirror_broken


func get_clones() -> Array[DoppelClone]:
	var alive: Array[DoppelClone] = []
	for c in _clones:
		if is_instance_valid(c) and not c.is_dead():
			alive.append(c)
	return alive


func get_last_mimic() -> Mimic:
	return _last_mimic


func get_mimic_count() -> int:
	return _mimics


func get_swap_count() -> int:
	return _swaps


func _get_move_velocity(delta: float) -> Vector2:
	if not _mirror_requested:
		_mirror_requested = true
		if mirror_scene != null:
			request_summon(mirror_scene, global_position)
		_emerge_left = EMERGE_TIME
		sprite.modulate.a = 0.15
		set_status("거울 속에서 무언가가 걸어 나온다…", Color(0.85, 0.75, 1.0))
	if _emerge_left > 0.0:
		_emerge_left -= delta
		sprite.modulate.a = lerpf(1.0, 0.15, _emerge_left / EMERGE_TIME)
		if _emerge_left <= 0.0:
			sprite.modulate.a = 1.0
			set_status("", Color.WHITE)
		return Vector2(0, EMERGE_DISTANCE / EMERGE_TIME)
	_mimic_cooldown = maxf(_mimic_cooldown - delta, 0.0)
	if _lunge_left > 0.0:
		_lunge_left -= delta
		return _lunge_dir * 300.0
	if phase_two:
		_update_clones(delta)
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and mirror == null:
		mirror = minion as BossPart
		mirror.boss = self
		mirror.follow_boss = false
		mirror.max_hp = maxi(1, roundi(max_hp * mirror_hp_ratio))
		mirror.z_index = -1
		mirror.died.connect(_on_mirror_broken)
	elif minion is DoppelClone:
		minion.max_hp = maxi(1, roundi(max_hp * clone_hp_ratio))
		minion.gold_min = 0
		minion.gold_max = 0
		_clones.append(minion as DoppelClone)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_emerging():
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


# ============================================================ 기믹 1페이즈: 따라하기
func _on_player_attacked(weapon: WeaponData, _aim: Vector2) -> void:
	if phase_two or is_dead() or is_emerging() or _mimic_cooldown > 0.0 or not has_target() or not is_inside_tree():
		return
	_mimic_cooldown = 0.8
	var kind := Mimic.SLASH if weapon.is_melee() else (Mimic.ARROW if weapon.is_bow() else Mimic.SPELL)
	_after(0.3, mimic.bind(kind))


## 플레이어의 공격을 따라 함 (테스트에서도 직접 호출)
func mimic(kind: Mimic) -> void:
	if is_dead() or not has_target():
		return
	_last_mimic = kind
	_mimics += 1
	var dir := direction_to_player()
	match kind:
		Mimic.SLASH:
			set_status("따라하기: 검 베기", Color(0.85, 0.75, 1.0))
			_lunge_dir = dir
			_lunge_left = 0.22
			telegraph_strike(get_hit_center() + dir * minf(distance_to_player(), 70.0), 26.0, 0.32, slash_damage, Elements.Type.DARK)
		Mimic.ARROW:
			set_status("따라하기: 활", Color(0.85, 0.75, 1.0))
			for a in [-0.12, 0.0, 0.12]:
				shoot(dir.rotated(a), 250.0, shard_damage, arrow_texture, 0.0, Elements.Type.DARK)
		Mimic.SPELL:
			set_status("따라하기: 마법", Color(0.85, 0.75, 1.0))
			telegraph_strike(_player.global_position, 32.0, 0.75, slash_damage, Elements.Type.ARCANE)
	Fx.burst(self, get_hit_center(), Color(0.8, 0.6, 1.0), 8, 45.0, 0.3)
	_after(0.9, func() -> void:
		if get_status_text().begins_with("따라하기"):
			set_status("", Color.WHITE))


# ============================================================ 기믹 2페이즈: 분신 · 거울
func _update_clones(delta: float) -> void:
	_clone_timer -= delta
	if _clone_timer <= 0.0:
		_clone_timer = clone_interval
		summon_clones()
	_swap_timer -= delta
	if _swap_timer <= 0.0:
		_swap_timer = swap_interval
		swap_with_clone()


## 거울이 살아 있으면 분신을 MAX_CLONES 까지 채움
func summon_clones() -> void:
	if not has_mirror() or clone_scene == null or is_dead():
		return
	var missing := MAX_CLONES - get_clones().size()
	for i in missing:
		request_summon(clone_scene, mirror.global_position + Vector2.from_angle(TAU * i / maxf(missing, 1)) * 30.0)
	if missing > 0:
		Fx.shockwave(self, mirror.get_hit_center(), Color(0.8, 0.7, 1.0), 40.0, 0.35)


## 진짜 도플갱어가 무작위 분신과 자리를 바꿈
func swap_with_clone() -> bool:
	var clones := get_clones()
	if clones.is_empty() or is_dead():
		return false
	var other: DoppelClone = clones.pick_random()
	var here := global_position
	global_position = other.global_position
	other.global_position = here
	_swaps += 1
	Fx.burst(self, here, Color(0.8, 0.7, 1.0), 6, 40.0, 0.25)
	Fx.burst(self, global_position, Color(0.8, 0.7, 1.0), 6, 40.0, 0.25)
	return true


func _on_mirror_broken(_enemy: Enemy) -> void:
	_mirror_broken = true
	mirror = null
	for c in get_clones():
		c.shatter()
	_clones.clear()
	stun(2.0)
	set_status("거울이… 깨졌어…!", Color(1.0, 0.7, 0.9))
	_after(1.8, set_status.bind("", Color.WHITE))
	GameManager.show_notice("거울을 부쉈다! 분신이 모두 사라졌다", Color(0.85, 0.75, 1.0))


func _on_phase_two() -> void:
	_clone_timer = 0.0
	_swap_timer = swap_interval
	if has_mirror():
		GameManager.show_notice("도플갱어가 거울 속 분신들을 불러낸다! 거울을 부수면 분신이 사라진다", Color(0.85, 0.75, 1.0))
	else:
		GameManager.show_notice("도플갱어: 거울만 있었다면…!", Color(0.85, 0.75, 1.0))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.SHARDS:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.17), 135.0, shard_damage, shard_texture, 0.0, Elements.Type.ARCANE)
			return 1.0
		Pattern.BLINK:
			if not has_target():
				return 0.5
			var behind := _player.global_position - _player.get_aim_direction() * 34.0
			Fx.burst(self, get_hit_center(), Color(0.6, 0.4, 0.9), 10, 50.0, 0.3)
			global_position = behind if not arena_rect.has_area() else behind.clamp(arena_rect.position, arena_rect.end)
			telegraph_strike(_player.global_position, 26.0, 0.55, slash_damage, Elements.Type.DARK)
			return 1.0
		Pattern.RAIN:
			if has_target():
				for i in 5:
					var at := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(28.0, 80.0))
					telegraph_strike(at, 20.0, 0.8 + 0.12 * i, shard_damage, Elements.Type.ARCANE)
			return 1.4
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0
