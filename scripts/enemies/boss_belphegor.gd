class_name BossBelphegor
extends PatternBoss
## 82스테이지 보스: 나태의 마왕 벨페고르 — 일곱 대죄 중 「나태」. 늘어진 옥좌에 파묻혀 세상을 게으르게 만드는 마왕.
##   YAWN    : 하품 — 몸 주위로 퍼지는 졸음의 고리
##   SLUMP   : 몸을 털썩 내려놓음 (큰 장판)
##   DROWSE  : 졸음 구슬 탄막 (맞으면 느려짐)
##   SUMMON  : 졸음 정령 · 꾸벅이는 구울 · 거대 달팽이 호출
##
## [기믹] 나태의 오라: 벨페고르 둘레(aura_radius) 안에서는 이동 속도가 aura_slow 배로 느려짐
## [기믹] 깊은 잠: sleep_after 초 동안 공격받지 않으면 잠들어 초당 최대 체력의 sleep_heal 만큼 회복
##   잠든 벨페고르를 때리면 깨어나며 크게 휘청 (잠든 동안 받는 첫 공격은 피해 x wake_multiplier) → 쉬지 않고 몰아쳐야 함
## 체력 50% 이하: 오라가 넓어지고 더 빨리 잠듦

enum Pattern { YAWN, SLUMP, DROWSE, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var drowse_texture: Texture2D
@export var yawn_damage: int = 86
@export var slump_damage: int = 104
@export var drowse_damage: int = 62
@export var aura_radius: float = 110.0
@export var aura_slow: float = 0.55
@export var sleep_after: float = 4.0
@export var sleep_heal: float = 0.02
@export var wake_multiplier: float = 1.5

var _idle: float = 0.0
var _asleep: bool = false
var _heal_acc: float = 0.0
var _healed: int = 0
var _sleeps: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.YAWN, Pattern.DROWSE, Pattern.SLUMP, Pattern.DROWSE, Pattern.SUMMON]


func is_asleep() -> bool:
	return _asleep


func get_healed_total() -> int:
	return _healed


func get_sleep_count() -> int:
	return _sleeps


func aura() -> float:
	return aura_radius * (1.3 if phase_two else 1.0)


func _get_move_velocity(delta: float) -> Vector2:
	if _asleep:
		return Vector2.ZERO
	return super._get_move_velocity(delta) * 0.6


## 잠듦 (테스트에서도 직접 호출)
func fall_asleep() -> void:
	if _asleep or is_dead():
		return
	_asleep = true
	_sleeps += 1
	set_status("깊은 잠 — 회복 중 (때려서 깨워라)", Color(0.75, 0.7, 1.0))
	Net.announce("벨페고르가 깊은 잠에 빠져 회복한다! 어서 때려 깨워라", Color(0.75, 0.7, 1.0))


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	_idle = 0.0
	if _asleep and amount > 0:
		_asleep = false
		amount = roundi(amount * wake_multiplier)
		super.take_damage(amount, knockback, is_crit, armor_pen)
		super.stun(4.0)
		FloatingText.spawn(self, global_position + Vector2(0, -50), "깼다!", Color(1.0, 0.7, 0.5), true)
		set_status("나태의 오라", Color(0.8, 0.75, 1.0))
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _physics_process(delta: float) -> void:
	if not is_dead() and has_target():
		if _player.global_position.distance_to(global_position) <= aura():
			_player.apply_slow(aura_slow, 0.15)
			_player.mark_floor_status("나태의 오라 (느려짐)")
		if _asleep:
			_heal_acc += max_hp * sleep_heal * delta
			if _heal_acc >= 1.0 and hp < max_hp:
				var amount := mini(int(_heal_acc), max_hp - hp)
				_heal_acc -= int(_heal_acc)
				hp += amount
				_healed += amount
				health_changed.emit(hp, max_hp)
		else:
			_idle += delta
			if _idle >= sleep_after * (0.7 if phase_two else 1.0):
				fall_asleep()
		queue_redraw()
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target() or _asleep:
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.YAWN:
			for i in 14:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0) * 64.0, 22.0, 0.9, yawn_damage, Elements.Type.ARCANE)
			return 1.2
		Pattern.SLUMP:
			telegraph_strike(get_hit_center() + dir * 30.0, 56.0, 1.1, slump_damage, Elements.Type.EARTH)
			return 1.4
		Pattern.DROWSE:
			for i in 7:
				shoot(dir.rotated((i - 3) * 0.17), 110.0, drowse_damage, drowse_texture, 1.5, Elements.Type.ARCANE)
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


## 나태의 오라
func _draw() -> void:
	if is_dead():
		return
	draw_circle(Vector2(0, -10), aura(), Color(0.6, 0.55, 0.9, 0.08))
	draw_arc(Vector2(0, -10), aura(), 0.0, TAU, 48, Color(0.75, 0.7, 1.0, 0.35), 1.0)


func _on_phase_two() -> void:
	Net.announce("벨페고르가 하품을 한다… 오라가 넓어지고 더 빨리 잠든다", Color(0.75, 0.7, 1.0))
