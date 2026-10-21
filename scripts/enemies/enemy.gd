class_name Enemy
extends Area2D
## 모든 몬스터의 기반 클래스 (Area2D)
##
## - 플레이어의 근접 공격(AttackController 의 형상 질의)과 투사체(area_entered)가 take_damage() 를 호출합니다.
## - 방어력(defense)만큼 받는 피해가 줄어듭니다. 무기·팔찌의 방어력 관통(방깍)이 그만큼 방어력을 무시합니다.
##   (아무리 방어력이 높아도 원래 피해의 MIN_DAMAGE_RATIO 만큼은 들어감)
## - 플레이어 몸체와 겹쳐 있는 동안 contact_damage 를 줍니다 (플레이어 무적시간으로 연타 방지).
##   방패로 막히면 apply_knockback() 으로 밀려나고, 퍼펙트 가드면 stun() 으로 기절합니다.
## - 사망 시 died 시그널 발행 → StageManager 가 골드(확정) / 장비(확률) 드랍을 처리합니다.
## - 이동 패턴은 자식 클래스에서 _get_move_velocity() 를 오버라이드해서 만듭니다.
## - 원거리/장판 공격은 shoot() / telegraph_strike() 헬퍼를 쓰면 풀·이펙트·난이도 배율이 자동 적용됩니다.

signal died(enemy: Enemy)
signal health_changed(current: int, max_hp: int)
## 보스가 졸개를 소환할 때 사용 (StageManager 가 받아서 스폰하고, 소환자에게 register_minion() 으로 알려 줌)
signal summon_requested(scene: PackedScene, at_global: Vector2, summoner: Enemy)

## 지휘관(드라이어드 등)이 내리는 명령. 명령을 받는 동안은 원래 이동 패턴 대신 명령대로 움직입니다.
##   CHARGE : 잠깐 멈춰 힘을 모은 뒤 그 순간의 플레이어 방향으로 일직선 돌격
##   MOVE_TO: 지정한 지점으로 빠르게 이동해 대기 (포위 진형 등)
##   GUARD  : 지휘관 곁(지정한 오프셋)으로 돌아와 지킴
enum Command { NONE, CHARGE, MOVE_TO, GUARD }
## 플레이어 공격 종류. 공중에 뜬 적(airborne)은 활(BOW)로만 맞힐 수 있음 (와이번 기믹)
enum HitKind { MELEE, BOW, MAGIC }

const COMMAND_CHARGE_WINDUP := 0.35
const COMMAND_CHARGE_SPEED := 3.4
const COMMAND_MOVE_SPEED := 2.0
## 느린 몬스터(트렌트 등)도 명령은 따라올 수 있도록 하는 최소 속도
const COMMAND_MIN_CHARGE_SPEED := 160.0
const COMMAND_MIN_MOVE_SPEED := 120.0
## 호위 명령은 지휘관 곁으로 서둘러 돌아옴
const COMMAND_GUARD_SPEED := 180.0

@export var display_name: String = "몬스터"
@export var max_hp: int = 20
## 받는 피해에서 빠지는 방어력 (방어력 관통만큼 무시됨)
@export var defense: int = 0
@export var move_speed: float = 40.0
@export var contact_damage: int = 8
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
@export var is_boss: bool = false

@export_group("Aura")
## 몸에 두르는 속성 오라 파티클 (헬하운드/수문장의 불꽃, 골렘의 원소 등). 0 이면 없음
@export var aura_element: Elements.Type = Elements.Type.NONE
@export var aura_amount: int = 0

@export_group("Burn")
## 0 보다 크면 이 적의 공격(접촉·탄·장판)에 맞은 플레이어가 화상을 입음 (0.5초마다 이 피해, 방어력으로 감소)
@export var burn_damage: int = 0
@export var burn_duration: float = 3.0
## true 면 화상 대신 독 (상태 표시·색만 다름)
@export var burn_is_poison: bool = false
## 0 보다 크면 이 적의 공격에 맞을 때마다 플레이어에게 「죽음의 낙인」이 쌓임 (사신)
@export var death_mark_on_hit: int = 0

@export_group("Drops")
@export var gold_min: int = 3
@export var gold_max: int = 6
@export_range(0.0, 1.0) var item_drop_chance: float = 0.1
## ItemDB 의 장비 id 목록 (무기/방패). 드랍 시 이 중 하나가 무작위로 선택됩니다.
@export var item_drop_ids: Array[StringName] = []

const MIN_DAMAGE_RATIO := 0.2

var hp: int = 0
## 난이도 공격력 배율 (탄/장판 피해에 곱해짐)
var power: float = 1.0
## StageManager 가 지정. 크기가 0 이 아니면 이 영역 밖으로 밀려나지 않습니다.
var arena_rect: Rect2 = Rect2()

var _player: Player
var _knockback: Vector2 = Vector2.ZERO
var _touching_player: bool = false
var _dead: bool = false
var _hit_flash: float = 0.0
var _stun_left: float = 0.0
var _slow_left: float = 0.0
var _slow_multiplier: float = 1.0
var _aura: CPUParticles2D
var _anim_time: float = 0.0
## 공중에 떠 있으면 true → 활 공격만 맞음
var airborne: bool = false
## 맞힐 수 없는 공격이 닿았을 때 뜨는 문구 (모래 속에 숨은 스콜피언 등은 바꿔 씀)
var immune_text: String = "공중! 활만 닿음"
## 평소 색조 (오크킹의 함성으로 강화된 졸개는 붉게)
var base_tint: Color = Color.WHITE
var _immune_text_cooldown: float = 0.0
## 나를 소환해 지휘하는 적 (없으면 null)
var commander: Enemy
var _command: Command = Command.NONE
var _command_point: Vector2 = Vector2.ZERO
var _command_left: float = 0.0
var _command_elapsed: float = 0.0
var _command_dir: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var _hit_shape: CollisionShape2D = $CollisionShape2D


## 멀티플레이 참가자 화면의 그림자 복제본 (움직임은 방장이 보내 줌, 맞히면 방장에게 피해를 보냄)
var net_mirror: bool = false
## 멀티플레이: 가까운 용사로 목표를 다시 고르는 간격
const RETARGET_TIME := 1.5
var _retarget_left: float = 0.0


func _ready() -> void:
	net_mirror = has_meta(&"net_mirror")
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = 0 if net_mirror else Layers.PLAYER
	hp = max_hp
	_anim_time = randf() * 10.0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if aura_amount > 0:
		_aura = Fx.make_aura(Elements.color_of(aura_element), aura_amount, _aura_radius(), Elements.gravity_of(aura_element))
		_aura.position = _hit_shape.position
		_aura.z_index = 1
		add_child(_aura)
		_aura.emitting = true
	# 스폰 연출
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.25)


## 난이도 배율 적용 (StageManager 가 add_child 전에 호출). 체력은 여기서 딜 인플레 배율(Balance.K)도 곱함
func apply_difficulty(info: Dictionary) -> void:
	max_hp = roundi(max_hp * float(info["enemy_hp"])) * Balance.K
	defense += int(info.get("enemy_defense", 0))
	contact_damage = roundi(contact_damage * float(info["enemy_damage"]))
	power *= float(info["enemy_damage"])
	move_speed *= float(info["enemy_speed"])
	gold_min = roundi(gold_min * float(info["gold"]))
	gold_max = roundi(gold_max * float(info["gold"]))


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_ignite(delta)
	if _dead:
		return
	_anim_time += delta
	_retarget_left -= delta
	if _player == null or not is_instance_valid(_player) or _player.is_net_dead() or _retarget_left <= 0.0:
		_retarget_left = RETARGET_TIME
		_pick_target()

	_immune_text_cooldown = maxf(_immune_text_cooldown - delta, 0.0)
	_stun_left = maxf(_stun_left - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	var move := Vector2.ZERO
	if _stun_left <= 0.0:
		move = _get_command_velocity(delta) if _command != Command.NONE else _get_move_velocity(delta)
	if _slow_left > 0.0:
		move *= _slow_multiplier
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	global_position += (move + _knockback) * delta
	if arena_rect.has_area():
		global_position = global_position.clamp(arena_rect.position, arena_rect.end)

	if _touching_player and _stun_left <= 0.0 and not airborne and _player != null and is_instance_valid(_player):
		if _player.take_hit(contact_damage, get_hit_center(), self) == Player.HitResult.DAMAGED:
			if burn_damage > 0:
				_player.apply_burn(burn_damage, burn_duration, burn_is_poison)
			if death_mark_on_hit > 0:
				_player.add_death_mark(death_mark_on_hit)

	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if _hit_flash > 0.0:
		sprite.self_modulate = Color(3.0, 3.0, 3.0)
	elif _stun_left > 0.0:
		sprite.self_modulate = Color(0.6, 0.8, 1.6)  # 기절: 푸르스름하게
	elif _command != Command.NONE:
		sprite.self_modulate = Color(0.8, 1.45, 0.75)  # 지휘받는 중: 초록빛
	elif _slow_left > 0.0:
		sprite.self_modulate = Color(0.7, 0.95, 1.3)  # 빙결 감속
	else:
		sprite.self_modulate = base_tint
	_update_visual(delta, move)


## 자식 클래스에서 오버라이드: 이번 프레임의 이동 속도(px/s) 반환
func _get_move_velocity(_delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	return global_position.direction_to(_player.global_position) * move_speed


## 자식 클래스에서 오버라이드: 스프라이트 연출
func _update_visual(_delta: float, move: Vector2) -> void:
	if absf(move.x) > 1.0:
		sprite.flip_h = move.x < 0.0


func has_target() -> bool:
	return _player != null and is_instance_valid(_player) and not _player.is_net_dead()


## 목표 용사 고르기: 혼자면 그 용사, 멀티플레이면 살아 있는 용사 중 가까운 쪽 (지금 목표보다 확실히 가까울 때만 바꿈)
func _pick_target() -> void:
	var nearest := Player.find_nearest(get_tree(), global_position)
	if nearest == null:
		return
	if _player == null or not is_instance_valid(_player) or _player.is_net_dead():
		_player = nearest
	elif nearest != _player and nearest.global_position.distance_to(global_position) < _player.global_position.distance_to(global_position) * 0.7:
		_player = nearest


func is_dead() -> bool:
	return _dead


func is_stunned() -> bool:
	return _stun_left > 0.0


## 몸통 판정 중심 (근접 공격 각도 계산 / 가드 방향 판정용)
func get_hit_center() -> Vector2:
	return _hit_shape.global_position


## 빙결 등으로 감속 (보스는 넉백 저항만큼 덜 느려짐)
func apply_slow(multiplier: float, duration: float) -> void:
	if _dead:
		return
	if net_mirror:
		Net.forward_enemy_call(self, &"apply_slow", [multiplier, duration])
		return
	_slow_multiplier = lerpf(multiplier, 1.0, knockback_resistance * 0.5)
	_slow_left = maxf(_slow_left, duration)


func is_slowed() -> bool:
	return _slow_left > 0.0


func direction_to_player() -> Vector2:
	if not has_target():
		return Vector2.RIGHT
	return get_hit_center().direction_to(_player.global_position + Vector2(0, -4))


func distance_to_player() -> float:
	if not has_target():
		return INF
	return global_position.distance_to(_player.global_position)


## 적 탄 발사 (ProjectilePool 사용, 난이도 배율 적용)
func shoot(dir: Vector2, speed: float, damage: int, texture: Texture2D, slow: float = 0.0,
		element: Elements.Type = Elements.Type.NONE, from: Vector2 = Vector2.INF) -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var origin := get_hit_center() if from == Vector2.INF else from
	var spec := ProjectileSpec.enemy_bullet(origin, dir, speed, roundi(damage * power), texture, slow, element)
	spec.burn_damage = burn_damage
	spec.burn_duration = burn_duration
	spec.burn_poison = burn_is_poison
	spec.death_mark = death_mark_on_hit
	pool.spawn(spec)


## 용의 브레스: duration 초 동안 입(get_hit_center)에서 숨결 덩어리를 원뿔로 뿜음 — 덩어리는 날아가며 커지고 끝에서 흐려짐
## info: texture · damage · element · speed(150) · range(150) · cone(라디안, 0.5) · rate(초당 덩어리, 26) · duration(0.9)
##       sweep(뿜는 동안 휘두르는 각도, 0) · grow(끝에서 몇 배, 2.6) · slow(감속 초, 0) · scale(1.0) · track(플레이어를 따라 돌기, 0)
##       decay(부패 초 — 헬리시온, 0) · windup(뿜기 전 입에 기운이 모이는 시간, 0.3)
## 덩어리 하나하나가 보통 적 탄이라 가드 · 퍼펙트 가드 · 멀티플레이 복제가 그대로 됨
func breathe(aim: Vector2, info: Dictionary) -> void:
	var duration := float(info.get("duration", 0.9))
	var rate := float(info.get("rate", 26.0))
	var count := maxi(1, roundi(duration * rate))
	var state := {"dir": aim.normalized(), "i": 0}
	var sweep := float(info.get("sweep", 0.0))
	var track := float(info.get("track", 0.0))
	var puff := func() -> void:
		if _dead or not is_inside_tree():
			return
		var t := float(state["i"]) / maxf(count - 1, 1)
		state["i"] = int(state["i"]) + 1
		var dir: Vector2 = state["dir"]
		if track > 0.0 and has_target():
			# 플레이어 쪽으로 천천히 고개를 돌림 (한 덩어리마다 최대 track 라디안)
			var want := direction_to_player()
			dir = dir.rotated(clampf(dir.angle_to(want), -track, track))
			state["dir"] = dir
		var center := dir.rotated(sweep * (t - 0.5))
		var cone := float(info.get("cone", 0.5))
		_breath_puff(center.rotated(randf_range(-cone, cone) * 0.5), info)
	var tween := create_tween()
	var windup := float(info.get("windup", 0.3))
	if windup > 0.0:
		# 예고: 입에 기운이 모임 (피할 틈)
		var glow := Elements.color_of(info.get("element", Elements.Type.NONE)).lightened(0.3)
		Fx.flash(self, get_hit_center() + aim.normalized() * float(info.get("mouth", 10.0)), glow, 12.0, windup)
		Fx.burst(self, get_hit_center() + aim.normalized() * float(info.get("mouth", 10.0)), glow, 8, 30.0, windup, Vector2.ZERO, 0.8)
		tween.tween_interval(windup)
	for i in count:
		tween.tween_callback(puff)
		tween.tween_interval(1.0 / rate)


func _breath_puff(dir: Vector2, info: Dictionary) -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var element: Elements.Type = info.get("element", Elements.Type.NONE)
	var origin := get_hit_center() + dir * float(info.get("mouth", 10.0))
	var speed := float(info.get("speed", 150.0)) * randf_range(0.85, 1.15)
	var spec := ProjectileSpec.enemy_bullet(origin, dir, speed, roundi(int(info.get("damage", 30)) * power), info.get("texture") as Texture2D,
		float(info.get("slow", 0.0)), element)
	spec.max_distance = float(info.get("range", 150.0)) * randf_range(0.85, 1.1)
	spec.grow = float(info.get("grow", 2.6))
	spec.scale = float(info.get("scale", 1.0)) * randf_range(0.85, 1.15)
	spec.color = Color.WHITE  # 그림 색을 그대로 (속성 색을 덧칠하지 않음)
	spec.fx_level = 1
	spec.burn_damage = burn_damage
	spec.burn_duration = burn_duration
	spec.burn_poison = burn_is_poison
	spec.death_mark = death_mark_on_hit
	spec.decay_duration = float(info.get("decay", 0.0))
	pool.spawn(spec)


## 예고 후 폭발하는 장판 공격 (난이도 배율 적용)
func telegraph_strike(at_global: Vector2, radius: float, delay: float, damage: int,
		element: Elements.Type = Elements.Type.FIRE, slow: float = 0.0) -> AoeStrike:
	var strike := AoeStrike.spawn(self, at_global, radius, delay, roundi(damage * power), Elements.color_of(element), slow, Elements.gravity_of(element))
	if strike != null:
		strike.burn_damage = burn_damage
		strike.burn_duration = burn_duration
		strike.burn_poison = burn_is_poison
		strike.death_mark = death_mark_on_hit
	return strike


func _aura_radius() -> float:
	var circle := _hit_shape.shape as CircleShape2D
	return circle.radius if circle != null else 8.0


func apply_knockback(force: Vector2) -> void:
	if _dead:
		return
	if net_mirror:
		Net.forward_enemy_call(self, &"apply_knockback", [force])
		return
	_knockback += force * (1.0 - knockback_resistance)


# ============================================================ 원초의 불꽃: 용사의 공격에 맞으면 불탐
const IGNITE_TICK := 0.5
var _ignite_left: float = 0.0
var _ignite_damage: int = 0
var _ignite_timer: float = 0.0


## 용사의 공격이 맞은 뒤 호출 (근접 · 화살 · 마법 폭발). 원초의 불꽃이 켜져 있으면 그 일격 피해의 일정 비율로 불붙임
static func on_player_hit(enemy: Enemy, hit_damage: int) -> void:
	if enemy == null or enemy.is_dead() or hit_damage <= 0:
		return
	var ratio := GameManager.get_buff_value("burn_on_hit")
	if ratio > 0.0:
		enemy.ignite(maxi(1, roundi(hit_damage * ratio)), 4.0)


## duration 초 동안 0.5초마다 tick 피해 (방어력 무시) — 더 센 불이 붙으면 그쪽으로
func ignite(tick: int, duration: float) -> void:
	if _dead or tick <= 0:
		return
	if net_mirror:
		Net.forward_enemy_call(self, &"ignite", [tick, duration])
		return
	if _ignite_left <= 0.0:
		_ignite_timer = IGNITE_TICK
	_ignite_damage = maxi(_ignite_damage if _ignite_left > 0.0 else 0, tick)
	_ignite_left = maxf(_ignite_left, duration)


func is_ignited() -> bool:
	return _ignite_left > 0.0


func _tick_ignite(delta: float) -> void:
	if _ignite_left <= 0.0:
		return
	_ignite_left -= delta
	_ignite_timer -= delta
	if _ignite_timer <= 0.0:
		_ignite_timer += IGNITE_TICK
		if Engine.get_physics_frames() % 2 == 0:
			Fx.burst(self, get_hit_center(), Color(1.0, 0.5, 0.15), 4, 40.0, 0.4, Vector2(0, -60))
		take_damage(_ignite_damage, Vector2.ZERO, false, 99999999)
	if _ignite_left <= 0.0:
		_ignite_damage = 0


## 퍼펙트 가드 등으로 기절. 보스는 넉백 저항만큼 기절 시간이 줄어듭니다.
func stun(duration: float) -> void:
	if _dead:
		return
	if net_mirror:
		Net.forward_enemy_call(self, &"stun", [duration])
		return
	var actual := duration * (1.0 - knockback_resistance * 0.6)
	_stun_left = maxf(_stun_left, actual)
	FloatingText.spawn(self, global_position + Vector2(0, -20), "기절!", Color(0.6, 0.8, 1.0))


## 이 종류의 공격으로 맞힐 수 있는지 (공중에 뜨면 활만 가능)
func can_be_hit_by(kind: HitKind) -> bool:
	return not airborne or kind == HitKind.BOW


## 맞힐 수 없는 공격이 닿았을 때 안내 문구 (너무 자주 뜨지 않게)
func show_immune() -> void:
	if _immune_text_cooldown > 0.0 or _dead:
		return
	_immune_text_cooldown = 0.5
	FloatingText.spawn(self, global_position + Vector2(0, -34), immune_text, Color(0.75, 0.85, 1.0))


## 졸개 소환 요청 (보스 등 자식 클래스에서 사용)
func request_summon(scene: PackedScene, at_global: Vector2) -> void:
	summon_requested.emit(scene, at_global, self)


## StageManager 가 내가 소환한 졸개를 만들었을 때 호출 (지휘하는 보스가 오버라이드)
func register_minion(_minion: Enemy) -> void:
	pass


# ============================================================ 지휘 명령
## 지휘관이 명령을 내림. point: MOVE_TO 는 목표 지점, GUARD 는 지휘관 기준 오프셋
func give_command(command: Command, point: Vector2 = Vector2.ZERO, duration: float = 1.5) -> void:
	if _dead:
		return
	_command = command
	_command_point = point
	_command_left = duration
	_command_elapsed = 0.0
	_command_dir = Vector2.ZERO


func get_command() -> Command:
	return _command


func is_commanded() -> bool:
	return _command != Command.NONE


func _get_command_velocity(delta: float) -> Vector2:
	_command_left -= delta
	_command_elapsed += delta
	if _command_left <= 0.0:
		_command = Command.NONE
		return Vector2.ZERO
	match _command:
		Command.CHARGE:
			if _command_elapsed < COMMAND_CHARGE_WINDUP:
				return Vector2.ZERO  # 힘 모으기
			if _command_dir == Vector2.ZERO:
				_command_dir = direction_to_player()
			return _command_dir * maxf(move_speed * COMMAND_CHARGE_SPEED, COMMAND_MIN_CHARGE_SPEED)
		Command.MOVE_TO:
			var to_point := _command_point - global_position
			if to_point.length() < 3.0:
				return Vector2.ZERO
			return to_point.normalized() * minf(maxf(move_speed * COMMAND_MOVE_SPEED, COMMAND_MIN_MOVE_SPEED), to_point.length() / maxf(delta, 0.001))
		Command.GUARD:
			if commander == null or not is_instance_valid(commander) or commander.is_dead():
				_command = Command.NONE
				return Vector2.ZERO
			var to_post := commander.global_position + _command_point - global_position
			if to_post.length() < 3.0:
				return Vector2.ZERO
			return to_post.normalized() * minf(maxf(move_speed * COMMAND_MOVE_SPEED, COMMAND_GUARD_SPEED), to_post.length() / maxf(delta, 0.001))
	return Vector2.ZERO


## 실제 방어력 (defense 는 예전 단위 — 기믹의 방어력 ± 도 그대로 Balance.K 배)
func get_defense_value() -> int:
	return maxi(defense, 0) * Balance.K


## 방어력 관통을 반영해 실제로 들어갈 피해 계산
func calc_damage(amount: int, armor_pen: int = 0) -> int:
	if amount <= 0:
		return 0
	var effective_defense := maxi(get_defense_value() - maxi(armor_pen, 0), 0)
	return maxi(amount - effective_defense, maxi(ceili(amount * MIN_DAMAGE_RATIO), 1))


## 용사의 공격이 적에게 닿을 때는 이 함수로 — 멀티플레이 참가자 화면의 복제본이면 방장에게 보내서 진짜 적이 맞음
static func hit(enemy: Enemy, amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if enemy == null or enemy.is_dead():
		return
	if enemy.net_mirror:
		Net.forward_enemy_call(enemy, &"take_damage", [amount, knockback, is_crit, armor_pen])
		return
	enemy.take_damage(amount, knockback, is_crit, armor_pen)


## amount 는 방어력 적용 전 피해. armor_pen 만큼 방어력을 무시합니다.
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _dead or amount <= 0:
		return
	amount = calc_damage(amount, armor_pen)
	hp = maxi(hp - amount, 0)
	_knockback += knockback * (1.0 - knockback_resistance)
	_hit_flash = 0.12
	health_changed.emit(hp, max_hp)

	var color := Color(1.0, 0.85, 0.3) if is_crit else Color.WHITE
	FloatingText.spawn(self, global_position + Vector2(0, -12), str(amount) + ("!" if is_crit else ""), color, is_crit)

	if hp == 0:
		_die()


## 드랍/시그널 없이 조용히 제거 (스테이지 정리용)
func despawn() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group(&"enemies")
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _die() -> void:
	_dead = true
	remove_from_group(&"enemies")
	if _aura != null:
		_aura.emitting = false
	# 충돌 콜백 안에서 호출될 수 있으므로 반드시 deferred
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	died.emit(self)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.6, 0.2), 0.18)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_touching_player = true
		_player = body as Player


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_touching_player = false
