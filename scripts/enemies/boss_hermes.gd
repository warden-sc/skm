class_name BossHermes
extends PatternBoss
## 40스테이지 보스: 전령의 신 헤르메스 — 날개 달린 신발과 뱀 지팡이(카두케우스)의 신들의 전령이자 도둑의 신.
##   CADUCEUS : 뱀 지팡이 — 두 갈래로 휘감기며 퍼지는 탄
##   KICK     : 질풍 차기 — 플레이어 쪽 일직선 장판
##   STEAL    : 도둑의 손 — 플레이어 발밑 예고, 그때 그 자리에 있으면 손에 든 무기를 빼앗김
##   LETTERS  : 전령의 편지 — 편지 3통을 보스방 구석으로 날려 보냄
##   SUMMON   : 사티로스 · 님프 호출
##
## [기믹 1] 신속: 잔상을 남기며 매우 빠르게 움직이는 동안엔 피해를 moving_ratio 만 받음 「너무 빠르다!」
##   패턴을 쓰려고 멈춘 동안에만 제대로 맞음
## [기믹 2] 도둑의 손: 손에 든 무기를 훔쳐 감(무기가 하나뿐이면 골드를 훔침). 훔친 뒤 최대 체력의 recover_ratio 만큼
##   피해를 주면 돌려받음 → 그동안은 남은 무기로 싸워야 함 (헤르메스가 쓰러지면 무조건 돌려받음)
## [기믹 3] 전령의 편지: 날아가는 편지(체력 따로)가 구석에 도착하면 「전령의 축복」 — 이동 속도·공격력이 오름 (최대 5중첩)
##   → 날아가는 동안 쏘아 떨어뜨려야 함
## 체력 50% 이하: 편지가 4통, 더 빠르게 날아감

enum Pattern { CADUCEUS, KICK, STEAL, LETTERS, SUMMON }

const MAX_BLESSINGS := 5

@export var letter_scene: PackedScene
@export var minion_scenes: Array[PackedScene] = []
@export var snake_texture: Texture2D
@export var snake_damage: int = 50
@export var kick_damage: int = 76
@export var steal_damage: int = 40
@export var moving_ratio: float = 0.35
@export var recover_ratio: float = 0.03
@export var letter_speed: float = 55.0
@export var letter_hp_ratio: float = 0.008

var stolen: WeaponData
var stolen_gold: int = 0
var blessings: int = 0
var _recover_left: int = 0
var _letters: Dictionary = {}   # BossPart → 목표 지점
var _letter_queue: Array[Vector2] = []
var _ghost_timer: float = 0.0
var _fast_text_cooldown: float = 0.0
var _base_speed: float = 0.0
var _base_power: float = 1.0
var _steals: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.CADUCEUS, Pattern.STEAL, Pattern.KICK, Pattern.LETTERS, Pattern.CADUCEUS, Pattern.SUMMON, Pattern.KICK]
	_base_speed = move_speed


func apply_difficulty(info: Dictionary) -> void:
	super.apply_difficulty(info)
	_base_power = power


func is_moving_fast() -> bool:
	return not is_casting() and not is_stunned()


func has_stolen() -> bool:
	return stolen != null or stolen_gold > 0


func get_steal_count() -> int:
	return _steals


func get_letters() -> Array[BossPart]:
	var alive: Array[BossPart] = []
	for l in _letters:
		if is_instance_valid(l) and not (l as BossPart).is_dead():
			alive.append(l as BossPart)
	return alive


func _get_move_velocity(delta: float) -> Vector2:
	_fast_text_cooldown = maxf(_fast_text_cooldown - delta, 0.0)
	_update_letters(delta)
	var v := super._get_move_velocity(delta)
	if v.length() > 1.0:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = 0.07
			_spawn_ghost()
	return v


func _spawn_ghost() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.8, 0.95, 1.0, 0.45)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	ghost.global_position = sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


# ============================================================ 기믹 1: 신속
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, is_crit: bool = false, armor_pen: int = 0) -> void:
	if is_dead() or amount <= 0:
		return
	if is_moving_fast():
		amount = maxi(1, roundi(amount * moving_ratio))
		if _fast_text_cooldown <= 0.0:
			_fast_text_cooldown = 0.6
			FloatingText.spawn(self, global_position + Vector2(0, -50), "너무 빠르다!", Color(0.75, 0.9, 1.0))
	var before := hp
	super.take_damage(amount, knockback, is_crit, armor_pen)
	if has_stolen() and not is_dead():
		_recover_left -= before - hp
		if _recover_left <= 0:
			give_back()
		else:
			set_status("훔친 것을 돌려받기까지 %d" % _recover_left, Color(1.0, 0.85, 0.5))


# ============================================================ 기믹 2: 도둑의 손
## 플레이어가 그 자리에 있으면 훔침 (테스트에서도 직접 호출)
func try_steal() -> bool:
	if has_stolen() or not has_target() or _player.is_dashing():
		return false
	_steals += 1
	_recover_left = maxi(1, roundi(max_hp * recover_ratio))
	stolen = GameManager.steal_active_weapon()
	if stolen != null:
		GameManager.show_notice("헤르메스가 [%s]을(를) 훔쳤다! 돌려받으려면 헤르메스를 때려라" % stolen.display_name, Color(1.0, 0.85, 0.5))
	else:
		stolen_gold = mini(GameManager.gold, 300)
		if stolen_gold <= 0 or not GameManager.spend_gold(stolen_gold):
			stolen_gold = 0
			_steals -= 1
			return false
		GameManager.show_notice("헤르메스가 골드 %d 을(를) 훔쳤다! 때려서 돌려받아라" % stolen_gold, Color(1.0, 0.85, 0.5))
	FloatingText.spawn(_player, _player.global_position + Vector2(0, -24), "도둑맞았다!", Color(1.0, 0.85, 0.5), true)
	set_status("훔친 것을 돌려받기까지 %d" % _recover_left, Color(1.0, 0.85, 0.5))
	return true


func give_back() -> void:
	if stolen != null:
		GameManager.return_stolen_weapon()
		GameManager.show_notice("[%s]을(를) 되찾았다!" % stolen.display_name, Color(0.7, 1.0, 0.7))
	if stolen_gold > 0:
		GameManager.add_gold(stolen_gold)
		GameManager.show_notice("골드 %d 을(를) 되찾았다!" % stolen_gold, Color(0.7, 1.0, 0.7))
	stolen = null
	stolen_gold = 0
	_recover_left = 0
	set_status("", Color.WHITE)


# ============================================================ 기믹 3: 전령의 편지
func send_letters() -> void:
	if letter_scene == null:
		return
	var area := arena_rect if arena_rect.has_area() else Rect2(global_position - Vector2(360, 220), Vector2(720, 440))
	var corners: Array[Vector2] = [area.position + Vector2(20, 30), Vector2(area.end.x - 20, area.position.y + 30),
			Vector2(area.position.x + 20, area.end.y - 20), area.end - Vector2(20, 20)]
	corners.shuffle()
	for i in (4 if phase_two else 3):
		_letter_queue.append(corners[i])
		request_summon(letter_scene, get_hit_center())
	GameManager.show_notice("헤르메스가 편지를 날려 보냈다! 구석에 닿기 전에 떨어뜨려라", Color(0.75, 0.9, 1.0))


func register_minion(minion: Enemy) -> void:
	if minion is BossPart and not _letter_queue.is_empty():
		var letter := minion as BossPart
		letter.boss = self
		letter.follow_boss = false
		letter.max_hp = maxi(1, roundi(max_hp * letter_hp_ratio))
		_letters[letter] = _letter_queue.pop_front()


func _update_letters(delta: float) -> void:
	for l in _letters.keys():
		var letter := l as BossPart
		if not is_instance_valid(letter) or letter.is_dead():
			_letters.erase(l)
			continue
		var target: Vector2 = _letters[l]
		letter.global_position = letter.global_position.move_toward(target, letter_speed * (1.3 if phase_two else 1.0) * delta)
		if letter.global_position.distance_to(target) < 2.0:
			_letters.erase(l)
			letter.despawn()
			_bless()


func _bless() -> void:
	if blessings >= MAX_BLESSINGS:
		return
	blessings += 1
	move_speed = _base_speed * (1.0 + 0.12 * blessings)
	power = _base_power * (1.0 + 0.1 * blessings)
	FloatingText.spawn(self, global_position + Vector2(0, -56), "전령의 축복 %d" % blessings, Color(0.8, 0.95, 1.0), true)
	GameManager.show_notice("편지가 전해졌다! 헤르메스가 더 빨라지고 강해진다 (축복 %d)" % blessings, Color(0.75, 0.9, 1.0))


# ============================================================ 패턴
func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	match pattern:
		Pattern.CADUCEUS:
			var aim := direction_to_player()
			for k in 10:
				_after(0.08 * k, func() -> void:
					if is_dead():
						return
					for side in 2:
						var sway := sin(k * 0.9) * 0.45 * (1.0 if side == 0 else -1.0)
						shoot(aim.rotated(sway), 150.0, snake_damage, snake_texture, 0.0, Elements.Type.NATURE))
			return 1.2
		Pattern.KICK:
			var dir := direction_to_player()
			for i in 9:
				telegraph_strike(get_hit_center() + dir * (26.0 + 24.0 * i), 15.0, 0.6 + 0.04 * i, kick_damage, Elements.Type.NATURE)
			return 1.1
		Pattern.STEAL:
			var at := _player.global_position
			var strike := telegraph_strike(at, 24.0, 0.75, steal_damage, Elements.Type.ARCANE)
			if strike != null:
				strike.color = Color(1.0, 0.85, 0.4)
			_after(0.75, func() -> void:
				if not is_dead() and has_target() and _player.global_position.distance_to(at) <= 28.0:
					try_steal())
			return 1.1
		Pattern.LETTERS:
			send_letters()
			return 0.8
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _die() -> void:
	give_back()
	for l in get_letters():
		l.despawn()
	super._die()


func despawn() -> void:
	give_back()
	super.despawn()


func _on_phase_two() -> void:
	GameManager.show_notice("헤르메스: 신들의 소식은 멈추지 않는다! 편지가 늘어난다", Color(0.75, 0.9, 1.0))
