class_name BossTydeus
extends PatternBoss
## 77스테이지 보스: 티데우스 — 테베를 공격한 일곱 장수 중 하나. 아테나가 불사의 약을 가져다주려 했던 사나운 영웅.
##   SPEAR   : 창 찌르기 (일직선 둘)
##   BASH    : 멧돼지 가죽 방패로 밀치기 (앞쪽 부채꼴)
##   ROCKS   : 돌팔매 (부채꼴)
##   SUMMON  : 테베 전사 · 테베 들개 호출
##
## [기믹] 아테나의 불사의 약: potion_interval 초마다 보스방 어딘가에 약병이 떨어짐 (금빛 예고 1.2초)
##   티데우스가 먼저 닿으면 마심 → 최대 체력의 heal_ratio 회복 + immortal_time 초 동안 「불사」(피해 없음)
##   플레이어가 먼저 닿으면 약병을 깨뜨림. 약병이 떨어지면 티데우스는 약병으로 내달림
## 체력 50% 이하: 약병이 더 자주 떨어짐

enum Pattern { SPEAR, BASH, ROCKS, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var potion_texture: Texture2D
@export var rock_texture: Texture2D
@export var spear_damage: int = 98
@export var bash_damage: int = 90
@export var rock_damage: int = 62
@export var potion_interval: float = 14.0
@export var heal_ratio: float = 0.1
@export var immortal_time: float = 8.0

var potion: CarryItem
var _potion_left: float = 6.0
var _immortal_left: float = 0.0
var _drinks: int = 0
var _smashed: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPEAR, Pattern.BASH, Pattern.ROCKS, Pattern.SPEAR, Pattern.SUMMON]
	immune_text = "불사! 피해가 들어가지 않음"


func is_immortal() -> bool:
	return _immortal_left > 0.0


func has_potion() -> bool:
	return potion != null and is_instance_valid(potion) and potion.available


func get_drink_count() -> int:
	return _drinks


func get_smash_count() -> int:
	return _smashed


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
	if has_potion() and not is_casting():
		return global_position.direction_to(potion.global_position) * move_speed * 1.8
	return super._get_move_velocity(delta)


## 약병을 떨어뜨림 (테스트에서도 직접 호출). at 이 INF 면 무작위 자리
func drop_potion(at: Vector2 = Vector2.INF) -> void:
	if is_dead() or has_potion():
		return
	var area := _area().grow(-40.0)
	var spot := at if at != Vector2.INF else Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
	var mark := AoeStrike.spawn(self, spot, 14.0, 1.2, 0, Color(1.0, 0.9, 0.5))
	if mark != null:
		mark.harmless = true
	_after(1.2, func() -> void:
		if is_dead():
			return
		if potion == null or not is_instance_valid(potion):
			potion = CarryItem.spawn(self, spot, potion_texture, "불사의 약병", Color(1.0, 0.9, 0.5))
			if potion != null:
				potion.follow_player = false
				potion.picked_up.connect(_on_potion_smashed)
		else:
			potion.reappear(spot))
	Net.announce("아테나의 불사의 약병이 떨어진다! 티데우스보다 먼저 깨뜨려라", Color(1.0, 0.9, 0.5))


func _on_potion_smashed(item: CarryItem) -> void:
	_smashed += 1
	item.hide_for(99999.0)
	Fx.burst(item, item.global_position, Color(1.0, 0.9, 0.6), 18, 60.0, 0.5)
	Net.announce("불사의 약병을 깨뜨렸다!", Color(0.9, 0.9, 1.0))


func _drink() -> void:
	_drinks += 1
	potion.hide_for(99999.0)
	_immortal_left = immortal_time
	var heal := mini(roundi(max_hp * heal_ratio), max_hp - hp)
	hp += heal
	health_changed.emit(hp, max_hp)
	Fx.burst(self, get_hit_center(), Color(1.0, 0.9, 0.5), 24, 70.0, 0.6, Vector2(0, -50))
	Net.announce("티데우스가 불사의 약을 마셨다! %d초 동안 불사" % roundi(immortal_time), Color(1.0, 0.6, 0.4))


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_immortal():
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _immortal_left > 0.0:
			_immortal_left -= delta
		if has_potion() and global_position.distance_to(potion.global_position) <= 20.0:
			_drink()
		if not has_potion():
			_potion_left -= delta
			if _potion_left <= 0.0:
				_potion_left = potion_interval * (0.7 if phase_two else 1.0)
				drop_potion()
		if is_immortal():
			set_status("불사 %.0f초" % _immortal_left, Color(1.0, 0.85, 0.4))
		elif has_potion():
			set_status("약병으로 달려간다!", Color(1.0, 0.6, 0.4))
		else:
			set_status("", Color.WHITE)
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SPEAR:
			for k in 2:
				var d := dir.rotated((k - 0.5) * 0.3)
				for i in 9:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.NONE)
			return 1.1
		Pattern.BASH:
			for i in 7:
				telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.28) * 44.0, 20.0, 0.7, bash_damage, Elements.Type.NONE)
			return 1.0
		Pattern.ROCKS:
			for i in 7:
				shoot(dir.rotated((i - 3) * 0.16), 170.0, rock_damage, rock_texture, 0.0, Elements.Type.EARTH)
			return 0.9
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("티데우스가 피에 굶주린다! 약병이 더 자주 떨어진다", Color(1.0, 0.5, 0.4))
