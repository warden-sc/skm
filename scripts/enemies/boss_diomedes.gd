class_name BossDiomedes
extends PatternBoss
## 73스테이지 보스: 영웅 디오메데스 — 아테나에게 신을 알아보는 눈을 받아 전장에서 아레스까지 찌른 아르고스의 영웅.
##   SPEAR    : 창 찌르기 (일직선 둘)
##   JAVELIN  : 투창 세례
##   BOULDER  : 두 사람도 못 들 바위를 던짐 (큰 장판)
##   SUMMON   : 아르고스 창병 · 안개 망령 호출
##
## [기믹] 안개의 전장: 보스방이 짙은 안개에 덮여 디오메데스와 병사들이 거의 보이지 않음
##   보스방의 「아테나의 등불」 둘레(light_radius)만 안개가 걷힘 — 등불 밖에 있는 디오메데스는 공격이 빗맞아 피해 x fog_ratio
##   등불은 집어 들고 다닐 수 있음 (들고 있는 동안 맞으면 떨어뜨리고 제자리로 돌아감)
## 체력 50% 이하: 안개가 짙어져 등불 둘레가 좁아짐

enum Pattern { SPEAR, JAVELIN, BOULDER, SUMMON }

const LAMP_SPOT := Vector2(0, 60)

@export var minion_scenes: Array[PackedScene] = []
@export var lamp_texture: Texture2D
@export var javelin_texture: Texture2D
@export var spear_damage: int = 98
@export var javelin_damage: int = 62
@export var boulder_damage: int = 96
@export var light_radius: float = 100.0
@export var fog_ratio: float = 0.25

var lamp: CarryItem
var veil: FogVeil
var _fog_hits: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPEAR, Pattern.JAVELIN, Pattern.BOULDER, Pattern.SPEAR, Pattern.SUMMON]


func get_fog_hits() -> int:
	return _fog_hits


func light_position() -> Vector2:
	return lamp.global_position if lamp != null and is_instance_valid(lamp) else _area().get_center() + LAMP_SPOT


func is_lit(at: Vector2) -> bool:
	return at.distance_to(light_position()) <= light_radius * (0.8 if phase_two else 1.0)


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		lamp = CarryItem.spawn(self, _area().get_center() + LAMP_SPOT, lamp_texture, "아테나의 등불", Color(1.0, 0.9, 0.6))
		veil = FogVeil.spawn(self, _area())
		Net.announce("짙은 안개가 전장을 덮었다! 아테나의 등불 곁에서만 적이 보인다", Color(0.85, 0.88, 0.95))
	return super._get_move_velocity(delta)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		var radius := light_radius * (0.8 if phase_two else 1.0)
		if veil != null and is_instance_valid(veil):
			veil.light_at = light_position()
			veil.light_radius = radius
		# 안개 밖의 적은 거의 보이지 않음
		for e in get_tree().get_nodes_in_group(&"enemies"):
			var enemy := e as Enemy
			if enemy != null and not enemy.is_dead() and enemy.is_inside_tree():
				enemy.sprite.modulate.a = 1.0 if is_lit(enemy.global_position) else 0.1
		set_status("안개 속 — 등불 곁으로 끌어들여라" if not is_lit(global_position) else "등불에 드러남", Color(0.85, 0.88, 0.95))
	super._physics_process(delta)


## 안개 밖에서는 공격이 빗맞음
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and _started and not is_lit(global_position):
		_fog_hits += 1
		amount = maxi(1, roundi(amount * fog_ratio))
		if _immune_text_cooldown <= 0.0:
			_immune_text_cooldown = 0.6
			FloatingText.spawn(self, global_position + Vector2(0, -44), "안개 속 — 빗맞음", Color(0.85, 0.88, 0.95))
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SPEAR:
			for k in 2:
				var d := dir.rotated((k - 0.5) * 0.3)
				for i in 10:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.NONE)
			return 1.1
		Pattern.JAVELIN:
			for i in 5:
				shoot(dir.rotated((i - 2) * 0.2), 200.0, javelin_damage, javelin_texture)
			return 0.9
		Pattern.BOULDER:
			telegraph_strike(_player.global_position, 44.0, 1.1, boulder_damage, Elements.Type.EARTH)
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Enemy and (e as Enemy).is_inside_tree():
			(e as Enemy).sprite.modulate.a = 1.0
	super._die()


func _on_phase_two() -> void:
	Net.announce("디오메데스: 안개 속에서도 나는 너를 본다! 안개가 짙어진다", Color(0.85, 0.88, 0.95))
