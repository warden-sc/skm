class_name BossFallenStar
extends PatternBoss
## 88스테이지 보스: 무저갱의 열쇠를 든 타락한 별 — 하늘에서 떨어져 「바닥 없는 구덩이」의 열쇠를 받은 별.
##   STARFALL : 떨어지는 별빛 — 플레이어 주변 장판
##   SMOKE    : 구덩이의 연기 탄막 (사방)
##   KEY_SWING: 열쇠 휘두르기 (앞쪽 부채꼴)
##   SUMMON   : 무저갱의 기어 나오는 것 · 연기 악마 호출
##
## [기믹] 무저갱의 문: 보스방 가운데 문이 열려 있는 동안 crawl_interval 초마다 졸개가 기어 나오고, 연기로 방이 어두워짐
## [기믹] 무저갱의 열쇠: 별이 쥔 열쇠(체력 따로)를 부수면 열쇠가 바닥에 떨어짐 → 주워서 문까지 가져가면 문이 닫힘
##   문이 닫히면 졸개가 더 나오지 않고, 별이 크게 휘청이며 방어력 -close_defense
##   열쇠를 든 채 맞으면 떨어뜨리고, 열쇠는 별에게 돌아가 다시 쥐어짐
## 체력 50% 이하: 졸개가 더 자주 기어 나옴

enum Pattern { STARFALL, SMOKE, KEY_SWING, SUMMON }

@export var key_scene: PackedScene
@export var crawler_scenes: Array[PackedScene] = []
@export var key_texture: Texture2D
@export var smoke_texture: Texture2D
@export var starfall_damage: int = 92
@export var smoke_damage: int = 62
@export var swing_damage: int = 100
@export var key_hp_ratio: float = 0.03
@export var crawl_interval: float = 6.0
@export var close_defense: int = 25

var key_part: BossPart
var dropped_key: CarryItem
var pit: FieldProp
var _gate_open: bool = true
var _crawl_left: float = 3.0
var _base_defense: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.STARFALL, Pattern.KEY_SWING, Pattern.SMOKE, Pattern.STARFALL, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_defense = defense


func is_gate_open() -> bool:
	return _gate_open


func holds_key() -> bool:
	return key_part != null and is_instance_valid(key_part) and not key_part.is_dead()


func gate_position() -> Vector2:
	return pit.global_position if pit != null and is_instance_valid(pit) else _area().get_center()


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		pit = FieldProp.spawn(self, _area().get_center() + Vector2(0, 20), null, Color(1.0, 0.45, 0.2))
		_grab_key()
		_update_status()
	return super._get_move_velocity(delta)


func _grab_key() -> void:
	if key_scene != null and not is_dead():
		request_summon(key_scene, global_position + Vector2(18, -10))


func register_minion(minion: Enemy) -> void:
	if key_scene != null and minion.scene_file_path == key_scene.resource_path:
		key_part = minion as BossPart
		key_part.boss = self
		key_part.follow_boss = true
		key_part.anchor_offset = Vector2(18, -10)
		key_part.max_hp = maxi(1, roundi(max_hp * key_hp_ratio))
		key_part.hp = key_part.max_hp
		key_part.died.connect(_on_key_knocked)


func _on_key_knocked(_k: Enemy) -> void:
	if is_dead():
		return
	key_part = null
	# 문 반대쪽으로 튕겨 나감 — 문 바로 옆에 떨어지면 줍자마자 닫혀 버림
	var away := gate_position().direction_to(global_position)
	if away == Vector2.ZERO:
		away = Vector2.DOWN
	var reach := maxf(gate_position().distance_to(global_position) + 30.0, 150.0)
	var area := _area().grow(-30.0)
	var at := (gate_position() + away * reach).clamp(area.position, area.end)
	if dropped_key == null or not is_instance_valid(dropped_key):
		dropped_key = CarryItem.spawn(self, at, key_texture, "무저갱의 열쇠", Color(1.0, 0.8, 0.4))
		if dropped_key != null:
			dropped_key.dropped.connect(_on_key_dropped)
	else:
		dropped_key.reappear(at)
	GameManager.show_notice("무저갱의 열쇠가 떨어졌다! 주워서 가운데 문으로 가져가라", Color(1.0, 0.8, 0.4))


## 플레이어가 열쇠를 떨어뜨리면 별이 다시 쥠
func _on_key_dropped(item: CarryItem) -> void:
	item.hide_for(99999.0)
	if _gate_open:
		_grab_key()


## 문을 닫음 (테스트에서도 직접 호출)
func close_gate() -> void:
	if not _gate_open or is_dead():
		return
	_gate_open = false
	defense = maxi(_base_defense - close_defense, 0)
	if dropped_key != null and is_instance_valid(dropped_key):
		dropped_key.hide_for(99999.0)
	super.stun(8.0)
	Fx.explosion(self, gate_position(), Color(1.0, 0.8, 0.4), 50.0, 2)
	GameManager.show_notice("무저갱의 문이 닫혔다! 타락한 별이 크게 휘청인다", Color(1.0, 0.85, 0.5))
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _gate_open:
			_crawl_left -= delta
			if _crawl_left <= 0.0:
				_crawl_left = crawl_interval * (0.7 if phase_two else 1.0)
				if not crawler_scenes.is_empty():
					request_summon(crawler_scenes.pick_random(), gate_position())
			if dropped_key != null and is_instance_valid(dropped_key) and dropped_key.is_carried() and dropped_key.global_position.distance_to(gate_position() + Vector2(0, -26)) <= 30.0:
				close_gate()
		queue_redraw()
	super._physics_process(delta)


func _update_status() -> void:
	if _gate_open:
		set_status("무저갱의 문이 열려 있음 — 열쇠를 빼앗아 닫아라", Color(1.0, 0.6, 0.4))
	else:
		set_status("문이 닫힘 (방어력 -%d)" % close_defense, Color(0.8, 0.85, 1.0))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.STARFALL:
			for i in 7:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 80.0)
				telegraph_strike(at, 22.0, 0.9 + 0.07 * i, starfall_damage, Elements.Type.HOLY)
			return 1.2
		Pattern.SMOKE:
			for i in 16:
				shoot(Vector2.from_angle(TAU * i / 16.0 + randf() * 0.2), 110.0, smoke_damage, smoke_texture, 0.0, Elements.Type.DARK)
			return 1.0
		Pattern.KEY_SWING:
			for i in 7:
				telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.28) * 48.0, 22.0, 0.7, swing_damage, Elements.Type.NONE)
			return 1.1
		Pattern.SUMMON:
			if not crawler_scenes.is_empty():
				request_summon(crawler_scenes.pick_random(), global_position + Vector2(0, 40))
			return 0.8
	return 1.0


## 무저갱의 문 (열려 있으면 붉게 일렁이는 구덩이)
func _draw() -> void:
	if pit == null or not is_instance_valid(pit):
		return
	var c := to_local(gate_position())
	if _gate_open:
		draw_circle(c, 34.0, Color(0.05, 0.02, 0.04, 0.9))
		draw_arc(c, 34.0, 0.0, TAU, 32, Color(1.0, 0.4, 0.15, 0.8), 2.0)
	else:
		draw_circle(c, 34.0, Color(0.35, 0.3, 0.25, 0.9))
		draw_arc(c, 34.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.5, 0.9), 2.0)
