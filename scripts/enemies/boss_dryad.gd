class_name BossDryad
extends Enemy
## 4스테이지 보스: 숲의 주인 드라이어드.
## 숲의 몬스터를 소환하고, 소환한 몬스터들을 덩굴로 이어 직접 지휘합니다.
##
## 패턴 (순환, 지휘할 몬스터가 없으면 먼저 소환):
##   SUMMON   : 땅에서 뿌리가 솟으며 숲 몬스터(늑대·버섯·트렌트) 소환 → 덩굴로 연결되어 지휘 대상이 됨
##   CHARGE   : "돌격하라!" — 지휘 중인 몬스터 전부가 잠깐 힘을 모은 뒤 플레이어에게 일제히 돌격
##   SURROUND : "포위하라!" — 몬스터들이 플레이어를 둥글게 에워싼 뒤 한꺼번에 덮침
##   THORNS   : 가시 탄막을 부채꼴로 여러 번 발사
##   ROOTS    : 플레이어 발밑에 휘감는 뿌리 (예고 장판, 맞으면 감속)
##   GUARD    : "나를 지켜라!" — 몬스터들이 드라이어드 곁으로 돌아와 호위 (2페이즈: 끝나면 한 마리의 생명을 흡수해 회복)
## 체력 50% 이하: 숲의 분노 — 소환 수 증가, 명령 주기 단축, 생명 흡수 사용
##
## 드라이어드는 마법사라 플레이어와 거리를 두고 떠다닙니다.

enum State { DRIFT, CASTING }
enum Pattern { SUMMON, CHARGE, THORNS, SURROUND, ROOTS, GUARD }

const PATTERN_ORDER := [Pattern.SUMMON, Pattern.CHARGE, Pattern.THORNS, Pattern.SUMMON, Pattern.SURROUND, Pattern.ROOTS, Pattern.GUARD, Pattern.CHARGE]
const SHOUTS := {
	Pattern.CHARGE: "돌격하라!",
	Pattern.SURROUND: "포위하라!",
	Pattern.GUARD: "나를 지켜라!",
}
const MAX_MINIONS := 6
const VINE_COLOR := Color(0.45, 0.9, 0.35, 0.75)

@export var minion_scenes: Array[PackedScene] = []
@export var thorn_texture: Texture2D
@export var thorn_damage: int = 22
@export var root_damage: int = 28
@export var keep_distance: float = 120.0
@export var drift_time: float = 1.8
## 2페이즈 생명 흡수: 한 마리당 최대 체력의 이 비율만큼 회복
@export var drain_heal_ratio: float = 0.04

var _state: State = State.DRIFT
var _state_timer: float = 0.0
var _pattern_index: int = 0
var _phase_two: bool = false
var _minions: Array[Enemy] = []
var _shout: Label
var _base_sprite_pos: Vector2
var _orbit_sign: float = 1.0


func _ready() -> void:
	super._ready()
	is_boss = true
	_base_sprite_pos = sprite.position
	_state_timer = 1.2
	_shout = Label.new()
	_shout.add_theme_font_size_override(&"font_size", 10)
	_shout.add_theme_color_override(&"font_color", Color(0.75, 1.0, 0.6))
	_shout.add_theme_color_override(&"font_outline_color", Color(0.05, 0.15, 0.05))
	_shout.add_theme_constant_override(&"outline_size", 4)
	_shout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout.position = Vector2(-50, -62)
	_shout.size = Vector2(100, 14)
	_shout.z_index = 70
	_shout.modulate.a = 0.0
	add_child(_shout)


## 지금 지휘 중인 (살아 있는) 몬스터
func get_minions() -> Array[Enemy]:
	_prune_minions()
	return _minions


func register_minion(minion: Enemy) -> void:
	_minions.append(minion)


func _prune_minions() -> void:
	var alive: Array[Enemy] = []
	for minion in _minions:
		if is_instance_valid(minion) and not minion.is_dead():
			alive.append(minion)
	_minions = alive


func _process(_delta: float) -> void:
	queue_redraw()  # 덩굴은 졸개를 따라 매 프레임 다시 그림


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.DRIFT:
			if _state_timer <= 0.0:
				_start_next_pattern()
				return Vector2.ZERO
			# 플레이어와 거리를 두고 옆으로 떠다님
			var away := _player.global_position.direction_to(global_position)
			var target := _player.global_position + away.rotated(0.5 * _orbit_sign) * keep_distance
			return global_position.direction_to(target) * move_speed * (1.3 if _phase_two else 1.0)
		State.CASTING:
			if _state_timer <= 0.0:
				_state = State.DRIFT
				_state_timer = drift_time * (0.6 if _phase_two else 1.0)
				_orbit_sign = -_orbit_sign
			return Vector2.ZERO
	return Vector2.ZERO


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if not _phase_two and not is_dead() and float(hp) <= max_hp * 0.5:
		_phase_two = true
		GameManager.show_notice("드라이어드: 숲이 분노한다!", Color(0.6, 1.0, 0.45))
		Fx.explosion(self, get_hit_center(), Elements.color_of(Elements.Type.NATURE), 70.0, 3, Vector2(0, -40))
		_say("숲이여, 분노하라!")
		if _aura != null:
			_aura.amount = _aura.amount * 2


func _start_next_pattern() -> void:
	var pattern: Pattern = PATTERN_ORDER[_pattern_index % PATTERN_ORDER.size()]
	_pattern_index += 1
	var commands := pattern == Pattern.CHARGE or pattern == Pattern.SURROUND or pattern == Pattern.GUARD
	if commands and get_minions().is_empty():
		pattern = Pattern.SUMMON  # 지휘할 몬스터가 없으면 먼저 부름
	if pattern == Pattern.GUARD and not _phase_two:
		pattern = Pattern.CHARGE  # 호위·생명 흡수는 2페이즈 전용
	match pattern:
		Pattern.SUMMON:
			_summon()
			_cast(1.0)
		Pattern.CHARGE:
			command_charge()
			_cast(1.1)
		Pattern.SURROUND:
			command_surround()
			_cast(2.0)
		Pattern.THORNS:
			var waves := 4 if _phase_two else 3
			for w in waves:
				_after(0.3 * w, _fire_thorns.bind(w))
			_cast(0.3 * waves + 0.4)
		Pattern.ROOTS:
			_cast_roots()
			_cast(1.2)
		Pattern.GUARD:
			command_guard()
			_cast(2.4)


# ============================================================ 소환 / 지휘
func _summon() -> void:
	if minion_scenes.is_empty():
		return
	var room := MAX_MINIONS - get_minions().size()
	var count := mini(4 if _phase_two else 3, room)
	_say("숲의 아이들아, 깨어나라!")
	for i in count:
		var at := global_position + Vector2.RIGHT.rotated(TAU * i / maxi(count, 1) + randf() * 0.5) * 46.0
		Fx.burst(self, at, Elements.color_of(Elements.Type.NATURE), 14, 40.0, 0.6, Vector2(0, 60), 1.2)
		Fx.shockwave(self, at, Color(0.5, 0.85, 0.3), 16.0, 0.3)
		request_summon(minion_scenes.pick_random(), at)
	Fx.explosion(self, get_hit_center(), Elements.color_of(Elements.Type.NATURE), 36.0, 2, Vector2(0, -30))


## "돌격하라!" — 지휘 중인 몬스터 전부가 플레이어에게 일제히 돌격
func command_charge() -> void:
	_say(SHOUTS[Pattern.CHARGE])
	for minion in get_minions():
		minion.give_command(Command.CHARGE, Vector2.ZERO, Enemy.COMMAND_CHARGE_WINDUP + (0.75 if _phase_two else 0.6))
		_pulse_vine(minion)


## "포위하라!" — 플레이어를 둥글게 에워싼 뒤, 잠시 후 한꺼번에 덮침
func command_surround() -> void:
	_say(SHOUTS[Pattern.SURROUND])
	var minions := get_minions()
	if _player == null:
		return
	var center := _player.global_position
	var radius := 58.0
	for i in minions.size():
		var spot := center + Vector2.RIGHT.rotated(TAU * i / minions.size()) * radius
		if arena_rect.has_area():
			spot = spot.clamp(arena_rect.position, arena_rect.end)
		minions[i].give_command(Command.MOVE_TO, spot, 1.1)
		_pulse_vine(minions[i])
	_after(1.15, _close_in)


func _close_in() -> void:
	if is_dead():
		return
	for minion in get_minions():
		minion.give_command(Command.CHARGE, Vector2.ZERO, Enemy.COMMAND_CHARGE_WINDUP + 0.5)
		_pulse_vine(minion)


## "나를 지켜라!" — 곁으로 불러들여 호위. 2페이즈에서는 끝날 때 한 마리의 생명을 흡수
func command_guard() -> void:
	_say(SHOUTS[Pattern.GUARD])
	var minions := get_minions()
	for i in minions.size():
		var offset := Vector2.RIGHT.rotated(TAU * i / maxi(minions.size(), 1)) * 30.0
		minions[i].give_command(Command.GUARD, offset, 2.0)
		_pulse_vine(minions[i])
	if _phase_two:
		_after(2.0, _drain_minion)


## 가장 가까운 졸개의 생명을 흡수해 체력 회복
func _drain_minion() -> void:
	if is_dead():
		return
	var minions := get_minions()
	if minions.is_empty():
		return
	var nearest := minions[0]
	for minion in minions:
		if minion.global_position.distance_squared_to(global_position) < nearest.global_position.distance_squared_to(global_position):
			nearest = minion
	var heal := roundi(max_hp * drain_heal_ratio)
	Fx.burst(self, nearest.get_hit_center(), Color(0.6, 1.0, 0.5), 18, 40.0, 0.5, Vector2.ZERO, 1.2)
	Fx.flash(self, get_hit_center(), Color(0.6, 1.0, 0.5), 30.0, 0.4)
	nearest.despawn()
	hp = mini(hp + heal, max_hp)
	health_changed.emit(hp, max_hp)
	FloatingText.spawn(self, global_position + Vector2(0, -40), "+%d" % heal, Color(0.5, 1.0, 0.4))
	_say("생명을 바쳐라…")


# ============================================================ 공격
func _fire_thorns(wave: int) -> void:
	if is_dead() or not has_target():
		return
	var count := 7 if _phase_two else 5
	var spread := deg_to_rad(70.0)
	var base := direction_to_player().rotated((wave % 2) * spread / count * 0.5)
	for i in count:
		var t := float(i) / float(count - 1) - 0.5
		shoot(base.rotated(spread * t), 150.0, thorn_damage, thorn_texture, 0.0, Elements.Type.NATURE)


func _cast_roots() -> void:
	if _player == null:
		return
	_say("뿌리여, 붙잡아라!")
	var count := 6 if _phase_two else 4
	telegraph_strike(_player.global_position, 22.0, 0.85, root_damage, Elements.Type.NATURE, 1.2)
	for i in count - 1:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(28.0, 70.0)
		telegraph_strike(_player.global_position + offset, 20.0, randf_range(0.85, 1.2), root_damage, Elements.Type.NATURE, 1.2)


# ============================================================ 연출
func _say(text: String) -> void:
	_shout.text = text
	_shout.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_shout, "modulate:a", 0.0, 0.4)


func get_shout_text() -> String:
	return _shout.text if _shout.modulate.a > 0.0 else ""


func _pulse_vine(minion: Enemy) -> void:
	Fx.burst(self, minion.get_hit_center(), Color(0.6, 1.0, 0.45), 6, 30.0, 0.4, Vector2(0, -20))


func _cast(duration: float) -> void:
	_state = State.CASTING
	_state_timer = duration


func _after(seconds: float, callable: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(callable)


## 지휘 중인 몬스터들과 이어진 덩굴 (명령을 받는 중이면 밝게 빛남)
func _draw() -> void:
	if is_dead():
		return
	var from := to_local(get_hit_center())
	for minion in _minions:
		if not is_instance_valid(minion) or minion.is_dead() or not minion.is_inside_tree():
			continue
		var to := to_local(minion.get_hit_center())
		var active := minion.is_commanded()
		var color := Color(0.75, 1.0, 0.5, 0.95) if active else VINE_COLOR
		var mid := (from + to) * 0.5 + (to - from).orthogonal().normalized() * sin(_anim_time * 3.0 + minion.get_instance_id() % 7) * 6.0
		draw_polyline(PackedVector2Array([from, mid, to]), color, 2.0 if active else 1.0)
		draw_circle(mid, 1.5, Color(1.0, 0.7, 0.85, color.a))


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if _state == State.CASTING:
		sprite.position = _base_sprite_pos + Vector2(0.0, -3.0)
		sprite.modulate = Color(Color(1.0, 1.15, 0.9) if not _phase_two else Color(1.15, 1.2, 0.85), sprite.modulate.a)
	else:
		sprite.position = _base_sprite_pos + Vector2(0.0, -2.0 - sin(_anim_time * 2.5) * 2.0)
		sprite.modulate = Color(Color(1.0, 0.9, 0.85) if _phase_two else Color.WHITE, sprite.modulate.a)
