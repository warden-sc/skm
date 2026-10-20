class_name BossGoldStatue
extends PatternBoss
## 93스테이지 보스: 느부갓네살의 금 신상 — 꿈에 본 큰 신상: 머리는 금, 가슴과 팔은 은, 배는 놋, 다리는 철, 발은 철과 진흙.
##   GOLD_BEAM   : 금 머리의 빛줄기 (일직선)
##   SILVER_ARMS : 은 팔 휘두르기 (좌우 부채꼴)
##   BRONZE_QUAKE: 놋 배의 울림 — 몸 주위 고리
##   SUMMON      : 바빌론 창병 · 갈대아 점성술사 · 풀무불 정령 호출
##
## [기믹] 부위마다 다른 단단함: 금 머리 25% · 은 가슴 40% · 놋 배 55% · 철 다리 75% 만 피해가 들어감 (몸통에 바로 맞으면 body_ratio)
## [기믹] 진흙 발: 발 둘(각각 보스 체력의 foot_hp_ratio)을 모두 깨면 신상이 무너져 collapse_time 초 동안 기절 + 피해 collapse_ratio 배
##   발은 foot_regrow 초 뒤 다시 붙음
## [기믹] 뜨인 돌: stone_interval 초마다 손대지 않고 뜨인 돌이 보스방을 가로질러 굴러감 (굴러갈 길이 미리 보임)
##   그 길로 신상을 끌어들이면 돌이 신상을 쳐서 발이 깨지고 최대 체력의 stone_hit_ratio 피해 — 플레이어도 맞으면 큰 피해

enum Pattern { GOLD_BEAM, SILVER_ARMS, BRONZE_QUAKE, SUMMON }

const SECTION_NAMES := ["금 머리", "은 가슴", "놋 배", "철 다리"]
const SECTION_RATIOS := [0.25, 0.4, 0.55, 0.75]
const SECTION_OFFSETS := [Vector2(0, -66), Vector2(0, -46), Vector2(0, -30), Vector2(0, -12)]
const FOOT_OFFSETS := [Vector2(-8, 8), Vector2(8, 8)]

@export var section_scene: PackedScene
@export var foot_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var stone_texture: Texture2D
@export var beam_damage: int = 104
@export var arm_damage: int = 100
@export var quake_damage: int = 94
@export var stone_damage: int = 110
@export var body_ratio: float = 0.3
@export var foot_hp_ratio: float = 0.02
@export var collapse_time: float = 8.0
@export var collapse_ratio: float = 1.6
@export var foot_regrow: float = 20.0
@export var stone_interval: float = 14.0
@export var stone_hit_ratio: float = 0.06

var sections: Array[BossPart] = []
var feet: Array[BossPart] = []
var stone: RollingStone
var _pending: Array[int] = []  # 소환 요청 순서대로 -1~-2 = 발, 0~3 = 부위
var _collapse_left: float = 0.0
var _regrow_left: float = 0.0
var _stone_left: float = 0.0
var _stone_hits: int = 0
var _collapses: int = 0
var _hit_frame: int = -1
var _hit_best: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.GOLD_BEAM, Pattern.SILVER_ARMS, Pattern.BRONZE_QUAKE, Pattern.GOLD_BEAM, Pattern.SUMMON]


func is_collapsed() -> bool:
	return _collapse_left > 0.0


func get_stone_hits() -> int:
	return _stone_hits


func get_collapse_count() -> int:
	return _collapses


func living_feet() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for f in feet:
		if is_instance_valid(f) and not f.is_dead():
			alive.append(f)
	return alive


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		_stone_left = stone_interval * 0.6
		for i in SECTION_OFFSETS.size():
			_pending.append(i)
			request_summon(section_scene, global_position + SECTION_OFFSETS[i])
		_grow_feet()
		_update_status()
	if is_collapsed():
		return Vector2.ZERO
	return super._get_move_velocity(delta) * 0.7


func _grow_feet() -> void:
	feet.clear()
	for i in FOOT_OFFSETS.size():
		_pending.append(-1 - i)
		request_summon(foot_scene, global_position + FOOT_OFFSETS[i])


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart or _pending.is_empty():
		return
	var slot: int = _pending.pop_front()
	var p := minion as BossPart
	p.boss = self
	p.follow_boss = true
	p.bob_amount = 0.0
	if slot >= 0:
		p.anchor_offset = SECTION_OFFSETS[slot]
		p.relay_ratio = SECTION_RATIOS[slot]
		p.show_bar = false
		p.display_name = "금 신상의 %s" % SECTION_NAMES[slot]
		p.visible = false  # 판정만 하는 부위 (몸은 신상 그림 그대로)
		sections.append(p)
	else:
		p.anchor_offset = FOOT_OFFSETS[-1 - slot]
		p.max_hp = maxi(1, roundi(max_hp * foot_hp_ratio))
		p.hp = p.max_hp
		p.died.connect(_on_foot_broken)
		feet.append(p)


func _on_foot_broken(_f: Enemy) -> void:
	if is_dead():
		return
	if living_feet().is_empty() and not is_collapsed():
		collapse()
	else:
		Net.announce("진흙 발 하나가 부서졌다! 하나 남았다", Color(0.85, 0.7, 0.5))
	_update_status()


## 신상이 무너짐 (테스트에서도 직접 호출)
func collapse() -> void:
	if is_dead():
		return
	for f in living_feet():
		f.despawn()
	_collapses += 1
	_collapse_left = collapse_time
	_regrow_left = foot_regrow
	super.stun(collapse_time)
	Fx.explosion(self, global_position, Color(0.85, 0.7, 0.45), 60.0, 2)
	Net.announce("진흙 발이 부서져 금 신상이 무너졌다! 지금 몰아쳐라 (피해 x%.1f)" % collapse_ratio, Color(1.0, 0.85, 0.4))
	_update_status()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	_apply_hit(amount, knockback, is_crit, armor_pen, body_ratio)


func take_weak_point_hit(amount: int, knockback: Vector2, is_crit: bool, armor_pen: int, ratio: float) -> void:
	_apply_hit(amount, knockback, is_crit, armor_pen, ratio)


## 한 공격이 여러 부위에 한꺼번에 닿으면 가장 무른 부위 하나만 셈
func _apply_hit(amount: int, knockback: Vector2, is_crit: bool, armor_pen: int, ratio: float) -> void:
	if is_dead() or amount <= 0:
		return
	var frame := Engine.get_physics_frames()
	if frame != _hit_frame:
		_hit_frame = frame
		_hit_best = 0.0
	if ratio <= _hit_best:
		return
	var r := ratio - _hit_best
	_hit_best = ratio
	var mult := collapse_ratio if is_collapsed() else 1.0
	super.take_damage(maxi(1, roundi(amount * r * mult)), knockback, is_crit, armor_pen)


## 뜨인 돌을 굴림 (테스트에서도 직접 호출)
func roll_stone(start: Vector2, end: Vector2, warn: float = 2.5) -> void:
	if stone != null and is_instance_valid(stone):
		stone.queue_free()
	stone = RollingStone.spawn(self, start, end, stone_texture, roundi(stone_damage * power), warn)
	if stone != null:
		var struck := [false]
		stone.hit_callback = func(at: Vector2) -> void:
			if not struck[0] and not is_dead() and at.distance_to(global_position + Vector2(0, -16)) < 34.0:
				struck[0] = true
				_on_stone_struck()
	Net.announce("손대지 않고 뜨인 돌이 굴러오려 한다 — 신상을 그 길로 끌어들여라", Color(0.95, 0.9, 0.8))


func _on_stone_struck() -> void:
	_stone_hits += 1
	super.take_damage(roundi(max_hp * stone_hit_ratio), Vector2.ZERO, true, 999999)
	if not is_dead() and not is_collapsed():
		collapse()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _collapse_left > 0.0:
			_collapse_left -= delta
			if _collapse_left <= 0.0:
				Net.announce("금 신상이 다시 일어선다", Color(1.0, 0.85, 0.4))
				_update_status()
		elif _regrow_left > 0.0:
			_regrow_left -= delta
			if _regrow_left <= 0.0:
				_grow_feet()
				_update_status()
		_stone_left -= delta
		if _stone_left <= 0.0:
			_stone_left = stone_interval * (0.7 if phase_two else 1.0)
			var area := _area().grow(-16.0)
			var across := randf() < 0.5
			var line := clampf(global_position.y - 16.0 + randf_range(-80.0, 80.0), area.position.y, area.end.y) if across else clampf(global_position.x + randf_range(-80.0, 80.0), area.position.x, area.end.x)
			var flip := randf() < 0.5
			if across:
				roll_stone(Vector2(area.end.x if flip else area.position.x, line), Vector2(area.position.x if flip else area.end.x, line))
			else:
				roll_stone(Vector2(line, area.end.y if flip else area.position.y), Vector2(line, area.position.y if flip else area.end.y))
	super._physics_process(delta)


func _update_status() -> void:
	if is_collapsed():
		set_status("무너짐 — 피해 x%.1f" % collapse_ratio, Color(1.0, 0.85, 0.4))
	else:
		set_status("진흙 발 %d/2 · 금 25%% · 은 40%% · 놋 55%% · 철 75%%" % living_feet().size(), Color(1.0, 0.85, 0.4))


func _run_pattern(pattern: int) -> float:
	if not has_target() or is_collapsed():
		return 0.5
	var dir := direction_to_player()
	var head := global_position + SECTION_OFFSETS[0]
	match pattern:
		Pattern.GOLD_BEAM:
			for i in 13:
				telegraph_strike(head + (_player.global_position - head).normalized() * (24.0 + 22.0 * i), 14.0, 0.65 + 0.03 * i, beam_damage, Elements.Type.HOLY)
		Pattern.SILVER_ARMS:
			for side in [-1.0, 1.0]:
				for i in 5:
					telegraph_strike(global_position + dir.rotated(side * (0.7 + 0.22 * i)) * 58.0, 22.0, 0.8, arm_damage, Elements.Type.NONE)
		Pattern.BRONZE_QUAKE:
			for ring in 2:
				for i in 12:
					telegraph_strike(global_position + Vector2.from_angle(TAU * i / 12.0 + ring * 0.26) * (50.0 + 34.0 * ring), 18.0, 0.8 + 0.25 * ring, quake_damage, Elements.Type.EARTH)
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.2


func _die() -> void:
	if stone != null and is_instance_valid(stone):
		stone.queue_free()
	super._die()
