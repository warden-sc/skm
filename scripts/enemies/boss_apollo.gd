class_name BossApollo
extends PatternBoss
## 70스테이지 보스: 태양의 신 아폴론 — 빛과 음악과 궁술의 신, 은빛 활로 역병의 화살을 쏘는 델포이의 주인.
##   SUN_ARROWS : 햇살 화살 세례 (부채꼴)
##   PLAGUE     : 역병의 화살 — 맞으면 「역병」
##   SOLAR_RING : 태양의 고리 — 몸 주위 빛기둥
##   SUMMON     : 델포이 신전 수호병 · 태양 사제 · 빛의 정령 호출
##
## [기믹 1] 해시계의 그림자: 보스방 위를 태양이 돌고(sun_period 초에 한 바퀴), 돌기둥 4개의 그림자가 태양 반대쪽으로 드리움
##   햇빛 아래에 있으면 「일사」가 쌓이고(그림자 속에서는 빠르게 식음), 100% 가 되면 계속 화상
## [기믹 2] 정오: noon_interval 초마다 태양이 머리 위로 — noon_warn 초 예고 뒤 그림자가 기둥 바로 아래로 줄어들고
##   보스방 전체에 빛이 내리꽂힘 → 기둥 바로 아래가 아니면 최대 체력의 noon_ratio 만큼 피해 (가드 불가)
## [기믹 3] 역병의 화살: 맞으면 plague_time 초 동안 「역병」 — 포션 회복 절반 + 2초마다 발밑에 역병 장판이 퍼짐
## 체력 50% 이하: 태양이 더 빨리 돌고, 정오가 잦아짐

enum Pattern { SUN_ARROWS, PLAGUE, SOLAR_RING, SUMMON }

const PILLAR_SPOTS := [Vector2(-150, -70), Vector2(150, -70), Vector2(-150, 80), Vector2(150, 80)]

@export var minion_scenes: Array[PackedScene] = []
@export var sun_texture: Texture2D
@export var plague_texture: Texture2D
@export var arrow_damage: int = 62
@export var plague_damage: int = 56
@export var ring_damage: int = 90
@export var sun_period: float = 24.0
@export var stroke_rate: float = 14.0
@export var noon_interval: float = 30.0
@export var noon_warn: float = 3.0
@export var noon_ratio: float = 0.6
@export var plague_time: float = 7.0

var sundial: Sundial
var sunstroke: float = 0.0
var _stroke_tick: float = 0.0
var _noon_left: float = 20.0
var _noon_warn_left: float = 0.0
var _noons: int = 0
var _noon_hits: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SUN_ARROWS, Pattern.PLAGUE, Pattern.SOLAR_RING, Pattern.SUN_ARROWS, Pattern.PLAGUE, Pattern.SUMMON]


func get_noon_count() -> int:
	return _noons


func get_noon_hits() -> int:
	return _noon_hits


func is_noon_coming() -> bool:
	return _noon_warn_left > 0.0


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		sundial = Sundial.spawn(self, _area(), PILLAR_SPOTS)
	return super._get_move_velocity(delta)


func _physics_process(delta: float) -> void:
	if not is_dead() and sundial != null and is_instance_valid(sundial) and has_target():
		if not sundial.noon:
			sundial.sun_angle = wrapf(sundial.sun_angle + TAU / (sun_period * (0.7 if phase_two else 1.0)) * delta, 0.0, TAU)
		_update_sunstroke(delta)
		_update_noon(delta)
	super._physics_process(delta)


func _update_sunstroke(delta: float) -> void:
	var at := _player.global_position
	if sundial.is_in_shade(at):
		sunstroke = maxf(sunstroke - 35.0 * delta, 0.0)
	else:
		sunstroke = minf(sunstroke + stroke_rate * delta, 100.0)
	if sunstroke >= 100.0:
		_stroke_tick -= delta
		if _stroke_tick <= 0.0:
			_stroke_tick = 1.5
			_player.apply_burn(roundi(12 * power), 2.0)
	if sunstroke > 0.0:
		_player.mark_floor_status("일사 %d%% (기둥 그림자 속으로)" % roundi(sunstroke))


func _update_noon(delta: float) -> void:
	if _noon_warn_left > 0.0:
		_noon_warn_left -= delta
		if _noon_warn_left <= 0.0:
			strike_noon()
		return
	if sundial.noon:
		_noon_left -= delta
		if _noon_left <= 0.0:
			sundial.noon = false
			_noon_left = noon_interval * (0.7 if phase_two else 1.0)
		return
	_noon_left -= delta
	if _noon_left <= 0.0:
		begin_noon()


## 정오 예고 (테스트에서도 직접 호출)
func begin_noon() -> void:
	_noon_warn_left = noon_warn
	sundial.noon = true
	set_status("정오가 다가온다 — 기둥 바로 아래로!", Color(1.0, 0.9, 0.4))
	GameManager.show_notice("태양이 머리 위로 떠오른다! 정오의 빛을 피해 기둥 바로 아래로", Color(1.0, 0.9, 0.4))


func strike_noon() -> void:
	_noon_warn_left = 0.0
	_noons += 1
	_noon_left = 1.5  # 잠깐 정오가 머문 뒤 그림자가 돌아옴
	Fx.flash(self, _area().get_center(), Color(1.0, 0.95, 0.7), 400.0, 0.6)
	set_status("", Color.WHITE)
	if has_target() and not sundial.is_in_shade(_player.global_position):
		_noon_hits += 1
		_player.take_unblockable_hit(roundi(GameManager.max_hp * noon_ratio), _player.global_position + Vector2(0, -10), false)


func _shoot_plague(dir: Vector2) -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var spec := ProjectileSpec.enemy_bullet(get_hit_center(), dir, 190.0, roundi(plague_damage * power), plague_texture, 0.0, Elements.Type.NATURE)
	spec.plague_duration = plague_time
	pool.spawn(spec)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SUN_ARROWS:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead() or not has_target():
						return
					var aim := direction_to_player()
					for i in 7:
						shoot(aim.rotated((i - 3) * 0.13 + w * 0.06), 200.0, arrow_damage, sun_texture, 0.0, Elements.Type.HOLY))
			return 1.0
		Pattern.PLAGUE:
			for i in 5:
				_shoot_plague(dir.rotated((i - 2) * 0.18))
			return 0.9
		Pattern.SOLAR_RING:
			for i in 14:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0) * 56.0, 20.0, 0.85, ring_damage, Elements.Type.HOLY)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if has_target():
		_player.cure_plague()  # 쓰러지면 역병도 걷힘
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("아폴론: 빛은 숨을 곳을 남기지 않는다! 태양이 더 빨리 돌고 정오가 잦아진다", Color(1.0, 0.9, 0.4))
