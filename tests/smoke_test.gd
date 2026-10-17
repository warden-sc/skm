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


## 11~22스테이지: 잡몹 · 보스 패턴 · 보스 기믹. 22스테이지 보스(마지막 보스)를 쓰러뜨리지 않은 채 돌려줌
func _test_late_stages(main: Node2D, first: int = 11) -> Enemy:
	var player := main.get_node("Entities/Player") as Player
	var pool := main.get_node("ProjectilePool") as ProjectilePool
	var stage := main.get_node("StageManager") as StageManager
	var field_portal := main.get_node("Entities/FieldPortal") as Portal
	var gate := main.get_node("Entities/BossGate") as BossGate
	var next_portal := main.get_node("Entities/NextStagePortal") as Portal
	var boss_center := stage.boss_room.get_arena_rect().get_center()
	var stage_mobs := {
		11: ["실패한 실험체", "호문쿨루스", "광기의 연금술사"],
		12: ["마도 인형", "마도 드론", "마도 수호병"],
		13: ["어인 전사", "심해 해파리", "아귀"],
		14: ["태엽 병정", "모래 전갈", "시간의 망령"],
		15: ["거울 망령", "그림자 검사", "파편 정령"],
		16: ["하피", "바람 정령", "거대 독수리"],
		17: ["언덕 거인", "외눈 거인", "사슬 묶인 거인"],
		18: ["인형 병사", "광대 인형", "실 거미"],
		19: ["바다뱀", "폭풍 정령", "서리 정령"],
		20: ["견습 마법사", "마력 갑옷", "날아다니는 마도서"],
		21: ["태엽 거미", "증기 골렘", "기계 사수"],
		22: ["사막 도적", "사막 독사", "미라"],
	}
	var stage_names := {11: "금단의 연구소", 12: "마도 공장", 13: "가라앉은 신전", 14: "시간의 회랑", 15: "거울의 미궁", 16: "바람의 봉우리", 17: "거인의 감옥", 18: "인형 극장", 19: "폭풍의 바다", 20: "대마법사의 탑", 21: "기계 신전", 22: "모래 폭풍의 사막"}
	var boss_names := {11: "금단의 실험체 키메라", 12: "폭주한 마도기신 레기온", 13: "심해의 포식자 크라켄", 14: "모래시계의 파수꾼 아르케오스", 15: "거울에 갇힌 미혹의 도플갱어", 16: "천공의 수호자 그리핀", 17: "추방된 자 티탄", 18: "꼭두각시 마리오네트", 19: "폭풍의 지배자 레비아탄", 20: "대마법사 아르카나", 21: "기계의 정점 테모스", 22: "사막의 암살자 스콜피언"}
	var final_boss: Enemy = null
	for n in range(first, 23):
		next_portal.interacted.emit()
		await _frames(3)
		print("[%d스테이지 - %s]" % [n, stage_names[n]])
		_check(_gm.stage == n and _gm.stage_name == stage_names[n], "스테이지 %d 「%s」" % [n, _gm.stage_name])
		field_portal.interacted.emit()
		await _frames(2)
		for scene in stage.get_stage_data().enemy_scenes:
			stage._add_enemy(scene.instantiate() as Enemy, stage._pick_spawn_position(stage.field_room.get_arena_rect()), stage.field_room.get_arena_rect())
		await _frames(3)
		var names_now := _enemy_names()
		var all_mobs := true
		for mob_name in stage_mobs[n]:
			if not names_now.has(mob_name):
				all_mobs = false
		_check(all_mobs, "잡몹: %s" % ", ".join(stage_mobs[n]))
		await _survive(240)
		_check(not _gm.is_player_dead, "%d스테이지 잡몹 패턴 실행" % n)
		gate.open()
		gate.interacted.emit()
		await _frames(int(stage.boss_entry_delay * 60) + 10)
		var boss := _find_boss()
		_check(boss != null and boss.display_name == boss_names[n], "%d스테이지 보스: %s" % [n, boss_names[n]])
		if boss == null:
			continue
		player.global_position = boss_center + Vector2(0, 60)
		match n:
			11:
				var chimera := boss as BossChimera
				await _survive(5)
				_check(chimera.has_tail() and chimera.tail.max_hp == roundi(chimera.max_hp * chimera.tail_hp_ratio) and chimera.tail.hp == chimera.tail.max_hp, "[기믹] 키메라: 몸통과 꼬리 체력이 따로 (꼬리 %d)" % (chimera.tail.max_hp if chimera.tail != null else 0))
				var poison_seen := {"poison": false}
				chimera.cast(BossChimera.Pattern.STING)
				await _survive(120, func() -> void:
					if _gm.player_status.contains("독"):
						poison_seen["poison"] = true)
				_check(poison_seen["poison"], "꼬리 독액에 맞으면 독 (지속 피해)")
				var seen11 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen11["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen11["shot"] = true)
				_check(seen11["aoe"] and seen11["shot"], "키메라 패턴: 덮치기 · 화염 숨결 · 독액 · 포효")
				var power_before := chimera.power
				var contact_before := chimera.contact_damage
				chimera.tail.take_damage(999999)
				await _frames(3)
				_check(chimera.is_tail_cut() and is_equal_approx(chimera.power, power_before * 0.5) and chimera.contact_damage == roundi(contact_before * 0.5), "[기믹] 꼬리를 자르면 본체 공격력 50%% (%.2f → %.2f)" % [power_before, chimera.power])
				_check(chimera.get_status_text().contains("50%"), "꼬리 절단 상태 표시 (%s)" % chimera.get_status_text())
			12:
				var legion := boss as BossLegion
				await _survive(5)
				var core := legion.get_core()
				_check(core != null and core.relay_ratio == 1.5, "[기믹] 레기온 가슴의 마도코어 (약점)")
				if core != null:
					legion.set_physics_process(false)
					await _frames(2)
					var hp0 := legion.hp
					core.take_damage(1000)
					var core_drop := hp0 - legion.hp
					await _frames(1)
					var hp1 := legion.hp
					legion.take_damage(1000)
					var body_drop := hp1 - legion.hp
					_check(core_drop == legion.calc_damage(1500) and body_drop == legion.calc_damage(1000), "마도코어를 맞히면 피해 1.5배 (몸 %d / 코어 %d)" % [body_drop, core_drop])
					await _frames(1)
					var hp2 := legion.hp
					legion.take_damage(1000)
					core.take_damage(1000)
					_check(hp2 - legion.hp == legion.calc_damage(1500), "몸과 코어에 함께 맞아도 1.5배만 (중복 없음: %d)" % (hp2 - legion.hp))
					legion.set_physics_process(true)
				player.global_position = legion.get_hit_center() + Vector2(0, 90)
				legion.fire_laser()
				var laser := legion.get_laser()
				var laser_frames := int((laser.warn_time + laser.duration) * 60) + 10 if laser != null else 10
				var sweep := {"laser": laser, "total": 0.0, "last": INF, "hits": 0}
				laser = null  # 레이저는 끝나면 사라지므로 람다에는 딕셔너리로만 넘김
				await _survive(laser_frames, func() -> void:
					if not is_instance_valid(sweep["laser"]):
						return
					var beam := sweep["laser"] as LaserSweep
					if beam.is_firing():
						var a := beam.get_angle()
						if float(sweep["last"]) != INF:
							sweep["total"] = float(sweep["total"]) + absf(angle_difference(float(sweep["last"]), a))
						sweep["last"] = a
						sweep["hits"] = beam.get_hit_count())
				_check(float(sweep["total"]) > deg_to_rad(320.0), "[기믹] 레이저 한 줄기가 360도 회전 (%.0f도)" % rad_to_deg(float(sweep["total"])))
				_check(int(sweep["hits"]) >= 1, "회전 레이저에 닿으면 피해")
				var seen12 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen12["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen12["shot"] = true)
				_check(seen12["aoe"] and seen12["shot"], "레기온 패턴: 마력 포탄 · 주먹 충격파 · 마력탄 · 출격")
			13:
				var kraken := boss as BossKraken
				await _survive(10)
				_check(kraken.get_tentacles().size() == 4 and kraken.is_guarded(), "[기믹] 크라켄 주변에 촉수 4개 (체력 따로)")
				var hp_g := kraken.hp
				kraken.take_damage(1000, Vector2.ZERO, false, 9999)
				_check(hp_g - kraken.hp <= 301, "촉수가 남아 있으면 본체 피해 -70%% (%d)" % (hp_g - kraken.hp))
				for t in kraken.get_tentacles():
					t.take_damage(999999)
				await _frames(3)
				_check(not kraken.is_guarded() and kraken.get_status_text().contains("드러남"), "촉수를 모두 베면 본체가 드러남 (%s)" % kraken.get_status_text())
				hp_g = kraken.hp
				kraken.take_damage(1000, Vector2.ZERO, false, 9999)
				_check(hp_g - kraken.hp == 1000, "드러난 본체에는 피해가 그대로")
				kraken._regrow_left = 0.05
				kraken._stun_left = 0.0  # 촉수를 다 베이면 잠깐 기절하는데, 기절 중에는 다시 자라지 않음
				await _survive(10)
				_check(kraken.get_tentacles().size() == 4, "시간이 지나면 촉수가 다시 솟아오름")
				kraken.cast(BossKraken.Pattern.INK)
				await _survive(70)
				var ink: GroundZone = null
				for z in get_tree().get_nodes_in_group(&"hostile_zones"):
					if (z as GroundZone).kind == GroundZone.Kind.INK:
						ink = z as GroundZone
				_check(ink != null, "먹물 분사 → 먹물 웅덩이")
				if ink != null:
					player.global_position = ink.global_position
					await _survive(3)
					_check(player.is_slowed() and _gm.player_status.contains("먹물"), "먹물을 밟으면 크게 느려짐 (%s)" % _gm.player_status)
				var seen13 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen13["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen13["shot"] = true)
				_check(seen13["aoe"] and seen13["shot"], "크라켄 패턴: 먹물 · 소용돌이 · 촉수 내려치기")
			14:
				var arkeos := boss as BossArkeos
				arkeos.rewind_seconds = 1.0
				arkeos._rewind_cooldown = 999.0
				var spot_a := boss_center + Vector2(-70, 50)
				player.global_position = spot_a
				await _survive(80)
				player.global_position = boss_center + Vector2(80, 70)
				var hp_before := arkeos.hp
				arkeos.take_damage(2000, Vector2.ZERO, false, 9999)
				var snap := arkeos.get_past_snapshot()
				var target: Vector2 = snap["pos"]
				arkeos.begin_rewind()
				var strike_waiting := false
				for node in get_tree().current_scene.get_children():
					if node is AoeStrike and (node as Node2D).global_position.distance_to(target) < 2.0:
						strike_waiting = true
				_check(arkeos.is_rewind_pending() and strike_waiting, "[기믹] 시간 역행 예고: 보스가 끌려갈 자리를 알고 미리 장판")
				await _survive(int(arkeos.rewind_delay * 60) + 4)
				_check(arkeos.get_rewind_count() == 1 and arkeos.hp >= hp_before - 1, "시간 역행: 그동안 받은 피해가 되돌아감 (+%d)" % arkeos.get_last_rewind_heal())
				_check(player.global_position.distance_to(target) < 6.0 and target.distance_to(spot_a) < 40.0, "플레이어가 1초 전 자리로 강제 전이")
				var seen14 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen14["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen14["shot"] = true)
				_check(seen14["aoe"] and seen14["shot"], "아르케오스 패턴: 모래 가시 · 시곗바늘 · 시간의 모래")
			15:
				var doppel := boss as BossDoppelganger
				await _frames(3)
				var hp_e := doppel.hp
				doppel.take_damage(500, Vector2.ZERO, false, 9999)
				_check(doppel.is_emerging() and doppel.hp == hp_e and doppel.has_mirror(), "[기믹] 뒤의 거울 안에서 걸어 나옴 (나오는 동안 무적)")
				await _survive(int(BossDoppelganger.EMERGE_TIME * 60) + 5)
				_check(not doppel.is_emerging() and doppel.global_position.y > doppel.mirror.global_position.y + 20.0, "거울에서 걸어 나와 앞으로")
				_gm.report_player_attacked(ItemDB.get_weapon(&"rusty_sword"), Vector2.DOWN)
				await _survive(30)
				_check(doppel.get_last_mimic() == BossDoppelganger.Mimic.SLASH and doppel.get_mimic_count() == 1, "[기믹] 1페이즈 따라하기: 검으로 치면 검 베기로 되갚음")
				doppel.mimic(BossDoppelganger.Mimic.ARROW)
				var arrow_seen := false
				for c in pool.get_children():
					if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
						arrow_seen = true
				_check(arrow_seen, "활로 쏘면 화살로 따라함")
				var strikes_before := _count_nodes_of("AoeStrike")
				doppel.mimic(BossDoppelganger.Mimic.SPELL)
				_check(_count_nodes_of("AoeStrike") > strikes_before, "지팡이 마법은 플레이어 발밑 마법으로 따라함")
				doppel.take_damage(roundi(doppel.hp * 0.6), Vector2.ZERO, false, 9999)
				await _survive(30)
				_check(doppel.phase_two and doppel.get_clones().size() == BossDoppelganger.MAX_CLONES, "[기믹] 2페이즈: 분신 %d개 소환" % doppel.get_clones().size())
				var at_before := doppel.global_position
				var swapped := doppel.swap_with_clone()
				_check(swapped and doppel.global_position.distance_to(at_before) > 1.0, "본체가 분신과 자리를 바꿈")
				var mimics_before := doppel.get_mimic_count()
				_gm.report_player_attacked(ItemDB.get_weapon(&"rusty_sword"), Vector2.DOWN)
				await _survive(30)
				_check(doppel.get_mimic_count() == mimics_before, "2페이즈에서는 따라하기 대신 분신")
				doppel.mirror.take_damage(999999)
				await _frames(3)
				_check(doppel.is_mirror_broken() and doppel.get_clones().is_empty(), "거울을 부수면 분신이 모두 사라짐")
				doppel.summon_clones()
				await _frames(3)
				_check(doppel.get_clones().is_empty(), "거울이 없으면 분신을 다시 부를 수 없음")
				var seen15 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen15["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen15["shot"] = true)
				_check(seen15["aoe"] and seen15["shot"], "도플갱어 패턴: 거울 파편 · 순간이동 베기 · 파편 낙하")
			16:
				var griffin := boss as BossGriffin
				await _survive(5)
				var wings := griffin.get_wings()
				_check(wings.size() == 2 and wings[0].max_hp == roundi(griffin.max_hp * griffin.wing_hp_ratio) and wings[1].hp == wings[1].max_hp, "[기믹] 그리핀: 양쪽 날개에 몸통과 따로 체력 (%d)" % (wings[0].max_hp if not wings.is_empty() else 0))
				griffin.take_off()
				await _survive(30)
				var wings_air := true
				for w in griffin.get_wings():
					if not w.airborne or w.can_be_hit_by(Enemy.HitKind.MELEE):
						wings_air = false
				_check(griffin.is_flying() and not griffin.can_be_hit_by(Enemy.HitKind.MELEE) and not griffin.can_be_hit_by(Enemy.HitKind.MAGIC) and griffin.can_be_hit_by(Enemy.HitKind.BOW) and wings_air, "[기믹] 그리핀 비행: 공중에서는 몸통·날개 모두 활로만 맞음")
				griffin._flight_left = 0.01
				await _survive(80)
				_check(not griffin.is_flying(), "비행이 끝나면 급강하해 착지")
				var def_before := player.get_effective_defense()
				griffin.roar()
				await _frames(2)
				_check(player.is_armor_broken() and player.get_effective_defense() == maxi(def_before - griffin.roar_armor_break, 0) and _gm.player_status.contains("방어력 감소"), "[기믹] 포효: 플레이어 방어력 감소 (%d → %d · %s)" % [def_before, player.get_effective_defense(), _gm.player_status])
				var claw_before := _count_nodes_of("AoeStrike")
				await _survive(40)
				_check(_count_nodes_of("AoeStrike") > claw_before, "포효 뒤 강한 앞발톱 할퀴기")
				var seen16 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen16["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen16["shot"] = true)
				_check(seen16["aoe"] and seen16["shot"], "그리핀 패턴: 돌진 · 포효+발톱 · 깃털 · 비행")
				if not griffin.is_flying():
					griffin.take_off()
				await _survive(20)
				for w in griffin.get_wings():
					w.take_damage(999999)
				await _frames(3)
				_check(griffin.is_groggy() and not griffin.is_flying() and griffin.get_groggy_count() == 1 and griffin.get_status_text().contains("그로기"), "[기믹] 양쪽 날개를 부수면 땅에 처박히며 그로기 (%s)" % griffin.get_status_text())
				var gx := griffin.global_position
				griffin.take_off()
				await _survive(30)
				_check(not griffin.is_flying() and griffin.global_position.distance_to(gx) < 2.0, "그로기 중에는 움직이지도 날지도 못함")
				griffin._groggy_left = 0.01
				griffin._regrow_left = 0.01
				await _survive(10)
				_check(griffin.get_wings().size() == 2 and not griffin.is_groggy(), "시간이 지나면 날개가 다시 돋아남")
			17:
				var titan := boss as BossTitan
				titan.set_physics_process(false)
				titan.slam()
				await _survive(80)
				var rocks := titan.get_cover_rocks()
				_check(rocks.size() == titan.rocks_per_slam, "[기믹] 티탄 내려찍기 → 튄 돌 %d개가 경기장 곳곳에 박힘" % rocks.size())
				for e in get_tree().get_nodes_in_group(&"enemies"):
					if not (e as Enemy).is_boss:
						(e as Enemy).despawn()
				stage._release_projectiles()
				await _survive(60)
				if not rocks.is_empty():
					var rock := rocks[0]
					var hand := titan.get_hit_center() + Vector2(0, -26)
					var behind := rock.get_center() + hand.direction_to(rock.get_center()) * 30.0
					player.global_position = behind + Vector2(0, 5)
					player.velocity = Vector2.ZERO
					await _frames(2)
					_gm.hp = _gm.max_hp
					var hp_cover: int = _gm.hp
					titan.throw_boulder()
					await _frames(150)
					_check(rock.hits == 1 and _gm.hp >= hp_cover - 2, "[기믹] 박힌 바위 뒤에 숨으면 던진 바위를 막아 줌 (피해 %d)" % (hp_cover - _gm.hp))
				for r in titan.get_cover_rocks():
					r.crumble()
				await _frames(2)
				player.global_position = titan.global_position + Vector2(40, 90)
				player.velocity = Vector2.ZERO
				await _frames(2)
				_gm.hp = _gm.max_hp
				var hp_open: int = _gm.hp
				titan.throw_boulder()
				await _frames(150)
				_check(hp_open - _gm.hp >= titan.get_boulder_damage() - 3, "엄폐 없이 던진 바위에 맞으면 큰 피해 (-%d / 최대 체력의 %d%%)" % [hp_open - _gm.hp, roundi(titan.boulder_ratio * 100.0)])
				_gm.hp = _gm.max_hp
				titan.set_physics_process(true)
				var throws_before := titan._throws
				var seen17 := {"aoe": false}
				await _survive(700, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen17["aoe"] = true)
				_check(seen17["aoe"] and titan._throws > throws_before, "티탄 패턴: 내려찍기 · 바위 던지기 · 쇠사슬 휘두르기 · 구속구 내리치기")
			18:
				var mario := boss as BossMarionette
				await _survive(5)
				_check(mario.get_node("DarkMist") != null, "마리오네트: 검은 안개를 두름")
				var switches := mario.get_switches()
				var sides_ok := switches.size() == 4
				var arena18 := stage.boss_room.get_arena_rect()
				for sw in switches:
					var near_edge := minf(minf(sw.global_position.x - arena18.position.x, arena18.end.x - sw.global_position.x), minf(sw.global_position.y - arena18.position.y, arena18.end.y - sw.global_position.y))
					if near_edge > 40.0:
						sides_ok = false
				_check(sides_ok, "[기믹] 마리오네트 보스방 가장자리 네 곳에 스위치")
				mario.set_physics_process(false)
				player.global_position = boss_center + Vector2(0, 100)
				mario.begin_control()
				await _frames(2)
				_check(player.is_puppeted() and mario.get_threads() == 4 and is_equal_approx(player.get_puppet_strength(), 0.9) and not player.can_attack() and not player.can_guard() and _gm.player_status.contains("꼭두각시"), "[기믹] 꼭두각시 조종: 실 4가닥, 공격·가드 불가 (%s)" % _gm.player_status)
				var d0 := player.global_position.distance_to(mario.global_position)
				await _frames(40)
				_check(player.global_position.distance_to(mario.global_position) < d0 - 10.0, "조종당하면 마리오네트 쪽으로 끌려감")
				var strengths: Array[float] = []
				for i in 3:
					player.global_position = switches[i].global_position
					await _frames(3)
					strengths.append(player.get_puppet_strength())
				_check(mario.get_threads() == 1 and strengths[0] > strengths[1] and strengths[1] > strengths[2] and player.is_puppeted(), "스위치를 밟을 때마다 실이 끊어지며 구속력 약화 (%s)" % str(strengths))
				player.global_position = switches[3].global_position
				await _frames(3)
				_check(not player.is_puppeted() and not mario.is_controlling() and mario.get_release_count() == 1 and mario.is_stunned() and player.can_attack(), "스위치 4개를 모두 밟으면 구속에서 해방 + 마리오네트 휘청")
				mario._stun_left = 0.0
				mario.set_physics_process(true)
				mario.begin_control()
				mario._control_left = 0.02
				await _survive(5)
				_check(not player.is_puppeted(), "조종 시간이 다 되면 저절로 풀림")
				var seen18 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen18["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen18["shot"] = true)
				_check(seen18["aoe"] and seen18["shot"], "마리오네트 패턴: 실 베기 · 인형의 춤 · 바늘 · 소환")
			19:
				var levi := boss as BossLeviathan
				await _survive(5)
				var field := levi.get_field()
				_check(field != null, "[기믹] 레비아탄 보스방이 상단(구름) / 하단(폭풍우)으로 나뉨")
				if field != null:
					levi.set_physics_process(false)
					for e in get_tree().get_nodes_in_group(&"enemies"):
						if not (e as Enemy).is_boss:
							(e as Enemy).despawn()
					stage._release_projectiles()
					var upper_spot := Vector2(field.area.get_center().x - 60.0, field.get_divider_y() - 50.0)
					player.global_position = upper_spot
					levi._zone_pending = false
					levi._next_zone = StormField.Zone.UPPER
					var hits0 := levi.get_zone_hit_count()
					levi.begin_zone_attack()
					_check(field.get_warn_zone() == StormField.Zone.UPPER and levi.get_status_text().contains("상단"), "상단 공격 예고 (%s)" % levi.get_status_text())
					await _survive(int(levi.zone_warn * 60) + 6, func() -> void:
						player.global_position = upper_spot)
					_check(levi.get_zone_hit_count() == hits0 + 1, "상단 공격 때 상단에 있으면 고드름에 맞음")
					_check(levi.get_next_zone() == StormField.Zone.LOWER, "상단 다음은 하단 공격 (번갈아)")
					player.velocity = Vector2.ZERO
					levi.begin_zone_attack()
					await _survive(int(levi.zone_warn * 60) + 6, func() -> void:
						player.global_position = upper_spot)
					_check(levi.get_zone_hit_count() == hits0 + 1 and levi.get_zone_attack_count() >= 2, "하단 공격 때는 상단으로 피하면 안전")
					var lower_spot := Vector2(field.area.get_center().x + 60.0, field.get_divider_y() + 50.0)
					levi.begin_zone_attack()
					await _survive(int(levi.zone_warn * 60) + 6, func() -> void:
						player.global_position = lower_spot)
					_check(levi.get_zone_hit_count() == hits0 + 1, "상단 공격 때는 하단으로 피하면 안전")
					levi.set_physics_process(true)
				var b0 := levi.get_breath_count()
				levi.breath()
				var breath_shot := {"shot": false}
				await _survive(60, func() -> void:
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							breath_shot["shot"] = true)
				_check(levi.get_breath_count() == b0 + 1 and breath_shot["shot"], "[기믹] 상단·하단 상관없이 브레스")
				var zones_before := levi.get_zone_attack_count()
				var seen19 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen19["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen19["shot"] = true)
				_check(seen19["aoe"] and seen19["shot"] and levi.get_zone_attack_count() >= zones_before + 1, "레비아탄 패턴: 지대 공격 반복 · 꼬리 · 물보라 · 브레스")
			20:
				var mage := boss as BossArchmage
				await _survive(5)
				_check(mage.get_node("DarkMist") != null, "대마법사 아르카나: 검은 안개를 두름")
				mage.begin_chant()
				_check(mage.is_chanting() and mage.get_safe_spot() != Vector2.INF, "[기믹] 대마법 영창: 메테오 스웜 + 안전지대 표시")
				mage.take_damage(roundi(mage.get_interrupt_threshold() / 0.8) + 40, Vector2.ZERO, false, 9999)
				_check(not mage.is_chanting() and mage.get_interrupt_count() == 1 and mage.is_backlashed() and mage.is_stunned(), "영창 중 일정 피해를 주면 영창이 끊기고 마력 역류 (기절)")
				var hp_b := mage.hp
				mage.take_damage(1000, Vector2.ZERO, false, 9999)
				_check(hp_b - mage.hp == 1500, "마력 역류 중에는 받는 피해 1.5배 (%d)" % (hp_b - mage.hp))
				mage._backlash_left = 0.0
				mage._stun_left = 0.0
				mage.set_physics_process(false)
				mage.begin_chant()
				var safe := mage.get_safe_spot()
				player.global_position = safe
				_gm.hp = _gm.max_hp
				var hp_safe: int = _gm.hp
				mage._chant_left = 0.0001
				mage.set_physics_process(true)
				await _frames(3)
				mage.set_physics_process(false)
				_check(mage.get_meteor_count() == 1 and not mage.did_meteor_hit() and _gm.hp >= hp_safe - 1, "영창을 못 끊어도 안전지대 안에 있으면 메테오를 피함")
				mage.begin_chant()
				safe = mage.get_safe_spot()
				var arena20 := stage.boss_room.get_arena_rect()
				player.global_position = (safe + Vector2(mage.safe_radius + 50.0, 0.0) if safe.x < arena20.get_center().x else safe - Vector2(mage.safe_radius + 50.0, 0.0))
				_gm.hp = _gm.max_hp
				var hp_out: int = _gm.hp
				mage._chant_left = 0.0001
				mage.set_physics_process(true)
				await _frames(3)
				_check(mage.get_meteor_count() == 2 and mage.did_meteor_hit() and hp_out - _gm.hp >= roundi(_gm.max_hp * mage.meteor_ratio) - 2, "안전지대 밖에서 메테오를 맞으면 큰 피해 (-%d)" % (hp_out - _gm.hp))
				_gm.hp = _gm.max_hp
				var seen20 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen20["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen20["shot"] = true)
				_check(seen20["aoe"] and seen20["shot"], "아르카나 패턴: 화염 · 서리 · 낙뢰 · 비전 · 순간이동")
			21:
				var temos := boss as BossTemos
				await _survive(5)
				var machines := temos.get_machines()
				_check(machines.size() == 4 and machines[0].max_hp == roundi(temos.max_hp * temos.machine_hp_ratio) and machines[0].hp != temos.hp, "[기믹] 테모스와 연결된 냉각수 기계 4대 (체력 따로 %d)" % (machines[0].max_hp if not machines.is_empty() else 0))
				_check(temos.get_node_or_null("Sprite2D") != null and temos.sprite.get_child_count() >= 3, "몸통의 거대한 태엽과 작은 태엽들")
				var rot0 := temos._gear_big.rotation
				await _survive(10)
				_check(not is_equal_approx(temos._gear_big.rotation, rot0), "태엽이 돌아감")
				for i in 5:
					temos.cast(BossTemos.Pattern.GEARS)
					await _survive(30)
				_check(not temos.is_overheated() and temos.heat < 40.0, "냉각수 기계가 살아 있으면 스킬을 써도 열이 쌓이지 않음 (열 %.0f)" % temos.heat)
				for m in temos.get_machines():
					m.take_damage(999999)
				await _frames(3)
				_check(temos.get_machines().is_empty() and is_equal_approx(temos.get_cooling_rate(), temos.base_cooling), "냉각수 기계를 부수면 열이 거의 식지 않음")
				var casts := 0
				while not temos.is_overheated() and casts < 10:
					temos.cast(BossTemos.Pattern.GEARS)
					casts += 1
					await _survive(6)
				_check(temos.is_overheated() and temos.defense == roundi(temos._base_defense * 0.5) and temos.contact_damage == 0 and temos.get_status_text().contains("과열"), "[기믹] 스킬 %d번 만에 과열: 방어력 -50%% (%d), 몸통 피해 없음" % [casts, temos.defense])
				var skills0 := temos.get_skill_count()
				temos.cast(BossTemos.Pattern.PISTON)
				await _survive(60)
				_check(temos.get_skill_count() == skills0, "과열 중에는 스킬을 쓰지 못함 (공격 불가)")
				temos.heat = 0.5
				await _survive(5)
				_check(not temos.is_overheated() and temos.defense == temos._base_defense and temos.contact_damage > 0, "열이 정상으로 돌아오면 과열 해제 (방어력 복구)")
				var seen21 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen21["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen21["shot"] = true)
				_check(seen21["aoe"] and seen21["shot"] and temos.get_overheat_count() >= 1, "테모스 패턴: 톱니 탄 · 증기 · 피스톤 · 포격 · 소환")
			22:
				var scorp := boss as BossScorpion
				await _survive(5)
				scorp.take_damage(6000, Vector2.ZERO, false, 9999)
				var hp_low := scorp.hp
				player.global_position = boss_center + Vector2(0, 110)
				scorp.burrow()
				await _frames(2)
				var hp_burrow := scorp.hp
				scorp.take_damage(5000, Vector2.ZERO, false, 9999)
				_check(scorp.is_burrowed() and not scorp.sprite.visible and not scorp.can_be_hit_by(Enemy.HitKind.MELEE) and not scorp.can_be_hit_by(Enemy.HitKind.BOW) and not scorp.can_be_hit_by(Enemy.HitKind.MAGIC) and scorp.hp >= hp_burrow, "[기믹] 모래 속으로 숨으면 어떤 공격도 닿지 않음")
				var d_track := scorp.global_position.distance_to(player.global_position)
				var ambush := {"strike": false}
				var hold := player.global_position
				await _survive(int(scorp.burrow_time * 60) - 30, func() -> void:
					player.global_position = hold
					for node in get_tree().current_scene.get_children():
						if node is AoeStrike and (node as Node2D).global_position.distance_to(hold) < 3.0:
							ambush["strike"] = true)
				_check(scorp.hp > hp_low and scorp.get_healed_total() > 0, "숨어 있는 동안 체력 회복 (+%d)" % scorp.get_healed_total())
				_check(scorp.global_position.distance_to(player.global_position) < d_track - 20.0, "모래 둔덕이 플레이어를 쫓아옴")
				await _survive(60, func() -> void:
					player.global_position = hold
					for node in get_tree().current_scene.get_children():
						if node is AoeStrike and (node as Node2D).global_position.distance_to(hold) < 3.0:
							ambush["strike"] = true)
				_check(not scorp.is_burrowed() and scorp.sprite.visible and ambush["strike"] and scorp.global_position.distance_to(hold) < 12.0, "끝나기 직전 발밑에 예고 → 그 자리에서 솟구치며 기습")
				scorp.set_physics_process(false)
				scorp._burrow_cooldown = 999.0
				var below := scorp.get_hit_center() + Vector2(0, 44)
				player.global_position = below
				await _frames(1)
				scorp.cast(BossScorpion.Pattern.PINCER)
				await _survive(50, func() -> void:
					player.global_position = below)
				_check(player.is_armor_broken() and _gm.player_status.contains("방어력 감소"), "[기믹] 집게에 맞으면 갑각 분쇄 (방어력 감소)")
				scorp.cast(BossScorpion.Pattern.STING)
				var poisoned := {"poison": false}
				await _survive(110, func() -> void:
					player.global_position = below
					if _gm.player_status.contains("독"):
						poisoned["poison"] = true)
				_check(poisoned["poison"], "[기믹] 꼬리 독침에 맞으면 강한 독")
				scorp.set_physics_process(true)
				scorp._burrow_cooldown = 3.0
				var burrows0 := scorp.get_burrow_count()
				var seen22 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen22["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen22["shot"] = true)
				_check(seen22["aoe"] and seen22["shot"] and scorp.get_burrow_count() > burrows0, "스콜피언 패턴: 독침 · 집게 · 신경독 · 꼬리 휩쓸기 · 잠행 반복")
				if scorp.is_burrowed():
					scorp._burrow_left = 0.01
					await _survive(3)
				final_boss = scorp
		if n < 22:
			boss.take_damage(999999, Vector2.ZERO, false, 9999)
			await _frames(4)
			_check(not _gm.is_game_cleared and next_portal.enabled, "%d스테이지 보스 토벌 → 다음 스테이지 텔레포트" % n)
	return final_boss


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
	_check(hud.get_node("%Hotbar").get_child_count() == 14, "HUD 단축바 (무기 3 + 방어구 4 + 장신구 3 + 포션)")
	_check(_gm.get_potion_count(&"small_potion") == 2, "시작 포션: 작은 회복 포션 2개")
	_check(_gm.gold == 100, "시작 골드 100G")

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
	var rusty_weapon := ItemDB.get_weapon(&"rusty_sword")
	_check(rusty_damage >= rusty_weapon.damage - front.defense, "정면 적 타격 (데미지 %d, 슬라임 방어력 %d)" % [rusty_damage, front.defense])
	_check(behind.hp == hp_behind, "등 뒤 적은 맞지 않음")
	behind.despawn()
	# 슬라임이 뛰어드는 거리보다 검이 멀리 닿아야 함 (예전 리치 26 → 지금 38)
	var far := slime_scene.instantiate() as Enemy
	far.move_speed = 0.0
	far.max_hp = 999
	stage._add_enemy(far, _enemy_pos_for_hit_center(origin + aim * 36.0), camp_arena)
	await _frames(3)
	var hp_far := far.hp
	await _frames(25)
	attack.perform_attack()
	_check(far.hp < hp_far, "녹슨 검 사거리 %d — 36px 떨어진 슬라임도 맞음" % roundi(rusty_weapon.melee_range))
	far.despawn()

	print("[몬스터 방어력 / 방어력 관통]")
	var orc_test := (load("res://scenes/enemies/orc.tscn") as PackedScene).instantiate() as Enemy
	_check(orc_test.defense > front.defense and front.defense > 0, "잡몹에 방어력 (슬라임 %d · 오크 %d)" % [front.defense, orc_test.defense])
	_check(orc_test.calc_damage(20) == 20 - orc_test.defense, "방어력만큼 피해 감소 (20 → %d)" % orc_test.calc_damage(20))
	_check(orc_test.calc_damage(20, 4) == 20 - (orc_test.defense - 4), "방깍 4 → 방어력 무시 (20 → %d)" % orc_test.calc_damage(20, 4))
	_check(orc_test.calc_damage(20, 99) == 20, "방깍이 방어력보다 크면 피해 그대로")
	_check(orc_test.calc_damage(5) >= 1, "방어력이 높아도 최소 피해는 들어감")
	orc_test.free()
	for boss_path in ["res://scenes/enemies/boss_slime_king.tscn", "res://scenes/enemies/boss_hell_gatekeeper.tscn", "res://scenes/enemies/boss_archeon.tscn"]:
		var boss_test := (load(boss_path) as PackedScene).instantiate() as Enemy
		_check(boss_test.defense > 0, "보스 방어력: %s %d" % [boss_test.display_name, boss_test.defense])
		boss_test.free()

	print("[무기 특화]")
	var swords: Array[WeaponData] = []
	var bows: Array[WeaponData] = []
	var staffs: Array[WeaponData] = []
	for item in ItemDB.get_all():
		var w := item as WeaponData
		if w == null:
			continue
		if w.weapon_type == WeaponData.WeaponType.SWORD:
			swords.append(w)
		elif w.is_bow():
			bows.append(w)
		elif w.is_staff():
			staffs.append(w)
	var specialized := true
	for b in bows:
		for sw in swords:
			if sw.rarity == b.rarity and (b.damage >= sw.damage or b.attack_cooldown + b.windup_time >= sw.attack_cooldown):
				specialized = false
		if b.armor_pen <= 0:
			specialized = false
	_check(specialized, "활: 같은 등급 검보다 공격력 낮고 공속 빠름 + 방깍 보유")
	var all_aoe := true
	for st in staffs:
		if st.explosion_radius <= 0.0:
			all_aoe = false
	_check(all_aoe and staffs.size() == 6, "지팡이 %d종 모두 범위(폭발) 공격" % staffs.size())
	var sword_max := 0
	for item in ItemDB.get_all():
		var w2 := item as WeaponData
		if w2 != null and w2.rarity == ItemData.Rarity.LEGENDARY:
			sword_max = maxi(sword_max, w2.damage)
	_check(ItemDB.get_weapon(&"holy_sword").damage == sword_max, "검: 같은 등급 최고 공격력")

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

	print("[지팡이 - 지팡이마다 다른 범위 마법]")
	var staff_from := player.get_muzzle_position()
	var staff_aim := player.get_aim_direction()
	var staff_arena := stage.camp_room.get_arena_rect()
	var ratios_ok := true
	for staff_id in [&"apprentice_staff", &"frost_staff", &"slime_staff", &"ignis_staff", &"king_scepter", &"arcana_staff"]:
		var test_staff := ItemDB.get_weapon(staff_id)
		if not is_equal_approx(test_staff.explosion_damage_ratio, 0.8):
			ratios_ok = false
		var direct := slime_scene.instantiate() as Enemy
		var side := slime_scene.instantiate() as Enemy
		for target in [direct, side]:
			(target as Enemy).move_speed = 0.0
			(target as Enemy).max_hp = 9999
		var center := staff_from + staff_aim * 70.0
		stage._add_enemy(direct, _enemy_pos_for_hit_center(center), staff_arena)
		stage._add_enemy(side, _enemy_pos_for_hit_center(center + staff_aim.orthogonal() * 22.0), staff_arena)
		await _frames(3)
		Spells.cast_staff(player, test_staff, center)
		var sky_count := get_tree().get_nodes_in_group(&"sky_strikes").size()
		var saw_fire := false
		var saw_slime := false
		var side_slowed := false
		for f in 110:
			await get_tree().physics_frame
			for zone in get_tree().get_nodes_in_group(&"ground_zones"):
				if (zone as GroundZone).kind == GroundZone.Kind.FIRE:
					saw_fire = true
				else:
					saw_slime = true
			if is_instance_valid(side) and side.is_slowed():
				side_slowed = true
		_check(direct.hp < direct.max_hp and side.hp < side.max_hp, "%s(%s): %s — 옆의 적도 범위 피해" % [test_staff.display_name, test_staff.get_rarity_name(), WeaponData.SPELL_TEXT[test_staff.spell].get_slice(" —", 0)])
		match test_staff.spell:
			WeaponData.Spell.FROST_NOVA:
				_check(side_slowed, "서리 폭발: 범위 안의 적 모두 감속")
			WeaponData.Spell.SLIME_POOL:
				_check(saw_slime and side_slowed, "점액 웅덩이: 바닥 장판 + 감속")
			WeaponData.Spell.FIREBALL:
				_check(saw_fire, "업화: 폭발 후 불타는 땅")
			WeaponData.Spell.SLIME_METEOR:
				_check(sky_count == 1 and saw_slime, "거대 슬라임: 하늘에서 1개 낙하 + 점액 웅덩이")
			WeaponData.Spell.STARFALL:
				_check(sky_count == test_staff.strike_count, "별똥별: 하늘에서 %d개 낙하" % sky_count)
		direct.despawn()
		side.despawn()
		await _frames(5)
	_check(ratios_ok, "지팡이 6종 주변 피해 모두 80%")
	# 영창 중 조준한 곳에 범위 원 표시
	_gm.add_item(ItemDB.get_item(&"ignis_staff"))
	_gm.equip_item(ItemDB.get_item(&"ignis_staff"))
	await _frames(12)
	Input.action_press(&"attack")
	await _frames(10)
	var ring := player.get_node("TargetRing") as TargetRing
	_check(ring.visible and is_equal_approx(ring.radius, ItemDB.get_weapon(&"ignis_staff").explosion_radius), "영창 중 조준한 곳에 폭발 범위 원 표시 (반경 %d)" % roundi(ring.radius))
	Input.action_release(&"attack")
	await _frames(3)
	_check(not ring.visible, "영창 취소 → 범위 원 숨김")
	_gm.equip_item(staff)
	await _frames(40)

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

	print("[장신구 - 팔찌 · 반지 · 펜던트]")
	_gm.select_weapon_slot(0)
	var ruby := ItemDB.get_accessory(&"ruby_ring")
	var star := ItemDB.get_accessory(&"star_ring")
	var bracelet := ItemDB.get_accessory(&"obsidian_bracelet")
	var pendant := ItemDB.get_accessory(&"guardian_pendant")
	for acc in [ruby, star, bracelet, pendant]:
		_gm.add_item(acc)
	_gm.equip_item(ruby)
	_gm.equip_item(star)
	_check(_gm.accessory_slots[AccessoryData.SlotType.RING] == star and not _gm.is_equipped(ruby), "반지 칸은 1개 — 별의 반지가 루비 반지를 교체")
	_gm.equip_item(ruby)
	_gm.equip_item(bracelet)
	_check(_gm.accessory_slots[AccessoryData.SlotType.BRACELET] == bracelet and _gm.accessory_slots.count(null) == 1, "팔찌 칸 · 반지 칸 사용")
	_check(is_equal_approx(_gm.get_crit_chance_bonus(), ruby.crit_chance_bonus), "반지: 치명타 확률 +%d%%" % roundi(_gm.get_crit_chance_bonus() * 100.0))
	_check(is_equal_approx(_gm.damage_multiplier, 1.0 + ruby.attack_bonus), "반지: 공격력 +%d%%" % roundi(ruby.attack_bonus * 100.0))
	_check(is_equal_approx(_gm.get_crit_damage_bonus(), bracelet.crit_damage_bonus) and _gm.get_armor_pen(iron) == iron.armor_pen + bracelet.armor_pen, "팔찌: 치명타 피해 +%d%% · 방깍 %d" % [roundi(bracelet.crit_damage_bonus * 100.0), bracelet.armor_pen])
	_check(_gm.roll_weapon_damage(bow)["armor_pen"] == bow.armor_pen + bracelet.armor_pen, "활 방깍 + 팔찌 방깍 합산 (%d)" % (bow.armor_pen + bracelet.armor_pen))
	var spec := ProjectileSpec.from_weapon(bow, Vector2.ZERO, Vector2.RIGHT, _gm.roll_weapon_damage(bow))
	_check(spec.armor_pen == bow.armor_pen + bracelet.armor_pen, "화살 투사체에 방깍 전달")
	var def_before: int = _gm.get_total_defense()
	var hp_cap_before: int = _gm.max_hp
	_gm.equip_item(pendant)
	_check(_gm.get_total_defense() == def_before and _gm.max_hp == hp_cap_before + pendant.bonus_max_hp and is_equal_approx(_gm.get_hp_regen(), pendant.hp_regen), "펜던트: 최대 체력 +%d · 체력 재생 초당 %.1f (방어력 없음)" % [pendant.bonus_max_hp, pendant.hp_regen])
	_gm.hp = _gm.max_hp - 30
	var hp_before_regen: int = _gm.hp
	await _frames(122)
	_check(_gm.hp >= hp_before_regen + 2, "펜던트 체력 재생: 2초 동안 %d 회복" % (_gm.hp - hp_before_regen))
	_gm.unequip_item(pendant)
	_check(_gm.max_hp == hp_cap_before and is_zero_approx(_gm.get_hp_regen()), "펜던트 해제 → 원래 능력치")
	print("[신발 - 방어력 + 이동 속도]")
	var boots := ItemDB.get_item(&"iron_greaves") as BootsData
	_gm.add_item(boots)
	var def_no_boots: int = _gm.get_total_defense()
	_gm.equip_item(boots)
	_check(_gm.equipped_boots == boots and _gm.get_total_defense() == def_no_boots + boots.defense and is_equal_approx(_gm.get_move_speed_bonus(), boots.move_bonus), "신발 칸 장착: 방어력 +%d · 이동 속도 +%d%%" % [boots.defense, roundi(boots.move_bonus * 100.0)])
	_check((player.get_node("BodySprite/BootsSprite") as Sprite2D).visible, "플레이어 발에 신발 표시")
	var speed_start := player.global_position.x
	Input.action_press(&"move_right")
	await _frames(60)
	Input.action_release(&"move_right")
	var boots_dist := player.global_position.x - speed_start
	_gm.unequip_item(boots)
	await _frames(30)
	speed_start = player.global_position.x
	Input.action_press(&"move_left")
	await _frames(60)
	Input.action_release(&"move_left")
	var plain_dist := speed_start - player.global_position.x
	_check(boots_dist > plain_dist * 1.04, "신발을 신으면 더 빨리 달림 (%.0f px > %.0f px)" % [boots_dist, plain_dist])
	await _frames(30)
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
	_check(crit_amount == expected_crit, "치명타 피해 %d (팔찌 치피 반영)" % crit_amount)

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
	await _frames(2)
	_check(player.get_node("WeaponPivot/ShieldSprite").modulate.r > 1.2, "패링 판정 중 방패가 금빛으로 빛남")
	await _frames(10)
	var hp3: int = _gm.hp
	var bullet := pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + aim * 12.0, -aim, 200.0, 10, null))
	await _frames(6)
	_check(_gm.hp == hp3 and bullet.is_active and bullet.get_team() == ProjectileSpec.Team.PLAYER, "퍼펙트 가드 (가드 0.2초 뒤 맞아도 성공): 피해 0 + 탄 반사")
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
	_check(inventory.get_node("%WeaponSlots").get_child_count() == 3 and inventory.get_node("%ArmorSlots").get_child_count() == 4 and inventory.get_node("%AccessorySlots").get_child_count() == 3, "장비 칸: 무기 3 · 방어구 4 · 장신구 3")
	_check(inventory.get_node("%BagList").get_child_count() == _gm.items.size() + _gm.get_owned_potions().size(), "가방 목록: 포션 %d종 + 장비 %d개" % [_gm.get_owned_potions().size(), _gm.items.size()])
	inventory._on_unequip_pressed(ruby)
	await get_tree().process_frame
	_check(not _gm.is_equipped(ruby) and is_zero_approx(_gm.get_crit_chance_bonus()), "반지 칸 해제 → 치명타 보너스 제거")
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
	# 아래쪽 장비에 마우스를 올려 긴 설명이 나와도 목록·버튼 위치가 바뀌면 안 됨 (설명칸 높이 고정)
	await get_tree().process_frame
	var buy_scroll := shop.get_node("%BuyList").get_parent() as Control
	var list_rect_before := buy_scroll.get_global_rect()
	var bottom_button := _row_button(rows, 4)
	var button_rect_before := bottom_button.get_global_rect()
	bottom_button.mouse_entered.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(shop.get_node("%Detail").text.contains(ItemDB.get_item(&"solaris_bow").display_name), "아래쪽 장비에 마우스 → 설명 표시")
	_check(buy_scroll.get_global_rect() == list_rect_before and bottom_button.get_global_rect() == button_rect_before, "설명이 길어도 구매 목록·버튼 위치 그대로 (가려지지 않음)")
	var shop_panel := shop.get_node("Panel") as Control
	_check(Rect2(Vector2.ZERO, shop_panel.get_viewport_rect().size).encloses(shop_panel.get_global_rect()), "상점 창이 화면 밖으로 늘어나지 않음")
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
	# [기믹] 점액 분출 → 점액 바닥을 밟으면 느려짐
	(slime_king as BossSlimeKing).spew_slime()
	await _survive(70)
	var slime_floors := get_tree().get_nodes_in_group(&"hostile_zones")
	_check(slime_floors.size() >= 5, "[기믹] 슬라임 킹 점액 분출 → 바닥에 점액 웅덩이 %d개" % slime_floors.size())
	if not slime_floors.is_empty():
		player.global_position = (slime_floors[0] as Node2D).global_position
		await _survive(4)
		_check(player.is_slowed() and _gm.player_status.contains("점액"), "점액 바닥을 밟으면 이동 속도 감소 + 상태 표시 (%s)" % _gm.player_status)
		_check(hud.get_node("StatusLabel").visible, "HUD 에 상태 이상 표시")
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
	_check(chest_item != null and not (chest_item is AccessoryData) and not (chest_item is WeaponData and (chest_item as WeaponData).weapon_type == WeaponData.WeaponType.DAGGER), "상자 장비 종류: 검/활/지팡이/방패/투구/갑옷")
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
	# [기믹] 화상: 방어력이 높을수록 지속 피해 감소
	_check(gatekeeper.burn_damage > 0, "[기믹] 수문장의 불 공격에 화상 부여 (0.5초마다 %d)" % gatekeeper.burn_damage)
	player.apply_burn(10, 2.0)
	var burn_low_def := player.get_burn_tick_damage()
	var def_items := [ItemDB.get_item(&"paladin_plate"), ItemDB.get_item(&"gatekeeper_horns"), ItemDB.get_item(&"windwalker_boots")]
	var worn_before := [_gm.equipped_armor, _gm.equipped_helmet, _gm.equipped_boots]
	for it in def_items:
		_gm.add_item(it)
		_gm.equip_item(it)
	var burn_high_def := player.get_burn_tick_damage()
	_check(burn_high_def < burn_low_def, "화상 피해는 방어력이 높을수록 감소 (방어력 낮음 %d → 높음 %d)" % [burn_low_def, burn_high_def])
	_gm.hp = _gm.max_hp
	var hp_burn_start: int = _gm.hp
	await _frames(70)
	_check(_gm.hp < hp_burn_start, "화상: 가드·무적으로 막을 수 없는 지속 피해 (-%d)" % (hp_burn_start - _gm.hp))
	for i in def_items.size():
		if worn_before[i] != null:
			_gm.equip_item(worn_before[i])
		else:
			_gm.unequip_item(def_items[i])
	var fire_hit := {"burned": false}
	gatekeeper.global_position = player.global_position + Vector2(60, 0)
	gatekeeper.shoot(Vector2.LEFT, 160.0, 5, null, 0.0, Elements.Type.FIRE, player.global_position + Vector2(30, 0))
	await _survive(30, func() -> void:
		if player.is_burning():
			fire_hit["burned"] = true)
	_check(fire_hit["burned"], "수문장의 화염구에 맞으면 화상")
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
	# [기믹] 원소 강화
	var base_def := archeon.defense
	archeon.apply_element_buff(Elements.Type.EARTH)
	_check(archeon.defense >= base_def + archeon.earth_defense_bonus - 0 and archeon.get_buff_text().contains("대지의 갑주"), "[기믹] 대지: 대지의 갑주 — 방어력 %d → %d" % [base_def, archeon.defense])
	archeon.apply_element_buff(Elements.Type.ICE)
	var shield_start := archeon.ice_shield
	var hp_ice := archeon.hp
	archeon.take_damage(50, Vector2.ZERO, false, 999)
	_check(shield_start > 0 and archeon.ice_shield == shield_start - 50 and archeon.hp == hp_ice, "[기믹] 빙결: 얼음 보호막 %d 이 피해를 먼저 흡수" % shield_start)
	archeon.apply_element_buff(Elements.Type.LIGHTNING)
	_check(archeon.move_speed > archeon._base_speed * 1.5 and archeon.ice_shield == 0, "[기믹] 뇌전: 뇌신 — 이동 속도 x%.1f + 순간이동" % (archeon.move_speed / archeon._base_speed))
	archeon.apply_element_buff(Elements.Type.FIRE)
	_check(archeon.burn_damage > 0 and archeon.defense == archeon._base_defense, "[기믹] 화염: 작열 — 공격에 화상, 이전 속성 능력은 사라짐")
	await _survive(240)
	archeon.take_damage(999999)
	await _frames(4)
	_check(not _gm.is_game_cleared and stage.get_chest() != null and next_portal.enabled, "3스테이지 보스 토벌 → 상자 + 4스테이지 텔레포트 (아직 엔딩 아님)")
	next_portal.interacted.emit()
	await _frames(3)

	print("[4스테이지 - 드라이어드의 숲]")
	_check(_gm.stage == 4 and _gm.stage_name == "드라이어드의 숲", "스테이지 4 「%s」" % _gm.stage_name)
	field_portal.interacted.emit()
	await _frames(2)
	for scene in stage.get_stage_data().enemy_scenes:
		stage._add_enemy(scene.instantiate() as Enemy, stage._pick_spawn_position(stage.field_room.get_arena_rect()), stage.field_room.get_arena_rect())
	await _frames(3)
	var forest_names := _enemy_names()
	_check(forest_names.has("숲 늑대") and forest_names.has("포자 버섯") and forest_names.has("덩굴 트렌트"), "숲 몬스터 3종: 숲 늑대, 포자 버섯, 덩굴 트렌트")
	var near_mushroom := (load("res://scenes/enemies/mushroom.tscn") as PackedScene).instantiate() as Enemy
	stage._add_enemy(near_mushroom, player.global_position + Vector2(90, 0), stage.field_room.get_arena_rect())
	var forest_seen := {"spores": false}
	await _survive(420, func() -> void:
		for c in pool.get_children():
			if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
				forest_seen["spores"] = true)
	_check(not _gm.is_player_dead and forest_seen["spores"], "숲 몬스터 패턴 실행 (포자 버섯의 포자 탄막)")
	gate.open()
	gate.interacted.emit()
	await _frames(int(stage.boss_entry_delay * 60) + 10)
	var dryad := _find_boss() as BossDryad
	_check(dryad != null and dryad.display_name == "숲의 주인 드라이어드", "4스테이지 보스: 숲의 주인 드라이어드")
	dryad.set_physics_process(false)  # 지휘 명령을 하나씩 검사하는 동안 자동 패턴 정지
	var boss_center := stage.boss_room.get_arena_rect().get_center()
	player.global_position = boss_center + Vector2(0, 40)
	dryad._summon()
	await _frames(4)
	var minions := dryad.get_minions()
	var all_linked := minions.size() == 3
	for m in minions:
		if m.commander != dryad:
			all_linked = false
	_check(all_linked, "숲 몬스터 소환 → 덩굴로 연결되어 드라이어드가 지휘 (%d마리)" % minions.size())
	# 돌격 명령
	var start_dist := {}
	for i in minions.size():
		minions[i].global_position = player.global_position + Vector2.RIGHT.rotated(TAU * i / minions.size()) * 90.0
		start_dist[i] = 90.0
	dryad.command_charge()
	var all_charging := true
	for m in minions:
		if m.get_command() != Enemy.Command.CHARGE:
			all_charging = false
	_check(all_charging and dryad.get_shout_text() == "돌격하라!", "「돌격하라!」 — 지휘 중인 몬스터 전부에게 돌격 명령")
	await _survive(36)
	var closed := 0
	for i in minions.size():
		if is_instance_valid(minions[i]) and minions[i].global_position.distance_to(player.global_position) < 60.0:
			closed += 1
	_check(closed == minions.size(), "돌격: 몬스터들이 일제히 플레이어에게 달려듦 (%d/%d)" % [closed, minions.size()])
	await _survive(60)
	# 포위 명령 (벽에 붙지 않도록 방 가운데에서)
	player.global_position = boss_center + Vector2(0, 40)
	for i in minions.size():
		minions[i].global_position = player.global_position + Vector2(-20.0 + 20.0 * i, 70.0)
	var surround_center := player.global_position
	dryad.command_surround()
	await _survive(62)
	var ring_ok := dryad.get_shout_text() == "포위하라!"
	var min_gap := INF
	for i in minions.size():
		var spot: Vector2 = minions[i]._command_point
		var radius_ok := absf(spot.distance_to(surround_center) - 58.0) < 1.0
		if not radius_ok or minions[i].global_position.distance_to(spot) > 12.0:
			ring_ok = false
		for j in range(i + 1, minions.size()):
			min_gap = minf(min_gap, minions[i].global_position.distance_to(minions[j].global_position))
	_check(ring_ok and min_gap > 40.0, "「포위하라!」 — 몬스터들이 플레이어를 둥글게 에워쌈 (반경 58)")
	await _survive(20)
	var closing := 0
	for m in minions:
		if m.get_command() == Enemy.Command.CHARGE:
			closing += 1
	_check(closing == minions.size(), "포위 후 한꺼번에 덮침")
	await _survive(60)
	# 2페이즈: 호위 + 생명 흡수
	dryad.take_damage(roundi(dryad.max_hp * 0.55))
	_check(dryad._phase_two, "체력 50% 이하 → 숲의 분노")
	var hp_before_drain := dryad.hp
	var count_before := dryad.get_minions().size()
	dryad.command_guard()
	await _survive(100)
	var guarding := 0
	for m in dryad.get_minions():
		if m.global_position.distance_to(dryad.global_position) < 45.0:
			guarding += 1
	_check(guarding == count_before, "「나를 지켜라!」 — 몬스터들이 드라이어드 곁으로 돌아와 호위")
	await _survive(40)
	_check(dryad.hp > hp_before_drain and dryad.get_minions().size() == count_before - 1, "2페이즈: 호위하던 몬스터의 생명을 흡수해 회복 (+%d)" % (dryad.hp - hp_before_drain))
	# 자동 패턴 순환
	dryad.set_physics_process(true)
	var shouts := {}
	var dryad_seen := {"roots": false, "thorns": false}
	await _survive(1100, func() -> void:
		if is_instance_valid(dryad) and dryad.get_shout_text() != "":
			shouts[dryad.get_shout_text()] = true
		if _count_nodes_of("AoeStrike") > 0:
			dryad_seen["roots"] = true
		for c in pool.get_children():
			if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
				dryad_seen["thorns"] = true)
	_check(shouts.has("돌격하라!") and shouts.has("포위하라!") and dryad_seen["roots"] and dryad_seen["thorns"], "자동 패턴: 소환 · 돌격 · 포위 · 가시 · 뿌리 (%s)" % ", ".join(shouts.keys()))

	dryad.take_damage(999999)
	await _frames(4)
	_check(not _gm.is_game_cleared and stage.get_chest() != null and next_portal.enabled, "4스테이지 보스 토벌 → 상자 + 5스테이지 텔레포트 (아직 엔딩 아님)")
	next_portal.interacted.emit()
	await _frames(3)

	print("[5스테이지 - 어둠의 성]")
	_check(_gm.stage == 5 and _gm.stage_name == "어둠의 성", "스테이지 5 「%s」" % _gm.stage_name)
	var ambient := stage.get_node("Ambient") as CanvasModulate
	_check(ambient.color.v < 0.95 and ambient.color.b > ambient.color.r, "어둡고 푸르스름한 분위기 (화면 색 %s)" % ambient.color)
	_check(stage.get_boss_decor() != null and stage.get_boss_decor().texture.resource_path.ends_with("throne.png"), "보스방에 빈 옥좌")
	field_portal.interacted.emit()
	await _frames(2)
	for scene in stage.get_stage_data().enemy_scenes:
		stage._add_enemy(scene.instantiate() as Enemy, stage._pick_spawn_position(stage.field_room.get_arena_rect()), stage.field_room.get_arena_rect())
	await _frames(3)
	var knight_names := _enemy_names()
	_check(knight_names.has("기사") and knight_names.has("중기사") and knight_names.has("궁수"), "기사 3종: 기사, 중기사, 궁수")
	# 중기사: 정면 공격은 방패로 막고, 뒤에서 치면 그대로 들어감
	var heavy := (load("res://scenes/enemies/heavy_knight.tscn") as PackedScene).instantiate() as HeavyKnight
	heavy.max_hp = 9999
	heavy.move_speed = 0.0
	stage._add_enemy(heavy, player.global_position + Vector2(60, 0), stage.field_room.get_arena_rect())
	await _survive(40)
	var hp_h := heavy.hp
	heavy.take_damage(100, -heavy.get_facing() * 50.0, false, 999)
	var front_dmg := hp_h - heavy.hp
	hp_h = heavy.hp
	heavy.take_damage(100, heavy.get_facing() * 50.0, false, 999)
	var back_dmg := hp_h - heavy.hp
	_check(front_dmg < back_dmg * 0.5, "중기사: 정면은 방패로 막음 (정면 %d / 뒤 %d)" % [front_dmg, back_dmg])
	heavy.despawn()
	var arrows := {"shot": false}
	await _survive(360, func() -> void:
		for c in pool.get_children():
			if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
				arrows["shot"] = true)
	_check(not _gm.is_player_dead and arrows["shot"], "기사 패턴 실행 (궁수의 화살)")
	gate.open()
	gate.interacted.emit()
	await _frames(int(stage.boss_entry_delay * 60) + 10)
	var dullahan := _find_boss() as BossDullahan
	_check(dullahan != null and dullahan.display_name == "기사단장 듀라한", "5스테이지 보스: 기사단장 듀라한")
	var throne := stage.get_boss_decor()
	_check(dullahan != null and throne != null and dullahan.global_position.distance_to(throne.global_position) < 90.0, "빈 옥좌 옆에서 듀라한 등장 (옥좌와 거리 %d)" % roundi(dullahan.global_position.distance_to(throne.global_position)))
	dullahan.set_physics_process(false)
	player.global_position = stage.boss_room.get_arena_rect().get_center() + Vector2(0, 60)
	var body_def := dullahan.defense
	dullahan.throw_head()
	await _survive(4)
	var head := dullahan.get_thrown_head()
	_check(head != null and dullahan.is_headless() and dullahan.defense >= body_def + BossDullahan.HEADLESS_DEFENSE_BONUS, "[기믹] 머리 던지기 → 머리 없는 몸은 방어력 %d → %d" % [body_def, dullahan.defense])
	var hp_body := dullahan.hp
	dullahan.take_damage(60)
	_check(hp_body - dullahan.hp <= 12, "머리 없는 동안 몸에는 피해가 거의 안 들어감 (-%d)" % (hp_body - dullahan.hp))
	_check(head != null and head.defense == 0 and head.max_hp < dullahan.max_hp * 0.1, "약점인 머리는 방어력 0 · 체력 %d" % (head.max_hp if head != null else 0))
	if head != null:
		head.take_damage(999999)
	await _frames(3)
	_check(dullahan.is_exposed() and dullahan.defense == 0 and dullahan.get_status_text().contains("약점 노출"), "머리를 쓰러뜨리면 무릎 꿇음 + 약점 노출 (방어력 0)")
	hp_body = dullahan.hp
	dullahan.take_damage(100)
	_check(hp_body - dullahan.hp == 150, "약점 노출 중 받는 피해 x1.5 (100 → %d)" % (hp_body - dullahan.hp))
	dullahan.set_physics_process(true)
	await _survive(int(dullahan.kneel_time * 60) + 10)
	_check(not dullahan.is_exposed() and dullahan.defense == body_def, "시간이 지나면 머리가 다시 생겨 원래대로")
	# 머리를 못 잡으면 돌아가서 회복
	dullahan.set_physics_process(false)
	dullahan.take_damage(1500)
	dullahan.head_time = 0.5
	dullahan.throw_head()
	await _frames(4)
	var hp_before_return := dullahan.hp
	dullahan.set_physics_process(true)
	await _survive(50)
	_check(not dullahan.is_headless() and dullahan.hp > hp_before_return, "머리를 놓치면 몸으로 돌아가 회복 (+%d)" % (dullahan.hp - hp_before_return))
	dullahan.head_time = 12.0
	var dl_seen := {"slash": false, "wave": false}
	await _survive(900, func() -> void:
		if _count_nodes_of("AoeStrike") > 0:
			dl_seen["slash"] = true
		for c in pool.get_children():
			if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
				dl_seen["wave"] = true)
	_check(dl_seen["slash"] and dl_seen["wave"], "듀라한 패턴: 대검 베기 · 암흑 검기 · 돌진 · 기사 소환 · 머리 던지기")

	dullahan.take_damage(999999, Vector2.ZERO, false, 9999)
	if not dullahan.is_dead() and dullahan.get_thrown_head() != null:
		dullahan.get_thrown_head().take_damage(999999)
		await _frames(2)
		dullahan.take_damage(999999)
	await _frames(4)
	_check(not _gm.is_game_cleared and stage.get_chest() != null and next_portal.enabled, "5스테이지 보스 토벌 → 상자 + 6스테이지 텔레포트 (아직 엔딩 아님)")
	var stage_mobs := {
		6: ["홉고블린", "오크 전사", "오크 주술사"],
		7: ["해골 병사", "유령"],
		8: ["새끼 와이번", "리자드맨 투창병"],
		9: ["하급 서큐버스"],
		10: ["왕실 근위병", "궁정 마술사"],
	}
	var stage_names := {6: "오크 요새", 7: "망자의 묘지", 8: "비룡의 둥지", 9: "마계의 문", 10: "버려진 왕궁"}
	var boss_names := {6: "오크킹", 7: "죽음의 사신", 8: "와이번", 9: "상급마족 서큐버스", 10: "옥좌 잃은 왕"}
	var final_boss: Enemy = null
	for n in range(6, 11):
		next_portal.interacted.emit()
		await _frames(3)
		print("[%d스테이지 - %s]" % [n, stage_names[n]])
		_check(_gm.stage == n and _gm.stage_name == stage_names[n], "스테이지 %d 「%s」" % [n, _gm.stage_name])
		field_portal.interacted.emit()
		await _frames(2)
		for scene in stage.get_stage_data().enemy_scenes:
			stage._add_enemy(scene.instantiate() as Enemy, stage._pick_spawn_position(stage.field_room.get_arena_rect()), stage.field_room.get_arena_rect())
		await _frames(3)
		var names_now := _enemy_names()
		var all_mobs := true
		for mob_name in stage_mobs[n]:
			if not names_now.has(mob_name):
				all_mobs = false
		_check(all_mobs, "잡몹: %s" % ", ".join(stage_mobs[n]))
		await _survive(240)
		_check(not _gm.is_player_dead, "%d스테이지 잡몹 패턴 실행" % n)
		gate.open()
		gate.interacted.emit()
		await _frames(int(stage.boss_entry_delay * 60) + 10)
		var boss := _find_boss()
		_check(boss != null and boss.display_name == boss_names[n], "%d스테이지 보스: %s" % [n, boss_names[n]])
		if boss == null:
			continue
		player.global_position = boss_center + Vector2(0, 60)
		var seen6 := {"aoe": false, "shot": false}
		match n:
			6, 7:
				var before_names := _enemy_names().size()
				await _survive(900, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen6["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen6["shot"] = true)
				_check(seen6["aoe"] and seen6["shot"] and _enemy_names().size() >= before_names, "%s 패턴: 장판 · 탄막 · 부하 소환" % boss.display_name)
				if n == 6:
					var orc_king := boss as BossOrcKing
					orc_king.set_physics_process(false)
					var before_rally := orc_king.get_minions().size()
					orc_king.cast(BossOrcKing.Pattern.WAR_CRY)
					await _frames(4)
					var rallied_ok := orc_king.get_minions().size() > before_rally
					for m in orc_king.get_minions():
						if not m.has_meta(&"war_cry") or m.power < 1.3 or m.defense < 8:
							rallied_ok = false
					_check(rallied_ok, "[기믹] 족장의 함성: 오크킹이 부른 부하 %d명 강화 (공격력 x1.4 · 방어력 +8)" % orc_king.get_minions().size())
					var calm_power := orc_king.power
					orc_king.take_damage(roundi(orc_king.hp * 0.7), Vector2.ZERO, false, 999)
					orc_king.set_physics_process(true)
					await _survive(100)
					_check(orc_king.power > calm_power * 1.3 and orc_king.get_status_text().contains("광폭화"), "[기믹] 광폭화: 체력이 줄수록 공격력 증가 (x%.2f · %s)" % [orc_king.power / calm_power, orc_king.get_status_text()])
					orc_king.set_physics_process(true)
				if n == 7:
					var reaper := boss as BossReaper
					_check(reaper.get_node("DarkMist") != null and (reaper.get_node("DarkMist") as CPUParticles2D).emitting, "사신 몸에서 검은 안개가 피어오름")
					# 죽음의 낙인 (사신 공격이 섞이지 않도록 잠시 정지 + 부하·날아오는 탄 정리 — 아래 피해 검사는 체력을 채우지 않음)
					reaper.set_physics_process(false)
					for e in get_tree().get_nodes_in_group(&"enemies"):
						if not (e as Enemy).is_boss:
							(e as Enemy).despawn()
					stage._release_projectiles()
					await _frames(60)
					stage._release_projectiles()
					for node in get_tree().current_scene.get_children():
						if node is AoeStrike:
							node.queue_free()
					player.death_marks = 0
					for i in 4:
						player.add_death_mark(1)
					await _frames(2)
					_check(player.death_marks == 4 and not player.is_sentenced() and _gm.player_status.contains("죽음의 낙인 4/5"), "[기믹] 죽음의 낙인 4/5 (상태 표시: %s)" % _gm.player_status)
					_gm.hp = _gm.max_hp
					var hp_exec: int = _gm.hp
					player.add_death_mark(1)
					_check(player.is_sentenced(), "낙인 5개 → 사형 선고")
					await _frames(int(Player.EXECUTION_DELAY * 60) + 6)
					_check(_gm.hp <= hp_exec - roundi(_gm.max_hp * Player.EXECUTION_RATIO) + 1 and player.death_marks == 0, "사형 선고: 최대 체력의 35%% 피해 (-%d)" % (hp_exec - _gm.hp))
					_gm.hp = _gm.max_hp
					for i in 5:
						player.add_death_mark(1)
					while player.is_sentenced() and player._execution_left > 0.12:
						await get_tree().physics_frame
					player._start_dash(Vector2.RIGHT)  # 대시 입력 자체는 앞의 [이동/대시] 에서 검사
					for i in 20:
						await get_tree().physics_frame
					_check(player.last_execution_dodged and player.death_marks == 0 and not player.is_sentenced(), "사형 선고 순간 대시하면 회피 (dodged=%s marks=%d left=%.2f since=%.2f dead=%s hp=%d)" % [player.last_execution_dodged, player.death_marks, player._execution_left, player._since_dash, player._is_dead, _gm.hp])
					reaper.set_physics_process(true)
					player.global_position = reaper.global_position + Vector2(10, 0)  # 몸통·낫이 반드시 닿는 거리
					var mark_hit := {"marked": false}
					await _survive(360, func() -> void:
						if player.death_marks > 0 or player.is_sentenced():
							mark_hit["marked"] = true)
					_check(mark_hit["marked"], "사신의 공격에 맞으면 낙인이 쌓임 (left=%.2f dead=%s hp=%d)" % [player._execution_left, player._is_dead, _gm.hp])
					# 망령화
					reaper.enter_wraith()
					var misses := 0
					for i in 40:
						var hp_r := reaper.hp
						reaper.take_damage(10, Vector2.ZERO, false, 999)
						if reaper.hp == hp_r:
							misses += 1
					await _survive(30)
					_check(reaper.is_wraith() and misses >= 15 and reaper.sprite.modulate.a < 0.7, "[기믹] 망령화: 거의 투명해지고 공격이 잘 맞지 않음 (40번 중 %d번 빗나감)" % misses)
					reaper._exit_wraith()
				if n == 7:
					var reaper := boss as BossReaper
					reaper.set_physics_process(false)
					reaper.global_position = boss_center + Vector2(0, -80)
					reaper.cast(BossReaper.Pattern.BLINK)
					await _survive(30)
					_check(reaper.global_position.distance_to(player.global_position) < 80.0, "사신: 안개처럼 사라졌다 플레이어 곁에서 나타남")
					reaper.set_physics_process(true)
			8:
				var wyvern := boss as BossWyvern
				wyvern.take_off()
				await _survive(30)
				_check(wyvern.is_flying() and not wyvern.can_be_hit_by(Enemy.HitKind.MELEE) and not wyvern.can_be_hit_by(Enemy.HitKind.MAGIC) and wyvern.can_be_hit_by(Enemy.HitKind.BOW), "[기믹] 와이번 비행: 공중에서는 활로만 맞음")
				var hp_w := wyvern.hp
				Spells.damage_area(player, wyvern.get_hit_center(), 40.0, 500, 500, 0, 0.0)
				var staff_spec := ProjectileSpec.from_weapon(ItemDB.get_weapon(&"ignis_staff"), player.get_muzzle_position(), player.get_muzzle_position().direction_to(wyvern.get_hit_center()), {"amount": 500, "crit": false, "armor_pen": 0})
				staff_spec.max_distance = 400.0
				pool.spawn(staff_spec)
				await _survive(20)
				_check(wyvern.hp == hp_w, "비행 중 지팡이 마법·폭발은 닿지 않음")
				wyvern.set_physics_process(false)  # 빠르게 선회하므로 화살 한 발 검사 동안만 고정
				var bow_spec := ProjectileSpec.from_weapon(ItemDB.get_weapon(&"hunter_bow"), player.get_muzzle_position(), player.get_muzzle_position().direction_to(wyvern.get_hit_center()), {"amount": 500, "crit": false, "armor_pen": 99})
				bow_spec.max_distance = 400.0
				pool.spawn(bow_spec)
				var bow_hit := {"hit": false}
				await _survive(40, func() -> void:
					if is_instance_valid(wyvern) and wyvern.hp < hp_w:
						bow_hit["hit"] = true)
				_check(bow_hit["hit"], "비행 중에도 화살은 맞음")
				wyvern.set_physics_process(true)
				await _survive(int(wyvern.flight_time * 1.3 * 60) + 120)
				_check(not wyvern.is_flying(), "비행이 끝나면 급강하해 착지 → 다시 모든 공격이 닿음")
			9:
				var succubus := boss as BossSuccubus
				succubus.set_physics_process(false)
				succubus.global_position = player.global_position + Vector2(0, -90)
				succubus.set_physics_process(true)
				succubus.cast(BossSuccubus.Pattern.CHARM)
				var charm_seen := {"charmed": false, "behind": false}
				await _survive(110, func() -> void:
					if player.is_charmed() and not charm_seen["charmed"]:
						charm_seen["charmed"] = true
					if player.is_charmed() and is_instance_valid(succubus) and succubus.global_position.distance_to(player.global_position) < 50.0:
						charm_seen["behind"] = true)
				_check(charm_seen["charmed"], "[기믹] 서큐버스 매혹의 하트에 맞으면 매혹")
				_check(charm_seen["behind"], "매혹되면 서큐버스가 등 뒤로 순간이동")
				player.apply_charm(1.0, succubus)
				_check(not player.can_attack() and not player.can_guard() and _gm.player_status.contains("매혹"), "매혹 중: 공격·가드 불가 + 상태 표시")
				var charm_x := player.global_position.x
				Input.action_press(&"move_right")
				await _survive(20)
				Input.action_release(&"move_right")
				_check(player.global_position.x - charm_x < 12.0, "매혹 중: 이동 입력이 먹히지 않음")
				await _survive(60)
				_check(not player.is_charmed() and player.can_attack(), "매혹이 풀리면 다시 조작 가능")
			10:
				var king := boss as BossLostKing
				await _survive(10)
				_check(king.get_node("DarkMist") != null and king.get_status_text().contains("옥좌"), "옥좌 잃은 왕: 검은 안개 + 듀라한이 지키던 옥좌를 찾음 (%s)" % king.get_status_text())
				_check(king.has_crown() and (king.crown as CrownEnemy).king == king and king.crown.max_hp < king.max_hp, "[기믹] 왕관: 왕과 따로 체력 (%d)" % (king.crown.max_hp if king.crown != null else 0))
				king.raise_barrier()
				var hp_k := king.hp
				king.take_damage(500, Vector2.ZERO, false, 99)
				_check(king.is_barrier_up() and king.hp == hp_k, "왕관이 있으면 「왕관의 가호」로 공격을 막음")
				king.crown.take_damage(999999)
				await _frames(3)
				_check(king.is_crown_broken() and not king.is_barrier_up(), "왕관을 부수면 가호가 사라짐")
				hp_k = king.hp
				king.take_damage(500, Vector2.ZERO, false, 99)
				king.raise_barrier()
				_check(king.hp < hp_k and not king.is_barrier_up(), "왕관이 없으면 피해가 들어가고 가호를 다시 못 씀")
		boss.take_damage(999999, Vector2.ZERO, false, 9999)
		await _frames(4)
		_check(not _gm.is_game_cleared and next_portal.enabled, "%d스테이지 보스 토벌 → 다음 스테이지 텔레포트" % n)

	final_boss = await _test_late_stages(main)

	print("[엔딩 - 22스테이지 보스 토벌]")
	var kills_before: int = _gm.total_kills
	stage.ending_delay = 600.0  # 아래 테스트가 끝난 뒤 엔딩 화면을 따로 검사
	if final_boss != null:
		final_boss.take_damage(999999, Vector2.ZERO, false, 9999)
	await _frames(4)
	_check(_gm.is_game_cleared and stage.get_state() == StageManager.State.CLEARED, "마지막(22스테이지) 보스 토벌 → 모든 스테이지 클리어")
	_check(_gm.total_kills > kills_before and _gm.play_time > 0.0, "엔딩 기록: 처치 %d마리 · 플레이 %s" % [_gm.total_kills, _gm.get_play_time_text()])
	_check(stage.get_chest() == null and not next_portal.enabled and get_tree().get_nodes_in_group(&"enemies").is_empty(), "마지막 스테이지: 상자 / 텔레포트 없음, 남은 졸개 정리")
	stage.go_to_next_stage()
	await _frames(3)
	_check(_gm.stage == 22, "22스테이지 이후 반복 스테이지 없음")

	print("[난이도 배율]")
	_gm.difficulty = _gm.Difficulty.VERY_HARD
	var tough := slime_scene.instantiate() as Enemy
	var base_hp := tough.max_hp
	stage._add_enemy(tough, player.global_position + Vector2(0, -80), camp_arena)
	await _frames(2)
	var hp_mult: float = _gm.DIFFICULTY_INFO[_gm.Difficulty.VERY_HARD]["enemy_hp"]
	_check(tough.max_hp == roundi(base_hp * hp_mult), "베리하드: 몬스터 체력 %d → %d" % [base_hp, tough.max_hp])
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
	_check(not _gm.is_game_cleared and _gm.total_kills == 0, "엔딩 기록 초기화")
	await _frames(10)

	print("[엔딩 화면 → 난이도 선택]")
	var new_stage := get_tree().current_scene.get_node("StageManager") as StageManager
	new_stage.go_to_ending()
	await _frames(5)
	_check(get_tree().current_scene.name != "Ending", "클리어 전에는 엔딩으로 갈 수 없음")
	_gm.total_kills = 77
	_gm.report_game_cleared()
	new_stage.go_to_ending()
	await _frames(90)
	var ending := get_tree().current_scene
	_check(ending != null and ending.name == "Ending", "모든 스테이지 클리어 → 엔딩 화면")
	if ending != null and ending.name == "Ending":
		await _press_action(&"interact")
		await _frames(2)
		_check(ending.is_finished() and (ending.get_node("%RecordPanel") as Control).visible, "아무 키 → 연출 건너뛰고 모험 기록 표시")
		_check((ending.get_node("%Record") as Label).text.contains("77마리"), "기록: 처치 수 · 클리어 시간 · 골드 · 무기")
		(ending.get_node("%ReturnButton") as Button).pressed.emit()
		await _frames(10)
		var title_after := get_tree().current_scene
		_check(title_after != null and title_after.name == "Title" and (title_after.get_node("%DifficultyPanel") as Control).visible, "엔딩 → 난이도 선택 화면")
		_check(not _gm.is_game_cleared and _gm.stage == 1 and _gm.total_kills == 0, "새 모험을 위해 GameManager 초기화")

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
