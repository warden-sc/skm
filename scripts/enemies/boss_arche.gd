class_name BossArche
extends PatternBoss
## 히든 보스: 고대 드래곤 아르케 — 다섯 용보다 먼저 태어난, 모든 원소의 근원인 용.
## (30~35스테이지 사냥터에 숨겨진 「고대 용의 비늘」 6개를 모두 모으면 헬리시온 토벌 뒤 히든 던전이 열림)
##   ASPECT  : 지금 두른 원소의 공격 (바람 칼날 / 대지 낙석 / 얼음 조각 / 화염구)
##   ANCIENT : 고대의 고리 — 사방으로 퍼지는 고대 구체 두 겹
##   BREATH  : 원소 숨결 — 지금 원소의 탄 부채꼴
##
## [기믹 1] 원소 순환: aspect_time 초마다 바람 → 대지 → 얼음 → 화염 순으로 원소를 바꿔 두름
##   바람 = 보스방에 바람 (투사체가 휨) / 대지 = 방어력 +earth_armor / 얼음 = 플레이어 발밑에 빙판 / 화염 = 공격에 화상 + 발밑에 용암
## [기믹 2] 고대 용언: rune_interval 초마다 네 원소의 룬 원이 나타나고, 아르케가 원소 하나를 외침
##   → rune_warn 초 뒤 외친 원소의 원 안에 있지 않으면 최대 체력의 rune_ratio 피해 (가드·대시 불가)
## 체력 50% 이하: 원소가 더 빨리 바뀌고 용언이 더 자주, 더 빨리

enum Pattern { ASPECT, ANCIENT, BREATH }
enum Aspect { WIND, EARTH, ICE, FIRE }

const ASPECT_NAMES := ["바람", "대지", "얼음", "화염"]
const ASPECT_COLORS := [Color(0.75, 1.0, 0.85), Color(1.0, 0.8, 0.55), Color(0.75, 0.9, 1.0), Color(1.0, 0.6, 0.4)]

@export var ancient_texture: Texture2D
@export var wind_texture: Texture2D
@export var rock_texture: Texture2D
@export var ice_texture: Texture2D
@export var fire_texture: Texture2D
@export var bullet_damage: int = 52
@export var strike_damage: int = 80
@export var aspect_time: float = 12.0
@export var earth_armor: int = 40
@export var rune_interval: float = 20.0
@export var rune_warn: float = 4.0
@export var rune_ratio: float = 0.55

var aspect: Aspect = Aspect.WIND
var wind: WindField
var runes: DragonRunes
var _aspect_left: float = 0.0
var _aspect_changes: int = 0
var _hazard_timer: float = 2.0
var _rune_cooldown: float = 10.0
var _rune_left: float = 0.0
var _rune_hits: int = 0
var _rune_dodges: int = 0
var _base_defense: int = 0
var _base_burn: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.ASPECT, Pattern.ANCIENT, Pattern.ASPECT, Pattern.BREATH]
	_base_defense = defense
	_base_burn = burn_damage


func get_aspect() -> Aspect:
	return aspect


func get_aspect_name() -> String:
	return ASPECT_NAMES[aspect]


func get_aspect_changes() -> int:
	return _aspect_changes


func get_wind() -> WindField:
	return wind if wind != null and is_instance_valid(wind) else null


func get_runes() -> DragonRunes:
	return runes if runes != null and is_instance_valid(runes) else null


func get_rune_hits() -> int:
	return _rune_hits


func get_rune_dodges() -> int:
	return _rune_dodges


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	if not _started:
		_started = true
		set_aspect(Aspect.WIND)
	_aspect_left -= delta
	if _aspect_left <= 0.0:
		var next_aspect: int = (int(aspect) + 1) % 4
		set_aspect(next_aspect as Aspect)
	_update_hazards(delta)
	if _rune_left > 0.0:
		_rune_left -= delta
		if _rune_left <= 0.0:
			_resolve_runes()
	else:
		_rune_cooldown -= delta
		if _rune_cooldown <= 0.0:
			begin_runes()
	return super._get_move_velocity(delta)


# ============================================================ 기믹 1: 원소 순환
func set_aspect(next: Aspect) -> void:
	aspect = next
	_aspect_changes += 1
	_aspect_left = aspect_time * (0.7 if phase_two else 1.0)
	_hazard_timer = 1.5
	defense = _base_defense + (earth_armor if aspect == Aspect.EARTH else 0)
	burn_damage = 10 if aspect == Aspect.FIRE else _base_burn
	burn_duration = 2.5
	if aspect == Aspect.WIND:
		if get_wind() == null:
			var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))
			wind = WindField.spawn(self, area.grow(40.0))
		if get_wind() != null:
			wind.set_wind(Vector2.from_angle(float(randi() % 8) * PI / 4.0), 240.0)
	elif get_wind() != null:
		wind.queue_free()
		wind = null
	base_tint = ASPECT_COLORS[aspect].lerp(Color.WHITE, 0.45)
	var extra := ""
	match aspect:
		Aspect.WIND:
			extra = "바람이 분다 %s — 투사체가 휜다" % (wind.get_arrow() if get_wind() != null else "")
		Aspect.EARTH:
			extra = "대지의 비늘 — 방어력 +%d" % Balance.scale(earth_armor)
		Aspect.ICE:
			extra = "발밑이 얼어붙는다 — 빙판에서 미끄러진다"
		Aspect.FIRE:
			extra = "불꽃을 두른다 — 화상 · 발밑에 용암"
	set_status("원소: %s" % ASPECT_NAMES[aspect], ASPECT_COLORS[aspect])
	GameManager.show_notice("아르케가 「%s」의 힘을 두른다! %s" % [ASPECT_NAMES[aspect], extra], ASPECT_COLORS[aspect])


func _update_hazards(delta: float) -> void:
	_hazard_timer -= delta
	if _hazard_timer > 0.0:
		return
	match aspect:
		Aspect.ICE:
			_hazard_timer = 2.2
			IceFloor.spawn(self, _player.global_position, 34.0, 10.0)
		Aspect.FIRE:
			_hazard_timer = 2.6
			var at := _player.global_position
			telegraph_strike(at, 20.0, 0.9, strike_damage - 20, Elements.Type.FIRE)
			_after(0.9, func() -> void:
				if not is_dead():
					GroundZone.spawn_hostile(self, at, GroundZone.Kind.FIRE, 22.0, 10.0, 1.0, roundi(10 * power), 2.0))
		_:
			_hazard_timer = 1.0


# ============================================================ 기믹 2: 고대 용언
func begin_runes(safe: int = -1) -> void:
	if get_runes() != null or is_dead():
		return
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
	var c := area.get_center()
	var dx := area.size.x * 0.3
	var dy := area.size.y * 0.25
	var points: Array[Vector2] = [c + Vector2(-dx, -dy), c + Vector2(dx, -dy), c + Vector2(-dx, dy), c + Vector2(dx, dy)]
	points.shuffle()
	if safe < 0:
		safe = randi() % 4
	_rune_left = rune_warn * (0.8 if phase_two else 1.0)
	_rune_cooldown = rune_interval * (0.75 if phase_two else 1.0)
	runes = DragonRunes.spawn(self, points, safe, _rune_left)
	set_status("고대 용언: 「%s」!" % DragonRunes.NAMES[safe], DragonRunes.COLORS[safe])
	GameManager.show_notice("아르케의 고대 용언 — 「%s」! %s의 룬 원 안으로 들어가라" % [DragonRunes.NAMES[safe], DragonRunes.NAMES[safe]], DragonRunes.COLORS[safe])


func _resolve_runes() -> void:
	_rune_left = 0.0
	var r := get_runes()
	if r == null:
		return
	Fx.explosion(self, get_hit_center(), Color(1.0, 0.95, 0.7), 120.0, 3)
	if has_target():
		if r.safe_contains(_player.global_position):
			_rune_dodges += 1
			FloatingText.spawn(_player, _player.global_position + Vector2(0, -26), "용언을 견뎠다!", Color(1.0, 0.95, 0.6), true)
		elif _player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * rune_ratio)), get_hit_center(), false) == Player.HitResult.DAMAGED:
			_rune_hits += 1
		_player.shake_camera(7.0)
	r.queue_free()
	runes = null
	set_status("원소: %s" % ASPECT_NAMES[aspect], ASPECT_COLORS[aspect])


# ============================================================ 패턴
func _aspect_texture() -> Texture2D:
	match aspect:
		Aspect.WIND:
			return wind_texture
		Aspect.EARTH:
			return rock_texture
		Aspect.ICE:
			return ice_texture
	return fire_texture


func _aspect_element() -> Elements.Type:
	match aspect:
		Aspect.WIND:
			return Elements.Type.NATURE
		Aspect.EARTH:
			return Elements.Type.EARTH
		Aspect.ICE:
			return Elements.Type.ICE
	return Elements.Type.FIRE


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.ASPECT:
			match aspect:
				Aspect.WIND:
					var aim := direction_to_player()
					for i in 9:
						shoot(aim.rotated((i - 4) * 0.15), 150.0, bullet_damage, wind_texture, 0.0, Elements.Type.NATURE)
				Aspect.EARTH:
					for i in 7:
						var at := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 100.0))
						telegraph_strike(at, 22.0, 0.9 + 0.08 * i, strike_damage, Elements.Type.EARTH)
				Aspect.ICE:
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0), 105.0, bullet_damage, ice_texture, 0.8, Elements.Type.ICE)
				Aspect.FIRE:
					var aim2 := direction_to_player()
					for w in 3:
						_after(0.2 * w, func() -> void:
							if not is_dead():
								for i in 5:
									shoot(aim2.rotated((i - 2) * 0.15), 165.0, bullet_damage, fire_texture, 0.0, Elements.Type.FIRE))
			return 1.2
		Pattern.ANCIENT:
			for w in 2:
				_after(0.35 * w, func() -> void:
					if is_dead():
						return
					for i in 18:
						shoot(Vector2.from_angle(TAU * i / 18.0 + w * 0.17), 110.0, bullet_damage, ancient_texture, 0.0, Elements.Type.HOLY))
			return 1.1
		Pattern.BREATH:
			var aim3 := direction_to_player()
			var tex := _aspect_texture()
			var element := _aspect_element()
			for w in 4:
				_after(0.18 * w, func() -> void:
					if not is_dead():
						for i in 7:
							shoot(aim3.rotated((i - 3) * 0.12 + randf_range(-0.04, 0.04)), 170.0, bullet_damage, tex, 0.0, element))
			return 1.3
	return 1.0


func _die() -> void:
	if get_wind() != null:
		wind.queue_free()
	if get_runes() != null:
		runes.queue_free()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("아르케: 다섯 용의 근원을 보아라! 원소가 더 빨리 바뀐다", Color(1.0, 0.95, 0.7))
