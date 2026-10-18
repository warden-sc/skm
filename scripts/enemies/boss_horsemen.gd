class_name BossHorsemen
extends PatternBoss
## 85스테이지 보스: 묵시록의 네 기사 — 흰 말(정복) · 붉은 말(전쟁) · 검은 말(기근) · 창백한 말(죽음).
## 한 몸(체력 바 하나)을 네 기사가 차례로 맡음 — 체력이 1/4 씩 깎일 때마다 다음 기사가 달려 나옴 (교대 중 잠깐 무적).
##   정복: 화살 세례 · 면류관의 빛 (부채꼴 탄막, 장판 고리)
##   전쟁: 큰 칼 돌진 · 칼바람 (일직선 · 앞쪽 부채꼴)
##   기근: 저울의 심판 — 맞으면 「굶주림」(포션 회복 0) · 메마른 땅 장판
##   죽음: 큰 낫 · 영혼 탄막
##
## [기믹] 교대: 기사가 바뀔 때마다 패턴이 통째로 바뀜
## [기믹] 죽음의 부활: 「죽음」이 나오면 쓰러진 기사들을 되살리려 revive_time 초 동안 의식을 올림 (머리 위 게이지)
##   그동안 최대 체력의 revive_break 만큼 피해를 주면 의식이 끊기며 휘청, 못 끊으면 최대 체력의 revive_heal 만큼 회복

enum Rider { CONQUEST, WAR, FAMINE, DEATH }
enum Pattern { A, B, C, SUMMON }

const RIDER_NAMES := ["정복 — 흰 말의 기사", "전쟁 — 붉은 말의 기사", "기근 — 검은 말의 기사", "죽음 — 창백한 말의 기사"]
const RIDER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/characters/horseman_conquest.png"),
	preload("res://assets/sprites/characters/horseman_war.png"),
	preload("res://assets/sprites/characters/horseman_famine.png"),
	preload("res://assets/sprites/characters/horseman_death.png"),
]

@export var minion_scenes: Array[PackedScene] = []
@export var arrow_texture: Texture2D
@export var soul_texture: Texture2D
@export var main_damage: int = 98
@export var bolt_damage: int = 62
@export var revive_time: float = 6.0
@export var revive_break: float = 0.06
@export var revive_heal: float = 0.15
@export var famine_time: float = 6.0

var rider: Rider = Rider.CONQUEST
var _swap_left: float = 0.0
var _revive_left: float = 0.0
var _revive_damage: int = 0
var _revive_done: bool = false
var _interrupts: int = 0
var _revives: int = 0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.A, Pattern.B, Pattern.C, Pattern.A, Pattern.SUMMON]
	_apply_rider()


func is_reviving() -> bool:
	return _revive_left > 0.0


func get_interrupt_count() -> int:
	return _interrupts


func get_revive_count() -> int:
	return _revives


func _apply_rider() -> void:
	sprite.texture = RIDER_TEXTURES[rider]
	set_status(RIDER_NAMES[rider], [Color(0.95, 0.95, 1.0), Color(1.0, 0.45, 0.4), Color(0.75, 0.75, 0.6), Color(0.7, 1.0, 0.75)][rider])


func _get_move_velocity(delta: float) -> Vector2:
	if _swap_left > 0.0 or _revive_left > 0.0:
		return Vector2.ZERO
	if _charge_left > 0.0:
		_charge_left -= delta
		if has_target() and global_position.distance_to(_player.global_position) < 30.0:
			_player.take_hit(roundi(main_damage * power), global_position, self)
			_charge_left = 0.0
		return _charge_dir * 300.0
	return super._get_move_velocity(delta)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if _swap_left > 0.0:
		show_immune()
		return
	var before := hp
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if is_dead():
		return
	if _revive_left > 0.0:
		_revive_damage += before - hp
		if _revive_damage >= roundi(max_hp * revive_break):
			_revive_left = 0.0
			_interrupts += 1
			super.stun(5.0)
			GameManager.show_notice("부활의 의식이 끊겼다! 「죽음」이 휘청인다", Color(0.7, 1.0, 0.75))
	var next := clampi(int((1.0 - float(hp) / max_hp) * 4.0), 0, 3)
	if next > int(rider):
		switch_rider(next as Rider)


## 다음 기사로 교대 (테스트에서도 직접 호출)
func switch_rider(next: Rider) -> void:
	rider = next
	_swap_left = 1.2
	_charge_left = 0.0
	Fx.burst(self, get_hit_center(), Color(0.8, 0.8, 0.8), 28, 90.0, 0.6)
	_apply_rider()
	GameManager.show_notice("묵시록의 기사가 바뀐다: %s" % RIDER_NAMES[rider], Color(0.9, 0.9, 0.95))
	if rider == Rider.DEATH and not _revive_done:
		_revive_done = true
		_after(1.3, begin_revive)


func begin_revive() -> void:
	if is_dead():
		return
	_revive_left = revive_time
	_revive_damage = 0
	GameManager.show_notice("「죽음」이 쓰러진 기사들을 되살리려 한다! 몰아쳐서 의식을 끊어라", Color(0.7, 1.0, 0.75))


func _physics_process(delta: float) -> void:
	if not is_dead():
		_swap_left = maxf(_swap_left - delta, 0.0)
		if _revive_left > 0.0:
			_revive_left -= delta
			if _revive_left <= 0.0:
				_revives += 1
				var heal := mini(roundi(max_hp * revive_heal), max_hp - hp)
				hp += heal
				health_changed.emit(hp, max_hp)
				GameManager.show_notice("기사들이 되살아나 「죽음」에게 힘을 보탰다 (+%d)" % heal, Color(0.7, 1.0, 0.75))
		queue_redraw()
	super._physics_process(delta)


func _run_pattern(pattern: int) -> float:
	if not has_target() or _revive_left > 0.0:
		return 0.5
	var dir := direction_to_player()
	if pattern == Pattern.SUMMON:
		if not minion_scenes.is_empty():
			for i in 2:
				request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
		return 0.9
	match rider:
		Rider.CONQUEST:
			if pattern == Pattern.A:
				for i in 9:
					shoot(dir.rotated((i - 4) * 0.12), 210.0, bolt_damage, arrow_texture)
			else:
				for i in 12:
					telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 50.0, 20.0, 0.85, main_damage - 10, Elements.Type.HOLY)
			return 1.0
		Rider.WAR:
			if pattern == Pattern.A:
				_charge_dir = dir
				_charge_left = 0.6
				for i in 10:
					Fx.flash(self, global_position + dir * (20.0 + 20.0 * i), Color(1.0, 0.4, 0.3), 12.0, 0.4)
			else:
				for i in 7:
					telegraph_strike(get_hit_center() + dir.rotated((i - 3) * 0.28) * 48.0, 22.0, 0.7, main_damage, Elements.Type.FIRE)
			return 1.2
		Rider.FAMINE:
			if pattern == Pattern.A:
				var at := _player.global_position
				telegraph_strike(at, 40.0, 1.0, main_damage - 20, Elements.Type.EARTH)
				_after(1.0, func() -> void:
					if not is_dead() and has_target() and _player.global_position.distance_to(at) <= 42.0:
						_player.apply_decay(famine_time)
						FloatingText.spawn(_player, _player.global_position + Vector2(0, -26), "굶주림! (포션 회복 불가)", Color(0.8, 0.75, 0.5), true))
			else:
				for i in 4:
					var at2 := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 60.0)
					GroundZone.spawn_hostile(self, at2, GroundZone.Kind.SAND, 26.0, 5.0, 0.6, roundi(6 * power), 2.0)
			return 1.2
		Rider.DEATH:
			if pattern == Pattern.A:
				for i in 9:
					telegraph_strike(get_hit_center() + dir.rotated((i - 4) * 0.22) * 56.0, 20.0, 0.75, main_damage + 6, Elements.Type.DARK)
			else:
				for i in 16:
					shoot(Vector2.from_angle(TAU * i / 16.0), 115.0, bolt_damage, soul_texture, 0.0, Elements.Type.DARK)
			return 1.1
	return 1.0


## 부활 의식 게이지
func _draw() -> void:
	if _revive_left <= 0.0:
		return
	var w := 50.0
	var need := maxf(max_hp * revive_break, 1.0)
	draw_rect(Rect2(-w * 0.5, sprite.position.y - 52.0, w, 4.0), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(-w * 0.5, sprite.position.y - 52.0, w * clampf(_revive_damage / need, 0.0, 1.0), 4.0), Color(0.6, 1.0, 0.7))
