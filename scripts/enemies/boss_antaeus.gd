class_name BossAntaeus
extends PatternBoss
## 45스테이지 보스: 대지의 거인 안타이오스 — 땅에 닿아 있는 한 결코 지치지 않는 리비아의 레슬러 거인.
##   GRAB   : 붙잡기 — 플레이어 발밑 예고, 그 자리에 있으면 붙잡혀 묶임 + 피해
##   QUAKE  : 땅 울림 — 플레이어 주변 장판
##   SAND   : 모래 뿌리기 — 모래 탄 부채꼴 (맞으면 감속)
##   SUMMON : 리비아 투사 · 사막 하이에나 호출
##
## [기믹 1] 대지의 힘: 땅에 닿아 있는 동안 방어력 +ground_armor, 초당 최대 체력의 ground_regen 회복,
##   ground_stack_time 초마다 공격력 +10% (최대 +50%)
## [기믹 2] 상승 기류 발판: 보스방의 발판으로 유인해 안타이오스가 밟으면 lift_time 초 동안 공중으로 떠오름
##   → 대지의 힘이 끊겨 회복·방어력 보너스가 사라지고, 쌓인 공격력이 초기화, 받는 피해 lift_multiplier 배, 공격하지 못함
## 체력 50% 이하: 땅의 힘이 더 빨리 쌓임

enum Pattern { GRAB, QUAKE, SAND, SUMMON }

const LIFT_HEIGHT := 40.0

@export var minion_scenes: Array[PackedScene] = []
@export var sand_texture: Texture2D
@export var grab_damage: int = 80
@export var quake_damage: int = 78
@export var sand_damage: int = 50
@export var ground_armor: int = 30
@export var ground_regen: float = 0.003
@export var ground_stack_time: float = 10.0
@export var lift_time: float = 5.0
@export var lift_multiplier: float = 1.5

var pads: Array[UpdraftPad] = []
var stacks: int = 0
var _lift_left: float = 0.0
var _lifts: int = 0
var _stack_timer: float = 0.0
var _regen_carry: float = 0.0
var _base_defense: int = 0
var _base_power: float = 1.0
var _height: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.GRAB, Pattern.SAND, Pattern.QUAKE, Pattern.GRAB, Pattern.SUMMON]
	_base_defense = defense
	defense = _base_defense + ground_armor


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func is_lifted() -> bool:
	return _lift_left > 0.0


func get_lift_count() -> int:
	return _lifts


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
		var c := area.get_center()
		# 등장 자리(위쪽 가운데)와 겹치지 않게 양옆과 아래쪽에
		for v in [Vector2(-0.34, 0.05), Vector2(0.34, 0.05), Vector2(0.0, 0.33)]:
			var off: Vector2 = v
			pads.append(UpdraftPad.spawn(self, c + Vector2(off.x * area.size.x, off.y * area.size.y)))
	if is_lifted():
		return Vector2.ZERO
	# 대지의 힘
	if hp < max_hp:
		_regen_carry += max_hp * ground_regen * delta
		if _regen_carry >= 1.0:
			var amount := mini(int(_regen_carry), max_hp - hp)
			_regen_carry -= int(_regen_carry)
			hp += amount
			health_changed.emit(hp, max_hp)
	_stack_timer += delta * (1.4 if phase_two else 1.0)
	if _stack_timer >= ground_stack_time and stacks < 5:
		_stack_timer = 0.0
		stacks += 1
		power = _base_power * (1.0 + 0.1 * stacks)
		FloatingText.spawn(self, global_position + Vector2(0, -60), "대지의 힘 +%d%%" % (stacks * 10), Color(0.9, 0.75, 0.45), true)
	set_status("대지의 힘: 회복 · 방어력 +%d · 공격력 +%d%%" % [Balance.scale(ground_armor), stacks * 10], Color(0.9, 0.75, 0.45))
	for pad in pads:
		if is_instance_valid(pad) and pad.is_ready() and pad.contains(global_position):
			lift(pad)
			return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹 2: 상승 기류
func lift(pad: UpdraftPad = null) -> void:
	if is_lifted() or is_dead():
		return
	_lifts += 1
	_lift_left = lift_time
	if pad != null:
		pad.use()
	defense = _base_defense
	stacks = 0
	_stack_timer = 0.0
	power = _base_power
	_bstate = BossState.CHASE
	_btimer = chase_time
	set_status("공중에 떴다! 대지의 힘이 끊겼다", Color(0.8, 1.0, 0.95))
	Net.announce("안타이오스가 상승 기류에 떠올랐다! 땅의 힘이 끊긴 지금 몰아쳐라", Color(0.8, 1.0, 0.95))


func _physics_process(delta: float) -> void:
	if _lift_left > 0.0 and not is_dead():
		_lift_left -= delta
		if _lift_left <= 0.0:
			defense = _base_defense + ground_armor
			if _player != null:
				_player.shake_camera(6.0)
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 46.0, 20.0, 0.5, quake_damage, Elements.Type.EARTH)
	super._physics_process(delta)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_lifted():
		amount = roundi(amount * lift_multiplier)
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	_height = move_toward(_height, LIFT_HEIGHT if is_lifted() else 0.0, delta * 140.0)
	sprite.position.y = _base_sprite_pos.y - _height
	if is_lifted():
		sprite.rotation = sin(_anim_time * 6.0) * 0.2
	else:
		sprite.rotation = 0.0


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.GRAB:
			var at := _player.global_position
			var strike := telegraph_strike(at, 22.0, 0.8, grab_damage, Elements.Type.EARTH)
			if strike != null:
				strike.color = Color(0.95, 0.7, 0.4)
			_after(0.8, func() -> void:
				if not is_dead() and not is_lifted() and has_target() and not _player.is_dashing() and _player.global_position.distance_to(at) <= 24.0:
					_player.apply_root(1.5, "붙잡힘! (1.5초)"))
			return 1.2
		Pattern.QUAKE:
			for i in 6:
				var p := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0))
				telegraph_strike(p, 22.0, 0.85 + 0.08 * i, quake_damage, Elements.Type.EARTH)
			return 1.4
		Pattern.SAND:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.16), 140.0, sand_damage, sand_texture, 0.8, Elements.Type.EARTH)
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("안타이오스가 대지를 움켜쥔다! 땅의 힘이 더 빨리 쌓인다", Color(0.9, 0.75, 0.45))
