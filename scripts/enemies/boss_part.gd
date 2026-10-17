class_name BossPart
extends Enemy
## 보스에 딸린 부위 (11~15스테이지 보스 기믹): 키메라의 꼬리 · 레기온의 마도코어 · 크라켄의 촉수 · 도플갱어의 거울.
## 보스가 request_summon() 으로 만들고, register_minion() 에서 boss / 체력 / 위치를 정해 줍니다.
##
## - follow_boss  : true 면 매 프레임 보스 위치 + anchor_offset 에 붙어 다님 (꼬리·코어). false 면 제자리 (촉수·거울)
## - mirror_x     : true 면 보스가 바라보는 방향에 따라 anchor_offset.x 를 뒤집음 (꼬리는 항상 몸 뒤쪽)
## - relay_ratio  : 0 보다 크면 자기 체력은 그대로 두고, 받은 공격을 이 배율로 보스에게 넘김 (약점 부위 = 마도코어)
## - show_bar     : 머리 위에 따로 작은 체력 바 (보스 체력과 따로인 부위)
## 보스가 죽으면 부위도 조용히 사라집니다.

@export var follow_boss: bool = true
@export var mirror_x: bool = false
@export var relay_ratio: float = 0.0
@export var show_bar: bool = true
@export var bar_color: Color = Color(1.0, 0.82, 0.3)
@export var bar_y: float = -16.0
## 떠 있는 연출 (위아래로 흔들림 폭, 0 이면 없음)
@export var bob_amount: float = 1.5

var boss: Enemy
var anchor_offset: Vector2 = Vector2.ZERO
var _base_sprite_pos: Vector2


func _ready() -> void:
	super._ready()
	knockback_resistance = 1.0
	collision_mask = 0  # 부위는 몸으로 부딪혀 피해를 주지 않음 (공격은 보스가 부위를 통해서)
	_base_sprite_pos = sprite.position


func _get_move_velocity(delta: float) -> Vector2:
	queue_redraw()
	if boss == null or not is_instance_valid(boss) or boss.is_dead():
		if boss != null:
			despawn()
		return Vector2.ZERO
	if not follow_boss:
		return Vector2.ZERO
	var offset := anchor_offset
	if mirror_x and boss.sprite.flip_h:
		offset.x = -offset.x
	return (boss.global_position + offset - global_position) / maxf(delta, 0.001)


## 보스가 이 부위를 통해 공격할 때 쓰는 발사 위치
func get_muzzle() -> Vector2:
	return get_hit_center()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if relay_ratio > 0.0:
		if boss != null and is_instance_valid(boss) and not boss.is_dead() and boss.has_method(&"take_weak_point_hit"):
			_hit_flash = 0.08
			boss.call(&"take_weak_point_hit", amount, knockback, is_crit, armor_pen, relay_ratio)
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _update_visual(_delta: float, _move: Vector2) -> void:
	if follow_boss and mirror_x and boss != null and is_instance_valid(boss):
		sprite.flip_h = boss.sprite.flip_h
	if bob_amount > 0.0:
		sprite.position = _base_sprite_pos + Vector2(0.0, -sin(_anim_time * 3.0) * bob_amount)


## 머리 위 작은 체력 바 (보스 체력과 따로)
func _draw() -> void:
	if is_dead() or not show_bar or relay_ratio > 0.0:
		return
	var w := 26.0
	var ratio := float(hp) / float(maxi(max_hp, 1))
	draw_rect(Rect2(-w * 0.5, bar_y, w, 3.0), Color(0.1, 0.08, 0.05, 0.85))
	draw_rect(Rect2(-w * 0.5, bar_y, w * ratio, 3.0), bar_color)
