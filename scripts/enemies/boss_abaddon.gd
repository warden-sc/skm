class_name BossAbaddon
extends PatternBoss
## 90스테이지 보스: 마왕 아바돈 — 무저갱(바닥 없는 구덩이)의 왕, 그리스 이름으로는 「아폴리온(파괴자)」.
##   STING    : 전갈 꼬리 찌르기 (일직선 둘)
##   HELLFIRE : 지옥불 고리 — 몸 주위
##   ABYSS    : 무저갱의 탄막 (사방)
##   SUMMON   : 타락한 천사병 · 지옥의 망령 호출
##
## [등장] 옥좌: 보스방에 들어서면 아바돈이 옥좌에 앉아 있다가(무적) intro_time 초 뒤 옥좌에서 일어나며 싸움이 시작됨
## [기믹 1] 바닥 없는 구덩이: 보스방 가운데 구덩이가 점점 넓어짐 — 빠지면 최대 체력의 fall_ratio 피해를 입고 가장자리로 튕겨 나옴 (대시 중엔 건너뜀)
## [기믹 2] 일곱 대죄의 힘: sin_time 초마다 앞서 쓰러뜨린 대죄 마왕의 힘을 차례로 빌림 (머리 위에 표시)
##   탐욕 — 금화 더미 쟁탈 (아바돈이 먹으면 공격력 상승) / 나태 — 느려지는 오라 / 폭식 — 졸개를 잡아먹어 회복 / 색욕 — 사슬로 묶음
## [기믹 3] 파괴자 아폴리온: 체력 50% 이하에서 각성 — 날개를 펴고 flight_time 초씩 날아올라(활만 닿음) 공격하고,
##   무저갱의 연기가 보스방을 뒤덮어 플레이어 둘레만 보임

enum Pattern { STING, HELLFIRE, ABYSS, SUMMON }
enum Sin { GREED, SLOTH, GLUTTONY, LUST }

const SIN_NAMES := ["탐욕", "나태", "폭식", "색욕"]
const FLIGHT_HEIGHT := 18.0

@export var minion_scenes: Array[PackedScene] = []
@export var throne_texture: Texture2D
@export var coin_texture: Texture2D
@export var bolt_texture: Texture2D
@export var sting_damage: int = 108
@export var hellfire_damage: int = 96
@export var bolt_damage: int = 66
@export var intro_time: float = 3.0
@export var fall_ratio: float = 0.15
@export var sin_time: float = 15.0
@export var flight_time: float = 6.0

var pit: AbyssPit
var throne: FieldProp
var veil: FogVeil
var current_sin: int = Sin.GREED
var coins: Array[CarryItem] = []
var _intro_left: float = 0.0
var _seated: bool = true
var _sin_left: float = 0.0
var _sin_tick: float = 0.0
var _greed: int = 0
var _falls: int = 0
var _fly_left: float = 0.0
var _ground_left: float = 0.0
var _base_power: float = 1.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.STING, Pattern.HELLFIRE, Pattern.ABYSS, Pattern.STING, Pattern.SUMMON]
	immune_text = "옥좌의 위엄 — 아직 일어나지 않았다"
	set_status("무저갱의 옥좌에 앉아 있다…", Color(1.0, 0.4, 0.3))


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func is_seated() -> bool:
	return _seated


func get_fall_count() -> int:
	return _falls


func is_flying() -> bool:
	return _fly_left > 0.0


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		_intro_left = intro_time
		throne = FieldProp.spawn(self, global_position + Vector2(0, -6), throne_texture, Color(1.0, 0.3, 0.15))
		GameManager.show_notice("무저갱의 옥좌 위에서, 마왕 아바돈이 천천히 눈을 뜬다…", Color(1.0, 0.4, 0.3))
	if _seated:
		return Vector2.ZERO
	return super._get_move_velocity(delta)


## 옥좌에서 일어남 (테스트에서도 직접 호출)
func rise() -> void:
	if not _seated or is_dead():
		return
	_seated = false
	_intro_left = 0.0
	pit = AbyssPit.spawn(self, _area().get_center() + Vector2(0, 30))
	if pit != null:
		pit.fall_callback = _on_fall
	_sin_left = sin_time
	_apply_sin()
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.3, 0.15), 160.0, 0.7)
	Fx.burst(self, get_hit_center(), Color(0.4, 0.1, 0.1), 40, 110.0, 0.8, Vector2(0, -40))
	GameManager.show_notice("아바돈이 옥좌에서 일어난다! 무저갱이 입을 벌린다", Color(1.0, 0.35, 0.25))


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _seated:
		show_immune()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func can_be_hit_by(kind: HitKind) -> bool:
	return not _seated and super.can_be_hit_by(kind)


func _on_fall(player: Player) -> void:
	_falls += 1
	player.take_unblockable_hit(roundi(GameManager.max_hp * fall_ratio), pit.global_position, false)
	player.global_position = pit.rim_point(player.global_position)
	GameManager.show_notice("무저갱에 떨어졌다! 가장자리로 간신히 기어 나왔다", Color(1.0, 0.4, 0.3))


# ============================================================ 기믹 2: 일곱 대죄의 힘
## 다음 대죄로 (테스트에서도 직접 호출)
func next_sin() -> void:
	current_sin = (current_sin + 1) % SIN_NAMES.size()
	_sin_left = sin_time
	_apply_sin()


func _apply_sin() -> void:
	for c in coins:
		if is_instance_valid(c):
			c.queue_free()
	coins.clear()
	_sin_tick = 0.0
	match current_sin:
		Sin.GREED:
			var area := _area().grow(-40.0)
			for i in 4:
				var at := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
				if pit != null and pit.contains(at):
					at = pit.rim_point(at, 40.0)
				var coin := CarryItem.spawn(self, at, coin_texture, "금화 더미", Color(1.0, 0.85, 0.3))
				if coin != null:
					coin.follow_player = false
					coin.picked_up.connect(func(c: CarryItem) -> void:
						c.hide_for(99999.0)
						GameManager.add_gold(30))
					coins.append(coin)
	GameManager.show_notice("아바돈이 「%s」의 힘을 빌린다" % SIN_NAMES[current_sin], Color(1.0, 0.5, 0.4))
	_update_status()


func _sin_effects(delta: float) -> void:
	_sin_tick -= delta
	match current_sin:
		Sin.GREED:
			for c in coins:
				if is_instance_valid(c) and c.available and c.global_position.distance_to(global_position) <= 24.0:
					c.hide_for(99999.0)
					_greed += 1
					power = _base_power * (1.0 + 0.06 * _greed)
					FloatingText.spawn(self, global_position + Vector2(0, -60), "탐욕 +1", Color(1.0, 0.85, 0.3), true)
		Sin.SLOTH:
			if _player.global_position.distance_to(global_position) <= 120.0:
				_player.apply_slow(0.55, 0.15)
				_player.mark_floor_status("나태의 오라 (느려짐)")
		Sin.GLUTTONY:
			if _sin_tick <= 0.0:
				_sin_tick = 4.0
				for e in get_tree().get_nodes_in_group(&"enemies"):
					var enemy := e as Enemy
					if enemy != null and enemy != self and not enemy.is_boss and not enemy is BossPart and not enemy.is_dead() and enemy.global_position.distance_to(global_position) <= 160.0:
						enemy.despawn()
						var heal := mini(roundi(max_hp * 0.03), max_hp - hp)
						hp += heal
						health_changed.emit(hp, max_hp)
						FloatingText.spawn(self, global_position + Vector2(0, -60), "꿀꺽! +%d" % heal, Color(0.7, 0.9, 0.4), true)
						break
		Sin.LUST:
			var d := global_position.distance_to(_player.global_position)
			if d > 160.0:
				_player.apply_push(_player.global_position.direction_to(global_position) * (d - 160.0) * 12.0)
				_player.mark_floor_status("욕망의 사슬에 묶임")


func _update_status() -> void:
	if _seated:
		return
	var text := "대죄의 힘: %s" % SIN_NAMES[current_sin]
	if phase_two:
		text = "파괴자 아폴리온 · " + text + (" · 비상!" if is_flying() else "")
	set_status(text, Color(1.0, 0.45, 0.35))


# ============================================================ 기믹 3: 파괴자 아폴리온
func _on_phase_two() -> void:
	_ground_left = 2.0
	veil = FogVeil.spawn(self, _area())
	GameManager.show_notice("「나는 아폴리온, 파괴하는 자」 — 아바돈이 날개를 펴고, 무저갱의 연기가 방을 뒤덮는다", Color(1.0, 0.3, 0.25))
	_update_status()


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _seated:
			_intro_left -= delta
			if _intro_left <= 0.0:
				rise()
		elif has_target():
			_sin_left -= delta
			if _sin_left <= 0.0:
				next_sin()
			_sin_effects(delta)
			if phase_two:
				if veil != null and is_instance_valid(veil):
					veil.light_at = _player.global_position
					veil.light_radius = 130.0
				if _fly_left > 0.0:
					_fly_left -= delta
					if _fly_left <= 0.0:
						airborne = false
						_ground_left = flight_time
						_update_status()
				else:
					_ground_left -= delta
					if _ground_left <= 0.0:
						airborne = true
						immune_text = "날아오른 파괴자 — 활만 닿음"
						_fly_left = flight_time
						_update_status()
			if Engine.get_physics_frames() % 30 == 0:
				_update_status()
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target() or _seated:
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.STING:
			for k in 2:
				var d := dir.rotated((k - 0.5) * 0.3)
				for i in 12:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, sting_damage, Elements.Type.NATURE)
			return 1.1
		Pattern.HELLFIRE:
			for i in 14:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0) * 58.0, 22.0, 0.85, hellfire_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.ABYSS:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2), 120.0, bolt_damage, bolt_texture, 0.0, Elements.Type.DARK))
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if _seated:
		sprite.position = _base_sprite_pos + Vector2(0, 4)
		sprite.modulate = Color(0.75, 0.6, 0.65, sprite.modulate.a)
	else:
		sprite.modulate = Color(1, 1, 1, sprite.modulate.a)
		if airborne:
			sprite.position.y += -FLIGHT_HEIGHT + sin(_anim_time * 4.0) * 2.0


func _die() -> void:
	for c in coins:
		if is_instance_valid(c):
			c.queue_free()
	if veil != null and is_instance_valid(veil):
		veil.queue_free()
	super._die()
