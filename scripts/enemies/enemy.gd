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
## - 원거리/장판 공격은 shoot() / telegraph_strike() 헬퍼를 쓰면 풀·이펙트·강화 배율이 자동 적용됩니다.

signal died(enemy: Enemy)
signal health_changed(current: int, max_hp: int)
## 보스가 졸개를 소환할 때 사용 (StageManager 가 받아서 스폰)
signal summon_requested(scene: PackedScene, at_global: Vector2)

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

@export_group("Drops")
@export var gold_min: int = 3
@export var gold_max: int = 6
@export_range(0.0, 1.0) var item_drop_chance: float = 0.1
## ItemDB 의 장비 id 목록 (무기/방패). 드랍 시 이 중 하나가 무작위로 선택됩니다.
@export var item_drop_ids: Array[StringName] = []

const MIN_DAMAGE_RATIO := 0.2

var hp: int = 0
## 반복 스테이지 강화 배율 (탄/장판 피해에 곱해짐)
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

@onready var sprite: Sprite2D = $Sprite2D
@onready var _hit_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.PLAYER
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


## StageManager 가 add_child 전에 호출.
## 스테이지별 몬스터는 각자 씬에서 수치가 설계되어 있으므로, level 은
## "마지막 스테이지를 몇 바퀴째 반복 중인지" 입니다 (0 = 강화 없음).
func apply_scaling(level: int) -> void:
	level = maxi(level, 0)
	max_hp = roundi(max_hp * (1.0 + 0.5 * level))
	defense += 2 * level
	contact_damage = roundi(contact_damage * (1.0 + 0.25 * level))
	gold_min = roundi(gold_min * (1.0 + 0.3 * level))
	gold_max = roundi(gold_max * (1.0 + 0.3 * level))
	move_speed *= 1.0 + 0.05 * level
	power = 1.0 + 0.25 * level


## 난이도 배율 적용 (StageManager 가 add_child 전에 호출)
func apply_difficulty(info: Dictionary) -> void:
	max_hp = roundi(max_hp * float(info["enemy_hp"]))
	defense += int(info.get("enemy_defense", 0))
	contact_damage = roundi(contact_damage * float(info["enemy_damage"]))
	power *= float(info["enemy_damage"])
	move_speed *= float(info["enemy_speed"])
	gold_min = roundi(gold_min * float(info["gold"]))
	gold_max = roundi(gold_max * float(info["gold"]))


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_anim_time += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player

	_stun_left = maxf(_stun_left - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	var move := Vector2.ZERO if _stun_left > 0.0 else _get_move_velocity(delta)
	if _slow_left > 0.0:
		move *= _slow_multiplier
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	global_position += (move + _knockback) * delta
	if arena_rect.has_area():
		global_position = global_position.clamp(arena_rect.position, arena_rect.end)

	if _touching_player and _stun_left <= 0.0 and _player != null and is_instance_valid(_player):
		_player.take_hit(contact_damage, get_hit_center(), self)

	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if _hit_flash > 0.0:
		sprite.self_modulate = Color(3.0, 3.0, 3.0)
	elif _stun_left > 0.0:
		sprite.self_modulate = Color(0.6, 0.8, 1.6)  # 기절: 푸르스름하게
	elif _slow_left > 0.0:
		sprite.self_modulate = Color(0.7, 0.95, 1.3)  # 빙결 감속
	else:
		sprite.self_modulate = Color.WHITE
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
	return _player != null and is_instance_valid(_player) and not GameManager.is_player_dead


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


## 적 탄 발사 (ProjectilePool 사용, 반복 강화 배율 적용)
func shoot(dir: Vector2, speed: float, damage: int, texture: Texture2D, slow: float = 0.0,
		element: Elements.Type = Elements.Type.NONE, from: Vector2 = Vector2.INF) -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var origin := get_hit_center() if from == Vector2.INF else from
	pool.spawn(ProjectileSpec.enemy_bullet(origin, dir, speed, roundi(damage * power), texture, slow, element))


## 예고 후 폭발하는 장판 공격 (반복 강화 배율 적용)
func telegraph_strike(at_global: Vector2, radius: float, delay: float, damage: int,
		element: Elements.Type = Elements.Type.FIRE, slow: float = 0.0) -> AoeStrike:
	return AoeStrike.spawn(self, at_global, radius, delay, roundi(damage * power), Elements.color_of(element), slow, Elements.gravity_of(element))


func _aura_radius() -> float:
	var circle := _hit_shape.shape as CircleShape2D
	return circle.radius if circle != null else 8.0


func apply_knockback(force: Vector2) -> void:
	if _dead:
		return
	_knockback += force * (1.0 - knockback_resistance)


## 퍼펙트 가드 등으로 기절. 보스는 넉백 저항만큼 기절 시간이 줄어듭니다.
func stun(duration: float) -> void:
	if _dead:
		return
	var actual := duration * (1.0 - knockback_resistance * 0.6)
	_stun_left = maxf(_stun_left, actual)
	FloatingText.spawn(self, global_position + Vector2(0, -20), "기절!", Color(0.6, 0.8, 1.0))


## 졸개 소환 요청 (보스 등 자식 클래스에서 사용)
func request_summon(scene: PackedScene, at_global: Vector2) -> void:
	summon_requested.emit(scene, at_global)


## 방어력 관통을 반영해 실제로 들어갈 피해 계산
func calc_damage(amount: int, armor_pen: int = 0) -> int:
	if amount <= 0:
		return 0
	var effective_defense := maxi(defense - maxi(armor_pen, 0), 0)
	return maxi(amount - effective_defense, maxi(ceili(amount * MIN_DAMAGE_RATIO), 1))


## amount 는 방어력 적용 전 피해. armor_pen 만큼 방어력을 무시합니다.
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _dead or amount <= 0:
		return
	amount = calc_damage(amount, armor_pen)
	hp = maxi(hp - amount, 0)
	_knockback += knockback * (1.0 - knockback_resistance)
	_hit_flash = 0.08
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
