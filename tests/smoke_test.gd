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

	print("[구조]")
	_check(attack is AttackController and not (attack is Node2D), "AttackController 는 Node (Node2D 아님)")
	_check(pool.get_total_count() == 128 and pool.get_available_count() == 128, "풀 사전 생성 128개")
	_check(_gm.equipped_weapon != null and _gm.equipped_weapon.id == &"rusty_sword", "시작 무기 장착")
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

	print("[발사/풀 반환]")
	var avail := pool.get_available_count()
	_check(attack.fire(), "AttackController.fire()")
	_check(pool.get_available_count() == avail - 1, "풀에서 1개 꺼냄")
	await _frames(40)
	_check(pool.get_available_count() == avail, "사거리 끝에서 풀로 반환")

	print("[피격/드랍/줍기]")
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	slime.weapon_drop_chance = 1.0
	stage._add_enemy(slime, player.global_position + Vector2(36, 0))
	await _frames(2)
	slime.move_speed = 0.0
	var hp0 := slime.hp
	var dir := player.global_position.direction_to(slime.global_position)
	pool.spawn(ProjectileSpec.from_weapon(_gm.equipped_weapon, player.global_position, dir, 1.0))
	await _frames(12)
	var rusty_damage := hp0 - slime.hp
	_check(rusty_damage >= 6, "녹슨 검 투사체 명중 (데미지 %d)" % rusty_damage)
	_check(pool.get_available_count() == avail or pool.get_available_count() == avail - 1, "관통 투사체 처리")

	var gold_before: int = _gm.gold
	slime.take_damage(9999)
	await _frames(3)
	var pickups := entities.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	var weapon_drops := pickups.filter(func(p: Pickup) -> bool: return p.kind == Pickup.Kind.WEAPON)
	_check(pickups.size() >= 2, "골드 확정 드랍 + 무기 드랍 생성 (%d개)" % pickups.size())
	_check(weapon_drops.size() == 1, "무기 드랍 (확률 1.0 설정)")
	for p in pickups:
		(p as Pickup).global_position = player.global_position
	await _frames(40)
	_check(_gm.gold > gold_before, "골드 획득 %d → %d" % [gold_before, _gm.gold])
	_check(_gm.inventory.size() == 2, "드랍 무기 인벤토리 추가")

	print("[무기 장착 → 데미지 변화]")
	var iron := WeaponDB.get_weapon(&"iron_sword")
	_gm.add_weapon(iron)
	_gm.equip_weapon(iron)
	_check(player.get_node("WeaponPivot/WeaponSprite").texture == iron.icon, "장착 무기 스프라이트 교체")
	var dummy := (load("res://scenes/enemies/goblin.tscn") as PackedScene).instantiate() as Enemy
	stage._add_enemy(dummy, player.global_position + Vector2(-36, 0))
	await _frames(2)
	dummy.move_speed = 0.0
	var dhp := dummy.hp
	pool.spawn(ProjectileSpec.from_weapon(_gm.equipped_weapon, player.global_position, player.global_position.direction_to(dummy.global_position), 1.0))
	await _frames(12)
	_check(dhp - dummy.hp >= 12, "강철 검 데미지 %d (녹슨 검 %d)" % [dhp - dummy.hp, rusty_damage])
	dummy.despawn()

	print("[상점]")
	_gm.add_gold(1000)
	var gold_pre: int = _gm.gold
	_gm.request_shop("테스트 상점", [&"hunter_bow", &"flame_blade"])
	await get_tree().process_frame
	_check(shop.is_open() and get_tree().paused, "상점 열림 + 일시정지")
	_check(shop.get_node("%BuyList").get_child_count() == 2, "판매 목록 2개")
	var bow := WeaponDB.get_weapon(&"hunter_bow")
	shop._on_buy_pressed(bow)
	_check(_gm.owns_weapon(&"hunter_bow") and _gm.equipped_weapon == bow, "구매 후 자동 장착")
	_check(_gm.gold == gold_pre - bow.price, "골드 차감 %d" % bow.price)
	_check(not _gm.buy_weapon(bow), "중복 구매 불가")
	shop.close()
	_check(not shop.is_open() and not get_tree().paused, "상점 닫힘 + 재개")
	_gm.cycle_weapon(1)
	_check(_gm.equipped_weapon != bow, "Q 무기 순환")

	print("[적 탄환/플레이어 피격]")
	await _frames(40)
	var hp_before: int = _gm.hp
	pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + Vector2(30, -4), Vector2.LEFT, 200.0, 7, null))
	await _frames(20)
	_check(_gm.hp == hp_before - 7, "적 탄환 피격 HP %d → %d" % [hp_before, _gm.hp])
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
	var boss_drop := entities.get_children().filter(func(n: Node) -> bool: return n is Pickup and n.kind == Pickup.Kind.WEAPON)
	_check(boss_drop.size() >= 1, "보스 무기 확정 드랍")

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
