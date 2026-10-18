class_name BossTrumpetAngel
extends PatternBoss
## 89스테이지 보스: 일곱 나팔의 천사 — 나팔을 불 때마다 정해진 순서대로 재앙이 내리고, 다섯째 나팔에 무저갱이 열린다.
##   TRUMPET : 나팔을 들어 trumpet_windup 초 뒤 불어 다음 재앙을 내림
##   SPEAR   : 빛의 창 (일직선)
##   CHORUS  : 천상의 합창 — 몸 주위 고리
##   FEATHER : 깃털 탄막
##
## [기믹] 일곱 나팔의 재앙 (순서대로 돌아감): ① 우박과 불 → ② 피로 물든 바다(보스방 아래쪽이 피의 장판) → ③ 쓴 별(독 장판)
##   → ④ 어두워진 해(시야가 좁아짐) → ⑤ 무저갱(메뚜기가 기어 나옴) → 다시 ①
## [기믹] 나팔 부수기: 천사가 든 나팔(체력 따로)을 부수면 다음 재앙 하나가 끊기고 천사가 휘청 — 나팔은 trumpet_regrow 초 뒤 다시 듦
## 체력 50% 이하: 나팔을 더 자주 붊

enum Pattern { TRUMPET, SPEAR, CHORUS, FEATHER }
enum Plague { HAIL, BLOOD_SEA, WORMWOOD, DARK_SUN, ABYSS }

const PLAGUE_NAMES := ["우박과 불", "피로 물든 바다", "쓴 별", "어두워진 해", "무저갱"]

@export var trumpet_scene: PackedScene
@export var locust_scene: PackedScene
@export var feather_texture: Texture2D
@export var hail_damage: int = 92
@export var spear_damage: int = 100
@export var chorus_damage: int = 86
@export var feather_damage: int = 62
@export var trumpet_hp_ratio: float = 0.025
@export var trumpet_windup: float = 2.0
@export var trumpet_regrow: float = 8.0
@export var dark_time: float = 8.0

var trumpet: BossPart
var next_plague: int = Plague.HAIL
var veil: FogVeil
var _blown: int = 0
var _skipped: int = 0
var _windup_left: float = 0.0
var _regrow_left: float = 0.0
var _dark_left: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.TRUMPET, Pattern.SPEAR, Pattern.FEATHER, Pattern.CHORUS]


func has_trumpet() -> bool:
	return trumpet != null and is_instance_valid(trumpet) and not trumpet.is_dead()


func get_blown_count() -> int:
	return _blown


func get_skipped_count() -> int:
	return _skipped


func is_dark() -> bool:
	return _dark_left > 0.0


func _area() -> Rect2:
	return arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(320, 180), Vector2(640, 360))


func _get_move_velocity(delta: float) -> Vector2:
	if not _started and has_target():
		_started = true
		_raise_trumpet()
	if _windup_left > 0.0:
		return Vector2.ZERO
	return super._get_move_velocity(delta)


func _raise_trumpet() -> void:
	if trumpet_scene != null and not is_dead():
		request_summon(trumpet_scene, global_position + Vector2(20, -24))


func register_minion(minion: Enemy) -> void:
	if trumpet_scene != null and minion.scene_file_path == trumpet_scene.resource_path:
		trumpet = minion as BossPart
		trumpet.boss = self
		trumpet.follow_boss = true
		trumpet.anchor_offset = Vector2(20, -24)
		trumpet.max_hp = maxi(1, roundi(max_hp * trumpet_hp_ratio))
		trumpet.hp = trumpet.max_hp
		trumpet.died.connect(_on_trumpet_broken)
		_update_status()


func _on_trumpet_broken(_t: Enemy) -> void:
	if is_dead():
		return
	trumpet = null
	_regrow_left = trumpet_regrow
	_skipped += 1
	_windup_left = 0.0
	GameManager.show_notice("나팔을 부쉈다! 「%s」의 재앙이 끊긴다" % PLAGUE_NAMES[next_plague], Color(1.0, 0.9, 0.6))
	next_plague = (next_plague + 1) % PLAGUE_NAMES.size()
	super.stun(5.0)
	_update_status()


## 나팔을 불어 다음 재앙을 내림 (테스트에서도 직접 호출) — 나팔이 없으면 false
func blow_trumpet() -> bool:
	if not has_trumpet() or is_dead():
		return false
	var plague := next_plague
	next_plague = (next_plague + 1) % PLAGUE_NAMES.size()
	_blown += 1
	Fx.shockwave(self, get_hit_center(), Color(1.0, 0.9, 0.5), 140.0, 0.6)
	GameManager.show_notice("%d번째 나팔: 「%s」" % [_blown, PLAGUE_NAMES[plague]], Color(1.0, 0.9, 0.6))
	var area := _area().grow(-20.0)
	match plague:
		Plague.HAIL:
			for i in 12:
				telegraph_strike(Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y)), 22.0, 0.9 + 0.05 * i, hail_damage, Elements.Type.FIRE)
		Plague.BLOOD_SEA:
			var y := area.get_center().y + 30.0
			var x := area.position.x + 30.0
			while x < area.end.x:
				var yy := y
				while yy < area.end.y:
					GroundZone.spawn_hostile(self, Vector2(x, yy), GroundZone.Kind.CURSE, 32.0, 6.0, 0.7, roundi(8 * power), 2.0)
					yy += 56.0
				x += 56.0
		Plague.WORMWOOD:
			for i in 5:
				var at := _player.global_position + Vector2.from_angle(TAU * i / 5.0) * randf_range(20.0, 80.0) if has_target() else area.get_center()
				var strike := telegraph_strike(at, 26.0, 1.0, hail_damage - 20, Elements.Type.NATURE)
				if strike != null:
					strike.burn_poison = true
					strike.burn_damage = 10
					strike.burn_duration = 3.0
		Plague.DARK_SUN:
			_dark_left = dark_time
			if veil == null or not is_instance_valid(veil):
				veil = FogVeil.spawn(self, _area())
		Plague.ABYSS:
			if locust_scene != null:
				for i in 3:
					request_summon(locust_scene, area.get_center() + Vector2.from_angle(TAU * i / 3.0) * 40.0)
	_update_status()
	return true


func _physics_process(delta: float) -> void:
	if not is_dead() and _started:
		if _windup_left > 0.0:
			_windup_left -= delta
			if _windup_left <= 0.0:
				blow_trumpet()
		if not has_trumpet() and _regrow_left > 0.0:
			_regrow_left -= delta
			if _regrow_left <= 0.0:
				_raise_trumpet()
		if _dark_left > 0.0:
			_dark_left -= delta
			if veil != null and is_instance_valid(veil) and has_target():
				veil.light_at = _player.global_position
				veil.light_radius = 90.0
			if _dark_left <= 0.0 and veil != null and is_instance_valid(veil):
				veil.queue_free()
				veil = null
	super._physics_process(delta)


func _update_status() -> void:
	set_status("다음 나팔: 「%s」%s" % [PLAGUE_NAMES[next_plague], "" if has_trumpet() else " (나팔 없음)"], Color(1.0, 0.9, 0.6))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.TRUMPET:
			if not has_trumpet():
				return _run_pattern(Pattern.FEATHER)
			_windup_left = trumpet_windup * (0.75 if phase_two else 1.0)
			GameManager.show_notice("천사가 나팔을 든다 — 다음 재앙: 「%s」 (나팔을 부수면 끊긴다)" % PLAGUE_NAMES[next_plague], Color(1.0, 0.9, 0.6))
			return _windup_left + 0.3
		Pattern.SPEAR:
			for i in 12:
				telegraph_strike(get_hit_center() + dir * (24.0 + 22.0 * i), 14.0, 0.6 + 0.03 * i, spear_damage, Elements.Type.HOLY)
			return 1.1
		Pattern.CHORUS:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 52.0, 20.0, 0.85, chorus_damage, Elements.Type.HOLY)
			return 1.2
		Pattern.FEATHER:
			for w in 2:
				_after(0.3 * w, func() -> void:
					if is_dead():
						return
					for i in 14:
						shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 125.0, feather_damage, feather_texture, 0.0, Elements.Type.HOLY))
			return 1.1
	return 1.0


func _die() -> void:
	if veil != null and is_instance_valid(veil):
		veil.queue_free()
	super._die()


func _on_phase_two() -> void:
	pattern_order = [Pattern.TRUMPET, Pattern.SPEAR, Pattern.TRUMPET, Pattern.FEATHER, Pattern.CHORUS]
	GameManager.show_notice("천사가 하늘을 우러른다 — 나팔을 더 자주 분다", Color(1.0, 0.9, 0.6))
