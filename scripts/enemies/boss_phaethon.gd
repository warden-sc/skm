class_name BossPhaethon
extends PatternBoss
## 63스테이지 보스: 태양 전차를 몬 파에톤 — 태양신의 아들임을 증명하려다 태양 전차를 폭주시켜 세상을 태울 뻔한 소년.
##   CHARGE   : 폭주 전차 — 붉은 예고선 뒤 돌진, 지나간 자리에 불타는 궤적(화상 장판)이 남음
##   SUNFLARE : 태양 불꽃 — 몸 주위로 퍼지는 불꽃 탄
##   SCORCH   : 작열 — 플레이어를 가로지르는 불기둥 줄
##   SUMMON   : 불꽃 말 · 불타는 마부 호출
##
## [기믹] 폭주 전차: 전차에 치이면 큰 피해 + 화상, 궤적은 trail_time 초 동안 남음
## [기믹] 고삐 기둥: 보스방 네 귀퉁이의 고삐 기둥(체력 따로) — 하나 끊을 때마다 전차가 느려짐
##   4개를 모두 끊으면 전차가 멈추고 파에톤이 떨어짐 → 오래 기절 + 그 뒤로 방어력 -fall_defense, 더는 돌진하지 못함
## 체력 50% 이하: 돌진이 두 번 연달아

enum Pattern { CHARGE, SUNFLARE, SCORCH, SUMMON }

const PILLAR_SPOTS := [Vector2(-250, -125), Vector2(250, -125), Vector2(-250, 125), Vector2(250, 125)]

@export var pillar_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var flare_texture: Texture2D
@export var charge_damage: int = 98
@export var flare_damage: int = 60
@export var scorch_damage: int = 86
@export var pillar_hp_ratio: float = 0.03
@export var trail_time: float = 5.0
@export var fall_defense: int = 30

var pillars: Array[BossPart] = []
var _fallen: bool = false
var _base_defense: int = 0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_windup: float = 0.0
var _charge_left: float = 0.0
var _charge_hit: bool = false
var _charges_queued: int = 0
var _trail_tick: float = 0.0
var _trails: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.CHARGE, Pattern.SUNFLARE, Pattern.SCORCH, Pattern.CHARGE, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_defense = defense


func get_pillars() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for p in pillars:
		if is_instance_valid(p) and not p.is_dead():
			alive.append(p)
	return alive


func is_fallen() -> bool:
	return _fallen


func is_charging() -> bool:
	return _charge_windup > 0.0 or _charge_left > 0.0


func get_trail_count() -> int:
	return _trails


## 남은 고삐 기둥 수만큼 전차 속도
func chariot_speed() -> float:
	return 300.0 * (0.55 + 0.15 * get_pillars().size())


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if pillar_scene != null:
			for spot in PILLAR_SPOTS:
				request_summon(pillar_scene, _area().get_center() + spot)
		_update_status()
	if is_charging():
		return _charge_velocity(delta)
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart:
		return
	var pillar := minion as BossPart
	pillar.boss = self
	pillar.follow_boss = false
	pillar.max_hp = maxi(1, roundi(max_hp * pillar_hp_ratio))
	pillar.hp = pillar.max_hp
	pillar.died.connect(_on_pillar_cut)
	pillars.append(pillar)


func _on_pillar_cut(_pillar: Enemy) -> void:
	if is_dead():
		return
	if get_pillars().is_empty():
		fall()
	else:
		Net.announce("고삐 하나를 끊었다! 전차가 느려진다 (남은 고삐 %d)" % get_pillars().size(), Color(1.0, 0.85, 0.5))
	_update_status()


## 전차에서 떨어짐 (테스트에서도 직접 호출)
func fall() -> void:
	if _fallen or is_dead():
		return
	_fallen = true
	_charge_windup = 0.0
	_charge_left = 0.0
	_charges_queued = 0
	defense = maxi(_base_defense - fall_defense, 0)
	super.stun(10.0)
	Fx.explosion(self, get_hit_center(), Color(1.0, 0.7, 0.3), 50.0, 2)
	Net.announce("고삐가 모두 끊어졌다! 태양 전차가 멈추고 파에톤이 떨어진다", Color(1.0, 0.85, 0.5))
	_update_status()


func _update_status() -> void:
	if _fallen:
		set_status("전차에서 떨어짐 (방어력 -%d)" % Balance.scale(fall_defense), Color(1.0, 0.6, 0.5))
	else:
		set_status("폭주하는 태양 전차 — 고삐 %d개" % get_pillars().size(), Color(1.0, 0.8, 0.4))


func start_charge() -> void:
	if _fallen or not has_target():
		return
	_charge_dir = direction_to_player()
	_charge_windup = 0.6
	_charge_left = 0.8
	_charge_hit = false
	_trail_tick = 0.0
	for i in 14:
		Fx.flash(self, global_position + _charge_dir * (20.0 + 22.0 * i), Color(1.0, 0.55, 0.2), 12.0, 0.6)  # 돌진 예고선


func _charge_velocity(delta: float) -> Vector2:
	if _charge_windup > 0.0:
		_charge_windup -= delta
		return Vector2.ZERO
	_charge_left -= delta
	_trail_tick -= delta
	if _trail_tick <= 0.0:
		_trail_tick = 0.07
		_trails += 1
		GroundZone.spawn_hostile(self, global_position, GroundZone.Kind.FIRE, 14.0, trail_time, 1.0, roundi(9 * power), 2.0)
	if not _charge_hit and has_target() and global_position.distance_to(_player.global_position) < 34.0:
		_charge_hit = true
		if _player.take_hit(roundi(charge_damage * power), global_position, self) == Player.HitResult.DAMAGED:
			_player.apply_burn(maxi(burn_damage, 9), 3.0)
	if _charge_left <= 0.0 and _charges_queued > 0:
		_charges_queued -= 1
		start_charge()
	return _charge_dir * chariot_speed()


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	if pattern == Pattern.CHARGE and _fallen:
		pattern = Pattern.SUNFLARE
	match pattern:
		Pattern.CHARGE:
			_charges_queued = 1 if phase_two else 0
			start_charge()
			return 1.6 if phase_two else 1.5
		Pattern.SUNFLARE:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2), 115.0, flare_damage, flare_texture, 0.0, Elements.Type.FIRE))
			return 1.1
		Pattern.SCORCH:
			var across := dir.orthogonal()
			for i in 11:
				telegraph_strike(_player.global_position + across * (-100.0 + 20.0 * i), 16.0, 0.8, scorch_damage, Elements.Type.FIRE)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("파에톤: 멈춰! 말을 들어! 전차가 더 거칠게 날뛴다", Color(1.0, 0.6, 0.3))
