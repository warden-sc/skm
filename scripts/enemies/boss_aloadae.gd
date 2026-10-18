class_name BossAloadae
extends PatternBoss
## 55스테이지 보스: 거인 형제 알로아다이 「오토스 & 에피알테스」 — 전쟁의 신 아레스를 청동 항아리에 가둔 쌍둥이 거인.
## 오토스(role = OTUS)가 보스방에 나타나면서 에피알테스(role = EPHIALTES)를 불러냅니다. 보스 체력 바는 오토스, 에피알테스는 머리 위 작은 체력 바.
##   SPEAR   : 거대한 창 찌르기 (일직선)
##   STOMP   : 발 구르기 — 몸 주위 고리
##   BOULDER : 바위 던지기 (플레이어 주변 장판)
##   SUMMON  : 어린 거인 · 바위 투척병 호출
##
## [기믹] 형제의 힘: 형제가 둘 다 서 있으면 서로 방어력 +brother_defense (따로 잡으려 하면 매우 단단함)
## [기믹] 황금 사슴: hind_interval 초마다 아르테미스의 황금 사슴이 나타남 — 플레이어가 다가가면 반대쪽으로 달아남
##   사슴을 형제 사이로 몰아넣으면 둘이 사슴을 노리고 던진 창이 서로를 꿰뚫음
##   → 둘 다 최대 체력의 clash_ratio 만큼 피해 + 기절 + wound_time 초 동안 「형제의 힘」 사라짐
## 한쪽이 쓰러지면 남은 쪽이 분노 (공격력 상승). 오토스가 쓰러지면 싸움이 끝남
## 체력 50% 이하: 공격이 거세짐

enum Role { OTUS, EPHIALTES }
enum Pattern { SPEAR, STOMP, BOULDER, SUMMON }

@export var role: Role = Role.OTUS
@export var partner_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var rock_texture: Texture2D
@export var spear_damage: int = 92
@export var stomp_damage: int = 84
@export var boulder_damage: int = 76
@export var brother_defense: int = 25
@export var hind_interval: float = 12.0
@export var clash_ratio: float = 0.08
@export var wound_time: float = 8.0

var partner: BossAloadae
var hind: GoldenHind
var _hind_left: float = 4.0
var _clashes: int = 0
var _wound_left: float = 0.0
var _base_defense: int = 0
var _base_power: float = 1.0
var _enraged: bool = false
var _partner_requested: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	if role == Role.OTUS:
		pattern_order = [Pattern.SPEAR, Pattern.STOMP, Pattern.BOULDER, Pattern.SPEAR, Pattern.SUMMON]
	else:
		pattern_order = [Pattern.BOULDER, Pattern.SPEAR, Pattern.STOMP, Pattern.BOULDER]
		_btimer = chase_time * 1.5


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power
	_base_defense = defense


func has_partner() -> bool:
	return partner != null and is_instance_valid(partner) and not partner.is_dead()


func get_clash_count() -> int:
	return _clashes


func is_wounded() -> bool:
	return _wound_left > 0.0


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if role == Role.OTUS and not _partner_requested and partner_scene != null and has_target():
		_partner_requested = true
		request_summon(partner_scene, global_position + Vector2(160, 0))
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossAloadae and partner == null:
		partner = minion as BossAloadae
		partner.partner = self
		partner.arena_rect = arena_rect
		partner.died.connect(_on_partner_died)


func _physics_process(delta: float) -> void:
	if not is_dead():
		_wound_left = maxf(_wound_left - delta, 0.0)
		defense = _base_defense + (brother_defense if has_partner() and not is_wounded() else 0)
		if role == Role.OTUS and has_partner():
			_update_hind(delta)
		if is_wounded():
			set_status("상처 입음 — 형제의 힘 없음 %.0f초" % _wound_left, Color(1.0, 0.6, 0.5))
		elif has_partner():
			set_status("형제의 힘 (방어력 +%d)" % brother_defense, Color(0.8, 0.85, 1.0))
		elif _enraged:
			set_status("형제를 잃은 분노!", Color(1.0, 0.4, 0.3))
	super._physics_process(delta)


func _update_hind(delta: float) -> void:
	if hind == null or not is_instance_valid(hind):
		_hind_left -= delta
		if _hind_left <= 0.0:
			_hind_left = hind_interval
			var at := _area().get_center() + Vector2(randf_range(-200, 200), randf_range(-110, 110))
			hind = GoldenHind.spawn(self, at, _area())
			GameManager.show_notice("아르테미스의 황금 사슴이 나타났다! 거인 형제 사이로 몰아라", Color(1.0, 0.9, 0.5))
		return
	if is_stunned() or partner.is_stunned():
		return
	if hind_between_brothers(hind.global_position):
		clash()


## 사슴이 두 거인 사이(둘을 잇는 선 근처)에 있는지
func hind_between_brothers(at: Vector2) -> bool:
	if not has_partner():
		return false
	var a := global_position
	var b := partner.global_position
	if a.distance_to(b) < 60.0:
		return false
	var closest := Geometry2D.get_closest_point_to_segment(at, a, b)
	return closest.distance_to(at) < 22.0 and closest.distance_to(a) > 16.0 and closest.distance_to(b) > 16.0


## 서로를 찌름 (테스트에서도 직접 호출)
func clash() -> void:
	if not has_partner():
		return
	_clashes += 1
	if hind != null and is_instance_valid(hind):
		Fx.burst(hind, hind.global_position, Color(1.0, 0.9, 0.5), 20, 70.0, 0.6)
		hind.queue_free()
	hind = null
	_hind_left = hind_interval
	for giant: BossAloadae in [self, partner]:
		giant._wound_left = wound_time
		giant.take_damage(roundi(giant.max_hp * clash_ratio), Vector2.ZERO, false, 999999)
		if not giant.is_dead():
			giant.stun(7.0)
		Fx.cross_glint(giant, giant.get_hit_center(), Color(1.0, 0.5, 0.4), 24.0)
	GameManager.show_notice("황금 사슴을 노린 창이 거인 형제를 서로 꿰뚫었다!", Color(1.0, 0.85, 0.5))


func _on_partner_died(_enemy: Enemy) -> void:
	partner = null
	_enrage()


func _enrage() -> void:
	if _enraged or is_dead():
		return
	_enraged = true
	power = _base_power * 1.2
	GameManager.show_notice("형제를 잃은 거인이 분노한다!", Color(1.0, 0.5, 0.4))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SPEAR:
			for i in 11:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 15.0, 0.65 + 0.03 * i, spear_damage, Elements.Type.NONE)
			return 1.2
		Pattern.STOMP:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 52.0, 22.0, 0.85, stomp_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.BOULDER:
			for i in (4 if phase_two else 3):
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 60.0)
				telegraph_strike(at, 26.0, 1.0 + 0.15 * i, boulder_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				request_summon(minion_scenes.pick_random(), global_position + Vector2(0, 40))
			return 0.8
	return 1.0


func _die() -> void:
	if role == Role.OTUS:
		if has_partner():
			partner.despawn()
		if hind != null and is_instance_valid(hind):
			hind.queue_free()
	elif partner != null and is_instance_valid(partner):
		partner._on_partner_died(self)
	super._die()


func _on_phase_two() -> void:
	if role == Role.OTUS:
		GameManager.show_notice("거인 형제: 올림포스 위에 산을 쌓아 주마! 공격이 거세진다", Color(0.9, 0.8, 0.6))


## 에피알테스: 머리 위 작은 체력 바 (보스 체력 바는 오토스)
func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if role == Role.EPHIALTES:
		queue_redraw()


func _draw() -> void:
	if role != Role.EPHIALTES or is_dead():
		return
	var w := 40.0
	var ratio := float(hp) / float(maxi(max_hp, 1))
	draw_rect(Rect2(-w * 0.5, sprite.position.y - 40.0, w, 4.0), Color(0.1, 0.08, 0.05, 0.85))
	draw_rect(Rect2(-w * 0.5, sprite.position.y - 40.0, w * ratio, 4.0), Color(1.0, 0.45, 0.35))
