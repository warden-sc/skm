class_name BossHeracles
extends PatternBoss
## 48스테이지 보스: 영웅 헤라클레스 (반신) — 네메아 사자 가죽을 두르고 몽둥이를 든 그리스 최고의 영웅.
## 체력 25% 구간마다 「과업」이 바뀌며 패턴이 달라짐
##   0 네메아의 사자    : 포효(고리 장판) · 사자 도약
##   1 레르나의 히드라  : 독화살 부채꼴
##   2 에리만토스 멧돼지: 일직선 돌진
##   3 스팀팔로스의 새  : 화살비(보스방 곳곳 장판)
##   공통: 몽둥이 휘두르기 · 소환
##
## [기믹 1] 네메아 사자 가죽: 근접 공격(검)이 통하지 않음 → 활·마법으로만 맞힘
## [기믹 2] 숨 고르기: 과업이 바뀔 때마다 rest_time 초 동안 가죽을 벗고 숨을 고름 → 이때는 검도 통하고 받는 피해 rest_multiplier 배

enum Pattern { LABOR, CLUB, LABOR2, SUMMON }

const LABOR_NAMES := ["네메아의 사자", "레르나의 히드라", "에리만토스의 멧돼지", "스팀팔로스의 새"]

@export var minion_scenes: Array[PackedScene] = []
@export var arrow_texture: Texture2D
@export var club_damage: int = 88
@export var roar_damage: int = 80
@export var arrow_damage: int = 58
@export var rush_damage: int = 90
@export var rest_time: float = 6.0
@export var rest_multiplier: float = 1.3

var labor: int = 0
var _rest_left: float = 0.0
var _rests: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.LABOR, Pattern.CLUB, Pattern.LABOR2, Pattern.SUMMON, Pattern.LABOR, Pattern.CLUB]
	immune_text = "사자 가죽! 검이 통하지 않음 (활·마법)"


func is_resting() -> bool:
	return _rest_left > 0.0


func get_rest_count() -> int:
	return _rests


func can_be_hit_by(kind: HitKind) -> bool:
	if kind == HitKind.MELEE and not is_resting():
		return false
	return super.can_be_hit_by(kind)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_dead() or amount <= 0:
		return
	if is_resting():
		amount = roundi(amount * rest_multiplier)
	super.take_damage(amount, knockback, is_crit, armor_pen)
	var next := clampi(int((1.0 - float(hp) / max_hp) * 4.0), 0, 3)
	if next > labor and not is_dead():
		labor = next
		begin_rest()


func _physics_process(delta: float) -> void:
	if _rest_left > 0.0 and not is_dead():
		_rest_left -= delta
		if _rest_left <= 0.0:
			base_tint = Color.WHITE
			set_status("과업: %s" % LABOR_NAMES[labor], Color(1.0, 0.85, 0.5))
			GameManager.show_notice("헤라클레스가 다시 사자 가죽을 두른다 — 과업 「%s」" % LABOR_NAMES[labor], Color(1.0, 0.85, 0.5))
	super._physics_process(delta)


func _get_move_velocity(delta: float) -> Vector2:
	if get_status_text() == "":
		set_status("과업: %s" % LABOR_NAMES[labor], Color(1.0, 0.85, 0.5))
	return super._get_move_velocity(delta)


# ============================================================ 기믹 2: 숨 고르기
func begin_rest() -> void:
	_rests += 1
	_rest_left = rest_time
	_stun_left = maxf(_stun_left, rest_time)
	base_tint = Color(1.0, 0.85, 0.75)
	set_status("숨 고르기 — 가죽을 벗었다! (검도 통함)", Color(1.0, 0.95, 0.7))
	GameManager.show_notice("과업을 마친 헤라클레스가 숨을 고른다! 사자 가죽을 벗은 지금은 검도 통한다", Color(1.0, 0.95, 0.7))


# ============================================================ 패턴
func _labor_attack() -> float:
	match labor:
		0:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 52.0, 22.0, 0.85, roar_damage, Elements.Type.EARTH)
			return 1.3
		1:
			var keep := burn_damage
			burn_damage = 9
			burn_is_poison = true
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.15), 170.0, arrow_damage, arrow_texture, 0.0, Elements.Type.NATURE)
			burn_damage = keep
			burn_is_poison = false
			return 1.0
		2:
			var dir := direction_to_player()
			var end := global_position
			for i in 10:
				var at := get_hit_center() + dir * (24.0 + 26.0 * i)
				if arena_rect.has_area() and not arena_rect.has_point(at):
					break
				telegraph_strike(at, 16.0, 0.8, rush_damage, Elements.Type.EARTH)
				end = at
			_after(0.8, func() -> void:
				if not is_dead() and not is_resting():
					global_position = end)
			return 1.3
	# 3: 스팀팔로스의 새 — 화살비
	var a := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
	for i in 12:
		var at := _player.global_position if i == 0 else Vector2(randf_range(a.position.x, a.end.x), randf_range(a.position.y, a.end.y))
		telegraph_strike(at, 18.0, 0.8 + 0.06 * i, arrow_damage + 10, Elements.Type.NATURE)
	return 1.6


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.LABOR, Pattern.LABOR2:
			return _labor_attack()
		Pattern.CLUB:
			var dir := direction_to_player()
			for i in 5:
				telegraph_strike(get_hit_center() + dir.rotated((i - 2) * 0.35) * 46.0, 22.0, 0.75, club_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("헤라클레스: 과업은 아직 반이나 남았다!", Color(1.0, 0.85, 0.5))
