class_name BossOdysseus
extends PatternBoss
## 76스테이지 보스: 오디세우스 — 아테나가 가장 아낀 꾀 많은 영웅. 이타카로 돌아와 열두 도끼의 구멍을 화살 하나로 꿰뚫었습니다.
##   AXE_ARROW : 열두 도끼 꿰뚫기 — 도끼 줄의 한쪽 끝에서, 줄을 따라 일직선으로 화살이 꿰뚫음 (줄 위에 있으면 큰 피해)
##   VOLLEY    : 활 세례 (부채꼴)
##   DISGUISE  : 늙은 거지로 변장 — 똑같이 생긴 거지들 사이에 섞임
##   SUMMON    : 구혼자 · 구혼자 궁수 호출
##
## [기믹] 열두 도끼: 보스방을 가로질러 도끼 12자루가 일렬로 섬 (각각 체력 따로)
##   도끼를 쓰러뜨려 줄을 끊으면, 화살은 쏜 쪽에서 가장 가까운 끊긴 자리에서 막힘 → 끝 쪽 도끼를 쓰러뜨리면 화살이 아예 나가지 못함
##   쓰러진 도끼는 axe_restand 초 뒤 모두 다시 섬
## [기믹] 거지 변장: disguise_time 초 동안 거지 모습으로 거지 decoy_count 명과 섞임 — 진짜를 때리면 정체가 드러나며 휘청
## 체력 50% 이하: 열두 도끼 화살이 두 번 연달아

enum Pattern { AXE_ARROW, VOLLEY, DISGUISE, SUMMON }

const AXE_COUNT := 12
const AXE_SPACING := 38.0
const AXE_ROW_Y := -10.0

@export var axe_scene: PackedScene
@export var decoy_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var arrow_texture: Texture2D
@export var beggar_texture: Texture2D
@export var axe_arrow_damage: int = 104
@export var volley_damage: int = 62
@export var axe_hp_ratio: float = 0.01
@export var axe_restand: float = 20.0
@export var disguise_time: float = 6.0
@export var decoy_count: int = 3

var axes: Array[BossPart] = []
var decoys: Array[Enemy] = []
var last_shot: Array[Vector2] = []
var _pending_slot: int = -1
var _restand_left: float = 0.0
var _disguise_left: float = 0.0
var _reveals: int = 0
var _blocked_shots: int = 0
var _normal_texture: Texture2D
var _started: bool = false


func _ready() -> void:
	super._ready()
	_normal_texture = sprite.texture
	pattern_order = [Pattern.AXE_ARROW, Pattern.VOLLEY, Pattern.DISGUISE, Pattern.AXE_ARROW, Pattern.SUMMON]
	for i in AXE_COUNT:
		axes.append(null)


func axe_spot(i: int) -> Vector2:
	return _area().get_center() + Vector2((i - (AXE_COUNT - 1) * 0.5) * AXE_SPACING, AXE_ROW_Y)


func standing_axes() -> int:
	var n := 0
	for a in axes:
		if a != null and is_instance_valid(a) and not a.is_dead():
			n += 1
	return n


func is_disguised() -> bool:
	return _disguise_left > 0.0


func get_reveal_count() -> int:
	return _reveals


func get_blocked_shots() -> int:
	return _blocked_shots


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		stand_axes()
	return super._get_move_velocity(delta)


## 쓰러진 도끼를 모두 다시 세움 (테스트에서도 직접 호출)
func stand_axes() -> void:
	_restand_left = 0.0
	for i in AXE_COUNT:
		if axes[i] == null or not is_instance_valid(axes[i]) or axes[i].is_dead():
			_pending_slot = i
			if axe_scene != null:
				request_summon(axe_scene, axe_spot(i))
			_pending_slot = -1


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and _pending_slot >= 0:
		var axe := minion as BossPart
		axe.boss = self
		axe.follow_boss = false
		axe.max_hp = maxi(1, roundi(max_hp * axe_hp_ratio))
		axe.hp = axe.max_hp
		axe.died.connect(_on_axe_fallen)
		axes[_pending_slot] = axe
	elif decoy_scene != null and minion.scene_file_path == decoy_scene.resource_path:
		decoys.append(minion)


func _on_axe_fallen(_axe: Enemy) -> void:
	if _restand_left <= 0.0 and not is_dead():
		_restand_left = axe_restand


## 열두 도끼 꿰뚫기: 쏜 쪽 끝에서 첫 끊긴 자리까지 터짐 (테스트에서도 직접 호출) — 반환값 = 터지는 자리 수
func shoot_through_axes(from_left: bool) -> int:
	last_shot.clear()
	var order: Array[int] = []
	for i in AXE_COUNT:
		order.append(i if from_left else AXE_COUNT - 1 - i)
	for i in order:
		if axes[i] == null or not is_instance_valid(axes[i]) or axes[i].is_dead():
			break
		last_shot.append(axe_spot(i))
	if last_shot.is_empty():
		_blocked_shots += 1
		FloatingText.spawn(self, global_position + Vector2(0, -50), "도끼 줄이 끊겨 화살이 막혔다!", Color(0.8, 0.8, 0.7), true)
		return 0
	var start := axe_spot(0 if from_left else AXE_COUNT - 1) + Vector2(-AXE_SPACING if from_left else AXE_SPACING, 0)
	CarryItem.fly(self, start, last_shot[last_shot.size() - 1], arrow_texture, 0.9)
	for k in last_shot.size():
		telegraph_strike(last_shot[k], 18.0, 0.9 + 0.02 * k, axe_arrow_damage, Elements.Type.NONE)
	if last_shot.size() < AXE_COUNT:
		_blocked_shots += 1
	return last_shot.size()


func disguise() -> void:
	if is_disguised() or is_dead():
		return
	_disguise_left = disguise_time
	if beggar_texture != null:
		sprite.texture = beggar_texture
	set_status("", Color.WHITE)
	if decoy_scene != null:
		for i in decoy_count:
			request_summon(decoy_scene, global_position + Vector2.from_angle(TAU * i / decoy_count) * 70.0)
	Fx.burst(self, get_hit_center(), Color(0.8, 0.75, 0.6), 24, 60.0, 0.6)
	GameManager.show_notice("오디세우스가 늙은 거지로 변장해 거지들 사이에 숨었다!", Color(0.9, 0.85, 0.7))


func _end_disguise(revealed: bool) -> void:
	_disguise_left = 0.0
	sprite.texture = _normal_texture
	for d in decoys:
		if is_instance_valid(d) and not d.is_dead():
			d.despawn()
	decoys.clear()
	if revealed:
		_reveals += 1
		super.stun(5.0)
		GameManager.show_notice("정체를 들켰다! 오디세우스가 휘청인다", Color(1.0, 0.85, 0.5))
	set_status("도끼 %d/12" % standing_axes(), Color(0.95, 0.85, 0.6))


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if is_disguised() and not is_dead() and amount > 0:
		_end_disguise(true)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _restand_left > 0.0:
			_restand_left -= delta
			if _restand_left <= 0.0:
				stand_axes()
				GameManager.show_notice("오디세우스가 열두 도끼를 다시 세웠다", Color(0.95, 0.85, 0.6))
		if _disguise_left > 0.0:
			_disguise_left -= delta
			if _disguise_left <= 0.0:
				_end_disguise(false)
		elif Engine.get_physics_frames() % 20 == 0:
			set_status("열두 도끼 %d/12 — 끝의 도끼를 쓰러뜨려 줄을 끊어라" % standing_axes(), Color(0.95, 0.85, 0.6))
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.AXE_ARROW:
			var from_left := global_position.x < _area().get_center().x
			GameManager.show_notice("오디세우스가 열두 도끼 줄을 겨눈다! 도끼 줄 위에서 벗어나라", Color(1.0, 0.85, 0.5))
			shoot_through_axes(from_left)
			if phase_two:
				_after(1.2, func() -> void:
					if not is_dead():
						shoot_through_axes(not from_left))
			return 1.6 if phase_two else 1.3
		Pattern.VOLLEY:
			for i in 7:
				shoot(dir.rotated((i - 3) * 0.13), 210.0, volley_damage, arrow_texture)
			return 0.9
		Pattern.DISGUISE:
			disguise()
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if is_disguised():
		_end_disguise(false)
	super._die()


func _on_phase_two() -> void:
	GameManager.show_notice("오디세우스: 이타카의 왕이 돌아왔다! 열두 도끼 화살이 두 번 날아온다", Color(1.0, 0.8, 0.5))
