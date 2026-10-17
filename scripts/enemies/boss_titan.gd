class_name BossTitan
extends PatternBoss
## 17스테이지 보스: 티탄 — 거인의 감옥 깊은 곳에 쇠사슬로 묶여 있던 고대 거인.
## 양 손목의 쇠사슬 끝에 커다란 원형 쇠 구속구가 달려 있고, 그것을 무기처럼 휘두른다.
##   SLAM  : 내려찍기 — 주변 큰 장판, 튄 돌들이 경기장 곳곳에 날아가 박힘 (CoverRock = 엄폐물)
##   THROW : 바위 던지기 — 예고선 뒤 거대한 바위가 일직선으로 날아감 (ThrownBoulder)
##   CHAIN : 쇠사슬 휘두르기 — 몸 주위를 크게 휩쓰는 고리 장판 (구속구가 도는 범위)
##   WHIP  : 구속구 내리치기 — 플레이어 쪽으로 일직선 장판 2줄
##   SUMMON: 거인 병사 호출
##
## [기믹] 엄폐: 내려찍기로 땅에 박힌 바위 뒤에 숨으면 던진 바위를 그 바위가 대신 맞아 줌 (바위는 두 번 맞으면 부서짐)
##   던진 바위에 직접 맞으면 최대 체력의 boulder_ratio 만큼 큰 피해 (방패로도 못 막음, 대시 중에는 통과)
## 체력 50% 이하: 바위를 연달아 2개 던지고, 내려찍기에서 튀는 돌이 줄어듦

enum Pattern { SLAM, THROW, CHAIN, WHIP, SUMMON }

const MAX_ROCKS := 8

@export var minion_scenes: Array[PackedScene] = []
@export var slam_damage: int = 60
@export var chain_damage: int = 54
@export var whip_damage: int = 50
## 던진 바위 피해 = 플레이어 최대 체력 × boulder_ratio
@export var boulder_ratio: float = 0.45
@export var rocks_per_slam: int = 4

var _rocks_spawned: int = 0
var _throws: int = 0
var _last_boulder: ThrownBoulder


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SLAM, Pattern.THROW, Pattern.CHAIN, Pattern.THROW, Pattern.WHIP, Pattern.SUMMON, Pattern.SLAM, Pattern.THROW]


func get_cover_rocks() -> Array[CoverRock]:
	var rocks: Array[CoverRock] = []
	for node in get_tree().get_nodes_in_group(&"cover_rocks"):
		if node is CoverRock and is_instance_valid(node):
			rocks.append(node as CoverRock)
	return rocks


func get_last_boulder() -> ThrownBoulder:
	return _last_boulder if _last_boulder != null and is_instance_valid(_last_boulder) else null


func get_boulder_damage() -> int:
	return maxi(1, roundi(GameManager.max_hp * boulder_ratio))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.SLAM:
			return slam()
		Pattern.THROW:
			var count := 2 if phase_two else 1
			for i in count:
				_after(0.9 * i, throw_boulder)
			return 1.4 + 0.9 * (count - 1)
		Pattern.CHAIN:
			set_status("쇠사슬 휘두르기", Color(0.8, 0.82, 0.9))
			telegraph_strike(get_hit_center(), 84.0, 1.1, chain_damage, Elements.Type.NONE)
			_after(1.1, func() -> void:
				if not is_dead():
					Fx.shockwave(self, get_hit_center(), Color(0.7, 0.72, 0.8), 90.0, 0.4)
					set_status("", Color.WHITE))
			return 1.6
		Pattern.WHIP:
			var dir := direction_to_player()
			for side in [-1.0, 1.0]:
				for i in 6:
					telegraph_strike(get_hit_center() + dir.orthogonal() * 22.0 * side + dir * (34.0 + 26.0 * i), 16.0, 0.8 + 0.06 * i, whip_damage, Elements.Type.NONE)
			return 1.4
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-70.0 + 140.0 * i, 30.0))
			return 1.0
	return 1.0


## 내려찍기: 주변 장판 + 경기장 곳곳에 바위가 날아가 박힘 (테스트에서도 직접 호출)
func slam() -> float:
	set_status("내려찍기: 돌이 튄다!", Color(0.9, 0.8, 0.6))
	telegraph_strike(get_hit_center(), 54.0, 0.9, slam_damage, Elements.Type.EARTH)
	_after(0.9, _scatter_rocks)
	return 1.5


func _scatter_rocks() -> void:
	if is_dead():
		return
	if _player != null:
		_player.shake_camera(6.0)
	set_status("", Color.WHITE)
	var old := get_cover_rocks()
	var count := rocks_per_slam - (1 if phase_two else 0)
	var excess := old.size() + count - MAX_ROCKS
	for i in maxi(excess, 0):
		old[i].crumble()  # 오래된 바위부터 무너뜨려 최대 MAX_ROCKS 개 유지
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(200, 150), Vector2(400, 300))
	var placed: Array[Vector2] = []
	for i in count:
		var spot := Vector2.ZERO
		for attempt in 16:
			spot = Vector2(randf_range(area.position.x + 20.0, area.end.x - 20.0), randf_range(area.position.y + 30.0, area.end.y - 20.0))
			var ok := spot.distance_to(global_position) > 70.0
			if has_target() and spot.distance_to(_player.global_position) < 26.0:
				ok = false
			for other in placed:
				if spot.distance_to(other) < 50.0:
					ok = false
			if ok:
				break
		placed.append(spot)
		CoverRock.spawn(self, spot, get_hit_center())
		_rocks_spawned += 1


## 바위 던지기: 예고선 뒤 플레이어 쪽으로 일직선
func throw_boulder() -> void:
	if is_dead() or not has_target():
		return
	set_status("바위 던지기! 박힌 바위 뒤로 숨어라", Color(1.0, 0.6, 0.45))
	var from := get_hit_center() + Vector2(0, -26)
	_last_boulder = ThrownBoulder.spawn(self, from, from.direction_to(_player.global_position + Vector2(0, -5)), get_boulder_damage(), 0.9)
	_throws += 1
	_after(1.0, func() -> void:
		if get_status_text().begins_with("바위 던지기"):
			set_status("", Color.WHITE))


func _on_phase_two() -> void:
	GameManager.show_notice("티탄이 쇠사슬을 끊을 듯 날뛴다! 바위를 연달아 던진다", Color(1.0, 0.6, 0.45))
	base_tint = Color(1.15, 0.95, 0.9)
