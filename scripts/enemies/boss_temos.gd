class_name BossTemos
extends PatternBoss
## 21스테이지 보스: 기계의 정점 테모스 — 기계 신전의 꼭대기에서 스스로를 완성한 기계 거인.
## 몸통 한가운데 거대한 태엽을 중심으로 작은 태엽들이 맞물려 돌아감 (톱니는 따로 돌아가는 스프라이트).
##   GEARS  : 톱니 탄 부채꼴
##   STEAM  : 증기 분출 — 몸 주위 고리 장판 (화상)
##   PISTON : 피스톤 주먹 — 플레이어 쪽으로 일직선 충격파 2줄
##   BARRAGE: 포격 — 플레이어 주변 예고 장판
##   SUMMON : 태엽 거미 · 기계 사수 호출
##
## [기믹] 냉각수 기계: 보스방 곳곳에 테모스와 배관으로 연결된 냉각수 기계 4대 (기계마다 체력이 따로)
##   - 테모스는 스킬을 쓸 때마다 열이 오름 (머리 위 열 게이지)
##   - 살아 있는 냉각수 기계가 많을수록 열이 빨리 식음 → 4대가 다 있으면 열이 쌓이지 않음
##   - 기계를 부술수록 열이 쌓이고, 열이 100에 닿으면 「과열」: 열이 정상(0)으로 돌아올 때까지
##     공격 불가 (스킬·몸통 피해 없음) + 방어력 50% 감소
## 체력 50% 이하: 스킬을 더 자주 씀 (= 열도 더 빨리 쌓임)

enum Pattern { GEARS, STEAM, PISTON, BARRAGE, SUMMON }

const GEAR_BIG: Texture2D = preload("res://assets/sprites/characters/gear_big.png")
const GEAR_SMALL: Texture2D = preload("res://assets/sprites/characters/gear_small.png")
const MACHINE_SPOTS: Array[Vector2] = [Vector2(-150, 40), Vector2(150, 40), Vector2(-110, 160), Vector2(110, 160)]
const MAX_HEAT := 100.0

@export var machine_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var gear_texture: Texture2D
@export var gear_damage: int = 36
@export var steam_damage: int = 56
@export var piston_damage: int = 60
@export var barrage_damage: int = 52
@export var machine_hp_ratio: float = 0.06
## 스킬 1번당 오르는 열
@export var heat_per_skill: float = 18.0
## 초당 식는 열 = base_cooling + 살아 있는 냉각수 기계 수 × cooling_per_machine
@export var base_cooling: float = 3.0
@export var cooling_per_machine: float = 14.0
## 과열 중 초당 식는 열
@export var overheat_cooling: float = 16.0

var heat: float = 0.0
var _machines: Array[BossPart] = []
var _machines_requested: bool = false
var _home: Vector2
var _overheated: bool = false
var _overheats: int = 0
var _base_defense: int = 0
var _base_contact: int = 0
var _skills: int = 0
var _gear_big: Sprite2D
var _gears_small: Array[Sprite2D] = []
var _overlay: Node2D
var _steam: CPUParticles2D


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.GEARS, Pattern.PISTON, Pattern.STEAM, Pattern.BARRAGE, Pattern.SUMMON, Pattern.GEARS, Pattern.PISTON]
	_base_defense = defense
	_base_contact = contact_damage
	# 가슴의 거대한 태엽 + 어깨의 작은 태엽 (스프라이트 자식이라 크기·좌우 반전을 따라감)
	_gear_big = Sprite2D.new()
	_gear_big.texture = GEAR_BIG
	_gear_big.position = Vector2(-0.5, 0.0)
	sprite.add_child(_gear_big)
	for x in [-17.0, 17.0]:
		var g := Sprite2D.new()
		g.texture = GEAR_SMALL
		g.position = Vector2(x, -17.0)
		sprite.add_child(g)
		_gears_small.append(g)
	_overlay = Node2D.new()
	_overlay.top_level = true
	_overlay.z_index = -3
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_steam = Fx.make_aura(Color(0.9, 0.9, 0.95), 24, 18.0, Vector2(0, -60), 0.9)
	_steam.position = get_hit_center() - global_position + Vector2(0, -20)
	_steam.z_index = 3
	add_child(_steam)
	_steam.emitting = false


func get_machines() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for m in _machines:
		if is_instance_valid(m) and not m.is_dead():
			alive.append(m)
	return alive


func is_overheated() -> bool:
	return _overheated


func get_overheat_count() -> int:
	return _overheats


func get_skill_count() -> int:
	return _skills


func get_cooling_rate() -> float:
	return overheat_cooling if _overheated else base_cooling + cooling_per_machine * get_machines().size()


func _get_move_velocity(delta: float) -> Vector2:
	if not _machines_requested:
		_machines_requested = true
		_home = global_position
		if machine_scene != null:
			for spot in MACHINE_SPOTS:
				request_summon(machine_scene, _home + spot)
	_overlay.queue_redraw()
	heat = maxf(heat - get_cooling_rate() * delta, 0.0)
	var spin := 1.0 + heat / MAX_HEAT * 3.0
	if _overheated:
		spin = 8.0 + sin(_anim_time * 20.0) * 3.0  # 과열: 태엽이 미친 듯이 헛돎
		if heat <= 0.0:
			_cool_down()
		else:
			_gear_big.rotation += delta * spin
			for g in _gears_small:
				g.rotation -= delta * spin * 1.8
			return Vector2.ZERO
	_gear_big.rotation += delta * spin
	for g in _gears_small:
		g.rotation -= delta * spin * 1.8
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart:
		var m := minion as BossPart
		m.boss = self
		m.follow_boss = false
		m.max_hp = maxi(1, roundi(max_hp * machine_hp_ratio))
		m.died.connect(_on_machine_broken)
		_machines.append(m)


# ============================================================ 기믹: 열 · 냉각수 기계 · 과열
func _on_machine_broken(_enemy: Enemy) -> void:
	_machines = get_machines()
	if is_dead():
		return
	if _machines.is_empty():
		GameManager.show_notice("냉각수 기계를 모두 부쉈다! 이제 테모스의 열이 거의 식지 않는다", Color(1.0, 0.6, 0.3))
	else:
		GameManager.show_notice("냉각수 기계 파괴! (남은 기계 %d대) 테모스가 점점 뜨거워진다" % _machines.size(), Color(1.0, 0.75, 0.4))


## 스킬을 쓸 때마다 열이 오름 → 100 이면 과열
func add_heat(amount: float) -> void:
	if _overheated or is_dead():
		return
	heat = minf(heat + amount, MAX_HEAT)
	if heat >= MAX_HEAT:
		_overheat()


func _overheat() -> void:
	_overheated = true
	_overheats += 1
	heat = MAX_HEAT
	defense = roundi(_base_defense * 0.5)
	contact_damage = 0
	_bstate = BossState.CHASE
	_btimer = chase_time
	base_tint = Color(1.5, 0.7, 0.55)
	_steam.emitting = true
	set_status("과열! 공격 불가 · 방어력 -50%", Color(1.0, 0.45, 0.3))
	GameManager.show_notice("테모스 과열! 열이 식을 때까지 공격하지 못하고 방어력이 절반으로", Color(1.0, 0.5, 0.35))
	Fx.explosion(self, get_hit_center(), Color(1.0, 0.5, 0.2), 40.0, 2, Vector2(0, -80))


func _cool_down() -> void:
	_overheated = false
	defense = _base_defense
	contact_damage = _base_contact
	base_tint = Color.WHITE
	_steam.emitting = false
	set_status("", Color.WHITE)
	GameManager.show_notice("테모스의 열이 정상으로 돌아왔다", Color(0.7, 0.85, 1.0))


## 과열 중에는 스킬을 쓸 수 없음
func cast(pattern: int) -> void:
	if _overheated or is_dead():
		return
	super.cast(pattern)
	_skills += 1
	add_heat(heat_per_skill * (1.25 if pattern == Pattern.PISTON else 1.0))


func _draw_overlay() -> void:
	if is_dead():
		return
	# 냉각수 기계와 이어진 배관
	for m in get_machines():
		_overlay.draw_line(m.global_position + Vector2(0, -12), global_position + Vector2(0, -30), Color(0.35, 0.75, 0.95, 0.45), 3.0)
		_overlay.draw_line(m.global_position + Vector2(0, -12), global_position + Vector2(0, -30), Color(0.2, 0.25, 0.3, 0.6), 1.0)
	# 머리 위 열 게이지
	var bar := Rect2(global_position + Vector2(-28, -92), Vector2(56, 5))
	var ratio := heat / MAX_HEAT
	_overlay.draw_rect(bar, Color(0.1, 0.06, 0.05, 0.9))
	_overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color(1.0, 0.85 - ratio * 0.6, 0.2 - ratio * 0.15))
	if _overheated:
		_overlay.draw_rect(bar.grow(1.0), Color(1.0, 0.3, 0.2, 0.6 + 0.4 * sin(_anim_time * 12.0)), false, 1.0)


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.GEARS:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.17), 145.0, gear_damage, gear_texture, 0.0, Elements.Type.NONE)
			return 1.0
		Pattern.STEAM:
			set_status("증기 분출", Color(0.9, 0.9, 0.95))
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 52.0, 20.0, 0.9, steam_damage, Elements.Type.FIRE)
			_after(1.0, func() -> void:
				if get_status_text() == "증기 분출":
					set_status("", Color.WHITE))
			return 1.3
		Pattern.PISTON:
			var dir := direction_to_player()
			for side in [-1.0, 1.0]:
				for i in 6:
					telegraph_strike(get_hit_center() + dir.orthogonal() * 20.0 * side + dir * (36.0 + 26.0 * i), 16.0, 0.75 + 0.06 * i, piston_damage, Elements.Type.NONE)
			return 1.4
		Pattern.BARRAGE:
			if has_target():
				for i in 6:
					telegraph_strike(_player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0)), 22.0, 0.9 + 0.1 * i, barrage_damage, Elements.Type.FIRE)
			return 1.5
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 1.0
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("테모스: 계산 완료. 출력 최대. — 스킬이 더 잦아진다", Color(1.0, 0.75, 0.4))
	chase_time *= 0.75
