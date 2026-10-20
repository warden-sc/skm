class_name BossReaper
extends PatternBoss
## 7스테이지 보스: 죽음의 사신 — 거대한 낫을 든 망령. 몸에서 검은 안개가 피어오름.
##   SWEEP   : 낫을 크게 휘둘러 앞쪽 반원에 예고 장판 5개
##   BLINK   : 안개처럼 흩어졌다가 플레이어 근처에서 나타나 곧바로 휘두르기
##   SOULS   : 영혼 구슬을 원형으로 천천히 퍼뜨림 (2페이즈 2겹)
##   RAISE   : 해골 병사 · 유령 불러내기
## 체력 50% 이하: 이동 강화, 순간이동 빈도 증가
##
## [기믹] 죽음의 낙인: 사신의 공격(낫·영혼 구슬·몸통)에 맞을 때마다 낙인이 쌓임 (Player.add_death_mark)
##   5개가 되면 「사형 선고」 → 1.5초 뒤 최대 체력의 35% 피해 (그 순간 대시하면 회피). 낙인은 8초 동안 안 맞으면 하나씩 사라짐
## [기믹] 망령화: wraith_interval 마다 wraith_time 동안 거의 투명해지고(검은 안개만 보임) 빨라짐.
##   망령화 중에는 공격이 wraith_evade 확률로 스쳐 지나감 → 망령화가 끝난 뒤를 노리세요

enum Pattern { SWEEP, BLINK, SOULS, RAISE }

@export var soul_texture: Texture2D
@export var minion_scenes: Array[PackedScene] = []
@export var sweep_damage: int = 46
@export var soul_damage: int = 26
@export var wraith_interval: float = 14.0
@export var wraith_time: float = 5.0
@export_range(0.0, 1.0) var wraith_evade: float = 0.65

var _wraith_left: float = 0.0
var _wraith_cooldown: float = 0.0
var _mist: CPUParticles2D
var _base_speed: float = 0.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SWEEP, Pattern.SOULS, Pattern.BLINK, Pattern.RAISE, Pattern.SWEEP, Pattern.BLINK, Pattern.SOULS]
	_base_speed = move_speed
	_wraith_cooldown = wraith_interval * 0.6
	# 몸 주위로 퍼지는 검은 안개
	_mist = Fx.make_dark_mist(26, 20.0)
	_mist.name = "DarkMist"
	_mist.position = get_hit_center() - global_position
	_mist.z_index = -1  # 몸 뒤로 퍼져 실루엣이 보이도록
	add_child(_mist)
	_mist.emitting = true


# ============================================================ 기믹: 망령화
func is_wraith() -> bool:
	return _wraith_left > 0.0


func enter_wraith() -> void:
	if is_dead():
		return
	_wraith_left = wraith_time * (1.2 if phase_two else 1.0)
	move_speed = _base_speed * 1.6
	_mist.amount = 60
	set_status("망령화: 공격이 잘 맞지 않음", Color(0.6, 0.95, 0.9))
	Fx.burst(self, get_hit_center(), Color(0.3, 0.2, 0.4), 24, 50.0, 0.8)


func _exit_wraith() -> void:
	_wraith_left = 0.0
	_wraith_cooldown = wraith_interval * (0.7 if phase_two else 1.0)
	move_speed = _base_speed
	_mist.amount = 26
	set_status("", Color.WHITE)


func _get_move_velocity(delta: float) -> Vector2:
	if _wraith_left > 0.0:
		_wraith_left -= delta
		if _wraith_left <= 0.0:
			_exit_wraith()
	else:
		_wraith_cooldown -= delta
		if _wraith_cooldown <= 0.0 and not is_casting():
			enter_wraith()
	return super._get_move_velocity(delta)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_wraith() and not is_dead() and randf() < wraith_evade:
		FloatingText.spawn(self, global_position + Vector2(0, -30), "스쳐 지나감", Color(0.6, 0.8, 0.85))
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if is_wraith():
		sprite.modulate.a = move_toward(sprite.modulate.a, 0.15, delta * 3.0)
	elif not is_casting():
		sprite.modulate.a = move_toward(sprite.modulate.a, 1.0, delta * 3.0)


func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.SWEEP:
			_sweep(direction_to_player())
			return 1.3
		Pattern.BLINK:
			_blink()
			return 1.6
		Pattern.SOULS:
			var waves := 2 if phase_two else 1
			for w in waves:
				_after(0.5 * w, _souls.bind(w))
			return 0.8 + 0.5 * waves
		Pattern.RAISE:
			_raise()
			return 1.0
	return 1.0


func _sweep(dir: Vector2) -> void:
	for i in 5:
		var a := (float(i) / 4.0 - 0.5) * PI * 0.9
		telegraph_strike(get_hit_center() + dir.rotated(a) * 42.0, 22.0, 0.75, sweep_damage, Elements.Type.DARK)


## 안개처럼 사라졌다가 플레이어 옆에서 나타나 휘두르기
func _blink() -> void:
	if not has_target():
		return
	Fx.burst(self, get_hit_center(), Color(0.5, 0.9, 0.85), 18, 40.0, 0.6, Vector2(0, -30))
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_reappear)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.25)


func _reappear() -> void:
	if is_dead() or not has_target():
		return
	var to := _player.global_position + Vector2.from_angle(randf() * TAU) * 56.0
	if arena_rect.has_area():
		to = to.clamp(arena_rect.position, arena_rect.end)
	global_position = to
	Fx.burst(self, get_hit_center(), Color(0.5, 0.9, 0.85), 18, 40.0, 0.6, Vector2(0, -30))
	_after(0.35, func() -> void:
		if not is_dead():
			_sweep(direction_to_player()))


func _souls(wave: int) -> void:
	if is_dead():
		return
	var count := 14
	for i in count:
		shoot(Vector2.RIGHT.rotated(TAU * i / count + wave * 0.2), 75.0, soul_damage, soul_texture, 0.6, Elements.Type.ICE)


func _raise() -> void:
	set_status("일어나라, 망자들이여…", Color(0.6, 0.95, 0.9))
	_after(1.2, set_status.bind("", Color.WHITE))
	if minion_scenes.is_empty():
		return
	for i in (3 if phase_two else 2):
		var at := global_position + Vector2.from_angle(randf() * TAU) * 50.0
		Fx.burst(self, at, Color(0.5, 0.9, 0.85), 10, 30.0, 0.5, Vector2(0, -40))
		request_summon(minion_scenes.pick_random(), at)


func _on_phase_two() -> void:
	Net.announce("죽음의 사신: 너의 영혼도 거두어 주마…", Color(0.6, 0.95, 0.9))
	pattern_order = [Pattern.SWEEP, Pattern.BLINK, Pattern.SOULS, Pattern.BLINK, Pattern.RAISE]
