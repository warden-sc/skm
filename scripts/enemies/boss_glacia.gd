class_name BossGlacia
extends PatternBoss
## 26스테이지 보스: 빙결의 여왕 글라시아 — 얼어붙은 궁전의 여왕.
##   ICICLE : 고드름 — 플레이어 주변에 떨어지는 얼음 장판 (감속)
##   NOVA   : 서리 폭발 — 몸 주위 고리 장판
##   SHARDS : 얼음 파편 부채꼴
##   MIRROR : 얼음 거울 — 얼음 기둥에 냉기를 쏘면 기둥이 사방으로 얼음 파편을 반사
##   SUMMON : 서리 늑대 · 얼음 골렘 호출
##
## [기믹] 냉기 게이지 (플레이어 머리 위 상태 표시):
##   - 가만히 서 있거나 가드를 하고 있으면 냉기가 쌓이고, 움직이면 빠짐
##   - 100% 가 되면 freeze_time 동안 「빙결」(조작 불가)
## [기믹] 눈보라 (blizzard_interval 마다): blizzard_time 동안 한쪽(왼쪽/오른쪽)에서 강풍
##   - 바람에 밀려나고 냉기도 빨리 쌓임
##   - 바람이 오는 쪽에 얼음 기둥을 두고 그 뒤에 서면 바람을 피함
## 체력 50% 이하: 눈보라가 더 잦고 강해짐

enum Pattern { ICICLE, NOVA, SHARDS, MIRROR, SUMMON }

const PILLAR_SPOTS: Array[Vector2] = [Vector2(-120, 60), Vector2(120, 60), Vector2(-60, 150), Vector2(60, 150)]

@export var minion_scenes: Array[PackedScene] = []
@export var shard_texture: Texture2D
@export var icicle_damage: int = 56
@export var nova_damage: int = 58
@export var shard_damage: int = 36
@export var freeze_time: float = 2.0
## 초당 냉기: 가만히 있을 때 / 움직일 때(음수) / 눈보라에 노출됐을 때 추가
@export var chill_still: float = 30.0
@export var chill_move: float = -28.0
@export var chill_wind: float = 18.0
@export var blizzard_interval: float = 14.0
@export var blizzard_time: float = 4.0
@export var wind_force: float = 130.0

var chill: float = 0.0
var _pillars: Array[IcePillar] = []
var _placed: bool = false
var _home: Vector2
var _freezes: int = 0
var _blizzard_cooldown: float = 6.0
var _blizzard_warn: float = 0.0
var _blizzard_left: float = 0.0
var _wind: Vector2 = Vector2.RIGHT
var _sheltered_frames: int = 0
var _pushed_frames: int = 0
var _snow: CPUParticles2D


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.ICICLE, Pattern.SHARDS, Pattern.MIRROR, Pattern.NOVA, Pattern.SUMMON, Pattern.ICICLE, Pattern.MIRROR]


func get_pillars() -> Array[IcePillar]:
	var alive: Array[IcePillar] = []
	for p in _pillars:
		if is_instance_valid(p):
			alive.append(p)
	return alive


func is_blizzard() -> bool:
	return _blizzard_left > 0.0


func get_wind() -> Vector2:
	return _wind


func get_freeze_count() -> int:
	return _freezes


func get_sheltered_frames() -> int:
	return _sheltered_frames


func get_pushed_frames() -> int:
	return _pushed_frames


func _get_move_velocity(delta: float) -> Vector2:
	if not _placed:
		_placed = true
		_home = global_position
		for spot in PILLAR_SPOTS:
			var p := IcePillar.spawn(self, _home + spot)
			if p != null:
				_pillars.append(p)
		_snow = CPUParticles2D.new()
		_snow.top_level = true
		_snow.amount = 120
		_snow.lifetime = 1.2
		_snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_snow.emission_rect_extents = Vector2(20, 160)
		_snow.spread = 8.0
		_snow.gravity = Vector2.ZERO
		_snow.initial_velocity_min = 260.0
		_snow.initial_velocity_max = 340.0
		_snow.color = Color(0.92, 0.97, 1.0, 0.75)
		_snow.z_index = 60
		_snow.emitting = false
		add_child(_snow)
	if has_target():
		_update_chill(delta)
		_update_blizzard(delta)
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 냉기
func _update_chill(delta: float) -> void:
	if _player.is_charmed():
		_player.set_chill(chill)
		return
	var still := _player.velocity.length() < 25.0 or _player.is_guarding()
	var rate := chill_still if still else chill_move
	if is_blizzard() and not _is_sheltered():
		rate = maxf(rate, 0.0) + chill_wind
	add_chill(rate * delta)


func add_chill(amount: float) -> void:
	chill = clampf(chill + amount, 0.0, 100.0)
	if chill >= 100.0 and has_target():
		chill = 0.0
		_freezes += 1
		_player.apply_charm(freeze_time, null, "빙결")
		Fx.burst(self, _player.global_position + Vector2(0, -8), Color(0.75, 0.9, 1.0), 14, 50.0, 0.4)
	if has_target():
		_player.set_chill(chill)


# ============================================================ 기믹: 눈보라
func begin_blizzard() -> void:
	if is_blizzard() or _blizzard_warn > 0.0 or is_dead():
		return
	_wind = Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT
	_blizzard_warn = 1.0
	_blizzard_cooldown = blizzard_interval * (0.75 if phase_two else 1.0)
	var from_side := "왼쪽" if _wind.x > 0.0 else "오른쪽"
	set_status("눈보라가 %s에서 몰려온다 — 기둥 뒤로!" % from_side, Color(0.8, 0.92, 1.0))
	Net.announce("눈보라! %s에서 바람이 분다 — 얼음 기둥 뒤에 숨어라" % from_side, Color(0.8, 0.92, 1.0))


func _update_blizzard(delta: float) -> void:
	if _blizzard_warn > 0.0:
		_blizzard_warn -= delta
		if _blizzard_warn <= 0.0:
			_blizzard_left = blizzard_time
			_start_snow()
		return
	if _blizzard_left > 0.0:
		_blizzard_left -= delta
		if _is_sheltered():
			_sheltered_frames += 1
		elif not _player.is_dashing():
			_pushed_frames += 1
			_player.apply_push(_wind * wind_force * (1.3 if phase_two else 1.0))
		if _blizzard_left <= 0.0:
			_snow.emitting = false
			set_status("", Color.WHITE)
		return
	_blizzard_cooldown -= delta
	if _blizzard_cooldown <= 0.0 and not is_casting():
		begin_blizzard()


func _is_sheltered() -> bool:
	for p in get_pillars():
		if p.shelters(_player.global_position, _wind):
			return true
	return false


func _start_snow() -> void:
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(220, 60), Vector2(440, 300))
	# 보스방 전체에서 눈발이 바람 방향으로 휘날림
	_snow.global_position = area.get_center()
	_snow.emission_rect_extents = area.size * 0.5
	_snow.direction = _wind
	_snow.amount = 220
	_snow.lifetime = 0.7
	_snow.emitting = true


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.ICICLE:
			for i in 6:
				telegraph_strike(_player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(28.0, 80.0)), 18.0, 0.8 + 0.08 * i, icicle_damage, Elements.Type.ICE, 1.0)
			return 1.4
		Pattern.NOVA:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 52.0, 20.0, 0.9, nova_damage, Elements.Type.ICE, 1.2)
			return 1.3
		Pattern.SHARDS:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.16), 145.0, shard_damage, shard_texture, 0.8, Elements.Type.ICE)
			return 0.9
		Pattern.MIRROR:
			return mirror()
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 30.0))
			return 0.9
	return 1.0


## 얼음 거울: 기둥마다 냉기를 쏘고, 기둥이 사방으로 얼음 파편을 반사 (테스트에서도 직접 호출)
func mirror() -> float:
	set_status("얼음 거울", Color(0.8, 0.92, 1.0))
	for p in get_pillars():
		Fx.pillar(self, p.global_position, Color(0.7, 0.9, 1.0), 12.0, 70.0, 0.5)
		_after(0.6, _reflect.bind(p))
	_after(1.0, func() -> void:
		if get_status_text() == "얼음 거울":
			set_status("", Color.WHITE))
	return 1.3


func _reflect(p: IcePillar) -> void:
	if is_dead() or not is_instance_valid(p):
		return
	for i in 8:
		shoot(Vector2.from_angle(TAU * i / 8.0 + 0.2), 120.0, shard_damage, shard_texture, 0.6, Elements.Type.ICE, p.global_position + Vector2(0, -16))


func _die() -> void:
	if _snow != null:
		_snow.emitting = false
	if has_target():
		_player.set_chill(0.0)
	super._die()


func _on_phase_two() -> void:
	Net.announce("글라시아: 영원한 겨울을 맞이하라…! 눈보라가 더 거세진다", Color(0.8, 0.92, 1.0))
