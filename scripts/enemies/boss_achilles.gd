class_name BossAchilles
extends PatternBoss
## 66스테이지 보스: 영웅 아킬레우스 — 스틱스강에 담가져 불사의 몸이 되었지만, 어머니가 잡고 있던 뒤꿈치만은 젖지 않은 영웅.
##   SPEAR   : 창 찌르기 — 바라보는 방향으로 일직선 셋
##   RUSH    : 돌진 — 바라보는 방향으로 크게 내달린 뒤 멈춰 숨을 고름 (그동안 느리게 돌아섬 → 등 뒤를 노릴 기회)
##   SHIELD  : 방패 밀치기 — 앞쪽 부채꼴
##   SUMMON  : 미르미돈 전사 · 방패병 호출
##
## [기믹] 불사의 몸: 앞이나 옆에서 들어온 공격은 거의 통하지 않음 (heel_ratio 의 반대 — 피해 1)
## [기믹] 뒤꿈치: 아킬레우스가 바라보는 방향의 뒤쪽(등 뒤)에서 때리면 피해 x heel_multiplier
##   아킬레우스는 turn_speed 로만 천천히 몸을 돌림 — 돌진 뒤에는 더 느려짐
## 체력 50% 이하: 「분노」 — 돌진이 더 길고 빨라짐

enum Pattern { SPEAR, RUSH, SHIELD, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var javelin_texture: Texture2D
@export var spear_damage: int = 96
@export var rush_damage: int = 100
@export var shield_damage: int = 84
@export var turn_speed: float = 1.6
@export var heel_multiplier: float = 1.5

var facing: Vector2 = Vector2.DOWN
var _rush_left: float = 0.0
var _rush_hit: bool = false
var _recover_left: float = 0.0
var _heel_hits: int = 0
var _blocked: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SPEAR, Pattern.RUSH, Pattern.SHIELD, Pattern.RUSH, Pattern.SUMMON]
	set_status("불사의 몸 — 등 뒤의 뒤꿈치만 통함", Color(1.0, 0.85, 0.5))


func get_heel_hits() -> int:
	return _heel_hits


func get_blocked_hits() -> int:
	return _blocked


## 플레이어가 등 뒤에 있는지
func is_behind(at: Vector2) -> bool:
	return facing.dot(global_position.direction_to(at)) < -0.25


func _get_move_velocity(delta: float) -> Vector2:
	if has_target() and _rush_left <= 0.0:
		var want := direction_to_player()
		var rate := turn_speed * (0.35 if _recover_left > 0.0 else 1.0)
		facing = facing.rotated(clampf(facing.angle_to(want), -rate * delta, rate * delta)).normalized()
	if _recover_left > 0.0:
		_recover_left -= delta
		return Vector2.ZERO
	if _rush_left > 0.0:
		_rush_left -= delta
		if not _rush_hit and has_target() and global_position.distance_to(_player.global_position) < 30.0:
			_rush_hit = true
			_player.take_hit(roundi(rush_damage * power), global_position, self)
		if _rush_left <= 0.0:
			_recover_left = 1.6
		return facing * (330.0 if phase_two else 280.0)
	return super._get_move_velocity(delta)


func _chase_velocity(_delta: float) -> Vector2:
	# 바라보는 쪽으로만 걸음 (몸을 홱 돌리지 못함)
	return facing * move_speed * (1.25 if phase_two else 1.0)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and not is_dead() and has_target():
		if is_behind(_player.global_position):
			_heel_hits += 1
			amount = roundi(amount * heel_multiplier)
			if _immune_text_cooldown <= 0.0:
				_immune_text_cooldown = 0.5
				FloatingText.spawn(self, global_position + Vector2(0, -44), "뒤꿈치!", Color(1.0, 0.5, 0.4), true)
		else:
			_blocked += 1
			immune_text = "불사의 몸! 등 뒤를 노려라"
			show_immune()
			amount = 1
			armor_pen = 999999
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.SPEAR:
			for k in 3:
				var d := facing.rotated((k - 1) * 0.25)
				for i in 9:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 13.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.NONE)
			if javelin_texture != null:
				shoot(facing, 220.0, spear_damage - 30, javelin_texture)
			return 1.1
		Pattern.RUSH:
			_rush_left = 0.75 if phase_two else 0.6
			_rush_hit = false
			for i in 12:
				Fx.flash(self, global_position + facing * (20.0 + 20.0 * i), Color(1.0, 0.6, 0.3), 10.0, 0.45)
			return 0.2
		Pattern.SHIELD:
			for i in 7:
				telegraph_strike(get_hit_center() + facing.rotated((i - 3) * 0.28) * 46.0, 20.0, 0.7, shield_damage, Elements.Type.NONE)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if absf(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0.0
	queue_redraw()


## 바라보는 방향 표시 (발밑 화살표)
func _draw() -> void:
	if is_dead():
		return
	var tip := facing * 26.0
	draw_line(Vector2.ZERO, tip, Color(1.0, 0.85, 0.5, 0.5), 2.0)
	draw_circle(-facing * 18.0, 3.0, Color(1.0, 0.4, 0.4, 0.7))  # 뒤꿈치


func _on_phase_two() -> void:
	GameManager.show_notice("아킬레우스의 분노! 돌진이 더 길고 빨라진다", Color(1.0, 0.5, 0.4))
