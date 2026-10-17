class_name BossChimera
extends PatternBoss
## 11스테이지 보스: 금단의 실험체 키메라 — 사자·염소·뱀을 꿰매 붙인 연구소의 실패작이자 걸작.
##   POUNCE : 사자 머리 — 낮게 웅크렸다가(예고선) 플레이어 쪽으로 덮치기
##   BREATH : 염소 머리 — 부채꼴 화염 숨결 (화상: 키메라의 burn_damage)
##   STING  : 뱀 꼬리 — 꼬리에서 독액 3발 (독) · 꼬리가 잘리면 덮치기로 대신
##   ROAR   : 포효 — 실패한 실험체들을 불러냄
##
## [기믹] 꼬리: 몸통과 꼬리는 체력이 따로 (몸 뒤쪽에 붙어 다니는 뱀 꼬리를 따로 공격)
##   - 꼬리를 자르면 본체 공격력이 50%로 떨어짐 (접촉 피해 포함) + 잠깐 비틀거림
## 체력 50% 이하: 패턴 강화 (덮치기 2연속, 숨결 탄 증가)

enum Pattern { POUNCE, BREATH, STING, ROAR }

const TAIL_CUT_POWER := 0.5

@export var tail_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var fire_texture: Texture2D
## 꼬리 독액 탄 (꼬리 쪽 burn_is_poison 으로 독이 묻음)
@export var sting_texture: Texture2D
@export var pounce_damage: int = 50
@export var breath_damage: int = 34
@export var tail_hp_ratio: float = 0.16

var tail: BossPart
var _tail_requested: bool = false
var _tail_cut: bool = false
var _pounce_dir: Vector2 = Vector2.ZERO
var _pounce_left: float = 0.0
var _pounce_windup: float = 0.0
var _pounces_queued: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.POUNCE, Pattern.STING, Pattern.BREATH, Pattern.ROAR, Pattern.POUNCE, Pattern.STING]


func has_tail() -> bool:
	return tail != null and is_instance_valid(tail) and not tail.is_dead()


func is_tail_cut() -> bool:
	return _tail_cut


func _get_move_velocity(delta: float) -> Vector2:
	if not _tail_requested and tail_scene != null:
		_tail_requested = true
		request_summon(tail_scene, global_position + Vector2(26, -14))
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and tail == null:
		tail = minion as BossPart
		tail.boss = self
		tail.anchor_offset = Vector2(26, -14)  # 몸 뒤쪽 위로 치켜든 꼬리 (바라보는 방향에 따라 뒤집힘)
		tail.max_hp = maxi(1, roundi(max_hp * tail_hp_ratio))
		tail.died.connect(_on_tail_cut)


# ============================================================ 기믹: 꼬리
func _on_tail_cut(_enemy: Enemy) -> void:
	_tail_cut = true
	tail = null
	power *= TAIL_CUT_POWER
	contact_damage = roundi(contact_damage * TAIL_CUT_POWER)
	base_tint = Color(0.85, 0.85, 0.95)
	set_status("꼬리 절단: 공격력 50%", Color(0.6, 1.0, 0.5))
	GameManager.show_notice("키메라의 꼬리를 잘랐다! 키메라의 공격력이 절반으로 떨어진다", Color(0.6, 1.0, 0.5))
	stun(1.6)
	Fx.explosion(self, get_hit_center() + Vector2(20, -10), Color(0.5, 0.9, 0.4), 30.0, 2)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.POUNCE:
			_pounces_queued = 2 if phase_two else 1
			_start_pounce()
			return 0.6 + 0.85 * _pounces_queued
		Pattern.BREATH:
			set_status("염소 머리: 화염 숨결", Color(1.0, 0.6, 0.3))
			_after(0.5, _breath)
			return 1.3
		Pattern.STING:
			if not has_tail():
				return _run_pattern(Pattern.POUNCE)
			set_status("뱀 꼬리: 독액", Color(0.6, 1.0, 0.4))
			Fx.burst(self, tail.get_muzzle(), Color(0.5, 1.0, 0.3), 8, 40.0, 0.4)
			_after(0.45, _sting)
			return 1.1
		Pattern.ROAR:
			set_status("포효: 실험체들이 깨어난다", Color(1.0, 0.8, 0.5))
			Fx.shockwave(self, get_hit_center(), Color(1.0, 0.85, 0.6), 70.0, 0.4)
			if not minion_scenes.is_empty():
				for i in (3 if phase_two else 2):
					request_summon(minion_scenes.pick_random(), global_position + Vector2.from_angle(TAU * i / 3.0) * 60.0)
			if _player != null:
				_player.shake_camera(3.0)
			return 1.0
	return 1.0


func _start_pounce() -> void:
	_pounce_windup = 0.55
	_pounce_left = 0.0
	_pounce_dir = direction_to_player()
	set_status("사자 머리: 덮치기", Color(1.0, 0.85, 0.5))
	# 덮칠 길을 미리 예고 (끝 지점에 장판)
	for i in 4:
		telegraph_strike(get_hit_center() + _pounce_dir * (30.0 + 30.0 * i), 18.0, 0.55 + 0.08 * i, pounce_damage, Elements.Type.NONE)


func _casting_velocity(delta: float) -> Vector2:
	if _pounce_windup > 0.0:
		_pounce_windup -= delta
		if _pounce_windup <= 0.0:
			_pounce_left = 0.35
		return Vector2.ZERO
	if _pounce_left > 0.0:
		_pounce_left -= delta
		if _pounce_left <= 0.0:
			_pounces_queued -= 1
			if _pounces_queued > 0 and not is_dead():
				_start_pounce()
			else:
				set_status("", Color.WHITE)
		return _pounce_dir * 340.0
	return Vector2.ZERO


func _breath() -> void:
	if is_dead():
		return
	var aim := direction_to_player()
	var count := 9 if phase_two else 7
	for i in count:
		var t := float(i) / float(count - 1) - 0.5
		shoot(aim.rotated(t * 1.1), 120.0 + randf() * 30.0, breath_damage, fire_texture, 0.0, Elements.Type.FIRE, get_hit_center() + Vector2(0, -10))
	set_status("", Color.WHITE)


func _sting() -> void:
	if not has_tail() or is_dead():
		return
	var aim := tail.get_muzzle().direction_to(_player.global_position) if has_target() else Vector2.LEFT
	for a in [-0.25, 0.0, 0.25]:
		tail.shoot(aim.rotated(a), 145.0, 30, sting_texture, 0.0, Elements.Type.NATURE, tail.get_muzzle())
	set_status("", Color.WHITE)


func _on_phase_two() -> void:
	GameManager.show_notice("키메라가 날뛴다! 덮치기가 2연속으로", Color(1.0, 0.6, 0.4))
