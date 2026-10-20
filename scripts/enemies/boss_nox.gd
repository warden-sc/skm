class_name BossNox
extends PatternBoss
## 27스테이지 보스: 심연의 군주 녹스 — 빛이 닿지 않는 심연에서 올라온 어둠 그 자체.
##   CLAWS  : 그림자 발톱 — 플레이어 주변에 연달아 솟는 장판
##   VOID   : 공허의 고리 — 몸 주위로 퍼지는 고리 장판 두 겹
##   LUNGE  : 그림자 습격 — 어둠 속으로 사라졌다가 플레이어 곁에서 나타나 베기
##   SUMMON : 그림자 추적자 · 심연의 눈 호출
## (어둠 속에서도 보이도록 녹스의 예고 장판은 어둠 위에 빛나는 원으로 그려짐)
##
## [기믹] 어둠: 보스방이 칠흑같이 어두워 플레이어 주변 작은 원만 보임 (DarknessVeil 셰이더)
## [기믹] 횃불: 보스방 네 곳의 횃불(처음엔 꺼짐)을 밟으면 불이 붙어 주변이 밝아짐
##   - 녹스가 켜진 횃불의 빛 안에 들어오면 「빛에 드러남」: 방어력 -exposed_reduction
##   - 녹스는 extinguish_interval 마다 그림자 손을 뻗어 켜진 횃불 하나를 끔 (예고 후)
## 체력 50% 이하: 횃불을 더 자주 끄고, 그림자 발톱이 늘어남

enum Pattern { CLAWS, VOID, LUNGE, SUMMON }

const DARKNESS_SHADER: Shader = preload("res://assets/shaders/darkness.gdshader")
const TORCH_SPOTS: Array[Vector2] = [Vector2(-150, 20), Vector2(150, 20), Vector2(-150, 170), Vector2(150, 170)]
const PLAYER_LIGHT := 70.0

@export var minion_scenes: Array[PackedScene] = []
@export var claw_damage: int = 62
@export var void_damage: int = 58
@export var lunge_damage: int = 66
## 빛에 드러났을 때 방어력 감소 비율
@export var exposed_reduction: float = 0.6
@export var extinguish_interval: float = 9.0
@export var darkness: float = 0.9

var _torches: Array[AbyssTorch] = []
var _veil: ColorRect
var _area: Rect2
var _placed: bool = false
var _exposed: bool = false
var _base_defense: int = 0
var _extinguish_cooldown: float = 6.0
var _extinguishing: AbyssTorch
var _extinguish_left: float = 0.0
var _extinguished: int = 0
var _hand: Node2D


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.CLAWS, Pattern.VOID, Pattern.LUNGE, Pattern.CLAWS, Pattern.SUMMON]
	_base_defense = defense
	_hand = Node2D.new()
	_hand.top_level = true
	_hand.z_index = 96
	_hand.draw.connect(_draw_hand)
	add_child(_hand)


func get_torches() -> Array[AbyssTorch]:
	var alive: Array[AbyssTorch] = []
	for t in _torches:
		if is_instance_valid(t):
			alive.append(t)
	return alive


func get_veil() -> ColorRect:
	return _veil if _veil != null and is_instance_valid(_veil) else null


func is_exposed() -> bool:
	return _exposed


func get_extinguish_count() -> int:
	return _extinguished


func _get_move_velocity(delta: float) -> Vector2:
	if not _placed:
		_placed = true
		_setup_darkness()
	_update_veil()
	_update_exposed()
	_hand.queue_redraw()
	if _extinguishing != null:
		_extinguish_left -= delta
		if _extinguish_left <= 0.0:
			if is_instance_valid(_extinguishing):
				_extinguishing.set_lit(false)
				_extinguished += 1
			_extinguishing = null
			set_status("", Color.WHITE)
	elif has_target():
		_extinguish_cooldown -= delta
		if _extinguish_cooldown <= 0.0:
			extinguish()
	return super._get_move_velocity(delta)


# ============================================================ 기믹: 어둠 · 횃불
func _setup_darkness() -> void:
	_area = arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(220, 60), Vector2(440, 300))
	var home := global_position
	for spot in TORCH_SPOTS:
		var t := AbyssTorch.spawn(self, (home + spot).clamp(_area.position + Vector2(12, 24), _area.end - Vector2(12, 4)))
		if t != null:
			_torches.append(t)
	var tree := get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	_veil = ColorRect.new()
	_veil.name = "DarknessVeil"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.z_index = 90
	var margin := 160.0
	_veil.position = _area.position - Vector2(margin, margin)
	_veil.size = _area.size + Vector2(margin, margin) * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = DARKNESS_SHADER
	mat.set_shader_parameter(&"darkness", darkness)
	_veil.material = mat
	_veil.add_to_group(&"storm_fields")  # 스테이지가 바뀌면 함께 정리
	root.add_child(_veil)
	Net.announce("보스방이 어둠에 잠겼다! 횃불을 밟아 불을 밝혀라", Color(0.75, 0.6, 1.0))


func _update_veil() -> void:
	if get_veil() == null:
		return
	var lights := PackedVector2Array()
	var radii := PackedFloat32Array()
	if has_target():
		lights.append(_player.global_position + Vector2(0, -8) - _veil.position)
		radii.append(PLAYER_LIGHT)
	for t in get_torches():
		if t.lit and lights.size() < 8:
			lights.append(t.global_position + Vector2(0, -16) - _veil.position)
			radii.append(AbyssTorch.LIGHT_RADIUS)
	while lights.size() < 8:
		lights.append(Vector2(-9999, -9999))
		radii.append(1.0)
	var mat := _veil.material as ShaderMaterial
	mat.set_shader_parameter(&"lights", lights)
	mat.set_shader_parameter(&"radii", radii)
	mat.set_shader_parameter(&"count", 8)


## 켜진 횃불의 빛 안에 들어오면 방어력 감소
func _update_exposed() -> void:
	var now := false
	for t in get_torches():
		if t.lit and t.global_position.distance_to(get_hit_center()) <= AbyssTorch.LIGHT_RADIUS:
			now = true
			break
	if now == _exposed:
		return
	_exposed = now
	defense = roundi(_base_defense * (1.0 - exposed_reduction)) if now else _base_defense
	base_tint = Color(1.4, 1.3, 1.5) if now else Color.WHITE
	if now:
		FloatingText.spawn(self, global_position + Vector2(0, -56), "빛에 드러남! 방어력 -%d%%" % roundi(exposed_reduction * 100.0), Color(1.0, 0.9, 0.6), true)


## 그림자 손: 켜진 횃불 하나를 예고 후 끔 (테스트에서도 직접 호출)
func extinguish() -> void:
	_extinguish_cooldown = extinguish_interval * (0.7 if phase_two else 1.0)
	var target: AbyssTorch = null
	for t in get_torches():
		if t.lit and (target == null or t.global_position.distance_to(global_position) < target.global_position.distance_to(global_position)):
			target = t
	if target == null:
		return
	_extinguishing = target
	_extinguish_left = 1.2
	set_status("그림자 손이 횃불을 끈다!", Color(0.75, 0.6, 1.0))


func _draw_hand() -> void:
	if _extinguishing == null or not is_instance_valid(_extinguishing):
		return
	var from := get_hit_center()
	var to := _extinguishing.global_position + Vector2(0, -16)
	var t := clampf(1.0 - _extinguish_left / 1.2, 0.0, 1.0)
	var tip := from.lerp(to, t)
	_hand.draw_line(from, tip, Color(0.35, 0.15, 0.55, 0.9), 5.0)
	_hand.draw_line(from, tip, Color(0.75, 0.5, 1.0, 0.8), 1.5)
	_hand.draw_circle(tip, 5.0, Color(0.2, 0.08, 0.3, 0.95))


func _glow_strike(at: Vector2, radius: float, delay: float, damage: int) -> void:
	var s := telegraph_strike(at, radius, delay, damage, Elements.Type.DARK)
	if s != null:
		s.z_index = 92  # 어둠 위에서 빛나는 예고


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.CLAWS:
			var n := 6 if phase_two else 4
			for i in n:
				_after(0.2 * i, func() -> void:
					if not is_dead() and has_target():
						_glow_strike(_player.global_position, 20.0, 0.6, claw_damage))
			return 0.6 + 0.2 * n
		Pattern.VOID:
			for ring in 2:
				for i in 10:
					_glow_strike(get_hit_center() + Vector2.from_angle(TAU * i / 10.0 + ring * 0.3) * (44.0 + 36.0 * ring), 18.0, 0.8 + 0.3 * ring, void_damage)
			return 1.5
		Pattern.LUNGE:
			var at := _player.global_position + Vector2.from_angle(randf() * TAU) * 40.0
			global_position = at.clamp(_area.position, _area.end) if _area.has_area() else at
			_glow_strike(_player.global_position, 26.0, 0.55, lunge_damage)
			return 1.0
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	if get_veil() != null:
		var tween := _veil.create_tween()
		tween.tween_property(_veil, "modulate:a", 0.0, 1.0)
		tween.tween_callback(_veil.queue_free)
	for t in get_torches():
		t.set_lit(true)
	super._die()


func _on_phase_two() -> void:
	Net.announce("녹스: 빛은 언젠가 꺼진다… 횃불이 더 빨리 꺼진다", Color(0.75, 0.6, 1.0))
