class_name BossCerberus
extends PatternBoss
## 43스테이지 보스: 명계의 문지기 케르베로스 — 불·얼음·독의 세 머리를 가진 명계의 개.
##   VOLLEY : 세 머리 — 깨어 있는 머리마다 제 속성 탄 (불 = 화상 / 얼음 = 감속 / 독 = 독)
##   BITE   : 물어뜯기 — 앞쪽 장판 세 개
##   HOWL   : 울부짖음 — 사방으로 퍼지는 어둠 탄
##   SUMMON : 명계 개 · 망령 병사 호출
##
## [기믹 1] 세 머리: 몸통은 단단해서 피해를 body_ratio 만 받음 → 머리를 때려야 함 (머리가 받은 공격이 몸으로 전해짐)
## [기믹 2] 리라: 보스방의 리라 곁에 서 있으면 연주가 쌓이고, 다 차면 깨어 있는 머리 하나가 sleep_time 초 잠듦
##   잠든 머리는 공격하지 않고, 잠든 머리를 때리면 피해 sleep_multiplier 배
## 체력 50% 이하: 잠이 짧아짐

enum Pattern { VOLLEY, BITE, HOWL, SUMMON }
enum Head { FIRE, ICE, POISON }

const HEAD_NAMES := ["불의 머리", "얼음의 머리", "독의 머리"]
const HEAD_OFFSETS := [Vector2(-22, -40), Vector2(0, -48), Vector2(22, -40)]

@export var head_scenes: Array[PackedScene] = []
@export var minion_scenes: Array[PackedScene] = []
@export var fire_texture: Texture2D
@export var ice_texture: Texture2D
@export var poison_texture: Texture2D
@export var dark_texture: Texture2D
@export var head_damage: int = 54
@export var bite_damage: int = 84
@export var howl_damage: int = 52
@export var body_ratio: float = 0.3
@export var sleep_time: float = 8.0
@export var sleep_multiplier: float = 2.0

var heads: Array[BossPart] = [null, null, null]
var lyre: Lyre
var _sleep_left: Array[float] = [0.0, 0.0, 0.0]
var _queue: Array[int] = []
var _started: bool = false
var _sleeps: int = 0
var _body_text_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.VOLLEY, Pattern.BITE, Pattern.HOWL, Pattern.VOLLEY, Pattern.SUMMON, Pattern.BITE]


func is_head_asleep(head: int) -> bool:
	return _sleep_left[head] > 0.0


func get_sleep_count() -> int:
	return _sleeps


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for i in mini(head_scenes.size(), 3):
			_queue.append(i)
			request_summon(head_scenes[i], global_position + HEAD_OFFSETS[i])
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
		lyre = Lyre.spawn(self, Vector2(area.get_center().x, area.end.y - 40))
		if lyre != null:
			lyre.song_finished.connect(_on_song_finished)
	_body_text_cooldown = maxf(_body_text_cooldown - delta, 0.0)
	return super._get_move_velocity(delta)


## 잠든 시간은 케르베로스가 기절해 있어도 흐름
func _physics_process(delta: float) -> void:
	for i in 3:
		if _sleep_left[i] > 0.0:
			_sleep_left[i] -= delta
			if _sleep_left[i] <= 0.0:
				_wake(i)
	super._physics_process(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and not _queue.is_empty():
		var i: int = _queue.pop_front()
		var head := minion as BossPart
		head.boss = self
		head.follow_boss = true
		head.anchor_offset = HEAD_OFFSETS[i]
		head.relay_ratio = 1.0
		head.show_bar = false
		heads[i] = head


# ============================================================ 기믹 1: 세 머리
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_dead() or amount <= 0:
		return
	if _body_text_cooldown <= 0.0:
		_body_text_cooldown = 0.8
		FloatingText.spawn(self, global_position + Vector2(0, -20), "몸통은 단단하다 — 머리를!", Color(0.8, 0.8, 0.9))
	super.take_damage(maxi(1, roundi(amount * body_ratio)), knockback, is_crit, armor_pen)


## 머리(BossPart, relay_ratio)가 받은 공격 → 몸으로 (잠든 머리는 relay_ratio 가 커져 있음)
func take_weak_point_hit(amount: int, knockback: Vector2, is_crit: bool, armor_pen: int, ratio: float) -> void:
	if is_dead():
		return
	super.take_damage(roundi(amount * ratio), knockback, is_crit or ratio > 1.0, armor_pen)


# ============================================================ 기믹 2: 리라
func _on_song_finished() -> void:
	var awake: Array[int] = []
	for i in 3:
		if not is_head_asleep(i):
			awake.append(i)
	if awake.is_empty():
		return
	put_to_sleep(awake.pick_random())


func put_to_sleep(i: int) -> void:
	_sleeps += 1
	_sleep_left[i] = sleep_time * (0.7 if phase_two else 1.0)
	var head := heads[i]
	if head != null and is_instance_valid(head):
		head.relay_ratio = sleep_multiplier
		head.base_tint = Color(0.6, 0.6, 0.8)
		head.sprite.rotation = 0.4
		FloatingText.spawn(head, head.global_position + Vector2(0, -20), "Zzz…", Color(0.8, 0.85, 1.0), true)
	Net.announce("리라 소리에 %s가 잠들었다! 잠든 머리는 피해 %d배" % [HEAD_NAMES[i], roundi(sleep_multiplier)], Color(1.0, 0.92, 0.6))


func _wake(i: int) -> void:
	_sleep_left[i] = 0.0
	var head := heads[i]
	if head != null and is_instance_valid(head):
		head.relay_ratio = 1.0
		head.base_tint = Color.WHITE
		head.sprite.rotation = 0.0


# ============================================================ 패턴
func _head_shot(i: int, dir: Vector2) -> void:
	var head := heads[i]
	if head == null or not is_instance_valid(head) or is_head_asleep(i):
		return
	var from := head.get_hit_center()
	match i:
		Head.FIRE:
			var keep := burn_damage
			burn_damage = 9
			burn_is_poison = false
			shoot(dir, 150.0, head_damage, fire_texture, 0.0, Elements.Type.FIRE, from)
			burn_damage = keep
		Head.ICE:
			shoot(dir, 140.0, head_damage, ice_texture, 1.2, Elements.Type.ICE, from)
		Head.POISON:
			var keep2 := burn_damage
			burn_damage = 9
			burn_is_poison = true
			shoot(dir, 140.0, head_damage, poison_texture, 0.0, Elements.Type.NATURE, from)
			burn_damage = keep2
			burn_is_poison = false


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.VOLLEY:
			for w in 3:
				_after(0.25 * w, func() -> void:
					if is_dead() or not has_target():
						return
					for i in 3:
						var head := heads[i]
						if head != null and is_instance_valid(head):
							var aim := head.get_hit_center().direction_to(_player.global_position + Vector2(0, -4))
							for k in 3:
								_head_shot(i, aim.rotated((k - 1) * 0.18)))
			return 1.2
		Pattern.BITE:
			var dir := direction_to_player()
			for i in 3:
				telegraph_strike(get_hit_center() + dir.rotated((i - 1) * 0.5) * 44.0, 22.0, 0.75, bite_damage, Elements.Type.DARK)
			return 1.1
		Pattern.HOWL:
			for i in 16:
				shoot(Vector2.from_angle(TAU * i / 16.0), 110.0, howl_damage, dark_texture, 0.0, Elements.Type.DARK)
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if lyre != null and is_instance_valid(lyre):
		lyre.queue_free()
	super._die()


func _on_phase_two() -> void:
	Net.announce("케르베로스가 세 머리로 울부짖는다! 잠이 얕아진다", Color(0.9, 0.6, 0.6))
