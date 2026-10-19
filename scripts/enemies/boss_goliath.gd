class_name BossGoliath
extends PatternBoss
## 94스테이지 보스: 거인 골리앗 — 가드 사람, 키가 여섯 규빗 한 뼘. 놋 투구와 비늘 갑옷, 베틀채 같은 창.
##   SPEAR    : 베틀채 같은 창 찌르기 (일직선 · 굵게)
##   STOMP    : 땅 구르기 — 몸 주위 고리 두 겹
##   JAVELIN  : 놋 단창 던지기 (부채꼴 탄)
##   TAUNT    : 「너희 중에서 한 사람을 택하여 내게로 내려보내라」 — 블레셋 병사 호출
##
## [기믹] 비늘 갑옷: 몸통에는 armor_ratio 만 피해가 들어감 (이마에 돌을 맞고 기절한 동안은 그대로)
## [기믹] 다윗의 물맷돌: 보스방 시냇가에 매끄러운 돌 stone_count 개 — 돌을 들고 공격하면 조준한 쪽으로 돌을 던짐
##   골리앗 이마(조준 각 sling_aim 안 · 거리 sling_range 안)에 맞으면 stone_stun 초 기절 + 최대 체력의 stone_hit_ratio 피해
##   돌을 다 쓰면 stone_respawn 초 뒤 시냇가에 다시 생김
## [기믹] 방패 든 자: 골리앗 앞(플레이어 쪽)에서 방패를 든 자가 막아섬 — 살아 있으면 던진 돌이 방패에 막힘
##   쓰러뜨리면 shield_return 초 뒤 다시 나옴

enum Pattern { SPEAR, STOMP, JAVELIN, TAUNT }

const HEAD_OFFSET := Vector2(0, -58)

@export var shield_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var stone_texture: Texture2D
@export var javelin_texture: Texture2D
@export var spear_damage: int = 108
@export var stomp_damage: int = 98
@export var javelin_damage: int = 66
@export var armor_ratio: float = 0.5
@export var stone_count: int = 5
@export var stone_respawn: float = 10.0
@export var stone_stun: float = 8.0
@export var stone_hit_ratio: float = 0.04
@export var sling_aim: float = 0.3
@export var sling_range: float = 300.0
@export var shield_hp_ratio: float = 0.03
@export var shield_return: float = 18.0

var shieldbearer: BossPart
var stones: Array[CarryItem] = []
var brook: WaterPool
var _respawn_left: float = 0.0
var _shield_left: float = 0.0
var _head_hits: int = 0
var _blocked: int = 0
var _misses: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPEAR, Pattern.STOMP, Pattern.JAVELIN, Pattern.SPEAR, Pattern.TAUNT]


func get_head_hits() -> int:
	return _head_hits


func get_blocked_count() -> int:
	return _blocked


func get_miss_count() -> int:
	return _misses


func has_shieldbearer() -> bool:
	return shieldbearer != null and is_instance_valid(shieldbearer) and not shieldbearer.is_dead()


func head_position() -> Vector2:
	return global_position + HEAD_OFFSET


func carried_stone() -> CarryItem:
	for s in stones:
		if is_instance_valid(s) and s.is_carried():
			return s
	return null


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func brook_position() -> Vector2:
	var area := _area()
	return Vector2(area.position.x + 70.0, area.end.y - 60.0)


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		brook = WaterPool.spawn(self, brook_position(), 46.0)
		_scatter_stones()
		_call_shieldbearer()
		_player.attacked.connect(_on_player_attacked)
		_update_status()
	return super._get_move_velocity(delta) * 0.8


func _scatter_stones() -> void:
	for s in stones:
		if is_instance_valid(s):
			s.queue_free()
	stones.clear()
	for i in stone_count:
		var at := brook_position() + Vector2.from_angle(TAU * i / stone_count) * Vector2(58.0, 30.0)
		var s := CarryItem.spawn(self, at, stone_texture, "매끄러운 시냇돌", Color(0.85, 0.9, 1.0))
		if s != null:
			stones.append(s)
	_update_status()


func _call_shieldbearer() -> void:
	if shield_scene != null and not is_dead():
		request_summon(shield_scene, global_position + Vector2(0, 30))


func register_minion(minion: Enemy) -> void:
	if shield_scene != null and minion.scene_file_path == shield_scene.resource_path:
		shieldbearer = minion as BossPart
		shieldbearer.boss = self
		shieldbearer.follow_boss = true
		shieldbearer.bob_amount = 0.0
		shieldbearer.max_hp = maxi(1, roundi(max_hp * shield_hp_ratio))
		shieldbearer.hp = shieldbearer.max_hp
		shieldbearer.died.connect(_on_shield_down)
		_update_status()


func _on_shield_down(_s: Enemy) -> void:
	if is_dead():
		return
	shieldbearer = null
	_shield_left = shield_return
	GameManager.show_notice("방패 든 자가 쓰러졌다! 지금 이마를 노려라", Color(0.9, 0.95, 1.0))
	_update_status()


## 돌을 든 채 공격하면 조준한 쪽으로 던짐
func _on_player_attacked() -> void:
	var s := carried_stone()
	if s == null or is_dead() or not has_target():
		return
	throw_stone(_player.get_aim_direction())


## 들고 있는 돌을 던짐 (테스트에서도 직접 호출) — 이마에 맞았으면 true
func throw_stone(aim: Vector2) -> bool:
	var s := carried_stone()
	if s == null:
		return false
	s.hide_for(99999.0)
	var from := _player.global_position + Vector2(0, -10)
	var to_head := head_position() - from
	var hit := absf(aim.angle_to(to_head)) <= sling_aim and to_head.length() <= sling_range
	var land := head_position() if hit else from + aim.normalized() * minf(to_head.length(), sling_range)
	if hit and has_shieldbearer():
		land = shieldbearer.get_hit_center()
		hit = false
		_blocked += 1
		FloatingText.spawn(shieldbearer, land + Vector2(0, -20), "방패에 막힘!", Color(0.8, 0.85, 0.9))
	elif not hit:
		_misses += 1
	CarryItem.fly(self, from, land, stone_texture, 0.25)
	if hit:
		_head_hits += 1
		super.stun(stone_stun)
		super.take_damage(roundi(max_hp * stone_hit_ratio), Vector2.ZERO, true, 999999)
		Fx.star_burst(self, head_position(), 26.0)
		GameManager.show_notice("물맷돌이 골리앗의 이마에 박혔다! 거인이 비틀거린다", Color(0.9, 0.95, 1.0))
	if _stones_left() == 0:
		_respawn_left = stone_respawn
	_update_status()
	return hit


func _stones_left() -> int:
	var n := 0
	for s in stones:
		if is_instance_valid(s) and s.available:
			n += 1
	return n


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and not is_stunned():
		amount = maxi(1, roundi(amount * armor_ratio))
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if has_shieldbearer() and has_target():
			shieldbearer.anchor_offset = direction_to_player() * 26.0 + Vector2(0, -4)
		elif _shield_left > 0.0:
			_shield_left -= delta
			if _shield_left <= 0.0:
				_call_shieldbearer()
		if _respawn_left > 0.0:
			_respawn_left -= delta
			if _respawn_left <= 0.0:
				_scatter_stones()
				GameManager.show_notice("시냇가에 매끄러운 돌이 다시 보인다", Color(0.85, 0.9, 1.0))
	super._physics_process(delta)


func _update_status() -> void:
	set_status("비늘 갑옷 (피해 %d%%) · 시냇돌 %d개%s" % [roundi(armor_ratio * 100.0), _stones_left(), " · 방패 든 자" if has_shieldbearer() else ""], Color(0.9, 0.85, 0.6))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SPEAR:
			for i in 12:
				telegraph_strike(get_hit_center() + dir * (28.0 + 22.0 * i), 18.0, 0.65 + 0.03 * i, spear_damage, Elements.Type.NONE)
			return 1.2
		Pattern.STOMP:
			for ring in 2:
				for i in 12:
					telegraph_strike(global_position + Vector2.from_angle(TAU * i / 12.0 + ring * 0.26) * (48.0 + 34.0 * ring), 18.0, 0.8 + 0.25 * ring, stomp_damage, Elements.Type.EARTH)
			return 1.3
		Pattern.JAVELIN:
			for i in 5:
				shoot(dir.rotated((i - 2) * 0.16), 190.0, javelin_damage, javelin_texture)
			return 1.0
		Pattern.TAUNT:
			GameManager.show_notice("골리앗: 「너희 중에서 한 사람을 택하여 내게로 내려보내라!」", Color(0.9, 0.8, 0.6))
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 1.0
	return 1.0


func _die() -> void:
	for s in stones:
		if is_instance_valid(s):
			s.queue_free()
	if _player != null and is_instance_valid(_player) and _player.attacked.is_connected(_on_player_attacked):
		_player.attacked.disconnect(_on_player_attacked)
	super._die()
