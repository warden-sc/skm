class_name BossGabriel
extends PatternBoss
## 100스테이지 보스: 대천사 가브리엘 — 「나는 하나님 앞에 서 있는 가브리엘이라」. 하늘의 뜻을 전하는 전령, 손에는 흰 백합.
##   REVELATION : 하늘의 전언 — 가브리엘이 먼저 말로 선포한 곳(동 · 서 · 북 · 남 · 가운데 · 가장자리)에 빛이 내림
##   SPEAR      : 빛의 창 (일직선 셋)
##   FEATHERS   : 깃털 탄막
##   SUMMON     : 백합의 정령 · 계시의 천사 · 스랍 호출
##
## [등장] 강림: 보스방에 들어서면 하늘에서 빛기둥이 내리고, descend_time 초 뒤 가브리엘이 내려오며 싸움이 시작됨 (그동안 무적)
## [기믹] 하늘의 전언: 공격하기 전에 어디에 빛이 내릴지 선포 — announce_time 초 뒤 그곳 전체에 빛
##   2페이즈부터 seal_chance 확률로 「봉인된 계시」 — 선포한 곳의 반대쪽에 빛이 내림
## [기믹] 백합의 정원: 보스방의 백합 LILY_COUNT 송이 — 백합 곁(lily_radius)에 있으면 전언의 빛 피해가 lily_ratio 로 줄어듦
##   가브리엘은 wither_interval 초마다 플레이어에게 가장 가까운 백합을 시들게 함 (lily_regrow 초 뒤 다시 핌)
## [기믹] 여섯 날개 각성: 체력 50% 이하에서 여섯 날개를 펴고 날아오름 — 활만 닿고 깃털 비가 내림
##   날개 하나하나(각각 보스 체력의 wing_hp_ratio)를 모두 떨어뜨리면 내려와 크게 휘청, 그 뒤로는 땅에서 싸움

enum Pattern { REVELATION, SPEAR, FEATHERS, SUMMON }
enum Region { EAST, WEST, NORTH, SOUTH, INNER, OUTER }

const REGION_NAMES := ["동쪽", "서쪽", "북쪽", "남쪽", "가운데", "가장자리"]
const OPPOSITE := [Region.WEST, Region.EAST, Region.SOUTH, Region.NORTH, Region.OUTER, Region.INNER]
const LILY_COUNT := 5
const INNER_RADIUS := 110.0
const FLIGHT_HEIGHT := 20.0

@export var wing_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var lily_texture: Texture2D
@export var withered_texture: Texture2D
@export var feather_texture: Texture2D
@export var revelation_damage: int = 112
@export var spear_damage: int = 106
@export var feather_damage: int = 66
@export var rain_damage: int = 94
@export var descend_time: float = 3.0
@export var announce_time: float = 1.6
@export var seal_chance: float = 0.45
@export var lily_radius: float = 34.0
@export var lily_ratio: float = 0.5
@export var wither_interval: float = 10.0
@export var lily_regrow: float = 20.0
@export var wing_hp_ratio: float = 0.012
@export var land_stun: float = 10.0

var lilies: Array[FieldProp] = []
var withered: Array[float] = []
var wings: Array[BossPart] = []
var center: Vector2 = Vector2.ZERO
var _descend_left: float = 0.0
var _descending: bool = true
var _flying: bool = false
var _landed: bool = false
var _wither_left: float = 0.0
var _rain_left: float = 0.0
var _revelations: int = 0
var _sealed: int = 0
var _revelation_hits: int = 0
var _lily_saves: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.REVELATION, Pattern.SPEAR, Pattern.REVELATION, Pattern.FEATHERS, Pattern.SUMMON]
	immune_text = "하늘에서 내려오는 중 — 아직 닿지 않는다"


func is_descending() -> bool:
	return _descending


func is_flying() -> bool:
	return _flying


func get_revelation_hits() -> int:
	return _revelation_hits


func get_lily_saves() -> int:
	return _lily_saves


func get_sealed_count() -> int:
	return _sealed


func living_wings() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for w in wings:
		if is_instance_valid(w) and not w.is_dead():
			alive.append(w)
	return alive


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		center = _area().get_center()
		global_position = center + Vector2(0, -25)
		_descend_left = descend_time
		Fx.pillar(self, global_position, Color(1.0, 0.97, 0.8), 40.0, 260.0, 0.9)
		GameManager.show_notice("하늘이 열리고 빛기둥이 내린다…", Color(1.0, 0.97, 0.8))
		set_status("강림하는 중…", Color(1.0, 0.97, 0.8))
	if _descending:
		return Vector2.ZERO
	return super._get_move_velocity(delta)


## 하늘에서 내려옴 (테스트에서도 직접 호출)
func descend() -> void:
	if not _descending or is_dead():
		return
	_descending = false
	_descend_left = 0.0
	immune_text = "여섯 날개로 날아오름 — 활만 닿음 · 날개를 떨어뜨려라"
	for i in LILY_COUNT:
		var at := center + Vector2(cos(TAU * i / LILY_COUNT + 0.3) * _area().size.x * 0.34, sin(TAU * i / LILY_COUNT + 0.3) * _area().size.y * 0.34)
		lilies.append(FieldProp.spawn(self, at, lily_texture, Color(1.0, 1.0, 0.85)))
		withered.append(0.0)
	_wither_left = wither_interval
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.97, 0.8), 180.0, 0.8)
	GameManager.show_notice("「나는 하나님 앞에 서 있는 가브리엘이라」 — 대천사가 내려와 백합이 피어난다", Color(1.0, 0.97, 0.8))
	_update_status()


func can_be_hit_by(kind: HitKind) -> bool:
	return not _descending and super.can_be_hit_by(kind)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _descending:
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


# ============================================================ 백합의 정원
func is_lily_alive(i: int) -> bool:
	return i < lilies.size() and withered[i] <= 0.0


func near_lily(at: Vector2) -> bool:
	for i in lilies.size():
		if is_lily_alive(i) and lilies[i] != null and is_instance_valid(lilies[i]) and at.distance_to(lilies[i].global_position) <= lily_radius:
			return true
	return false


## 백합을 시들게 함 (테스트에서도 직접 호출)
func wither_lily(i: int) -> void:
	if i < 0 or i >= lilies.size():
		return
	withered[i] = lily_regrow
	if lilies[i] != null and is_instance_valid(lilies[i]):
		lilies[i]._sprite.texture = withered_texture
	Fx.burst(self, lilies[i].global_position, Color(0.8, 0.75, 0.55), 10, 40.0, 0.5)


func _nearest_lily_to_player() -> int:
	var best := -1
	for i in lilies.size():
		if is_lily_alive(i) and (best < 0 or _player.global_position.distance_to(lilies[i].global_position) < _player.global_position.distance_to(lilies[best].global_position)):
			best = i
	return best


# ============================================================ 하늘의 전언
func in_region(at: Vector2, region: int) -> bool:
	match region:
		Region.EAST:
			return at.x > center.x
		Region.WEST:
			return at.x < center.x
		Region.NORTH:
			return at.y < center.y
		Region.SOUTH:
			return at.y > center.y
		Region.INNER:
			return at.distance_to(center) < INNER_RADIUS
	return at.distance_to(center) >= INNER_RADIUS


## 전언을 선포하고 announce_time 초 뒤 빛을 내림 (테스트에서도 직접 호출) — 실제로 빛이 내릴 곳을 돌려줌
func announce(region: int, sealed: bool) -> int:
	var actual: int = OPPOSITE[region] if sealed else region
	_revelations += 1
	if sealed:
		_sealed += 1
		GameManager.show_notice("봉인된 계시: 「%s」 — 반대쪽에 빛이 내린다!" % REGION_NAMES[region], Color(0.85, 0.75, 1.0))
	else:
		GameManager.show_notice("가브리엘의 전언: 「%s에 빛이 내리리라」" % REGION_NAMES[region], Color(1.0, 0.97, 0.8))
	var area := _area().grow(-10.0)
	var y := area.position.y + 24.0
	while y < area.end.y:
		var x := area.position.x + 24.0
		while x < area.end.x:
			if in_region(Vector2(x, y), actual):
				var strike := AoeStrike.spawn(self, Vector2(x, y), 22.0, announce_time, 1, Color(1.0, 0.95, 0.7))
				if strike != null:
					strike.harmless = true
			x += 48.0
		y += 48.0
	_after(announce_time, func() -> void:
		if is_dead() or not has_target():
			return
		if in_region(_player.global_position, actual) and not _player.is_invincible():
			var safe := near_lily(_player.global_position)
			if safe:
				_lily_saves += 1
			_revelation_hits += 1
			_player.take_hit(maxi(1, roundi(revelation_damage * power * (lily_ratio if safe else 1.0))), center, self))
	return actual


# ============================================================ 여섯 날개 각성
func _on_phase_two() -> void:
	_flying = true
	airborne = true
	_rain_left = 2.0
	if wing_scene != null:
		for i in 6:
			request_summon(wing_scene, global_position + _wing_offset(i))
	GameManager.show_notice("가브리엘이 여섯 날개를 펴고 날아오른다 — 활로 날개를 떨어뜨려라", Color(1.0, 0.97, 0.8))
	_update_status()


func _wing_offset(i: int) -> Vector2:
	var side := -1.0 if i % 2 == 0 else 1.0
	return Vector2(side * (22.0 + 6.0 * floori(i / 2.0)), -48.0 + 14.0 * floori(i / 2.0))


func register_minion(minion: Enemy) -> void:
	if wing_scene != null and minion.scene_file_path == wing_scene.resource_path:
		var w := minion as BossPart
		var i := wings.size()
		w.boss = self
		w.follow_boss = true
		w.anchor_offset = _wing_offset(i)
		var flip := i % 2 == 0
		if w.is_node_ready():
			w.sprite.flip_h = flip
		else:  # 소환은 지연 추가라 아직 _ready 전일 수 있음
			w.ready.connect(func() -> void: w.sprite.flip_h = flip, CONNECT_ONE_SHOT)
		w.max_hp = maxi(1, roundi(max_hp * wing_hp_ratio))
		w.hp = w.max_hp
		w.died.connect(_on_wing_lost)
		wings.append(w)


func _on_wing_lost(_w: Enemy) -> void:
	if is_dead():
		return
	if living_wings().is_empty() and _flying:
		land()
	else:
		GameManager.show_notice("날개 하나가 떨어졌다 (남은 날개 %d)" % living_wings().size(), Color(1.0, 0.97, 0.8))
	_update_status()


## 날개를 모두 잃고 내려옴 (테스트에서도 직접 호출)
func land() -> void:
	_flying = false
	_landed = true
	airborne = false
	for w in living_wings():
		w.despawn()
	super.stun(land_stun)
	Fx.shockwave(self, global_position, Color(1.0, 0.97, 0.8), 120.0, 0.6)
	GameManager.show_notice("여섯 날개를 모두 잃은 가브리엘이 땅에 내려섰다!", Color(1.0, 0.97, 0.8))
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _descending:
			_descend_left -= delta
			if _descend_left <= 0.0:
				descend()
		elif has_target():
			for i in withered.size():
				if withered[i] > 0.0:
					withered[i] -= delta
					if withered[i] <= 0.0 and lilies[i] != null and is_instance_valid(lilies[i]):
						lilies[i]._sprite.texture = lily_texture
			_wither_left -= delta
			if _wither_left <= 0.0:
				_wither_left = wither_interval * (0.7 if phase_two else 1.0)
				var i := _nearest_lily_to_player()
				if i >= 0:
					wither_lily(i)
					GameManager.show_notice("가브리엘이 손을 들자 백합 한 송이가 시든다 — 다른 백합으로", Color(0.9, 0.85, 0.65))
			if _flying:
				_rain_left -= delta
				if _rain_left <= 0.0:
					_rain_left = 2.6
					for k in 5:
						telegraph_strike(_player.global_position + Vector2.from_angle(TAU * k / 5.0 + randf()) * randf_range(10.0, 70.0), 18.0, 0.9 + 0.05 * k, rain_damage, Elements.Type.HOLY)
	super._physics_process(delta)


func _update_status() -> void:
	var text := "하늘의 전언"
	if _flying:
		text = "여섯 날개 (남은 날개 %d) · 활만 닿음" % living_wings().size()
	elif phase_two:
		text = "봉인된 계시가 섞임"
	set_status(text, Color(1.0, 0.97, 0.8))


func _run_pattern(pattern: int) -> float:
	if not has_target() or _descending:
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.REVELATION:
			var region := randi() % REGION_NAMES.size()
			if not in_region(_player.global_position, region) and randf() < 0.6:
				region = OPPOSITE[region]  # 대개는 플레이어가 있는 곳을 선포
			announce(region, phase_two and randf() < seal_chance)
			return announce_time + 0.4
		Pattern.SPEAR:
			for k in 3:
				var d := dir.rotated((k - 1) * 0.35)
				for i in 12:
					telegraph_strike(get_hit_center() + d * (26.0 + 22.0 * i), 13.0, 0.65 + 0.03 * i, spear_damage, Elements.Type.HOLY)
			return 1.2
		Pattern.FEATHERS:
			for w in 2:
				for i in 14:
					shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 125.0, feather_damage, feather_texture, 0.0, Elements.Type.HOLY)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if _descending:
		var t := clampf(_descend_left / maxf(descend_time, 0.01), 0.0, 1.0)
		sprite.position = _base_sprite_pos + Vector2(0, -60.0 * t)
		sprite.modulate = Color(1, 1, 1, 0.35 + 0.65 * (1.0 - t))
	elif airborne:
		sprite.position.y += -FLIGHT_HEIGHT + sin(_anim_time * 3.0) * 2.0
