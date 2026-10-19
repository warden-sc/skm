class_name BossBellerophon
extends PatternBoss
## 74스테이지 보스: 페가수스를 탄 벨레로폰 — 아테나의 황금 굴레로 페가수스를 길들여 키마이라를 무찌른 영웅.
##   LANCE   : 하늘에서 내리꽂는 창 (일직선)
##   SWOOP   : 플레이어 쪽으로 낮게 급강하해 스쳐 지나감 (지나간 줄이 터짐)
##   GALE    : 날갯바람 — 깃털 탄막
##   SUMMON  : 어린 키마이라 · 솔리모이 전사 호출
##
## [기믹] 천마: 페가수스를 타고 있는 동안은 하늘 높이 — 활만 닿음
## [기믹] 아테나의 황금 굴레: 보스방에 놓인 굴레를 집어 들고, 낮게 스쳐 가는 페가수스에 닿으면(tame_reach) 굴레가 씌워짐
##   → 길들여진 페가수스가 벨레로폰을 떨어뜨리고 날아감: 오래 기절 + 그 뒤로 땅에서 싸움 (근접도 통함, 방어력 -fall_defense)
##   굴레를 든 채 맞으면 떨어뜨림
## 체력 50% 이하: 급강하가 잦아짐

enum Pattern { LANCE, SWOOP, GALE, SUMMON }

const FLIGHT_HEIGHT := 16.0
const BRIDLE_SPOT := Vector2(-160, 100)

@export var minion_scenes: Array[PackedScene] = []
@export var bridle_texture: Texture2D
@export var feather_texture: Texture2D
@export var lance_damage: int = 98
@export var swoop_damage: int = 92
@export var feather_damage: int = 60
@export var tame_reach: float = 40.0
@export var fall_defense: int = 20

var bridle: CarryItem
var _fallen: bool = false
var _swoop_dir: Vector2 = Vector2.ZERO
var _swoop_left: float = 0.0
var _base_defense: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	airborne = true
	immune_text = "하늘 높이! 활만 닿음 — 황금 굴레를 씌워라"
	pattern_order = [Pattern.LANCE, Pattern.SWOOP, Pattern.GALE, Pattern.SWOOP, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_defense = defense


func is_fallen() -> bool:
	return _fallen


func is_swooping() -> bool:
	return _swoop_left > 0.0


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		bridle = CarryItem.spawn(self, _area().get_center() + BRIDLE_SPOT, bridle_texture, "황금 굴레", Color(1.0, 0.85, 0.3))
		_update_status()
	if _swoop_left > 0.0:
		_swoop_left -= delta
		return _swoop_dir * 300.0
	return super._get_move_velocity(delta)


## 날아 있을 땐 플레이어 주위를 크게 맴돎
func _chase_velocity(delta: float) -> Vector2:
	if _fallen:
		return super._chase_velocity(delta) * 0.8
	var orbit := (global_position - _player.global_position).normalized().rotated(0.8) * 130.0 + _player.global_position
	return global_position.direction_to(orbit) * move_speed * 1.8


func _physics_process(delta: float) -> void:
	if not is_dead() and _started and not _fallen and has_target():
		if bridle != null and is_instance_valid(bridle) and bridle.is_carried() and global_position.distance_to(_player.global_position) <= tame_reach:
			tame()
	super._physics_process(delta)


## 황금 굴레를 씌움 (테스트에서도 직접 호출)
func tame() -> void:
	if _fallen or is_dead():
		return
	_fallen = true
	_swoop_left = 0.0
	airborne = false
	defense = maxi(_base_defense - fall_defense, 0)
	if bridle != null and is_instance_valid(bridle):
		bridle.hide_for(99999.0)
	super.stun(10.0)
	Fx.burst(self, get_hit_center(), Color(1.0, 0.95, 0.8), 30, 90.0, 0.8, Vector2(0, -80))
	GameManager.show_notice("황금 굴레에 길들여진 페가수스가 벨레로폰을 떨어뜨리고 날아간다!", Color(1.0, 0.9, 0.5))
	_update_status()


func _update_status() -> void:
	if _fallen:
		set_status("땅에 떨어짐 (방어력 -%d)" % Balance.scale(fall_defense), Color(1.0, 0.6, 0.5))
	else:
		set_status("천마를 탐 — 활만 닿음 · 황금 굴레를 씌워라", Color(0.9, 0.95, 1.0))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	if pattern == Pattern.SWOOP and _fallen:
		pattern = Pattern.LANCE
	match pattern:
		Pattern.LANCE:
			for i in 11:
				telegraph_strike(get_hit_center() + dir * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, lance_damage, Elements.Type.LIGHTNING)
			return 1.1
		Pattern.SWOOP:
			_swoop_dir = dir
			_swoop_left = 0.75 if phase_two else 0.6
			for i in 9:
				telegraph_strike(global_position + dir * (30.0 + 24.0 * i), 16.0, 0.75 + 0.03 * i, swoop_damage, Elements.Type.NONE)
			return 1.2
		Pattern.GALE:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 14:
						shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 125.0, feather_damage, feather_texture, 0.0, Elements.Type.NONE))
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if airborne:
		sprite.position.y += -FLIGHT_HEIGHT + sin(_anim_time * 4.0) * 2.0


func _on_phase_two() -> void:
	if not _fallen:
		pattern_order = [Pattern.SWOOP, Pattern.LANCE, Pattern.SWOOP, Pattern.GALE, Pattern.SUMMON]
	GameManager.show_notice("벨레로폰: 올림포스까지 날아오르리라! 급강하가 잦아진다", Color(0.9, 0.95, 1.0))
