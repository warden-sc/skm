class_name BossLeviathan
extends PatternBoss
## 19스테이지 보스: 폭풍의 지배자 레비아탄 — 폭풍의 바다를 다스리는 거대 바다룡.
## 보스방이 가로로 나뉨: 위쪽 = 구름 지대, 아래쪽 = 폭풍우 지대 (StormField)
##
## [기믹] 상단·하단 공격이 번갈아 옴 (zone_interval 마다):
##   - 상단 공격 「고드름 낙하」: 구름 지대 전체에 고드름이 쏟아짐 → 하단으로 피해야 함
##   - 하단 공격 「폭풍」: 폭풍우 지대 전체에 번개와 돌풍 → 상단으로 피해야 함
##   - zone_warn 초 동안 공격할 쪽이 붉게 깜빡이며 예고, 그 순간 그쪽에 있으면 큰 피해 (가드 불가, 대시로 회피 가능)
## [기믹] 브레스: 상단·하단 상관없이 breath_interval 마다 플레이어 쪽으로 얼음 브레스 (여러 번 이어지는 탄 줄기)
## 그 밖에 꼬리 내려치기 · 물보라 탄 · 바다뱀 호출. 레비아탄은 두 지대의 경계선을 따라 좌우로 헤엄침.
## 체력 50% 이하: 지대 공격 주기 단축, 브레스가 더 넓어짐

enum Pattern { TAIL, SPRAY, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var ice_texture: Texture2D
@export var water_texture: Texture2D
@export var zone_damage: int = 70
@export var breath_damage: int = 34
@export var tail_damage: int = 54
@export var spray_damage: int = 30
@export var zone_interval: float = 6.0
@export var zone_warn: float = 1.6
@export var breath_interval: float = 9.0

var field: StormField
var _next_zone: int = StormField.Zone.UPPER
var _zone_timer: float = 3.0
var _zone_pending: bool = false
var _zone_attacks: int = 0
var _zone_hits: int = 0
var _breath_timer: float = 5.0
var _breaths: int = 0
var _swim_dir: float = 1.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPRAY, Pattern.TAIL, Pattern.SPRAY, Pattern.SUMMON]


func get_field() -> StormField:
	return field if field != null and is_instance_valid(field) else null


func get_zone_attack_count() -> int:
	return _zone_attacks


func get_zone_hit_count() -> int:
	return _zone_hits


func get_breath_count() -> int:
	return _breaths


func get_next_zone() -> int:
	return _next_zone


func _get_move_velocity(delta: float) -> Vector2:
	if field == null:
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(220, 60), Vector2(440, 300))
		field = StormField.spawn(self, area)
	if has_target():
		if not _zone_pending:
			_zone_timer -= delta
			if _zone_timer <= 0.0:
				begin_zone_attack()
		_breath_timer -= delta
		if _breath_timer <= 0.0 and not is_casting():
			breath()
	return super._get_move_velocity(delta)


## 경계선을 따라 좌우로 헤엄 (플레이어 쪽으로 조금씩)
func _chase_velocity(_delta: float) -> Vector2:
	if get_field() == null:
		return Vector2.ZERO
	var line_y := field.get_divider_y() + 10.0
	if global_position.x > field.area.end.x - 50.0:
		_swim_dir = -1.0
	elif global_position.x < field.area.position.x + 50.0:
		_swim_dir = 1.0
	var v := Vector2(_swim_dir * move_speed, (line_y - global_position.y) * 2.0)
	return v


# ============================================================ 기믹: 상단 / 하단
## 다음 지대 공격 예고 (테스트에서도 직접 호출)
func begin_zone_attack() -> void:
	if _zone_pending or is_dead() or get_field() == null:
		return
	_zone_pending = true
	var zone := _next_zone
	field.warn(zone, zone_warn)
	if zone == StormField.Zone.UPPER:
		set_status("상단: 고드름 낙하 — 아래로 피하라!", Color(0.75, 0.9, 1.0))
	else:
		set_status("하단: 폭풍 — 위로 피하라!", Color(1.0, 0.95, 0.6))
	_after(zone_warn, _resolve_zone.bind(zone))


func _resolve_zone(zone: int) -> void:
	_zone_pending = false
	if is_dead() or get_field() == null:
		return
	_zone_attacks += 1
	field.strike(zone)
	if has_target() and field.is_in_zone(_player.global_position, zone):
		if _player.take_unblockable_hit(roundi(zone_damage * power), _player.global_position + Vector2(0, -20)) == Player.HitResult.DAMAGED:
			_zone_hits += 1
			if zone == StormField.Zone.UPPER:
				_player.apply_slow(0.5, 1.0)
	if _player != null:
		_player.shake_camera(4.0)
	_next_zone = StormField.Zone.LOWER if zone == StormField.Zone.UPPER else StormField.Zone.UPPER
	_zone_timer = zone_interval * (0.75 if phase_two else 1.0) - zone_warn
	set_status("", Color.WHITE)


# ============================================================ 기믹: 브레스
func breath() -> void:
	if is_dead() or not has_target():
		return
	_breath_timer = breath_interval
	_breaths += 1
	set_status("브레스!", Color(0.7, 0.9, 1.0))
	Fx.burst(self, get_hit_center() + Vector2(0, -30), Color(0.7, 0.9, 1.0), 14, 50.0, 0.4)
	var aim := (get_hit_center() + Vector2(0, -30)).direction_to(_player.global_position)
	for w in 5:
		_after(0.35 + 0.12 * w, _breath_wave.bind(aim, w))
	_after(1.2, func() -> void:
		if get_status_text() == "브레스!":
			set_status("", Color.WHITE))


func _breath_wave(aim: Vector2, wave: int) -> void:
	if is_dead():
		return
	var spread := 0.7 if phase_two else 0.5
	for i in 5:
		var t := float(i) / 4.0 - 0.5
		shoot(aim.rotated(t * spread + sin(wave) * 0.06), 170.0, breath_damage, ice_texture, 0.6, Elements.Type.ICE, get_hit_center() + Vector2(0, -30))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.TAIL:
			telegraph_strike(get_hit_center(), 60.0, 0.9, tail_damage, Elements.Type.ICE)
			return 1.3
		Pattern.SPRAY:
			for k in 10:
				_after(0.08 * k, _spray.bind(k))
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 30.0))
			return 0.9
	return 1.0


func _spray(step: int) -> void:
	if is_dead():
		return
	for arm in 4:
		shoot(Vector2.from_angle(step * 0.28 + TAU * arm / 4.0), 100.0, spray_damage, water_texture, 0.0, Elements.Type.ICE)


func _die() -> void:
	if get_field() != null:
		field.queue_free()
	super._die()


func _on_phase_two() -> void:
	Net.announce("레비아탄이 폭풍을 부른다! 상단·하단 공격이 더 빨라진다", Color(0.75, 0.9, 1.0))
