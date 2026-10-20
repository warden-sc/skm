class_name BossPrometheus
extends PatternBoss
## 49스테이지 보스: 사슬에 묶인 티탄 프로메테우스 — 신들의 불을 훔쳐 인간에게 준 죄로 바위산에 묶인 티탄.
##   FLAME   : 훔친 불 — 화염구 부채꼴
##   BLAZE   : 불기둥 — 플레이어 주변 장판 + 남는 불바다
##   NOVA    : 불의 고리 — 사방으로 퍼지는 불꽃
##   SUMMON  : 바위산 독수리 · 사슬 감시자 호출
##
## [기믹] 사슬 4개: 보스방 네 곳의 바위에 박힌 사슬(체력 따로)이 프로메테우스를 묶고 있음
##   묶인 사슬마다 방어력 +chain_armor, 사슬에 묶여 있는 동안엔 움직이는 범위가 줄어듦
##   사슬을 끊을 때마다 방어력이 떨어지지만 「해방」 — 공격력 +12% · 더 빨리 움직임 (모두 끊으면 완전 해방)
##   → 사슬을 남겨 두면 단단하고, 끊으면 사나워짐
## 보상: 처치하면 「프로메테우스의 불씨」를 얻음 (장비 조정 때 쓰일 예정인 보물)
## 체력 50% 이하: 불길이 더 거세짐

enum Pattern { FLAME, BLAZE, NOVA, SUMMON }

const EMBER_ID := &"prometheus_ember"

@export var chain_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var fire_texture: Texture2D
@export var flame_damage: int = 58
@export var blaze_damage: int = 86
@export var nova_damage: int = 56
@export var chain_armor: int = 12
@export var chain_hp_ratio: float = 0.03

var chains: Array[BossPart] = []
var freed: int = 0
var _anchor: Vector2 = Vector2.ZERO
var _chain_queue: int = 0
var _base_defense: int = 0
var _base_power: float = 1.0
var _base_speed: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.FLAME, Pattern.BLAZE, Pattern.NOVA, Pattern.SUMMON, Pattern.FLAME, Pattern.BLAZE]
	_base_defense = defense
	_base_speed = move_speed


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func get_chains() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for c in chains:
		if is_instance_valid(c) and not c.is_dead():
			alive.append(c)
	return alive


## 사슬에 묶여 움직일 수 있는 반경 (모두 끊으면 제한 없음)
func leash_radius() -> float:
	var left := get_chains().size() + _chain_queue
	return INF if left == 0 else 30.0 + 30.0 * (4 - left)


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		_anchor = global_position
		var a := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
		var c := a.get_center()
		for v in [Vector2(-0.38, -0.3), Vector2(0.38, -0.3), Vector2(-0.38, 0.32), Vector2(0.38, 0.32)]:
			var off: Vector2 = v
			_chain_queue += 1
			request_summon(chain_scene, c + Vector2(off.x * a.size.x, off.y * a.size.y))
		_update_freedom()
	var v2 := super._get_move_velocity(delta)
	var limit := leash_radius()
	if limit < INF:
		var next := global_position + v2 * delta
		if next.distance_to(_anchor) > limit:
			return Vector2.ZERO
	return v2


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and _chain_queue > 0:
		_chain_queue -= 1
		var chain := minion as BossPart
		chain.boss = self
		chain.follow_boss = false
		chain.max_hp = maxi(1, roundi(max_hp * chain_hp_ratio))
		chain.died.connect(_on_chain_broken)
		chains.append(chain)
		_update_freedom()


func _update_freedom() -> void:
	var left := get_chains().size() + _chain_queue
	freed = 4 - left
	defense = _base_defense + chain_armor * left
	power = _base_power * (1.0 + 0.12 * freed)
	move_speed = _base_speed * (1.0 + 0.2 * freed)
	set_status("사슬 %d개 — 방어력 +%d · 해방 %d" % [left, chain_armor * left * Balance.K, freed] if left > 0 else "완전 해방!", Color(1.0, 0.7, 0.4))


func _on_chain_broken(_enemy: Enemy) -> void:
	if is_dead():
		return
	_update_freedom()
	Fx.fire_blast(self, get_hit_center(), 30.0, 2)
	if freed >= 4:
		Net.announce("마지막 사슬이 끊어졌다! 프로메테우스가 완전히 해방되었다", Color(1.0, 0.6, 0.3))
	else:
		Net.announce("사슬이 끊어졌다! 방어력이 떨어졌지만 프로메테우스가 더 사나워진다 (해방 %d)" % freed, Color(1.0, 0.7, 0.4))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.FLAME:
			var aim := direction_to_player()
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 7:
						shoot(aim.rotated((i - 3) * 0.16 + w * 0.08), 150.0, flame_damage, fire_texture, 0.0, Elements.Type.FIRE))
			return 1.1
		Pattern.BLAZE:
			for i in (7 if phase_two else 5):
				var at := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0))
				telegraph_strike(at, 22.0, 0.85 + 0.08 * i, blaze_damage, Elements.Type.FIRE)
				_after(0.85 + 0.08 * i, func() -> void:
					if not is_dead():
						GroundZone.spawn_hostile(self, at, GroundZone.Kind.FIRE, 20.0, 6.0, 1.0, roundi(8 * power), 2.0))
			return 1.5
		Pattern.NOVA:
			for i in 18:
				shoot(Vector2.from_angle(TAU * i / 18.0), 115.0, nova_damage, fire_texture, 0.0, Elements.Type.FIRE)
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if not GameManager.key_items.has(EMBER_ID):
		GameManager.key_items.append(EMBER_ID)
		GameManager.inventory_changed.emit()
	Net.announce("「프로메테우스의 불씨」를 얻었다 — 인간에게 불을 준 티탄의 마지막 불씨", Color(1.0, 0.7, 0.3))
	for c in get_chains():
		c.despawn()
	super._die()


func _on_phase_two() -> void:
	Net.announce("프로메테우스: 이 불은 신들의 것이 아니다! 불길이 거세진다", Color(1.0, 0.6, 0.3))
