class_name PatternBoss
extends Enemy
## 6~10스테이지 보스 공용 기반: 추적(CHASE) ↔ 시전(CASTING) 반복.
## 자식 클래스는 pattern_order 를 채우고 _run_pattern() 에서 패턴을 실행한 뒤 걸리는 시간을 돌려줍니다.
## 체력 50% 이하에서 phase_two 가 켜지고 _on_phase_two() 가 한 번 호출됩니다.
## 머리 위 상태 문구는 set_status() 로 표시합니다 (기믹 안내용).

enum BossState { CHASE, CASTING }

@export var chase_time: float = 2.0

var pattern_order: Array[int] = []
var phase_two: bool = false

var _bstate: BossState = BossState.CHASE
var _btimer: float = 0.0
var _pattern_index: int = 0
var _status_label: Label
var _base_sprite_pos: Vector2


func _ready() -> void:
	super._ready()
	is_boss = true
	_base_sprite_pos = sprite.position
	_btimer = chase_time
	_status_label = Label.new()
	_status_label.add_theme_font_size_override(&"font_size", 9)
	_status_label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.03, 0.08))
	_status_label.add_theme_constant_override(&"outline_size", 4)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.size = Vector2(160, 12)
	_status_label.position = Vector2(-80, sprite.position.y - 46)
	_status_label.z_index = 70
	add_child(_status_label)


func set_status(text: String, color: Color = Color.WHITE) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override(&"font_color", color)


func get_status_text() -> String:
	return _status_label.text


func is_casting() -> bool:
	return _bstate == BossState.CASTING


func _get_move_velocity(delta: float) -> Vector2:
	if not has_target():
		return Vector2.ZERO
	_btimer -= delta
	match _bstate:
		BossState.CHASE:
			if _btimer <= 0.0:
				var pattern: int = pattern_order[_pattern_index % pattern_order.size()] if not pattern_order.is_empty() else 0
				_pattern_index += 1
				cast(pattern)
				return Vector2.ZERO
			return _chase_velocity(delta)
		BossState.CASTING:
			if _btimer <= 0.0:
				_bstate = BossState.CHASE
				_btimer = chase_time * (0.7 if phase_two else 1.0)
				return Vector2.ZERO
			return _casting_velocity(delta)
	return Vector2.ZERO


## 신화 이야기가 시작되는 40스테이지(헤르메스)부터 보스 연출 강화
const LATE_STAGE := 40
const CAST_CIRCLE := preload("res://assets/sprites/effects/magic_circle.png")


## 패턴을 바로 실행 (테스트·기믹에서도 사용)
func cast(pattern: int) -> void:
	_bstate = BossState.CASTING
	_cast_flourish()
	_btimer = _run_pattern(pattern)


## 패턴을 쓸 때의 연출: 보스 속성 색으로 번쩍임. 40스테이지 이후 보스는 발밑에 마법진이 깔리고 충격파 (신화 · 마왕 · 천사의 위엄)
func _cast_flourish() -> void:
	if not is_inside_tree():
		return
	var color := Elements.color_of(aura_element) if aura_element != Elements.Type.NONE else Color(1.0, 0.85, 0.6)
	Fx.flash(self, get_hit_center(), color, 18.0, 0.25)
	if GameManager.stage >= LATE_STAGE:
		Fx.sprite_pop(self, global_position, CAST_CIRCLE, Color(color, 0.75), 0.4, 1.1, 0.7, Vector2.ZERO, 1.2, true)
		Fx.shockwave(self, global_position, color.lightened(0.2), 34.0, 0.35)


## 자식 클래스: 패턴 실행, 반환값 = 시전 시간(초)
func _run_pattern(_pattern: int) -> float:
	return 1.0


func _chase_velocity(_delta: float) -> Vector2:
	return global_position.direction_to(_player.global_position) * move_speed * (1.25 if phase_two else 1.0)


func _casting_velocity(_delta: float) -> Vector2:
	return Vector2.ZERO


func _on_phase_two() -> void:
	pass


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if not phase_two and not is_dead() and float(hp) <= max_hp * 0.5:
		phase_two = true
		_on_phase_two()


func _after(seconds: float, callable: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(callable)


func _update_visual(delta: float, move: Vector2) -> void:
	super._update_visual(delta, move)
	if is_casting():
		sprite.position = _base_sprite_pos + Vector2(randf_range(-0.8, 0.8), -1.0)
	else:
		sprite.position = _base_sprite_pos + Vector2(0.0, -absf(sin(_anim_time * 4.0)) * 1.5)
