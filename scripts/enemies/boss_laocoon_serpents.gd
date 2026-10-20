class_name BossLaocoonSerpents
extends PatternBoss
## 71스테이지 보스: 라오콘의 바다뱀 「포르케스 & 카리보이아」 — 트로이 목마를 의심한 라오콘을 덮치라고 아테나가 보낸 쌍둥이 바다뱀.
## 포르케스(보스 본체)와 카리보이아(BossPart, 받은 피해를 그대로 본체에 넘김)가 보스방 양쪽 물웅덩이에 하나씩.
##   BITE   : 솟은 뱀이 플레이어 쪽으로 일직선 물기
##   WAVE   : 솟은 뱀 주위로 물결 고리
##   SPIT   : 바닷물 탄 (부채꼴)
##   COIL   : 휘감기 — 예고 자리에 있으면 휘감김
##
## [기믹] 번갈아 솟기: 두 뱀 중 하나만 물 위로 솟아 싸우고(surface_time 초), 다른 하나는 물속 (때릴 수 없음) → 번갈아 바뀜
## [기믹] 휘감기: 잡히면 움직일 수 없고 0.5초마다 최대 체력의 squeeze_ratio 만큼 조여짐 (가드 불가)
##   공격을 escape_hits 번 연타하면 빠져나옴 (bind_time 초가 지나도 풀림)
## 체력 50% 이하: 더 자주 바뀌고, 휘감기를 빠져나오려면 더 많이 연타해야 함

enum Pattern { BITE, WAVE, SPIT, COIL }

const POOL_SPOTS := [Vector2(-180, -10), Vector2(180, -10)]

@export var twin_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var spit_texture: Texture2D
@export var bite_damage: int = 96
@export var wave_damage: int = 84
@export var spit_damage: int = 60
@export var surface_time: float = 6.0
@export var bind_time: float = 5.0
@export var escape_hits: int = 6
@export var squeeze_ratio: float = 0.03

var twin: BossPart
var pools: Array[WaterPool] = []
var up: int = 0   # 0 = 포르케스, 1 = 카리보이아
var _surface_left: float = 6.0
var _bound_left: float = 0.0
var _struggles: int = 0
var _squeeze_tick: float = 0.0
var _binds: int = 0
var _escapes: int = 0
var _started: bool = false
var _twin_ready: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BITE, Pattern.SPIT, Pattern.COIL, Pattern.WAVE, Pattern.SPIT]


func is_binding() -> bool:
	return _bound_left > 0.0


func get_escape_count() -> int:
	return _escapes


func get_bind_count() -> int:
	return _binds


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func pool_position(i: int) -> Vector2:
	return _area().get_center() + POOL_SPOTS[i]


## 지금 솟아 있는 뱀의 위치
func up_position() -> Vector2:
	if up == 1 and twin != null and is_instance_valid(twin):
		return twin.get_hit_center()
	return get_hit_center()


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for i in POOL_SPOTS.size():
			pools.append(WaterPool.spawn(self, pool_position(i), 40.0))
		global_position = pool_position(0)
		if twin_scene != null:
			request_summon(twin_scene, pool_position(1))
		if _player.has_signal(&"attacked"):
			_player.attacked.connect(_on_player_attacked)
		_update_status()
	super._get_move_velocity(delta)
	return Vector2.ZERO  # 물웅덩이에서 움직이지 않음


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and twin == null:
		twin = minion as BossPart
		twin.boss = self
		twin.follow_boss = false
		twin.relay_ratio = 1.0  # 카리보이아가 받은 피해는 그대로 본체로
		_apply_surface()


## 카리보이아가 맞으면 본체가 피해
func take_weak_point_hit(amount: int, knockback: Vector2, is_crit: bool, armor_pen: int, ratio: float) -> void:
	if up == 1:
		_take(roundi(amount * ratio), knockback, is_crit, armor_pen)


func _take(amount: int, knockback: Vector2, is_crit: bool, armor_pen: int) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if up == 1:
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


## 물속/물 위 상태 반영 (물속이면 맞지 않음)
func _apply_surface() -> void:
	var porkes_up := up == 0
	collision_layer = Layers.ENEMY if porkes_up else 0
	airborne = not porkes_up  # 물속: 몸통 접촉 피해 없음
	sprite.modulate.a = 1.0 if porkes_up else 0.12
	if twin != null and is_instance_valid(twin) and twin.is_inside_tree():
		twin.collision_layer = 0 if porkes_up else Layers.ENEMY
		twin.sprite.modulate.a = 0.12 if porkes_up else 1.0
	immune_text = "물속에 잠김 — 솟아 있는 뱀을 노려라"
	_update_status()


## 다른 뱀이 솟음 (테스트에서도 직접 호출)
func swap() -> void:
	up = 1 - up
	_surface_left = surface_time * (0.7 if phase_two else 1.0)
	Fx.burst(self, up_position(), Color(0.5, 0.75, 1.0), 24, 80.0, 0.6, Vector2(0, -60))
	_apply_surface()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if not _twin_ready and twin != null and is_instance_valid(twin) and twin.is_inside_tree():
			_twin_ready = true
			_apply_surface.call_deferred()  # 카리보이아가 트리에 들어온 뒤 (Enemy._ready 가 충돌층을 덮어쓰므로)
		_surface_left -= delta
		if _surface_left <= 0.0 and not is_binding():
			swap()
		if _bound_left > 0.0:
			_bound_left -= delta
			_squeeze_tick -= delta
			if _squeeze_tick <= 0.0 and has_target():
				_squeeze_tick = 0.5
				_player.take_unblockable_hit(roundi(GameManager.max_hp * squeeze_ratio), up_position(), false)
			if _bound_left <= 0.0:
				_release(false)
	super._physics_process(delta)


## 휘감기 (테스트에서도 직접 호출)
func bind() -> void:
	if not has_target() or _player.is_dashing() or is_binding():
		return
	_binds += 1
	_bound_left = bind_time
	_struggles = 0
	_squeeze_tick = 0.5
	_player.apply_root(bind_time, "휘감김! 공격을 연타해 빠져나가라")
	Net.announce("바다뱀에게 휘감겼다! 공격을 연타해 빠져나가라", Color(0.6, 0.85, 1.0))


func _on_player_attacked() -> void:
	if not is_binding():
		return
	_struggles += 1
	FloatingText.spawn(_player, _player.global_position + Vector2(0, -26), "%d / %d" % [_struggles, _needed()], Color(0.7, 0.9, 1.0))
	if _struggles >= _needed():
		_release(true)


func _needed() -> int:
	return escape_hits + (2 if phase_two else 0)


func _release(escaped: bool) -> void:
	_bound_left = 0.0
	if has_target():
		_player.release_root()
	if escaped:
		_escapes += 1
		FloatingText.spawn(_player, _player.global_position + Vector2(0, -30), "빠져나왔다!", Color(0.7, 0.95, 1.0), true)


func _update_status() -> void:
	set_status("%s 솟음 — 다른 뱀은 물속" % ("포르케스" if up == 0 else "카리보이아"), Color(0.6, 0.85, 1.0))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var from := up_position()
	var dir := from.direction_to(_player.global_position)
	match pattern:
		Pattern.BITE:
			for i in 10:
				telegraph_strike(from + dir * (26.0 + 24.0 * i), 16.0, 0.6 + 0.03 * i, bite_damage, Elements.Type.NONE)
			return 1.1
		Pattern.WAVE:
			for i in 12:
				telegraph_strike(from + Vector2.from_angle(TAU * i / 12.0) * 60.0, 22.0, 0.85, wave_damage, Elements.Type.ICE)
			return 1.2
		Pattern.SPIT:
			for i in 7:
				shoot(dir.rotated((i - 3) * 0.16), 150.0, spit_damage, spit_texture, 0.0, Elements.Type.ICE, from)
			if not minion_scenes.is_empty() and randf() < 0.5:
				request_summon(minion_scenes.pick_random(), from + Vector2(0, 40))
			return 1.0
		Pattern.COIL:
			var at := _player.global_position
			var strike := telegraph_strike(at, 24.0, 0.8, 30, Elements.Type.ICE)
			if strike != null:
				strike.color = Color(0.4, 0.7, 1.0)
			_after(0.8, func() -> void:
				if not is_dead() and has_target() and _player.global_position.distance_to(at) <= 26.0:
					bind())
			return 1.2
	return 1.0


func _die() -> void:
	if is_binding():
		_release(false)
	sprite.modulate.a = 1.0
	collision_layer = 0
	super._die()


func _on_phase_two() -> void:
	Net.announce("두 바다뱀이 몸부림친다! 더 자주 바뀌고, 휘감기가 더 단단해진다", Color(0.6, 0.85, 1.0))
