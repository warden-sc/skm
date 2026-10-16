class_name CasterEnemy
extends Enemy
## 마법을 쓰는 잡몹 공용 스크립트 (오크 주술사 / 하급 서큐버스 / 궁정 마술사).
## 거리를 두고 떠다니다가 손에 마력을 모은 뒤(예고) 시전합니다.
##   - bolt_count > 0   : 플레이어를 향해 탄을 부채꼴로 발사 (bolt_slow 가 있으면 맞으면 느려짐)
##   - strike_count > 0 : 플레이어 발밑에 예고 장판
##   둘 다 있으면 번갈아 사용합니다.

enum State { DRIFT, CHANNEL, RECOVER }

@export var element: Elements.Type = Elements.Type.ARCANE
@export var keep_distance: float = 110.0
@export var cast_interval: float = 2.4
@export var channel_time: float = 0.6

@export_group("Bolts")
@export var bolt_texture: Texture2D
@export var bolt_count: int = 3
@export var bolt_spread_degrees: float = 30.0
@export var bolt_damage: int = 20
@export var bolt_speed: float = 120.0
@export var bolt_slow: float = 0.0

@export_group("Strikes")
@export var strike_count: int = 0
@export var strike_damage: int = 26
@export var strike_radius: float = 22.0

var _state: State = State.DRIFT
var _state_timer: float = 0.0
var _orbit_sign: float = 1.0
var _casts: int = 0
var _glow: Sprite2D
var _base_sprite_y: float = 0.0


func _ready() -> void:
	super._ready()
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0
	_base_sprite_y = sprite.position.y
	_state_timer = randf_range(0.8, cast_interval)
	_glow = Sprite2D.new()
	_glow.texture = Fx.GLOW_TEXTURE
	_glow.material = Fx.additive_material()
	_glow.modulate = Elements.color_of(element)
	_glow.position = get_hit_center() - global_position + Vector2(0, -6)
	_glow.scale = Vector2.ZERO
	_glow.z_index = 3
	add_child(_glow)


func is_channeling() -> bool:
	return _state == State.CHANNEL


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.DRIFT:
			if _state_timer <= 0.0:
				_state = State.CHANNEL
				_state_timer = channel_time
				return Vector2.ZERO
			var away := _player.global_position.direction_to(global_position)
			var dist := distance_to_player()
			var radial := away * (1.0 if dist < keep_distance else -1.0) * (0.0 if absf(dist - keep_distance) < 15.0 else 1.0)
			return (radial + away.orthogonal() * _orbit_sign * 0.6).normalized() * move_speed
		State.CHANNEL:
			if _state_timer <= 0.0:
				_cast()
				_state = State.RECOVER
				_state_timer = 0.4
			return Vector2.ZERO
		State.RECOVER:
			if _state_timer <= 0.0:
				_state = State.DRIFT
				_state_timer = cast_interval
			return Vector2.ZERO
	return Vector2.ZERO


func _cast() -> void:
	_casts += 1
	var use_strike := strike_count > 0 and (bolt_count <= 0 or _casts % 2 == 0)
	if use_strike:
		telegraph_strike(_player.global_position, strike_radius, 0.8, strike_damage, element)
		for i in strike_count - 1:
			telegraph_strike(_player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(26.0, 60.0), strike_radius, randf_range(0.8, 1.1), strike_damage, element)
	else:
		var aim := direction_to_player()
		var spread := deg_to_rad(bolt_spread_degrees)
		for i in bolt_count:
			var t := 0.0 if bolt_count == 1 else float(i) / float(bolt_count - 1) - 0.5
			shoot(aim.rotated(spread * t), bolt_speed, bolt_damage, bolt_texture, bolt_slow, element)
	Fx.burst(self, _glow.global_position, Elements.color_of(element), 8, 40.0, 0.35)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	var target := 0.45 if _state == State.CHANNEL else 0.0
	_glow.scale = _glow.scale.lerp(Vector2.ONE * target, 1.0 - exp(-10.0 * delta))
	sprite.position.y = _base_sprite_y - sin(_anim_time * 3.0) * 1.5
