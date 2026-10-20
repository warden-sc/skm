class_name BossAstaroth
extends PatternBoss
## 37스테이지 보스: 타락한 신 아스타로트 — 버려진 신전에서 광신도들의 기도를 먹고 자란 타락한 신.
##   DARK_ORBS : 타락의 고리 — 사방으로 퍼지는 어둠 구체 두 겹
##   SMITE     : 천벌 — 플레이어 주변에 연달아 떨어지는 장판
##   CHAINS    : 속박의 사슬 — 플레이어 쪽 일직선 장판 (맞으면 감속)
##   SUMMON    : 광신도 · 타락 사제 호출
##
## [기믹 1] 신앙 게이지: 서 있는 신상 근처에 있으면 신앙이 차오르고(멀어지면 줄어듦)
##   신앙이 높을수록 플레이어 공격력이 오름 (100% 에서 +50%)
##   → 하지만 100% 가 되면 「광신화」: faith_charm 초 동안 조작 불가, 아스타로트에게 끌려감 (신앙은 0 으로)
## [기믹 2] 신상: 보스방 네 곳의 신상(체력 따로)이 서 있는 동안 신상 하나마다 아스타로트 방어력 +statue_armor
##   신상을 부술수록 아스타로트가 약해지지만, 부서진 자리에 오래 남는 「저주의 땅」이 생김 (밟으면 감속 + 지속 피해)
##   → 신상은 신앙(공격력)의 원천이기도 해서, 언제 부술지 고르는 것이 공략
## 체력 50% 이하: 신앙이 더 빨리 차오름

enum Pattern { DARK_ORBS, SMITE, CHAINS, SUMMON }

const FAITH_RADIUS := 80.0

@export var statue_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var orb_texture: Texture2D
@export var orb_damage: int = 52
@export var smite_damage: int = 78
@export var chain_damage: int = 70
@export var statue_armor: int = 10
@export var statue_hp_ratio: float = 0.04
@export var faith_gain: float = 16.0
@export var faith_decay: float = 8.0
@export var faith_charm: float = 3.0
@export var curse_burn: int = 9

var faith: float = 0.0
var _statues: Array[BossPart] = []
var _statues_requested: bool = false
var _statue_queue: int = 0
var _base_defense: int = 0
var _fanatic_count: int = 0
var _broken: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.DARK_ORBS, Pattern.SMITE, Pattern.CHAINS, Pattern.SUMMON, Pattern.SMITE, Pattern.DARK_ORBS]
	_base_defense = defense


func get_statues() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for st in _statues:
		if is_instance_valid(st) and not st.is_dead():
			alive.append(st)
	return alive


func get_fanatic_count() -> int:
	return _fanatic_count


func get_broken_count() -> int:
	return _broken


func is_near_statue(point: Vector2) -> bool:
	for st in get_statues():
		if st.global_position.distance_to(point) <= FAITH_RADIUS:
			return true
	return false


func _get_move_velocity(delta: float) -> Vector2:
	if not _statues_requested and has_target():
		_statues_requested = true
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
		var c := area.get_center()
		var spots: Array[Vector2] = [c + Vector2(-area.size.x * 0.33, -area.size.y * 0.22), c + Vector2(area.size.x * 0.33, -area.size.y * 0.22),
				c + Vector2(-area.size.x * 0.33, area.size.y * 0.3), c + Vector2(area.size.x * 0.33, area.size.y * 0.3)]
		if statue_scene != null:
			for spot in spots:
				_statue_queue += 1
				request_summon(statue_scene, spot)
		_update_armor()
	_update_faith(delta)
	return super._get_move_velocity(delta)


# ============================================================ 기믹 1: 신앙 · 광신화
func _update_faith(delta: float) -> void:
	if not has_target():
		return
	if _player.is_charmed():
		_player.set_faith(faith)
		return
	if is_near_statue(_player.global_position):
		faith += faith_gain * (1.4 if phase_two else 1.0) * delta
	else:
		faith -= faith_decay * delta
	faith = clampf(faith, 0.0, 100.0)
	if faith >= 100.0:
		fanaticize()
	_player.set_faith(faith)


## 광신화 (테스트에서도 직접 호출)
func fanaticize() -> void:
	faith = 0.0
	_fanatic_count += 1
	if not has_target():
		return
	_player.set_faith(0.0)
	_player.apply_charm(faith_charm, self, "광신")
	Net.announce("신앙이 넘쳐 광신에 빠졌다! %d초 동안 몸이 아스타로트에게 끌려간다" % roundi(faith_charm), Color(0.9, 0.5, 0.9))


# ============================================================ 기믹 2: 신상
func register_minion(minion: Enemy) -> void:
	if minion is BossPart and _statue_queue > 0:
		_statue_queue -= 1
		var st := minion as BossPart
		st.boss = self
		st.follow_boss = false
		st.max_hp = maxi(1, roundi(max_hp * statue_hp_ratio))
		st.died.connect(_on_statue_broken)
		_statues.append(st)
		_update_armor()


func _update_armor() -> void:
	var count := get_statues().size() + _statue_queue
	defense = _base_defense + statue_armor * count
	set_status("신상의 가호 %d — 방어력 +%d" % [count, statue_armor * count * Balance.K] if count > 0 else "", Color(0.9, 0.6, 0.9))


func _on_statue_broken(statue: Enemy) -> void:
	if is_dead():
		return
	_broken += 1
	var at := statue.global_position
	GroundZone.spawn_hostile(self, at, GroundZone.Kind.CURSE, 46.0, 9999.0, 0.6, roundi(curse_burn * power), 2.0)
	_update_armor()
	Net.announce("신상을 부쉈다! 아스타로트가 약해진다 — 부서진 자리엔 저주의 땅이 남는다", Color(0.9, 0.6, 0.9))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.DARK_ORBS:
			for w in 2:
				_after(0.35 * w, func() -> void:
					if is_dead():
						return
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2), 110.0, orb_damage, orb_texture, 0.0, Elements.Type.DARK))
			return 1.1
		Pattern.SMITE:
			for i in (8 if phase_two else 6):
				_after(0.2 * i, func() -> void:
					if not is_dead() and has_target():
						telegraph_strike(_player.global_position, 20.0, 0.7, smite_damage, Elements.Type.DARK))
			return 1.6
		Pattern.CHAINS:
			var dir := direction_to_player()
			for i in 10:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 15.0, 0.65 + 0.04 * i, chain_damage, Elements.Type.DARK, 1.5)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if has_target():
		_player.set_faith(0.0)
	for zone in get_tree().get_nodes_in_group(&"hostile_zones"):
		zone.queue_free()
	super._die()


func _on_phase_two() -> void:
	Net.announce("아스타로트: 더 기도하라… 신앙이 더 빨리 차오른다", Color(0.9, 0.5, 0.9))
