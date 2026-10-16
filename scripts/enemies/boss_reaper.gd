class_name BossReaper
extends PatternBoss
## 7스테이지 보스: 죽음의 사신 — 거대한 낫을 든 망령. (기믹은 아직 미정 → 패턴만)
##   SWEEP   : 낫을 크게 휘둘러 앞쪽 반원에 예고 장판 5개
##   BLINK   : 안개처럼 흩어졌다가 플레이어 근처에서 나타나 곧바로 휘두르기
##   SOULS   : 영혼 구슬을 원형으로 천천히 퍼뜨림 (2페이즈 2겹)
##   RAISE   : 해골 병사 · 유령 불러내기
## 체력 50% 이하: 이동 강화, 순간이동 빈도 증가

enum Pattern { SWEEP, BLINK, SOULS, RAISE }

@export var soul_texture: Texture2D
@export var minion_scenes: Array[PackedScene] = []
@export var sweep_damage: int = 46
@export var soul_damage: int = 26


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SWEEP, Pattern.SOULS, Pattern.BLINK, Pattern.RAISE, Pattern.SWEEP, Pattern.BLINK, Pattern.SOULS]


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
	GameManager.show_notice("죽음의 사신: 너의 영혼도 거두어 주마…", Color(0.6, 0.95, 0.9))
	pattern_order = [Pattern.SWEEP, Pattern.BLINK, Pattern.SOULS, Pattern.BLINK, Pattern.RAISE]
