class_name BossTwin
extends PatternBoss
## 25스테이지 보스: 해와 달의 쌍둥이 「솔 & 루나」 — 한 몸처럼 싸우는 두 신관.
## 솔(해, role = SOL)이 보스방에 나타나면서 루나(달, role = LUNA)를 불러냅니다. 보스 체력 바는 솔, 루나는 머리 위 작은 체력 바.
##   솔  : 근접형 — 태양 돌진 · 플레어(몸 주위 불꽃 고리) · 햇살(일직선) · 태양 사제 호출
##   루나: 원거리형 — 거리를 벌리며 달빛 탄막 · 초승달 화살 · 서리 장판 · 월광 궁수 호출
##
## [기믹] 쌍둥이: 한쪽 체력이 다 닳으면 죽지 않고 「쓰러짐」 (공격이 닿지 않음)
##   - 남은 쪽이 revive_time 안에 쓰러지지 않으면, 쓰러진 쪽을 최대 체력의 revive_ratio 로 되살림
##   - 둘 다 쓰러져야(한쪽이 쓰러진 동안 다른 쪽도 쓰러뜨려야) 비로소 함께 소멸 → 두 체력을 비슷하게 깎아 거의 동시에
## [기믹] 공명: 둘이 resonance_range 안으로 붙으면 둘 다 방어력 +resonance_defense (둘 사이에 빛줄기)
## 체력 50% 이하: 각자 패턴 강화

enum Role { SOL, LUNA }
enum Pattern { CHARGE, FLARE, SUNBEAM, SUMMON_SUN, MOONBOLT, CRESCENT, FROST, SUMMON_MOON }

@export var role: Role = Role.SOL
@export var partner_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var orb_texture: Texture2D
@export var arrow_texture: Texture2D
@export var melee_damage: int = 62
@export var bolt_damage: int = 34
@export var revive_time: float = 10.0
@export var revive_ratio: float = 0.5
@export var resonance_range: float = 90.0
@export var resonance_defense: int = 20

var partner: BossTwin
var _partner_requested: bool = false
var _fallen: bool = false
var _revive_left: float = -1.0
var _revives: int = 0
var _base_defense: int = 0
var _base_contact: int = 0
var _resonating: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_windup: float = 0.0
var _charge_left: float = 0.0


func _ready() -> void:
	super._ready()
	_base_defense = defense
	_base_contact = contact_damage
	if role == Role.SOL:
		pattern_order = [Pattern.CHARGE, Pattern.FLARE, Pattern.SUNBEAM, Pattern.CHARGE, Pattern.SUMMON_SUN]
	else:
		pattern_order = [Pattern.MOONBOLT, Pattern.CRESCENT, Pattern.FROST, Pattern.MOONBOLT, Pattern.SUMMON_MOON]
		_btimer = chase_time * 1.5  # 둘이 동시에 쓰지 않도록 엇갈림


func is_fallen() -> bool:
	return _fallen


func is_resonating() -> bool:
	return _resonating


func get_revive_count() -> int:
	return _revives


func is_reviving_partner() -> bool:
	return _revive_left > 0.0


func has_partner() -> bool:
	return partner != null and is_instance_valid(partner) and not partner.is_dead()


func _get_move_velocity(delta: float) -> Vector2:
	if role == Role.SOL and not _partner_requested and partner_scene != null:
		_partner_requested = true
		request_summon(partner_scene, global_position + Vector2(90, 20))
	queue_redraw()
	_update_resonance()
	if _fallen:
		return Vector2.ZERO
	if _revive_left > 0.0:
		_revive_left -= delta
		set_status("%.0f초 안에 나를 쓰러뜨리지 않으면 %s(이)가 되살아난다!" % [ceilf(_revive_left), partner.display_name if has_partner() else "?"], Color(1.0, 0.85, 0.5))
		if _revive_left <= 0.0:
			_revive_left = -1.0
			set_status("", Color.WHITE)
			if has_partner() and partner.is_fallen():
				partner.revive()
	return super._get_move_velocity(delta)


func register_minion(minion: Enemy) -> void:
	if minion is BossTwin and partner == null:
		partner = minion as BossTwin
		partner.partner = self
		partner.max_hp = max_hp


# ============================================================ 기믹: 쌍둥이
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_dead() or amount <= 0:
		return
	if _fallen:
		show_immune()
		return
	var lethal := calc_damage(amount, armor_pen) >= hp
	if lethal and has_partner():
		if partner.is_fallen():
			# 둘 다 쓰러짐 → 함께 소멸 (먼저 쓰러져 있던 쪽부터)
			var other := partner
			_revive_left = -1.0
			super.take_damage(amount, knockback, is_crit, armor_pen)
			if is_instance_valid(other) and not other.is_dead():
				other._die()
			return
		hp = 0
		health_changed.emit(hp, max_hp)
		_fall()
		return
	super.take_damage(amount, knockback, is_crit, armor_pen)


func _fall() -> void:
	_fallen = true
	_revive_left = -1.0
	contact_damage = 0
	_charge_left = 0.0
	_charge_windup = 0.0
	base_tint = Color(0.45, 0.45, 0.5)
	sprite.rotation = 0.5
	immune_text = "쓰러짐 — 다른 쪽을 쓰러뜨려라!"
	set_status("쓰러졌다…", Color(0.7, 0.7, 0.75))
	GameManager.show_notice("%s 쓰러짐! %d초 안에 %s도 쓰러뜨려야 한다!" % [display_name, roundi(revive_time), partner.display_name], Color(1.0, 0.85, 0.5))
	partner.start_revive()


## 짝이 쓰러짐 → revive_time 뒤 되살림
func start_revive() -> void:
	_revive_left = revive_time


func revive() -> void:
	if not _fallen or is_dead():
		return
	_fallen = false
	_revives += 1
	hp = maxi(1, roundi(max_hp * revive_ratio))
	health_changed.emit(hp, max_hp)
	contact_damage = _base_contact
	base_tint = Color.WHITE
	sprite.rotation = 0.0
	immune_text = "공중! 활만 닿음"
	set_status("", Color.WHITE)
	GameManager.show_notice("%s(이)가 되살아났다! (체력 %d%%)" % [display_name, roundi(revive_ratio * 100.0)], Color(1.0, 0.6, 0.5))
	Fx.explosion(self, get_hit_center(), Color(1.0, 0.9, 0.6) if role == Role.SOL else Color(0.7, 0.8, 1.0), 40.0, 3)


func _update_resonance() -> void:
	var now := has_partner() and not _fallen and not partner.is_fallen() and global_position.distance_to(partner.global_position) <= resonance_range
	if now == _resonating:
		return
	_resonating = now
	defense = _base_defense + (resonance_defense if now else 0)
	if now and role == Role.SOL:
		FloatingText.spawn(self, global_position + Vector2(0, -50), "공명! 방어력 +%d" % Balance.scale(resonance_defense), Color(1.0, 0.95, 0.7), true)


func _draw() -> void:
	if is_dead():
		return
	if role == Role.LUNA:
		# 루나 체력 바 (보스 체력 바는 솔)
		var w := 34.0
		var ratio := float(hp) / float(maxi(max_hp, 1))
		draw_rect(Rect2(-w * 0.5, -62.0, w, 3.0), Color(0.08, 0.08, 0.12, 0.85))
		draw_rect(Rect2(-w * 0.5, -62.0, w * ratio, 3.0), Color(0.6, 0.75, 1.0))
	elif _resonating and has_partner():
		var to := partner.get_hit_center() - global_position
		var from := get_hit_center() - global_position
		draw_line(from, to, Color(1.0, 0.95, 0.7, 0.35 + 0.25 * sin(_anim_time * 10.0)), 3.0)


# ============================================================ 이동 · 패턴
## 루나는 거리를 벌림
func _chase_velocity(delta: float) -> Vector2:
	if role == Role.SOL:
		return super._chase_velocity(delta)
	var away := _player.global_position.direction_to(global_position)
	var dist := distance_to_player()
	var radial := away * (1.0 if dist < 140.0 else -1.0) * (0.0 if absf(dist - 140.0) < 15.0 else 1.0)
	return (radial + away.orthogonal() * 0.6).normalized() * move_speed


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.CHARGE:
			_charge_dir = direction_to_player()
			_charge_windup = 0.5
			_charge_left = 0.0
			for i in 5:
				telegraph_strike(get_hit_center() + _charge_dir * (30.0 + 30.0 * i), 18.0, 0.5 + 0.07 * i, melee_damage, Elements.Type.FIRE)
			return 1.4
		Pattern.FLARE:
			for i in (12 if phase_two else 9):
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / (12.0 if phase_two else 9.0)) * 50.0, 18.0, 0.85, melee_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.SUNBEAM:
			var dir := direction_to_player()
			for i in 8:
				telegraph_strike(get_hit_center() + dir * (26.0 + 26.0 * i), 16.0, 0.7 + 0.04 * i, melee_damage, Elements.Type.HOLY)
			return 1.2
		Pattern.MOONBOLT:
			for w in (2 if phase_two else 1):
				_after(0.3 * w, func() -> void:
					if is_dead() or _fallen:
						return
					for i in 14:
						shoot(Vector2.from_angle(TAU * i / 14.0 + w * 0.22), 110.0, bolt_damage, orb_texture, 0.0, Elements.Type.ICE))
			return 1.0
		Pattern.CRESCENT:
			var aim := direction_to_player()
			for i in 5:
				shoot(aim.rotated((i - 2) * 0.16), 220.0, bolt_damage + 6, arrow_texture, 0.0, Elements.Type.ICE)
			return 0.8
		Pattern.FROST:
			for i in 5:
				telegraph_strike(_player.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0)), 20.0, 0.9 + 0.08 * i, melee_damage - 10, Elements.Type.ICE, 1.2)
			return 1.3
		Pattern.SUMMON_SUN, Pattern.SUMMON_MOON:
			if not minion_scenes.is_empty():
				request_summon(minion_scenes.pick_random(), global_position + Vector2(0, 30))
			return 0.8
	return 1.0


func _casting_velocity(delta: float) -> Vector2:
	if _charge_windup > 0.0:
		_charge_windup -= delta
		if _charge_windup <= 0.0:
			_charge_left = 0.4
		return Vector2.ZERO
	if _charge_left > 0.0:
		_charge_left -= delta
		return _charge_dir * 360.0
	return Vector2.ZERO


func _on_phase_two() -> void:
	GameManager.show_notice("%s: 해와 달은 결코 떨어지지 않는다!" % display_name, Color(1.0, 0.9, 0.6) if role == Role.SOL else Color(0.7, 0.8, 1.0))
