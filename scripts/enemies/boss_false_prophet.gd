class_name BossFalseProphet
extends PatternBoss
## 86스테이지 보스: 거짓 예언자 — 어린양처럼 두 뿔이 났으나 용처럼 말하며 사람들에게 「짐승의 표」를 받게 한 자.
##   FIRE_SIGN : 하늘에서 내리는 불 (거짓 이적) — 플레이어 주변 장판
##   MARK      : 짐승의 표 — 붉은 예고 자리에 있으면 표가 찍힘
##   DECEIT    : 거짓말 탄막 (부채꼴)
##   SUMMON    : 짐승의 우상 · 표 받은 광신도 호출
##
## [기믹] 짐승의 표: 표가 찍혀 있는 동안(mark_time 초) 플레이어의 공격이 거짓 예언자에게 들어가지 않음
##   보스방 양쪽 「정화의 샘」에 들어가면 표가 씻겨 나감
## 체력 50% 이하: 표를 더 자주 찍음

enum Pattern { FIRE_SIGN, MARK, DECEIT, SUMMON }

const SPRING_SPOTS := [Vector2(-230, 100), Vector2(230, 100)]

@export var minion_scenes: Array[PackedScene] = []
@export var deceit_texture: Texture2D
@export var fire_damage: int = 92
@export var mark_damage: int = 50
@export var deceit_damage: int = 64
@export var mark_time: float = 15.0

var springs: Array[WaterPool] = []
var _mark_left: float = 0.0
var _marks: int = 0
var _cleanses: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.MARK, Pattern.FIRE_SIGN, Pattern.DECEIT, Pattern.FIRE_SIGN, Pattern.SUMMON]
	immune_text = "짐승의 표 — 정화의 샘에서 씻어라"


func is_player_marked() -> bool:
	return _mark_left > 0.0


func get_cleanse_count() -> int:
	return _cleanses


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		for spot in SPRING_SPOTS:
			springs.append(WaterPool.spawn(self, _area().get_center() + spot, 30.0))
	return super._get_move_velocity(delta)


## 짐승의 표 (테스트에서도 직접 호출)
func mark_player() -> void:
	if not has_target():
		return
	_marks += 1
	_mark_left = mark_time
	FloatingText.spawn(_player, _player.global_position + Vector2(0, -28), "짐승의 표!", Color(1.0, 0.3, 0.3), true)
	GameManager.show_notice("짐승의 표가 찍혔다! 정화의 샘에서 씻기 전엔 공격이 통하지 않는다", Color(1.0, 0.4, 0.4))


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_player_marked():
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started and has_target():
		if _mark_left > 0.0:
			_mark_left -= delta
			_player.mark_floor_status("짐승의 표 %.0f초 — 정화의 샘으로" % _mark_left)
			for s in springs:
				if is_instance_valid(s) and s.contains(_player.global_position):
					_mark_left = 0.0
					_cleanses += 1
					FloatingText.spawn(_player, _player.global_position + Vector2(0, -28), "표가 씻겨 나갔다", Color(0.6, 0.85, 1.0), true)
					break
		set_status("짐승의 표가 있는 동안 무적" if is_player_marked() else "거짓 예언자", Color(1.0, 0.45, 0.45))
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.FIRE_SIGN:
			for i in 6:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0)
				telegraph_strike(at, 22.0, 0.9 + 0.08 * i, fire_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.MARK:
			var at := _player.global_position
			var strike := telegraph_strike(at, 26.0, 0.8, mark_damage, Elements.Type.DARK)
			if strike != null:
				strike.color = Color(1.0, 0.25, 0.25)
			_after(0.8, func() -> void:
				if not is_dead() and has_target() and _player.global_position.distance_to(at) <= 28.0 and not _player.is_dashing():
					mark_player())
			return 1.1
		Pattern.DECEIT:
			for i in 9:
				shoot(dir.rotated((i - 4) * 0.14), 140.0, deceit_damage, deceit_texture, 0.0, Elements.Type.DARK)
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	pattern_order = [Pattern.MARK, Pattern.FIRE_SIGN, Pattern.MARK, Pattern.DECEIT, Pattern.SUMMON]
	GameManager.show_notice("거짓 예언자: 모두 표를 받으라! 표를 더 자주 찍는다", Color(1.0, 0.45, 0.45))
