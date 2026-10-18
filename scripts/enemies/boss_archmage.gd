class_name BossArchmage
extends PatternBoss
## 20스테이지 보스: 대마법사 아르카나 — 어둠에 잠긴 탑 꼭대기에서 모든 원소를 다루는 대마법사 (전설 지팡이 「아르카나」의 주인).
## 몸에서 검은 안개가 피어오름. 끝에 마력 구슬이 달린 지팡이를 든다.
##   FIRE      : 화염구 부채꼴 (화상)
##   FROST     : 서리 고리 — 플레이어 주변을 둥글게 얼음 장판 (감속)
##   LIGHTNING : 낙뢰 — 플레이어를 따라 연달아 떨어지는 번개
##   ARCANE    : 비전 구체 — 사방으로 퍼지는 마력탄 2겹
##   BLINK     : 순간이동 — 보스방 다른 곳으로 사라졌다 나타남
##   SUMMON    : 견습 마법사 · 마력 갑옷 호출
##
## [기믹] 대마법 영창 (chant_interval 마다):
##   - chant_time 동안 머리 위에 영창 게이지가 차오르며 「메테오 스웜」을 영창 (그동안 움직이지 않음)
##   - 동시에 보스방 어딘가에 초록빛 「안전지대」 원이 나타남
##   - 영창 중 최대 체력의 interrupt_ratio 만큼 피해를 주면 → 영창 실패, 마력이 역류해 기절 + 받는 피해 1.5배 (역류 시간 동안)
##   - 끊지 못하면 → 보스방 전체에 운석이 쏟아짐: 안전지대 밖에 있으면 최대 체력의 meteor_ratio 피해 (가드 불가, 대시로는 못 피함)
## 체력 50% 이하: 영창이 더 자주 오고, 원소 마법을 두 개씩 겹쳐 씀

enum Pattern { FIRE, FROST, LIGHTNING, ARCANE, BLINK, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var fire_texture: Texture2D
@export var arcane_texture: Texture2D
@export var fire_damage: int = 36
@export var frost_damage: int = 46
@export var lightning_damage: int = 52
@export var arcane_damage: int = 32
@export var chant_interval: float = 18.0
@export var chant_time: float = 4.0
@export var interrupt_ratio: float = 0.05
@export var meteor_ratio: float = 0.6
@export var safe_radius: float = 34.0
@export var backlash_time: float = 4.0

var _chant_cooldown: float = 9.0
var _chant_left: float = 0.0
var _chant_damage: int = 0
var _safe_spot: Vector2 = Vector2.INF
var _backlash_left: float = 0.0
var _chants: int = 0
var _interrupts: int = 0
var _meteors: int = 0
var _meteor_hit: bool = false
var _overlay: Node2D


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.FIRE, Pattern.FROST, Pattern.LIGHTNING, Pattern.ARCANE, Pattern.BLINK, Pattern.SUMMON]
	_overlay = Node2D.new()
	_overlay.top_level = true
	_overlay.z_index = -3
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	var mist := Fx.make_dark_mist(24, 18.0)
	mist.name = "DarkMist"
	mist.position = get_hit_center() - global_position
	mist.z_index = -1  # 몸 뒤로 퍼져 실루엣이 보이도록
	add_child(mist)
	mist.emitting = true


func is_chanting() -> bool:
	return _chant_left > 0.0


func is_backlashed() -> bool:
	return _backlash_left > 0.0


func get_safe_spot() -> Vector2:
	return _safe_spot


func get_chant_count() -> int:
	return _chants


func get_interrupt_count() -> int:
	return _interrupts


func get_meteor_count() -> int:
	return _meteors


func did_meteor_hit() -> bool:
	return _meteor_hit


func get_interrupt_threshold() -> int:
	return maxi(1, roundi(max_hp * interrupt_ratio))


func _get_move_velocity(delta: float) -> Vector2:
	_overlay.queue_redraw()
	_backlash_left = maxf(_backlash_left - delta, 0.0)
	if _chant_left > 0.0:
		_chant_left -= delta
		if _chant_left <= 0.0:
			_cast_meteor()
		return Vector2.ZERO
	if has_target() and not is_backlashed():
		_chant_cooldown -= delta
		if _chant_cooldown <= 0.0 and not is_casting():
			begin_chant()
			return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 대마법 영창
func begin_chant() -> void:
	if is_chanting() or is_dead() or not has_target():
		return
	_chants += 1
	_chant_left = chant_time
	_chant_damage = 0
	_chant_cooldown = chant_interval * (0.75 if phase_two else 1.0)
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(200, 60), Vector2(400, 280))
	# 안전지대: 플레이어에게서 적당히 떨어진 곳 (달려가야 함)
	for attempt in 12:
		_safe_spot = Vector2(randf_range(area.position.x + 40.0, area.end.x - 40.0), randf_range(area.position.y + 50.0, area.end.y - 30.0))
		if _safe_spot.distance_to(_player.global_position) > 90.0 and _safe_spot.distance_to(global_position) > 60.0:
			break
	set_status("대마법 영창: 메테오 스웜", Color(1.0, 0.6, 0.3))
	GameManager.show_notice("아르카나가 메테오를 영창한다! 영창을 끊거나 초록 안전지대로!", Color(1.0, 0.65, 0.35))


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_backlashed() and not is_dead():
		amount = roundi(amount * 1.5)
	var before := hp
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if is_chanting() and not is_dead():
		_chant_damage += before - hp
		if _chant_damage >= get_interrupt_threshold():
			_interrupt()


func _interrupt() -> void:
	_chant_left = 0.0
	_interrupts += 1
	_safe_spot = Vector2.INF
	_backlash_left = backlash_time
	set_status("영창 실패! 마력 역류 (받는 피해 1.5배)", Color(0.6, 0.9, 1.0))
	GameManager.show_notice("영창을 끊었다! 아르카나가 마력 역류로 비틀거린다", Color(0.6, 0.9, 1.0))
	Fx.explosion(self, get_hit_center(), Color(0.6, 0.5, 1.0), 40.0, 3)
	stun(backlash_time)
	_after(backlash_time, func() -> void:
		if get_status_text().begins_with("영창 실패"):
			set_status("", Color.WHITE))


func _cast_meteor() -> void:
	_chant_left = 0.0
	_meteors += 1
	_meteor_hit = false
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(200, 60), Vector2(400, 280))
	for i in 22:
		var at := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if _safe_spot != Vector2.INF and at.distance_to(_safe_spot) < safe_radius + 10.0:
			continue
		_after(randf() * 0.35, func() -> void:
			Fx.explosion(self, at, Color(1.0, 0.45, 0.15), 30.0, 2, Vector2(0, -60)))
	if has_target() and (_safe_spot == Vector2.INF or _player.global_position.distance_to(_safe_spot) > safe_radius):
		_meteor_hit = true
		_player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * meteor_ratio)), _player.global_position + Vector2(0, -30), false)
	if _player != null:
		_player.shake_camera(8.0)
	_safe_spot = Vector2.INF
	set_status("", Color.WHITE)


func _draw_overlay() -> void:
	if not is_chanting():
		return
	var t := 1.0 - _chant_left / maxf(chant_time, 0.01)
	if _safe_spot != Vector2.INF:
		_overlay.draw_circle(_safe_spot, safe_radius, Color(0.3, 1.0, 0.45, 0.18 + 0.1 * sin(_anim_time * 8.0)))
		_overlay.draw_arc(_safe_spot, safe_radius, 0.0, TAU, 40, Color(0.4, 1.0, 0.5, 0.9), 2.0)
	# 머리 위 영창 게이지 + 끊기까지 남은 피해
	var bar := Rect2(global_position + Vector2(-24, -70), Vector2(48, 5))
	_overlay.draw_rect(bar, Color(0.1, 0.05, 0.1, 0.9))
	_overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color(1.0, 0.55, 0.2))
	var cut := clampf(float(_chant_damage) / float(get_interrupt_threshold()), 0.0, 1.0)
	_overlay.draw_rect(Rect2(bar.position + Vector2(0, 6), Vector2(bar.size.x * cut, 2)), Color(0.5, 0.9, 1.0))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	var t := _cast_element(pattern)
	if phase_two and pattern <= Pattern.ARCANE:
		_after(0.5, _cast_element.bind((pattern + 2) % 4))  # 2페이즈: 원소 마법 두 개를 겹쳐 씀
		t += 0.4
	return t


func _cast_element(pattern: int) -> float:
	if is_dead() or not has_target():
		return 0.8
	match pattern:
		Pattern.FIRE:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.16), 140.0, fire_damage, fire_texture, 0.0, Elements.Type.FIRE, get_hit_center() + Vector2(14, -34))
			return 1.0
		Pattern.FROST:
			for i in 8:
				telegraph_strike(_player.global_position + Vector2.from_angle(TAU * i / 8.0) * 46.0, 18.0, 0.9, frost_damage, Elements.Type.ICE, 1.2)
			telegraph_strike(_player.global_position, 18.0, 1.1, frost_damage, Elements.Type.ICE, 1.2)
			return 1.3
		Pattern.LIGHTNING:
			for i in 5:
				_after(0.25 * i, func() -> void:
					if not is_dead() and has_target():
						telegraph_strike(_player.global_position, 20.0, 0.6, lightning_damage, Elements.Type.LIGHTNING))
			return 1.6
		Pattern.ARCANE:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if not is_dead():
						for i in 14:
							shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 105.0, arcane_damage, arcane_texture, 0.0, Elements.Type.ARCANE))
			return 1.1
		Pattern.BLINK:
			var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(150, 60), Vector2(300, 200))
			Fx.burst(self, get_hit_center(), Color(0.6, 0.5, 1.0), 12, 60.0, 0.35)
			global_position = Vector2(randf_range(area.position.x + 40.0, area.end.x - 40.0), randf_range(area.position.y + 40.0, area.get_center().y))
			Fx.flash(self, get_hit_center(), Color(0.7, 0.6, 1.0), 30.0, 0.3)
			return 0.6
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("아르카나: 이제부터가 진짜 마법이다…! 원소 마법이 겹쳐 온다", Color(0.75, 0.6, 1.0))
