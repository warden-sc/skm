class_name BossKraken
extends PatternBoss
## 13스테이지 보스: 심해의 포식자 크라켄 — 가라앉은 신전 깊은 물속에서 올라온 거대 문어.
##   INK       : 먹물 — 먹물 탄을 뿜고, 플레이어 주변 바닥에 먹물 웅덩이 (밟으면 크게 느려짐)
##   WHIRLPOOL : 소용돌이 — 나선으로 퍼지는 물탄
##   SLAM      : 촉수 내려치기 — 살아 있는 촉수들이 한꺼번에 플레이어 쪽을 내려침
##   SUMMON    : 어인 전사 · 심해 해파리 호출
##
## [기믹] 촉수: 크라켄 주변 바닥에서 거대 촉수 4개가 솟아오름 (촉수마다 체력이 따로)
##   - 촉수가 하나라도 남아 있으면 촉수가 본체를 감싸 본체가 받는 피해 -70%
##   - 촉수는 가까이 온 플레이어를 스스로 내려침
##   - 촉수를 모두 베면 본체가 드러나 잠깐 기절, regrow_time 뒤 촉수가 다시 솟아오름
## 체력 50% 이하: 촉수가 더 빨리 다시 자라고, 소용돌이 2겹

enum Pattern { INK, WHIRLPOOL, SLAM, SUMMON }

const GUARD_REDUCTION := 0.7
const TENTACLE_SPOTS: Array[Vector2] = [Vector2(-96, 10), Vector2(96, 10), Vector2(-64, 90), Vector2(64, 90)]

@export var tentacle_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var ink_texture: Texture2D
@export var water_texture: Texture2D
@export var ink_damage: int = 30
@export var water_damage: int = 28
@export var slam_damage: int = 48
@export var tentacle_hp_ratio: float = 0.05
@export var regrow_time: float = 14.0
@export var tentacle_slam_interval: float = 2.8

var _tentacles: Array[BossPart] = []
var _spawned_once: bool = false
var _regrow_left: float = -1.0
var _tentacle_timer: float = 2.0
var _home: Vector2


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.INK, Pattern.WHIRLPOOL, Pattern.SLAM, Pattern.SUMMON, Pattern.WHIRLPOOL, Pattern.SLAM]


func get_tentacles() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for t in _tentacles:
		if is_instance_valid(t) and not t.is_dead():
			alive.append(t)
	return alive


func is_guarded() -> bool:
	return not get_tentacles().is_empty()


func _get_move_velocity(delta: float) -> Vector2:
	if not _spawned_once:
		_spawned_once = true
		_home = global_position
		raise_tentacles()
	if _regrow_left > 0.0:
		_regrow_left -= delta
		if _regrow_left <= 0.0:
			raise_tentacles()
	_tentacle_timer -= delta
	if _tentacle_timer <= 0.0:
		_tentacle_timer = tentacle_slam_interval
		for t in get_tentacles():
			if has_target() and t.global_position.distance_to(_player.global_position) < 90.0:
				_tentacle_strike(t, 0.9)
	return super._get_move_velocity(delta)


## 크라켄은 멀리 쫓아가지 않고 둥지(처음 자리) 근처를 맴돎
func _chase_velocity(_delta: float) -> Vector2:
	var target := _home + (_player.global_position - _home).limit_length(40.0)
	if global_position.distance_to(target) < 4.0:
		return Vector2.ZERO
	return global_position.direction_to(target) * move_speed


# ============================================================ 기믹: 촉수
func raise_tentacles() -> void:
	if is_dead() or tentacle_scene == null:
		return
	_regrow_left = -1.0
	for spot in TENTACLE_SPOTS:
		request_summon(tentacle_scene, _home + spot)
	set_status("촉수가 솟아올라 본체를 감싼다 (본체 피해 -70%)", Color(0.6, 0.85, 1.0))
	_after(2.5, func() -> void:
		if get_status_text().begins_with("촉수가 솟"):
			set_status("", Color.WHITE))


func register_minion(minion: Enemy) -> void:
	if minion is BossPart:
		var t := minion as BossPart
		t.boss = self
		t.follow_boss = false
		t.max_hp = maxi(1, roundi(max_hp * tentacle_hp_ratio))
		t.died.connect(_on_tentacle_cut)
		_tentacles.append(t)


func _on_tentacle_cut(_enemy: Enemy) -> void:
	_tentacles = get_tentacles()
	if not _tentacles.is_empty() or is_dead():
		return
	_regrow_left = regrow_time * (0.7 if phase_two else 1.0)
	set_status("촉수를 모두 베었다: 본체가 드러남!", Color(1.0, 0.85, 0.5))
	Net.announce("크라켄의 촉수를 모두 베었다! 지금 본체를 공격하라", Color(1.0, 0.85, 0.5))
	stun(2.0)
	_after(3.0, func() -> void:
		if get_status_text().begins_with("촉수를 모두"):
			set_status("", Color.WHITE))


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_guarded() and not is_dead() and amount > 0:
		amount = maxi(1, roundi(amount * (1.0 - GUARD_REDUCTION)))
		Fx.burst(self, get_hit_center(), Color(0.6, 0.85, 1.0), 3, 25.0, 0.2)
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _tentacle_strike(t: BossPart, delay: float) -> void:
	var dir := t.global_position.direction_to(_player.global_position) if has_target() else Vector2.DOWN
	for i in 3:
		telegraph_strike(t.global_position + dir * (18.0 + 22.0 * i), 18.0, delay + 0.06 * i, slam_damage, Elements.Type.ICE)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.INK:
			set_status("먹물 분사", Color(0.7, 0.55, 0.9))
			var aim := direction_to_player()
			for i in 5:
				shoot(aim.rotated((i - 2) * 0.22), 115.0, ink_damage, ink_texture, 1.2, Elements.Type.DARK)
			if has_target():
				var center := _player.global_position
				for i in 3:
					var at := center + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0))
					_after(0.5 + 0.15 * i, _ink_pool.bind(at))
			_after(1.0, set_status.bind("", Color.WHITE))
			return 1.2
		Pattern.WHIRLPOOL:
			var waves := 2 if phase_two else 1
			for k in 14:
				_after(0.07 * k, _whirl.bind(k, waves))
			return 1.5
		Pattern.SLAM:
			var alive := get_tentacles()
			if alive.is_empty():
				return _run_pattern(Pattern.INK)
			set_status("촉수 내려치기", Color(0.6, 0.85, 1.0))
			for t in alive:
				_tentacle_strike(t, 0.8)
			_after(1.0, set_status.bind("", Color.WHITE))
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 50.0))
			return 0.9
	return 1.0


func _ink_pool(at: Vector2) -> void:
	if not is_dead():
		GroundZone.spawn_hostile(self, at, GroundZone.Kind.INK, 30.0, 5.0, 0.45)
		Fx.burst(self, at, Color(0.3, 0.2, 0.4), 8, 40.0, 0.3)


func _whirl(step: int, waves: int) -> void:
	if is_dead():
		return
	for w in waves:
		for arm in 3:
			var angle := step * 0.32 + TAU * arm / 3.0 + w * PI / 3.0
			shoot(Vector2.from_angle(angle), 95.0, water_damage, water_texture, 0.0, Elements.Type.ICE)


func _on_phase_two() -> void:
	Net.announce("크라켄이 분노한다! 촉수가 더 빨리 다시 자란다", Color(0.6, 0.85, 1.0))
