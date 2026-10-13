class_name Golem
extends Enemy
## 속성 골렘 (3스테이지). element 에 따라 공격 패턴이 다릅니다.
##   FIRE      : 화염구 3발 부채꼴
##   ICE       : 얼음 파편 5발 (맞으면 감속)
##   LIGHTNING : 플레이어 위치 + 주변에 예고 낙뢰
##   EARTH     : 근접해서 대지 강타(자기 주변 장판) 후 돌 파편 고리
## 씬에서 aura_element 와 element 를 같은 값으로 맞춰 주세요.

enum State { CHASE, WINDUP, RECOVER }

@export var element: Elements.Type = Elements.Type.EARTH
@export var attack_damage: int = 18
@export var attack_interval: float = 2.6
@export var preferred_range: float = 90.0
@export var projectile_texture: Texture2D

var _state: State = State.CHASE
var _state_timer: float = 0.0
var _base_sprite_y: float = 0.0


func _ready() -> void:
	super._ready()
	_base_sprite_y = sprite.position.y
	_state_timer = randf_range(1.0, attack_interval)


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.CHASE:
			var dist := distance_to_player()
			var ready_to_attack := _state_timer <= 0.0 and dist <= preferred_range * 1.6
			if element == Elements.Type.EARTH:
				ready_to_attack = _state_timer <= 0.0 and dist <= preferred_range
			if ready_to_attack:
				_begin_attack()
				return Vector2.ZERO
			if dist > preferred_range * 0.8 or element == Elements.Type.EARTH:
				return global_position.direction_to(_player.global_position) * move_speed
			return Vector2.ZERO
		State.WINDUP:
			if _state_timer <= 0.0:
				_release_attack()
				_state = State.RECOVER
				_state_timer = 0.7
			return Vector2.ZERO
		State.RECOVER:
			if _state_timer <= 0.0:
				_state = State.CHASE
				_state_timer = attack_interval
			return Vector2.ZERO
	return Vector2.ZERO


func _begin_attack() -> void:
	_state = State.WINDUP
	_state_timer = 0.6
	if element == Elements.Type.EARTH:
		# 대지 강타는 장판 예고 자체가 준비 동작
		telegraph_strike(global_position, 42.0, 0.6, attack_damage, Elements.Type.EARTH)
	elif element == Elements.Type.LIGHTNING and _player != null:
		telegraph_strike(_player.global_position, 20.0, 0.8, attack_damage, Elements.Type.LIGHTNING)
		for i in 2:
			telegraph_strike(_player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 50.0), 18.0, 1.0, attack_damage, Elements.Type.LIGHTNING)


func _release_attack() -> void:
	var dir := direction_to_player()
	var color := Elements.color_of(element)
	Fx.flash(self, get_hit_center(), color, 18.0, 0.2)
	match element:
		Elements.Type.FIRE:
			for i in 3:
				shoot(dir.rotated(deg_to_rad(-12.0 + 12.0 * i)), 130.0, attack_damage, projectile_texture, 0.0, element)
		Elements.Type.ICE:
			for i in 5:
				shoot(dir.rotated(deg_to_rad(-24.0 + 12.0 * i)), 150.0, attack_damage - 4, projectile_texture, 1.5, element)
		Elements.Type.EARTH:
			for i in 8:
				shoot(Vector2.RIGHT.rotated(TAU * i / 8.0), 110.0, attack_damage - 6, projectile_texture, 0.0, element)
			if _player != null:
				_player.shake_camera(3.0)
		_:
			pass  # 낙뢰는 _begin_attack 에서 이미 예고됨


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if _state == State.WINDUP:
		var t := 1.0 - _state_timer / 0.6
		sprite.scale = Vector2.ONE * 1.2 * (1.0 + 0.08 * t)
		sprite.position.y = _base_sprite_y + randf_range(-0.5, 0.5)
	else:
		sprite.scale = Vector2.ONE * 1.2
		sprite.position.y = _base_sprite_y - absf(sin(_anim_time * 4.0)) * 1.0
