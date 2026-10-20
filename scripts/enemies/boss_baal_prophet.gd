class_name BossBaalProphet
extends PatternBoss
## 97스테이지 보스: 갈멜산의 바알 대예언자 — 엘리야와 겨루던 바알의 예언자 사백오십 명의 우두머리.
##   CRY      : 「바알이여, 우리에게 응답하소서」 — 몸 주위 고리
##   KNIVES   : 칼과 창 — 부채꼴 탄
##   HORNS    : 황소 뿔 돌진
##   SUMMON   : 바알의 사제 · 아세라 목상 호출
##
## [기믹] 두 제단: 보스방에 바알의 제단과 엘리야의 제단(돌 열두 개), 그리고 우물 — 우물의 물동이를 들어 엘리야의 제단에 붓기
##   pours_needed 번 부으면 하늘에서 불이 내려 대예언자에게 최대 체력의 fire_ratio 피해 + 크게 휘청 (바알의 춤도 끊김)
##   물동이를 든 채 맞으면 떨어뜨림 — 불이 내린 뒤 jar_cooldown 초 동안은 물동이가 없음
## [기믹] 바알의 춤: dance_interval 초마다 춤꾼 dancer_count 명이 바알의 제단 앞에서 춤을 춤 — 살아 있는 춤꾼마다
##   대예언자의 공격력 +dancer_power, 초당 최대 체력의 dance_regen 회복 → 춤꾼을 쓰러뜨려 춤을 끊어야 함 (dance_time 초가 지나도 끝남)

enum Pattern { CRY, KNIVES, HORNS, SUMMON }

@export var dancer_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var baal_altar_texture: Texture2D
@export var elijah_altar_texture: Texture2D
@export var jar_texture: Texture2D
@export var knife_texture: Texture2D
@export var cry_damage: int = 96
@export var knife_damage: int = 66
@export var horn_damage: int = 108
@export var pours_needed: int = 3
@export var fire_ratio: float = 0.1
@export var fire_stun: float = 9.0
@export var jar_cooldown: float = 12.0
@export var dance_interval: float = 18.0
@export var dance_time: float = 14.0
@export var dancer_count: int = 3
@export var dancer_power: float = 0.12
@export var dance_regen: float = 0.004

var baal_altar: FieldProp
var elijah_altar: FieldProp
var well: WaterPool
var jar: CarryItem
var dancers: Array[Enemy] = []
var pours: int = 0
var _fires: int = 0
var _dance_left: float = 0.0
var _dance_cd: float = 0.0
var _base_power: float = 1.0
var _regen: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.CRY, Pattern.KNIVES, Pattern.HORNS, Pattern.KNIVES, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func get_fire_count() -> int:
	return _fires


func is_dancing() -> bool:
	return _dance_left > 0.0


func living_dancers() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for d in dancers:
		if is_instance_valid(d) and not d.is_dead():
			alive.append(d)
	return alive


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func elijah_position() -> Vector2:
	var area := _area()
	return Vector2(area.position.x + 90.0, area.end.y - 50.0)


func well_position() -> Vector2:
	var area := _area()
	return Vector2(area.end.x - 90.0, area.end.y - 50.0)


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		var area := _area()
		baal_altar = FieldProp.spawn(self, Vector2(area.get_center().x, area.position.y + 50.0), baal_altar_texture, Color(1.0, 0.4, 0.3))
		elijah_altar = FieldProp.spawn(self, elijah_position(), elijah_altar_texture)
		well = WaterPool.spawn(self, well_position(), 26.0)
		jar = CarryItem.spawn(self, well_position() + Vector2(0, -26), jar_texture, "물동이", Color(0.6, 0.85, 1.0))
		_dance_cd = dance_interval * 0.5
		_update_status()
	if _charge_left > 0.0:
		_charge_left -= delta
		if has_target() and global_position.distance_to(_player.global_position) < 30.0:
			_player.take_hit(roundi(horn_damage * power), global_position, self)
			_charge_left = 0.0
		return _charge_dir * 280.0
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if dancer_scene != null and minion.scene_file_path == dancer_scene.resource_path:
		dancers.append(minion)


## 엘리야의 제단에 물을 부음 (테스트에서도 직접 호출)
func pour_water() -> void:
	if is_dead():
		return
	pours += 1
	Fx.burst(self, elijah_position() + Vector2(0, -10), Color(0.6, 0.85, 1.0), 20, 60.0, 0.6, Vector2(0, 60))
	if pours >= pours_needed:
		fire_from_heaven()
	else:
		if jar != null and is_instance_valid(jar):
			jar.hide_for(0.8)
		Net.announce("엘리야의 제단에 물을 부었다 (%d/%d)" % [pours, pours_needed], Color(0.6, 0.85, 1.0))
	_update_status()


## 하늘에서 불이 내림 (테스트에서도 직접 호출)
func fire_from_heaven() -> void:
	pours = 0
	_fires += 1
	if jar != null and is_instance_valid(jar):
		jar.hide_for(jar_cooldown)
	Fx.pillar(self, elijah_position(), Color(1.0, 0.6, 0.2), 30.0, 220.0, 0.8)
	Fx.pillar(self, global_position, Color(1.0, 0.6, 0.2), 40.0, 240.0, 0.8)
	Fx.fire_blast(self, global_position, 60.0, 3)
	end_dance()
	super.take_damage(roundi(max_hp * fire_ratio), Vector2.ZERO, true, 999999)
	super.stun(fire_stun)
	Net.announce("하늘에서 불이 내려 번제물과 나무와 돌과 흙을 태웠다! 바알 대예언자가 무너진다", Color(1.0, 0.75, 0.4))
	_update_status()


## 바알의 춤 시작 (테스트에서도 직접 호출)
func begin_dance() -> void:
	if is_dead() or dancer_scene == null:
		return
	_dance_left = dance_time
	var at := baal_altar.global_position if baal_altar != null else global_position
	for i in dancer_count:
		request_summon(dancer_scene, at + Vector2.from_angle(TAU * i / dancer_count) * 34.0 + Vector2(0, 30))
	Net.announce("바알의 춤이 시작된다 — 춤꾼을 쓰러뜨려 춤을 끊어라", Color(1.0, 0.5, 0.4))
	_update_status()


func end_dance() -> void:
	_dance_left = 0.0
	_dance_cd = dance_interval * (0.7 if phase_two else 1.0)
	for d in living_dancers():
		d.despawn()
	dancers.clear()
	power = _base_power
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if jar != null and is_instance_valid(jar) and jar.is_carried() and has_target() and _player.global_position.distance_to(elijah_position()) < 34.0:
			pour_water()
		if is_dancing():
			_dance_left -= delta
			var alive := living_dancers().size()
			if _dance_left <= 0.0 or (alive == 0 and not dancers.is_empty()):
				Net.announce("바알의 춤이 끊겼다", Color(1.0, 0.75, 0.6))
				end_dance()
			else:
				power = _base_power * (1.0 + dancer_power * alive)
				_regen += max_hp * dance_regen * alive * delta
				if _regen >= 1.0:
					var heal := mini(int(_regen), max_hp - hp)
					_regen -= int(_regen)
					if heal > 0:
						hp += heal
						health_changed.emit(hp, max_hp)
		else:
			_dance_cd -= delta
			if _dance_cd <= 0.0:
				begin_dance()
		if Engine.get_physics_frames() % 30 == 0:
			_update_status()
	super._physics_process(delta)


func _update_status() -> void:
	var text := "엘리야의 제단 %d/%d" % [pours, pours_needed]
	if is_dancing():
		text += " · 바알의 춤 (춤꾼 %d)" % living_dancers().size()
	set_status(text, Color(1.0, 0.6, 0.45))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.CRY:
			for i in 14:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0) * 56.0, 20.0, 0.85, cry_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.KNIVES:
			for i in 9:
				shoot(dir.rotated((i - 4) * 0.14), 165.0, knife_damage, knife_texture)
			return 1.0
		Pattern.HORNS:
			_charge_dir = dir
			_charge_left = 0.65
			for i in 10:
				Fx.flash(self, global_position + dir * (20.0 + 20.0 * i), Color(1.0, 0.5, 0.3), 12.0, 0.4)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


func _die() -> void:
	if jar != null and is_instance_valid(jar):
		jar.queue_free()
	super._die()
