class_name BossHydra
extends PatternBoss
## 41스테이지 보스: 머리 아홉의 히드라 — 레르나의 늪에 사는, 목을 자르면 두 개가 돋아나는 독룡.
##   VOLLEY : 독니 — 살아 있는 머리마다 플레이어에게 독액 탄
##   SWAMP  : 독 늪 — 플레이어 주변에 독 장판 (오래 남음)
##   WATER  : 물줄기 — 플레이어 쪽 일직선 장판 + 보스방의 성화대 하나를 꺼 버림
##   SUMMON : 늪 뱀 · 히드라 새끼 호출
##
## [기믹 1] 머리: start_heads 개로 시작(최대 9). 머리(체력 따로)마다 히드라 몸 방어력 +head_armor
##   머리를 자르면 「잘린 목」이 남고, regrow_time 초 안에 지지지 않으면 머리 두 개가 돋아남 (9개를 넘지는 않음)
## [기믹 2] 성화대: 보스방 네 곳의 성화대에 다가가면 무기에 「불꽃 부여」(enchant_time 초)
##   불꽃 부여 중에 잘린 목을 때리면 지져져서 다시 자라지 않음 + 히드라가 고통에 몸부림치며 피해
##   히드라의 물줄기가 성화대를 꺼 버림 → relight_time 초 뒤 다시 붙음
##   (fire_weapons_cauterize 를 켜면 불속성 무기로도 지질 수 있음 — 장비 밸런스를 맞춘 뒤 켤 수 있게 남겨 둠)
## 체력 50% 이하: 목이 더 빨리 다시 자람

enum Pattern { VOLLEY, SWAMP, WATER, SUMMON }

const MAX_HEADS := 9

@export var head_scene: PackedScene
@export var stump_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var venom_texture: Texture2D
@export var venom_damage: int = 52
@export var water_damage: int = 76
@export var start_heads: int = 5
@export var head_armor: int = 8
@export var head_hp_ratio: float = 0.025
@export var regrow_time: float = 6.0
@export var cauterize_ratio: float = 0.02
@export var enchant_time: float = 10.0
@export var relight_time: float = 8.0
@export var fire_weapons_cauterize: bool = false

var braziers: Array[Brazier] = []
## 머리 자리 9개: null / BossPart(머리) / HydraStump(잘린 목)
var _slots: Array = []
var _stump_left: Dictionary = {}   # HydraStump → 남은 시간
var _pending: Array[int] = []       # 소환 요청한 머리/목이 들어갈 자리
var _base_defense: int = 0
var _started: bool = false
var _cut: int = 0
var _burned: int = 0
var _regrown: int = 0
var _hint_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.VOLLEY, Pattern.WATER, Pattern.SWAMP, Pattern.VOLLEY, Pattern.SUMMON, Pattern.WATER]
	_base_defense = defense
	_slots.resize(MAX_HEADS)


func slot_offset(i: int) -> Vector2:
	var a := deg_to_rad(-160.0 + 140.0 * i / float(MAX_HEADS - 1))
	return Vector2(cos(a) * 46.0, -30.0 + sin(a) * 26.0)


func get_heads() -> Array[BossPart]:
	var list: Array[BossPart] = []
	for v in _slots:
		if v == null or not is_instance_valid(v):
			continue
		var part := v as BossPart
		if part != null and not part.is_dead() and not part is HydraStump:
			list.append(part)
	return list


func get_stumps() -> Array[HydraStump]:
	var list: Array[HydraStump] = []
	for v in _slots:
		if v == null or not is_instance_valid(v):
			continue
		var st := v as HydraStump
		if st != null and not st.is_dead():
			list.append(st)
	return list


func get_cut_count() -> int:
	return _cut


func get_burned_count() -> int:
	return _burned


func get_regrown_count() -> int:
	return _regrown


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
		var c := area.get_center()
		for k in 4:
			var at := c + Vector2((-1.0 if k % 2 == 0 else 1.0) * area.size.x * 0.36, (-0.22 if k < 2 else 0.3) * area.size.y)
			var b := Brazier.spawn(self, at)
			if b != null:
				b.enchant_time = enchant_time
				b.relight_time = relight_time
				braziers.append(b)
		for i in start_heads:
			_grow(_free_slot())
	_hint_cooldown = maxf(_hint_cooldown - delta, 0.0)
	return super._get_move_velocity(delta)


## 잘린 목의 시간은 기절 중에도 흐름
func _physics_process(delta: float) -> void:
	if not is_dead():
		for st in _stump_left.keys():
			var stump := st as HydraStump
			if not is_instance_valid(stump) or stump.is_dead():
				_stump_left.erase(st)
				continue
			_stump_left[st] = float(_stump_left[st]) - delta
			if float(_stump_left[st]) <= 0.0:
				_regrow(stump)
	super._physics_process(delta)


func _free_slot() -> int:
	var order := [4, 3, 5, 2, 6, 1, 7, 0, 8]
	for i in order:
		if _slots[i] == null and not _pending.has(i):
			return i
	return -1


func _grow(slot: int, as_stump: bool = false) -> void:
	if slot < 0:
		return
	var scene := stump_scene if as_stump else head_scene
	if scene == null:
		return
	_pending.append(slot)
	request_summon(scene, global_position + slot_offset(slot))


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart or _pending.is_empty():
		return
	var part := minion as BossPart
	var slot: int = _pending.pop_front()
	part.boss = self
	part.follow_boss = true
	part.anchor_offset = slot_offset(slot)
	_slots[slot] = part
	if part is HydraStump:
		_stump_left[part] = regrow_time * (0.7 if phase_two else 1.0)
	else:
		part.max_hp = maxi(1, roundi(max_hp * head_hp_ratio))
		part.died.connect(_on_head_cut.bind(slot))
	_update_armor()


func _update_armor() -> void:
	defense = _base_defense + head_armor * get_heads().size()


# ============================================================ 기믹 1: 머리 자르기 · 재생
func _on_head_cut(_enemy: Enemy, slot: int) -> void:
	if is_dead():
		return
	_cut += 1
	_slots[slot] = null
	_grow(slot, true)
	_update_armor()
	set_status("목이 잘렸다! 불로 지지지 않으면 둘로 자란다", Color(1.0, 0.7, 0.4))
	if _hint_cooldown <= 0.0:
		_hint_cooldown = 4.0
		GameManager.show_notice("히드라의 목을 잘랐다! 성화대의 불꽃을 무기에 두르고 잘린 목을 지져라", Color(1.0, 0.7, 0.4))


func _regrow(stump: HydraStump) -> void:
	var slot := _slots.find(stump)
	_stump_left.erase(stump)
	stump.despawn()
	if slot < 0:
		return
	_slots[slot] = null
	_regrown += 1
	_grow(slot)
	if get_heads().size() + _pending.size() < MAX_HEADS:
		_grow(_free_slot())
	Fx.burst(self, global_position + slot_offset(slot), Color(0.5, 0.9, 0.5), 16, 50.0, 0.4)
	GameManager.show_notice("잘린 목에서 머리 두 개가 돋아났다!", Color(0.6, 1.0, 0.5))


# ============================================================ 기믹 2: 지지기
func can_cauterize() -> bool:
	if not has_target():
		return false
	if _player.has_fire_enchant():
		return true
	return fire_weapons_cauterize and GameManager.equipped_weapon != null and GameManager.equipped_weapon.element == Elements.Type.FIRE


func on_stump_hit(stump: HydraStump) -> void:
	if is_dead() or stump.is_dead():
		return
	if not can_cauterize():
		if _hint_cooldown <= 0.0:
			_hint_cooldown = 1.5
			FloatingText.spawn(stump, stump.global_position + Vector2(0, -20), "불로 지져야 한다!", Color(1.0, 0.7, 0.4))
		return
	_burned += 1
	var slot := _slots.find(stump)
	if slot >= 0:
		_slots[slot] = null
	_stump_left.erase(stump)
	Fx.fire_blast(self, stump.get_hit_center(), 18.0, 2)
	stump.despawn()
	super.take_damage(maxi(1, roundi(max_hp * cauterize_ratio)), Vector2.ZERO, true, 999999)
	set_status("", Color.WHITE)
	GameManager.show_notice("잘린 목을 불로 지졌다! 더는 자라지 않는다", Color(1.0, 0.75, 0.4))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.VOLLEY:
			var heads := get_heads()
			for i in heads.size():
				var head := heads[i]
				_after(0.12 * i, func() -> void:
					if is_dead() or not is_instance_valid(head) or head.is_dead() or not has_target():
						return
					var dir := head.get_hit_center().direction_to(_player.global_position + Vector2(0, -4))
					shoot(dir, 140.0, venom_damage, venom_texture, 0.0, Elements.Type.NATURE, head.get_hit_center()))
			if heads.is_empty():
				return _run_pattern(Pattern.SWAMP)
			return 0.6 + 0.12 * heads.size()
		Pattern.SWAMP:
			for i in 4:
				var at := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 80.0))
				telegraph_strike(at, 20.0, 0.8, venom_damage, Elements.Type.NATURE)
				_after(0.8, func() -> void:
					if not is_dead():
						GroundZone.spawn_hostile(self, at, GroundZone.Kind.SLIME, 22.0, 9.0, 0.7, roundi(7 * power), 2.0))
			return 1.3
		Pattern.WATER:
			var dir2 := direction_to_player()
			for i in 9:
				telegraph_strike(get_hit_center() + dir2 * (26.0 + 24.0 * i), 15.0, 0.6 + 0.04 * i, water_damage, Elements.Type.ICE)
			douse_brazier()
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


## 성화대 하나(플레이어와 가장 가까운 켜진 것)를 물줄기로 꺼 버림
func douse_brazier() -> Brazier:
	var best: Brazier = null
	for b in braziers:
		if is_instance_valid(b) and b.lit and (best == null or (has_target() and b.global_position.distance_to(_player.global_position) < best.global_position.distance_to(_player.global_position))):
			best = b
	if best != null:
		best.douse()
	return best


func _die() -> void:
	for b in braziers:
		if is_instance_valid(b):
			b.queue_free()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("히드라가 울부짖는다! 잘린 목이 더 빨리 자란다", Color(0.6, 1.0, 0.5))
