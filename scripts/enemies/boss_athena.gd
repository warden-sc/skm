class_name BossAthena
extends PatternBoss
## 80스테이지 보스: 지혜의 신 아테나 — 전략과 지혜의 여신, 아테네의 수호신.
##   SPEAR     : 지혜의 창 — 일직선 셋 (부채꼴)
##   STRATEGY  : 전략의 수 — 보스방 칸 위에 다음 세 수를 표시한 뒤 차례로 터뜨림
##   FEATHERS  : 올빼미 깃 탄막
##   SUMMON    : 아테네 호플리테스 · 지혜의 올빼미 호출
##
## [기믹 1] 팔랑크스 진형: 방패병 phalanx_size 명이 아테나를 둘러싸 방패벽을 세움 (방패병마다 체력 따로)
##   플레이어가 있는 쪽 자리에 방패병이 서 있으면 아테나가 받는 피해 x wall_ratio — 방패병을 쓰러뜨려 생긴 빈틈 쪽에서 때리면 피해가 그대로
##   reform_time 초마다 진형을 다시 짜지만, 짤 때마다 인원이 한 명씩 줄어듦
## [기믹 2] 전략의 수: 보스방이 칸으로 나뉘고 아테나가 다음 세 수(번호 1 · 2 · 3)를 미리 보여 줌 → 순서대로 터짐
## [기믹 3] 간파: 같은 종류의 무기(검 · 활 · 지팡이 · 단검)로만 계속 때리면 아테나가 꿰뚫어 봐 그 무기 피해가 점점 줄어듦 (최대 -insight_cap)
##   다른 무기로 때리면 꿰뚫린 정도가 풀림 → 무기를 바꿔 가며 싸우기
## 체력 50% 이하: 전략의 수가 늘어나고 더 빨라짐

enum Pattern { SPEAR, STRATEGY, FEATHERS, SUMMON }

const WEAPON_NAMES := ["검", "활", "지팡이", "단검"]

@export var shield_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var feather_texture: Texture2D
@export var spear_damage: int = 104
@export var strategy_damage: int = 100
@export var feather_damage: int = 64
@export var phalanx_size: int = 6
@export var shield_hp_ratio: float = 0.02
@export var wall_ratio: float = 0.1
@export var reform_time: float = 20.0
@export var insight_step: float = 0.06
@export var insight_cap: float = 0.75

var shields: Array[BossPart] = []
var board: StrategyBoard
var insight: Dictionary = {}   # WeaponType -> 쌓인 수
var _slots_alive: Array[bool] = []
var _pending_slot: int = -1
var _reform_left: float = 20.0
var _reforms: int = 0
var _wall_blocks: int = 0
var _gap_hits: int = 0
var _strategy_hits: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPEAR, Pattern.STRATEGY, Pattern.FEATHERS, Pattern.SPEAR, Pattern.STRATEGY, Pattern.SUMMON]
	for i in phalanx_size:
		shields.append(null)
		_slots_alive.append(false)


func get_wall_blocks() -> int:
	return _wall_blocks


func get_gap_hits() -> int:
	return _gap_hits


func get_strategy_hits() -> int:
	return _strategy_hits


func living_shields() -> int:
	return _slots_alive.count(true)


## 아테나에게서 본 자리(방향)의 칸 번호
func slot_of(at: Vector2) -> int:
	var a := wrapf(global_position.direction_to(at).angle(), 0.0, TAU)
	return int(round(a / (TAU / phalanx_size))) % phalanx_size


func slot_offset(i: int) -> Vector2:
	return Vector2.from_angle(TAU * i / phalanx_size) * 36.0


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		board = StrategyBoard.spawn(self, _area())
		if board != null:
			board.hit_callback = _on_strategy_hit
		form_phalanx(phalanx_size)
	return super._get_move_velocity(delta)


## 진형을 짬: 빈 자리를 count 명까지 채움 (테스트에서도 직접 호출)
func form_phalanx(count: int) -> void:
	if shield_scene == null or is_dead():
		return
	var need := count - living_shields()
	for i in phalanx_size:
		if need <= 0:
			break
		if not _slots_alive[i]:
			_pending_slot = i
			request_summon(shield_scene, global_position + slot_offset(i))
			_pending_slot = -1
			need -= 1
	_update_status()


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and _pending_slot >= 0:
		var s := minion as BossPart
		s.boss = self
		s.follow_boss = true
		s.anchor_offset = slot_offset(_pending_slot)
		s.max_hp = maxi(1, roundi(max_hp * shield_hp_ratio))
		s.hp = s.max_hp
		var slot := _pending_slot
		s.died.connect(func(_e: Enemy) -> void: _on_shield_fallen(slot))
		shields[slot] = s
		_slots_alive[slot] = true


func _on_shield_fallen(slot: int) -> void:
	_slots_alive[slot] = false
	shields[slot] = null
	if not is_dead():
		FloatingText.spawn(self, global_position + slot_offset(slot) + Vector2(0, -20), "빈틈!", Color(1.0, 0.85, 0.5), true)
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		_reform_left -= delta
		if _reform_left <= 0.0:
			_reform_left = reform_time
			_reforms += 1
			var size := maxi(phalanx_size - _reforms, 0)
			if size > living_shields():
				form_phalanx(size)
				GameManager.show_notice("아테나가 팔랑크스 진형을 다시 짠다 (방패병 %d명)" % size, Color(0.75, 0.85, 1.0))
		if Engine.get_physics_frames() % 15 == 0:
			_update_status()
	super._physics_process(delta)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and not is_dead() and has_target():
		# 팔랑크스: 플레이어 쪽 자리에 방패병이 있으면 방패벽
		if _slots_alive[slot_of(_player.global_position)]:
			_wall_blocks += 1
			amount = maxi(1, roundi(amount * wall_ratio))
			if _immune_text_cooldown <= 0.0:
				_immune_text_cooldown = 0.6
				FloatingText.spawn(self, global_position + Vector2(0, -50), "방패벽!", Color(0.75, 0.85, 1.0))
		else:
			_gap_hits += 1
		# 간파: 같은 무기만 계속 쓰면 그 무기 피해가 줄어듦
		var weapon := GameManager.equipped_weapon
		if weapon != null:
			var kind: int = weapon.weapon_type
			for k in insight.keys():
				if k != kind:
					insight[k] = maxi(int(insight[k]) - 2, 0)
			var stacks: int = int(insight.get(kind, 0))
			amount = maxi(1, roundi(amount * insight_multiplier(kind)))
			insight[kind] = stacks + 1
	super.take_damage(amount, knockback, is_crit, armor_pen)


func insight_multiplier(kind: int) -> float:
	return maxf(1.0 - insight_step * int(insight.get(kind, 0)), 1.0 - insight_cap)


func _on_strategy_hit(cells: Array) -> void:
	if is_dead() or not has_target() or board == null:
		return
	if cells.has(board.cell_of(_player.global_position)):
		_strategy_hits += 1
		_player.take_hit(roundi(strategy_damage * power), _player.global_position + Vector2(0, -10), self)


func _update_status() -> void:
	var text := "팔랑크스 %d명" % living_shields()
	var weapon := GameManager.equipped_weapon
	if weapon != null:
		var cut := 1.0 - insight_multiplier(weapon.weapon_type)
		if cut > 0.01:
			text += " · 간파: %s -%d%%" % [WEAPON_NAMES[clampi(weapon.weapon_type, 0, 3)], roundi(cut * 100.0)]
	set_status(text, Color(0.75, 0.85, 1.0))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SPEAR:
			for k in 3:
				var d := dir.rotated((k - 1) * 0.28)
				for i in 10:
					telegraph_strike(get_hit_center() + d * (40.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.HOLY)
			return 1.1
		Pattern.STRATEGY:
			if board != null:
				board.plan(4 if phase_two else 3, 6 if phase_two else 5, 1.4, 0.7 if phase_two else 0.8)
			GameManager.show_notice("아테나가 다음 세 수를 둔다 — 번호 순서대로 터진다", Color(0.75, 0.85, 1.0))
			return 1.0
		Pattern.FEATHERS:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 14:
						shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 125.0, feather_damage, feather_texture, 0.0, Elements.Type.HOLY))
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("아테나: 지혜는 언제나 한 수 앞선다! 전략의 수가 늘어나고 빨라진다", Color(0.75, 0.85, 1.0))
