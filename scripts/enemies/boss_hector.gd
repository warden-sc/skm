class_name BossHector
extends PatternBoss
## 68스테이지 보스: 트로이의 영웅 헥토르 — 투구가 번쩍이는 트로이 제일의 장수. 아폴론이 몇 번이고 안개로 감싸 구해 냈습니다.
##   SPEAR   : 창 찌르기 (일직선 둘)
##   ARCHERS : 트로이 성벽의 궁수 지원 — 보스방 위쪽 끝에서 화살비
##   GLARE   : 번쩍이는 투구 — 몸 주위 빛의 고리
##   SUMMON  : 트로이 근위병 · 궁수 호출
##
## [기믹] 아폴론의 안개: 체력이 2/3 · 1/3 아래로 떨어지는 순간 안개에 감싸여 사라짐 (veil_time 초 무적)
##   → 다른 곳에서 나타나며 「빛의 제단」이 서 있는 수만큼 회복 (제단 1개마다 최대 체력의 heal_per_altar)
##   빛의 제단 3개(체력 따로)를 미리 부숴 두면 안개가 모이지 않아 사라지지 못하고 크게 휘청임
## 체력 50% 이하: 성벽 궁수의 화살이 늘어남

enum Pattern { SPEAR, ARCHERS, GLARE, SUMMON }

const ALTAR_SPOTS := [Vector2(-230, -110), Vector2(230, -110), Vector2(0, 125)]

@export var altar_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var arrow_texture: Texture2D
@export var spear_damage: int = 96
@export var arrow_damage: int = 60
@export var glare_damage: int = 84
@export var altar_hp_ratio: float = 0.03
@export var veil_time: float = 3.0
@export var heal_per_altar: float = 0.08

var altars: Array[BossPart] = []
var _veils_done: int = 0
var _veil_left: float = 0.0
var _healed: int = 0
var _failed_veils: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPEAR, Pattern.ARCHERS, Pattern.GLARE, Pattern.SPEAR, Pattern.SUMMON]
	immune_text = "아폴론의 안개 속 — 무적"


func get_altars() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for a in altars:
		if is_instance_valid(a) and not a.is_dead():
			alive.append(a)
	return alive


func is_veiled() -> bool:
	return _veil_left > 0.0


func get_healed_total() -> int:
	return _healed


func get_failed_veils() -> int:
	return _failed_veils


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if altar_scene != null:
			for spot in ALTAR_SPOTS:
				request_summon(altar_scene, _area().get_center() + spot)
		_update_status()
	if is_veiled():
		return Vector2.ZERO
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart:
		return
	var altar := minion as BossPart
	altar.boss = self
	altar.follow_boss = false
	altar.max_hp = maxi(1, roundi(max_hp * altar_hp_ratio))
	altar.hp = altar.max_hp
	altar.died.connect(func(_e: Enemy) -> void: _update_status())
	altars.append(altar)


func can_be_hit_by(kind: HitKind) -> bool:
	return not is_veiled() and super.can_be_hit_by(kind)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_veiled():
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if is_dead():
		return
	var crossed := 0
	if float(hp) < max_hp * (2.0 / 3.0):
		crossed = 1
	if float(hp) < max_hp * (1.0 / 3.0):
		crossed = 2
	if crossed > _veils_done:
		_veils_done = crossed
		veil()


## 아폴론의 안개 (테스트에서도 직접 호출)
func veil() -> void:
	var n := get_altars().size()
	if n == 0:
		_failed_veils += 1
		super.stun(10.0)
		Net.announce("빛의 제단이 없어 아폴론의 안개가 모이지 않는다! 헥토르가 휘청인다", Color(1.0, 0.85, 0.5))
		return
	_veil_left = veil_time
	airborne = true  # 안개 속: 몸통 접촉 피해 없음
	sprite.modulate.a = 0.15
	Fx.burst(self, get_hit_center(), Color(1.0, 0.95, 0.8), 30, 60.0, 0.8, Vector2(0, -30))
	Net.announce("아폴론의 안개가 헥토르를 감싼다! 빛의 제단을 부숴야 막을 수 있다", Color(1.0, 0.95, 0.75))
	_update_status()


func _reappear() -> void:
	_veil_left = 0.0
	airborne = false
	sprite.modulate.a = 1.0
	var area := _area().grow(-50.0)
	var best := global_position
	for i in 8:
		var at := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if not has_target() or at.distance_to(_player.global_position) > best.distance_to(_player.global_position):
			best = at
	global_position = best
	var heal := mini(roundi(max_hp * heal_per_altar * get_altars().size()), max_hp - hp)
	hp += heal
	_healed += heal
	health_changed.emit(hp, max_hp)
	Fx.burst(self, get_hit_center(), Color(1.0, 0.95, 0.7), 24, 70.0, 0.6, Vector2(0, -40))
	FloatingText.spawn(self, global_position + Vector2(0, -50), "+%d" % heal, Color(0.6, 1.0, 0.6), true)
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _veil_left > 0.0:
		_veil_left -= delta
		if _veil_left <= 0.0:
			_reappear()
	super._physics_process(delta)


func _update_status() -> void:
	if is_veiled():
		set_status("아폴론의 안개 속", Color(1.0, 0.95, 0.8))
	else:
		set_status("빛의 제단 %d개 — 안개로 달아날 수 있음" % get_altars().size(), Color(1.0, 0.9, 0.6))


func _run_pattern(pattern: int) -> float:
	if not has_target() or is_veiled():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SPEAR:
			for k in 2:
				var d := dir.rotated((k - 0.5) * 0.3)
				for i in 10:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.NONE)
			return 1.1
		Pattern.ARCHERS:
			var top := _area().position.y + 10.0
			for i in (9 if phase_two else 6):
				var from := Vector2(_area().position.x + 40.0 + i * (_area().size.x - 80.0) / (8.0 if phase_two else 5.0), top)
				shoot(from.direction_to(_player.global_position), 190.0, arrow_damage, arrow_texture, 0.0, Elements.Type.NONE, from)
			return 1.0
		Pattern.GLARE:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 50.0, 20.0, 0.85, glare_damage, Elements.Type.HOLY)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	sprite.modulate.a = 1.0
	super._die()


func _on_phase_two() -> void:
	Net.announce("헥토르: 트로이의 성벽이여, 나를 지켜라! 성벽 궁수가 늘어난다", Color(1.0, 0.7, 0.5))
