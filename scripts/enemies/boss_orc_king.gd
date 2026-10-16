class_name BossOrcKing
extends PatternBoss
## 6스테이지 보스: 오크킹 — 머리에 금관을 쓴 거대 오크. (기믹은 아직 미정 → 패턴만)
##   SLAM    : 도끼를 치켜든 뒤 땅을 내려찍어 주변 큰 장판 + 돌 파편 고리
##   AXE     : 손도끼 투척 (2페이즈 3개)
##   CHARGE  : 몸을 웅크렸다가 플레이어에게 돌진
##   WAR_CRY : "전군, 돌격!" 오크 전사 · 홉고블린 호출
## 체력 50% 이하: 분노 — 이동·돌진 강화, 도끼 수 증가

enum Pattern { SLAM, AXE, CHARGE, WAR_CRY }

@export var axe_texture: Texture2D
@export var rock_texture: Texture2D
@export var minion_scenes: Array[PackedScene] = []
@export var slam_damage: int = 44
@export var axe_damage: int = 30

var _charge_dir: Vector2 = Vector2.ZERO
var _charging: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SLAM, Pattern.AXE, Pattern.CHARGE, Pattern.WAR_CRY, Pattern.AXE, Pattern.SLAM, Pattern.CHARGE]


func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.SLAM:
			set_status("")
			telegraph_strike(get_hit_center(), 64.0, 1.0, slam_damage, Elements.Type.EARTH)
			_after(1.0, _slam_rocks)
			return 1.5
		Pattern.AXE:
			var count := 3 if phase_two else 1
			for i in count:
				_after(0.25 * i, _throw_axe)
			return 0.4 + 0.25 * count
		Pattern.CHARGE:
			_charging = false
			_after(0.7, _begin_charge)
			return 1.4
		Pattern.WAR_CRY:
			_war_cry()
			return 1.0
	return 1.0


func _casting_velocity(_delta: float) -> Vector2:
	if _charging:
		Fx.burst(self, get_hit_center() + Vector2(0, 14), Color(0.75, 0.55, 0.3), 3, 25.0, 0.4, Vector2(0, 60))
		return _charge_dir * move_speed * (6.0 if phase_two else 5.0)
	return Vector2.ZERO


func _begin_charge() -> void:
	if is_dead() or not has_target():
		return
	_charge_dir = direction_to_player()
	_charging = true
	_after(0.55, func() -> void: _charging = false)


func _slam_rocks() -> void:
	if is_dead():
		return
	for i in 16:
		shoot(Vector2.RIGHT.rotated(TAU * i / 16.0), 110.0, axe_damage - 8, rock_texture, 0.0, Elements.Type.EARTH)
	if _player != null:
		_player.shake_camera(6.0)


func _throw_axe() -> void:
	if is_dead() or not has_target():
		return
	shoot(direction_to_player().rotated(randf_range(-0.12, 0.12)), 170.0, axe_damage, axe_texture)


func _war_cry() -> void:
	set_status("전군, 돌격!", Color(1.0, 0.75, 0.4))
	_after(1.2, set_status.bind("", Color.WHITE))
	if minion_scenes.is_empty():
		return
	for i in (3 if phase_two else 2):
		request_summon(minion_scenes.pick_random(), global_position + Vector2.from_angle(TAU * i / 3.0) * 50.0)
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.7, 0.3), 70.0, 0.4)
	if _player != null:
		_player.shake_camera(3.0)


func _on_phase_two() -> void:
	GameManager.show_notice("오크킹이 분노했다!", Color(1.0, 0.5, 0.3))
	Fx.explosion(self, get_hit_center(), Color(1.0, 0.5, 0.3), 70.0, 3)
