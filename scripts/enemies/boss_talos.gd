class_name BossTalos
extends PatternBoss
## 38스테이지 보스: 청동 거인 탈로스 — 대장장이 신이 해안을 지키라고 만든 청동 거인.
##   STOMP   : 발 구르기 — 몸 주위 고리 장판
##   BOULDER : 바위 던지기 — 바위 부채꼴
##   PUNCH   : 주먹 내려치기 — 플레이어 쪽 장판 세 개
##   SUMMON  : 청동 병사 · 바위 게 호출
##
## [기믹 1] 청동 못: 발목에 박힌 청동 못(체력 따로)이 유일한 약점. 못이 박혀 있는 동안 방어력 +nail_armor
##   못을 부수면 신의 피(이코르)가 흘러나와 crash_stun 초 무너지고, bleed_time 초 동안 방어력 보너스가 사라진 채
##   0.5초마다 최대 체력의 bleed_ratio 를 잃음 → 그 뒤 더 단단한 새 못을 박음
## [기믹 2] 달궈진 몸: 열이 계속 오름. 50% 이상이면 공격·몸통에 화상, 100% 면 「작열」(주기적으로 몸 주위 폭발)
##   보스방의 물웅덩이로 유인하면(탈로스가 웅덩이에 들어가면) 김을 뿜으며 식고 잠깐 멈춤
## 체력 50% 이하: 열이 더 빨리 오름

enum Pattern { STOMP, BOULDER, PUNCH, SUMMON }

@export var nail_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var boulder_texture: Texture2D
@export var stomp_damage: int = 76
@export var boulder_damage: int = 56
@export var punch_damage: int = 80
@export var blaze_damage: int = 70
@export var nail_armor: int = 60
@export var nail_hp_ratio: float = 0.035
@export var crash_stun: float = 3.0
@export var bleed_time: float = 10.0
@export var bleed_ratio: float = 0.004
@export var heat_rate: float = 5.0

var heat: float = 0.0
var nail: BossPart
var pools: Array[WaterPool] = []
var _base_defense: int = 0
var _bleed_left: float = 0.0
var _bleed_tick: float = 0.5
var _renail_left: float = -1.0
var _nails_broken: int = 0
var _cools: int = 0
var _blaze_timer: float = 1.5
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.STOMP, Pattern.BOULDER, Pattern.PUNCH, Pattern.SUMMON, Pattern.BOULDER, Pattern.PUNCH]
	_base_defense = defense


func get_nail() -> BossPart:
	return nail if nail != null and is_instance_valid(nail) and not nail.is_dead() else null


func is_bleeding() -> bool:
	return _bleed_left > 0.0


func get_nails_broken() -> int:
	return _nails_broken


func get_cool_count() -> int:
	return _cools


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
		var c := area.get_center()
		for k in 2:
			var side := -1.0 if k == 0 else 1.0
			pools.append(WaterPool.spawn(self, c + Vector2(side * area.size.x * 0.32, area.size.y * 0.22), 36.0))
		hammer_nail()
	_update_heat(delta)
	return super._get_move_velocity(delta)


## 이코르 출혈 · 새 못 박기 타이머는 기절 중에도 흐름
func _physics_process(delta: float) -> void:
	if not is_dead():
		if _bleed_left > 0.0:
			_bleed_left -= delta
			_bleed_tick -= delta
			if _bleed_tick <= 0.0:
				_bleed_tick = 0.5
				var loss := mini(maxi(1, roundi(max_hp * bleed_ratio)), hp - 1)
				if loss > 0:
					hp -= loss
					health_changed.emit(hp, max_hp)
					FloatingText.spawn(self, global_position + Vector2(randf_range(-10, 10), -40), str(loss), Color(1.0, 0.85, 0.4))
				Fx.burst(self, global_position + Vector2(-10, -4), Color(1.0, 0.8, 0.3), 4, 40.0, 0.4, Vector2(0, 60))
			if _bleed_left <= 0.0:
				_renail_left = 2.0
				set_status("", Color.WHITE)
		elif _renail_left > 0.0:
			_renail_left -= delta
			if _renail_left <= 0.0:
				_renail_left = -1.0
				hammer_nail()
	super._physics_process(delta)


# ============================================================ 기믹 1: 청동 못
func hammer_nail() -> void:
	if is_dead() or nail_scene == null or get_nail() != null:
		return
	request_summon(nail_scene, global_position + Vector2(-12, -2))


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and get_nail() == null:
		nail = minion as BossPart
		nail.boss = self
		nail.follow_boss = true
		nail.anchor_offset = Vector2(-12, -2)
		nail.mirror_x = true
		nail.max_hp = maxi(1, roundi(max_hp * nail_hp_ratio * (1.0 + 0.3 * _nails_broken)))
		nail.died.connect(_on_nail_broken)
		defense = _base_defense + nail_armor
		if _nails_broken > 0:
			GameManager.show_notice("탈로스가 발목에 새 청동 못을 박았다! 더 단단하다", Color(0.95, 0.75, 0.45))


func _on_nail_broken(_enemy: Enemy) -> void:
	if is_dead():
		return
	_nails_broken += 1
	nail = null
	defense = _base_defense
	_stun_left = crash_stun
	_bleed_left = bleed_time
	_bleed_tick = 0.5
	set_status("이코르가 흘러나온다!", Color(1.0, 0.85, 0.4))
	GameManager.show_notice("청동 못이 뽑혔다! 신의 피가 흘러나와 탈로스가 무너진다 — 지금 몰아쳐라", Color(1.0, 0.85, 0.4))
	Fx.explosion(self, global_position + Vector2(-12, -4), Color(1.0, 0.8, 0.3), 30.0, 2)
	if _player != null:
		_player.shake_camera(6.0)


# ============================================================ 기믹 2: 달궈진 몸
func _update_heat(delta: float) -> void:
	heat = minf(heat + heat_rate * (1.4 if phase_two else 1.0) * delta, 100.0)
	for pool in pools:
		if is_instance_valid(pool) and pool.contains(global_position) and heat >= 30.0:
			cool_down(pool)
			return
	burn_damage = 10 if heat >= 50.0 else 0
	burn_duration = 2.5
	base_tint = Color.WHITE.lerp(Color(1.6, 0.7, 0.4), clampf((heat - 30.0) / 70.0, 0.0, 1.0))
	if heat >= 100.0:
		_blaze_timer -= delta
		if _blaze_timer <= 0.0:
			_blaze_timer = 1.6
			for i in 8:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 8.0) * 40.0, 22.0, 0.7, blaze_damage, Elements.Type.FIRE)
	if get_status_text() == "" or get_status_text().begins_with("열"):
		set_status("열 %d%%%s" % [roundi(heat), " — 작열!" if heat >= 100.0 else ""], Color(1.0, 0.6, 0.3) if heat >= 50.0 else Color(0.9, 0.85, 0.75))


func cool_down(pool: WaterPool = null) -> void:
	heat = 0.0
	_cools += 1
	burn_damage = 0
	base_tint = Color.WHITE
	_stun_left = maxf(_stun_left, 1.5)
	if pool != null:
		pool.steam()
	set_status("", Color.WHITE)
	GameManager.show_notice("탈로스가 물웅덩이에 들어가 식었다!", Color(0.7, 0.9, 1.0))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.STOMP:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 52.0, 20.0, 0.85, stomp_damage, Elements.Type.EARTH)
			if _player != null:
				_player.shake_camera(4.0)
			return 1.3
		Pattern.BOULDER:
			var aim := direction_to_player()
			for i in 5:
				shoot(aim.rotated((i - 2) * 0.22), 130.0, boulder_damage, boulder_texture, 0.0, Elements.Type.EARTH)
			return 1.0
		Pattern.PUNCH:
			var dir := direction_to_player()
			for i in 3:
				telegraph_strike(get_hit_center() + dir * (36.0 + 30.0 * i), 22.0, 0.75 + 0.1 * i, punch_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("탈로스의 청동 몸이 더 빨리 달아오른다!", Color(1.0, 0.6, 0.3))
