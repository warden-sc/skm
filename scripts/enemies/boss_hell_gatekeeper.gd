class_name BossHellGatekeeper
extends Enemy
## 2스테이지 보스: 지옥의 수문장 — 업화를 두른 거대한 오크 킹.
##
## 패턴 (순환):
##   CHARGE  : 몸을 떨며 힘을 모은 뒤 플레이어 쪽으로 돌진 (지나간 자리에 불꽃)
##   RING    : 화염구 고리를 여러 겹 발사
##   PILLARS : 플레이어 주변에 예고 후 솟아오르는 화염 기둥
##   SUMMON  : 헬하운드 소환
## 체력 50% 이하: 업화 각성 — 이동/돌진 강화, 탄막·기둥 수 증가, 오라 강화
##
## [기믹] 화상: 수문장의 모든 불 공격(몸통·화염구·화염 기둥)에 맞으면 화상 (지속 피해).
##   화상 피해는 방어력이 높을수록 줄어들고, 펜던트의 체력 재생으로 버틸 수 있습니다.
##   화염 기둥이 솟은 자리는 잠시 불바다가 되어, 밟으면 화상을 입습니다.

enum State { CHASE, CHARGE_WINDUP, CHARGE, RECOVER, CASTING }
enum Pattern { CHARGE, RING, PILLARS, SUMMON }

const PATTERN_ORDER := [Pattern.CHARGE, Pattern.RING, Pattern.SUMMON, Pattern.PILLARS, Pattern.CHARGE, Pattern.RING, Pattern.PILLARS]

@export var fireball_texture: Texture2D
@export var fireball_damage: int = 16
@export var pillar_damage: int = 22
@export var charge_speed_multiplier: float = 5.0
@export var minion_scene: PackedScene
@export var chase_time: float = 2.0
## 화염 기둥이 남기는 불바다 지속 시간
@export var fire_floor_time: float = 3.0

var _state: State = State.CHASE
var _state_timer: float = 0.0
var _pattern_index: int = 0
var _charge_dir: Vector2 = Vector2.ZERO
var _trail_timer: float = 0.0
var _phase_two: bool = false
var _base_sprite_pos: Vector2


func _ready() -> void:
	super._ready()
	is_boss = true
	_base_sprite_pos = sprite.position
	_state_timer = chase_time


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.CHASE:
			if _state_timer <= 0.0:
				_start_next_pattern()
				return Vector2.ZERO
			return global_position.direction_to(_player.global_position) * move_speed * (1.4 if _phase_two else 1.0)
		State.CHARGE_WINDUP:
			if _state_timer <= 0.0:
				_state = State.CHARGE
				_state_timer = 0.55
				_charge_dir = direction_to_player()
			return Vector2.ZERO
		State.CHARGE:
			_trail_timer -= delta
			if _trail_timer <= 0.0:
				_trail_timer = 0.06
				Fx.burst(self, get_hit_center() + Vector2(0, 8), Elements.color_of(Elements.Type.FIRE), 5, 30.0, 0.5, Vector2(0, -80))
			if _state_timer <= 0.0:
				_enter(State.RECOVER, 0.7)
				if _player != null:
					_player.shake_camera(4.0)
			return _charge_dir * move_speed * charge_speed_multiplier * (1.25 if _phase_two else 1.0)
		State.RECOVER, State.CASTING:
			if _state_timer <= 0.0:
				_enter(State.CHASE, chase_time * (0.7 if _phase_two else 1.0))
			return Vector2.ZERO
	return Vector2.ZERO


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if not _phase_two and not is_dead() and float(hp) <= max_hp * 0.5:
		_phase_two = true
		GameManager.show_notice("지옥의 수문장이 업화를 두른다!", Color(1.0, 0.45, 0.2))
		Fx.explosion(self, get_hit_center(), Elements.color_of(Elements.Type.FIRE), 60.0, 3, Vector2(0, -80))
		if _aura != null:
			_aura.amount = _aura.amount * 2


func _start_next_pattern() -> void:
	var pattern: Pattern = PATTERN_ORDER[_pattern_index % PATTERN_ORDER.size()]
	_pattern_index += 1
	match pattern:
		Pattern.CHARGE:
			_enter(State.CHARGE_WINDUP, 0.7)
		Pattern.RING:
			var waves := 3 if _phase_two else 2
			for w in waves:
				_after(0.35 * w, _fire_ring.bind(w))
			_enter(State.CASTING, 0.35 * waves + 0.4)
		Pattern.PILLARS:
			_cast_pillars()
			_enter(State.CASTING, 1.2)
		Pattern.SUMMON:
			var count := 3 if _phase_two else 2
			for i in count:
				request_summon(minion_scene, global_position + Vector2.RIGHT.rotated(TAU * i / count) * 40.0)
			Fx.explosion(self, get_hit_center(), Elements.color_of(Elements.Type.FIRE), 40.0, 2, Vector2(0, -80))
			_enter(State.CASTING, 0.8)


func _fire_ring(wave: int) -> void:
	if is_dead():
		return
	var count := 20 if _phase_two else 16
	var offset := wave * PI / count
	for i in count:
		shoot(Vector2.RIGHT.rotated(offset + TAU * i / count), 115.0, fireball_damage, fireball_texture, 0.0, Elements.Type.FIRE)
	if _player != null:
		_player.shake_camera(2.0)


func _cast_pillars() -> void:
	if _player == null:
		return
	var count := 8 if _phase_two else 5
	telegraph_strike(_player.global_position, 22.0, 0.9, pillar_damage, Elements.Type.FIRE)
	_after(0.9, _spawn_fire_floor.bind(_player.global_position, 22.0))
	for i in count - 1:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(25.0, 75.0)
		var delay := randf_range(0.9, 1.3)
		telegraph_strike(_player.global_position + offset, 20.0, delay, pillar_damage, Elements.Type.FIRE)
		_after(delay, _spawn_fire_floor.bind(_player.global_position + offset, 20.0))


## 화염 기둥이 솟은 자리에 불바다 (밟으면 화상)
func _spawn_fire_floor(at: Vector2, radius: float) -> void:
	if is_dead():
		return
	GroundZone.spawn_hostile(self, at, GroundZone.Kind.FIRE, radius, fire_floor_time, 1.0, burn_damage, burn_duration)


func _enter(state: State, duration: float) -> void:
	_state = state
	_state_timer = duration


## seconds 뒤에 callable 실행 (보스가 사라지면 함께 취소되도록 자기 트윈 사용)
func _after(seconds: float, callable: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(callable)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	match _state:
		State.CHARGE_WINDUP:
			sprite.position = _base_sprite_pos + Vector2(randf_range(-1.5, 1.5), 0.0)
			sprite.modulate = Color(1.0, 0.6, 0.5, sprite.modulate.a)
		_:
			sprite.position = _base_sprite_pos + Vector2(0.0, -absf(sin(_anim_time * 5.0)) * 1.5)
			var tint := Color(1.0, 0.8, 0.7) if _phase_two else Color.WHITE
			sprite.modulate = Color(tint, sprite.modulate.a)
