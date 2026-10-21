class_name BossColchian
extends PatternBoss
## 53스테이지 보스: 콜키스의 잠들지 않는 용 — 아레스의 숲에서 황금 양털을 지키는 용.
##   BITE   : 덮쳐 물기 (앞쪽 장판)
##   VENOM  : 독 브레스 — 초록 독가스를 뿜으며 고개를 플레이어 쪽으로 돌림 + 독침 (맞으면 중독)
##   COIL   : 몸을 휘감아 주위를 휩쓰는 고리
##   SUMMON : 콜키스 청동 황소 · 콜키스 전사 호출
##
## [기믹] 황금 양털: 용이 참나무에 걸린 양털 곁(guard_radius)에 있으면 초당 최대 체력의 regen_ratio 만큼 회복
## [기믹] 양털 빼앗기: 양털을 집어 들고 아르고호(배)까지 가져가면 실어 둠 → stash_time 초 동안 회복이 멈추고 용은 분노로 잠깐 멈칫
##   양털을 든 채 피해를 입으면 떨어뜨리고, 양털은 참나무로 돌아감. 양털을 든 플레이어를 용이 더 빨리 쫓음
## [기믹] 잠들지 않는 용: 기절 시간이 크게 줄어듦
## 체력 50% 이하: 회복량이 늘어남

const BREATH_TEXTURE := preload("res://assets/sprites/projectiles/breath_poison.png")
const SPIT_TEXTURE := preload("res://assets/sprites/projectiles/venom_spit.png")

enum Pattern { BITE, VENOM, COIL, SUMMON }

const FLEECE_SPOT := Vector2(0, -110)
const SHIP_SPOT := Vector2(-240, 120)

@export var minion_scenes: Array[PackedScene] = []
@export var fleece_texture: Texture2D
@export var ship_texture: Texture2D
@export var venom_texture: Texture2D
@export var bite_damage: int = 90
@export var venom_damage: int = 56
@export var coil_damage: int = 80
@export var regen_ratio: float = 0.01
@export var guard_radius: float = 130.0
@export var stash_time: float = 25.0

var fleece: CarryItem
var ship: FieldProp
var _stash_left: float = 0.0
var _stashes: int = 0
var _healed: int = 0
var _heal_acc: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.BITE, Pattern.VENOM, Pattern.COIL, Pattern.BITE, Pattern.SUMMON]


func get_healed_total() -> int:
	return _healed


func get_stash_count() -> int:
	return _stashes


func is_fleece_stashed() -> bool:
	return _stash_left > 0.0


func ship_position() -> Vector2:
	return ship.global_position if ship != null and is_instance_valid(ship) else _area().get_center() + SHIP_SPOT


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


## 양털 곁에서 회복 중인지
func is_guarding_fleece() -> bool:
	return fleece != null and is_instance_valid(fleece) and fleece.available and not fleece.is_carried() \
			and global_position.distance_to(fleece.home) <= guard_radius


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		fleece = CarryItem.spawn(self, _area().get_center() + FLEECE_SPOT, fleece_texture, "황금 양털")
		ship = FieldProp.spawn(self, _area().get_center() + SHIP_SPOT, ship_texture)
	return super._get_move_velocity(delta)


## 잠들지 않는 용: 기절이 아주 짧음
func stun(duration: float) -> void:
	super.stun(duration * 0.35)


func _chase_velocity(delta: float) -> Vector2:
	var v := super._chase_velocity(delta)
	if fleece == null or not is_instance_valid(fleece):
		return v
	if fleece.is_carried():
		return v * 1.5
	# 양털을 지키는 용: 참나무에서 너무 멀어지면 돌아감
	if fleece.available and global_position.distance_to(fleece.home) > guard_radius * 0.85:
		return global_position.direction_to(fleece.home) * move_speed
	return v


func _physics_process(delta: float) -> void:
	if not is_dead() and fleece != null and is_instance_valid(fleece):
		if _stash_left > 0.0:
			_stash_left -= delta
			if _stash_left <= 0.0:
				Net.announce("콜키스의 용이 아르고호에서 황금 양털을 되찾아 왔다!", Color(1.0, 0.85, 0.4))
		elif fleece.is_carried() and fleece.global_position.distance_to(ship_position()) <= 34.0:
			stash_fleece()
		if is_guarding_fleece() and _stash_left <= 0.0 and hp < max_hp:
			_heal_acc += max_hp * regen_ratio * (1.5 if phase_two else 1.0) * delta
			if _heal_acc >= 1.0:
				var amount := mini(int(_heal_acc), max_hp - hp)
				_heal_acc -= int(_heal_acc)
				hp += amount
				_healed += amount
				health_changed.emit(hp, max_hp)
				if Engine.get_physics_frames() % 30 == 0:
					Fx.burst(self, get_hit_center(), Color(1.0, 0.85, 0.3), 6, 40.0, 0.5, Vector2(0, -40))
		_update_fleece_status()
	super._physics_process(delta)


func _update_fleece_status() -> void:
	if _stash_left > 0.0:
		set_status("양털을 빼앗김 — 회복 불가 %.0f초" % _stash_left, Color(0.7, 0.9, 1.0))
	elif fleece.is_carried():
		set_status("양털을 내놓아라!", Color(1.0, 0.5, 0.4))
	elif is_guarding_fleece():
		set_status("황금 양털의 가호 — 회복 중", Color(1.0, 0.85, 0.4))
	else:
		set_status("", Color.WHITE)


## 양털을 아르고호에 실음 (테스트에서도 직접 호출)
func stash_fleece() -> void:
	if fleece == null or is_dead():
		return
	_stashes += 1
	_stash_left = stash_time
	fleece.hide_for(stash_time)
	super.stun(2.5)
	Fx.burst(self, ship_position(), Color(1.0, 0.9, 0.4), 24, 70.0, 0.7, Vector2(0, -50))
	Net.announce("황금 양털을 아르고호에 실었다! 용이 더는 회복하지 못한다", Color(1.0, 0.9, 0.5))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.BITE:
			for i in 3:
				telegraph_strike(get_hit_center() + dir * (40.0 + 30.0 * i), 26.0, 0.7 + 0.08 * i, bite_damage, Elements.Type.NONE)
			return 1.1
		Pattern.VENOM:
			breathe(dir, {"texture": BREATH_TEXTURE, "damage": venom_damage, "element": Elements.Type.NATURE,
				"speed": 120.0, "range": 160.0, "cone": 0.7, "duration": 1.0, "rate": 22.0, "grow": 3.0, "track": 0.03, "windup": 0.35})
			for w in 2:
				_after(0.5 + 0.3 * w, func() -> void:
					if is_dead() or not has_target():
						return
					var aim := direction_to_player()
					for i in 3:
						shoot(aim.rotated((i - 1) * 0.25), 165.0, venom_damage, SPIT_TEXTURE, 0.0, Elements.Type.NATURE))
			return 1.5
		Pattern.COIL:
			for i in 10:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0) * 56.0, 22.0, 0.9, coil_damage, Elements.Type.NATURE)
			return 1.3
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("잠들지 않는 용이 포효한다! 양털 곁에서 더 빨리 회복한다", Color(0.6, 1.0, 0.6))
