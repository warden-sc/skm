class_name BossMultiverseMaster
extends PatternBoss
## 최종장 보스: 멀티버스의 주인 — 야영지에서 장비를 팔던 그 상인. 백 개의 세계를 불러 모아 서로 싸우게 하고, 그걸 구경하며 즐기던 자.
##   COIN_STORM : 금화 폭풍 (사방 탄 두 겹)
##   PRICE_TAG  : 「값을 매겨 주지」 — 플레이어 발밑과 둘레에 장판
##   ECHO       : 지금 세계의 메아리 — 몸 주위 고리 두 겹 (세계마다 속성이 다름)
##   SUMMON     : 지금 세계의 몬스터 호출
##
## [등장] 정체: 상인의 모습으로 나타나 말을 건넴 (무적) → 모습이 찢어지며 멀티버스의 주인으로 변함 (보스방이 여러 세계로 깜빡임)
## [기믹 1] 세계 전환: shift_time 초마다 보스방이 지난 보스의 세계로 바뀌고, 그 세계의 기믹이 살아남
##   초록 들판(점액 바닥) · 안개의 전장(안개) · 나태의 늪(느려지는 오라) · 색욕의 궁전(사슬) · 무저갱(바닥 없는 구덩이)
##   에덴의 동쪽(두루 도는 불칼) · 두라 평지(뜨인 돌 — 주인을 그 길로 끌어들이면 큰 피해) · 홍수(방주의 판자) · 백합의 정원(하늘의 전언)
## [기믹 2] 관람석: 체력 75% · 50% · 25% 에서 주인이 관람석에 올라가 무적 — 서로 다른 세계의 투사 셋(체력 champion_hp_mult 배)을 싸움 붙임
##   spectate_time 초 안에 투사를 모두 쓰러뜨리면 주인이 관람석에서 떨어져 fall_stun 초 기절 + 피해 fall_ratio 배, 못 하면 주인이 회복
## [기믹 3] 멀티버스의 균열: 체력 2/3 이하에서 보스방 양쪽에 균열 둘 — 열려 있는 동안 주인은 피해 rift_ratio 만 받고, 균열에서 탄이 쏟아짐
##   균열을 부수면 rift_reopen 초 뒤 다시 열림
## [기믹 4] 멀티버스 붕괴: 체력 1/3 이하에서 세계가 더 빨리 바뀌고, 앞 세계의 기믹이 남은 채 두 세계가 겹침

enum Pattern { COIN_STORM, PRICE_TAG, ECHO, SUMMON }
enum Mode { MERCHANT, TRANSFORM, FIGHT, SPECTATING }
enum World { SLIME, FOG, SLOTH, CHAIN, ABYSS, SWORD, STONES, FLOOD, REVELATION }

const WORLD_STAGES := [1, 73, 82, 84, 90, 91, 93, 96, 100]
const WORLD_NAMES := ["초록 들판", "안개의 전장", "나태의 늪", "색욕의 궁전", "무저갱", "에덴의 동쪽", "두라 평지", "홍수", "백합의 정원"]
const WORLD_HINTS := ["슬라임 킹의 점액 바닥 — 밟으면 느려짐", "디오메데스의 안개 — 내 둘레만 보임", "벨페고르의 오라 — 주인 곁에서 느려짐",
	"아스모데우스의 사슬 — 멀어지면 끌려감", "아바돈의 구덩이 — 빠지면 큰 피해", "케루빔의 불칼 — 주인 둘레를 돎",
	"뜨인 돌 — 그 길로 주인을 끌어들여라", "네피림의 홍수 — 방주의 판자 위로", "가브리엘의 전언 — 선포한 곳을 피하라"]
const WORLD_ELEMENTS := [Elements.Type.NATURE, Elements.Type.NONE, Elements.Type.ARCANE, Elements.Type.DARK, Elements.Type.DARK,
	Elements.Type.FIRE, Elements.Type.EARTH, Elements.Type.ICE, Elements.Type.HOLY]
const LINES := [
	"짝, 짝, 짝… 훌륭했어, 손님. 아니 — 정말 훌륭한 구경거리였지.",
	"슬라임 킹부터 대천사 가브리엘까지… 전부 내가 불러 모은 세계들이야.",
	"백 개의 세계가 서로 부딪쳐 싸우는 걸 지켜보는 게, 내 유일한 즐거움이었거든.",
	"장비를 싸게 팔아 준 것도 다 네가 조금 더 오래 버텨 주길 바라서였지. 흐흐…",
	"자, 마지막 무대다. 이번엔 주인이 직접 올라가 주지.",
]
const SWORD_INNER := 30.0
const SWORD_OUTER := 140.0
const SPECTATE_THRESHOLDS := [0.75, 0.5, 0.25]

@export var rift_scene: PackedScene
@export var merchant_texture: Texture2D
@export var true_texture: Texture2D
@export var coin_texture: Texture2D
@export var stone_texture: Texture2D
@export var plank_texture: Texture2D
@export var coin_damage: int = 72
@export var price_damage: int = 116
@export var echo_damage: int = 104
@export var sword_damage: int = 100
@export var stone_damage: int = 110
@export var light_damage: int = 112
@export var line_time: float = 2.6
@export var transform_time: float = 3.0
@export var shift_time: float = 18.0
@export var spectate_time: float = 25.0
@export var champion_hp_mult: float = 3.0
@export var fall_stun: float = 10.0
@export var fall_ratio: float = 1.5
@export var rift_hp_ratio: float = 0.015
@export var rift_ratio: float = 0.6
@export var rift_reopen: float = 30.0
@export var rift_fire: float = 3.0

var mode: Mode = Mode.MERCHANT
var world: int = -1
var world2: int = -1
var champions: Array[Enemy] = []
var rifts: Array[BossPart] = []
var pit: AbyssPit
var flood: FloodField
var veil: FogVeil
var center: Vector2 = Vector2.ZERO
var sword_angle: float = 0.0
var _manager: StageManager
var _mode_left: float = 0.0
var _line: int = 0
var _flicker: float = 0.0
var _shift_left: float = 0.0
var _shifts: int = 0
var _spectated: Array[bool] = [false, false, false]
var _pending_champions: int = 0
var _spectate_left: float = 0.0
var _falls: int = 0
var _fallen_left: float = 0.0
var _rift_left: float = 0.0
var _rift_fire_left: float = 0.0
var _rifts_opened: bool = false
var _zones: Array[GroundZone] = []
var _sword_cd: float = 0.0
var _stone_left: float = 0.0
var _stone_hits: int = 0
var _light_left: float = 0.0
var _flood_tick: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.COIN_STORM, Pattern.PRICE_TAG, Pattern.ECHO, Pattern.PRICE_TAG, Pattern.SUMMON]
	immune_text = "「나는 그저 상인일 뿐인데, 손님?」"
	if merchant_texture != null:
		sprite.texture = merchant_texture


func get_phase() -> int:
	var r := float(hp) / float(max_hp)
	return 1 if r > 2.0 / 3.0 else (2 if r > 1.0 / 3.0 else 3)


func get_shift_count() -> int:
	return _shifts


func get_fall_count() -> int:
	return _falls


func get_stone_hits() -> int:
	return _stone_hits


func is_revealed() -> bool:
	return mode == Mode.FIGHT or mode == Mode.SPECTATING


func living_champions() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for c in champions:
		if is_instance_valid(c) and not c.is_dead():
			alive.append(c)
	return alive


func living_rifts() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for r in rifts:
		if is_instance_valid(r) and not r.is_dead():
			alive.append(r)
	return alive


func has_world(w: int) -> bool:
	return world == w or world2 == w


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		_manager = get_tree().get_first_node_in_group(&"stage_manager") as StageManager
		center = _area().get_center()
		global_position = center + Vector2(0, -25)
		_mode_left = 1.2
		set_status("야영지의 상인…?", Color(1.0, 0.8, 0.5))
	if mode != Mode.FIGHT:
		return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 등장: 상인 → 멀티버스의 주인
func can_be_hit_by(kind: HitKind) -> bool:
	return mode == Mode.FIGHT and super.can_be_hit_by(kind)


## 대사와 변신을 건너뜀 (테스트에서도 직접 호출)
func reveal() -> void:
	if is_revealed() or is_dead():
		return
	mode = Mode.FIGHT
	display_name = "멀티버스의 주인"
	immune_text = "관람석 — 투사들을 쓰러뜨려라"
	if true_texture != null:
		sprite.texture = true_texture
	sprite.modulate = Color.WHITE
	GameManager.report_boss_spawned("%s  · 방어력 %d" % [display_name, defense], max_hp)
	GameManager.report_boss_hp(hp, max_hp)
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.5, 1.0), 220.0, 0.9)
	Fx.explosion(self, get_hit_center(), Color(0.7, 0.4, 1.0), 90.0, 3)
	if has_target():
		_player.shake_camera(8.0)
	GameManager.show_notice("상인의 모습이 찢어지고 — 멀티버스의 주인이 정체를 드러낸다!", Color(1.0, 0.55, 1.0))
	shift_world()


func _begin_transform() -> void:
	mode = Mode.TRANSFORM
	_mode_left = transform_time
	GameManager.show_notice("상인의 몸이 일그러진다… 보스방 너머로 수많은 세계가 비친다", Color(0.9, 0.6, 1.0))


func _intro_process(delta: float) -> void:
	_mode_left -= delta
	if mode == Mode.MERCHANT:
		if _mode_left <= 0.0:
			if _line < LINES.size():
				GameManager.show_notice("상인: 「%s」" % LINES[_line], Color(1.0, 0.85, 0.55))
				_line += 1
				_mode_left = line_time
			else:
				_begin_transform()
		return
	# 변신: 상인과 참모습이 번갈아 깜빡이고, 보스방이 지난 세계들로 빠르게 바뀜
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = maxf(0.05, 0.25 * _mode_left / transform_time)
		sprite.texture = true_texture if sprite.texture == merchant_texture else merchant_texture
		sprite.modulate = Color(1.0, 0.7, 1.0) if sprite.texture == true_texture else Color.WHITE
		if _manager != null:
			_manager.apply_world(_manager.get_stage_data(randi_range(1, 100)))
		Fx.burst(self, get_hit_center(), Color(0.8, 0.5, 1.0), 10, 80.0, 0.4)
		if has_target():
			_player.shake_camera(2.0)
	if _mode_left <= 0.0:
		reveal()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if not is_revealed() or mode == Mode.SPECTATING:
		show_immune()
		return
	if amount > 0:
		if _fallen_left > 0.0:
			amount = roundi(amount * fall_ratio)
		elif not living_rifts().is_empty():
			amount = maxi(1, roundi(amount * rift_ratio))
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if not is_dead():
		_check_spectate()


# ============================================================ 기믹 1: 세계 전환
## 다음 세계로 (테스트에서도 직접 호출 — next 를 주면 그 세계로)
func shift_world(next: int = -1) -> void:
	if is_dead():
		return
	var overlap := get_phase() >= 3
	if overlap:
		if world2 >= 0:
			_end_world(world2)
		world2 = world
	elif world >= 0:
		_end_world(world)
	if next < 0:
		var choices: Array[int] = []
		for w in WORLD_STAGES.size():
			if w != world and w != world2:
				choices.append(w)
		next = choices.pick_random()
	world = next
	_shifts += 1
	_shift_left = shift_time * [1.0, 0.8, 0.55][get_phase() - 1]
	if _manager != null:
		_manager.apply_world(_manager.get_stage_data(WORLD_STAGES[world]))
	_start_world(world)
	Fx.shockwave(self, center, Color(0.85, 0.6, 1.0), 260.0, 0.6)
	GameManager.show_notice("세계 전환 — 「%s」: %s%s" % [WORLD_NAMES[world], WORLD_HINTS[world], (" (「%s」와 겹침)" % WORLD_NAMES[world2]) if world2 >= 0 else ""], Color(0.9, 0.7, 1.0))
	_update_status()


func _start_world(w: int) -> void:
	var area := _area().grow(-30.0)
	match w:
		World.SLIME:
			for i in 7:
				var at := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
				var zone := GroundZone.spawn_hostile(self, at, GroundZone.Kind.SLIME, 34.0, 999.0, 0.5, 0, 2.0)
				if zone != null:
					_zones.append(zone)
		World.FOG:
			veil = FogVeil.spawn(self, _area())
		World.ABYSS:
			pit = AbyssPit.spawn(self, center + Vector2(0, 40))
			if pit != null:
				pit.max_radius = 90.0
				pit.grow_rate = 4.0
				pit.fall_callback = _on_fall
				if has_target() and pit.contains(_player.global_position):
					_player.global_position = _safe_rim(_player.global_position)
		World.STONES:
			_stone_left = 1.5
		World.FLOOD:
			flood = FloodField.spawn(self, _area(), 4, plank_texture)
		World.REVELATION:
			_light_left = 2.0


func _end_world(w: int) -> void:
	match w:
		World.SLIME:
			for z in _zones:
				if is_instance_valid(z):
					z.queue_free()
			_zones.clear()
		World.FOG:
			if veil != null and is_instance_valid(veil):
				veil.queue_free()
			veil = null
		World.ABYSS:
			if pit != null and is_instance_valid(pit):
				pit.queue_free()
			pit = null
		World.FLOOD:
			if flood != null and is_instance_valid(flood):
				flood.queue_free()
			flood = null


func _world_process(delta: float) -> void:
	if not has_target():
		return
	if has_world(World.FOG) and veil != null and is_instance_valid(veil):
		veil.light_at = _player.global_position
		veil.light_radius = 110.0
	if has_world(World.SLOTH) and _player.global_position.distance_to(global_position) <= 130.0:
		_player.apply_slow(0.55, 0.15)
		_player.mark_floor_status("나태의 오라 (느려짐)")
	if has_world(World.CHAIN):
		var d := global_position.distance_to(_player.global_position)
		if d > 170.0:
			_player.apply_push(_player.global_position.direction_to(global_position) * (d - 170.0) * 12.0)
			_player.mark_floor_status("욕망의 사슬에 묶임")
	if has_world(World.SWORD):
		sword_angle = wrapf(sword_angle + 1.1 * delta, 0.0, TAU)
		_sword_cd = maxf(_sword_cd - delta, 0.0)
		if _sword_cd <= 0.0:
			var dir := Vector2.from_angle(sword_angle)
			var a := get_hit_center() + dir * SWORD_INNER
			var b := get_hit_center() + dir * SWORD_OUTER
			if _player.global_position.distance_to(Geometry2D.get_closest_point_to_segment(_player.global_position, a, b)) < 10.0:
				_sword_cd = 0.8
				_player.take_hit(roundi(sword_damage * power), get_hit_center(), self)
	if has_world(World.STONES):
		_stone_left -= delta
		if _stone_left <= 0.0:
			_stone_left = 4.0
			var area := _area().grow(-16.0)
			var y := clampf(global_position.y - 16.0 + randf_range(-70.0, 70.0), area.position.y, area.end.y)
			var flip := randf() < 0.5
			roll_stone(Vector2(area.end.x if flip else area.position.x, y), Vector2(area.position.x if flip else area.end.x, y))
	if has_world(World.FLOOD) and flood != null and is_instance_valid(flood):
		flood.level = minf(flood.level + delta / 5.0, 1.0)
		if flood.level > 0.35 and not flood.is_on_plank(_player.global_position):
			_player.apply_slow(0.6, 0.2)
			_player.mark_floor_status("홍수에 잠김 — 방주의 판자 위로")
			_flood_tick -= delta
			if _flood_tick <= 0.0:
				_flood_tick = 0.6
				_player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * 0.025 * flood.level)), _player.global_position, false)
	if has_world(World.REVELATION):
		_light_left -= delta
		if _light_left <= 0.0:
			_light_left = 5.0
			announce_light(randi() % 4)


func _on_fall(player: Player) -> void:
	player.take_unblockable_hit(roundi(GameManager.max_hp * 0.12), pit.global_position, false)
	player.global_position = _safe_rim(player.global_position)
	GameManager.show_notice("무저갱에 떨어졌다! 가장자리로 간신히 기어 나왔다", Color(1.0, 0.4, 0.3))


func _safe_rim(from: Vector2) -> Vector2:
	var area := _area().grow(-12.0)
	var dir := pit.global_position.direction_to(from)
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	for i in 17:
		var at: Vector2 = pit.global_position + dir.rotated((1 if i % 2 == 0 else -1) * ceili(i / 2.0) * TAU / 16.0) * (pit.radius + 30.0)
		if area.has_point(at):
			return at
	return pit.rim_point(from).clamp(area.position, area.end)


## 뜨인 돌 (테스트에서도 직접 호출) — 주인이 길 위에 있으면 큰 피해 + 휘청
func roll_stone(start: Vector2, end: Vector2, warn: float = 1.8) -> RollingStone:
	var stone := RollingStone.spawn(self, start, end, stone_texture, roundi(stone_damage * power), warn)
	if stone != null:
		var struck := [false]
		stone.hit_callback = func(at: Vector2) -> void:
			if not struck[0] and is_revealed() and not is_dead() and at.distance_to(get_hit_center()) < 30.0:
				struck[0] = true
				_on_stone_struck()
	return stone


func _on_stone_struck() -> void:
	_stone_hits += 1
	super.take_damage(roundi(max_hp * 0.02), Vector2.ZERO, true, 999999)
	super.stun(3.0)
	GameManager.show_notice("뜨인 돌이 멀티버스의 주인을 쳤다!", Color(0.95, 0.9, 0.8))


## 하늘의 전언 — 보스방 절반(0 동 · 1 서 · 2 북 · 3 남)에 빛 (테스트에서도 직접 호출)
func announce_light(half: int) -> void:
	GameManager.show_notice("주인이 가브리엘의 목소리를 흉내 낸다: 「%s에 빛이 내리리라」" % ["동쪽", "서쪽", "북쪽", "남쪽"][half], Color(1.0, 0.97, 0.8))
	var area := _area().grow(-10.0)
	var y := area.position.y + 24.0
	while y < area.end.y:
		var x := area.position.x + 24.0
		while x < area.end.x:
			if _in_half(Vector2(x, y), half):
				var strike := AoeStrike.spawn(self, Vector2(x, y), 22.0, 1.6, 1, Color(1.0, 0.95, 0.7))
				if strike != null:
					strike.harmless = true
			x += 48.0
		y += 48.0
	_after(1.6, func() -> void:
		if not is_dead() and has_target() and _in_half(_player.global_position, half):
			_player.take_hit(roundi(light_damage * power), center, self))


func _in_half(at: Vector2, half: int) -> bool:
	match half:
		0:
			return at.x > center.x
		1:
			return at.x < center.x
		2:
			return at.y < center.y
	return at.y > center.y


# ============================================================ 기믹 2: 관람석
func _check_spectate() -> void:
	if mode != Mode.FIGHT:
		return
	var r := float(hp) / float(max_hp)
	for i in SPECTATE_THRESHOLDS.size():
		if not _spectated[i] and r <= SPECTATE_THRESHOLDS[i]:
			_spectated[i] = true
			begin_spectate()
			return


## 관람석에 올라가 세계의 투사들을 싸움 붙임 (테스트에서도 직접 호출)
func begin_spectate() -> void:
	if is_dead():
		return
	mode = Mode.SPECTATING
	_spectate_left = spectate_time
	champions.clear()
	global_position = center + Vector2(0, -_area().size.y * 0.42)
	airborne = true
	var worlds: Array[int] = []
	while worlds.size() < 3:
		var w := randi_range(1, 99)
		if not worlds.has(w):
			worlds.append(w)
	for i in 3:
		var scenes: Array[PackedScene] = []
		if _manager != null:
			scenes = _manager.get_stage_data(worlds[i]).enemy_scenes
		if not scenes.is_empty():
			_pending_champions += 1
			request_summon(scenes.pick_random(), center + Vector2(-120.0 + 120.0 * i, 40.0))
	GameManager.show_notice("「자, 구경 좀 하자!」 — 주인이 관람석에 올라 서로 다른 세계의 투사들을 싸움 붙인다 (%d초)" % roundi(spectate_time), Color(1.0, 0.75, 0.4))
	_update_status()


func register_minion(minion: Enemy) -> void:
	if rift_scene != null and minion.scene_file_path == rift_scene.resource_path:
		var r := minion as BossPart
		r.boss = self
		r.follow_boss = false
		r.max_hp = maxi(1, roundi(max_hp * rift_hp_ratio))
		r.hp = r.max_hp
		r.died.connect(_on_rift_closed)
		rifts.append(r)
		return
	if _pending_champions > 0:
		_pending_champions -= 1
		minion.max_hp = roundi(minion.max_hp * champion_hp_mult)
		minion.hp = minion.max_hp
		minion.power *= 1.2
		minion.base_tint = Color(1.0, 0.85, 0.5)
		champions.append(minion)


func _fall_from_seat() -> void:
	mode = Mode.FIGHT
	airborne = false
	_falls += 1
	_fallen_left = fall_stun
	global_position = center + Vector2(0, -25)
	super.stun(fall_stun)
	Fx.shockwave(self, global_position, Color(1.0, 0.8, 0.4), 120.0, 0.6)
	GameManager.show_notice("투사들이 모두 쓰러졌다! 흥이 깨진 주인이 관람석에서 굴러떨어진다 (피해 x%.1f)" % fall_ratio, Color(1.0, 0.85, 0.5))
	_update_status()


func _spectate_timeout() -> void:
	mode = Mode.FIGHT
	airborne = false
	global_position = center + Vector2(0, -25)
	for c in living_champions():
		c.despawn()
	var heal := mini(roundi(max_hp * 0.04), max_hp - hp)
	hp += heal
	health_changed.emit(hp, max_hp)
	GameManager.show_notice("「재미있었어!」 — 구경을 마친 주인이 기운을 되찾는다 (+%d)" % heal, Color(1.0, 0.6, 0.6))
	_update_status()


# ============================================================ 기믹 3: 멀티버스의 균열
## 균열을 엶 (테스트에서도 직접 호출)
func open_rifts() -> void:
	if is_dead() or rift_scene == null:
		return
	_rifts_opened = true
	_rift_left = 0.0
	_rift_fire_left = rift_fire
	var area := _area()
	for side in [-1.0, 1.0]:
		request_summon(rift_scene, center + Vector2(side * area.size.x * 0.42, -20.0))
	GameManager.show_notice("멀티버스의 균열이 열렸다 — 균열이 열려 있는 동안 주인에게 피해가 덜 들어간다", Color(0.9, 0.5, 1.0))
	_update_status()


func _on_rift_closed(_r: Enemy) -> void:
	if is_dead():
		return
	if living_rifts().is_empty():
		_rift_left = rift_reopen
		GameManager.show_notice("균열이 모두 닫혔다!", Color(0.9, 0.8, 1.0))
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		match mode:
			Mode.MERCHANT, Mode.TRANSFORM:
				_intro_process(delta)
			Mode.SPECTATING:
				_spectate_left -= delta
				var alive := living_champions().size()
				if alive == 0 and _pending_champions == 0:
					_fall_from_seat()
				elif _spectate_left <= 0.0:
					_spectate_timeout()
				_world_process(delta)
			Mode.FIGHT:
				_fallen_left = maxf(_fallen_left - delta, 0.0)
				_shift_left -= delta
				if _shift_left <= 0.0:
					shift_world()
				_world_process(delta)
				if get_phase() >= 2:
					if not _rifts_opened:
						open_rifts()
					elif living_rifts().is_empty() and _rift_left > 0.0:
						_rift_left -= delta
						if _rift_left <= 0.0:
							rifts.clear()
							open_rifts()
		if is_revealed() and not living_rifts().is_empty() and has_target():
			_rift_fire_left -= delta
			if _rift_fire_left <= 0.0:
				_rift_fire_left = rift_fire
				for r in living_rifts():
					var from := r.get_hit_center()
					var dir := from.direction_to(_player.global_position)
					for i in 5:
						shoot(dir.rotated((i - 2) * 0.18), 140.0, coin_damage, coin_texture, 0.0, Elements.Type.ARCANE, from)
		if Engine.get_physics_frames() % 30 == 0 and is_revealed():
			_update_status()
		queue_redraw()
	super._physics_process(delta)


func _update_status() -> void:
	if not is_revealed():
		return
	var text := "세계: %s" % (WORLD_NAMES[world] if world >= 0 else "-")
	if world2 >= 0:
		text += " + %s" % WORLD_NAMES[world2]
	if mode == Mode.SPECTATING:
		text = "관람석 — 투사 %d · %.0f초" % [living_champions().size(), maxf(_spectate_left, 0.0)]
	elif _fallen_left > 0.0:
		text += " · 관람석에서 떨어짐!"
	elif not living_rifts().is_empty():
		text += " · 균열 %d" % living_rifts().size()
	set_status(text, Color(0.95, 0.7, 1.0))


func _run_pattern(pattern: int) -> float:
	if not has_target() or mode != Mode.FIGHT:
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.COIN_STORM:
			for w in 2:
				for i in 16:
					shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2 + dir.angle()), 130.0, coin_damage, coin_texture, 0.0, Elements.Type.ARCANE)
			return 1.1
		Pattern.PRICE_TAG:
			telegraph_strike(_player.global_position, 26.0, 0.9, price_damage, Elements.Type.ARCANE)
			for i in 6:
				telegraph_strike(_player.global_position + Vector2.from_angle(TAU * i / 6.0) * 56.0, 20.0, 1.05, price_damage - 10, Elements.Type.ARCANE)
			return 1.2
		Pattern.ECHO:
			var element := Elements.Type.ARCANE
			if world >= 0:
				element = WORLD_ELEMENTS[world] as Elements.Type
			for ring in 2:
				for i in 14:
					telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0 + ring * 0.22) * (50.0 + 36.0 * ring), 18.0, 0.8 + 0.25 * ring, echo_damage, element)
			return 1.3
		Pattern.SUMMON:
			var scenes: Array[PackedScene] = []
			if _manager != null and world >= 0:
				scenes = _manager.get_stage_data(WORLD_STAGES[world]).enemy_scenes
			if not scenes.is_empty():
				for i in 2:
					request_summon(scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


## 두루 도는 불칼
func _draw() -> void:
	if is_dead() or not has_world(World.SWORD) or not is_revealed():
		return
	var c := to_local(get_hit_center())
	var dir := Vector2.from_angle(sword_angle)
	draw_line(c + dir * SWORD_INNER, c + dir * SWORD_OUTER, Color(1.0, 0.45, 0.15, 0.85), 5.0)
	draw_line(c + dir * SWORD_INNER, c + dir * SWORD_OUTER, Color(1.0, 0.9, 0.5, 0.9), 2.0)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if mode == Mode.SPECTATING:
		sprite.position.y += -16.0 + sin(_anim_time * 2.0) * 2.0


func _die() -> void:
	if world >= 0:
		_end_world(world)
	if world2 >= 0:
		_end_world(world2)
	for c in living_champions():
		c.despawn()
	super._die()
