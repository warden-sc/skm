class_name BossSlimeKing
extends Enemy
## 스테이지 보스: 슬라임 킹
##
## 패턴 (순환):
##   1) CHASE   : 천천히 추적
##   2) RING    : 원형 탄막 발사 (2페이즈에서는 회전하며 여러 번)
##   3) SUMMON  : 슬라임 졸개 소환 (summon_requested 시그널 → StageManager 가 스폰)
##   4) SPEW    : [기믹] 점액 분출 — 점액 덩어리를 흩뿌려 바닥에 점액 웅덩이를 만듦.
##                웅덩이를 밟으면 이동 속도가 크게 느려짐 (대시로 건너면 영향 없음)
## 체력 50% 이하에서 2페이즈 (이동속도 / 탄막 강화, 쫓아다니며 지나간 자리에 점액을 흘림)

enum State { CHASE, RING, SUMMON, SPEW }

## 점액 웅덩이: 반경 / 지속 시간 / 밟았을 때 이동 속도 배율
const SLIME_POOL_RADIUS := 26.0
const SLIME_POOL_TIME := 7.0
const SLIME_POOL_SLOW := 0.45
const SPEW_TIME := 0.7

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
var _trail_timer: float = 0.0


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
			if _phase_two:
				_trail_timer -= delta
				if _trail_timer <= 0.0:
					_trail_timer = 1.6
					GroundZone.spawn_hostile(self, global_position, GroundZone.Kind.SLIME, SLIME_POOL_RADIUS * 0.8, SLIME_POOL_TIME * 0.6, SLIME_POOL_SLOW)
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
		State.SPEW:
			if _state_timer <= 0.0:
				spew_slime()
				_enter(State.CHASE, chase_time)
			return Vector2.ZERO
	return Vector2.ZERO


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if not _phase_two and not is_dead() and float(hp) <= max_hp * 0.5:
		_phase_two = true
		GameManager.show_notice("슬라임 킹이 분노했다!", Color(1.0, 0.4, 0.6))


func _next_pattern() -> void:
	_pattern_index += 1
	if _pattern_index % 3 == 0 and minion_scene != null:
		_enter(State.SUMMON, 0.6)
	elif _pattern_index % 3 == 2:
		_enter(State.SPEW, SPEW_TIME)
	else:
		_ring_shots_left = 3 if _phase_two else 1
		_ring_angle_offset = randf() * TAU
		_enter(State.RING, 0.5)


func _enter(state: State, duration: float) -> void:
	_state = state
	_state_timer = duration


func _fire_ring() -> void:
	var count := ring_bullet_count + (6 if _phase_two else 0)
	var origin := global_position + Vector2(0, -12)
	for i in count:
		var dir := Vector2.RIGHT.rotated(_ring_angle_offset + TAU * float(i) / float(count))
		shoot(dir, bullet_speed, bullet_damage, bullet_texture, 0.0, Elements.Type.NONE, origin)
	_ring_angle_offset += PI / float(count)
	if _player != null:
		_player.shake_camera(2.0)


## [기믹] 점액 분출: 점액 덩어리가 포물선을 그리며 날아가 떨어진 자리에 점액 웅덩이를 만듦.
## 첫 덩어리는 플레이어 발밑, 나머지는 주변에 흩어짐.
func spew_slime() -> void:
	if not has_target():
		return
	var count := 7 if _phase_two else 5
	GameManager.show_notice("슬라임 킹이 점액을 뿜어낸다! (밟으면 느려짐)", Color(0.6, 1.0, 0.5))
	for i in count:
		var target := _player.global_position
		if i > 0:
			target += Vector2.from_angle(randf() * TAU) * randf_range(40.0, 110.0)
		if arena_rect.has_area():
			target = target.clamp(arena_rect.position, arena_rect.end)
		_lob_glob(target, 0.55 + 0.08 * i)
	Fx.burst(self, get_hit_center(), Color(0.5, 0.95, 0.4), 16, 60.0, 0.5, Vector2(0, 120), 1.4)


## 점액 덩어리 한 개를 포물선으로 던짐 → 떨어지면 점액 웅덩이
func _lob_glob(target: Vector2, flight_time: float) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var glob := Sprite2D.new()
	glob.texture = bullet_texture
	glob.modulate = Color(0.5, 1.0, 0.4)
	glob.scale = Vector2.ONE * 1.8
	glob.z_index = 40
	root.add_child(glob)
	var start := get_hit_center()
	glob.global_position = start
	var tween := glob.create_tween()
	tween.tween_method(func(t: float) -> void:
		glob.global_position = start.lerp(target, t) + Vector2(0, -70.0 * sin(PI * t)), 0.0, 1.0, flight_time)
	tween.tween_callback(func() -> void:
		Fx.slime_splash(glob, target, SLIME_POOL_RADIUS * 0.8, 1)
		GroundZone.spawn_hostile(glob, target, GroundZone.Kind.SLIME, SLIME_POOL_RADIUS, SLIME_POOL_TIME, SLIME_POOL_SLOW)
		glob.queue_free())


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
		State.SPEW:
			var t := clampf(1.0 - _state_timer / SPEW_TIME, 0.0, 1.0)
			sprite.scale = Vector2(1.0 - 0.15 * t, 1.0 + 0.25 * t)
		_:
			var squash := 1.0 + sin(_anim_time * 4.0) * 0.05
			sprite.scale = Vector2(squash, 2.0 - squash)
	sprite.modulate = Color(1.0, 0.75, 0.8, sprite.modulate.a) if _phase_two else Color(1, 1, 1, sprite.modulate.a)
