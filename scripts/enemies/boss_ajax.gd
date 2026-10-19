class_name BossAjax
extends PatternBoss
## 75스테이지 보스: 큰 아이아스 — 일곱 겹 소가죽 탑 방패를 든 그리스 진영의 성벽 같은 거인 장수.
##   SPEAR   : 창 찌르기 (바라보는 방향 일직선)
##   BRACE   : 방패를 땅에 박고 버팀 — brace_time 초 동안 앞에서 오는 공격은 겹도 깎이지 않고, 가까이 오면 밀쳐 냄
##   BOULDER : 바위 던지기 (플레이어 주변 장판 셋)
##   SUMMON  : 살라미스 방패병 · 투석병 호출
##
## [기믹] 일곱 겹 소가죽 방패: 앞쪽(바라보는 방향)에서 들어온 피해는 본체 대신 방패가 받음 — 한 겹마다 체력 따로(layer_ratio)
##   한 겹을 다 찢으면 잠깐 휘청. 7겹을 모두 찢으면 방패가 없어져 무방비 (방어력 -bare_defense)
##   옆·뒤에서 들어온 공격은 그대로 본체로. 아이아스는 turn_speed 로 몸을 돌려 방패를 플레이어 쪽으로 향함
## 체력 50% 이하: 버티기가 잦아짐

enum Pattern { SPEAR, BRACE, BOULDER, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var spear_damage: int = 98
@export var boulder_damage: int = 88
@export var layer_ratio: float = 0.03
@export var turn_speed: float = 2.2
@export var brace_time: float = 2.5
@export var bare_defense: int = 20

var facing: Vector2 = Vector2.DOWN
var layers: int = 7
var layer_hp: int = 0
var _brace_left: float = 0.0
var _base_defense: int = 0
var _front_blocks: int = 0


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.SPEAR, Pattern.BRACE, Pattern.BOULDER, Pattern.SPEAR, Pattern.SUMMON]
	layer_hp = maxi(1, roundi(max_hp * layer_ratio))
	_update_status()


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_defense = defense


func is_bracing() -> bool:
	return _brace_left > 0.0


func get_front_blocks() -> int:
	return _front_blocks


func is_in_front(at: Vector2) -> bool:
	return facing.dot(global_position.direction_to(at)) > 0.2


func _get_move_velocity(delta: float) -> Vector2:
	if has_target():
		var want := direction_to_player()
		var rate := turn_speed * (3.0 if is_bracing() else 1.0)
		facing = facing.rotated(clampf(facing.angle_to(want), -rate * delta, rate * delta)).normalized()
	if _brace_left > 0.0:
		_brace_left -= delta
		if has_target() and global_position.distance_to(_player.global_position) < 36.0:
			_player.apply_push(global_position.direction_to(_player.global_position) * 260.0)
		return Vector2.ZERO
	return super._get_move_velocity(delta)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and layers > 0 and not is_dead() and has_target() and is_in_front(_player.global_position):
		_front_blocks += 1
		_hit_flash = 0.05
		if is_bracing():
			FloatingText.spawn(self, global_position + Vector2(0, -44), "버팀!", Color(0.9, 0.85, 0.7))
			return
		layer_hp -= amount
		FloatingText.spawn(self, global_position + Vector2(0, -40), "방패 %d" % amount, Color(0.85, 0.75, 0.55))
		if layer_hp <= 0:
			_tear_layer()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _tear_layer() -> void:
	layers -= 1
	layer_hp = maxi(1, roundi(max_hp * layer_ratio))
	Fx.burst(self, get_hit_center() + facing * 16.0, Color(0.7, 0.55, 0.35), 18, 70.0, 0.5)
	if layers <= 0:
		defense = maxi(_base_defense - bare_defense, 0)
		super.stun(6.0)
		GameManager.show_notice("일곱 겹 방패가 모두 찢어졌다! 아이아스가 무방비가 된다", Color(1.0, 0.85, 0.5))
	else:
		super.stun(1.0)
		GameManager.show_notice("소가죽 방패 한 겹이 찢어졌다 (남은 겹 %d/7)" % layers, Color(1.0, 0.85, 0.6))
	_update_status()


func _update_status() -> void:
	if layers > 0:
		set_status("일곱 겹 방패 — 남은 겹 %d/7 · 옆이나 뒤를 노려라" % layers, Color(0.95, 0.85, 0.65))
	else:
		set_status("방패 없음 (방어력 -%d)" % Balance.scale(bare_defense), Color(1.0, 0.6, 0.5))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	if pattern == Pattern.BRACE and layers <= 0:
		pattern = Pattern.BOULDER
	match pattern:
		Pattern.SPEAR:
			for k in 2:
				var d := facing.rotated((k - 0.5) * 0.25)
				for i in 10:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.NONE)
			return 1.1
		Pattern.BRACE:
			_brace_left = brace_time
			Fx.shockwave(self, get_hit_center(), Color(0.9, 0.8, 0.6), 50.0, 0.4)
			return brace_time + 0.2
		Pattern.BOULDER:
			for i in 3:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 50.0)
				telegraph_strike(at, 28.0, 1.0 + 0.15 * i, boulder_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if absf(facing.x) > 0.1:
		sprite.flip_h = facing.x > 0.0  # 방패(그림 왼쪽)가 바라보는 쪽으로
	queue_redraw()


## 방패가 향한 쪽 표시
func _draw() -> void:
	if is_dead() or layers <= 0:
		return
	var side := facing.orthogonal() * 20.0
	var c := facing * 26.0
	draw_line(c - side, c + side, Color(0.85, 0.7, 0.45, 0.7 if not is_bracing() else 1.0), 3.0)


func _on_phase_two() -> void:
	pattern_order = [Pattern.SPEAR, Pattern.BRACE, Pattern.BOULDER, Pattern.BRACE, Pattern.SPEAR, Pattern.SUMMON]
	GameManager.show_notice("아이아스: 이 방패를 넘을 수 있을까! 버티기가 잦아진다", Color(0.95, 0.85, 0.65))
