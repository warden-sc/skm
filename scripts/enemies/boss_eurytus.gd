class_name BossEurytus
extends PatternBoss
## 61스테이지 보스: 활의 왕 에우리토스 — 아폴론에게 활 솜씨를 겨루자고 했던 오이칼리아의 왕.
##   VOLLEY  : 부채꼴 화살 세례
##   PIERCE  : 꿰뚫는 화살 — 일직선 장판
##   RAIN    : 화살비 — 플레이어 주변에 떨어지는 화살
##   TARGET  : 경연 — 아직 아무도 맞히지 못한 과녁을 노려 쏨 (contest_shot_time 초 뒤 명중)
##   SUMMON  : 오이칼리아 궁수 · 사냥개 호출
##
## [기믹] 궁술 경연: 보스방 위쪽의 과녁 3개 — 먼저 맞힌 쪽이 그 과녁을 차지 (플레이어는 어떤 공격으로든 맞히면 됨)
##   과녁 3개가 모두 정해지면 판정: 플레이어가 2개 이상이면 「경연 패배」 → 크게 휘청이고 lose_time 초 동안 방어력 -lose_defense
##   에우리토스가 2개 이상이면 「경연 승리」 → win_time 초 동안 공격력 +win_power. round_rest 초 뒤 과녁이 다시 섬
## [기믹] 화살 맞받기: 플레이어의 화살·마법탄이 에우리토스의 화살에 닿으면 둘 다 떨어짐
## 체력 50% 이하: 경연 화살이 더 빨리 날아감

enum Pattern { VOLLEY, PIERCE, RAIN, TARGET, SUMMON }
enum Owner { NONE, PLAYER, BOSS }

const TARGET_SPOTS := [Vector2(-180, -120), Vector2(0, -135), Vector2(180, -120)]

@export var target_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var arrow_texture: Texture2D
@export var volley_damage: int = 60
@export var pierce_damage: int = 92
@export var rain_damage: int = 76
@export var contest_shot_time: float = 0.9
@export var lose_time: float = 15.0
@export var lose_defense: int = 25
@export var win_time: float = 15.0
@export var win_power: float = 0.2
@export var round_rest: float = 12.0

var targets: Array[BossPart] = [null, null, null]
var owners: Array[int] = [Owner.NONE, Owner.NONE, Owner.NONE]
var _pending_slot: int = -1
var _round_rest_left: float = 0.0
var _lose_left: float = 0.0
var _win_left: float = 0.0
var _player_wins: int = 0
var _boss_wins: int = 0
var _parries: int = 0
var _base_defense: int = 0
var _base_power: float = 1.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.VOLLEY, Pattern.TARGET, Pattern.PIERCE, Pattern.RAIN, Pattern.TARGET, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power
	_base_defense = defense


func get_player_wins() -> int:
	return _player_wins


func get_boss_wins() -> int:
	return _boss_wins


func get_parry_count() -> int:
	return _parries


func count_owned(who: int) -> int:
	return owners.count(who)


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		_set_up_targets()
	return super._get_move_velocity(delta)


func _set_up_targets() -> void:
	for i in TARGET_SPOTS.size():
		owners[i] = Owner.NONE
		if targets[i] != null and is_instance_valid(targets[i]):
			targets[i].despawn()
		targets[i] = null
		if target_scene != null:
			_pending_slot = i
			request_summon(target_scene, _area().get_center() + TARGET_SPOTS[i])
			_pending_slot = -1
	_update_status()


func register_minion(minion: Enemy) -> void:
	if not minion is BossPart or _pending_slot < 0:
		return
	var target := minion as BossPart
	target.boss = self
	target.follow_boss = false
	target.show_bar = false
	target.relay_ratio = 0.001 * (_pending_slot + 1)  # 몇 번째 과녁인지 구분용 (피해는 넘기지 않음)
	targets[_pending_slot] = target


## 과녁을 때리면 BossPart 가 여기로 알려 줌
func take_weak_point_hit(_amount: int, _kb: Vector2, _is_crit: bool, _armor_pen: int, ratio: float) -> void:
	claim_target(clampi(roundi(ratio * 1000.0) - 1, 0, targets.size() - 1), Owner.PLAYER)


## 과녁을 차지 (테스트에서도 직접 호출)
func claim_target(index: int, who: int) -> bool:
	if is_dead() or owners[index] != Owner.NONE or targets[index] == null or not is_instance_valid(targets[index]):
		return false
	owners[index] = who
	var t := targets[index]
	t.base_tint = Color(0.6, 0.85, 1.0) if who == Owner.PLAYER else Color(1.0, 0.5, 0.4)
	Fx.burst(t, t.get_hit_center(), t.base_tint, 14, 60.0, 0.5)
	FloatingText.spawn(t, t.global_position + Vector2(0, -28), "명중! (%s)" % ("나" if who == Owner.PLAYER else "에우리토스"), t.base_tint, true)
	if not owners.has(Owner.NONE):
		_judge()
	_update_status()
	return true


func _judge() -> void:
	if count_owned(Owner.PLAYER) >= 2:
		_player_wins += 1
		_lose_left = lose_time
		defense = maxi(_base_defense - lose_defense, 0)
		super.stun(5.0)
		GameManager.show_notice("궁술 경연에서 이겼다! 에우리토스가 분해서 휘청인다 (방어력 -%d)" % lose_defense, Color(0.7, 0.9, 1.0))
	else:
		_boss_wins += 1
		_win_left = win_time
		power = _base_power * (1.0 + win_power)
		GameManager.show_notice("에우리토스가 경연에서 이겼다! 기세가 올라 공격력이 오른다", Color(1.0, 0.6, 0.5))
	_round_rest_left = round_rest


func _physics_process(delta: float) -> void:
	if not is_dead():
		if _lose_left > 0.0:
			_lose_left -= delta
			if _lose_left <= 0.0:
				defense = _base_defense
		if _win_left > 0.0:
			_win_left -= delta
			if _win_left <= 0.0:
				power = _base_power
		if _round_rest_left > 0.0:
			_round_rest_left -= delta
			if _round_rest_left <= 0.0:
				_set_up_targets()
				GameManager.show_notice("새 과녁이 섰다! 에우리토스보다 먼저 맞혀라", Color(1.0, 0.9, 0.6))
		_parry_arrows()
	super._physics_process(delta)


## 플레이어의 탄이 적 화살에 닿으면 둘 다 떨어뜨림
func _parry_arrows() -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var enemy_shots: Array[Projectile] = []
	var player_shots: Array[Projectile] = []
	for c in pool.get_children():
		var p := c as Projectile
		if p == null or not p.is_active:
			continue
		if p.get_team() == ProjectileSpec.Team.ENEMY:
			enemy_shots.append(p)
		else:
			player_shots.append(p)
	if enemy_shots.is_empty() or player_shots.is_empty():
		return
	for ps in player_shots:
		for es in enemy_shots:
			if es.is_active and ps.is_active and ps.global_position.distance_to(es.global_position) < 10.0:
				_parries += 1
				Fx.burst(self, es.global_position, Color(1.0, 0.95, 0.7), 8, 50.0, 0.3)
				es.release()
				ps.release()
				break


func _update_status() -> void:
	set_status("궁술 경연 — 나 %d · 에우리토스 %d / 3" % [count_owned(Owner.PLAYER), count_owned(Owner.BOSS)], Color(1.0, 0.9, 0.6))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.VOLLEY:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead() or not has_target():
						return
					var aim := direction_to_player()
					for i in 7:
						shoot(aim.rotated((i - 3) * 0.12), 210.0, volley_damage, arrow_texture))
			return 1.0
		Pattern.PIERCE:
			for i in 14:
				telegraph_strike(get_hit_center() + dir * (24.0 + 22.0 * i), 12.0, 0.6 + 0.02 * i, pierce_damage, Elements.Type.NONE)
			return 1.1
		Pattern.RAIN:
			for i in 8:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0)
				telegraph_strike(at, 16.0, 0.8 + 0.07 * i, rain_damage, Elements.Type.NONE)
			return 1.2
		Pattern.TARGET:
			var open: Array[int] = []
			for i in owners.size():
				if owners[i] == Owner.NONE and targets[i] != null and is_instance_valid(targets[i]):
					open.append(i)
			if open.is_empty():
				return _run_pattern(Pattern.VOLLEY)
			var pick: int = open.pick_random()
			var flight := contest_shot_time * (0.7 if phase_two else 1.0)
			CarryItem.fly(self, get_hit_center(), targets[pick].get_hit_center(), arrow_texture, flight)
			_after(flight, func() -> void: claim_target(pick, Owner.BOSS))
			return 0.8
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("에우리토스: 아폴론조차 내 활을 두려워했다! 경연 화살이 빨라진다", Color(0.9, 1.0, 0.7))
