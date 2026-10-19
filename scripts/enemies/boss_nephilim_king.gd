class_name BossNephilimKing
extends PatternBoss
## 96스테이지 보스: 노아 홍수의 네피림 왕 — 하나님의 아들들과 사람의 딸들 사이에서 난 거인들의 왕. 큰 물이 땅을 덮을 때까지 버틴 자.
##   SLAM     : 두 주먹 내려치기 (앞쪽 큰 장판)
##   WAVE     : 물결 일으키기 (부채꼴 물 탄)
##   HURL     : 바위 던지기 — 플레이어 주변 장판
##   SUMMON   : 홍수의 거인병 · 물의 정령 · 바다 괴어 호출
##
## [기믹] 홍수: 마른 땅(dry_time 초) → 물이 차오름(flood_rise 초) → 가득 참(flood_hold 초) → 물이 빠짐(flood_recede 초) 을 되풀이
##   물이 차면 판자 밖의 플레이어는 느려지고 0.6초마다 최대 체력의 일부 피해 — 떠다니는 「방주의 판자」 위에서는 안전
##   물속을 걷는 네피림 왕에게는 물이 반 넘게 찬 동안 flooded_ratio 만 피해가 들어감
## [기믹] 진흙: 물이 다 빠지는 순간 네피림 왕이 진흙에 발이 빠져 mud_stun 초 기절 + 그동안 피해 mud_ratio 배

enum Pattern { SLAM, WAVE, HURL, SUMMON }
enum Flood { DRY, RISING, HIGH, RECEDING }

const FLOOD_NAMES := ["마른 땅", "물이 차오름", "홍수", "물이 빠짐"]

@export var minion_scenes: Array[PackedScene] = []
@export var plank_texture: Texture2D
@export var wave_texture: Texture2D
@export var slam_damage: int = 110
@export var wave_damage: int = 66
@export var hurl_damage: int = 100
@export var dry_time: float = 10.0
@export var flood_rise: float = 10.0
@export var flood_hold: float = 8.0
@export var flood_recede: float = 4.0
@export var water_ratio: float = 0.025
@export var water_slow: float = 0.6
@export var flooded_ratio: float = 0.6
@export var mud_stun: float = 8.0
@export var mud_ratio: float = 1.5

var flood: FloodField
var flood_state: Flood = Flood.DRY
var _state_left: float = 0.0
var _mud_left: float = 0.0
var _water_tick: float = 0.0
var _drowns: int = 0
var _floods: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SLAM, Pattern.WAVE, Pattern.HURL, Pattern.SLAM, Pattern.SUMMON]


func is_stuck_in_mud() -> bool:
	return _mud_left > 0.0


func get_drown_ticks() -> int:
	return _drowns


func get_flood_count() -> int:
	return _floods


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		flood = FloodField.spawn(self, _area(), 4, plank_texture)
		_state_left = dry_time * 0.6
		_update_status()
	if is_stuck_in_mud():
		return Vector2.ZERO
	return super._get_move_velocity(delta) * 0.8


## 물이 차오르기 시작 (테스트에서도 직접 호출)
func start_flood() -> void:
	if is_dead():
		return
	flood_state = Flood.RISING
	_state_left = flood_rise
	_floods += 1
	GameManager.show_notice("큰 깊음의 샘들이 터지고 하늘의 창문이 열린다 — 방주의 판자 위로!", Color(0.6, 0.8, 1.0))
	_update_status()


## 물이 다 빠짐 → 진흙에 발이 빠짐 (테스트에서도 직접 호출)
func drain() -> void:
	flood_state = Flood.DRY
	_state_left = dry_time * (0.7 if phase_two else 1.0)
	if flood != null:
		flood.level = 0.0
	_mud_left = mud_stun
	super.stun(mud_stun)
	Fx.burst(self, global_position, Color(0.45, 0.35, 0.25), 24, 70.0, 0.6)
	GameManager.show_notice("물이 빠지자 네피림 왕이 진흙에 발이 빠졌다! (피해 x%.1f)" % mud_ratio, Color(0.9, 0.75, 0.5))
	_update_status()


func water_level() -> float:
	return flood.level if flood != null else 0.0


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0:
		if is_stuck_in_mud():
			amount = roundi(amount * mud_ratio)
		elif water_level() > 0.5:
			amount = maxi(1, roundi(amount * flooded_ratio))
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		_mud_left = maxf(_mud_left - delta, 0.0)
		_state_left -= delta
		match flood_state:
			Flood.DRY:
				if _state_left <= 0.0:
					start_flood()
			Flood.RISING:
				flood.level = clampf(1.0 - _state_left / flood_rise, 0.0, 1.0)
				if _state_left <= 0.0:
					flood_state = Flood.HIGH
					_state_left = flood_hold
					_update_status()
			Flood.HIGH:
				flood.level = 1.0
				if _state_left <= 0.0:
					flood_state = Flood.RECEDING
					_state_left = flood_recede
					GameManager.show_notice("물이 빠지기 시작한다…", Color(0.7, 0.85, 1.0))
					_update_status()
			Flood.RECEDING:
				flood.level = clampf(_state_left / flood_recede, 0.0, 1.0)
				if _state_left <= 0.0:
					drain()
		if has_target() and water_level() > 0.35 and not flood.is_on_plank(_player.global_position):
			_player.apply_slow(water_slow, 0.2)
			_player.mark_floor_status("홍수에 잠김 — 방주의 판자 위로")
			_water_tick -= delta
			if _water_tick <= 0.0:
				_water_tick = 0.6
				_drowns += 1
				_player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * water_ratio * water_level())), _player.global_position, false)
		else:
			_water_tick = 0.3
	super._physics_process(delta)


func _update_status() -> void:
	set_status("%s%s" % [FLOOD_NAMES[flood_state], " · 진흙에 빠짐" if is_stuck_in_mud() else ""], Color(0.65, 0.8, 1.0))


func _run_pattern(pattern: int) -> float:
	if not has_target() or is_stuck_in_mud():
		return 0.5
	_update_status()
	var dir := direction_to_player()
	match pattern:
		Pattern.SLAM:
			for i in 3:
				for k in 3:
					telegraph_strike(get_hit_center() + dir * (40.0 + 30.0 * i) + dir.orthogonal() * (k - 1) * 30.0, 20.0, 0.8 + 0.1 * i, slam_damage, Elements.Type.EARTH)
			return 1.3
		Pattern.WAVE:
			for i in 11:
				shoot(dir.rotated((i - 5) * 0.13), 130.0, wave_damage, wave_texture, 0.6, Elements.Type.ICE)
			return 1.0
		Pattern.HURL:
			for i in 4:
				telegraph_strike(_player.global_position + Vector2.from_angle(TAU * i / 4.0 + randf()) * randf_range(0.0, 50.0), 26.0, 1.0 + 0.1 * i, hurl_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0
