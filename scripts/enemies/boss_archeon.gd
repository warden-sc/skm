class_name BossArcheon
extends Enemy
## 3스테이지 보스: 원소의 거신 아르케온 (Archeon, the Elemental Colossus)
##
## 고대 유적을 지키는 거대 골렘. 몸에 박힌 4개의 원소 핵(화염·빙결·뇌전·대지)이 주위를 돌며,
## 활성화된 핵의 속성에 따라 공격이 바뀝니다. 속성은 화염 → 빙결 → 뇌전 → 대지 순으로 순환합니다.
##   화염 : 회전하는 화염구 고리 3연발
##   빙결 : 나선형 얼음 파편 (맞으면 감속)
##   뇌전 : 플레이어 주변에 시간차 낙뢰 6발
##   대지 : 자기 주변 대지 붕괴(거대 장판) + 돌 파편 고리
## 체력 50% 이하 「원소 융합」: 두 속성을 동시에 사용, 속성 골렘 소환
##
## [기믹] 원소 강화: 활성 핵의 속성에 따라 아르케온 자신에게 능력이 붙습니다 (머리 위에 표시).
##   화염 「작열」      : 모든 공격(몸통·탄)에 맞으면 화상
##   빙결 「얼음 보호막」: 최대 체력의 일정 비율만큼 피해를 먼저 흡수하는 보호막 (깨면 사라짐)
##   뇌전 「뇌신」      : 이동 속도 대폭 증가 + 플레이어 근처로 순간이동
##   대지 「대지의 갑주」: 방어력 대폭 증가 → 방깍이 높은 활·팔찌나, 다른 속성으로 바뀔 때를 노리세요

enum State { CHASE, CASTING }

const CYCLE: Array[Elements.Type] = [Elements.Type.FIRE, Elements.Type.ICE, Elements.Type.LIGHTNING, Elements.Type.EARTH]
const CORE_ORBIT_RADIUS := 26.0

@export var fireball_texture: Texture2D
@export var ice_texture: Texture2D
@export var rock_texture: Texture2D
@export var attack_damage: int = 20
@export var chase_time: float = 2.2
## CYCLE 과 같은 순서의 속성 골렘 씬 (원소 융합 단계에서 소환)
@export var minion_scenes: Array[PackedScene] = []

@export_group("Element Buffs")
## 화염 「작열」: 화상 (0.5초마다 피해)
@export var fire_burn_damage: int = 5
## 빙결 「얼음 보호막」: 최대 체력 대비 보호막 크기
@export var ice_shield_ratio: float = 0.06
## 뇌전 「뇌신」: 이동 속도 배율
@export var lightning_speed_multiplier: float = 2.0
## 대지 「대지의 갑주」: 추가 방어력
@export var earth_defense_bonus: int = 15

var _state: State = State.CHASE
var _state_timer: float = 0.0
var _cycle_index: int = 0
var _phase_two: bool = false
var _cores: Array[Sprite2D] = []
var _base_sprite_pos: Vector2
var _base_defense: int = 0
var _base_speed: float = 0.0
## 빙결 「얼음 보호막」 남은 양
var ice_shield: int = 0
var _shield_ring: Sprite2D
var _buff_label: Label


func _ready() -> void:
	super._ready()
	is_boss = true
	_base_sprite_pos = sprite.position
	_state_timer = chase_time
	for element in CYCLE:
		var core := Sprite2D.new()
		core.texture = Fx.GLOW_TEXTURE
		core.material = Fx.additive_material()
		core.modulate = Elements.color_of(element)
		core.scale = Vector2.ONE * 0.35
		core.z_index = 2
		add_child(core)
		_cores.append(core)
	_base_defense = defense
	_base_speed = move_speed
	_shield_ring = Sprite2D.new()
	_shield_ring.texture = Fx.RING_TEXTURE
	_shield_ring.material = Fx.additive_material()
	_shield_ring.modulate = Color(0.6, 0.9, 1.0, 0.85)
	_shield_ring.position = get_hit_center() - global_position
	_shield_ring.scale = Vector2.ONE * 2.6
	_shield_ring.z_index = 3
	_shield_ring.hide()
	add_child(_shield_ring)
	_buff_label = Label.new()
	_buff_label.add_theme_font_size_override(&"font_size", 9)
	_buff_label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.1))
	_buff_label.add_theme_constant_override(&"outline_size", 4)
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buff_label.position = Vector2(-60, -66)
	_buff_label.size = Vector2(120, 12)
	_buff_label.z_index = 70
	add_child(_buff_label)
	apply_element_buff(get_current_element())


func get_current_element() -> Elements.Type:
	return CYCLE[_cycle_index % CYCLE.size()]


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_state_timer -= delta
	match _state:
		State.CHASE:
			if _state_timer <= 0.0:
				_cast_cycle()
				return Vector2.ZERO
			return global_position.direction_to(_player.global_position) * move_speed
		State.CASTING:
			if _state_timer <= 0.0:
				_cycle_index += 1
				_set_aura(get_current_element())
				apply_element_buff(get_current_element())
				_state = State.CHASE
				_state_timer = chase_time * (0.65 if _phase_two else 1.0)
			return Vector2.ZERO
	return Vector2.ZERO


## [기믹] 활성 속성에 맞는 능력 부여 (이전 속성의 능력은 사라짐)
func apply_element_buff(element: Elements.Type) -> void:
	defense = _base_defense
	move_speed = _base_speed
	burn_damage = 0
	ice_shield = 0
	var text := ""
	match element:
		Elements.Type.FIRE:
			burn_damage = fire_burn_damage
			burn_duration = 3.0
			text = "작열: 공격에 화상"
		Elements.Type.ICE:
			ice_shield = roundi(max_hp * ice_shield_ratio)
			text = "얼음 보호막 %d" % ice_shield
		Elements.Type.LIGHTNING:
			move_speed = _base_speed * lightning_speed_multiplier
			text = "뇌신: 이동 속도 x%.1f" % lightning_speed_multiplier
			_blink_near_player()
		Elements.Type.EARTH:
			defense = _base_defense + earth_defense_bonus
			text = "대지의 갑주: 방어력 +%d" % Balance.scale(earth_defense_bonus)
	_buff_label.text = text
	_buff_label.add_theme_color_override(&"font_color", Elements.color_of(element).lightened(0.2))
	_shield_ring.visible = ice_shield > 0
	Fx.shockwave(self, get_hit_center(), Elements.color_of(element), 46.0, 0.35)


func get_buff_text() -> String:
	return _buff_label.text


## 뇌전: 번개처럼 플레이어 근처로 순간이동
func _blink_near_player() -> void:
	if not has_target() or not is_inside_tree():
		return
	var to := _player.global_position + Vector2.from_angle(randf() * TAU) * 80.0
	if arena_rect.has_area():
		to = to.clamp(arena_rect.position, arena_rect.end)
	Fx.flash(self, get_hit_center(), Elements.color_of(Elements.Type.LIGHTNING), 40.0, 0.25)
	global_position = to
	Fx.explosion(self, get_hit_center(), Elements.color_of(Elements.Type.LIGHTNING), 36.0, 2)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if ice_shield > 0 and not is_dead() and amount > 0:
		# 얼음 보호막이 방어력 적용 후 피해를 먼저 흡수
		var dealt := calc_damage(amount, armor_pen)
		var absorbed := mini(ice_shield, dealt)
		ice_shield -= absorbed
		_buff_label.text = "얼음 보호막 %d" % ice_shield if ice_shield > 0 else "보호막 파괴!"
		FloatingText.spawn(self, global_position + Vector2(0, -30), "-%d 보호막" % absorbed, Color(0.6, 0.9, 1.0))
		if ice_shield <= 0:
			_shield_ring.hide()
			Fx.flying_sprites(self, get_hit_center(), Fx.ICE_SHARD_TEXTURE, 12, 40.0, Color(0.7, 0.95, 1.0))
		var left := dealt - absorbed
		if left <= 0:
			return
		amount = left
		armor_pen = 9999  # 이미 방어력을 적용한 피해
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if not _phase_two and not is_dead() and float(hp) <= max_hp * 0.5:
		_phase_two = true
		GameManager.show_notice("원소 융합 — 아르케온의 핵이 폭주한다!", Color(0.8, 0.6, 1.0))
		for element in CYCLE:
			Fx.explosion(self, get_hit_center(), Elements.color_of(element), 50.0 + 15.0 * CYCLE.find(element), 3)
		if _player != null:
			_player.shake_camera(6.0)


func _cast_cycle() -> void:
	var element := get_current_element()
	var duration := _cast_element(element)
	if _phase_two:
		var second: Elements.Type = CYCLE[(_cycle_index + 2) % CYCLE.size()]
		duration = maxf(duration, _cast_element(second))
		if _cycle_index % 2 == 1:
			_summon_golem(element)
	_state = State.CASTING
	_state_timer = duration
	Fx.flash(self, get_hit_center(), Elements.color_of(element), 40.0, 0.3)


## 속성 공격 시전. 반환값 = 시전에 걸리는 시간
func _cast_element(element: Elements.Type) -> float:
	match element:
		Elements.Type.FIRE:
			for wave in 3:
				_after(0.3 * wave, _fire_ring.bind(wave))
			return 1.2
		Elements.Type.ICE:
			for i in 24:
				_after(0.05 * i, _ice_shard.bind(i))
			return 1.5
		Elements.Type.LIGHTNING:
			if _player != null:
				for i in 6:
					var offset := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0)
					telegraph_strike(_player.global_position + offset, 22.0, 0.7 + 0.12 * i, attack_damage + 4, Elements.Type.LIGHTNING)
			return 1.4
		Elements.Type.EARTH:
			telegraph_strike(global_position, 70.0, 1.0, attack_damage + 10, Elements.Type.EARTH)
			_after(1.0, _rock_ring)
			return 1.5
	return 1.0


func _fire_ring(wave: int) -> void:
	if is_dead():
		return
	var count := 18
	for i in count:
		shoot(Vector2.RIGHT.rotated(wave * 0.35 + TAU * i / count), 120.0, attack_damage, fireball_texture, 0.0, Elements.Type.FIRE)


func _ice_shard(index: int) -> void:
	if is_dead():
		return
	var dir := Vector2.RIGHT.rotated(index * 0.55)
	shoot(dir, 140.0, attack_damage - 6, ice_texture, 1.5, Elements.Type.ICE)
	shoot(-dir, 140.0, attack_damage - 6, ice_texture, 1.5, Elements.Type.ICE)


func _rock_ring() -> void:
	if is_dead():
		return
	for i in 14:
		shoot(Vector2.RIGHT.rotated(TAU * i / 14.0), 105.0, attack_damage - 4, rock_texture, 0.0, Elements.Type.EARTH)
	if _player != null:
		_player.shake_camera(5.0)


func _summon_golem(element: Elements.Type) -> void:
	var index := CYCLE.find(element)
	if index < 0 or index >= minion_scenes.size() or minion_scenes[index] == null:
		return
	request_summon(minion_scenes[index], global_position + Vector2.from_angle(randf() * TAU) * 50.0)


func _set_aura(element: Elements.Type) -> void:
	if _aura == null:
		return
	_aura.color_ramp = Fx.fade_ramp(Elements.color_of(element))
	_aura.gravity = Elements.gravity_of(element)


func _after(seconds: float, callable: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(callable)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	# 4원소 핵이 몸 주위를 공전, 활성 속성 핵이 크게 빛남
	var active := get_current_element()
	var spin := _anim_time * (2.4 if _phase_two else 1.2)
	for i in _cores.size():
		var core := _cores[i]
		var angle := spin + TAU * i / _cores.size()
		core.position = get_hit_center() - global_position + Vector2(cos(angle), sin(angle) * 0.55) * CORE_ORBIT_RADIUS
		var target_scale := 0.6 if CYCLE[i] == active else 0.3
		core.scale = core.scale.lerp(Vector2.ONE * target_scale, 1.0 - exp(-8.0 * delta))
	if _state == State.CASTING:
		sprite.position = _base_sprite_pos + Vector2(randf_range(-1.0, 1.0), 0.0)
	else:
		sprite.position = _base_sprite_pos + Vector2(0.0, -absf(sin(_anim_time * 3.0)) * 2.0)
