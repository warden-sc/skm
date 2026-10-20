class_name BossCycnus
extends PatternBoss
## 57스테이지 보스: 해골 신전의 기사 키크노스 — 아레스의 아들. 지나가는 나그네를 죽여 그 해골로 아버지의 신전을 쌓았습니다.
##   LANCE   : 창 돌진 찌르기 (일직선 셋, 부채꼴)
##   SKULLS  : 해골 탄막 (몸 주위로 퍼짐)
##   SWAN    : 백조의 날개 — 몸 주위 고리 + 깃털
##   SUMMON  : 해골 순례자 · 해골 기사 호출
##
## [기믹] 해골 제단: 보스방의 제단 altar_count 개 중 하나라도 서 있으면 「제단의 가호」 — 받는 피해가 ward_ratio 배로 줄어듦
##   제단을 모두 부수면 가호가 깨지며 휘청임 (기절)
##   부서진 제단은 rebuild_time 초 뒤 해골 순례자가 하나씩 다시 쌓아 올림
## 체력 50% 이하: 제단이 더 빨리 다시 쌓임

enum Pattern { LANCE, SKULLS, SWAN, SUMMON }

const ALTAR_SPOTS := [Vector2(-210, -100), Vector2(210, -100), Vector2(0, 120)]

@export var altar_scene: PackedScene
@export var pilgrim_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var skull_texture: Texture2D
@export var feather_texture: Texture2D
@export var lance_damage: int = 92
@export var skull_damage: int = 58
@export var swan_damage: int = 80
@export var altar_hp_ratio: float = 0.03
@export var ward_ratio: float = 0.15
@export var rebuild_time: float = 22.0

var altars: Array[BossPart] = []
var _altar_slots: Array[int] = []
var _missing: Array[int] = []
var _rebuild_left: float = 0.0
var _rebuilt: int = 0
var _pending_slot: int = -1
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.LANCE, Pattern.SKULLS, Pattern.SWAN, Pattern.LANCE, Pattern.SUMMON]


func get_altars() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for a in altars:
		if is_instance_valid(a) and not a.is_dead():
			alive.append(a)
	return alive


func is_warded() -> bool:
	return not get_altars().is_empty()


func get_rebuilt_count() -> int:
	return _rebuilt


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for i in ALTAR_SPOTS.size():
			_raise_altar(i)
	return super._get_move_velocity(delta)


func _raise_altar(slot: int) -> void:
	if altar_scene == null:
		return
	_pending_slot = slot
	request_summon(altar_scene, _area().get_center() + ALTAR_SPOTS[slot])
	_pending_slot = -1


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart:
		return
	var altar := minion as BossPart
	altar.boss = self
	altar.follow_boss = false
	altar.max_hp = maxi(1, roundi(max_hp * altar_hp_ratio))
	altar.hp = altar.max_hp
	altar.died.connect(_on_altar_broken)
	altars.append(altar)
	_altar_slots.append(_pending_slot)
	_update_status()


func _on_altar_broken(altar: Enemy) -> void:
	var idx := altars.find(altar)
	if idx >= 0:
		_missing.append(_altar_slots[idx])
		altars.remove_at(idx)
		_altar_slots.remove_at(idx)
	if _rebuild_left <= 0.0:
		_rebuild_left = rebuild_time * (0.7 if phase_two else 1.0)
	if not is_warded() and not is_dead():
		super.stun(4.0)
		Fx.burst(self, get_hit_center(), Color(0.9, 0.9, 1.0), 24, 80.0, 0.6)
		Net.announce("해골 제단이 모두 무너졌다! 키크노스의 가호가 깨진다", Color(0.85, 0.9, 1.0))
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and not _missing.is_empty():
		_rebuild_left -= delta
		if _rebuild_left <= 0.0:
			rebuild_altar()
	super._physics_process(delta)


## 해골 순례자가 제단 하나를 다시 쌓음 (테스트에서도 직접 호출)
func rebuild_altar() -> void:
	if _missing.is_empty() or is_dead():
		return
	var slot: int = _missing.pop_front()
	_rebuilt += 1
	_raise_altar(slot)
	if pilgrim_scene != null:
		request_summon(pilgrim_scene, _area().get_center() + ALTAR_SPOTS[slot] + Vector2(20, 10))
	Net.announce("해골 순례자가 제단을 다시 쌓아 올렸다", Color(0.85, 0.85, 0.8))
	_rebuild_left = rebuild_time * (0.7 if phase_two else 1.0) if not _missing.is_empty() else 0.0


## 제단의 가호: 제단이 하나라도 서 있으면 받는 피해가 크게 줄어듦
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_warded() and amount > 0:
		amount = maxi(1, roundi(amount * ward_ratio))
		if _immune_text_cooldown <= 0.0:
			_immune_text_cooldown = 0.8
			FloatingText.spawn(self, global_position + Vector2(0, -44), "제단의 가호!", Color(0.85, 0.9, 1.0))
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _update_status() -> void:
	var n := get_altars().size()
	if n > 0:
		set_status("해골 제단의 가호 (제단 %d개) — 받는 피해 %d%%" % [n, roundi(ward_ratio * 100.0)], Color(0.85, 0.9, 1.0))
	else:
		set_status("가호가 깨짐", Color(1.0, 0.6, 0.5))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.LANCE:
			for k in 3:
				var d := dir.rotated((k - 1) * 0.3)
				for i in 8:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 13.0, 0.65 + 0.03 * i, lance_damage, Elements.Type.NONE)
			return 1.2
		Pattern.SKULLS:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 14:
						shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 120.0, skull_damage, skull_texture, 0.0, Elements.Type.DARK))
			return 1.1
		Pattern.SWAN:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 48.0, 20.0, 0.85, swan_damage, Elements.Type.HOLY)
			for i in 8:
				shoot(dir.rotated((i - 3.5) * 0.15), 160.0, skull_damage, feather_texture, 0.0, Elements.Type.HOLY)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	Net.announce("쓰러진 키크노스의 몸이 하얀 백조가 되어 날아오른다…", Color(0.9, 0.95, 1.0))
	super._die()


func _on_phase_two() -> void:
	Net.announce("키크노스: 아버지 아레스께 바칠 해골이 하나 더 늘겠군! 제단이 더 빨리 쌓인다", Color(0.85, 0.85, 1.0))
