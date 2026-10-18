class_name BossBeelzebub
extends PatternBoss
## 83스테이지 보스: 폭식의 마왕 바알제붑 — 일곱 대죄 중 「폭식」. 파리 떼를 거느린 파리의 왕.
##   VOMIT   : 토사물 — 앞쪽 부채꼴 독 장판
##   BUZZ    : 날갯짓 — 몸 주위 고리
##   MAGGOTS : 구더기 탄막
##   SUMMON  : 구울 · 구더기 호출 (먹이가 됨)
##
## [기믹] 폭식: devour_interval 초마다 devour_range 안의 졸개 하나를 끌어당겨 잡아먹음
##   → 최대 체력의 devour_heal 만큼 회복 + 몸집이 커지고 공격력 +devour_power (최대 max_feasts) — 졸개를 먼저 처치해야 함
## [기믹] 파리 떼: 검은 파리 구름이 플레이어를 느릿하게 따라다님 — 구름 안에서는 시야가 가려지고 느려짐 (대시로 벗어나기)
## 체력 50% 이하: 더 자주 먹음

enum Pattern { VOMIT, BUZZ, MAGGOTS, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var maggot_texture: Texture2D
@export var vomit_damage: int = 92
@export var buzz_damage: int = 86
@export var maggot_damage: int = 62
@export var devour_interval: float = 6.0
@export var devour_range: float = 140.0
@export var devour_heal: float = 0.04
@export var devour_power: float = 0.05
@export var max_feasts: int = 6

var swarm: FlySwarm
var feasts: int = 0
var _devour_left: float = 4.0
var _base_power: float = 1.0
var _base_scale: Vector2 = Vector2.ONE
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_scale = sprite.scale
	pattern_order = [Pattern.VOMIT, Pattern.SUMMON, Pattern.BUZZ, Pattern.MAGGOTS, Pattern.VOMIT]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		swarm = FlySwarm.spawn(self, global_position)
		set_status("폭식 0 — 졸개를 먼저 처치하라", Color(0.7, 0.8, 0.4))
	return super._get_move_velocity(delta)


## 가까운 졸개를 잡아먹음 (테스트에서도 직접 호출) — 먹었으면 true
func devour() -> bool:
	var best: Enemy = null
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := e as Enemy
		if enemy == null or enemy == self or enemy.is_boss or enemy is BossPart or enemy.is_dead():
			continue
		if enemy.global_position.distance_to(global_position) <= devour_range and (best == null or enemy.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = enemy
	if best == null:
		return false
	Fx.burst(self, best.global_position, Color(0.5, 0.6, 0.3), 16, 60.0, 0.5)
	CarryItem.fly(self, best.global_position, get_hit_center(), best.sprite.texture, 0.3)
	best.despawn()
	if feasts < max_feasts:
		feasts += 1
	var heal := mini(roundi(max_hp * devour_heal), max_hp - hp)
	hp += heal
	health_changed.emit(hp, max_hp)
	power = _base_power * (1.0 + devour_power * feasts)
	sprite.scale = _base_scale * (1.0 + 0.05 * feasts)
	FloatingText.spawn(self, global_position + Vector2(0, -56), "꿀꺽! +%d" % heal, Color(0.7, 0.9, 0.4), true)
	set_status("폭식 %d — 졸개를 먼저 처치하라" % feasts, Color(0.7, 0.8, 0.4))
	return true


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		_devour_left -= delta
		if _devour_left <= 0.0:
			_devour_left = devour_interval * (0.7 if phase_two else 1.0)
			devour()
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.VOMIT:
			for i in 7:
				var strike := telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.25) * 52.0, 22.0, 0.75, vomit_damage, Elements.Type.NATURE)
				if strike != null:
					strike.burn_poison = true
					strike.burn_damage = maxi(strike.burn_damage, 9)
			return 1.1
		Pattern.BUZZ:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 52.0, 20.0, 0.85, buzz_damage, Elements.Type.NONE)
			return 1.2
		Pattern.MAGGOTS:
			for i in 9:
				shoot(dir.rotated((i - 4) * 0.15), 130.0, maggot_damage, maggot_texture, 0.0, Elements.Type.NATURE)
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 3:
					request_summon(minion_scenes.pick_random(), global_position + Vector2.from_angle(TAU * i / 3.0) * 70.0)
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("바알제붑: 배가 고프다…! 졸개를 더 자주 잡아먹는다", Color(0.7, 0.8, 0.4))
