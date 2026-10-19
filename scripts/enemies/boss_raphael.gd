class_name BossRaphael
extends PatternBoss
## 98스테이지 보스: 치유의 대천사 라파엘 — 「하나님이 고치신다」. 토비아와 함께 길을 걸으며 물고기 쓸개로 악령을 쫓은 천사.
##   STAFF    : 순례자의 지팡이 — 일직선
##   BLESSING : 치유의 고리 — 몸 주위 고리 (닿으면 아픔)
##   FEATHERS : 깃털 탄막
##   SUMMON   : 빛의 치유사 · 천상의 수호병 · 천상의 사슴 호출
##
## [기믹] 치유의 샘: 보스방 양쪽에 샘 둘 — 라파엘은 체력이 heal_threshold 만큼 깎일 때마다 막히지 않은 샘으로 날아가
##   heal_time 초 동안 초당 최대 체력의 heal_rate 만큼 회복. 샘이 모두 막혀 있으면 갈 곳을 잃고 휘청
##   넓적한 돌을 들어 샘에 가져가면 seal_time 초 동안 샘이 덮임 (회복 중인 샘을 덮으면 회복이 끊기고 휘청)
## [기믹] 토비아의 물고기: fish_interval 초마다 물고기가 나타남 — 주우면 그 자리에서 쓸개를 태워 smoke_time 초 동안 연기가 피어오름
##   연기 안에서는 라파엘의 회복이 끊김

enum Pattern { STAFF, BLESSING, FEATHERS, SUMMON }
enum Mode { FIGHT, FLYING, HEALING }

const SMOKE_RADIUS := 70.0

@export var minion_scenes: Array[PackedScene] = []
@export var spring_texture: Texture2D
@export var stone_texture: Texture2D
@export var fish_texture: Texture2D
@export var feather_texture: Texture2D
@export var staff_damage: int = 104
@export var blessing_damage: int = 94
@export var feather_damage: int = 64
@export var heal_threshold: float = 0.15
@export var heal_time: float = 4.0
@export var heal_rate: float = 0.02
@export var seal_time: float = 25.0
@export var fish_interval: float = 15.0
@export var smoke_time: float = 10.0
@export var stagger_time: float = 7.0

var springs: Array[FieldProp] = []
var sealed: Array[float] = [0.0, 0.0]
var stone: CarryItem
var fish: CarryItem
var mode: Mode = Mode.FIGHT
var smoke_at: Vector2 = Vector2.INF
var _smoke_left: float = 0.0
var _heal_spring: int = -1
var _heal_left: float = 0.0
var _heal_acc: float = 0.0
var _healed: int = 0
var _heal_blocked: int = 0
var _next_heal_hp: int = 0
var _fish_left: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.STAFF, Pattern.FEATHERS, Pattern.BLESSING, Pattern.STAFF, Pattern.SUMMON]


func is_healing() -> bool:
	return mode == Mode.HEALING


func get_healed() -> int:
	return _healed


func get_heal_blocked() -> int:
	return _heal_blocked


func is_sealed(i: int) -> bool:
	return sealed[i] > 0.0


func in_smoke(at: Vector2) -> bool:
	return _smoke_left > 0.0 and at.distance_to(smoke_at) <= SMOKE_RADIUS


func spring_position(i: int) -> Vector2:
	var area := _area()
	return area.get_center() + Vector2((-1.0 if i == 0 else 1.0) * area.size.x * 0.36, 30.0)


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for i in 2:
			springs.append(FieldProp.spawn(self, spring_position(i), spring_texture, Color(0.6, 0.9, 1.0)))
		stone = CarryItem.spawn(self, _area().get_center() + Vector2(0, _area().size.y * 0.36), stone_texture, "넓적한 돌", Color(0.85, 0.85, 0.8))
		_next_heal_hp = hp - roundi(max_hp * heal_threshold)
		_fish_left = fish_interval * 0.5
		_update_status()
	match mode:
		Mode.FLYING:
			var to := spring_position(_heal_spring)
			if global_position.distance_to(to) < 6.0:
				_arrive()
				return Vector2.ZERO
			return global_position.direction_to(to) * 210.0
		Mode.HEALING:
			return Vector2.ZERO
	return super._get_move_velocity(delta)


## 막히지 않은 샘으로 날아감 (테스트에서도 직접 호출)
func seek_spring() -> void:
	if is_dead():
		return
	var best := -1
	for i in 2:
		if not is_sealed(i) and (best < 0 or global_position.distance_to(spring_position(i)) < global_position.distance_to(spring_position(best))):
			best = i
	_next_heal_hp = hp - roundi(max_hp * heal_threshold)
	if best < 0:
		_stagger("샘이 모두 덮여 라파엘이 갈 곳을 잃었다!")
		return
	_heal_spring = best
	mode = Mode.FLYING
	GameManager.show_notice("라파엘이 치유의 샘으로 날아간다 — 샘을 돌로 덮거나 연기로 막아라", Color(0.6, 0.95, 0.75))
	_update_status()


func _arrive() -> void:
	mode = Mode.HEALING
	_heal_left = heal_time
	_heal_acc = 0.0
	_update_status()


func _stagger(text: String) -> void:
	mode = Mode.FIGHT
	_heal_spring = -1
	super.stun(stagger_time)
	GameManager.show_notice(text + " 라파엘이 휘청인다", Color(0.9, 0.95, 0.8))
	_update_status()


## 샘을 돌로 덮음 (테스트에서도 직접 호출)
func seal_spring(i: int) -> void:
	sealed[i] = seal_time
	Fx.burst(self, spring_position(i), Color(0.75, 0.75, 0.7), 16, 50.0, 0.5)
	if stone != null and is_instance_valid(stone):
		stone.hide_for(3.0)
	if _heal_spring == i and mode != Mode.FIGHT:
		_heal_blocked += 1
		_stagger("치유의 샘이 덮였다!")
	else:
		GameManager.show_notice("치유의 샘을 넓적한 돌로 덮었다 (%.0f초)" % seal_time, Color(0.8, 0.9, 0.8))
	_update_status()


## 물고기 쓸개를 태움 (테스트에서도 직접 호출)
func burn_fish(at: Vector2) -> void:
	smoke_at = at
	_smoke_left = smoke_time
	Fx.burst(self, at, Color(0.55, 0.55, 0.6), 30, 50.0, 1.0, Vector2(0, -40))
	GameManager.show_notice("토비아의 물고기 쓸개를 태웠다 — 연기 안에서는 라파엘의 치유가 끊긴다", Color(0.75, 0.8, 0.85))


func _spawn_fish() -> void:
	if fish != null and is_instance_valid(fish):
		fish.queue_free()
	var area := _area().grow(-60.0)
	var at := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
	fish = CarryItem.spawn(self, at, fish_texture, "토비아의 물고기", Color(0.6, 0.8, 0.9))
	if fish != null:
		fish.follow_player = false
		fish.picked_up.connect(func(f: CarryItem) -> void:
			burn_fish(f.global_position)
			f.hide_for(99999.0))


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		for i in 2:
			sealed[i] = maxf(sealed[i] - delta, 0.0)
			if springs.size() > i and springs[i] != null and is_instance_valid(springs[i]):
				springs[i].modulate = Color(0.55, 0.55, 0.55) if is_sealed(i) else Color.WHITE
		if stone != null and is_instance_valid(stone) and stone.is_carried() and has_target():
			for i in 2:
				if not is_sealed(i) and _player.global_position.distance_to(spring_position(i)) < 28.0:
					seal_spring(i)
					break
		_smoke_left = maxf(_smoke_left - delta, 0.0)
		_fish_left -= delta
		if _fish_left <= 0.0:
			_fish_left = fish_interval
			_spawn_fish()
		if mode == Mode.FIGHT and hp <= _next_heal_hp and not is_stunned():
			seek_spring()
		elif mode == Mode.HEALING:
			_heal_left -= delta
			if in_smoke(global_position):
				if Engine.get_physics_frames() % 40 == 0:
					_heal_blocked += 1
					FloatingText.spawn(self, global_position + Vector2(0, -50), "연기에 치유가 막힘", Color(0.75, 0.8, 0.85))
			else:
				_heal_acc += max_hp * heal_rate * delta
				if _heal_acc >= 1.0:
					var heal := mini(int(_heal_acc), max_hp - hp)
					_heal_acc -= int(_heal_acc)
					if heal > 0:
						hp += heal
						_healed += heal
						health_changed.emit(hp, max_hp)
			if _heal_left <= 0.0:
				mode = Mode.FIGHT
				_heal_spring = -1
				_next_heal_hp = hp - roundi(max_hp * heal_threshold)
				_update_status()
		queue_redraw()
	super._physics_process(delta)


func _update_status() -> void:
	var text: String = ["", "샘으로 날아가는 중", "샘에서 치유하는 중"][mode]
	var open := 0
	for i in 2:
		if not is_sealed(i):
			open += 1
	set_status(("%s · " % text if text != "" else "") + "열린 샘 %d/2" % open, Color(0.65, 1.0, 0.8))


func _run_pattern(pattern: int) -> float:
	if not has_target() or mode != Mode.FIGHT:
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.STAFF:
			for i in 12:
				telegraph_strike(get_hit_center() + dir * (26.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, staff_damage, Elements.Type.HOLY)
			return 1.1
		Pattern.BLESSING:
			for i in 14:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0) * 56.0, 20.0, 0.85, blessing_damage, Elements.Type.NATURE)
			return 1.2
		Pattern.FEATHERS:
			for w in 2:
				for i in 12:
					shoot(Vector2.from_angle(TAU * i / 12.0 + w * 0.26), 125.0, feather_damage, feather_texture, 0.0, Elements.Type.HOLY)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


## 쓸개 연기
func _draw() -> void:
	if _smoke_left <= 0.0:
		return
	var c := to_local(smoke_at)
	var a := minf(_smoke_left / 2.0, 1.0)
	draw_circle(c, SMOKE_RADIUS, Color(0.45, 0.45, 0.5, 0.25 * a))
	draw_arc(c, SMOKE_RADIUS, 0.0, TAU, 40, Color(0.7, 0.7, 0.75, 0.5 * a), 2.0)


func _die() -> void:
	if stone != null and is_instance_valid(stone):
		stone.queue_free()
	if fish != null and is_instance_valid(fish):
		fish.queue_free()
	super._die()
