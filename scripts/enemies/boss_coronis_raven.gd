class_name BossCoronisRaven
extends PatternBoss
## 65스테이지 보스: 코로니스의 까마귀 — 원래 눈처럼 희었지만, 코로니스의 배신을 전한 죄로 아폴론이 새까맣게 태워 버린 까마귀.
##   FEATHERS : 깃털 세례 (흰 깃 = 빠르고 곧게 / 검은 깃 = 사방으로)
##   DIVE     : 일직선 급강하
##   CAW      : 울음 — 몸 주위 고리
##   SUMMON   : 검은 까마귀 호출
##
## [기믹] 흰 깃털 ↔ 검은 깃털: white_time 초 동안 흰 까마귀, black_time 초 동안 검은 까마귀로 번갈아 바뀜
## [기믹] 그림자 분신: 검게 변하면 똑같이 생긴 분신 clone_count 마리가 함께 날아다님 — 분신에게는 그림자가 없음
##   분신을 때리면 사라지며 깃털을 흩뿌림. 그림자가 있는 진짜를 때리면 분신이 모두 사라지고 정체가 드러나 휘청임 → 다시 흰 깃털로
## 체력 50% 이하: 분신이 늘어남

enum Pattern { FEATHERS, DIVE, CAW, SUMMON }

@export var shade_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var feather_texture: Texture2D
@export var feather_damage: int = 58
@export var dive_damage: int = 90
@export var caw_damage: int = 80
@export var white_time: float = 10.0
@export var black_time: float = 8.0
@export var clone_count: int = 4
@export var clone_hp_ratio: float = 0.01

var clones: Array[Enemy] = []
var _black: bool = false
var _phase_left: float = 10.0
var _reveals: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.FEATHERS, Pattern.DIVE, Pattern.CAW, Pattern.FEATHERS, Pattern.SUMMON]
	_phase_left = white_time
	_update_status()


func is_black() -> bool:
	return _black


func get_clones() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for c in clones:
		if is_instance_valid(c) and not c.is_dead():
			alive.append(c)
	return alive


func get_reveal_count() -> int:
	return _reveals


func _physics_process(delta: float) -> void:
	if not is_dead() and has_target():
		_phase_left -= delta
		if _phase_left <= 0.0:
			if _black:
				turn_white()
			else:
				turn_black()
	super._physics_process(delta)


## 검은 깃털 + 그림자 분신 (테스트에서도 직접 호출)
func turn_black() -> void:
	if _black or is_dead():
		return
	_black = true
	_phase_left = black_time
	base_tint = Color(0.35, 0.35, 0.45)
	if shade_scene != null:
		for i in clone_count + (2 if phase_two else 0):
			request_summon(shade_scene, global_position + Vector2.from_angle(TAU * i / clone_count) * 70.0)
	Fx.burst(self, get_hit_center(), Color(0.1, 0.1, 0.15), 30, 80.0, 0.6)
	GameManager.show_notice("까마귀가 새까맣게 타오르며 분신이 생겨났다! 그림자가 있는 진짜를 찾아라", Color(0.7, 0.7, 0.85))
	_update_status()


func turn_white() -> void:
	_black = false
	_phase_left = white_time
	base_tint = Color.WHITE
	for c in get_clones():
		c.despawn()
	clones.clear()
	_update_status()


func register_minion(minion: Enemy) -> void:
	if shade_scene != null and minion.scene_file_path == shade_scene.resource_path:
		minion.max_hp = maxi(1, roundi(max_hp * clone_hp_ratio))
		minion.hp = minion.max_hp
		minion.base_tint = base_tint
		var shadow := minion.get_node_or_null(^"Shadow") as CanvasItem
		if shadow != null:
			shadow.visible = false  # 분신에게는 그림자가 없음
		minion.died.connect(_on_clone_died)
		clones.append(minion)


func _on_clone_died(clone: Enemy) -> void:
	var at := clone.get_hit_center()
	FloatingText.spawn(clone, at + Vector2(0, -20), "가짜!", Color(0.8, 0.8, 0.9), true)
	if has_target():
		for i in 6:
			shoot(at.direction_to(_player.global_position).rotated((i - 2.5) * 0.25), 150.0, feather_damage, feather_texture, 0.0, Elements.Type.DARK, at)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if _black and not is_dead() and amount > 0:
		reveal()


## 진짜가 맞으면 정체가 드러남
func reveal() -> void:
	_reveals += 1
	turn_white()
	stun(6.0)
	GameManager.show_notice("그림자가 있는 진짜를 찾았다! 까마귀가 하얗게 질려 휘청인다", Color(0.9, 0.9, 1.0))


func _update_status() -> void:
	if _black:
		set_status("검은 깃털 — 그림자가 있는 진짜를 찾아라", Color(0.7, 0.7, 0.85))
	else:
		set_status("흰 깃털", Color(0.95, 0.95, 1.0))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.FEATHERS:
			if _black:
				for i in 16:
					shoot(Vector2.from_angle(TAU * i / 16.0), 115.0, feather_damage, feather_texture, 0.0, Elements.Type.DARK)
			else:
				for w in 3:
					_after(0.2 * w, func() -> void:
						if is_dead() or not has_target():
							return
						var aim := direction_to_player()
						for i in 5:
							shoot(aim.rotated((i - 2) * 0.1), 210.0, feather_damage, feather_texture, 0.0, Elements.Type.HOLY))
			return 1.0
		Pattern.DIVE:
			for i in 10:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 16.0, 0.6 + 0.03 * i, dive_damage, Elements.Type.NONE)
			return 1.1
		Pattern.CAW:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 48.0, 20.0, 0.85, caw_damage, Elements.Type.DARK)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	for c in get_clones():
		c.despawn()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("까마귀가 날카롭게 운다! 분신이 늘어난다", Color(0.7, 0.7, 0.85))
