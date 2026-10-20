class_name BossAsmodeus
extends PatternBoss
## 84스테이지 보스: 색욕의 마왕 아스모데우스 — 일곱 대죄 중 「색욕」. 욕망의 사슬로 상대를 옭아매는 마왕.
##   LASH     : 사슬 채찍 (일직선 둘)
##   KISS     : 매혹의 입맞춤 — 분홍 하트 탄 (맞으면 잠깐 매혹)
##   FLAME    : 욕망의 불꽃 — 몸 주위 고리
##   SUMMON   : 서큐버스 창병 · 매혹의 정령 · 사슬 사냥개 호출
##
## [기믹] 욕망의 사슬: 플레이어와 아스모데우스가 사슬로 묶여 tether_length 이상 멀어질 수 없음 (끌려감)
##   보스방의 사슬 기둥 3개(체력 따로)가 사슬을 붙들고 있음 → 기둥을 모두 부수면 사슬이 끊어지고 아스모데우스가 크게 휘청 (그 뒤로는 묶이지 않음)
## 체력 50% 이하: 사슬이 짧아짐

enum Pattern { LASH, KISS, FLAME, SUMMON }

const PILLAR_SPOTS := [Vector2(-220, -110), Vector2(220, -110), Vector2(0, 130)]

@export var pillar_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var heart_texture: Texture2D
@export var lash_damage: int = 98
@export var kiss_damage: int = 60
@export var flame_damage: int = 86
@export var pillar_hp_ratio: float = 0.03
@export var tether_length: float = 150.0
@export var charm_time: float = 1.0

var pillars: Array[BossPart] = []
var _chained: bool = true
var _pulls: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.LASH, Pattern.KISS, Pattern.FLAME, Pattern.LASH, Pattern.SUMMON]


func is_chained() -> bool:
	return _chained


func get_pull_count() -> int:
	return _pulls


func get_pillars() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for p in pillars:
		if is_instance_valid(p) and not p.is_dead():
			alive.append(p)
	return alive


func tether() -> float:
	return tether_length * (0.8 if phase_two else 1.0)


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if pillar_scene != null:
			for spot in PILLAR_SPOTS:
				request_summon(pillar_scene, _area().get_center() + spot)
		set_status("욕망의 사슬 — 사슬 기둥 3개", Color(1.0, 0.55, 0.75))
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossPart:
		var p := minion as BossPart
		p.boss = self
		p.follow_boss = false
		p.max_hp = maxi(1, roundi(max_hp * pillar_hp_ratio))
		p.hp = p.max_hp
		p.died.connect(_on_pillar_broken)
		pillars.append(p)


func _on_pillar_broken(_p: Enemy) -> void:
	if is_dead():
		return
	if get_pillars().is_empty() and _chained:
		_chained = false
		super.stun(8.0)
		Fx.burst(self, get_hit_center(), Color(1.0, 0.6, 0.8), 30, 90.0, 0.7)
		Net.announce("사슬 기둥이 모두 무너져 욕망의 사슬이 끊어졌다! 아스모데우스가 휘청인다", Color(1.0, 0.7, 0.85))
		set_status("사슬이 끊어짐", Color(1.0, 0.6, 0.6))
	else:
		set_status("욕망의 사슬 — 사슬 기둥 %d개" % get_pillars().size(), Color(1.0, 0.55, 0.75))


func _physics_process(delta: float) -> void:
	if not is_dead() and _started and _chained and has_target():
		var d := global_position.distance_to(_player.global_position)
		if d > tether():
			_pulls += 1
			_player.apply_push(_player.global_position.direction_to(global_position) * (d - tether()) * 12.0)
			_player.mark_floor_status("욕망의 사슬에 묶임 — 사슬 기둥을 부숴라")
		queue_redraw()
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.LASH:
			for k in 2:
				var d := dir.rotated((k - 0.5) * 0.35)
				for i in 10:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, lash_damage, Elements.Type.DARK)
			return 1.1
		Pattern.KISS:
			var pool := ProjectilePool.find(get_tree())
			if pool != null:
				for i in 5:
					var spec := ProjectileSpec.enemy_bullet(get_hit_center(), dir.rotated((i - 2) * 0.2), 130.0, roundi(kiss_damage * power), heart_texture, 0.0, Elements.Type.ARCANE)
					spec.charm_duration = charm_time
					spec.charmer = self
					spec.charm_label = "매혹"
					pool.spawn(spec)
			return 1.0
		Pattern.FLAME:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 52.0, 20.0, 0.85, flame_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


## 욕망의 사슬
func _draw() -> void:
	if is_dead() or not _chained or _player == null or not is_instance_valid(_player):
		return
	var to := to_local(_player.global_position)
	var n := 14
	for i in n:
		var p := Vector2(0, -16).lerp(to, float(i) / n)
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.6, 0.8, 0.8))


func _die() -> void:
	if has_target() and _player.is_charmed():
		_player.release_charm()
	super._die()


func _on_phase_two() -> void:
	Net.announce("아스모데우스: 더 가까이…! 사슬이 짧아진다", Color(1.0, 0.55, 0.75))
