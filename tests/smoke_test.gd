extends Node
## 헤드리스 통합 테스트. 모든 핵심 시스템이 에러 없이 맞물리는지 확인합니다.
## 실행: godot --headless --path . res://tests/smoke_test.tscn
## (-s 로 실행하면 Autoload 보다 먼저 컴파일되므로 반드시 씬으로 실행합니다.)

var _failures: int = 0
var _gm: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		printerr("  FAIL  ", label)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## 적의 몸통 판정 중심(CollisionShape2D, y -5)이 target 에 오도록 하는 적 위치
func _enemy_pos_for_hit_center(target: Vector2) -> Vector2:
	return target + Vector2(0, 5)


## 현재 씬에 떠 있는 파티클 / 장판 개수 (이펙트 확인용)
func _count_nodes_of(type_name: String) -> int:
	var count := 0
	for child in get_tree().current_scene.get_children():
		if child.get_class() == type_name or (type_name == "AoeStrike" and child is AoeStrike):
			count += 1
	return count


## 보스 패턴을 n 프레임 동안 돌려보기 (플레이어는 매 프레임 회복)
func _survive(frames: int, on_frame: Callable = Callable()) -> void:
	for i in frames:
		_gm.hp = _gm.max_hp
		await get_tree().physics_frame
		if on_frame.is_valid():
			on_frame.call()


func _find_boss() -> Enemy:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if (e as Enemy).is_boss:
			return e
	return null


func _enemy_names() -> Dictionary:
	var names := {}
	for e in get_tree().get_nodes_in_group(&"enemies"):
		names[(e as Enemy).display_name] = true
	return names


func _press_action(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


## 상점 판매 목록 i 번째 줄의 배경색 / 버튼
func _row_bg(rows: Array, i: int) -> Color:
	return ((rows[i] as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color


func _row_button(rows: Array, i: int, button_index: int = 0) -> Button:
	return (rows[i] as PanelContainer).get_child(0).get_child(2 + button_index) as Button


func _item_pickups(entities: Node) -> Array:
	return entities.get_children().filter(func(n: Node) -> bool: return n is Pickup and (n as Pickup).kind == Pickup.Kind.ITEM)


func _run() -> void:
	_gm = get_node("/root/GameManager")

	print("[타이틀 / 난이도]")
	var title: Control = (load("res://scenes/title/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title)
	await get_tree().process_frame
	_check(title.get_node("%DifficultyPanel").visible and not title.get_node("%HelpPanel").visible, "난이도 선택 창 표시")
	_check((title.get_node("Background") as TextureRect).texture != null, "전투 배경 일러스트")
	title.select_difficulty(_gm.Difficulty.HARD)
	_check(title.get_node("%HelpPanel").visible and not title.get_node("%DifficultyPanel").visible, "난이도 선택 → 조작 안내 표시")
	_check(title.get_node("%KeyGrid").get_child_count() == title.CONTROLS.size() * 2, "조작 키 %d개 안내" % title.CONTROLS.size())
	_check((title.get_node("%HelpTitle") as Label).text.contains("하드"), "안내 제목에 선택 난이도")
	_gm.start_new_game(title.get_selected_difficulty())
	_check(_gm.difficulty == _gm.Difficulty.HARD and _gm.get_difficulty_name() == "하드", "하드 난이도로 새 게임")
	title.queue_free()
	_gm.start_new_game(_gm.Difficulty.NORMAL)

	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _frames(3)

	var player := main.get_node("Entities/Player") as Player
	var entities := main.get_node("Entities") as Node2D
	var pool := main.get_node("ProjectilePool") as ProjectilePool
	var stage := main.get_node("StageManager") as StageManager
	var hud := main.get_node("HUD") as HUD
	var shop := main.get_node("ShopUI") as ShopUI
	var inventory := main.get_node("InventoryUI") as InventoryUI
	var attack := player.get_node("AttackController")
	var guard_ctl := player.get_node("GuardController")
	var slime_scene := load("res://scenes/enemies/slime.tscn") as PackedScene
	stage.instant_travel = true
	var camp_arena: Rect2 = stage.camp_room.get_arena_rect()

	print("[구조]")
	_check(attack is AttackController and not (attack is Node2D), "AttackController 는 Node (Node2D 아님)")
	_check(guard_ctl is GuardController and not (guard_ctl is Node2D), "GuardController 는 Node (Node2D 아님)")
	_check(pool.get_total_count() == 128 and pool.get_available_count() == 128, "풀 사전 생성 128개")
	_check(_gm.weapon_slots[0] != null and _gm.weapon_slots[0].id == &"rusty_sword" and _gm.weapon_slots[1] == null and _gm.weapon_slots[2] == null, "무기 칸: 검 칸에 녹슨 검, 활·지팡이 칸 비어 있음")
	_check(_gm.equipped_shield != null and _gm.equipped_shield.id == &"wooden_shield", "방패 칸: 나무 방패")
	_check(stage.get_state() == StageManager.State.CAMP and _gm.location_name == "야영지", "야영지에서 시작")
	_check(stage.camp_room.get_bounds().has_point(player.global_position), "플레이어가 야영지 안에 있음")
	_check(hud.get_node("%Hotbar").get_child_count() == 13, "HUD 단축바 (무기 3 + 방어구 3 + 보석 3 + 포션)")
	_check(_gm.get_potion_count(&"small_potion") == 2, "시작 포션: 작은 회복 포션 2개")

	print("[이동/대시]")
	var start_x := player.global_position.x
	Input.action_press(&"move_right")
	await _frames(30)
	_check(player.global_position.x > start_x + 20.0, "오른쪽 이동")
	_check(player.velocity.length() <= player.max_speed + 0.5, "최대 속도 제한")
	Input.action_release(&"move_right")
	await _frames(30)
	_check(player.velocity.length() < 1.0, "마찰로 정지")
	Input.action_press(&"dash")
	await _frames(2)
	Input.action_release(&"dash")
	_check(player.is_dashing() and player.is_invincible(), "대시 중 무적")
	_check(hud.get_node("%DashBar").value < 100.0, "HUD 대시 바 갱신")
	await _frames(70)
	_check(_gm.is_dash_ready(), "대시 쿨타임 회복")
	player.global_position = Vector2(-60, 60)
	await _frames(3)

	print("[근접 공격 - 검은 투사체 없이 부채꼴 타격]")
	var aim := player.get_aim_direction()
	var origin := player.get_attack_origin()
	var front := slime_scene.instantiate() as Enemy
	front.move_speed = 0.0
	front.max_hp = 999
	front.item_drop_chance = 1.0
	front.item_drop_ids = [&"slime_staff"]
	stage._add_enemy(front, _enemy_pos_for_hit_center(origin + aim * 18.0), camp_arena)
	var behind := slime_scene.instantiate() as Enemy
	behind.move_speed = 0.0
	stage._add_enemy(behind, _enemy_pos_for_hit_center(origin - aim * 18.0), camp_arena)
	await _frames(3)
	var avail := pool.get_available_count()
	var hp_front := front.hp
	var hp_behind := behind.hp
	_check(attack.perform_attack(), "녹슨 검 휘두르기")
	_check(pool.get_available_count() == avail, "검은 투사체를 쓰지 않음")
	var rusty_damage := hp_front - front.hp
	_check(rusty_damage >= 8, "정면 적 타격 (데미지 %d)" % rusty_damage)
	_check(behind.hp == hp_behind, "등 뒤 적은 맞지 않음")
	behind.despawn()

	print("[무기 칸 3개 - 종류별 1개씩, 중복 장착 없음]")
	var bow := ItemDB.get_weapon(&"hunter_bow")
	var staff := ItemDB.get_weapon(&"apprentice_staff")
	var iron := ItemDB.get_weapon(&"iron_sword")
	for w in [bow, staff, iron]:
		_gm.add_item(w)
	_gm.equip_item(bow)
	_gm.equip_item(staff)
	_check(_gm.weapon_slots[1] == bow and _gm.weapon_slots[2] == staff and _gm.equipped_weapon == staff, "활 칸 · 지팡이 칸에 장착, 마지막 장착 무기를 손에 듦")
	_gm.equip_item(iron)
	_check(_gm.weapon_slots[0] == iron and _gm.weapon_slots.count(iron) == 1, "강철 검이 검 칸의 녹슨 검을 교체 (중복 없음)")
	_check(not _gm.is_equipped(ItemDB.get_item(&"rusty_sword")) and _gm.owns_item(&"rusty_sword"), "교체된 녹슨 검은 가방으로")
	await _press_action(&"weapon_slot_2")
	_check(_gm.equipped_weapon == bow and _gm.active_weapon_slot == 1, "2 키 → 활")
	await _press_action(&"weapon_next")
	_check(_gm.equipped_weapon == staff, "Q → 다음 칸(지팡이)")
	_check(player.get_node("WeaponPivot/SwingPivot/WeaponSprite").texture == staff.icon, "손에 든 무기 스프라이트 교체")

	print("[활 - 시위를 당긴 뒤 발사]")
	_gm.select_weapon_slot(1)
	await _frames(30)
	var bow_string := player.get_node("WeaponPivot/SwingPivot/BowString") as Line2D
	Input.action_press(&"attack")
	await _frames(6)
	_check(attack.is_winding_up() and pool.get_available_count() == avail, "시위 당기는 중 (아직 발사 안 됨)")
	_check(bow_string.points[1].x < 2.0, "시위가 뒤로 당겨짐")
	await _frames(16)
	Input.action_release(&"attack")
	_check(pool.get_available_count() < avail, "끝까지 당기면 발사")
	await _frames(70)

	print("[마법 지팡이 - 영창 후 시전]")
	_gm.select_weapon_slot(2)
	await _frames(12)
	Input.action_press(&"attack")
	await _frames(10)
	var chant := player.get_node("ChantLabel") as Label
	_check(chant.visible and chant.text == staff.chant_text, "영창 대사 표시")
	_check(player.get_node("WeaponPivot/ChargeOrb").visible and pool.get_available_count() == avail, "구슬에 마력이 모이는 중")
	await _frames(16)
	Input.action_release(&"attack")
	_check(pool.get_available_count() <= avail - 3, "영창 완료 → 마력탄 3발")
	await _frames(70)

	print("[드랍 - 1스테이지는 일반·희귀까지만]")
	var gold_before: int = _gm.gold
	var items_before: int = _gm.items.size()
	front.take_damage(9999)
	var epic_dropper := slime_scene.instantiate() as Enemy
	epic_dropper.item_drop_chance = 1.0
	epic_dropper.item_drop_ids = [&"flame_blade"]
	stage._add_enemy(epic_dropper, player.global_position + Vector2(-80, 0), camp_arena)
	await _frames(3)
	epic_dropper.take_damage(9999)
	await _frames(3)
	var item_drops := _item_pickups(entities)
	_check(item_drops.size() == 1 and (item_drops[0] as Pickup).item.id == &"slime_staff", "희귀 장비는 드랍, 레어(화염검)는 1스테이지 잡몹에서 드랍 안 됨")
	for p in entities.get_children():
		if p is Pickup:
			(p as Pickup).global_position = player.global_position
	await _frames(40)
	_check(_gm.gold > gold_before, "골드 확정 드랍 획득")
	_check(_gm.items.size() == items_before + 1, "드랍 장비 가방에 추가")

	print("[보석 - 치명타]")
	_gm.select_weapon_slot(0)
	var ruby := ItemDB.get_item(&"ruby") as GemData
	var diamond := ItemDB.get_item(&"star_diamond") as GemData
	_gm.add_item(ruby)
	_gm.add_item(diamond)
	_gm.equip_item(ruby)
	_gm.equip_item(diamond)
	_check(_gm.gem_slots.count(null) == 1, "보석 칸 2개 사용")
	_check(is_equal_approx(_gm.get_crit_chance_bonus(), ruby.crit_chance_bonus + diamond.crit_chance_bonus), "치명타 확률 +%d%%" % roundi(_gm.get_crit_chance_bonus() * 100.0))
	_check(is_equal_approx(_gm.damage_multiplier, 1.0 + diamond.attack_bonus), "공격력 보너스 반영")
	var crits := 0
	var crit_amount := 0
	for i in 2000:
		var roll: Dictionary = _gm.roll_weapon_damage(iron)
		if roll["crit"]:
			crits += 1
			crit_amount = roll["amount"]
	var expected_rate: float = _gm.get_crit_chance(iron)
	_check(absf(crits / 2000.0 - expected_rate) < 0.05, "치명타 발생률 %.2f (기대 %.2f)" % [crits / 2000.0, expected_rate])
	var expected_crit := roundi(iron.damage * _gm.damage_multiplier * (iron.crit_multiplier + _gm.get_crit_damage_bonus()))
	_check(crit_amount == expected_crit, "치명타 피해 %d (보석 치피 반영)" % crit_amount)

	print("[등급별 이펙트]")
	var flame := ItemDB.get_weapon(&"flame_blade")
	var holy := ItemDB.get_weapon(&"holy_sword")
	_gm.add_item(flame)
	_gm.add_item(holy)
	await _frames(30)
	var base_particles := _count_nodes_of("CPUParticles2D")
	_gm.equip_item(ItemDB.get_item(&"rusty_sword"))
	attack.perform_attack()
	var common_fx := _count_nodes_of("CPUParticles2D") - base_particles
	_gm.equip_item(flame)
	attack.perform_attack()
	var epic_fx := _count_nodes_of("CPUParticles2D") - base_particles - common_fx
	_gm.equip_item(holy)
	attack.perform_attack()
	var legend_fx := _count_nodes_of("CPUParticles2D") - base_particles - common_fx - epic_fx
	_check(common_fx == 0 and epic_fx > 0 and legend_fx > epic_fx, "일반 %d < 레어 %d < 전설 %d 이펙트" % [common_fx, epic_fx, legend_fx])
	_gm.equip_item(iron)

	print("[방패 가드]")
	player.global_position = Vector2(150, 80)
	await _frames(40)
	aim = player.get_aim_direction()
	Input.action_press(&"guard")
	await _frames(20)
	_check(player.is_guarding() and not player.can_attack(), "우클릭 가드 (가드 중 공격 불가)")
	var hp1: int = _gm.hp
	pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + aim * 24.0, -aim, 200.0, 10, null))
	await _frames(15)
	_check(_gm.hp == hp1 - 3, "정면 가드: 나무 방패 70%% 막음 (HP %d → %d)" % [hp1, _gm.hp])
	Input.action_release(&"guard")
	await _frames(45)
	Input.action_press(&"guard")
	await _frames(1)
	var hp3: int = _gm.hp
	var bullet := pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + aim * 12.0, -aim, 200.0, 10, null))
	await _frames(6)
	_check(_gm.hp == hp3 and bullet.is_active and bullet.get_team() == ProjectileSpec.Team.PLAYER, "퍼펙트 가드: 피해 0 + 탄 반사")
	Input.action_release(&"guard")
	await _frames(30)

	print("[회복 포션]")
	var small := ItemDB.get_potion(&"small_potion")
	var medium := ItemDB.get_potion(&"potion")
	var greater := ItemDB.get_potion(&"greater_potion")
	_gm.heal_full()
	_check(not _gm.use_potion() and _gm.get_potion_count(&"small_potion") == 2, "체력이 가득 차 있으면 사용되지 않음")
	_gm.damage_player(20)
	var hp_low: int = _gm.hp
	await _press_action(&"use_potion")
	_check(_gm.hp == mini(hp_low + small.get_heal(_gm.max_hp), _gm.max_hp) and _gm.get_potion_count(&"small_potion") == 1, "H 키 → 작은 포션 사용 (HP %d → %d)" % [hp_low, _gm.hp])
	_gm.add_gold(1000)
	_check(_gm.buy_item(medium) and _gm.buy_item(medium) and _gm.get_potion_count(&"potion") == 2, "회복 포션 여러 개 구매")
	_check(not _gm.buy_item(greater), "고급 회복 포션(레어)은 2스테이지부터")
	for i in 10:
		_gm.buy_potion(small)
	_check(_gm.get_potion_count(&"small_potion") == _gm.POTION_MAX_STACK, "종류별 최대 %d개" % _gm.POTION_MAX_STACK)
	_gm.damage_player(roundi(_gm.max_hp * 0.35))
	_check(_gm.choose_potion() == medium, "많이 잃으면 큰 포션 자동 선택")
	await _frames(60)
	_gm.use_potion()
	_check(_gm.hp == _gm.max_hp and _gm.get_potion_count(&"potion") == 1, "회복 포션: 최대 체력의 %d%% 회복" % roundi(medium.heal_percent * 100.0))
	var potion_slot := hud.get_node("%Hotbar").get_child(hud.get_node("%Hotbar").get_child_count() - 1)
	_check((potion_slot.get_node("PotionCount") as Label).text == "x%d" % _gm.get_total_potions(), "HUD 포션 개수 표시 x%d" % _gm.get_total_potions())

	print("[인벤토리]")
	await _press_action(&"inventory")
	_check(inventory.is_open() and get_tree().paused, "I 키 → 인벤토리 열림 + 일시정지")
	_check(inventory.get_node("%WeaponSlots").get_child_count() == 3 and inventory.get_node("%ArmorSlots").get_child_count() == 3 and inventory.get_node("%GemSlots").get_child_count() == 3, "장비 칸: 무기 3 · 방어구 3 · 보석 3")
	_check(inventory.get_node("%BagList").get_child_count() == _gm.items.size() + _gm.get_owned_potions().size(), "가방 목록: 포션 %d종 + 장비 %d개" % [_gm.get_owned_potions().size(), _gm.items.size()])
	inventory._on_unequip_pressed(ruby)
	await get_tree().process_frame
	_check(not _gm.is_equipped(ruby) and _gm.get_crit_chance_bonus() < 0.2, "보석 칸 해제 → 치명타 보너스 감소")
	_gm.unequip_item(bow)
	_gm.unequip_item(staff)
	_check(not _gm.unequip_item(iron) and _gm.equipped_weapon == iron, "마지막 무기는 해제 불가")
	await _press_action(&"inventory")
	_check(not inventory.is_open() and not get_tree().paused, "다시 I → 닫힘 + 재개")

	print("[상점 - 구매 / 판매 / 스테이지 잠금 / 갑옷]")
	_gm.add_gold(5000)
	_gm.request_shop("테스트 상점", [&"rapid_crossbow", &"iron_shield", &"leather_armor", &"royal_aegis", &"solaris_bow", &"small_potion"])
	await get_tree().process_frame
	_check(shop.is_open() and get_tree().paused, "상점 열림 + 일시정지")
	var rows := shop.get_node("%BuyList").get_children()
	_check(_row_bg(rows, 0) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.RARE] and _row_bg(rows, 3) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.EPIC] and _row_bg(rows, 4) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.LEGENDARY], "등급 배경색: 희귀 파랑 / 레어 보라 / 전설 노랑")
	_check(_row_button(rows, 3).disabled and _row_button(rows, 3).text == "2스테이지", "1스테이지: 레어 잠김")
	_check(not _gm.buy_item(ItemDB.get_item(&"royal_aegis")), "잠긴 장비는 구매 불가")
	_check(_row_button(rows, 5).text == "가득 참" and _row_button(rows, 5).disabled, "상점: 포션이 가득 차면 구매 불가 표시")
	var leather := ItemDB.get_item(&"leather_armor") as ArmorData
	var max_hp_before: int = _gm.max_hp
	var gold_pre: int = _gm.gold
	shop._on_buy_pressed(leather)
	shop._on_buy_pressed(ItemDB.get_item(&"iron_shield"))
	await get_tree().process_frame
	_check(_gm.gold == gold_pre - leather.price - ItemDB.get_item(&"iron_shield").price, "구매 골드 차감")
	_check(_gm.equipped_armor == leather and _gm.max_hp == max_hp_before + leather.bonus_max_hp, "갑옷 구매 → 갑옷 칸 장착, 최대 HP +%d" % leather.bonus_max_hp)
	_check((player.get_node("BodySprite/ArmorSprite") as Sprite2D).visible, "플레이어 몸에 갑옷 표시")
	_check(_gm.get_total_defense() == 1 + leather.defense, "방어력 합산 (방패 + 갑옷)")
	var rusty := ItemDB.get_item(&"rusty_sword")
	var gold_before_sell: int = _gm.gold
	var sold: int = _gm.sell_item(rusty)
	_check(sold == rusty.get_sell_value() and _gm.gold == gold_before_sell + sold and not _gm.owns_item(rusty.id), "녹슨 검 판매 +%dG" % sold)
	_check(_gm.sell_item(_gm.equipped_shield) == 0, "장착 중인 장비는 판매 불가")
	await get_tree().process_frame
	_check(shop.get_node("%InventoryList").get_child_count() == _gm.items.size(), "상점 보유 장비 목록 (장착 / 판매 버튼)")
	shop.close()

	print("[1스테이지 진행: 야영지 → 사냥터 → 보스방 → 상자 → 다음 스테이지]")
	for e in get_tree().get_nodes_in_group(&"enemies"):
		(e as Enemy).despawn()
	var field_portal := main.get_node("Entities/FieldPortal") as Portal
	var camp_portal := main.get_node("Entities/CampPortal") as Portal
	var gate := main.get_node("Entities/BossGate") as BossGate
	var next_portal := main.get_node("Entities/NextStagePortal") as Portal
	_check(not next_portal.visible, "다음 스테이지 텔레포트는 숨겨져 있음")
	field_portal.interacted.emit()
	await _frames(60)
	_check(stage.get_state() == StageManager.State.FIELD and _gm.location_name == "사냥터", "텔레포트 → 사냥터")
	_check(stage.field_room.get_bounds().has_point(player.global_position), "플레이어가 사냥터로 이동")
	_check(get_tree().get_nodes_in_group(&"enemies").size() > 0, "사냥터에 몬스터 스폰")
	_check(not gate.is_open() and not gate.enabled, "보스문 봉인 상태")
	stage._kills = stage._kill_target - 1
	var last := slime_scene.instantiate() as Enemy
	stage._add_enemy(last, player.global_position + Vector2(0, -120), stage.field_room.get_arena_rect())
	await _frames(3)
	last.take_damage(9999)
	await _frames(3)
	_check(gate.is_open() and gate.enabled, "처치 목표 달성 → 보스방 봉인 해제")
	_check((hud.get_node("%ProgressLabel") as Label).text.contains("해방"), "HUD: 보스방 해방 표시")
	camp_portal.interacted.emit()
	await _frames(3)
	_check(stage.get_state() == StageManager.State.CAMP and get_tree().get_nodes_in_group(&"enemies").is_empty(), "귀환 텔레포트 → 야영지 (사냥터 몬스터 정리)")
	field_portal.interacted.emit()
	await _frames(3)
	_check(gate.is_open(), "다시 사냥터: 보스문은 열린 채 유지")
	gate.interacted.emit()
	await _frames(3)
	_check(stage.get_state() == StageManager.State.BOSS and _gm.location_name == "보스방" and stage.boss_room.get_bounds().has_point(player.global_position), "보스문 → 보스방 입장")
	await _frames(int(stage.boss_entry_delay * 60) + 10)
	var slime_king := _find_boss()
	_check(slime_king != null and slime_king.display_name == "슬라임 킹" and hud.get_node("%BossBox").visible, "보스 등장: 슬라임 킹")
	slime_king.take_damage(999999)
	await _frames(4)
	_check(stage.get_state() == StageManager.State.CLEARED and next_portal.visible and next_portal.enabled, "보스 토벌 → 다음 스테이지 텔레포트 등장")
	var chest := stage.get_chest()
	_check(chest != null and not chest.is_opened(), "보물상자 등장")
	_check(_item_pickups(entities).filter(func(p: Pickup) -> bool: return stage.boss_room.get_bounds().has_point(p.global_position)).is_empty(), "보스는 장비를 직접 떨어뜨리지 않음 (상자로 보상)")
	chest._interact()
	await _frames(3)
	var chest_drop := _item_pickups(entities).filter(func(p: Pickup) -> bool: return p.global_position.distance_to(chest.global_position) < 40.0)
	var chest_item: ItemData = (chest_drop[0] as Pickup).item if chest_drop.size() == 1 else null
	_check(chest_item != null and chest_item.rarity == ItemData.Rarity.EPIC, "1스테이지 보스 상자 → 레어 등급: %s" % (chest_item.display_name if chest_item else "없음"))
	_check(chest_item != null and not (chest_item is GemData) and not (chest_item is WeaponData and (chest_item as WeaponData).weapon_type == WeaponData.WeaponType.DAGGER), "상자 장비 종류: 검/활/지팡이/방패/투구/갑옷")
	next_portal.interacted.emit()
	await _frames(3)
	_check(_gm.stage == 2 and stage.get_state() == StageManager.State.CAMP and _gm.location_name == "야영지", "다음 스테이지 텔레포트 → 2스테이지 야영지")
	_check(chest_item != null and _gm.owns_item(chest_item.id), "보스방에 남은 상자 보상 자동 회수")
	_check(not gate.is_open() and not next_portal.visible, "새 스테이지: 보스문 재봉인 · 텔레포트 숨김")

	print("[2스테이지 - 불타는 지옥문]")
	_check(_gm.stage_name == "불타는 지옥문", "스테이지 이름")
	_gm.request_shop("테스트 상점", [&"hellsteel_plate", &"solaris_bow"])
	await get_tree().process_frame
	rows = shop.get_node("%BuyList").get_children()
	_check(not _row_button(rows, 0).disabled or _gm.owns_item(&"hellsteel_plate"), "2스테이지: 레어 해금")
	_check(_row_button(rows, 1).disabled, "2스테이지: 전설은 아직 잠김")
	shop.close()
	_gm.max_hp = 99999
	field_portal.interacted.emit()
	for i in 6:
		stage._spawn_regular_enemy()
	await _frames(3)
	_check(_enemy_names().keys().all(func(n: String) -> bool: return n in ["헬하운드", "오크"]), "일반 몹: %s" % ", ".join(_enemy_names().keys()))
	await _survive(240)
	_check(not _gm.is_player_dead, "헬하운드/오크 패턴 실행")
	stage._kills = stage._kill_target
	gate.open()
	gate.interacted.emit()
	await _frames(int(stage.boss_entry_delay * 60) + 10)
	var gatekeeper := _find_boss()
	_check(gatekeeper != null and gatekeeper.display_name == "지옥의 수문장", "2스테이지 보스: 지옥의 수문장")
	var seen := {"aoe": false, "fire": false, "hounds": false}
	await _survive(720, func() -> void:
		if _count_nodes_of("AoeStrike") > 0:
			seen["aoe"] = true
		for c in pool.get_children():
			if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
				seen["fire"] = true
		if _enemy_names().has("헬하운드"):
			seen["hounds"] = true)
	_check(seen["fire"] and seen["aoe"] and seen["hounds"], "수문장: 화염구 / 화염 기둥 / 헬하운드 소환")
	gatekeeper.take_damage(999999)
	await _frames(4)
	stage.get_chest()._interact()
	await _frames(3)
	var legend_drop := _item_pickups(entities).filter(func(p: Pickup) -> bool: return p.item.rarity == ItemData.Rarity.LEGENDARY)
	_check(legend_drop.size() >= 1, "2스테이지 보스 상자 → 전설 등급")
	next_portal.interacted.emit()
	await _frames(3)

	print("[3스테이지 - 원소의 유적]")
	_check(_gm.stage == 3 and _gm.stage_name == "원소의 유적", "스테이지 3 「%s」" % _gm.stage_name)
	field_portal.interacted.emit()
	await _frames(2)
	for scene in stage.get_stage_data().enemy_scenes:
		stage._add_enemy(scene.instantiate() as Enemy, stage._pick_spawn_position(stage.field_room.get_arena_rect()), stage.field_room.get_arena_rect())
	await _frames(3)
	var golem_names := _enemy_names().keys().filter(func(n: String) -> bool: return n.ends_with("골렘"))
	_check(golem_names.size() == 4, "속성 골렘 4종: %s" % ", ".join(golem_names))
	await _survive(360)
	_check(not _gm.is_player_dead, "골렘 속성 패턴 실행")
	gate.open()
	gate.interacted.emit()
	await _frames(int(stage.boss_entry_delay * 60) + 10)
	var archeon := _find_boss() as BossArcheon
	_check(archeon != null and archeon.display_name == "원소의 거신 아르케온", "3스테이지 보스: 원소의 거신 아르케온")
	var elements_seen := {}
	await _survive(1200, func() -> void:
		if is_instance_valid(archeon):
			elements_seen[archeon.get_current_element()] = true)
	_check(elements_seen.size() == 4, "4원소 순환 (%d종)" % elements_seen.size())
	archeon.take_damage(roundi(archeon.max_hp * 0.6))
	_check(archeon._phase_two, "체력 50% 이하 → 원소 융합")
	await _survive(240)
	archeon.take_damage(999999)
	await _frames(4)
	next_portal.interacted.emit()
	await _frames(3)
	_check(_gm.stage == 4 and _gm.stage_name.contains("+1"), "마지막 스테이지 이후 강화 반복: %s" % _gm.stage_name)

	print("[난이도 배율]")
	_gm.difficulty = _gm.Difficulty.VERY_HARD
	var tough := slime_scene.instantiate() as Enemy
	var base_hp := tough.max_hp
	stage._add_enemy(tough, player.global_position + Vector2(0, -80), camp_arena)
	await _frames(2)
	var hp_mult: float = _gm.DIFFICULTY_INFO[_gm.Difficulty.VERY_HARD]["enemy_hp"]
	var level_mult := 1.0 + 0.5 * stage.get_scaling_level()
	_check(tough.max_hp == roundi(roundi(base_hp * level_mult) * hp_mult), "베리하드: 몬스터 체력 %d → %d" % [base_hp, tough.max_hp])
	tough.despawn()
	_gm.difficulty = _gm.Difficulty.NORMAL

	print("[사망/재시작]")
	_gm.damage_player(_gm.hp)
	await _frames(2)
	_check(_gm.is_player_dead and hud.get_node("%GameOver").visible, "사망 → GAME OVER 표시")
	await _press_action(&"restart")
	await _frames(10)
	_check(get_tree().current_scene != main and get_tree().current_scene != null, "씬 재시작")
	_check(_gm.hp == _gm.max_hp and _gm.stage == 1 and not _gm.is_player_dead and _gm.items.size() == 2 and _gm.get_total_potions() == 2, "GameManager 초기화")
	await _frames(10)

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
