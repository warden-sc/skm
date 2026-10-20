class_name BossScylla
extends PatternBoss
## 44스테이지 보스: 스킬라와 카립디스 — 해협 양쪽을 지키는 두 바다 괴물.
##   스킬라(보스 본체): 보스방 가장자리를 따라 움직이는 여섯 머리의 괴물
##   카립디스: 보스방 한가운데의 소용돌이 (Whirlpool)
##   HEADS   : 여섯 머리 — 가장자리 띠(edge_band) 안을 물어뜯는 장판 6개 (가장자리에 있으면 플레이어를 노림)
##   BITE    : 늘어나는 목 — 스킬라에서 플레이어 쪽 일직선 장판
##   SPIT    : 카립디스가 바닷물을 토해냄 — 소용돌이 중심에서 사방으로 물방울
##   SUMMON  : 해협 상어 · 바다뱀 전사 호출
##
## [기믹] 해협: 가운데는 카립디스가 빨아들이고(중심에 빠지면 최대 체력의 8% 씩 피해), 가장자리는 스킬라의 머리가 덮침
##   swallow_interval 초마다 카립디스가 swallow_time 초 동안 거세게 빨아들임 → 그 뒤 바닷물을 토해냄
##   → 둘 사이의 「중간 고리」에서 버티며, 스킬라는 활·마법이나 잠깐 다가가서 때려야 함
## 체력 50% 이하: 더 자주 거세게 빨아들임

enum Pattern { HEADS, BITE, SPIT, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var water_texture: Texture2D
@export var head_damage: int = 84
@export var bite_damage: int = 80
@export var spit_damage: int = 52
@export var edge_band: float = 70.0
@export var swallow_interval: float = 12.0
@export var swallow_time: float = 4.0

var whirlpool: Whirlpool
var _swallow_cooldown: float = 6.0
var _swallows: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.HEADS, Pattern.BITE, Pattern.HEADS, Pattern.SUMMON, Pattern.BITE]


func get_whirlpool() -> Whirlpool:
	return whirlpool if whirlpool != null and is_instance_valid(whirlpool) else null


func get_swallow_count() -> int:
	return _swallows


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))


## 가장자리 띠 안인지 (스킬라의 머리가 닿는 곳)
func in_edge_band(point: Vector2) -> bool:
	var a := _area()
	return minf(minf(point.x - a.position.x, a.end.x - point.x), minf(point.y - a.position.y, a.end.y - point.y)) <= edge_band


## point 에서 가장 가까운 가장자리 지점 (띠 안쪽 edge_band * 0.4)
func edge_point(point: Vector2) -> Vector2:
	var a := _area()
	var inset := edge_band * 0.4
	var d := [point.x - a.position.x, a.end.x - point.x, point.y - a.position.y, a.end.y - point.y]
	var best := 0
	for i in 4:
		if float(d[i]) < float(d[best]):
			best = i
	match best:
		0:
			return Vector2(a.position.x + inset, clampf(point.y, a.position.y + inset, a.end.y - inset))
		1:
			return Vector2(a.end.x - inset, clampf(point.y, a.position.y + inset, a.end.y - inset))
		2:
			return Vector2(clampf(point.x, a.position.x + inset, a.end.x - inset), a.position.y + inset)
	return Vector2(clampf(point.x, a.position.x + inset, a.end.x - inset), a.end.y - inset)


func _get_move_velocity(delta: float) -> Vector2:
	if get_whirlpool() == null and has_target():
		whirlpool = Whirlpool.spawn(self, _area().get_center())
		if whirlpool != null:
			whirlpool.radius = minf(_area().size.x, _area().size.y) * 0.62
	if has_target() and get_whirlpool() != null:
		_swallow_cooldown -= delta
		if _swallow_cooldown <= 0.0:
			begin_swallow()
	return super._get_move_velocity(delta)


## 스킬라는 늘 가장자리를 따라(가운데를 가로지르지 않고) 플레이어와 가장 가까운 가장자리로
func _chase_velocity(delta: float) -> Vector2:
	var speed := move_speed * (1.3 if phase_two else 1.0)
	if not in_edge_band(global_position):
		return global_position.direction_to(edge_point(global_position)) * speed
	# 둘레를 따라 짧은 쪽으로 돌아감
	var length := _perimeter_length()
	var t0 := _to_perimeter(global_position)
	var gap := wrapf(_to_perimeter(_player.global_position) - t0, -length * 0.5, length * 0.5)
	if absf(gap) < 6.0:
		return Vector2.ZERO
	var next := _from_perimeter(t0 + signf(gap) * minf(absf(gap), speed * delta))
	return (next - global_position) / maxf(delta, 0.001)


func _inner_rect() -> Rect2:
	return _area().grow(-edge_band * 0.4)


func _perimeter_length() -> float:
	var r := _inner_rect()
	return 2.0 * (r.size.x + r.size.y)


## 가장자리 지점 → 둘레 위 거리 (위 → 오른쪽 → 아래 → 왼쪽, 시계 방향)
func _to_perimeter(point: Vector2) -> float:
	var r := _inner_rect()
	var q := edge_point(point)
	if is_equal_approx(q.y, r.position.y):
		return q.x - r.position.x
	if is_equal_approx(q.x, r.end.x):
		return r.size.x + (q.y - r.position.y)
	if is_equal_approx(q.y, r.end.y):
		return r.size.x + r.size.y + (r.end.x - q.x)
	return 2.0 * r.size.x + r.size.y + (r.end.y - q.y)


func _from_perimeter(t: float) -> Vector2:
	var r := _inner_rect()
	t = fposmod(t, _perimeter_length())
	if t <= r.size.x:
		return Vector2(r.position.x + t, r.position.y)
	t -= r.size.x
	if t <= r.size.y:
		return Vector2(r.end.x, r.position.y + t)
	t -= r.size.y
	if t <= r.size.x:
		return Vector2(r.end.x - t, r.end.y)
	t -= r.size.x
	return Vector2(r.position.x, r.end.y - t)


# ============================================================ 기믹: 카립디스
func begin_swallow() -> void:
	if get_whirlpool() == null:
		return
	_swallows += 1
	_swallow_cooldown = swallow_interval * (0.75 if phase_two else 1.0)
	whirlpool.swallow(swallow_time)
	Net.announce("카립디스가 바닷물을 삼킨다! 한가운데로 빨려 들어가지 마라", Color(0.6, 0.85, 1.0))
	_after(swallow_time, func() -> void:
		if not is_dead():
			spit())


## 카립디스가 바닷물을 토해냄 (소용돌이 중심에서 사방으로)
func spit() -> void:
	if get_whirlpool() == null:
		return
	for w in 2:
		_after(0.3 * w, func() -> void:
			if is_dead() or get_whirlpool() == null:
				return
			for i in 18:
				shoot(Vector2.from_angle(TAU * i / 18.0 + w * 0.17), 105.0, spit_damage, water_texture, 0.6, Elements.Type.ICE, whirlpool.global_position))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.HEADS:
			var near := edge_point(_player.global_position)
			for i in 6:
				var at := _player.global_position if (i == 0 and in_edge_band(_player.global_position)) else edge_point(near + Vector2(randf_range(-110, 110), randf_range(-110, 110)))
				telegraph_strike(at, 24.0, 0.7 + 0.08 * i, head_damage, Elements.Type.DARK)
			return 1.3
		Pattern.BITE:
			var dir := direction_to_player()
			for i in 10:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 15.0, 0.6 + 0.04 * i, bite_damage, Elements.Type.DARK)
			return 1.2
		Pattern.SPIT:
			spit()
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-40.0 + 80.0 * i, 0.0))
			return 0.9
	return 1.0


func _die() -> void:
	if get_whirlpool() != null:
		whirlpool.queue_free()
	super._die()


func _on_phase_two() -> void:
	Net.announce("해협이 요동친다! 카립디스가 더 자주 바닷물을 삼킨다", Color(0.6, 0.85, 1.0))
