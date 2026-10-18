class_name BossArachne
extends PatternBoss
## 46스테이지 보스: 거미 여인 아라크네 — 여신과 베 짜기를 겨뤘다가 거미가 된 직조공.
##   SILK    : 거미줄 탄 — 맞으면 감속되는 실 탄 부채꼴
##   POUNCE  : 덮치기 — 플레이어 자리 예고 후 그 자리로 뛰어내림
##   FANGS   : 독니 — 플레이어 쪽 일직선 장판 (독)
##   SUMMON  : 거미 시녀 · 동굴 거미 호출
##
## [기믹 1] 직조: weave_interval 초마다 보스방 바닥에 거미줄이 하나씩 깔림 (최대 MAX_WEBS, 플레이어 근처에 더 자주)
##   거미줄을 밟으면 느려지고, 오래 서 있으면 묶임
## [기믹 2] 베틀: 보스방 위쪽의 베틀(체력 따로)이 직조의 원천 → 부수면 직조가 멈추고 깔린 거미줄이 걷히며 아라크네가 휘청임
## 체력 50% 이하: 더 빨리 짬 (베틀이 남아 있다면)

enum Pattern { SILK, POUNCE, FANGS, SUMMON }

const MAX_WEBS := 14

@export var loom_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var silk_texture: Texture2D
@export var silk_damage: int = 52
@export var pounce_damage: int = 88
@export var fang_damage: int = 80
@export var weave_interval: float = 3.0
@export var loom_hp_ratio: float = 0.05

var loom: BossPart
var _weave_left: float = 2.0
var _loom_broken: bool = false
var _started: bool = false
var _pounce_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SILK, Pattern.POUNCE, Pattern.FANGS, Pattern.SUMMON, Pattern.SILK, Pattern.POUNCE]
	burn_damage = 8
	burn_duration = 2.5
	burn_is_poison = true


func get_loom() -> BossPart:
	return loom if loom != null and is_instance_valid(loom) and not loom.is_dead() else null


func is_loom_broken() -> bool:
	return _loom_broken


func get_webs() -> Array[WebPatch]:
	var list: Array[WebPatch] = []
	for node in get_tree().get_nodes_in_group(&"webs"):
		var w := node as WebPatch
		if w != null and not w.is_queued_for_deletion():
			list.append(w)
	return list


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		if loom_scene != null:
			request_summon(loom_scene, Vector2(_area().get_center().x, _area().position.y + 40))
	if not _loom_broken and has_target():
		_weave_left -= delta
		if _weave_left <= 0.0:
			_weave_left = weave_interval * (0.7 if phase_two else 1.0)
			weave()
	return super._get_move_velocity(delta)


# ============================================================ 기믹 1: 직조
func weave() -> WebPatch:
	var webs := get_webs()
	if webs.size() >= MAX_WEBS:
		webs[0].queue_free()
	var a := _area()
	var at := Vector2(randf_range(a.position.x + 30, a.end.x - 30), randf_range(a.position.y + 40, a.end.y - 30))
	if has_target() and randf() < 0.5:
		at = (_player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 60.0)).clamp(a.position, a.end)
	return WebPatch.spawn(self, at, randf_range(24.0, 36.0))


# ============================================================ 기믹 2: 베틀
func register_minion(minion: Enemy) -> void:
	if minion is BossPart and get_loom() == null and not _loom_broken:
		loom = minion as BossPart
		loom.boss = self
		loom.follow_boss = false
		loom.max_hp = maxi(1, roundi(max_hp * loom_hp_ratio))
		loom.died.connect(_on_loom_broken)


func _on_loom_broken(_enemy: Enemy) -> void:
	if is_dead():
		return
	_loom_broken = true
	loom = null
	for w in get_webs():
		w.fade(1.5)
	_stun_left = 3.0
	set_status("베틀이 부서졌다 — 직조가 멈췄다", Color(0.95, 0.95, 1.0))
	GameManager.show_notice("베틀을 부쉈다! 거미줄이 걷히고 아라크네가 휘청인다", Color(0.95, 0.95, 1.0))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.SILK:
			var aim := direction_to_player()
			for i in 7:
				shoot(aim.rotated((i - 3) * 0.17), 135.0, silk_damage, silk_texture, 1.0, Elements.Type.NATURE)
			return 1.0
		Pattern.POUNCE:
			_pounce_at = _player.global_position
			telegraph_strike(_pounce_at, 34.0, 0.9, pounce_damage, Elements.Type.DARK)
			_after(0.85, func() -> void:
				if not is_dead():
					global_position = _pounce_at.clamp(_area().position, _area().end)
					WebPatch.spawn(self, global_position, 30.0))
			return 1.3
		Pattern.FANGS:
			var dir := direction_to_player()
			for i in 9:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 15.0, 0.6 + 0.04 * i, fang_damage, Elements.Type.NATURE)
			return 1.1
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("아라크네: 내 베는 신보다 아름답다! 더 빨리 짠다", Color(0.95, 0.95, 1.0))
