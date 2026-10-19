class_name BossHephaestus
extends PatternBoss
## 50스테이지 보스: 대장장이 신 헤파이스토스 — 올림포스의 모든 무기와 갑옷을 벼려 낸 불과 대장간의 신.
##   WEAPON : 손에 든 무기의 공격 (망치 = 내려치기 고리 + 충격파 / 도끼 = 넓은 휘두르기 + 회전 / 창 = 긴 찌르기 + 투창)
##   NET    : 황금 그물 — 플레이어 발밑 예고, 그 자리에 있으면 그물에 갇힘
##   SPARKS : 불똥 — 사방으로 튀는 쇳물 방울
##   SUMMON : 청동 자동인형 · 청동 사냥개 호출
##
## [기믹 1] 용광로: pour_interval 초마다 보스방 바닥의 홈(가로 또는 세로 줄) 몇 개가 달아오르고(예고) 쇳물이 흐름
##   흐르는 홈 위에 있으면 0.5초마다 최대 체력의 12% + 화상 (가드·대시 불가) → 홈 사이 빈 땅으로
## [기믹 2] 담금질: 체력 2/3 · 1/3 에서 모루로 가 새 무기를 벼림 (망치 → 도끼 → 창, 공격력 +15%)
##   모루(체력 따로)를 미리 부숴 두면 새 무기를 벼리지 못하고 화를 내며 잠깐 멈춤
## [기믹 3] 황금 그물: 그물에 갇히면 움직일 수 없고(공격은 가능), 그물(체력 따로)을 공격해 찢어야 빠져나옴 (최대 net_time 초)
## 체력 50% 이하: 쇳물이 흐르는 홈이 늘어남

enum Pattern { WEAPON, NET, SPARKS, SUMMON }
enum Weapon { HAMMER, AXE, SPEAR }

const WEAPON_NAMES := ["망치", "도끼", "창"]

@export var anvil_scene: PackedScene
@export var net_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var spark_texture: Texture2D
@export var spear_texture: Texture2D
@export var hammer_damage: int = 90
@export var axe_damage: int = 92
@export var spear_damage: int = 94
@export var spark_damage: int = 58
@export var pour_interval: float = 11.0
@export var pour_warn: float = 1.6
@export var pour_time: float = 3.0
@export var forge_time: float = 3.0
@export var anvil_hp_ratio: float = 0.05
@export var net_time: float = 4.0
@export var net_hp_ratio: float = 0.008

var weapon: Weapon = Weapon.HAMMER
var channels: MoltenChannels
var anvil: BossPart
var net: BossPart
var _pour_cooldown: float = 5.0
var _forging_left: float = 0.0
var _forge_target: int = 0
var _forges: int = 0
var _anvil_broken: bool = false
var _net_left: float = 0.0
var _nets: int = 0
var _escapes: int = 0
var _base_power: float = 1.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.WEAPON, Pattern.SPARKS, Pattern.NET, Pattern.WEAPON, Pattern.SUMMON, Pattern.WEAPON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func get_anvil() -> BossPart:
	return anvil if anvil != null and is_instance_valid(anvil) and not anvil.is_dead() else null


func get_net() -> BossPart:
	return net if net != null and is_instance_valid(net) and not net.is_dead() else null


func is_forging() -> bool:
	return _forging_left > 0.0


func get_forge_count() -> int:
	return _forges


func get_net_escapes() -> int:
	return _escapes


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		channels = MoltenChannels.spawn(self, _area())
		if anvil_scene != null:
			request_summon(anvil_scene, _area().get_center() + Vector2(-90, -30))
		set_status("무기: %s" % WEAPON_NAMES[weapon], Color(1.0, 0.75, 0.4))
	if channels != null and is_instance_valid(channels) and has_target():
		_pour_cooldown -= delta
		if _pour_cooldown <= 0.0:
			begin_pour()
	if is_forging():
		return Vector2.ZERO
	var target_weapon := clampi(int((1.0 - float(hp) / max_hp) * 3.0), 0, 2)
	if target_weapon > _forge_target and not is_dead():
		_forge_target = target_weapon
		begin_forge()
		return Vector2.ZERO
	return super._get_move_velocity(delta)


## 담금질 · 그물 시간은 기절 중에도 흐름
func _physics_process(delta: float) -> void:
	if not is_dead():
		if _forging_left > 0.0:
			_forging_left -= delta
			if Engine.get_physics_frames() % 8 == 0 and get_anvil() != null:
				Fx.burst(self, anvil.get_hit_center(), Color(1.0, 0.7, 0.3), 6, 60.0, 0.3, Vector2(0, 60))
			if _forging_left <= 0.0:
				_finish_forge()
		if _net_left > 0.0:
			_net_left -= delta
			if _net_left <= 0.0 or get_net() == null:
				_release_net(get_net() == null)
	super._physics_process(delta)


# ============================================================ 기믹 1: 용광로
func begin_pour(is_vertical: int = -1) -> void:
	_pour_cooldown = pour_interval
	if channels == null or not is_instance_valid(channels):
		return
	var vertical := randf() < 0.5 if is_vertical < 0 else is_vertical == 1
	var pick: Array[int] = [0, 1, 2, 3, 4]
	pick.shuffle()
	var lanes: Array[int] = pick.slice(0, 3 if phase_two else 2)
	channels.tick_ratio = 0.12
	channels.warn(lanes, vertical, pour_warn)
	GameManager.show_notice("용광로가 끓어 넘친다! 붉게 달아오른 홈에서 비켜라", Color(1.0, 0.6, 0.3))
	_after(pour_warn, func() -> void:
		if not is_dead() and channels != null and is_instance_valid(channels):
			channels.pour(pour_time))


# ============================================================ 기믹 2: 담금질
func register_minion(minion: Enemy) -> void:
	if not minion is BossPart:
		return
	var part := minion as BossPart
	if get_anvil() == null and not _anvil_broken and anvil == null:
		anvil = part
		anvil.boss = self
		anvil.follow_boss = false
		anvil.max_hp = maxi(1, roundi(max_hp * anvil_hp_ratio))
		anvil.died.connect(_on_anvil_broken)
	elif _net_left > 0.0 and get_net() == null:
		net = part
		net.boss = self
		net.follow_boss = false
		net.max_hp = maxi(1, roundi(max_hp * net_hp_ratio))


func _on_anvil_broken(_enemy: Enemy) -> void:
	_anvil_broken = true
	anvil = null
	GameManager.show_notice("모루를 부쉈다! 헤파이스토스는 더 이상 새 무기를 벼릴 수 없다", Color(1.0, 0.8, 0.5))


func begin_forge() -> void:
	if get_anvil() == null:
		_stun_left = 2.0
		set_status("모루가 없다! (무기: %s)" % WEAPON_NAMES[weapon], Color(1.0, 0.5, 0.4))
		FloatingText.spawn(self, global_position + Vector2(0, -60), "내 모루가…!", Color(1.0, 0.5, 0.4), true)
		return
	_forging_left = forge_time
	_bstate = BossState.CHASE
	_btimer = chase_time
	global_position = (anvil.global_position + Vector2(36, 0)).clamp(_area().position, _area().end)
	set_status("담금질 중… 모루를 부수면 막을 수 있다", Color(1.0, 0.75, 0.4))
	GameManager.show_notice("헤파이스토스가 모루에서 새 무기를 벼린다! %d초 안에 모루를 부숴라" % roundi(forge_time), Color(1.0, 0.75, 0.4))


func _finish_forge() -> void:
	_forging_left = 0.0
	if get_anvil() == null:
		begin_forge()  # 그사이 모루가 부서짐 → 실패
		return
	_forges += 1
	weapon = mini(int(weapon) + 1, 2) as Weapon
	power = _base_power * (1.0 + 0.15 * int(weapon))
	set_status("무기: %s" % WEAPON_NAMES[weapon], Color(1.0, 0.75, 0.4))
	GameManager.show_notice("새 무기 「%s」가 완성되었다! 공격이 바뀐다" % WEAPON_NAMES[weapon], Color(1.0, 0.75, 0.4))
	Fx.explosion(self, get_hit_center(), Color(1.0, 0.7, 0.3), 50.0, 2)


# ============================================================ 기믹 3: 황금 그물
## 그물에 가둠 (테스트에서도 직접 호출)
func trap_in_net() -> bool:
	if not has_target() or _player.is_dashing() or _net_left > 0.0 or net_scene == null:
		return false
	_nets += 1
	_net_left = net_time
	_player.apply_root(net_time, "황금 그물에 갇힘! 그물을 공격해 찢어라")
	request_summon(net_scene, _player.global_position + Vector2(0, -2))
	GameManager.show_notice("황금 그물에 갇혔다! 그물을 공격해서 찢어라", Color(1.0, 0.9, 0.5))
	return true


func _release_net(escaped: bool) -> void:
	_net_left = 0.0
	if get_net() != null:
		net.despawn()
	net = null
	if escaped:
		_escapes += 1
		FloatingText.spawn(_player, _player.global_position + Vector2(0, -24), "그물을 찢었다!", Color(1.0, 0.95, 0.6), true)
	if _player != null and is_instance_valid(_player):
		_player.release_root()


# ============================================================ 패턴
func _weapon_attack() -> float:
	var dir := direction_to_player()
	match weapon:
		Weapon.HAMMER:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 50.0, 22.0, 0.85, hammer_damage, Elements.Type.FIRE)
			for i in 12:
				shoot(Vector2.from_angle(TAU * i / 12.0), 100.0, spark_damage, spark_texture, 0.0, Elements.Type.FIRE)
			return 1.3
		Weapon.AXE:
			for i in 7:
				telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.3) * 54.0, 24.0, 0.75, axe_damage, Elements.Type.FIRE)
			for i in 8:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 8.0) * 32.0, 18.0, 1.1, axe_damage - 10, Elements.Type.FIRE)
			return 1.4
	# 창: 긴 찌르기 + 투창
	for i in 12:
		telegraph_strike(get_hit_center() + dir * (24.0 + 24.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.FIRE)
	for k in 3:
		shoot(dir.rotated((k - 1) * 0.25), 210.0, spear_damage - 20, spear_texture, 0.0, Elements.Type.FIRE)
	return 1.2


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.WEAPON:
			return _weapon_attack()
		Pattern.NET:
			var at := _player.global_position
			var strike := telegraph_strike(at, 24.0, 0.8, 20, Elements.Type.HOLY)
			if strike != null:
				strike.color = Color(1.0, 0.85, 0.3)
			_after(0.8, func() -> void:
				if not is_dead() and has_target() and _player.global_position.distance_to(at) <= 26.0:
					trap_in_net())
			return 1.2
		Pattern.SPARKS:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2), 115.0, spark_damage, spark_texture, 0.0, Elements.Type.FIRE))
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	_release_net(false)
	if channels != null and is_instance_valid(channels):
		channels.queue_free()
	if GameManager.key_items.has(&"prometheus_ember"):
		# 프로메테우스의 불씨 → 헤파이스토스가 쓰러지며 용광로에서 「원초의 불꽃」으로 제련
		GameManager.key_items.erase(&"prometheus_ember")
		GameManager.add_relic(ItemDB.get_relic(&"primal_flame"))
		GameManager.show_notice("프로메테우스의 불씨가 용광로 속에서 다시 타올라 「원초의 불꽃」이 되었다! — 봉인됨 · 100스테이지를 클리어하면 [Z] 로 사용", Color(1.0, 0.6, 0.25))
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("헤파이스토스: 대장간의 불은 꺼지지 않는다! 쇳물이 더 넓게 흐른다", Color(1.0, 0.6, 0.3))
