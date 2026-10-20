class_name BossMichael
extends PatternBoss
## 99스테이지 보스: 천군의 장 대천사 미카엘 — 「하늘에 전쟁이 있으니 미카엘과 그의 사자들이 용과 더불어 싸울새」.
##   SWORD     : 불칼 휘두르기 (앞쪽 부채꼴)
##   JUDGEMENT : 심판의 빛 — 몸 주위 고리 두 겹
##   SPEARS    : 천군의 창 비 — 플레이어 주변 장판
##   SUMMON    : 천군 창병 · 천군 궁수 · 붉은 용의 새끼 호출
##
## [기믹] 하늘의 전쟁: 보스방 둘레를 붉은 용이 날며 breath_interval 초마다 플레이어 쪽으로 불길을 뿜음 (불길 길이 미리 보임)
##   불길이 미카엘을 덮치면 미카엘이 최대 체력의 dragon_hit_ratio 피해를 입고 잠깐 휘청 → 불길 길 위로 미카엘을 끌어들이기
## [기믹] 「누가 하나님과 같으랴」: shield_interval 초마다 빛나는 방패를 shield_time 초 동안 듦 (그동안 움직이지 않음)
##   방패 앞쪽에서 들어온 공격은 막히고 피해의 reflect_ratio 만큼 반사됨 — 옆이나 뒤로 돌아가 때리기

enum Pattern { SWORD, JUDGEMENT, SPEARS, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var dragon_texture: Texture2D
@export var sword_damage: int = 108
@export var judgement_damage: int = 96
@export var spear_damage: int = 100
@export var breath_damage: int = 104
@export var breath_interval: float = 7.0
@export var dragon_hit_ratio: float = 0.035
@export var shield_interval: float = 12.0
@export var shield_time: float = 4.0
@export var reflect_ratio: float = 0.3

var dragon: FieldProp
var shield_dir: Vector2 = Vector2.DOWN
var _dragon_angle: float = 0.0
var _breath_left: float = 0.0
var _shield_left: float = 0.0
var _shield_cd: float = 0.0
var _reflect_cd: float = 0.0
var _dragon_hits: int = 0
var _reflected: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SWORD, Pattern.SPEARS, Pattern.JUDGEMENT, Pattern.SWORD, Pattern.SUMMON]


func is_shielded() -> bool:
	return _shield_left > 0.0


func get_dragon_hits() -> int:
	return _dragon_hits


func get_reflected() -> int:
	return _reflected


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func dragon_position() -> Vector2:
	var area := _area()
	return area.get_center() + Vector2(cos(_dragon_angle) * area.size.x * 0.42, sin(_dragon_angle) * area.size.y * 0.4)


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		dragon = FieldProp.spawn(self, dragon_position(), dragon_texture, Color(1.0, 0.4, 0.2))
		if dragon != null:
			dragon.z_index = 2
		_breath_left = breath_interval * 0.6
		_shield_cd = shield_interval * 0.5
		_update_status()
	if is_shielded():
		return Vector2.ZERO
	return super._get_move_velocity(delta)


## 붉은 용이 target 쪽으로 불길을 뿜음 (테스트에서도 직접 호출)
func breathe_at(target: Vector2, delay: float = 0.9) -> void:
	if is_dead():
		return
	var from := dragon_position()
	var dir := from.direction_to(target)
	var points: Array[Vector2] = []
	for i in 16:
		var at := from + dir * (26.0 + 24.0 * i)
		if not _area().grow(20.0).has_point(at):
			break
		points.append(at)
		var strike := telegraph_strike(at, 18.0, delay + 0.02 * i, breath_damage, Elements.Type.FIRE)
		if strike != null:
			strike.color = Color(1.0, 0.35, 0.15)
	_after(delay + 0.05, func() -> void:
		if is_dead():
			return
		for p in points:
			if p.distance_to(get_hit_center()) <= 30.0:
				_on_dragon_fire()
				break)


func _on_dragon_fire() -> void:
	_dragon_hits += 1
	super.take_damage(roundi(max_hp * dragon_hit_ratio), Vector2.ZERO, true, 999999)
	super.stun(2.5)
	_shield_left = 0.0
	Fx.fire_blast(self, get_hit_center(), 40.0, 2)
	Net.announce("붉은 용의 불길이 미카엘을 덮쳤다!", Color(1.0, 0.55, 0.3))
	_update_status()


## 빛나는 방패를 듦 (테스트에서도 직접 호출)
func raise_shield() -> void:
	if is_dead():
		return
	_shield_left = shield_time
	shield_dir = direction_to_player() if has_target() else Vector2.DOWN
	Net.announce("「누가 하나님과 같으랴!」 — 미카엘이 빛나는 방패를 든다. 옆이나 뒤로!", Color(1.0, 0.95, 0.6))
	_update_status()


func is_in_front(at: Vector2) -> bool:
	return shield_dir.dot(get_hit_center().direction_to(at)) > 0.3


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and is_shielded() and has_target() and is_in_front(_player.global_position):
		_hit_flash = 0.05
		if _reflect_cd <= 0.0:
			_reflect_cd = 0.3
			_reflected += 1
			_player.take_unblockable_hit(maxi(1, roundi(amount * reflect_ratio)), global_position, false)
			FloatingText.spawn(self, global_position + Vector2(0, -46), "반사!", Color(1.0, 0.95, 0.6))
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		_dragon_angle = wrapf(_dragon_angle + 0.35 * delta, 0.0, TAU)
		if dragon != null and is_instance_valid(dragon):
			dragon.global_position = dragon_position()
		_reflect_cd = maxf(_reflect_cd - delta, 0.0)
		_breath_left -= delta
		if _breath_left <= 0.0 and has_target():
			_breath_left = breath_interval * (0.7 if phase_two else 1.0)
			breathe_at(_player.global_position)
		if is_shielded():
			_shield_left -= delta
			if _shield_left <= 0.0:
				_shield_cd = shield_interval
				_update_status()
		else:
			_shield_cd -= delta
			if _shield_cd <= 0.0 and not is_stunned():
				raise_shield()
		queue_redraw()
	super._physics_process(delta)


func _update_status() -> void:
	set_status("빛나는 방패 — 옆이나 뒤로!" if is_shielded() else "하늘의 전쟁 — 용의 불길을 미카엘에게", Color(1.0, 0.9, 0.55))


func _run_pattern(pattern: int) -> float:
	if not has_target() or is_shielded():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SWORD:
			for i in 7:
				telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.28) * 54.0, 22.0, 0.75, sword_damage, Elements.Type.FIRE)
			return 1.1
		Pattern.JUDGEMENT:
			for ring in 2:
				for i in 12:
					telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0 + ring * 0.26) * (48.0 + 34.0 * ring), 18.0, 0.8 + 0.25 * ring, judgement_damage, Elements.Type.HOLY)
			return 1.3
		Pattern.SPEARS:
			for i in 6:
				telegraph_strike(_player.global_position + Vector2.from_angle(TAU * i / 6.0 + randf()) * randf_range(0.0, 60.0), 20.0, 0.9 + 0.06 * i, spear_damage, Elements.Type.HOLY)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


## 빛나는 방패
func _draw() -> void:
	if not is_shielded() or is_dead():
		return
	var c := to_local(get_hit_center())
	var a := shield_dir.angle()
	draw_arc(c, 24.0, a - 1.1, a + 1.1, 20, Color(1.0, 0.95, 0.6, 0.9), 4.0)
	draw_arc(c, 28.0, a - 0.9, a + 0.9, 20, Color(1.0, 1.0, 0.85, 0.5), 2.0)
