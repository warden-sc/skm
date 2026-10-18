class_name BossNightmare
extends PatternBoss
## 29스테이지 보스: 몽마 나이트메어 — 잠든 자의 꿈속을 떠도는 말 머리의 몽마.
##   DREAM  : 꿈의 고리 — 사방으로 퍼지는 몽환탄 두 겹
##   HANDS  : 악몽의 손 — 플레이어 발밑에 연달아 솟는 그림자 손 장판
##   SLEEP  : 수면 구체 — 느린 구체 3발, 맞으면 sleep_time 동안 잠듦 (조작 불가)
##   SUMMON : 몽마 하수인 · 잠의 요정 호출
##
## [기믹] 환각 (illusion_interval 마다, illusion_time 동안):
##   - 진짜와 똑같이 생긴 환영 illusion_count 개가 나타나고, 진짜도 그 사이로 자리를 옮김
##   - 진짜만 발밑에 그림자가 있음 → 그림자를 보고 진짜를 찾아야 함
##   - 환영을 때리면 흩어질 뿐, 진짜를 때리면 「들켰다!」 → 환영이 모두 사라지고 진짜가 잠깐 휘청임
## 체력 50% 이하: 환영이 더 많고 더 자주

enum Pattern { DREAM, HANDS, SLEEP, SUMMON }

@export var illusion_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var dream_texture: Texture2D
@export var sleep_texture: Texture2D
@export var dream_damage: int = 40
@export var hands_damage: int = 64
@export var sleep_damage: int = 30
@export var sleep_time: float = 1.5
@export var illusion_interval: float = 13.0
@export var illusion_time: float = 8.0
@export var illusion_count: int = 4

var _illusions: Array[NightmareIllusion] = []
var _illusion_cooldown: float = 6.0
var _illusion_left: float = 0.0
var _illusion_casts: int = 0
var _caught: int = 0
var _orbit_angle: float = 0.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.DREAM, Pattern.HANDS, Pattern.SLEEP, Pattern.SUMMON, Pattern.HANDS, Pattern.DREAM]


func get_illusions() -> Array[NightmareIllusion]:
	var alive: Array[NightmareIllusion] = []
	for i in _illusions:
		if is_instance_valid(i) and not i.is_dead():
			alive.append(i)
	return alive


func is_illusion_active() -> bool:
	return _illusion_left > 0.0


func get_caught_count() -> int:
	return _caught


func _get_move_velocity(delta: float) -> Vector2:
	if _illusion_left > 0.0:
		_illusion_left -= delta
		if _illusion_left <= 0.0:
			end_illusion(false)
	elif has_target():
		_illusion_cooldown -= delta
		if _illusion_cooldown <= 0.0 and not is_casting():
			begin_illusion()
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 환각
func begin_illusion() -> void:
	if is_illusion_active() or is_dead() or not has_target() or illusion_scene == null:
		return
	_illusion_casts += 1
	_illusion_left = illusion_time
	_illusion_cooldown = illusion_interval * (0.75 if phase_two else 1.0)
	var count := illusion_count + (2 if phase_two else 0)
	var slot := randi() % (count + 1)  # 진짜가 설 자리
	for i in count + 1:
		var angle := TAU * i / float(count + 1)
		var at := _player.global_position + Vector2.from_angle(angle) * 110.0
		if arena_rect.has_area():
			at = at.clamp(arena_rect.position, arena_rect.end)
		if i == slot:
			Fx.burst(self, get_hit_center(), Color(0.6, 0.4, 0.9), 14, 50.0, 0.4)
			global_position = at
			_orbit_angle = angle
		else:
			request_summon(illusion_scene, at)
	set_status("", Color.WHITE)  # 머리 위 문구로 진짜가 드러나지 않도록
	GameManager.show_notice("나이트메어의 환각! 그림자가 있는 것이 진짜다", Color(0.85, 0.7, 1.0))


func register_minion(minion: Enemy) -> void:
	if minion is NightmareIllusion:
		var ill := minion as NightmareIllusion
		ill.set_orbit(_player.global_position.angle_to_point(ill.global_position) if has_target() else 0.0, 110.0)
		_illusions.append(ill)


## 환각 끝 (caught = 진짜가 맞아서 들킴)
func end_illusion(caught: bool) -> void:
	_illusion_left = 0.0
	for ill in get_illusions():
		ill.vanish(false)
	_illusions.clear()
	if caught:
		_caught += 1
		FloatingText.spawn(self, global_position + Vector2(0, -50), "들켰다!", Color(1.0, 0.85, 0.5), true)
		stun(1.5)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if is_illusion_active() and not is_dead():
		end_illusion(true)


## 환각 중에는 진짜도 환영과 똑같이 플레이어 주위를 맴돎 (움직임으로 구별되지 않도록)
func _chase_velocity(delta: float) -> Vector2:
	if not is_illusion_active():
		return super._chase_velocity(delta)
	_orbit_angle += delta * 0.7
	var target := _player.global_position + Vector2.from_angle(_orbit_angle) * 110.0
	return global_position.direction_to(target) * move_speed if global_position.distance_to(target) > 4.0 else Vector2.ZERO


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.DREAM:
			for w in 2:
				_after(0.35 * w, func() -> void:
					if is_dead():
						return
					for i in 16:
						shoot(Vector2.from_angle(TAU * i / 16.0 + w * 0.2), 105.0, dream_damage, dream_texture, 0.0, Elements.Type.ARCANE))
			return 1.1
		Pattern.HANDS:
			for i in (6 if phase_two else 4):
				_after(0.22 * i, func() -> void:
					if not is_dead() and has_target():
						telegraph_strike(_player.global_position, 20.0, 0.6, hands_damage, Elements.Type.DARK))
			return 1.5
		Pattern.SLEEP:
			return sleep_orbs()
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


## 수면 구체: 맞으면 잠듦 (테스트에서도 직접 호출)
func sleep_orbs() -> float:
	var pool := ProjectilePool.find(get_tree())
	if pool == null or not has_target():
		return 0.8
	var aim := direction_to_player()
	for a in [-0.25, 0.0, 0.25]:
		var spec := ProjectileSpec.enemy_bullet(get_hit_center(), aim.rotated(a), 95.0, roundi(sleep_damage * power), sleep_texture, 0.0, Elements.Type.ARCANE)
		spec.charm_duration = sleep_time
		spec.charm_label = "수면"
		pool.spawn(spec)
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("나이트메어: 깨어날 수 없는 꿈을 꾸어라… 환영이 늘어난다", Color(0.85, 0.7, 1.0))
