class_name BossMarionette
extends PatternBoss
## 18스테이지 보스: 꼭두각시 마리오네트 — 불 꺼진 인형 극장에서 주인을 잃고 스스로 실을 조종하게 된 저주받은 인형.
## 몸에서 검은 안개가 피어오름.
##   STRINGS : 실 베기 — 자기 몸에서 사방으로 뻗는 실 5줄 (예고 장판 줄)
##   DANCE   : 인형의 춤 — 빙글 돌며 탄을 나선으로 뿌림
##   NEEDLE  : 바늘 — 플레이어 쪽 부채꼴
##   SUMMON  : 인형 병사 · 광대 인형 호출
##
## [기믹] 꼭두각시 조종 (control_interval 마다):
##   - 플레이어에게 실 4가닥이 걸려 캐릭터를 마리오네트가 조종함 (공격·가드·대시 불가, 마리오네트 쪽으로 끌려감)
##   - 보스방 가장자리 네 곳(위·아래·왼쪽·오른쪽)에 스위치가 하나씩 → 밟을 때마다 실이 하나씩 끊어지며 구속력이 약해짐
##     (구속력 90% → 68% → 46% → 24%: 약해질수록 내 이동 입력이 더 먹힘)
##   - 스위치 4개를 모두 누르면 구속에서 해방, 마리오네트는 실이 끊긴 반동으로 잠깐 휘청임
##   - control_max_time 이 지나면 저절로 풀림
## 체력 50% 이하: 조종이 더 자주 옴

enum Pattern { STRINGS, DANCE, NEEDLE, SUMMON }

const THREADS := 4
## 남은 실 수별 구속력 (index = 남은 실 수)
const STRENGTH_BY_THREADS: Array[float] = [0.0, 0.24, 0.46, 0.68, 0.9]

@export var minion_scenes: Array[PackedScene] = []
@export var needle_texture: Texture2D
@export var orb_texture: Texture2D
@export var string_damage: int = 50
@export var needle_damage: int = 32
@export var dance_damage: int = 30
@export var control_interval: float = 16.0
@export var control_max_time: float = 16.0

var _switches: Array[PuppetSwitch] = []
var _switches_placed: bool = false
var _control_cooldown: float = 6.0
var _control_left: float = 0.0
var _threads: int = 0
var _controls: int = 0
var _releases: int = 0
var _thread_lines: Node2D


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.STRINGS, Pattern.NEEDLE, Pattern.DANCE, Pattern.SUMMON, Pattern.STRINGS, Pattern.NEEDLE]
	_thread_lines = Node2D.new()
	_thread_lines.top_level = true
	_thread_lines.z_index = 40
	_thread_lines.draw.connect(_draw_threads)
	add_child(_thread_lines)
	var mist := Fx.make_dark_mist(20, 16.0)
	mist.name = "DarkMist"
	mist.position = get_hit_center() - global_position
	mist.z_index = -1
	add_child(mist)
	mist.emitting = true


func get_switches() -> Array[PuppetSwitch]:
	return _switches


func is_controlling() -> bool:
	return _threads > 0


func get_threads() -> int:
	return _threads


func get_control_count() -> int:
	return _controls


func get_release_count() -> int:
	return _releases


func _get_move_velocity(delta: float) -> Vector2:
	if not _switches_placed:
		_switches_placed = true
		_place_switches()
	_thread_lines.queue_redraw()
	if is_controlling():
		_control_left -= delta
		_update_puppet()
		if _control_left <= 0.0:
			end_control(false)
	elif has_target():
		_control_cooldown -= delta
		if _control_cooldown <= 0.0 and not is_casting():
			begin_control()
	return super._get_move_velocity(delta)


func _place_switches() -> void:
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(220, 60), Vector2(440, 300))
	var c := area.get_center()
	var inset := 26.0
	for at in [Vector2(c.x, area.position.y + inset), Vector2(c.x, area.end.y - inset), Vector2(area.position.x + inset, c.y), Vector2(area.end.x - inset, c.y)]:
		var sw := PuppetSwitch.spawn(self, at)
		if sw != null:
			sw.pressed.connect(_on_switch_pressed)
			_switches.append(sw)


# ============================================================ 기믹: 꼭두각시 조종
func begin_control() -> void:
	if is_controlling() or is_dead() or not has_target():
		return
	_threads = THREADS
	_controls += 1
	_control_left = control_max_time
	for sw in _switches:
		if is_instance_valid(sw):
			sw.activate()
	_update_puppet()
	set_status("꼭두각시 조종: 실 %d가닥" % _threads, Color(1.0, 0.75, 0.9))
	Net.announce("마리오네트의 실에 묶였다! 가장자리의 스위치 4개를 밟아 실을 끊어라", Color(1.0, 0.75, 0.9))
	FloatingText.spawn(_player, _player.global_position + Vector2(0, -24), "조종당함!", Color(1.0, 0.7, 0.9), true)


func _on_switch_pressed(_sw: PuppetSwitch) -> void:
	if not is_controlling() or is_dead():
		return
	_threads -= 1
	FloatingText.spawn(self, global_position + Vector2(0, -50), "실이 끊어졌다! (%d/%d)" % [THREADS - _threads, THREADS], Color(1.0, 0.9, 0.5), true)
	if _threads <= 0:
		end_control(true)
		return
	_update_puppet()
	set_status("꼭두각시 조종: 실 %d가닥" % _threads, Color(1.0, 0.75, 0.9))


func end_control(freed: bool) -> void:
	_threads = 0
	_control_cooldown = control_interval * (0.75 if phase_two else 1.0)
	for sw in _switches:
		if is_instance_valid(sw):
			sw.deactivate()
	if _player != null and is_instance_valid(_player):
		_player.release_puppet()
	if freed:
		_releases += 1
		set_status("실이 모두 끊겼다!", Color(1.0, 0.9, 0.5))
		Net.announce("구속에서 해방되었다! 마리오네트가 휘청인다", Color(1.0, 0.9, 0.5))
		stun(3.0)
	else:
		set_status("", Color.WHITE)
	_after(1.5, func() -> void:
		if not is_controlling():
			set_status("", Color.WHITE))


func _update_puppet() -> void:
	if has_target():
		_player.set_puppet(self, STRENGTH_BY_THREADS[clampi(_threads, 0, THREADS)], _threads)


## 플레이어(Player)가 매 프레임 물어봄: 마리오네트가 끄는 방향 — 자기 쪽으로 끌어당겨 곁을 맴돌게 함
func get_puppet_pull(player: Node2D) -> Vector2:
	var to_me := global_position + Vector2(0, 20) - player.global_position
	if to_me.length() > 46.0:
		return to_me.normalized()
	return to_me.normalized().orthogonal()


func _draw_threads() -> void:
	if not is_controlling() or not has_target():
		return
	var hands: Array[Vector2] = [Vector2(-12, -44), Vector2(12, -44), Vector2(-6, -60), Vector2(6, -60)]
	var target := _player.global_position + Vector2(0, -10)
	for i in _threads:
		var from := global_position + hands[i]
		var wobble := Vector2(sin(_anim_time * 6.0 + i) * 3.0, 0.0)
		_thread_lines.draw_line(from, target + wobble, Color(0.75, 0.7, 0.8, 0.8), 1.0)


func _die() -> void:
	if is_controlling():
		end_control(false)
	for sw in _switches:
		if is_instance_valid(sw):
			sw.queue_free()
	super._die()


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.STRINGS:
			var base := direction_to_player().angle()
			for k in 5:
				var dir := Vector2.from_angle(base + TAU * k / 5.0)
				for i in 6:
					telegraph_strike(get_hit_center() + dir * (28.0 + 24.0 * i), 13.0, 0.8 + 0.05 * i, string_damage, Elements.Type.ARCANE)
			return 1.4
		Pattern.DANCE:
			set_status("인형의 춤", Color(1.0, 0.75, 0.9))
			for k in 18:
				_after(0.06 * k, _dance.bind(k))
			_after(1.3, func() -> void:
				if get_status_text() == "인형의 춤":
					set_status("", Color.WHITE))
			return 1.5
		Pattern.NEEDLE:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.14), 160.0, needle_damage, needle_texture, 0.0, Elements.Type.NONE)
			return 0.9
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 30.0))
			return 1.0
	return 1.0


func _dance(step: int) -> void:
	if is_dead():
		return
	for arm in 2:
		shoot(Vector2.from_angle(step * 0.35 + PI * arm), 110.0, dance_damage, orb_texture, 0.0, Elements.Type.ARCANE)


func _on_phase_two() -> void:
	Net.announce("마리오네트의 실이 더 질겨졌다… 조종이 더 자주 온다", Color(1.0, 0.75, 0.9))
