class_name BossMidas
extends PatternBoss
## 67스테이지 보스: 황금 손의 왕 미다스 — 닿는 것마다 황금으로 바꾸는 손을 얻었고, 아폴론의 노여움으로 당나귀 귀가 된 왕.
##   GOLD_TOUCH : 황금의 손 — 플레이어 주변에 황금 웅덩이를 흩뿌림
##   COINS      : 금화 탄막
##   SCEPTER    : 왕홀 내려치기 (앞쪽 부채꼴)
##   SUMMON     : 황금 병사 · 당나귀 귀 시종 호출
##
## [기믹] 황금화: 황금 웅덩이를 밟거나 미다스의 손에 닿으면 「황금화」가 쌓임 — 쌓인 만큼 느려지고, 100% 가 되면 굳어 버림 (행동불능)
##   보스방 아래쪽 「팍톨로스 강」에 들어가면 황금이 씻겨 나감 (미다스가 손을 씻었던 강)
## [기믹] 갈대밭의 속삭임: 왼쪽 위 갈대밭으로 미다스를 끌어들이면 「임금님 귀는 당나귀 귀」 속삭임에 혼란
##   → 크게 휘청이고 confuse_time 초 동안 방어력 -confuse_defense (갈대밭은 reeds_cooldown 초 쉼)
## 체력 50% 이하: 웅덩이가 더 많이, 더 오래 남음

enum Pattern { GOLD_TOUCH, COINS, SCEPTER, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var coin_texture: Texture2D
@export var coin_damage: int = 58
@export var scepter_damage: int = 92
@export var gild_rate: float = 45.0
@export var touch_gild: float = 25.0
@export var freeze_time: float = 2.0
@export var puddle_time: float = 7.0
@export var confuse_time: float = 10.0
@export var confuse_defense: int = 25
@export var reeds_rest: float = 15.0

var field: MidasField
var gild: float = 0.0
var _freezes: int = 0
var _confuse_left: float = 0.0
var _confusions: int = 0
var _base_defense: int = 0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.GOLD_TOUCH, Pattern.COINS, Pattern.SCEPTER, Pattern.GOLD_TOUCH, Pattern.SUMMON]
	GameManager.player_damaged.connect(_on_player_damaged)


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_defense = defense


func get_freeze_count() -> int:
	return _freezes


func is_confused() -> bool:
	return _confuse_left > 0.0


func get_confuse_count() -> int:
	return _confusions


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		field = MidasField.spawn(self, _area())
	return super._get_move_velocity(delta)


func add_gild(amount: float) -> void:
	if not has_target() or _player.is_charmed():
		return
	gild = minf(gild + amount, 100.0)
	if gild >= 100.0:
		_freezes += 1
		gild = 40.0
		_player.apply_charm(freeze_time, null, "황금화")
		GameManager.show_notice("온몸이 황금으로 굳었다! 팍톨로스 강에서 씻어 내라", Color(1.0, 0.85, 0.3))


## 미다스의 손(몸통)에 닿아도 황금화
func _on_player_damaged(_amount: int) -> void:
	if not is_dead() and has_target() and _touching_player:
		add_gild(touch_gild)


func _physics_process(delta: float) -> void:
	if not is_dead() and field != null and is_instance_valid(field) and has_target():
		var at := _player.global_position
		if field.is_in_river(at):
			if gild > 0.0:
				if gild >= 10.0:
					FloatingText.spawn(_player, at + Vector2(0, -26), "황금을 씻어 냈다", Color(0.6, 0.85, 1.0))
				gild = 0.0
		elif field.is_on_gold(at):
			add_gild(gild_rate * delta)
		if gild > 0.0:
			_player.apply_slow(1.0 - gild / 100.0 * 0.6, 0.1)
			_player.mark_floor_status("황금화 %d%% (팍톨로스 강에서 씻어 내기)" % roundi(gild))
		if field.reeds_cooldown <= 0.0 and field.is_in_reeds(global_position):
			confuse()
		if _confuse_left > 0.0:
			_confuse_left -= delta
			if _confuse_left <= 0.0:
				defense = _base_defense
		_update_status()
	super._physics_process(delta)


## 갈대밭의 속삭임 (테스트에서도 직접 호출)
func confuse() -> void:
	if is_dead():
		return
	_confusions += 1
	_confuse_left = confuse_time
	defense = maxi(_base_defense - confuse_defense, 0)
	if field != null:
		field.reeds_cooldown = reeds_rest
	super.stun(6.0)
	FloatingText.spawn(self, global_position + Vector2(0, -56), "「임금님 귀는 당나귀 귀…」", Color(0.8, 1.0, 0.6), true)
	GameManager.show_notice("갈대밭의 속삭임에 미다스가 혼란에 빠졌다! (방어력 -%d)" % confuse_defense, Color(0.8, 1.0, 0.6))


func _update_status() -> void:
	if is_confused():
		set_status("혼란 — 방어력 -%d" % confuse_defense, Color(0.8, 1.0, 0.6))
	else:
		set_status("황금 손 — 갈대밭으로 끌어들여라", Color(1.0, 0.85, 0.35))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.GOLD_TOUCH:
			for i in (7 if phase_two else 5):
				var at := _player.global_position + Vector2.from_angle(TAU * i / 5.0 + randf()) * randf_range(10.0, 70.0)
				var strike := telegraph_strike(at, MidasField.PUDDLE_RADIUS, 0.8, 30, Elements.Type.HOLY)
				if strike != null:
					strike.color = Color(1.0, 0.85, 0.3)
				_after(0.8, func() -> void:
					if not is_dead() and field != null and is_instance_valid(field):
						field.add_puddle(at, puddle_time * (1.4 if phase_two else 1.0)))
			return 1.1
		Pattern.COINS:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 14:
						shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 125.0, coin_damage, coin_texture, 0.0, Elements.Type.HOLY))
			return 1.1
		Pattern.SCEPTER:
			for i in 7:
				telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.28) * 48.0, 20.0, 0.7, scepter_damage, Elements.Type.NONE)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	gild = 0.0
	if has_target() and _player.is_charmed():
		_player.release_charm()
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("미다스: 모든 것을 황금으로! 웅덩이가 더 많이, 더 오래 남는다", Color(1.0, 0.85, 0.35))
