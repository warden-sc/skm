class_name BossSeraphine
extends PatternBoss
## 36스테이지 보스: 심판의 천사 세라핀 — 하늘 성채의 법정을 지키는 여섯 날개의 천사.
##   LANCE    : 성창 — 플레이어 쪽 일직선 장판
##   FEATHERS : 깃털 비 — 깃털 탄 부채꼴 두 겹
##   HALO     : 후광 — 사방으로 퍼지는 빛의 고리
##   STIGMA   : 성흔 — 느린 빛 구체 3발, 맞으면 「성흔」(포션 회복이 피해로)
##   SUMMON   : 천사 병사 · 오파님 호출
##
## [기믹 1] 천칭: 보스방을 왼쪽·오른쪽으로 나눠, 플레이어가 각 쪽에 서서 준 피해가 저울에 쌓임
##   한쪽이 tilt_limit(보스 최대 체력 비율) 이상 무거워지면 「심판」 → 무거운 쪽 절반 전체에 심판의 빛
##   (judge_warn 초 예고 후 최대 체력의 judge_ratio 피해, 가드·대시 불가) → 저울은 다시 0
##   → 양쪽을 오가며 번갈아 공격해야 심판을 피할 수 있음
## [기믹 2] 성흔: 성흔 구체·성창에 맞으면 stigma_time 초 동안 포션의 회복이 피해로 바뀜
## 체력 50% 이하: 저울이 더 쉽게 기울고, 심판 예고가 짧아짐

enum Pattern { LANCE, FEATHERS, HALO, STIGMA, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var feather_texture: Texture2D
@export var light_texture: Texture2D
@export var lance_damage: int = 76
@export var feather_damage: int = 50
@export var halo_damage: int = 52
@export var stigma_damage: int = 40
@export var stigma_time: float = 8.0
@export var tilt_limit: float = 0.05
@export var judge_warn: float = 1.6
@export var judge_ratio: float = 0.45

var scale_node: JudgementScale
var _judging: bool = false
var _judge_side: int = -1
var _judgements: int = 0
var _judge_hits: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.FEATHERS, Pattern.LANCE, Pattern.HALO, Pattern.STIGMA, Pattern.SUMMON, Pattern.LANCE]


func get_judgement_scale() -> JudgementScale:
	return scale_node if scale_node != null and is_instance_valid(scale_node) else null


func is_judging() -> bool:
	return _judging


func get_judgement_count() -> int:
	return _judgements


func get_judge_hits() -> int:
	return _judge_hits


func _get_move_velocity(delta: float) -> Vector2:
	if get_judgement_scale() == null and has_target():
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))
		scale_node = JudgementScale.spawn(self, area, max_hp * tilt_limit)
	return super._get_move_velocity(delta)


# ============================================================ 기믹 1: 천칭
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	var before := hp
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if is_dead() or get_judgement_scale() == null or not has_target() or _judging:
		return
	scale_node.add_weight(scale_node.side_of(_player.global_position), float(before - hp))
	var limit := max_hp * tilt_limit * (0.75 if phase_two else 1.0)
	var diff: float = scale_node.weights[JudgementScale.Side.RIGHT] - scale_node.weights[JudgementScale.Side.LEFT]
	if absf(diff) >= limit:
		begin_judgement(JudgementScale.Side.RIGHT if diff > 0.0 else JudgementScale.Side.LEFT)


## 심판 시작 (테스트에서도 직접 호출)
func begin_judgement(side: int) -> void:
	if _judging or get_judgement_scale() == null:
		return
	_judging = true
	_judge_side = side
	var warn_time := judge_warn * (0.75 if phase_two else 1.0)
	scale_node.warn(side, warn_time)
	var side_name := "왼쪽" if side == JudgementScale.Side.LEFT else "오른쪽"
	set_status("천칭이 기울었다 — %s에 심판!" % side_name, Color(1.0, 0.9, 0.5))
	Net.announce("천칭이 %s으로 기울었다! 심판의 빛이 내린다 — 반대쪽으로 피하라" % side_name, Color(1.0, 0.9, 0.5))
	_after(warn_time, _resolve_judgement)


func _resolve_judgement() -> void:
	_judging = false
	_judgements += 1
	if get_judgement_scale() == null:
		return
	scale_node.clear_warn()
	var c := scale_node.area.get_center()
	var half_center := Vector2(c.x + (scale_node.area.size.x * 0.25 if _judge_side == JudgementScale.Side.RIGHT else -scale_node.area.size.x * 0.25), c.y)
	for i in 6:
		Fx.pillar(self, half_center + Vector2(randf_range(-150, 150), randf_range(-150, 150)), Color(1.0, 0.95, 0.6), 18.0, 160.0, 0.5)
	if has_target() and not is_dead() and scale_node.is_in_side(_player.global_position, _judge_side):
		if _player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * judge_ratio)), _player.global_position + Vector2(0, -20), false) == Player.HitResult.DAMAGED:
			_judge_hits += 1
	scale_node.reset()
	set_status("", Color.WHITE)


# ============================================================ 패턴
func _shoot_stigma(dir: Vector2) -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var spec := ProjectileSpec.enemy_bullet(get_hit_center(), dir, 90.0, roundi(stigma_damage * power), light_texture, 0.0, Elements.Type.HOLY)
	spec.stigma_duration = stigma_time
	pool.spawn(spec)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.LANCE:
			var dir := direction_to_player()
			for i in 10:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 15.0, 0.65 + 0.04 * i, lance_damage, Elements.Type.HOLY)
			return 1.2
		Pattern.FEATHERS:
			var aim := direction_to_player()
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 7:
						shoot(aim.rotated((i - 3) * 0.17 + w * 0.08), 150.0, feather_damage, feather_texture, 0.0, Elements.Type.HOLY))
			return 1.1
		Pattern.HALO:
			for w in 2:
				_after(0.35 * w, func() -> void:
					if is_dead():
						return
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2), 110.0, halo_damage, light_texture, 0.0, Elements.Type.HOLY))
			return 1.1
		Pattern.STIGMA:
			var aim2 := direction_to_player()
			for a in [-0.3, 0.0, 0.3]:
				_shoot_stigma(aim2.rotated(a))
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if get_judgement_scale() != null:
		scale_node.queue_free()
	super._die()


func _on_phase_two() -> void:
	Net.announce("세라핀: 죄의 무게를 달아 보겠다… 천칭이 더 쉽게 기운다", Color(1.0, 0.9, 0.5))
