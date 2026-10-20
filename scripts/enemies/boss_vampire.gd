class_name BossVampire
extends PatternBoss
## 23스테이지 보스: 피의 군주 벨 — 피의 성의 주인인 흡혈귀 군주. 하위 뱀파이어들을 거느린다.
##   BATS   : 박쥐 떼 — 흡혈 박쥐 부채꼴 (맞은 만큼 벨이 조금 회복)
##   SCYTHE : 핏빛 낫 — 앞쪽으로 초승달 모양 장판
##   MIST   : 안개화 — 붉은 안개로 흩어졌다가 플레이어 등 뒤에서 나타나 할퀴기
##   RAIN   : 피의 비 — 플레이어 주변에 핏방울 장판
##   SUMMON : 하위 뱀파이어 · 흡혈 박쥐 호출
##
## [기믹] 흡혈 (drain_interval 마다):
##   - 벨과 플레이어가 붉은 핏줄기로 이어지고, drain_time 동안 0.5초마다 플레이어 최대 체력의 drain_ratio 만큼 피를 빨아감
##     (방어력·가드 무시) → 빨아간 피의 drain_heal_scale 배만큼 벨이 회복
##   - drain_range 보다 멀리 떨어지면 핏줄기가 끊어져 흡혈이 멈춤 (흡혈 중 벨은 제자리에서 흡혈에만 집중)
## 체력 50% 이하: 흡혈이 더 자주, 더 오래 / 박쥐가 두 겹

enum Pattern { BATS, SCYTHE, MIST, RAIN, SUMMON }

const DRAIN_TICK := 0.5

@export var minion_scenes: Array[PackedScene] = []
@export var bat_texture: Texture2D
@export var blood_texture: Texture2D
@export var bat_damage: int = 36
@export var scythe_damage: int = 60
@export var claw_damage: int = 62
@export var rain_damage: int = 50
@export var drain_interval: float = 13.0
@export var drain_time: float = 3.0
@export var drain_ratio: float = 0.04
@export var drain_heal_scale: float = 40.0
@export var drain_range: float = 180.0

var _drain_cooldown: float = 6.0
var _drain_left: float = 0.0
var _drain_tick: float = 0.0
var _drains: int = 0
var _drained_total: int = 0
var _healed_total: int = 0
var _breaks: int = 0
var _link: Node2D


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BATS, Pattern.SCYTHE, Pattern.MIST, Pattern.RAIN, Pattern.SUMMON, Pattern.BATS, Pattern.SCYTHE]
	_link = Node2D.new()
	_link.top_level = true
	_link.z_index = 40
	_link.draw.connect(_draw_link)
	add_child(_link)
	var mist := Fx.make_dark_mist(18, 16.0)
	mist.name = "DarkMist"
	mist.position = get_hit_center() - global_position
	mist.z_index = -1
	add_child(mist)
	mist.emitting = true


func is_draining() -> bool:
	return _drain_left > 0.0


func get_drain_count() -> int:
	return _drains


func get_drained_total() -> int:
	return _drained_total


func get_healed_total() -> int:
	return _healed_total


func get_break_count() -> int:
	return _breaks


func _get_move_velocity(delta: float) -> Vector2:
	_link.queue_redraw()
	if _drain_left > 0.0:
		_update_drain(delta)
		return Vector2.ZERO
	if has_target():
		_drain_cooldown -= delta
		if _drain_cooldown <= 0.0 and not is_casting():
			begin_drain()
			return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 흡혈
func begin_drain() -> void:
	if is_draining() or is_dead() or not has_target():
		return
	_drains += 1
	_drain_left = drain_time * (1.25 if phase_two else 1.0)
	_drain_tick = DRAIN_TICK
	_drain_cooldown = drain_interval * (0.75 if phase_two else 1.0)
	set_status("흡혈: 피를 빨아들인다 — 멀리 떨어져 핏줄기를 끊어라!", Color(1.0, 0.35, 0.4))
	Net.announce("피의 군주 벨이 피를 빨아들인다! 멀리 떨어지면 끊어진다", Color(1.0, 0.4, 0.45))


func _update_drain(delta: float) -> void:
	_drain_left -= delta
	if not has_target():
		_end_drain()
		return
	if global_position.distance_to(_player.global_position) > drain_range:
		_breaks += 1
		FloatingText.spawn(self, global_position + Vector2(0, -50), "핏줄기가 끊어졌다!", Color(1.0, 0.8, 0.8), true)
		_end_drain()
		return
	_drain_tick -= delta
	if _drain_tick <= 0.0:
		_drain_tick += DRAIN_TICK
		var amount := maxi(1, roundi(GameManager.max_hp * drain_ratio))
		GameManager.damage_player(amount)
		_drained_total += amount
		FloatingText.spawn(_player, _player.global_position + Vector2(0, -20), "-%d" % amount, Color(0.9, 0.15, 0.25))
		var heal := mini(roundi(amount * drain_heal_scale), max_hp - hp)
		if heal > 0:
			hp += heal
			_healed_total += heal
			health_changed.emit(hp, max_hp)
			FloatingText.spawn(self, global_position + Vector2(0, -36), "+%d" % heal, Color(1.0, 0.3, 0.4))
		Fx.burst(self, _player.global_position + Vector2(0, -8), Color(0.8, 0.05, 0.15), 6, 40.0, 0.3)
	if _drain_left <= 0.0:
		_end_drain()


func _end_drain() -> void:
	_drain_left = 0.0
	set_status("", Color.WHITE)
	_bstate = BossState.CHASE
	_btimer = chase_time * 0.5


func _draw_link() -> void:
	if not is_draining() or not has_target():
		return
	var from := get_hit_center() + Vector2(0, -8)
	var to := _player.global_position + Vector2(0, -8)
	var pulse := 0.6 + 0.4 * sin(_anim_time * 14.0)
	_link.draw_line(from, to, Color(0.6, 0.02, 0.1, 0.5 * pulse), 5.0)
	_link.draw_line(from, to, Color(1.0, 0.2, 0.3, 0.9 * pulse), 2.0)
	# 핏방울이 벨 쪽으로 흘러감
	for i in 4:
		var t := fmod(_anim_time * 1.5 + i * 0.25, 1.0)
		_link.draw_circle(to.lerp(from, t), 2.0, Color(1.0, 0.25, 0.3, 0.9))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.BATS:
			var aim := direction_to_player()
			for w in (2 if phase_two else 1):
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 9:
						shoot(aim.rotated((i - 4) * 0.14 + w * 0.07), 150.0, bat_damage, bat_texture, 0.0, Elements.Type.DARK))
			return 1.0
		Pattern.SCYTHE:
			var dir := direction_to_player()
			for i in 9:
				var a := (i - 4) * 0.2
				telegraph_strike(get_hit_center() + dir.rotated(a) * 54.0, 15.0, 0.75, scythe_damage, Elements.Type.DARK)
			return 1.2
		Pattern.MIST:
			if not has_target():
				return 0.5
			Fx.burst(self, get_hit_center(), Color(0.7, 0.05, 0.15), 18, 60.0, 0.4)
			var behind := _player.global_position - _player.get_aim_direction() * 30.0
			global_position = behind if not arena_rect.has_area() else behind.clamp(arena_rect.position, arena_rect.end)
			Fx.burst(self, get_hit_center(), Color(0.7, 0.05, 0.15), 18, 60.0, 0.4)
			telegraph_strike(_player.global_position, 24.0, 0.5, claw_damage, Elements.Type.DARK)
			return 1.0
		Pattern.RAIN:
			if has_target():
				for i in 7:
					telegraph_strike(_player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0)), 18.0, 0.8 + 0.1 * i, rain_damage, Elements.Type.DARK)
			return 1.5
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("벨: 더… 더 많은 피를…! 흡혈이 더 잦아진다", Color(1.0, 0.35, 0.4))
