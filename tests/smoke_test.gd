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
	_check(attack.attack(), "AttackController.attack() (녹슨 검)")
	_check(pool.get_available_count() == avail, "검은 투사체를 쓰지 않음 (풀 그대로)")
	var rusty_damage := hp_front - front.hp
	_check(rusty_damage >= 8, "정면 적 타격 (데미지 %d)" % rusty_damage)
	_check(behind.hp == hp_behind, "등 뒤 적은 맞지 않음")
	_check(far.hp == hp_far, "리치 밖 적은 맞지 않음")
	_check(player.get_node("WeaponPivot/SwingFx").modulate.a > 0.0, "휘두르기 이펙트 표시")
	behind.despawn()
	far.despawn()

	print("[원거리 공격 - 활은 투사체]")
	var bow := ItemDB.get_weapon(&"hunter_bow")
	_gm.add_item(bow)
	_gm.equip_item(bow)
	_check(attack.attack(), "활 발사")
	_check(pool.get_available_count() == avail - 1, "풀에서 투사체 1개 꺼냄")
	await _frames(60)
	_check(pool.get_available_count() == avail, "사거리 끝에서 풀로 반환")

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
	attack.attack()
	_check(dhp - dummy.hp >= 15, "강철 검 데미지 %d (녹슨 검 %d)" % [dhp - dummy.hp, rusty_damage])
	dummy.despawn()

	print("[방패 가드]")
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

	print("[상점]")
	_gm.add_gold(2000)
	var gold_pre: int = _gm.gold
	_gm.request_shop("테스트 상점", [&"rapid_crossbow", &"iron_shield"])
	await get_tree().process_frame
	_check(shop.is_open() and get_tree().paused, "상점 열림 + 일시정지")
	_check(shop.get_node("%BuyList").get_child_count() == 2, "판매 목록 2개 (무기 + 방패)")
	var crossbow := ItemDB.get_weapon(&"rapid_crossbow")
	var iron_shield := ItemDB.get_shield(&"iron_shield")
	shop._on_buy_pressed(crossbow)
	shop._on_buy_pressed(iron_shield)
	await get_tree().process_frame
	_check(_gm.equipped_weapon == crossbow and _gm.equipped_shield == iron_shield, "구매 후 무기/방패 자동 장착")
	_check(_gm.gold == gold_pre - crossbow.price - iron_shield.price, "골드 차감 %d" % (crossbow.price + iron_shield.price))
	_check(not _gm.buy_item(iron_shield), "중복 구매 불가")
	_check(hud.get_node("%GuardBar").max_value == iron_shield.max_guard, "방패 교체 → 가드 게이지 최대치 변경")
	_check(shop.get_node("%InventoryList").get_child_count() == _gm.weapons.size() + _gm.shields.size(), "보유 장비 목록 (무기 + 방패)")
	shop.close()
	_check(not shop.is_open() and not get_tree().paused, "상점 닫힘 + 재개")
	_gm.cycle_weapon(1)
	_check(_gm.equipped_weapon != crossbow, "Q 무기 순환")

	print("[적 탄환/플레이어 피격]")
	await _frames(40)
	var hp_before: int = _gm.hp
	pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + Vector2(30, -4), Vector2.LEFT, 200.0, 7, null))
	await _frames(20)
	_check(_gm.hp == hp_before - (7 - iron_shield.defense), "적 탄환 피격, 방패 방어력 적용 (HP %d → %d)" % [hp_before, _gm.hp])
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

	print("[사망/재시작]")
	_gm.damage_player(9999)
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
