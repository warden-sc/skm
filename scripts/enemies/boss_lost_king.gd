class_name BossLostKing
extends PatternBoss
## 10스테이지 보스: 옥좌 잃은 왕 — 어둠의 성(5스테이지)에서 기사단장 듀라한이 지키던 빈 옥좌의 주인.
## 왕국을 잃고 저주받은 왕관에 묶여, 무너진 왕궁에서 검은 안개를 두르고 있다.
##   DECREE : 왕명 — 홀로 가리킨 방향에 일직선 예고 장판
##   WRATH  : 왕의 분노 — 금빛 탄 고리 (2페이즈 2겹)
##   SUMMON : 근위병 · 궁정 마술사 호출
##   SLAM   : 홀로 바닥을 내리쳐 주변 장판
##
## [기믹] 왕관: 왕관은 왕과 체력이 따로 있음 (머리 위에 떠 있는 왕관을 따로 공격)
##   - 왕관이 살아 있으면 barrier_interval 마다 「왕관의 가호」(barrier_time 동안 왕이 모든 공격을 막음)
##   - 왕관을 부수면 가호가 사라지고, 왕이 잠깐 휘청임
## 체력 50% 이하: 패턴 강화

enum Pattern { DECREE, WRATH, SUMMON, SLAM }

@export var crown_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var bolt_texture: Texture2D
@export var decree_damage: int = 44
@export var wrath_damage: int = 28
@export var crown_hp_ratio: float = 0.15
@export var barrier_interval: float = 7.0
@export var barrier_time: float = 3.0

var crown: Enemy
var _crown_requested: bool = false
var _crown_broken: bool = false
var _barrier_cooldown: float = 3.0
var _barrier_left: float = 0.0
var _barrier_ring: Sprite2D
var _mist: CPUParticles2D
var _greeted: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.DECREE, Pattern.WRATH, Pattern.SLAM, Pattern.SUMMON, Pattern.DECREE, Pattern.WRATH]
	_barrier_ring = Sprite2D.new()
	_barrier_ring.texture = Fx.RING_TEXTURE
	_barrier_ring.material = Fx.additive_material()
	_barrier_ring.modulate = Color(1.0, 0.85, 0.35, 0.9)
	_barrier_ring.position = get_hit_center() - global_position
	_barrier_ring.scale = Vector2.ONE * 3.0
	_barrier_ring.z_index = 4
	_barrier_ring.hide()
	add_child(_barrier_ring)
	_mist = Fx.make_dark_mist(22, 18.0)
	_mist.name = "DarkMist"
	_mist.position = get_hit_center() - global_position
	_mist.z_index = -1  # 몸 뒤로 퍼져 실루엣이 보이도록
	add_child(_mist)
	_mist.emitting = true


func has_crown() -> bool:
	return crown != null and is_instance_valid(crown) and not crown.is_dead()


func is_barrier_up() -> bool:
	return _barrier_left > 0.0


func _get_move_velocity(delta: float) -> Vector2:
	if not _crown_requested and crown_scene != null:
		_crown_requested = true
		request_summon(crown_scene, global_position + Vector2(0, -52))
	if not _greeted:
		_greeted = true
		set_status("듀라한… 짐의 옥좌는 아직 무사하더냐…", Color(0.8, 0.65, 1.0))
		_after(3.0, func() -> void:
			if not is_barrier_up() and get_status_text().begins_with("듀라한"):
				set_status("", Color.WHITE))
	if _barrier_left > 0.0:
		_barrier_left -= delta
		_barrier_ring.rotation += delta * 2.0
		if _barrier_left <= 0.0:
			_barrier_ring.hide()
			set_status("", Color.WHITE)
	elif has_crown():
		_barrier_cooldown -= delta
		if _barrier_cooldown <= 0.0:
			raise_barrier()
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is CrownEnemy and crown == null:
		crown = minion
		(minion as CrownEnemy).king = self
		minion.max_hp = maxi(1, roundi(max_hp * crown_hp_ratio))
		minion.died.connect(_on_crown_broken)


# ============================================================ 기믹: 왕관
## 「왕관의 가호」: barrier_time 동안 왕은 모든 공격을 막음 (왕관이 살아 있을 때만)
func raise_barrier() -> void:
	if not has_crown() or is_dead():
		return
	_barrier_left = barrier_time
	_barrier_cooldown = barrier_interval * (0.8 if phase_two else 1.0)
	_barrier_ring.show()
	set_status("왕관의 가호: 공격 무효 — 왕관을 먼저 부숴라!", Color(1.0, 0.85, 0.35))
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.85, 0.35), 50.0, 0.35)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_barrier_up() and not is_dead():
		FloatingText.spawn(self, global_position + Vector2(0, -30), "가호", Color(1.0, 0.85, 0.35))
		Fx.burst(self, get_hit_center(), Color(1.0, 0.85, 0.35), 5, 30.0, 0.25)
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _on_crown_broken(_enemy: Enemy) -> void:
	_crown_broken = true
	crown = null
	_barrier_left = 0.0
	_barrier_ring.hide()
	set_status("왕관이… 짐의 마지막 왕권이…!", Color(1.0, 0.7, 0.4))
	_after(1.5, set_status.bind("", Color.WHITE))
	GameManager.show_notice("왕관이 부서졌다! 이제 왕관의 가호가 없다", Color(1.0, 0.85, 0.4))
	stun(2.0)
	Fx.explosion(self, get_hit_center() + Vector2(0, -40), Color(1.0, 0.85, 0.35), 40.0, 3)


func is_crown_broken() -> bool:
	return _crown_broken


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.DECREE:
			var dir := direction_to_player()
			for i in 6:
				telegraph_strike(get_hit_center() + dir * (28.0 + 26.0 * i), 16.0, 0.7 + 0.06 * i, decree_damage, Elements.Type.DARK)
			return 1.3
		Pattern.WRATH:
			var waves := 2 if phase_two else 1
			for w in waves:
				_after(0.4 * w, _wrath.bind(w))
			return 0.8 + 0.4 * waves
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 20.0))
			return 1.0
		Pattern.SLAM:
			telegraph_strike(get_hit_center(), 56.0, 0.9, decree_damage, Elements.Type.DARK)
			return 1.3
	return 1.0


func _wrath(wave: int) -> void:
	if is_dead():
		return
	for i in 20:
		shoot(Vector2.RIGHT.rotated(TAU * i / 20.0 + wave * 0.16), 105.0, wrath_damage, bolt_texture, 0.0, Elements.Type.DARK)


func _on_phase_two() -> void:
	GameManager.show_notice("옥좌 잃은 왕: 듀라한마저 쓰러뜨렸단 말이냐… 짐의 옥좌를 돌려다오!", Color(0.8, 0.6, 1.0))
