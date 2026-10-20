class_name BossDullahan
extends Enemy
## 5스테이지 보스: 기사단장 듀라한 — 주인 없는 빈 옥좌를 지키는 머리 없는 흑기사.
## 옥좌의 주인은 왕국을 잃고 떠난 왕(10스테이지 보스 「옥좌 잃은 왕」)이며, 듀라한은 왕이 돌아올 날을 기다리며 옥좌를 지킨다.
##
## 패턴 (순환):
##   SLASH  : 대검을 치켜든 뒤 앞쪽 부채꼴을 크게 베어냄 (예고 장판 3개)
##   WAVE   : 암흑 검기를 부채꼴로 날림
##   CHARGE : 어둠을 두르고 플레이어에게 돌진
##   SUMMON : 옥좌의 기사들을 불러냄 (기사 / 2페이즈는 중기사)
##   HEAD   : [기믹] 머리 던지기
##
## [기믹] 약점은 「머리」
##   1) 듀라한이 옆구리에 낀 머리를 던짐 → 머리가 플레이어 주위를 떠다니며 암흑탄을 쏨
##   2) 머리가 없는 동안 몸은 「머리 없는 분노」: 방어력이 크게 올라 거의 피해가 들어가지 않음
##   3) 머리를 쓰러뜨리면 → 몸이 무릎을 꿇음(기절) + 「약점 노출」: 방어력 0, 받는 피해 1.5배 (몇 초간)
##   4) 머리를 head_time 안에 못 쓰러뜨리면 → 머리가 몸으로 돌아가 듀라한이 체력을 회복
## 체력 50% 이하: 머리를 더 자주 던지고, 중기사를 부르며, 검기 수 증가

enum State { STALK, SLASH_WINDUP, CHARGE_WINDUP, CHARGE, CASTING, KNEEL }
enum Pattern { SLASH, WAVE, HEAD, CHARGE, SUMMON }

const PATTERN_ORDER := [Pattern.SLASH, Pattern.WAVE, Pattern.HEAD, Pattern.CHARGE, Pattern.SLASH, Pattern.SUMMON, Pattern.WAVE, Pattern.HEAD]
const HEADLESS_DEFENSE_BONUS := 40
const EXPOSED_DAMAGE_MULTIPLIER := 1.5

@export var headless_texture: Texture2D
@export var head_scene: PackedScene
@export var knight_scene: PackedScene
@export var heavy_knight_scene: PackedScene
@export var wave_texture: Texture2D
@export var slash_damage: int = 34
@export var wave_damage: int = 24
@export var stalk_time: float = 1.8
## 던진 머리가 돌아오기까지의 시간
@export var head_time: float = 12.0
## 머리를 쓰러뜨렸을 때 무릎 꿇는(약점 노출) 시간
@export var kneel_time: float = 4.5
## 머리를 이만큼 최대 체력 비율로 만듦
@export var head_hp_ratio: float = 0.06
## 머리가 무사히 돌아오면 회복하는 비율
@export var head_return_heal: float = 0.05

var _state: State = State.STALK
var _state_timer: float = 0.0
var _pattern_index: int = 0
var _phase_two: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _head: Enemy
var _head_left: float = 0.0
var _base_defense: int = 0
var _with_head_texture: Texture2D
var _base_sprite_pos: Vector2
var _label: Label


func _ready() -> void:
	super._ready()
	is_boss = true
	_base_defense = defense
	_with_head_texture = sprite.texture
	_base_sprite_pos = sprite.position
	_state_timer = stalk_time
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 9)
	_label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.02, 0.08))
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-70, -66)
	_label.size = Vector2(140, 12)
	_label.z_index = 70
	add_child(_label)


func has_head() -> bool:
	return _head == null


func is_headless() -> bool:
	return _head != null


func is_exposed() -> bool:
	return _state == State.KNEEL


func get_thrown_head() -> Enemy:
	return _head if _head != null and is_instance_valid(_head) else null


func get_status_text() -> String:
	return _label.text


func _get_move_velocity(delta: float) -> Vector2:
	_update_head(delta)
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.STALK:
			if _state_timer <= 0.0:
				_start_next_pattern()
				return Vector2.ZERO
			var speed := move_speed * (1.3 if _phase_two else 1.0)
			if is_headless():
				# 머리 없는 분노: 앞이 보이지 않아 비틀거리며 휘젓고 다님
				return global_position.direction_to(_player.global_position).rotated(sin(_anim_time * 2.3) * 1.1) * speed * 1.2
			return global_position.direction_to(_player.global_position) * speed
		State.SLASH_WINDUP:
			if _state_timer <= 0.0:
				_enter(State.CASTING, 0.5)
				if _player != null:
					_player.shake_camera(3.5)
			return Vector2.ZERO
		State.CHARGE_WINDUP:
			if _state_timer <= 0.0:
				_enter(State.CHARGE, 0.5)
				_charge_dir = direction_to_player()
			return Vector2.ZERO
		State.CHARGE:
			Fx.burst(self, get_hit_center() + Vector2(0, 10), Elements.color_of(Elements.Type.DARK), 3, 25.0, 0.5, Vector2(0, -30))
			if _state_timer <= 0.0:
				_enter(State.CASTING, 0.6)
			return _charge_dir * move_speed * 5.5
		State.CASTING:
			if _state_timer <= 0.0:
				_enter(State.STALK, stalk_time * (0.7 if _phase_two else 1.0))
			return Vector2.ZERO
		State.KNEEL:
			if _state_timer <= 0.0:
				_recover_head()
				_enter(State.STALK, stalk_time)
			return Vector2.ZERO
	return Vector2.ZERO


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_exposed():
		amount = roundi(amount * EXPOSED_DAMAGE_MULTIPLIER)
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if is_dead():
		Net.announce("듀라한: 폐하… 옥좌를… 지키지 못했습니다…", Color(0.8, 0.6, 1.0))
		return
	if not _phase_two and not is_dead() and float(hp) <= max_hp * 0.5:
		_phase_two = true
		Net.announce("기사단장 듀라한: 폐하께서 돌아오실 때까지… 이 옥좌는 내가 지킨다!", Color(0.8, 0.5, 1.0))
		Fx.explosion(self, get_hit_center(), Elements.color_of(Elements.Type.DARK), 70.0, 3, Vector2(0, -30))


func _start_next_pattern() -> void:
	var pattern: Pattern = PATTERN_ORDER[_pattern_index % PATTERN_ORDER.size()]
	_pattern_index += 1
	if pattern == Pattern.HEAD and is_headless():
		pattern = Pattern.WAVE
	if _phase_two and pattern == Pattern.CHARGE and not is_headless():
		pattern = Pattern.HEAD  # 2페이즈: 머리를 더 자주 던짐
	match pattern:
		Pattern.SLASH:
			_slash()
		Pattern.WAVE:
			_wave()
			_enter(State.CASTING, 0.9)
		Pattern.HEAD:
			throw_head()
			_enter(State.CASTING, 0.8)
		Pattern.CHARGE:
			_enter(State.CHARGE_WINDUP, 0.7)
		Pattern.SUMMON:
			_summon_knights()
			_enter(State.CASTING, 0.9)


# ============================================================ 기믹: 머리
## 머리를 던짐 → 머리가 떠다니며 공격, 그동안 몸은 방어력이 크게 오름
func throw_head() -> void:
	if is_headless() or head_scene == null:
		return
	Net.announce("듀라한이 머리를 던졌다! 약점은 머리 — 머리를 쓰러뜨려라!", Color(0.85, 0.6, 1.0))
	request_summon(head_scene, get_hit_center() + Vector2(0, -10))
	Fx.explosion(self, get_hit_center(), Elements.color_of(Elements.Type.DARK), 30.0, 2, Vector2(0, -30))


func register_minion(minion: Enemy) -> void:
	if minion is DullahanHead and _head == null:
		_head = minion
		minion.max_hp = maxi(1, roundi(max_hp * head_hp_ratio))
		minion.died.connect(_on_head_died)
		_head_left = head_time
		defense = _base_defense + HEADLESS_DEFENSE_BONUS
		sprite.texture = headless_texture
		_label.text = "머리 없는 분노: 방어력 +%d" % Balance.scale(HEADLESS_DEFENSE_BONUS)
		_label.add_theme_color_override(&"font_color", Color(0.85, 0.55, 1.0))


func _update_head(delta: float) -> void:
	if _head == null:
		return
	if not is_instance_valid(_head):
		_head = null
		return
	if _head.is_dead():
		return
	_head_left -= delta
	if _head_left <= 0.0:
		_head_returns()


## 머리를 시간 안에 못 쓰러뜨림 → 몸으로 돌아가 회복
func _head_returns() -> void:
	var head := _head
	_head = null
	if is_instance_valid(head):
		Fx.burst(self, head.get_hit_center(), Elements.color_of(Elements.Type.DARK), 12, 40.0, 0.4)
		head.despawn()
	var heal := roundi(max_hp * head_return_heal)
	hp = mini(hp + heal, max_hp)
	health_changed.emit(hp, max_hp)
	FloatingText.spawn(self, global_position + Vector2(0, -44), "+%d" % heal, Color(0.7, 0.5, 1.0))
	Net.announce("머리가 몸으로 돌아갔다… 듀라한이 회복한다", Color(0.8, 0.6, 1.0))
	_recover_head()


## 머리를 쓰러뜨림 → 무릎 꿇음 + 약점 노출
func _on_head_died(_enemy: Enemy) -> void:
	_head = null
	if is_dead():
		return
	_enter(State.KNEEL, kneel_time)
	defense = 0
	_label.text = "약점 노출! 받는 피해 x%.1f" % EXPOSED_DAMAGE_MULTIPLIER
	_label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	Net.announce("듀라한이 무릎을 꿇었다! 지금이 기회!", Color(1.0, 0.85, 0.4))
	Fx.explosion(self, get_hit_center(), Color(1.0, 0.85, 0.5), 50.0, 3)
	if _player != null:
		_player.shake_camera(4.0)


func _recover_head() -> void:
	defense = _base_defense
	sprite.texture = _with_head_texture
	_label.text = ""


# ============================================================ 공격
func _slash() -> void:
	_enter(State.SLASH_WINDUP, 0.75)
	var dir := direction_to_player()
	for a in [-0.6, 0.0, 0.6]:
		telegraph_strike(get_hit_center() + dir.rotated(a) * 34.0, 26.0, 0.75, slash_damage, Elements.Type.DARK)


func _wave() -> void:
	var count := 7 if _phase_two else 5
	var aim := direction_to_player()
	for i in count:
		var t := float(i) / float(count - 1) - 0.5
		shoot(aim.rotated(t * 1.1), 150.0, wave_damage, wave_texture, 0.0, Elements.Type.DARK)


func _summon_knights() -> void:
	var scene := heavy_knight_scene if _phase_two and heavy_knight_scene != null else knight_scene
	if scene == null:
		return
	for i in 2:
		request_summon(scene, global_position + Vector2(-40.0 + 80.0 * i, 20.0))
	Fx.explosion(self, get_hit_center(), Elements.color_of(Elements.Type.DARK), 36.0, 2, Vector2(0, -30))


func _enter(state: State, duration: float) -> void:
	_state = state
	_state_timer = duration


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	match _state:
		State.SLASH_WINDUP, State.CHARGE_WINDUP:
			sprite.position = _base_sprite_pos + Vector2(randf_range(-1.0, 1.0), -2.0)
		State.KNEEL:
			sprite.position = _base_sprite_pos + Vector2(0.0, 5.0)
		_:
			sprite.position = _base_sprite_pos + Vector2(0.0, -absf(sin(_anim_time * 4.0)) * 1.5)
	if is_exposed():
		sprite.modulate = Color(1.3, 1.2, 0.8, sprite.modulate.a)
	elif is_headless():
		sprite.modulate = Color(1.0, 0.8, 1.25, sprite.modulate.a)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, sprite.modulate.a)
