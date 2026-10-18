class_name BossVoidWorm
extends PatternBoss
## 28스테이지 보스: 공허의 포식자 보이드 웜 — 차원의 틈을 갉아먹으며 자라는 거대한 공허 지렁이.
##   SPIT   : 공허 토사물 — 공허탄 부채꼴
##   SLAM   : 몸통 내려치기 — 몸 주위 고리 장판
##   SUMMON : 공허 유충 · 균열 짐승 호출 (나중에 잡아먹음)
##   DEVOUR : 포식 — 주변 잡몹을 집어삼킴
##
## [기믹] 삼키기 (swallow_interval 마다):
##   1) 땅속으로 파고들어 플레이어를 쫓음 (땅속에 있는 동안 공격이 닿지 않음)
##   2) 플레이어 발밑에 거대한 입 예고 → 그때 원 안에 있으면(대시 중이 아니면) 삼켜짐
##   3) 삼켜지면 움직일 수 없고(공격은 가능) 0.5초마다 최대 체력의 digest_ratio 피해
##      → 눈앞의 「위벽」(체력 따로)을 부수면 탈출, 웜은 속이 터져 큰 피해 + 기절
##      → digest_time 안에 못 부수면 그대로 뱉어냄
## [기믹] 포식 성장: 포식으로 잡몹을 삼킬 때마다 몸이 커지고 공격력 +10% (최대 5단계) + 조금 회복
##   → 잡몹을 빨리 정리할수록 덜 위험
## 체력 50% 이하: 더 자주 삼키려 함

enum Pattern { SPIT, SLAM, SUMMON, DEVOUR }
enum Swallow { NONE, BURROW, MOUTH, INSIDE }

const MAX_GROWTH := 5

@export var wall_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var bolt_texture: Texture2D
@export var spit_damage: int = 40
@export var slam_damage: int = 66
@export var mouth_damage: int = 40
@export var swallow_interval: float = 16.0
@export var burrow_time: float = 3.0
@export var mouth_warn: float = 1.0
@export var mouth_radius: float = 34.0
@export var digest_time: float = 8.0
@export var digest_ratio: float = 0.04
@export var wall_hp_ratio: float = 0.03
@export var burst_damage_ratio: float = 0.05
@export var devour_range: float = 140.0

var growth: int = 0
var _swallow: Swallow = Swallow.NONE
var _swallow_left: float = 0.0
var _swallow_cooldown: float = 7.0
var _mouth_at: Vector2 = Vector2.ZERO
var _digest_tick: float = 0.0
var _wall: BossPart
var _swallows: int = 0
var _escapes: int = 0
var _base_power: float = 1.0
var _base_scale: Vector2
var _base_contact: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPIT, Pattern.SUMMON, Pattern.SLAM, Pattern.DEVOUR, Pattern.SPIT, Pattern.SLAM, Pattern.DEVOUR]
	immune_text = "땅속! 공격 안 닿음"
	_base_scale = sprite.scale
	_base_contact = contact_damage


func get_swallow_state() -> Swallow:
	return _swallow


func is_player_inside() -> bool:
	return _swallow == Swallow.INSIDE


func get_wall() -> BossPart:
	return _wall if _wall != null and is_instance_valid(_wall) and not _wall.is_dead() else null


func get_swallow_count() -> int:
	return _swallows


func get_escape_count() -> int:
	return _escapes


func can_be_hit_by(kind: HitKind) -> bool:
	return _swallow != Swallow.BURROW and _swallow != Swallow.MOUTH and super.can_be_hit_by(kind)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _swallow == Swallow.BURROW or _swallow == Swallow.MOUTH:
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func _get_move_velocity(delta: float) -> Vector2:
	match _swallow:
		Swallow.BURROW:
			return _burrow_velocity(delta)
		Swallow.MOUTH:
			_swallow_left -= delta
			if _swallow_left <= 0.0:
				_bite()
			return Vector2.ZERO
		Swallow.INSIDE:
			_digest(delta)
			return Vector2.ZERO
	if has_target():
		_swallow_cooldown -= delta
		if _swallow_cooldown <= 0.0 and not is_casting():
			begin_swallow()
			return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 삼키기
func begin_swallow() -> void:
	if _swallow != Swallow.NONE or is_dead() or not has_target():
		return
	_swallow = Swallow.BURROW
	_swallow_left = burrow_time
	_swallow_cooldown = swallow_interval * (0.75 if phase_two else 1.0)
	sprite.hide()
	contact_damage = 0
	set_status("땅속으로 파고들었다…", Color(0.8, 0.6, 1.0))
	Fx.burst(self, global_position, Color(0.5, 0.35, 0.6), 22, 70.0, 0.5, Vector2(0, 60), 1.4)


func _burrow_velocity(delta: float) -> Vector2:
	_swallow_left -= delta
	if Engine.get_physics_frames() % 6 == 0:
		Fx.burst(self, global_position, Color(0.45, 0.3, 0.55), 3, 30.0, 0.3)
	if _swallow_left <= 0.0:
		_open_mouth()
		return Vector2.ZERO
	return global_position.direction_to(_player.global_position) * move_speed * 1.8 if has_target() else Vector2.ZERO


func _open_mouth() -> void:
	_swallow = Swallow.MOUTH
	_swallow_left = mouth_warn
	_mouth_at = _player.global_position if has_target() else global_position
	global_position = _mouth_at
	var strike := telegraph_strike(_mouth_at, mouth_radius, mouth_warn, mouth_damage, Elements.Type.DARK)
	if strike != null:
		strike.color = Color(0.7, 0.3, 1.0)
	set_status("발밑에 거대한 입이 열린다 — 피하라!", Color(0.9, 0.5, 1.0))


func _bite() -> void:
	sprite.show()
	contact_damage = _base_contact
	Fx.explosion(self, _mouth_at, Color(0.6, 0.3, 0.8), 40.0, 2, Vector2(0, 120))
	if has_target() and _player.global_position.distance_to(_mouth_at) <= mouth_radius + 4.0 and not _player.is_dashing():
		_swallowed()
		return
	_swallow = Swallow.NONE
	set_status("", Color.WHITE)


func _swallowed() -> void:
	_swallow = Swallow.INSIDE
	_swallows += 1
	_swallow_left = digest_time
	_digest_tick = 0.5
	_player.global_position = global_position + Vector2(0, 2)
	_player.apply_root(digest_time + 0.5, "삼켜짐! 위벽을 공격해 탈출하라")
	set_status("삼켰다… 소화 중", Color(0.9, 0.5, 1.0))
	GameManager.show_notice("보이드 웜에게 삼켜졌다! 눈앞의 위벽을 부숴 탈출하라", Color(0.9, 0.5, 1.0))
	if wall_scene != null:
		request_summon(wall_scene, global_position + Vector2(0, -26))


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and _swallow == Swallow.INSIDE:
		_wall = minion as BossPart
		_wall.boss = self
		_wall.follow_boss = false
		_wall.max_hp = maxi(1, roundi(max_hp * wall_hp_ratio))
		_wall.died.connect(_on_wall_broken)


func _digest(delta: float) -> void:
	_swallow_left -= delta
	if has_target():
		_player.global_position = global_position + Vector2(0, 2)
		_digest_tick -= delta
		if _digest_tick <= 0.0:
			_digest_tick = 0.5
			_player.take_unblockable_hit(maxi(1, roundi(GameManager.max_hp * digest_ratio)), global_position, false)
	if _swallow_left <= 0.0:
		_spit_out(false)


func _on_wall_broken(_enemy: Enemy) -> void:
	if _swallow != Swallow.INSIDE or is_dead():
		return
	_escapes += 1
	super.take_damage(maxi(1, roundi(max_hp * burst_damage_ratio)), Vector2.ZERO, true, 999999)
	_spit_out(true)


func _spit_out(escaped: bool) -> void:
	_swallow = Swallow.NONE
	if get_wall() != null:
		_wall.despawn()
	_wall = null
	if has_target():
		_player.release_root()
		_player.global_position = global_position + Vector2(0, 46)
		_player.velocity = Vector2(0, 220)
	if escaped:
		set_status("속이 터졌다!", Color(1.0, 0.7, 0.9))
		GameManager.show_notice("위벽을 부수고 탈출했다! 보이드 웜이 비틀거린다", Color(1.0, 0.8, 0.95))
		stun(2.5)
	else:
		set_status("", Color.WHITE)
	_after(1.5, func() -> void:
		if _swallow == Swallow.NONE and get_status_text() == "속이 터졌다!":
			set_status("", Color.WHITE))


# ============================================================ 기믹: 포식 성장
## 주변 잡몹을 삼킴 → 성장 (테스트에서도 직접 호출). 삼킨 수를 돌려줌
func devour() -> int:
	var eaten := 0
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var e := node as Enemy
		if e == null or e == self or e.is_boss or e is BossPart or e.is_dead():
			continue
		if e.global_position.distance_to(global_position) > devour_range:
			continue
		Fx.burst(self, e.get_hit_center(), Color(0.6, 0.3, 0.8), 10, 50.0, 0.35)
		e.despawn()
		eaten += 1
		if growth < MAX_GROWTH:
			growth += 1
		var heal := mini(roundi(max_hp * 0.01), max_hp - hp)
		hp += heal
		health_changed.emit(hp, max_hp)
	if eaten > 0:
		power = _base_power * (1.0 + 0.1 * growth)
		sprite.scale = _base_scale * (1.0 + 0.08 * growth)
		set_status("포식! 성장 %d단계 (공격력 +%d%%)" % [growth, growth * 10], Color(0.9, 0.5, 1.0))
		_after(1.5, func() -> void:
			if get_status_text().begins_with("포식"):
				set_status("", Color.WHITE))
	return eaten


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.SPIT:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.16), 140.0, spit_damage, bolt_texture, 0.0, Elements.Type.DARK)
			return 1.0
		Pattern.SLAM:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 54.0, 20.0, 0.9, slam_damage, Elements.Type.DARK)
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 3:
					request_summon(minion_scenes.pick_random(), global_position + Vector2.from_angle(TAU * i / 3.0) * 60.0)
			return 1.0
		Pattern.DEVOUR:
			if devour() == 0:
				return _run_pattern(Pattern.SPIT)
			return 1.0
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("보이드 웜이 굶주림에 몸부림친다! 더 자주 삼키려 든다", Color(0.9, 0.5, 1.0))
