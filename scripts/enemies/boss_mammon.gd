class_name BossMammon
extends PatternBoss
## 81스테이지 보스: 탐욕의 마왕 마몬 — 일곱 대죄 중 「탐욕」. 금화라면 무엇이든 삼키는 황금 마왕.
##   COIN_RAIN : 금화 비 — 플레이어 주변에 떨어지는 금화 장판
##   SACK      : 금화 자루 휘두르기 (앞쪽 부채꼴)
##   GOLD_BOLT : 황금 탄막
##   SUMMON    : 탐욕의 임프 · 도둑 · 미믹 호출
##
## [기믹] 금화 더미 쟁탈: pile_interval 초마다 보스방 곳곳에 금화 더미 pile_count 개가 생김 — 마몬은 가까운 더미로 다가감
##   마몬이 먹으면 「탐욕」+1 → 몸집이 커지고 방어력 +greed_defense · 공격력 +greed_power (최대 max_greed)
##   플레이어가 먼저 주우면 골드를 얻고 마몬의 탐욕 -1
## 체력 50% 이하: 더미가 더 자주 생김

enum Pattern { COIN_RAIN, SACK, GOLD_BOLT, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var pile_texture: Texture2D
@export var coin_texture: Texture2D
@export var rain_damage: int = 84
@export var sack_damage: int = 100
@export var bolt_damage: int = 64
@export var pile_interval: float = 8.0
@export var pile_count: int = 3
@export var greed_defense: int = 5
@export var greed_power: float = 0.06
@export var max_greed: int = 8
@export var pile_gold: int = 40

var piles: Array[CarryItem] = []
var greed: int = 0
var _pile_left: float = 3.0
var _eaten: int = 0
var _stolen: int = 0
var _base_defense: int = 0
var _base_power: float = 1.0
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	super._ready()
	_base_defense = defense
	_base_scale = sprite.scale
	pattern_order = [Pattern.COIN_RAIN, Pattern.SACK, Pattern.GOLD_BOLT, Pattern.SACK, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_defense = defense
	_base_power = power


func get_eaten_count() -> int:
	return _eaten


func get_stolen_count() -> int:
	return _stolen


func live_piles() -> Array[CarryItem]:
	var alive: Array[CarryItem] = []
	for p in piles:
		if is_instance_valid(p) and p.available:
			alive.append(p)
	return alive


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


## 금화 더미를 뿌림 (테스트에서도 직접 호출)
func scatter_piles(spots: Array = []) -> void:
	var area := _area().grow(-40.0)
	for i in pile_count:
		var at: Vector2 = spots[i] if i < spots.size() else Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		var pile := CarryItem.spawn(self, at, pile_texture, "금화 더미", Color(1.0, 0.85, 0.3))
		if pile != null:
			pile.follow_player = false
			pile.picked_up.connect(_on_pile_taken)
			piles.append(pile)
	GameManager.show_notice("금화 더미가 쏟아졌다! 마몬보다 먼저 주워라", Color(1.0, 0.85, 0.35))


func _on_pile_taken(pile: CarryItem) -> void:
	_stolen += 1
	pile.hide_for(99999.0)
	GameManager.add_gold(pile_gold)
	set_greed(greed - 1)
	FloatingText.spawn(pile, pile.global_position + Vector2(0, -20), "+%d G" % pile_gold, Color(1.0, 0.9, 0.4), true)


func set_greed(value: int) -> void:
	greed = clampi(value, 0, max_greed)
	defense = _base_defense + greed_defense * greed
	power = _base_power * (1.0 + greed_power * greed)
	sprite.scale = _base_scale * (1.0 + 0.06 * greed)
	set_status("탐욕 %d — 방어력 +%d" % [greed, greed_defense * greed * Balance.K], Color(1.0, 0.85, 0.35))


func _get_move_velocity(delta: float) -> Vector2:
	var alive := live_piles()
	if not alive.is_empty() and not is_casting():
		var best := alive[0]
		for p in alive:
			if p.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
				best = p
		super._get_move_velocity(delta)
		return global_position.direction_to(best.global_position) * move_speed * 1.4
	return super._get_move_velocity(delta)


func _physics_process(delta: float) -> void:
	if not is_dead() and has_target():
		for p in live_piles():
			if p.global_position.distance_to(global_position) <= 22.0:
				_eaten += 1
				p.hide_for(99999.0)
				set_greed(greed + 1)
				Fx.burst(self, get_hit_center(), Color(1.0, 0.85, 0.3), 16, 60.0, 0.5)
				FloatingText.spawn(self, global_position + Vector2(0, -56), "냠!", Color(1.0, 0.8, 0.3), true)
		_pile_left -= delta
		if _pile_left <= 0.0:
			_pile_left = pile_interval * (0.7 if phase_two else 1.0)
			scatter_piles()
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.COIN_RAIN:
			for i in 8:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 80.0)
				telegraph_strike(at, 18.0, 0.8 + 0.07 * i, rain_damage, Elements.Type.HOLY).color = Color(1.0, 0.85, 0.3)
			return 1.2
		Pattern.SACK:
			for i in 7:
				telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.28) * 48.0, 22.0, 0.7, sack_damage, Elements.Type.NONE)
			return 1.1
		Pattern.GOLD_BOLT:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 14:
						shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 125.0, bolt_damage, coin_texture, 0.0, Elements.Type.HOLY))
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("마몬: 더! 더 많은 금화를! 금화 더미가 더 자주 쏟아진다", Color(1.0, 0.85, 0.35))
