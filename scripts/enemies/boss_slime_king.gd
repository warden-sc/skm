class_name BossSlimeKing
extends Enemy
## 스테이지 보스: 슬라임 킹
##
## 패턴 (순환):
##   1) CHASE   : 천천히 추적
##   2) RING    : 원형 탄막 발사 (2페이즈에서는 회전하며 여러 번)
##   3) SUMMON  : 슬라임 졸개 소환 (summon_requested 시그널 → StageManager 가 스폰)
## 체력 50% 이하에서 2페이즈 (이동속도 / 탄막 강화)

enum State { CHASE, RING, SUMMON }

@export var bullet_texture: Texture2D
@export var bullet_speed: float = 110.0
@export var bullet_damage: int = 12
@export var ring_bullet_count: int = 14
@export var minion_scene: PackedScene
@export var minions_per_summon: int = 3
@export var chase_time: float = 2.4

var _state: State = State.CHASE
var _state_timer: float = 0.0
var _pattern_index: int = 0
var _ring_shots_left: int = 0
var _ring_angle_offset: float = 0.0
var _phase_two: bool = false


func _ready() -> void:
	super._ready()
	is_boss = true
	_state_timer = chase_time


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta

	match _state:
		State.CHASE:
			if _state_timer <= 0.0:
				_next_pattern()
			var speed := move_speed * (1.5 if _phase_two else 1.0)
			return global_position.direction_to(_player.global_position) * speed
		State.RING:
			if _state_timer <= 0.0:
				_fire_ring()
				_ring_shots_left -= 1
				if _ring_shots_left <= 0:
					_enter(State.CHASE, chase_time)
				else:
					_state_timer = 0.35
			return Vector2.ZERO
		State.SUMMON:
			if _state_timer <= 0.0:
				_summon()
				_enter(State.CHASE, chase_time)
			return Vector2.ZERO
	return Vector2.ZERO


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	super.take_damage(amount, knockback, is_crit)
	if not _phase_two and not is_dead() and float(hp) <= max_hp * 0.5:
		_phase_two = true
		GameManager.show_notice("슬라임 킹이 분노했다!", Color(1.0, 0.4, 0.6))


func _next_pattern() -> void:
	_pattern_index += 1
	if _pattern_index % 3 == 0 and minion_scene != null:
		_enter(State.SUMMON, 0.6)
	else:
		_ring_shots_left = 3 if _phase_two else 1
		_ring_angle_offset = randf() * TAU
		_enter(State.RING, 0.5)


func _enter(state: State, duration: float) -> void:
	_state = state
	_state_timer = duration


func _fire_ring() -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var count := ring_bullet_count + (6 if _phase_two else 0)
	var origin := global_position + Vector2(0, -12)
	for i in count:
		var dir := Vector2.RIGHT.rotated(_ring_angle_offset + TAU * float(i) / float(count))
		pool.spawn(ProjectileSpec.enemy_bullet(origin, dir, bullet_speed, bullet_damage, bullet_texture))
	_ring_angle_offset += PI / float(count)
	if _player != null:
		_player.shake_camera(2.0)


func _summon() -> void:
	for i in minions_per_summon:
		var offset := Vector2.RIGHT.rotated(TAU * float(i) / float(minions_per_summon)) * 36.0
		request_summon(minion_scene, global_position + offset)


func _update_visual(_delta: float, _move: Vector2) -> void:
	match _state:
		State.RING:
			# 탄막 직전 부풀어오름
			var t := clampf(1.0 - _state_timer / 0.5, 0.0, 1.0)
			sprite.scale = Vector2.ONE * (1.0 + t * 0.15)
		State.SUMMON:
			sprite.scale = Vector2(1.0 + sin(_anim_time * 30.0) * 0.05, 1.0)
		_:
			var squash := 1.0 + sin(_anim_time * 4.0) * 0.05
			sprite.scale = Vector2(squash, 2.0 - squash)
	sprite.modulate = Color(1.0, 0.75, 0.8, sprite.modulate.a) if _phase_two else Color(1, 1, 1, sprite.modulate.a)
