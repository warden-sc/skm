class_name BossCherubim
extends PatternBoss
## 91스테이지 보스: 에덴의 문지기 케루빔 — 생명나무로 가는 길을 지키는, 네 얼굴과 네 날개의 천사. 곁에는 두루 도는 불칼이 있습니다.
##   FACE    : 플레이어 쪽을 향한 얼굴의 공격 — 사람(빛의 창) · 사자(포효 부채꼴) · 소(돌진) · 독수리(깃털 탄막)
##   WINGS   : 네 날개 바람 — 몸 주위 고리
##   SUMMON  : 불칼의 파수꾼 · 생명나무 정령 · 에덴의 뱀 호출
##
## [기믹] 네 얼굴: 동서남북으로 사람 · 사자 · 소 · 독수리 얼굴이 하나씩 — face_time 초마다 얼굴이 한 칸씩 돌아감
##   플레이어가 「사람 얼굴」 쪽에 있을 때만 피해가 제대로 들어가고, 다른 얼굴 쪽에서는 side_ratio 만 들어감
## [기믹] 두루 도는 불칼: 케루빔 둘레를 불칼이 돌며 길을 막음 — 닿으면 큰 피해 (2페이즈: 불칼 둘)

enum Pattern { FACE, WINGS, SUMMON }
enum Face { MAN, LION, OX, EAGLE }

const FACE_NAMES := ["사람", "사자", "소", "독수리"]
const FACE_COLORS := [Color(1.0, 0.9, 0.5), Color(1.0, 0.6, 0.25), Color(0.7, 0.5, 0.35), Color(0.75, 0.8, 0.95)]
const SWORD_INNER := 34.0
const SWORD_OUTER := 150.0

@export var minion_scenes: Array[PackedScene] = []
@export var feather_texture: Texture2D
@export var spear_damage: int = 104
@export var roar_damage: int = 98
@export var charge_damage: int = 104
@export var feather_damage: int = 64
@export var wing_damage: int = 92
@export var sword_damage: int = 96
@export var face_time: float = 6.0
@export var side_ratio: float = 0.3
@export var sword_speed: float = 0.9

var face_offset: int = 0
var sword_angle: float = 0.0
var _face_left: float = 0.0
var _sword_cd: float = 0.0
var _sword_hits: int = 0
var _guarded: int = 0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.FACE, Pattern.FACE, Pattern.WINGS, Pattern.FACE, Pattern.SUMMON]


func get_sword_hits() -> int:
	return _sword_hits


func get_guarded_count() -> int:
	return _guarded


## at 이 있는 쪽(동 · 남 · 서 · 북)을 바라보는 얼굴
func face_toward(at: Vector2) -> int:
	var d := posmod(roundi((at - get_hit_center()).angle() / (PI * 0.5)), 4)
	return (d + face_offset) % 4


## 사람 얼굴이 바라보는 방향
func human_direction() -> Vector2:
	return Vector2.RIGHT.rotated(posmod(-face_offset, 4) * PI * 0.5)


func sword_count() -> int:
	return 2 if phase_two else 1


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		_face_left = face_time
		_update_status()
	if _charge_left > 0.0:
		_charge_left -= delta
		if has_target() and global_position.distance_to(_player.global_position) < 30.0:
			_player.take_hit(roundi(charge_damage * power), global_position, self)
			_charge_left = 0.0
		return _charge_dir * 280.0
	return super._get_move_velocity(delta)


## 얼굴을 한 칸 돌림 (테스트에서도 직접 호출)
func rotate_faces() -> void:
	face_offset = (face_offset + 1) % 4
	_face_left = face_time * (0.7 if phase_two else 1.0)
	Fx.burst(self, get_hit_center(), FACE_COLORS[Face.MAN], 14, 60.0, 0.5)
	Net.announce("케루빔의 네 얼굴이 돈다 — 사람 얼굴 쪽으로 돌아가라", FACE_COLORS[Face.MAN])
	_update_status()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if amount > 0 and not is_dead() and has_target():
		var face := face_toward(_player.global_position)
		if face != Face.MAN:
			_guarded += 1
			amount = maxi(1, roundi(amount * side_ratio))
			if _immune_text_cooldown <= 0.0:
				_immune_text_cooldown = 0.6
				FloatingText.spawn(self, global_position + Vector2(0, -44), "%s 얼굴이 막음" % FACE_NAMES[face], FACE_COLORS[face])
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		_face_left -= delta
		if _face_left <= 0.0:
			rotate_faces()
		sword_angle = wrapf(sword_angle + sword_speed * (1.4 if phase_two else 1.0) * delta, 0.0, TAU)
		_sword_cd = maxf(_sword_cd - delta, 0.0)
		if has_target() and _sword_cd <= 0.0:
			for k in sword_count():
				if _segment_distance(_player.global_position, k) < 10.0:
					_sword_cd = 0.8
					_sword_hits += 1
					_player.take_hit(roundi(sword_damage * power), get_hit_center(), self)
					Fx.flash(self, _player.global_position, Color(1.0, 0.5, 0.2), 16.0, 0.25)
					break
		queue_redraw()
	super._physics_process(delta)


func _segment_distance(at: Vector2, index: int) -> float:
	var dir := Vector2.from_angle(sword_angle + PI * index)
	var a := get_hit_center() + dir * SWORD_INNER
	var b := get_hit_center() + dir * SWORD_OUTER
	return at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))


func _on_phase_two() -> void:
	Net.announce("케루빔이 날개를 펼친다 — 불칼이 둘이 되어 더 빨리 돈다!", Color(1.0, 0.55, 0.2))


func _update_status() -> void:
	set_status("사람 얼굴: %s쪽" % ["동", "남", "서", "북"][posmod(-face_offset, 4)], FACE_COLORS[Face.MAN])


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.FACE:
			match face_toward(_player.global_position):
				Face.MAN:
					for i in 12:
						telegraph_strike(get_hit_center() + dir * (26.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.HOLY)
				Face.LION:
					for i in 7:
						telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.28) * 52.0, 22.0, 0.75, roar_damage, Elements.Type.FIRE)
				Face.OX:
					_charge_dir = dir
					_charge_left = 0.6
					for i in 9:
						Fx.flash(self, global_position + dir * (20.0 + 20.0 * i), Color(0.8, 0.6, 0.4), 12.0, 0.4)
				Face.EAGLE:
					for i in 9:
						shoot(dir.rotated((i - 4) * 0.14), 160.0, feather_damage, feather_texture, 0.0, Elements.Type.HOLY)
			return 1.1
		Pattern.WINGS:
			for i in 14:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 14.0) * 56.0, 20.0, 0.85, wing_damage, Elements.Type.HOLY)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


## 불칼 · 네 얼굴 표시
func _draw() -> void:
	if is_dead() or not _started:
		return
	var c := to_local(get_hit_center())
	for k in sword_count():
		var dir := Vector2.from_angle(sword_angle + PI * k)
		draw_line(c + dir * SWORD_INNER, c + dir * SWORD_OUTER, Color(1.0, 0.45, 0.15, 0.85), 5.0)
		draw_line(c + dir * SWORD_INNER, c + dir * SWORD_OUTER, Color(1.0, 0.9, 0.5, 0.9), 2.0)
	for d in 4:
		var face := (d + face_offset) % 4
		var at := c + Vector2.RIGHT.rotated(d * PI * 0.5) * 26.0
		draw_circle(at, 4.0 if face == Face.MAN else 2.5, FACE_COLORS[face])
	var h := human_direction().angle()
	draw_arc(c, 30.0, h - PI * 0.25, h + PI * 0.25, 16, Color(1.0, 0.9, 0.5, 0.8), 2.0)
