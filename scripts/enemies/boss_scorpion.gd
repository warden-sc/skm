class_name BossScorpion
extends PatternBoss
## 22스테이지(마지막) 보스: 사막의 암살자 스콜피언 — 모래 폭풍 속에서 소리 없이 다가와 독침을 꽂는 거대 전갈.
##   STING  : 꼬리 독침 3연타 — 플레이어 쪽 일직선 찌르기 장판 3번 + 마지막에 독액 탄 (맞으면 강한 독)
##   PINCER : 집게 으깨기 — 앞쪽 양옆 집게 장판, 맞으면 「갑각 분쇄」(방어력 감소)
##   SPIT   : 신경독 분사 — 독액 부채꼴, 맞으면 1.4초간 느려짐
##   SWEEP  : 꼬리 휩쓸기 — 몸 주위 큰 장판
##   SUMMON : 사막 도적 · 사막 독사 호출
##
## [기믹] 잠행 (burrow_interval 마다): 모래 밑으로 파고듦 (burrow_time 동안)
##   - 모래 속에 있는 동안은 어떤 공격도 닿지 않음 ("모래 속! 공격 안 닿음")
##   - 숨어 있는 동안 초당 최대 체력의 burrow_heal_per_sec 씩 회복
##   - 모래 둔덕이 플레이어를 소리 없이 쫓아오다가, 끝나기 직전 플레이어 발밑에 예고 → 그 자리에서 솟구치며 기습 (암살)
## 체력 50% 이하: 더 자주 숨고, 숨는 시간이 짧은 대신 솟구칠 때 독침 탄을 사방으로 뿌림

enum Pattern { STING, PINCER, SPIT, SWEEP, SUMMON }

const MOUND_TEXTURE: Texture2D = preload("res://assets/sprites/characters/sand_mound.png")

@export var minion_scenes: Array[PackedScene] = []
@export var venom_texture: Texture2D
@export var sting_damage: int = 58
@export var pincer_damage: int = 62
@export var spit_damage: int = 36
@export var sweep_damage: int = 56
@export var ambush_damage: int = 70
@export var pincer_armor_break: int = 12
@export var burrow_interval: float = 15.0
@export var burrow_time: float = 5.0
## 숨어 있는 동안 초당 회복 (최대 체력 비율)
@export var burrow_heal_per_sec: float = 0.015
## 솟구치기 몇 초 전에 발밑 예고
@export var ambush_warn: float = 0.9

var _burrowed: bool = false
var _burrow_left: float = 0.0
var _burrow_cooldown: float = 7.0
var _ambush_marked: bool = false
var _ambush_at: Vector2 = Vector2.ZERO
var _heal_carry: float = 0.0
var _healed_total: int = 0
var _burrows: int = 0
var _mound: Sprite2D
var _base_contact: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.STING, Pattern.PINCER, Pattern.SPIT, Pattern.SWEEP, Pattern.STING, Pattern.SUMMON]
	immune_text = "모래 속! 공격 안 닿음"
	_base_contact = contact_damage
	_mound = Sprite2D.new()
	_mound.texture = MOUND_TEXTURE
	_mound.scale = Vector2.ONE * 1.4
	_mound.position = Vector2(0, -6)
	_mound.hide()
	add_child(_mound)


func is_burrowed() -> bool:
	return _burrowed


func get_burrow_count() -> int:
	return _burrows


func get_healed_total() -> int:
	return _healed_total


func can_be_hit_by(_kind: HitKind) -> bool:
	return not _burrowed


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _burrowed:
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _get_move_velocity(delta: float) -> Vector2:
	if _burrowed:
		return _burrow_velocity(delta)
	if has_target():
		_burrow_cooldown -= delta
		if _burrow_cooldown <= 0.0 and not is_casting():
			burrow()
			return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 잠행
func burrow() -> void:
	if _burrowed or is_dead():
		return
	_burrowed = true
	_burrows += 1
	_burrow_left = burrow_time * (0.8 if phase_two else 1.0)
	_ambush_marked = false
	_heal_carry = 0.0
	contact_damage = 0
	sprite.hide()
	_mound.show()
	set_status("모래 속으로 숨었다 — 공격이 닿지 않고 체력 회복 중", Color(1.0, 0.85, 0.5))
	GameManager.show_notice("스콜피언이 모래 속으로 숨었다! 발밑을 조심하라", Color(1.0, 0.85, 0.5))
	Fx.burst(self, global_position, Color(0.85, 0.7, 0.45), 24, 70.0, 0.5, Vector2(0, 60), 1.4)


func _burrow_velocity(delta: float) -> Vector2:
	_burrow_left -= delta
	# 숨어 있는 동안 회복
	_heal_carry += max_hp * burrow_heal_per_sec * delta
	if _heal_carry >= 1.0 and hp < max_hp:
		var amount := mini(int(_heal_carry), max_hp - hp)
		_heal_carry -= int(_heal_carry)
		hp += amount
		_healed_total += amount
		health_changed.emit(hp, max_hp)
		if Engine.get_physics_frames() % 30 == 0:
			FloatingText.spawn(self, global_position + Vector2(0, -24), "+%d" % amount, Color(0.6, 1.0, 0.6))
	if Engine.get_physics_frames() % 6 == 0:
		Fx.burst(self, global_position, Color(0.85, 0.7, 0.45), 3, 30.0, 0.3)
	if _burrow_left <= 0.0:
		_emerge()
		return Vector2.ZERO
	if not has_target():
		return Vector2.ZERO
	# 끝나기 직전 플레이어 발밑에 예고하고 그 자리로
	if not _ambush_marked and _burrow_left <= ambush_warn:
		_ambush_marked = true
		_ambush_at = _player.global_position
		telegraph_strike(_ambush_at, 30.0, _burrow_left, ambush_damage, Elements.Type.EARTH)
	if _ambush_marked:
		var to := _ambush_at - global_position
		return to / maxf(_burrow_left, delta) if to.length() > 1.0 else Vector2.ZERO
	# 모래 둔덕이 소리 없이 쫓아옴
	return global_position.direction_to(_player.global_position) * move_speed * 1.6


func _emerge() -> void:
	_burrowed = false
	_burrow_cooldown = burrow_interval * (0.75 if phase_two else 1.0)
	contact_damage = _base_contact
	sprite.show()
	_mound.hide()
	set_status("", Color.WHITE)
	Fx.explosion(self, global_position, Color(0.85, 0.7, 0.45), 36.0, 2, Vector2(0, 120))
	if _player != null:
		_player.shake_camera(5.0)
	if phase_two:
		for i in 12:
			shoot(Vector2.from_angle(TAU * i / 12.0), 120.0, spit_damage, venom_texture, 0.0, Elements.Type.NATURE)
	_bstate = BossState.CHASE
	_btimer = 0.6


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.STING:
			set_status("꼬리 독침!", Color(0.85, 0.5, 1.0))
			for k in 3:
				_after(0.35 * k, _sting.bind(k == 2))
			_after(1.3, func() -> void:
				if get_status_text() == "꼬리 독침!":
					set_status("", Color.WHITE))
			return 1.5
		Pattern.PINCER:
			var dir := direction_to_player()
			for side in [-1.0, 1.0]:
				var at: Vector2 = get_hit_center() + dir * 34.0 + dir.orthogonal() * 22.0 * side
				telegraph_strike(at, 22.0, 0.7, pincer_damage, Elements.Type.NONE)
				_after(0.7, _check_pincer.bind(at))
			return 1.1
		Pattern.SPIT:
			var aim := direction_to_player()
			for i in 5:
				shoot(aim.rotated((i - 2) * 0.2), 130.0, spit_damage, venom_texture, 1.4, Elements.Type.NATURE)
			set_status("신경독 분사", Color(0.85, 0.5, 1.0))
			_after(0.8, func() -> void:
				if get_status_text() == "신경독 분사":
					set_status("", Color.WHITE))
			return 0.9
		Pattern.SWEEP:
			telegraph_strike(get_hit_center(), 62.0, 0.9, sweep_damage, Elements.Type.EARTH)
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 30.0))
			return 0.9
	return 1.0


## 꼬리 독침: 플레이어 쪽 일직선 찌르기, 마지막 한 번은 독액 탄까지
func _sting(last: bool) -> void:
	if is_dead() or _burrowed or not has_target():
		return
	var dir := direction_to_player()
	for i in 4:
		var strike := telegraph_strike(get_hit_center() + dir * (28.0 + 22.0 * i), 14.0, 0.45, sting_damage, Elements.Type.NATURE)
		if strike != null:
			strike.burn_damage = 9
			strike.burn_duration = 4.0
			strike.burn_poison = true
	if last:
		var saved := [burn_damage, burn_duration, burn_is_poison]
		burn_damage = 9
		burn_duration = 4.0
		burn_is_poison = true
		shoot(dir, 170.0, spit_damage, venom_texture, 0.0, Elements.Type.NATURE)
		burn_damage = saved[0]
		burn_duration = saved[1]
		burn_is_poison = saved[2]


## 집게에 맞았으면 갑각 분쇄 (방어력 감소)
func _check_pincer(at: Vector2) -> void:
	if not has_target() or is_dead():
		return
	if _player.global_position.distance_to(at) <= 26.0 and not _player.is_dashing():
		_player.apply_armor_break(pincer_armor_break, 5.0)
		FloatingText.spawn(_player, _player.global_position + Vector2(0, -24), "갑각 분쇄! 방어력 -%d" % pincer_armor_break, Color(1.0, 0.6, 0.4), true)


func _on_phase_two() -> void:
	GameManager.show_notice("스콜피언의 독이 진해진다… 더 자주 모래 속으로 숨는다", Color(0.85, 0.5, 1.0))
