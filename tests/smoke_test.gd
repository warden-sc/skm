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
		_gm.heal_full()
		await get_tree().physics_frame
		if on_frame.is_valid():
			on_frame.call()


## 상점 판매 목록 i 번째 줄의 배경색 / 버튼
func _row_bg(rows: Array, i: int) -> Color:
	return ((rows[i] as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color


func _row_button(rows: Array, i: int) -> Button:
	return (rows[i] as PanelContainer).get_child(0).get_child(2) as Button


func _find_boss() -> Enemy:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if (e as Enemy).is_boss:
			return e
	return null


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		(e as Enemy).despawn()


func _run() -> void:
	_gm = get_node("/root/GameManager")
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
	var attack := player.get_node("AttackController")
	var guard_ctl := player.get_node("GuardController")
	var slime_scene := load("res://scenes/enemies/slime.tscn") as PackedScene
	var goblin_scene := load("res://scenes/enemies/goblin.tscn") as PackedScene

	print("[구조]")
	_check(attack is AttackController and not (attack is Node2D), "AttackController 는 Node (Node2D 아님)")
	_check(guard_ctl is GuardController and not (guard_ctl is Node2D), "GuardController 는 Node (Node2D 아님)")
	_check(pool.get_total_count() == 128 and pool.get_available_count() == 128, "풀 사전 생성 128개")
	_check(_gm.equipped_weapon != null and _gm.equipped_weapon.id == &"rusty_sword", "시작 무기 장착")
	_check(_gm.equipped_shield != null and _gm.equipped_shield.id == &"wooden_shield", "시작 방패 장착")
	_check(stage.get_state() == StageManager.State.INTERMISSION, "정비 시간으로 시작")

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
	_check(_gm.dash_cooldown_remaining > 0.0, "대시 쿨타임이 GameManager 에 반영")
	_check(hud.get_node("%DashBar").value < 100.0, "HUD 대시 바 갱신")
	await _frames(70)
	_check(_gm.is_dash_ready(), "대시 쿨타임 회복")

	print("[근접 공격 - 검은 투사체 없이 부채꼴 타격]")
	var aim := player.get_aim_direction()
	var origin := player.get_attack_origin()
	var front := slime_scene.instantiate() as Enemy
	front.move_speed = 0.0
	front.max_hp = 999  # 뒤의 활 테스트 화살에 맞아도 죽지 않도록
	front.item_drop_chance = 1.0
	front.item_drop_ids = [&"slime_staff"]
	stage._add_enemy(front, _enemy_pos_for_hit_center(origin + aim * 18.0))
	var behind := slime_scene.instantiate() as Enemy
	behind.move_speed = 0.0
	stage._add_enemy(behind, _enemy_pos_for_hit_center(origin - aim * 18.0))
	var far := slime_scene.instantiate() as Enemy
	far.move_speed = 0.0
	stage._add_enemy(far, _enemy_pos_for_hit_center(origin + aim * 70.0))
	await _frames(3)
	var avail := pool.get_available_count()
	var hp_front := front.hp
	var hp_behind := behind.hp
	var hp_far := far.hp
	_check(attack.perform_attack(), "AttackController.attack() (녹슨 검)")
	_check(pool.get_available_count() == avail, "검은 투사체를 쓰지 않음 (풀 그대로)")
	var rusty_damage := hp_front - front.hp
	_check(rusty_damage >= 8, "정면 적 타격 (데미지 %d)" % rusty_damage)
	_check(behind.hp == hp_behind, "등 뒤 적은 맞지 않음")
	_check(far.hp == hp_far, "리치 밖 적은 맞지 않음")
	_check(player.get_node("WeaponPivot/SwingFx").modulate.a > 0.0, "휘두르기 이펙트 표시")
	behind.despawn()
	far.despawn()

	print("[활 - 시위를 당긴 뒤 발사]")
	var bow := ItemDB.get_weapon(&"hunter_bow")
	_gm.add_item(bow)
	_gm.equip_item(bow)
	await _frames(30)  # 직전 근접 공격 쿨타임 대기
	var bow_string := player.get_node("WeaponPivot/SwingPivot/BowString") as Line2D
	_check(bow_string.visible, "활 장착 시 시위 표시")
	Input.action_press(&"attack")
	await _frames(6)
	_check(attack.is_winding_up() and pool.get_available_count() == avail, "시위 당기는 중 (아직 발사 안 됨)")
	_check(bow_string.points[1].x < 2.0, "시위가 뒤로 당겨짐 (x=%.1f)" % bow_string.points[1].x)
	_check(player.get_node("WeaponPivot/SwingPivot/NockedArrow").visible, "화살이 시위에 걸림")
	await _frames(16)
	Input.action_release(&"attack")
	_check(pool.get_available_count() < avail, "끝까지 당기면 발사")
	await _frames(70)
	_check(pool.get_available_count() == avail, "사거리 끝에서 풀로 반환")
	Input.action_press(&"attack")
	await _frames(5)
	Input.action_release(&"attack")
	await _frames(2)
	_check(not attack.is_winding_up() and pool.get_available_count() == avail, "중간에 떼면 발사 취소")

	print("[마법 지팡이 - 영창 후 시전]")
	var staff := ItemDB.get_weapon(&"apprentice_staff")
	_gm.add_item(staff)
	_gm.equip_item(staff)
	await _frames(12)
	Input.action_press(&"attack")
	await _frames(10)
	var chant := player.get_node("ChantLabel") as Label
	_check(chant.visible and chant.text == staff.chant_text, "영창 대사 표시: %s" % chant.text)
	_check(player.get_node("WeaponPivot/ChargeOrb").visible and player.is_winding_up(), "지팡이 구슬에 마력이 모임")
	_check(pool.get_available_count() == avail, "영창 중 (아직 시전 안 됨)")
	await _frames(16)
	Input.action_release(&"attack")
	_check(pool.get_available_count() <= avail - 3, "영창 완료 → 마력탄 3발 시전")
	_check(not chant.visible, "시전 후 영창 대사 사라짐")
	await _frames(70)

	print("[드랍/줍기]")
	var gold_before: int = _gm.gold
	var weapons_before: int = _gm.weapons.size()
	front.take_damage(9999)
	await _frames(3)
	var pickups := entities.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	var item_drops := pickups.filter(func(p: Pickup) -> bool: return p.kind == Pickup.Kind.ITEM)
	_check(pickups.size() >= 2, "골드 확정 드랍 + 장비 드랍 생성 (%d개)" % pickups.size())
	_check(item_drops.size() == 1, "장비 드랍 (확률 1.0 설정)")
	for p in pickups:
		(p as Pickup).global_position = player.global_position
	await _frames(40)
	_check(_gm.gold > gold_before, "골드 획득 %d → %d" % [gold_before, _gm.gold])
	_check(_gm.weapons.size() == weapons_before + 1, "드랍 무기 인벤토리 추가")

	print("[무기 장착 → 데미지 변화]")
	var iron := ItemDB.get_weapon(&"iron_sword")
	_gm.add_item(iron)
	_gm.equip_item(iron)
	_check(player.get_node("WeaponPivot/SwingPivot/WeaponSprite").texture == iron.icon, "장착 무기 스프라이트 교체")
	aim = player.get_aim_direction()
	origin = player.get_attack_origin()
	var dummy := goblin_scene.instantiate() as Enemy
	dummy.move_speed = 0.0
	stage._add_enemy(dummy, _enemy_pos_for_hit_center(origin + aim * 20.0))
	await _frames(3)
	var dhp := dummy.hp
	attack.perform_attack()
	_check(dhp - dummy.hp >= 15, "강철 검 데미지 %d (녹슨 검 %d)" % [dhp - dummy.hp, rusty_damage])
	dummy.despawn()

	print("[등급별 이펙트]")
	var flame := ItemDB.get_weapon(&"flame_blade")
	var holy := ItemDB.get_weapon(&"holy_sword")
	_gm.add_item(flame)
	_gm.add_item(holy)
	await _frames(30)
	var base_particles := _count_nodes_of("CPUParticles2D")
	_gm.equip_item(ItemDB.get_weapon(&"rusty_sword"))
	attack.perform_attack()
	var common_fx := _count_nodes_of("CPUParticles2D") - base_particles
	_gm.equip_item(flame)
	attack.perform_attack()
	var epic_fx := _count_nodes_of("CPUParticles2D") - base_particles - common_fx
	_gm.equip_item(holy)
	attack.perform_attack()
	var legend_fx := _count_nodes_of("CPUParticles2D") - base_particles - common_fx - epic_fx
	_check(common_fx == 0 and epic_fx > 0 and legend_fx > epic_fx, "일반 %d < 레어(화염검) %d < 전설(성검) %d 이펙트" % [common_fx, epic_fx, legend_fx])

	var ignis := ItemDB.get_weapon(&"ignis_staff")
	_gm.add_item(ignis)
	_gm.equip_item(ignis)
	await _frames(2)
	aim = player.get_aim_direction()
	origin = player.get_attack_origin()
	var g1 := goblin_scene.instantiate() as Enemy
	var g2 := goblin_scene.instantiate() as Enemy
	g1.move_speed = 0.0
	g2.move_speed = 0.0
	g1.max_hp = 999
	g2.max_hp = 999
	stage._add_enemy(g1, _enemy_pos_for_hit_center(origin + aim * 60.0))
	stage._add_enemy(g2, _enemy_pos_for_hit_center(origin + aim * 60.0 + aim.orthogonal() * 22.0))
	await _frames(3)
	var g1_hp := g1.hp
	var g2_hp := g2.hp
	attack.perform_attack()
	await _frames(25)
	_check(g1.hp < g1_hp and g2.hp < g2_hp, "이그니스 화염구 폭발: 주변 적까지 피해 (%d, %d)" % [g1_hp - g1.hp, g2_hp - g2.hp])
	g1.despawn()
	g2.despawn()
	_gm.equip_item(iron)

	print("[방패 가드]")
	player.global_position = Vector2(200, 100)
	_check(hud.get_node("%GuardBar").value == 40.0, "HUD 가드 게이지 표시")
	await _frames(40)
	aim = player.get_aim_direction()
	Input.action_press(&"guard")
	await _frames(20)
	_check(player.is_guarding(), "우클릭 가드")
	_check(not player.can_attack(), "가드 중에는 공격 불가")
	var hp1: int = _gm.hp
	pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + aim * 24.0, -aim, 200.0, 10, null))
	await _frames(15)
	_check(_gm.hp == hp1 - 3, "정면 가드: 나무 방패 70%% 막음 (HP %d → %d)" % [hp1, _gm.hp])
	_check(_gm.guard < 40.0 and hud.get_node("%GuardBar").value < 40.0, "가드 게이지 소모 → HUD 반영")

	await _frames(20)
	var hp2: int = _gm.hp
	pool.spawn(ProjectileSpec.enemy_bullet(player.global_position - aim * 24.0, aim, 200.0, 10, null))
	await _frames(15)
	_check(_gm.hp == hp2 - 10, "등 뒤 공격은 막지 못함 (HP %d → %d)" % [hp2, _gm.hp])

	Input.action_release(&"guard")
	await _frames(45)
	Input.action_press(&"guard")
	await _frames(1)
	var hp3: int = _gm.hp
	var bullet := pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + aim * 12.0, -aim, 200.0, 10, null))
	await _frames(6)
	_check(_gm.hp == hp3, "퍼펙트 가드: 피해 0")
	_check(bullet.is_active and bullet.get_team() == ProjectileSpec.Team.PLAYER, "퍼펙트 가드: 탄 반사 (플레이어 편으로 전환)")

	Input.action_release(&"guard")
	await _frames(2)
	var brute := goblin_scene.instantiate() as Enemy
	brute.move_speed = 0.0
	stage._add_enemy(brute, _enemy_pos_for_hit_center(player.get_attack_origin() + aim * 40.0))
	await _frames(3)
	Input.action_press(&"guard")
	await _frames(1)
	var parry := player.take_hit(10, brute.get_hit_center(), brute)
	_check(parry == Player.HitResult.PARRIED and brute.is_stunned(), "퍼펙트 가드: 근접 적 기절")
	brute.despawn()

	await _frames(20)
	var broke := false
	for i in 6:
		player.take_hit(30, player.global_position + aim * 20.0)
		await _frames(18)
		if guard_ctl.is_broken():
			broke = true
			break
	_check(broke and not player.is_guarding() and _gm.guard == 0.0, "게이지 소진 → 가드 브레이크")
	Input.action_release(&"guard")
	_gm.heal_full()
	await _frames(90)
	_check(_gm.guard > 0.0, "가드를 내리면 게이지 회복")

	print("[상점 - 스테이지별 입고 / 등급 배경색 / 투구]")
	_gm.add_gold(5000)
	_gm.request_shop("테스트 상점", [&"rapid_crossbow", &"iron_shield", &"iron_helm", &"royal_aegis", &"solaris_bow"])
	await get_tree().process_frame
	var gold_pre: int = _gm.gold
	_check(shop.is_open() and get_tree().paused, "상점 열림 + 일시정지")
	var rows := shop.get_node("%BuyList").get_children()
	_check(rows.size() == 5, "판매 목록 5개 (무기/방패/투구)")
	_check(_row_bg(rows, 0) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.RARE], "희귀 = 파란 배경")
	_check(_row_bg(rows, 3) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.EPIC], "레어 = 보라 배경")
	_check(_row_bg(rows, 4) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.LEGENDARY], "전설 = 노란 배경")
	_check(_row_button(rows, 3).disabled and _row_button(rows, 3).text == "2스테이지", "1스테이지: 레어 등급 잠김")
	_check(_row_button(rows, 4).disabled and _row_button(rows, 4).text == "3스테이지", "1스테이지: 전설 등급 잠김")
	var crossbow := ItemDB.get_weapon(&"rapid_crossbow")
	var iron_shield := ItemDB.get_shield(&"iron_shield")
	var iron_helm := ItemDB.get_helmet(&"iron_helm")
	shop._on_buy_pressed(crossbow)
	shop._on_buy_pressed(iron_shield)
	shop._on_buy_pressed(iron_helm)
	await get_tree().process_frame
	_check(_gm.equipped_weapon == crossbow and _gm.equipped_shield == iron_shield and _gm.equipped_helmet == iron_helm, "구매 후 무기/방패/투구 자동 장착")
	_check(_gm.gold == gold_pre - crossbow.price - iron_shield.price - iron_helm.price, "골드 차감 %d" % (crossbow.price + iron_shield.price + iron_helm.price))
	_check(not _gm.buy_item(iron_shield), "중복 구매 불가")
	_check(hud.get_node("%GuardBar").max_value == iron_shield.max_guard, "방패 교체 → 가드 게이지 최대치 변경")
	_check(_gm.max_hp == 100 + iron_helm.bonus_max_hp, "투구 체력 보너스 (최대 HP %d)" % _gm.max_hp)
	_check(_gm.get_total_defense() == iron_shield.defense + iron_helm.defense, "방어력 합산 (방패 %d + 투구 %d)" % [iron_shield.defense, iron_helm.defense])
	var helmet_sprite := player.get_node("BodySprite/HelmetSprite") as Sprite2D
	_check(helmet_sprite.visible and helmet_sprite.texture == iron_helm.worn_texture, "플레이어 머리에 투구 표시")
	_check((hud.get_node("%HelmetLabel") as Label).text.contains(iron_helm.display_name), "HUD 투구 표시")
	_check(shop.get_node("%InventoryList").get_child_count() == _gm.weapons.size() + _gm.shields.size() + _gm.helmets.size(), "보유 장비 목록 (무기 + 방패 + 투구)")
	shop.close()
	_check(not shop.is_open() and not get_tree().paused, "상점 닫힘 + 재개")
	_gm.cycle_weapon(1)
	_check(_gm.equipped_weapon != crossbow, "Q 무기 순환")

	print("[적 탄환/플레이어 피격]")
	player.global_position = Vector2(-200, 100)  # 상인(벽 판정)에 탄이 가로막히지 않는 빈 공간
	await _frames(40)
	var hp_before: int = _gm.hp
	pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + Vector2(30, -4), Vector2.LEFT, 200.0, 7, null))
	await _frames(20)
	_check(_gm.hp == hp_before - (7 - _gm.get_total_defense()), "적 탄환 피격, 방패+투구 방어력 적용 (HP %d → %d)" % [hp_before, _gm.hp])
	_check(hud.get_node("%HPLabel").text == "%d / %d" % [_gm.hp, _gm.max_hp], "HUD HP 라벨 갱신")

	print("[보스]")
	stage._begin_wave()
	stage._kills = stage._kill_target - 1
	var fodder := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	stage._add_enemy(fodder, Vector2(300, 200))
	await _frames(2)
	fodder.take_damage(9999)
	await _frames(3)
	_check(stage.get_state() == StageManager.State.BOSS, "목표 처치 수 달성 → 보스전")
	_check(hud.get_node("%BossBox").visible, "HUD 보스 체력바 표시")
	var boss: Enemy = null
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if (e as Enemy).is_boss:
			boss = e
	_check(boss != null, "보스 스폰")
	player.global_position = Vector2(-400, 250)
	var saw_enemy_bullets := false
	for i in 300:
		await get_tree().physics_frame
		for c in pool.get_children():
			if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
				saw_enemy_bullets = true
		if saw_enemy_bullets:
			break
	_check(saw_enemy_bullets, "보스 원형 탄막 발사 (풀 사용)")
	boss.take_damage(roundi(boss.max_hp / 3.0))
	_check(hud.get_node("%BossBar").value < boss.max_hp, "보스 체력바 갱신")
	var stage_no: int = _gm.stage
	boss.take_damage(99999)
	await _frames(3)
	_check(_gm.stage == stage_no + 1, "보스 처치 → 다음 스테이지")
	_check(_gm.hp == _gm.max_hp, "스테이지 클리어 체력 회복")
	_check(not hud.get_node("%BossBox").visible, "보스 체력바 숨김")
	var boss_drop := entities.get_children().filter(func(n: Node) -> bool: return n is Pickup and n.kind == Pickup.Kind.ITEM)
	_check(boss_drop.size() >= 1, "보스 장비 확정 드랍")

	print("[2스테이지 - 불타는 지옥문]")
	_check(_gm.stage == 2 and _gm.stage_name == "불타는 지옥문", "스테이지 2 「%s」" % _gm.stage_name)
	_check((main.get_node("Ground/Floor") as Sprite2D).texture.resource_path.ends_with("floor_hell.png"), "바닥이 지옥 타일로 변경")
	_check((hud.get_node("%StageLabel") as Label).text.contains("불타는 지옥문"), "HUD 스테이지 이름")
	_gm.request_shop("테스트 상점", [&"royal_aegis", &"solaris_bow"])
	await get_tree().process_frame
	rows = shop.get_node("%BuyList").get_children()
	_check(not _row_button(rows, 0).disabled and _row_button(rows, 1).disabled, "2스테이지: 레어 해금, 전설은 아직 잠김")
	shop.close()
	_gm.max_hp = 99999  # 보스 패턴 관찰용으로 버티기
	_gm.heal_full()
	stage._begin_wave()
	for i in 8:
		stage._spawn_regular_enemy()
	await _frames(3)
	var names := {}
	for e in get_tree().get_nodes_in_group(&"enemies"):
		names[(e as Enemy).display_name] = true
	_check(names.keys().all(func(n: String) -> bool: return n in ["헬하운드", "오크"]), "일반 몹: %s" % ", ".join(names.keys()))
	await _survive(240)
	_check(not _gm.is_player_dead, "헬하운드/오크 패턴 4초 실행")
	_clear_enemies()
	await _frames(20)
	stage._kills = 0
	stage._begin_boss()
	await _frames(3)
	var gatekeeper := _find_boss()
	_check(gatekeeper != null and gatekeeper.display_name == "지옥의 수문장", "2스테이지 보스: 지옥의 수문장")
	var seen := {"aoe": false, "fire": false, "hounds": false}
	await _survive(720, func() -> void:
		if _count_nodes_of("AoeStrike") > 0:
			seen["aoe"] = true
		for c in pool.get_children():
			if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
				seen["fire"] = true
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if (e as Enemy).display_name == "헬하운드":
				seen["hounds"] = true)
	_check(seen["fire"], "수문장: 화염구 고리")
	_check(seen["aoe"], "수문장: 화염 기둥 장판")
	_check(seen["hounds"], "수문장: 헬하운드 소환")
	gatekeeper.take_damage(99999)
	await _frames(3)

	print("[3스테이지 - 원소의 유적]")
	_check(_gm.stage == 3 and _gm.stage_name == "원소의 유적", "스테이지 3 「%s」" % _gm.stage_name)
	_check((main.get_node("Ground/Floor") as Sprite2D).texture.resource_path.ends_with("floor_ruins.png"), "바닥이 유적 타일로 변경")
	_clear_enemies()
	stage._begin_wave()
	# 4속성 골렘을 하나씩 확실히 소환해 모든 패턴을 실행
	for scene in stage.get_stage_data().enemy_scenes:
		var golem := scene.instantiate() as Enemy
		stage._add_enemy(golem, stage._pick_spawn_position())
	await _frames(3)
	names = {}
	for e in get_tree().get_nodes_in_group(&"enemies"):
		names[(e as Enemy).display_name] = true
	_check(names.size() == 4 and names.keys().all(func(n: String) -> bool: return n.ends_with("골렘")), "속성 골렘 4종: %s" % ", ".join(names.keys()))
	await _survive(360)
	_check(not _gm.is_player_dead, "골렘 속성 패턴 6초 실행")
	_clear_enemies()
	await _frames(20)
	stage._kills = 0
	stage._begin_boss()
	await _frames(3)
	var archeon := _find_boss() as BossArcheon
	_check(archeon != null and archeon.display_name == "원소의 거신 아르케온", "3스테이지 보스: 원소의 거신 아르케온")
	var elements_seen := {}
	seen = {"aoe": false, "slowed": false}
	await _survive(1200, func() -> void:
		if is_instance_valid(archeon):
			elements_seen[archeon.get_current_element()] = true
		if _count_nodes_of("AoeStrike") > 0:
			seen["aoe"] = true
		if player.is_slowed():
			seen["slowed"] = true)
	_check(elements_seen.size() == 4, "4원소 순환 (%d종)" % elements_seen.size())
	_check(seen["aoe"], "아르케온: 낙뢰/대지 장판")
	archeon.take_damage(roundi(archeon.max_hp * 0.6))
	_check(archeon._phase_two, "체력 50% 이하 → 원소 융합")
	await _survive(300)
	archeon.take_damage(999999)
	await _frames(3)
	_check(_gm.stage == 4 and _gm.stage_name.contains("+1"), "마지막 스테이지 이후 강화 반복: %s" % _gm.stage_name)
	var legend_drop := entities.get_children().filter(func(n: Node) -> bool: return n is Pickup and n.kind == Pickup.Kind.ITEM and n.item.rarity == ItemData.Rarity.LEGENDARY)
	_check(legend_drop.size() >= 1, "아르케온 전설 장비 드랍")

	print("[사망/재시작]")
	_gm.damage_player(_gm.hp)
	await _frames(2)
	_check(_gm.is_player_dead and hud.get_node("%GameOver").visible, "사망 → GAME OVER 표시")
	var ev := InputEventAction.new()
	ev.action = &"restart"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(10)
	_check(get_tree().current_scene != main and get_tree().current_scene != null, "씬 재시작")
	_check(_gm.hp == _gm.max_hp and _gm.stage == 1 and not _gm.is_player_dead, "GameManager 초기화")
	await _frames(10)

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
