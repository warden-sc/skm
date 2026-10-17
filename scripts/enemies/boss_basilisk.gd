class_name BossBasilisk
extends PatternBoss
## 24스테이지(마지막) 보스: 맹독의 패주 바실리스크 — 맹독의 늪을 다스리는 왕관 볏의 거대 독룡.
##   GAZE   : 석화의 눈 — 노란 눈빛이 일직선으로 뻗음 (예고), 맞으면 1.5초 석화 (조작 불가)
##   TAIL   : 꼬리 휩쓸기 — 몸 주위 큰 장판
##   LUNGE  : 독니 돌진 — 예고선 뒤 일직선 돌진
##   SUMMON : 독 도마뱀 · 맹독 거미 호출
##
## [기믹] 독샘: 머리 위에 독샘이 있고 체력이 따로 (작은 체력 바)
##   - 독샘이 살아 있는 동안
##       · 보스방 가장자리부터 독안개가 점점 차올라 fog_time 뒤엔 보스방 전체를 덮음 (안개 속에 있으면 독)
##       · breath_interval 마다 독 브레스 (독 탄 부채꼴 여러 줄기)
##   - 독샘을 부수면 독안개가 걷히고 독 브레스도 더는 쓰지 못함
## [독] 독에 걸리면 지속 피해 + 포션 회복량 -50% (Player 가 GameManager.potion_heal_multiplier 로 반영)
## 체력 50% 이하: 독 브레스가 더 넓어지고, 석화의 눈이 세 갈래

enum Pattern { GAZE, TAIL, LUNGE, SUMMON }

const GLAND_OFFSET := Vector2(21, -50)

@export var gland_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var poison_texture: Texture2D
@export var breath_damage: int = 34
@export var tail_damage: int = 60
@export var lunge_damage: int = 62
@export var gaze_damage: int = 40
@export var poison_tick: int = 9
@export var gland_hp_ratio: float = 0.08
@export var fog_time: float = 45.0
@export var breath_interval: float = 8.0
@export var petrify_time: float = 1.5

var gland: BossPart
var fog: PoisonFog
var _gland_requested: bool = false
var _gland_broken: bool = false
var _breath_timer: float = 4.0
var _breaths: int = 0
var _petrifies: int = 0
var _lunge_dir: Vector2 = Vector2.ZERO
var _lunge_windup: float = 0.0
var _lunge_left: float = 0.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.GAZE, Pattern.TAIL, Pattern.LUNGE, Pattern.SUMMON, Pattern.GAZE, Pattern.LUNGE]


func has_gland() -> bool:
	return gland != null and is_instance_valid(gland) and not gland.is_dead()


func is_gland_broken() -> bool:
	return _gland_broken


func get_fog() -> PoisonFog:
	return fog if fog != null and is_instance_valid(fog) else null


func get_breath_count() -> int:
	return _breaths


func get_petrify_count() -> int:
	return _petrifies


func _get_move_velocity(delta: float) -> Vector2:
	if not _gland_requested:
		_gland_requested = true
		if gland_scene != null:
			request_summon(gland_scene, global_position + GLAND_OFFSET)
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(220, 60), Vector2(440, 300))
		fog = PoisonFog.spawn(self, area, fog_time, poison_tick)
	if has_gland() and has_target():
		_breath_timer -= delta
		if _breath_timer <= 0.0 and not is_casting():
			breath()
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and gland == null:
		gland = minion as BossPart
		gland.boss = self
		gland.anchor_offset = GLAND_OFFSET
		gland.mirror_x = true
		gland.max_hp = maxi(1, roundi(max_hp * gland_hp_ratio))
		gland.died.connect(_on_gland_broken)


# ============================================================ 기믹: 독샘 · 독안개 · 독 브레스
func _on_gland_broken(_enemy: Enemy) -> void:
	_gland_broken = true
	gland = null
	if get_fog() != null:
		fog.recede()
	set_status("독샘이 터졌다! 독안개가 걷힌다", Color(0.7, 1.0, 0.5))
	_after(2.0, func() -> void:
		if get_status_text().begins_with("독샘이"):
			set_status("", Color.WHITE))
	GameManager.show_notice("바실리스크의 독샘을 부쉈다! 독안개가 걷히고 독 브레스를 쓰지 못한다", Color(0.7, 1.0, 0.5))
	stun(1.5)
	Fx.explosion(self, global_position + Vector2(GLAND_OFFSET.x * (-1.0 if sprite.flip_h else 1.0), GLAND_OFFSET.y), Color(0.5, 0.9, 0.3), 36.0, 2)


## 독 브레스: 독 탄 부채꼴이 여러 줄기로 (맞으면 독)
func breath() -> void:
	if not has_gland() or is_dead() or not has_target():
		return
	_breath_timer = breath_interval
	_breaths += 1
	set_status("독 브레스!", Color(0.6, 1.0, 0.4))
	var mouth := global_position + Vector2(30.0 * (-1.0 if sprite.flip_h else 1.0), -40.0)
	var aim := mouth.direction_to(_player.global_position)
	var spread := 0.9 if phase_two else 0.6
	for w in 4:
		_after(0.15 * w, func() -> void:
			if is_dead() or not has_gland():
				return
			var saved_burn := burn_damage
			var saved_poison := burn_is_poison
			var saved_time := burn_duration
			burn_damage = poison_tick
			burn_is_poison = true
			burn_duration = 4.0
			for i in 6:
				var t := float(i) / 5.0 - 0.5
				shoot(aim.rotated(t * spread + sin(w * 1.7) * 0.05), 150.0, breath_damage, poison_texture, 0.0, Elements.Type.NATURE, mouth)
			burn_damage = saved_burn
			burn_is_poison = saved_poison
			burn_duration = saved_time)
	_after(1.0, func() -> void:
		if get_status_text() == "독 브레스!":
			set_status("", Color.WHITE))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.GAZE:
			return gaze()
		Pattern.TAIL:
			telegraph_strike(get_hit_center(), 64.0, 0.9, tail_damage, Elements.Type.NATURE)
			return 1.3
		Pattern.LUNGE:
			_lunge_dir = direction_to_player()
			_lunge_windup = 0.6
			_lunge_left = 0.0
			for i in 5:
				telegraph_strike(get_hit_center() + _lunge_dir * (30.0 + 30.0 * i), 18.0, 0.6 + 0.07 * i, lunge_damage, Elements.Type.NATURE)
			return 1.4
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 30.0))
			return 0.9
	return 1.0


## 석화의 눈: 일직선 예고 → 그 줄 위에 있으면 피해 + 석화 (테스트에서도 직접 호출)
func gaze() -> float:
	if not has_target():
		return 0.5
	set_status("석화의 눈!", Color(1.0, 0.95, 0.4))
	var eye := global_position + Vector2(24.0 * (-1.0 if sprite.flip_h else 1.0), -44.0)
	var base := eye.direction_to(_player.global_position)
	var dirs: Array[Vector2] = [base]
	if phase_two:
		dirs.append(base.rotated(0.35))
		dirs.append(base.rotated(-0.35))
	for d in dirs:
		for i in 8:
			telegraph_strike(eye + d * (24.0 + 24.0 * i), 12.0, 0.8, gaze_damage, Elements.Type.LIGHTNING)
	_after(0.8, _resolve_gaze.bind(eye, dirs))
	return 1.3


func _resolve_gaze(eye: Vector2, dirs: Array[Vector2]) -> void:
	set_status("", Color.WHITE)
	if is_dead() or not has_target() or _player.is_dashing():
		return
	var p := _player.global_position + Vector2(0, -5) - eye
	for d in dirs:
		var along := p.dot(d)
		if along > 10.0 and along < 24.0 + 24.0 * 8 and absf(p.cross(d)) < 16.0:
			_petrifies += 1
			_player.apply_charm(petrify_time, null, "석화")
			return


func _casting_velocity(delta: float) -> Vector2:
	if _lunge_windup > 0.0:
		_lunge_windup -= delta
		if _lunge_windup <= 0.0:
			_lunge_left = 0.4
		return Vector2.ZERO
	if _lunge_left > 0.0:
		_lunge_left -= delta
		return _lunge_dir * 360.0
	return Vector2.ZERO


func _die() -> void:
	if get_fog() != null:
		fog.recede()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("바실리스크가 분노한다! 독 브레스가 넓어지고 석화의 눈이 세 갈래로", Color(0.6, 1.0, 0.4))
