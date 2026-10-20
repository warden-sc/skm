class_name BossMeleager
extends PatternBoss
## 56스테이지 보스: 칼리돈의 영웅 멜레아그로스 — 아레스의 아들이라고도 전해지는 칼리돈의 사냥꾼.
## 그가 태어날 때 운명의 여신들은 「화로의 장작이 다 타면 이 아이의 목숨도 다한다」고 예언했습니다.
##   SPEAR    : 사냥창 연속 찌르기 (일직선 둘)
##   JAVELIN  : 투창 세례
##   BOAR     : 칼리돈의 멧돼지에게 돌격 명령 + 땅을 파헤치는 장판
##   SUMMON   : 쿠레테스 전사 · 사냥꾼 호출
##
## [기믹] 생명의 장작: 보스방에 장작이 하나씩 놓임 — 집어 들어 화로까지 가져가면 태움
##   장작 하나가 탈 때마다 최대 체력의 burn_ratio 피해 · 방어력 -burn_defense · 공격력 -burn_power
##   장작을 든 채 피해를 입으면 떨어뜨리고 장작은 제자리로 돌아감. 멜레아그로스는 장작을 든 플레이어를 더 빨리 쫓음
##   brand_count 개를 모두 태우면 「꺼져 가는 목숨」: 오래 휘청이고 더 약해짐
## [기믹] 칼리돈의 멧돼지: 싸움이 시작되면 거대한 멧돼지를 데려옴 (명령에 따라 돌격)
## 체력 50% 이하: 「사냥꾼의 분노」 — 공격이 빨라짐

enum Pattern { SPEAR, JAVELIN, BOAR, SUMMON }

const BRAND_SPOTS := [Vector2(-230, -110), Vector2(230, 110), Vector2(230, -110), Vector2(-230, 110)]
const HEARTH_SPOT := Vector2(0, -120)

@export var boar_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var brand_texture: Texture2D
@export var hearth_texture: Texture2D
@export var javelin_texture: Texture2D
@export var spear_damage: int = 90
@export var javelin_damage: int = 58
@export var dig_damage: int = 74
@export var brand_count: int = 4
@export var burn_ratio: float = 0.05
@export var burn_defense: int = 8
@export var burn_power: float = 0.08

var brand: CarryItem
var hearth: FieldProp
var boar: Enemy
var _burned: int = 0
var _base_defense: int = 0
var _base_power: float = 1.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	_base_defense = defense
	pattern_order = [Pattern.SPEAR, Pattern.JAVELIN, Pattern.BOAR, Pattern.SPEAR, Pattern.SUMMON]


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power
	_base_defense = defense


func get_burned_count() -> int:
	return _burned


func hearth_position() -> Vector2:
	return hearth.global_position if hearth != null and is_instance_valid(hearth) else _area().get_center() + HEARTH_SPOT


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		hearth = FieldProp.spawn(self, _area().get_center() + HEARTH_SPOT, hearth_texture, Color(1.0, 0.55, 0.15))
		brand = CarryItem.spawn(self, _area().get_center() + BRAND_SPOTS[0], brand_texture, "생명의 장작", Color(1.0, 0.6, 0.3))
		if boar_scene != null:
			request_summon(boar_scene, global_position + Vector2(-60, 20))
		_update_status()
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if boar == null and boar_scene != null and minion.scene_file_path == boar_scene.resource_path:
		boar = minion


func _chase_velocity(delta: float) -> Vector2:
	var v := super._chase_velocity(delta)
	return v * 1.6 if brand != null and is_instance_valid(brand) and brand.is_carried() else v


func _physics_process(delta: float) -> void:
	if not is_dead() and brand != null and is_instance_valid(brand) and brand.is_carried():
		if brand.global_position.distance_to(hearth_position()) <= 30.0:
			burn_brand()
	super._physics_process(delta)


## 장작을 화로에 태움 (테스트에서도 직접 호출)
func burn_brand() -> void:
	if is_dead() or _burned >= brand_count:
		return
	_burned += 1
	defense = maxi(_base_defense - burn_defense * _burned, 0)
	power = _base_power * maxf(1.0 - burn_power * _burned, 0.2)
	Fx.fire_blast(self, hearth_position() + Vector2(0, -10), 30.0)
	take_damage(roundi(max_hp * burn_ratio), Vector2.ZERO, false, 999999)
	if _burned >= brand_count:
		brand.hide_for(9999.0)
		super.stun(8.0)
		Net.announce("마지막 장작이 다 타 버렸다! 멜레아그로스의 목숨이 꺼져 간다", Color(1.0, 0.6, 0.3))
	else:
		brand.hide_for(3.0)
		brand.home = _area().get_center() + BRAND_SPOTS[_burned % BRAND_SPOTS.size()]
		super.stun(2.0)
		Net.announce("생명의 장작이 타오른다! 멜레아그로스가 약해진다 (%d/%d)" % [_burned, brand_count], Color(1.0, 0.7, 0.4))
	_update_status()


func _update_status() -> void:
	if _burned >= brand_count:
		set_status("꺼져 가는 목숨", Color(0.8, 0.6, 0.5))
	else:
		set_status("생명의 장작 %d/%d — 화로에 태워라" % [brand_count - _burned, brand_count], Color(1.0, 0.75, 0.4))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SPEAR:
			for k in 2:
				var d := dir.rotated((k - 0.5) * 0.35)
				for i in 9:
					telegraph_strike(get_hit_center() + d * (24.0 + 22.0 * i), 14.0, 0.6 + 0.2 * k + 0.03 * i, spear_damage, Elements.Type.NONE)
			return 1.2 if not phase_two else 0.9
		Pattern.JAVELIN:
			for i in 5:
				shoot(dir.rotated((i - 2) * 0.2), 200.0, javelin_damage, javelin_texture)
			return 0.9
		Pattern.BOAR:
			if boar != null and is_instance_valid(boar) and not boar.is_dead():
				boar.give_command(Enemy.Command.CHARGE)
			for i in 5:
				telegraph_strike(_player.global_position + Vector2.from_angle(TAU * i / 5.0) * 40.0, 20.0, 1.0, dig_damage, Elements.Type.EARTH)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if boar != null and is_instance_valid(boar):
		boar.despawn()
	super._die()


func _on_phase_two() -> void:
	chase_time *= 0.75
	Net.announce("멜레아그로스: 칼리돈의 사냥은 끝나지 않았다! 공격이 빨라진다", Color(0.9, 0.85, 0.6))
