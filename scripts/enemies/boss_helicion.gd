class_name BossHelicion
extends PatternBoss
## 35스테이지 보스: 언데드 드래곤 헬리시온 — 용의 묘지에서 되살아난 뼈의 용.
##   DECAY  : 부패의 숨결 — 부패탄 부채꼴 (맞으면 「부패」: 포션 회복 불가)
##   BONES  : 뼈 창 — 사방으로 퍼지는 뼈 창 두 겹
##   CURSE  : 저주의 땅 — 플레이어 주변 장판 (맞으면 부패)
##   SUMMON : 해골 용병 · 구울 · 원혼 호출 (망자 부활)
##
## [기믹 1] 불사: 체력이 0 이 되면 죽지 않고 뼈더미로 무너지며 「영혼」(체력 따로)이 빠져나옴
##   영혼은 soul_time 초에 걸쳐 천천히 뼈더미로 돌아감 → 그 전에 영혼을 부수면 진짜로 죽음
##   돌아가면 최대 체력의 revive_ratio 로 되살아남 (영혼은 되살아날 때마다 더 단단해짐)
## [기믹 2] 부패: 부패탄·저주의 땅에 맞으면 decay_time 초 동안 포션으로 회복할 수 없음
## 체력 50% 이하: 숨결이 더 넓고 망자를 더 많이 부름

enum Pattern { DECAY, BONES, CURSE, SUMMON }

@export var soul_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var decay_texture: Texture2D
@export var bone_texture: Texture2D
@export var decay_damage: int = 46
@export var bone_damage: int = 52
@export var curse_damage: int = 70
@export var decay_time: float = 6.0
@export var soul_time: float = 9.0
@export var revive_ratio: float = 0.4
@export var soul_hp_ratio: float = 0.04

var _fallen: bool = false
var _soul: BossPart
var _soul_left: float = 0.0
var _soul_start: Vector2
var _revives: int = 0
var _soul_broken: bool = false
var _base_contact: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.DECAY, Pattern.BONES, Pattern.CURSE, Pattern.SUMMON, Pattern.DECAY, Pattern.BONES]
	_base_contact = contact_damage


func is_fallen() -> bool:
	return _fallen


func get_soul() -> BossPart:
	return _soul if _soul != null and is_instance_valid(_soul) and not _soul.is_dead() else null


func get_revive_count() -> int:
	return _revives


func can_be_hit_by(kind: HitKind) -> bool:
	return not _fallen and super.can_be_hit_by(kind)


func _get_move_velocity(delta: float) -> Vector2:
	if _fallen:
		_update_soul(delta)
		return Vector2.ZERO
	return super._get_move_velocity(delta)


# ============================================================ 기믹 1: 불사
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_dead() or amount <= 0:
		return
	if _fallen:
		show_immune()
		return
	if calc_damage(amount, armor_pen) >= hp and not _soul_broken:
		hp = 0
		health_changed.emit(hp, max_hp)
		FloatingText.spawn(self, global_position + Vector2(0, -12), str(calc_damage(amount, armor_pen)), Color.WHITE)
		_fall()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _fall() -> void:
	_fallen = true
	contact_damage = 0
	_bstate = BossState.CHASE
	_btimer = chase_time
	base_tint = Color(0.55, 0.55, 0.6)
	sprite.rotation = 0.35
	immune_text = "뼈더미 — 빠져나온 영혼을 부숴라!"
	set_status("뼈더미… 영혼이 돌아오려 한다", Color(0.7, 1.0, 0.8))
	_soul_left = soul_time
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(300, 180), Vector2(600, 360))
	_soul_start = global_position + Vector2.from_angle(randf() * TAU) * 150.0
	_soul_start = _soul_start.clamp(area.position + Vector2(30, 30), area.end - Vector2(30, 20))
	if soul_scene != null:
		request_summon(soul_scene, _soul_start)
	GameManager.show_notice("헬리시온이 무너졌다… 영혼이 빠져나왔다! %d초 안에 영혼을 부숴라" % roundi(soul_time), Color(0.7, 1.0, 0.8))


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and _fallen and get_soul() == null:
		_soul = minion as BossPart
		_soul.boss = self
		_soul.follow_boss = false
		_soul.max_hp = maxi(1, roundi(max_hp * soul_hp_ratio * (1.0 + 0.5 * _revives)))
		_soul.died.connect(_on_soul_broken)


func _update_soul(delta: float) -> void:
	_soul_left -= delta
	set_status("영혼이 돌아오기까지 %.1f초" % maxf(_soul_left, 0.0), Color(0.7, 1.0, 0.8))
	var soul := get_soul()
	if soul != null:
		var t := clampf(1.0 - _soul_left / soul_time, 0.0, 1.0)
		soul.global_position = _soul_start.lerp(get_hit_center(), t * t)
	if _soul_left <= 0.0:
		_revive()


func _on_soul_broken(_enemy: Enemy) -> void:
	if not _fallen or is_dead():
		return
	_soul_broken = true
	_soul = null
	GameManager.show_notice("영혼을 부쉈다! 헬리시온이 영원한 잠에 든다", Color(0.8, 1.0, 0.85))
	_die()


func _revive() -> void:
	_fallen = false
	_revives += 1
	if get_soul() != null:
		_soul.despawn()
	_soul = null
	hp = maxi(1, roundi(max_hp * revive_ratio))
	health_changed.emit(hp, max_hp)
	contact_damage = _base_contact
	base_tint = Color.WHITE
	sprite.rotation = 0.0
	immune_text = "공중! 활만 닿음"
	set_status("", Color.WHITE)
	GameManager.show_notice("영혼이 돌아왔다! 헬리시온이 다시 일어선다 (체력 %d%%)" % roundi(revive_ratio * 100.0), Color(0.6, 1.0, 0.7))
	Fx.burst(self, get_hit_center(), Color(0.5, 1.0, 0.6), 30, 80.0, 0.6)
	for i in 3:
		if not minion_scenes.is_empty():
			request_summon(minion_scenes.pick_random(), global_position + Vector2.from_angle(TAU * i / 3.0) * 60.0)


# ============================================================ 패턴
func _shoot_decay(dir: Vector2, speed: float) -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var spec := ProjectileSpec.enemy_bullet(get_hit_center(), dir, speed, roundi(decay_damage * power), decay_texture, 0.0, Elements.Type.DARK)
	spec.decay_duration = decay_time
	pool.spawn(spec)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.DECAY:
			var aim := direction_to_player()
			var count := 9 if phase_two else 7
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead() or _fallen:
						return
					for i in count:
						_shoot_decay(aim.rotated((i - (count - 1) * 0.5) * 0.16 + w * 0.08), 125.0))
			return 1.1
		Pattern.BONES:
			for w in 2:
				_after(0.35 * w, func() -> void:
					if is_dead() or _fallen:
						return
					for i in 14:
						shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 115.0, bone_damage, bone_texture, 0.0, Elements.Type.DARK))
			return 1.1
		Pattern.CURSE:
			for i in 6:
				var at := _player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(28.0, 90.0))
				var strike := telegraph_strike(at, 20.0, 0.85 + 0.08 * i, curse_damage, Elements.Type.DARK)
				if strike != null:
					strike.color = Color(0.45, 0.85, 0.5)
					strike.decay_duration = decay_time
			return 1.4
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in (3 if phase_two else 2):
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 60.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("헬리시온: 죽음은 끝이 아니다… 망자들이 깨어난다", Color(0.6, 1.0, 0.7))
