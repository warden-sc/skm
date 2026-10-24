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
		if (e as Node).has_meta(&"gate_core") or (e as Node).has_meta(&"gate_elite"):
			continue  # 보스방 해방 시련의 파괴 물건 · 정예는 빼고
		names[(e as Enemy).display_name] = true
	return names


## 운영자 모드: 권한 없으면 단축키 무시 → 시험용 키로 권한 → 모드 · 패널 · 스테이지 이동 · 운영자 장비 · 강림 · 선물
func _press_key(keycode: Key, ctrl: bool = false, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	Input.parse_input_event(ev)
	await _frames(2)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


func _test_admin(main: Node2D) -> void:
	print("[운영자 모드 (개발자 수동 개입)]")
	Sfx.history.clear()
	var stage := main.get_node("StageManager") as StageManager
	var player := main.get_node("Entities/Player") as Player
	var cfg := ConfigFile.new()
	_check(cfg.load("res://export_presets.cfg") == OK and range(3).all(func(i: int) -> bool:
		var preset_name: String = cfg.get_value("preset.%d" % i, "name", "")
		var features: String = cfg.get_value("preset.%d" % i, "custom_features", "")
		return features.contains("admin_build") == (preset_name == "Windows (운영자)")),
		"배포용 내보내기(Windows Desktop · Web)에는 운영자 기능 없음 — 「Windows (운영자)」에만 admin_build")
	OS.unset_environment(Admin.ENV_KEY)
	Admin.refresh_authorization()
	var key_file := FileAccess.file_exists(Admin.KEY_FILE)
	if not key_file:
		_check(not Admin.authorized, "키 없음 → 권한 없음")
		await _press_key(KEY_A, true, true)
		await _press_key(KEY_F11)
		await _press_key(KEY_D, true, true)
		_check(not Admin.enabled and not Admin.set_enabled(true) and Admin.get_node_or_null(^"AdminLayer") == null and not Admin.descent_active,
			"권한 없음: Ctrl+Shift+A · F11 · Ctrl+Shift+D 를 눌러도 아무 일도 없음 (UI 도 안 만들어짐)")
	OS.set_environment(Admin.ENV_KEY, "wrong-key")
	Admin.refresh_authorization()
	_check(key_file or not Admin.authorized, "틀린 키 → 권한 없음")
	# 시험용 키 (진짜 운영자 키는 저장소에 없음 — 해시만)
	Admin.key_hash = "smoke-test-key".sha256_text()
	OS.set_environment(Admin.ENV_KEY, "smoke-test-key")
	Admin.refresh_authorization()
	_check(Admin.authorized and Admin.auth_source in ["env", "file"] and not Admin.enabled, "맞는 키(환경변수) → 권한 있음, 그래도 처음엔 일반 플레이어 모드")
	_check(Admin.machine_code().length() == 16 and Admin.DEV_MACHINE_CODES.is_empty(), "이 PC 코드 %s (DEV_MACHINE_CODES 에 넣으면 그 PC 에서만)" % Admin.machine_code())
	var hangul_a := InputEventKey.new()
	hangul_a.keycode = KEY_NONE
	hangul_a.physical_keycode = KEY_A
	_check(Admin.key_matches("\ufeffsmoke-test-key\r\n") and Admin._is_key(hangul_a, KEY_A) and Admin.explain_denied().contains(Admin.ENV_KEY),
		"메모장 BOM · 줄바꿈이 붙은 키도 인정 · 한글 자판에서도 Ctrl+Shift+A (같은 자리 키) · 권한 없을 때 이유는 출력 창에")
	stage.instant_travel = true
	stage.go_to_stage(3)
	await _frames(3)
	await _press_key(KEY_F11)
	_check(not Admin.is_panel_open(), "운영자 모드가 꺼져 있으면 F11 도 안 열림")
	await _press_key(KEY_A, true, true)
	_check(Admin.enabled and Admin.get_badge() != null and Admin.get_badge().visible and Admin.get_badge().text == "ADMIN MODE", "Ctrl+Shift+A → 운영자 모드 ON · 구석에 「ADMIN MODE」")
	await _press_key(KEY_F11)
	_check(Admin.is_panel_open() and get_tree().paused, "F11 → 운영자 패널 (게임 멈춤)")
	var panel := Admin.get_panel() as AdminPanel
	_check(panel != null and panel.item_option.item_count > 200, "패널: 선물할 아이템 목록 %d개" % (panel.item_option.item_count if panel != null else 0))
	await _press_key(KEY_F11)
	await _frames(2)
	_check(not Admin.is_panel_open() and not get_tree().paused, "F11 다시 → 패널 닫힘")
	_check(Admin.teleport_to_stage(12) and _gm.stage == 12, "자유 스테이지 이동: 12스테이지 야영지로")
	await _frames(3)
	stage._do_enter_field()
	await _frames(3)
	_check(Admin.open_boss_gate() and stage.boss_gate.is_open(), "보스방 문 바로 열기")
	await _frames(240)
	# 운영자 장비 한 벌
	var before_weapons: Array = _gm.weapon_slots.duplicate()
	var before_shield: ItemData = _gm.equipped_shield
	_check(Admin.set_gear(true) and Admin.god and _gm.equipped_weapon != null and _gm.equipped_weapon.id == &"admin_sword"
		and _gm.equipped_weapon.display_name == "운영자의 검" and _gm.weapon_slots[1].display_name == "운영자의 활", "운영자 장비 착용: 운영자의 검 · 활 · 지팡이")
	var worn_ids := [_gm.equipped_shield, _gm.equipped_helmet, _gm.equipped_armor, _gm.equipped_boots].map(func(it: ItemData) -> String: return String(it.id) if it != null else "")
	worn_ids.append_array(_gm.accessory_slots.map(func(it: ItemData) -> String: return String(it.id) if it != null else ""))
	_check(worn_ids.all(func(id: String) -> bool: return id.begins_with("admin_")) and worn_ids.size() == 7,
		"운영자의 방패 · 투구 · 갑옷 · 신발 · 반지 · 팔찌 · 펜던트 (%s)" % ", ".join(worn_ids))
	_check(player.has_wings() and _gm.equipped_armor.worn_texture.resource_path.ends_with("admin_armor_worn.png"), "갑옷 등 뒤에 날개 · 앞에 운영자의 문양")
	var hp_before: int = _gm.hp
	_gm.damage_player(999999999)
	var roll: Dictionary = _gm.roll_weapon_damage(_gm.equipped_weapon)
	_check(_gm.hp == hp_before and not _gm.is_player_dead and int(roll["amount"]) >= Admin.GEAR_DAMAGE, "무적 (피해 0) · 즉사급 공격력 %d" % int(roll["amount"]))
	_check(not _gm.can_sell(_gm.equipped_weapon) and not _gm.can_drop(_gm.weapon_slots[2]) and not (_gm.to_save_data()["weapon_slots"] as Array).has("admin_sword")
		and not (_gm.to_save_data()["items"] as Array).has("admin_bow") and _gm.to_save_data()["armor"] != "admin_armor", "운영자 장비는 팔기 · 버리기 · 저장 불가")
	_check(not Achievements.unlock(&"HARD_CLEAR"), "운영자 모드 중에는 업적 달성 안 됨")
	# 운영자 전용 스킬
	var attack := player.get_node("AttackController") as AttackController
	var skill_names := []
	for i in 3:
		var w: WeaponData = _gm.weapon_slots[i]
		skill_names.append(w.get_skill_name())
		_gm.skill_cooldowns.clear()
		var start_pos := player.global_position
		var target := AdminSkills.pick_target(player)
		_check(w.get_skill_icon() != null and w.get_skill_cooldown() <= 3.0 and attack.use_skill(w), "[Q] %s — %s" % [w.get_skill_name(), w.get_skill_info().get("desc", "")])
		await _frames(150)
		_check(player.modulate.a == 1.0 and not _gm.is_player_dead, "%s: 하늘에서 내려와 다시 보임" % w.get_skill_name())
		if i == 0 and target != null:
			_check(player.global_position.distance_to(start_pos) > 10.0 or start_pos.distance_to(target.global_position) < 40.0, "천상낙하참: 노린 적(보스 우선)에게 내리꽂힘")
	_check(skill_names == ["천상낙하참", "천벌의 빛화살", "창세의 빛"], "운영자 무기 스킬: %s" % ", ".join(skill_names))
	Admin.set_gear(false)
	_check(not Admin.god and _gm.weapon_slots == before_weapons and _gm.equipped_shield == before_shield and not _gm.owns_item(&"admin_sword")
		and not player.has_wings(), "운영자 장비 벗기 → 원래 장비로 (날개도 사라짐)")
	# 강림 · 가호
	var clean := Admin.sanitize({"lines": ["1", "2", "3", "4", "5", "6", "7"], "gold": 999999999999, "item": "no_such_item", "count": 500,
		"blessing": {"attack": 999999.0, "reduction": 300.0, "time": 99999.0}})
	_check((clean["lines"] as Array).size() == Admin.MAX_LINES and int(clean["gold"]) == Admin.MAX_GOLD and clean["item"] == "" and int(clean["count"]) == 99
		and float(clean["blessing"]["attack"]) == 10000.0 and float(clean["blessing"]["reduction"]) == 95.0 and float(clean["blessing"]["time"]) == Admin.BLESSING_MAX_TIME
		and Admin.sanitize({"item": "admin_sword"})["item"] == "admin_sword", "강림 내용 거르기: 대사 6줄 · 골드 · 가호 상한 · 없는 아이템 제외 (운영자 장비는 선물 가능)")
	_gm.damage_player(roundi(_gm.max_hp * 0.3))
	var gold_before: int = _gm.gold
	var potion := ItemDB.get_potion(&"greater_potion")
	var potion_id := potion.id
	var potions_before: int = _gm.get_potion_count(potion_id)
	var max_hp_before: int = _gm.max_hp
	var defense_before: int = _gm.get_total_defense()
	var chat_before := Chat.history.size()
	_check(Admin.descend({"lines": ["버텨라, 용사여!", "축복을 내리마."], "heal": true, "invincible": true, "shield_time": 20.0, "gold": 5000, "item": String(potion_id), "count": 2,
		"blessing": {"attack": 200.0, "max_hp": 50.0, "defense": 100.0, "reduction": 50.0, "time": 45.0}}),
		"Ctrl+Shift+D / 패널 → 개발자 강림 시작")
	await _frames(30)
	_check(get_tree().get_nodes_in_group(&"admin_developer").size() == 1 and Sfx.history.has(&"descent"), "하늘에서 빛기둥이 내리꽂히며 개발자 등장 (효과음)")
	await _frames(90)
	var box := Story.get_box()
	_check(Story.is_playing() and box != null and box.current_line().get("name", "") == Admin.DEV_NAME and box.current_portrait() == Admin.DEV_TEXTURE,
		"[개발자] 초상화 + 커스텀 대사창 「%s」" % (box.current_line().get("text", "") if box != null else ""))
	_check(Chat.history.size() >= chat_before + 2 and Chat.history[chat_before]["text"] == "버텨라, 용사여!" and Chat.history[chat_before]["kind"] == Chat.Kind.ADMIN,
		"강림 대사는 채팅창에도 [운영자] 글로 남음")
	Story.skip()
	await _frames(20)
	_check(_gm.hp == _gm.max_hp and _gm.has_buff(Admin.BLESSING_NAME) and _gm.has_buff(Admin.SHIELD_NAME) and _gm.gold == gold_before + 5000
		and _gm.get_potion_count(potion_id) > potions_before, "대사가 끝나면 선물: 체력 회복 · 운영자의 가호 · 보호막 · 5000G · 포션")
	_check(_gm.max_hp >= roundi(max_hp_before * 1.45) and _gm.get_total_defense() == defense_before * 2 and _gm.get_damage_reduction() >= 0.5
		and absf(_gm.get_buff_value("attack") - 2.0) < 0.001,
		"운영자의 가호 (직접 정한 수치): 공격 +200%% · 최대 체력 %d → %d · 방어 %d → %d · 받는 피해 -%d%%" % [max_hp_before, _gm.max_hp, defense_before, _gm.get_total_defense(), roundi(_gm.get_damage_reduction() * 100)])
	_check(_gm.is_invincible(), "개발자의 보호막: 무적")
	await _frames(150)
	_check(get_tree().get_nodes_in_group(&"admin_developer").is_empty() and not Admin.descent_active and Sfx.history.has(&"ascend"), "역 빛기둥을 타고 퇴장")
	# 운영자 장비 · 드랍 전용 · 신화 아이템도 선물
	Admin.apply_gifts(Admin.sanitize({"item": "admin_bow"}))
	Admin.apply_gifts(Admin.sanitize({"item": "goblin_dagger"}))
	_check(_gm.owns_item(&"admin_bow") and _gm.owns_item(&"goblin_dagger"), "운영자 장비 · 드랍 전용 장비도 선물로 받음")
	_check(AdminPanel.get_gift_items().size() == ItemDB.get_all().size() + AdminGear.get_all().size() and AdminGear.get_all().size() == 10,
		"선물 목록: 모든 아이템 %d개 + 운영자 장비 10종" % ItemDB.get_all().size())
	Admin.remove_admin_items()
	_check(not _gm.owns_item(&"admin_bow"), "운영자 장비 치우기")
	# 채팅
	Admin.set_enabled(false)
	await _frames(2)
	await _press_key(KEY_ENTER)
	_check(Chat.is_typing() and Net.ui_blocks_input(), "[Enter] → 채팅 입력 (그동안 용사 조작 막힘)")
	player.velocity = Vector2.ZERO  # 앞 테스트(운영자 스킬 등)에서 남은 밀림은 빼고 입력만 봄
	await _frames(2)
	var pos_before := player.global_position
	Input.action_press(&"move_right")
	await _frames(20)
	Input.action_release(&"move_right")
	_check(player.global_position.distance_to(pos_before) < 2.0, "채팅 입력 중에는 움직이지 않음")
	Chat._line.text = "안녕하세요 " + "가".repeat(200)
	Chat.submit()
	await _frames(2)
	var last := Chat.get_last()
	_check(not Chat.is_typing() and last.get("name", "") == _gm.hero_name and String(last.get("text", "")).begins_with("안녕하세요") and String(last["text"]).length() == Chat.MAX_CHARS
		and last["kind"] == Chat.Kind.PLAYER, "[Enter] 보내기 → 「%s: …」 (%d자 제한)" % [_gm.hero_name, Chat.MAX_CHARS])
	_check(Chat.send("/한 dkssudgktpdy") and Chat.get_last()["text"] == "안녕하세요", "채팅 「/한 dkssudgktpdy」 → 「안녕하세요」 (한글 입력기 대체)")
	Chat.open()
	(Chat._line.get_node("HangulInput") as HangulInput).type_keys("rkwk qhtmfmf whrwk")
	_check(Chat._line.text == "가자 보스를 족자", "채팅 칸에서도 한글이 여러 글자 조합되어 들어감 「%s」" % Chat._line.text)
	Chat._line.text = ""
	Chat.close()
	await _press_key(KEY_ENTER)
	await _press_key(KEY_ESCAPE)
	_check(not Chat.is_typing() and not get_tree().paused, "[Esc] → 채팅 취소 (설정창은 안 열림)")
	Admin.set_enabled(true)
	_check(Chat.send("운영자 테스트") and Chat.get_last()["kind"] == Chat.Kind.ADMIN and Chat.send_admin("공지입니다") and Chat.get_last()["name"] == Admin.DEV_NAME,
		"운영자 모드의 글 · 패널 공지는 금빛 [운영자] 글")
	Admin.set_enabled(false)
	_check(not Chat.send_admin("몰래 공지"), "운영자 모드가 아니면 공지 불가")
	Admin.set_enabled(true)
	await _press_key(KEY_A, true, true)
	_check(not Admin.enabled and not Admin.get_badge().visible, "Ctrl+Shift+A 다시 → 일반 플레이어 모드")
	OS.unset_environment(Admin.ENV_KEY)
	Admin.key_hash = Admin.ADMIN_KEY_SHA256
	Admin.refresh_authorization()
	_check(not Admin.authorized or key_file, "키를 지우면 다시 권한 없음")
	_gm._buffs.clear()
	_gm._recalculate_stats()


## 배경음: 스테이지마다 컨셉별 사냥터 곡 · 보스방은 보스 곡 · 야영지는 작게 · 최종장 곡
func _test_bgm(main: Node2D) -> void:
	print("[배경음]")
	var stage := main.get_node("StageManager") as StageManager
	var all_ok := true
	for n in range(1, 101):
		var path := Bgm.DIR + String(Bgm.field_track(n)) + ".ogg"
		if Bgm.field_track(n) == Bgm.TITLE_TRACK and n not in [1, 4, 16, 30]:
			all_ok = false
		if not ResourceLoader.exists(path) or not ResourceLoader.exists(Bgm.DIR + String(Bgm.boss_track(n)) + ".ogg"):
			all_ok = false
	_check(all_ok and ResourceLoader.exists(Bgm.DIR + "bgm_boss_07_final.ogg"), "1~100스테이지 모두 사냥터 곡 · 보스 곡이 있음")
	_check(Bgm.field_track(1) == &"bgm_field_01_meadow" and Bgm.field_track(7) == &"bgm_field_07_undead" and Bgm.field_track(71) == &"bgm_field_09_sea"
		and Bgm.boss_track(30) == &"bgm_boss_02_milestone" and Bgm.boss_track(33) == &"bgm_boss_03_dragon" and Bgm.boss_track(60) == &"bgm_boss_04_god"
		and Bgm.boss_track(90) == &"bgm_boss_05_abaddon" and Bgm.boss_track(100) == &"bgm_boss_06_gabriel" and Bgm.boss_track(6) == &"bgm_boss_01_normal",
		"곡 고르기: 1 초원 · 7 망자 · 71 바다 / 보스 30 10단위 · 33 용 · 60 신 · 90 아바돈 · 100 가브리엘 · 6 일반")
	stage.instant_travel = true
	stage.go_to_stage(7)
	await _frames(5)
	_check(Bgm.get_track() == &"bgm_camp_01_fantasy" and is_equal_approx(Bgm._gain, 1.0) and Bgm.get_active_player().playing, "야영지: 야영지 전용 곡 (1~37 중세 판타지)")
	_check(Bgm.camp_track(38) == &"bgm_camp_02_myth" and Bgm.camp_track(100) == &"bgm_camp_03_heaven" and Bgm.title_track() == &"bgm_title",
		"야영지 곡 3곡(38~80 그리스 · 81~100 천상) · 타이틀 전용 곡이 있음")
	stage._do_enter_field()
	await _frames(20)
	_check(Bgm.get_track() == &"bgm_field_07_undead" and is_equal_approx(Bgm._gain, 1.0), "사냥터: 망자의 묘지 곡")
	stage._do_enter_boss_room()
	await _frames(5)
	_check(Bgm.get_track() == &"bgm_boss_01_normal", "보스방: 보스 곡 (곡이 겹치며 넘어감)")
	var before := Bgm.get_active_player()
	before.seek(before.stream.get_length() - 1.0)
	await _frames(10)
	_check(Bgm.get_active_player() != before and Bgm.get_active_player().playing and Bgm.get_track() == &"bgm_boss_01_normal", "곡 끝에서 처음과 겹쳐 이어짐 (끊기지 않음)")
	Profile.set_setting("bgm_volume", 0.0)
	await _frames(120)
	_check(Bgm.get_active_player().volume_db <= -60.0, "설정 배경음 0% → 소리 없음")
	Profile.set_setting("bgm_volume", 0.7)
	stage._do_return_to_camp()
	await _frames(3)



## 효과음: 파일 · 무작위 변형 · 상황별로 나는지 · 너무 잦으면 한 번만
func _test_sfx(main: Node2D) -> void:
	print("[효과음]")
	var stage := main.get_node("StageManager") as StageManager
	var player := main.get_node("Entities/Player") as Player
	var names := [&"ui_click", &"menu_open", &"menu_close", &"inventory_open", &"inventory_close", &"dialogue_next", &"denied",
		&"gold_pickup", &"item_pickup", &"item_drop", &"equip_weapon", &"equip_armor", &"shop_buy", &"footstep", &"chest_open",
		&"gate_open", &"teleport", &"hit", &"hit_crit", &"boss_hit", &"enemy_death", &"boss_death", &"guard_block",
		&"guard_perfect", &"guard_break", &"player_hurt", &"skill_cast"]
	_check(names.all(func(n: StringName) -> bool: return not Sfx._variants(n).is_empty()) and Sfx.has_sounds(), "효과음 %d 가지 모두 파일이 있음" % names.size())
	_check(Sfx._variants(&"hit").size() == 5 and Sfx._variants(&"footstep").size() == 3 and Sfx._variants(&"enemy_death").size() == 3,
		"같은 상황의 다른 소리: 타격 5 · 발소리 3 · 처치 3 (무작위)")
	Sfx.history.clear()
	Sfx._last_time.clear()
	Sfx.play_local(&"hit")
	Sfx.play_local(&"hit")
	_check(Sfx.history.count(&"hit") == 1, "같은 소리를 한꺼번에 여러 번 → 한 번만")
	Sfx._last_time.clear()
	var arena := stage.field_room.get_arena_rect() if stage.field_room != null else Rect2(player.global_position - Vector2(200, 200), Vector2(400, 400))
	var mob := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	stage._add_enemy(mob, player.global_position + Vector2(120, 0), arena)
	await _frames(2)
	mob.take_damage(1)
	_check(Sfx.last_played == &"hit", "몬스터를 때림 → 타격음")
	Sfx._last_time.clear()
	mob.take_damage(1, Vector2.ZERO, true)
	_check(Sfx.last_played == &"hit_crit", "치명타 → 치명타 타격음")
	mob.take_damage(999999999)
	_check(Sfx.history.has(&"enemy_death"), "몬스터 처치 → 처치음")
	Sfx.history.clear()
	GameManager.boss_defeated.emit()
	_check(Sfx.history.has(&"boss_death"), "보스 토벌 → 보스 처치음")
	Pickup.receive(Pickup.Kind.GOLD, 1, null)
	_check(Sfx.history.has(&"gold_pickup"), "골드 줍기 → 동전 소리")
	var inventory := main.get_node("InventoryUI") as InventoryUI
	inventory.open()
	inventory.close()
	_check(Sfx.history.has(&"inventory_open") and Sfx.history.has(&"inventory_close"), "인벤토리 열기 · 닫기 소리")
	var button := Button.new()
	main.add_child(button)
	Sfx._last_time.clear()
	button.pressed.emit()
	_check(Sfx.last_played == &"ui_click", "화면의 버튼을 누르면 딸깍")
	button.queue_free()
	for p in Sfx._players:
		p.stop()
	Profile.set_setting("sfx_volume", 0.0)
	Sfx._last_time.clear()
	Sfx.play_local(&"hit")
	_check(Sfx._players.all(func(p: AudioStreamPlayer) -> bool: return not p.playing), "설정 효과음 0% → 소리 없음")
	Profile.set_setting("sfx_volume", 0.8)

## 보스방 해방 시련: 스테이지 컨셉별 7가지 (3 파괴 · 4 수집 · 5 점화 · 6 정예 · 9 수호 · 14 버티기)
func _test_gate_trials(main: Node2D) -> void:
	print("[보스방 해방 시련 (스테이지 컨셉별) · 문이 열리는 연출]")
	var stage := main.get_node("StageManager") as StageManager
	var player := main.get_node("Entities/Player") as Player
	var gate := main.get_node("Entities/BossGate") as BossGate
	var hud := main.get_node("HUD") as HUD
	var progress_label := hud.get_node("%ProgressLabel") as Label
	stage.instant_travel = true
	var T := StageManager.GateTrial
	_check(StageManager.gate_trial_for(1) == T.KILL and StageManager.gate_trial_for(2) == T.KILL and StageManager.gate_trial_for(3) == T.SEAL_CORES
		and StageManager.gate_trial_for(4) == T.COLLECT and StageManager.gate_trial_for(5) == T.IGNITE and StageManager.gate_trial_for(6) == T.ELITE
		and StageManager.gate_trial_for(9) == T.ALTAR and StageManager.gate_trial_for(14) == T.SURVIVE,
		"해방 시련이 스테이지 컨셉에 맞게: 3 원소 결정 파괴 · 4 생명의 씨앗 · 5 성의 횃불 · 6 오크 족장 · 9 마계의 문 봉인 · 14 시간의 틈")
	var kinds := {}
	var titles := {}
	var elites_ok := true
	for st in range(3, 101):
		var info := GateTrials.get_info(st)
		kinds[info["type"]] = int(kinds.get(info["type"], 0)) + 1
		titles[info["title"]] = true
		if info["type"] == T.ELITE:
			var data: StageData = load("res://data/stages/stage_%d.tres" % st)
			elites_ok = elites_ok and data.enemy_scenes.any(func(sc: PackedScene) -> bool: return sc.resource_path.get_file().get_basename() == info["elite"])
	_check(kinds.size() == 7 and titles.size() >= 95 and kinds.values().all(func(n: int) -> bool: return n >= 2), "3~100스테이지: 7가지 시련, 이름은 스테이지마다 다름 (%d가지 · %s)" % [titles.size(), str(kinds)])
	_check(elites_ok, "정예 시련의 몬스터는 모두 그 스테이지 몬스터")
	# 파괴 (3 원소의 유적: 원소 결정 4개)
	stage.go_to_stage(3)
	await _frames(3)
	stage._do_enter_field()
	await _frames(4)
	var cores: Array = get_tree().get_nodes_in_group(&"enemies").filter(func(e: Node) -> bool: return e.has_meta(&"gate_core"))
	_check(stage.gate_trial == T.SEAL_CORES and cores.size() == 4 and (cores[0] as Enemy).display_name == "원소 결정" and not gate.is_open()
		and progress_label.text.contains("원소 결정 파괴 0 / 4"), "3스테이지: 원소 결정 4개 · HUD 「%s」" % progress_label.text)
	Sfx.history.clear()
	(cores[0] as Enemy).take_damage(999999999, Vector2.ZERO, false, 99999)
	await _frames(3)
	_check(stage._trial_count == 1 and not gate.is_open() and Sfx.history.has(&"core_break"), "결정 하나 파괴 → 1 / 4")
	stage._do_return_to_camp()
	await _frames(3)
	stage._do_enter_field()
	await _frames(4)
	cores = get_tree().get_nodes_in_group(&"enemies").filter(func(e: Node) -> bool: return e.has_meta(&"gate_core"))
	_check(cores.size() == 3, "야영지에 다녀와도 부순 결정은 그대로 — 남은 결정 3개")
	for c in cores:
		(c as Enemy).take_damage(999999999, Vector2.ZERO, false, 99999)
	await _frames(3)
	_check(gate.is_open() and gate.enabled and stage.is_trial_complete(), "결정 4개 모두 파괴 → 보스방 해방")
	await _frames(20)
	_check(player.is_camera_focused(), "문이 열리면 카메라가 잠깐 북쪽 보스문을 비춤")
	await _frames(80)
	_check((gate.get_node("Sprite2D") as Sprite2D).texture == gate.open_texture, "땅이 울리고(굉음) → 사슬이 끊기고 → 빛기둥 속에 문이 열림")
	await _frames(60)
	_check(not player.is_camera_focused(), "연출이 끝나면 카메라가 용사에게 돌아옴")
	# 수집 (4 드라이어드의 숲: 생명의 씨앗 5개)
	stage.go_to_stage(4)
	await _frames(3)
	stage._do_enter_field()
	await _frames(4)
	var seeds := stage.get_trial_markers()
	_check(stage.gate_trial == T.COLLECT and seeds.size() == 5 and seeds.all(func(m: TrialMarker) -> bool: return m.kind == TrialMarker.Kind.COLLECT and stage.field_room.get_arena_rect().grow(4).has_point(m.global_position))
		and progress_label.text.contains("생명의 씨앗 0 / 5"), "4스테이지: 사냥터 안에 생명의 씨앗 5개 · 「%s」" % progress_label.text)
	player.global_position = seeds[0].global_position
	await _frames(3)
	_check(stage._trial_count == 1 and stage.get_trial_markers().size() == 4, "씨앗에 닿으면 주워짐 → 1 / 5")
	stage._do_return_to_camp()
	await _frames(3)
	stage._do_enter_field()
	await _frames(4)
	seeds = stage.get_trial_markers()
	_check(seeds.size() == 4 and stage._trial_count == 1, "야영지에 다녀와도 주운 씨앗은 그대로 — 남은 씨앗 4개")
	for m in seeds:
		player.global_position = m.global_position
		await _frames(2)
	_check(gate.is_open(), "씨앗 5개를 모두 모으면 보스방 해방")
	await _frames(150)
	# 점화 (5 어둠의 성: 횃불 4개)
	stage.go_to_stage(5)
	await _frames(3)
	stage._do_enter_field()
	await _frames(4)
	var torches := stage.get_trial_markers()
	_check(stage.gate_trial == T.IGNITE and torches.size() == 4 and torches.all(func(m: TrialMarker) -> bool: return m.kind == TrialMarker.Kind.IGNITE and not m.done), "5스테이지: 꺼진 횃불 4개")
	player.global_position = torches[0].global_position + Vector2(TrialMarker.IGNITE_RADIUS + 20.0, 0)
	await _survive(20)
	_check(torches[0].progress == 0.0, "원 밖에서는 불이 붙지 않음")
	await _survive(30, func() -> void: player.global_position = torches[0].global_position)
	_check(torches[0].progress > 0.1 and not torches[0].done, "원 안에 서 있으면 불씨가 차오름")
	await _survive(90, func() -> void: player.global_position = torches[0].global_position)
	_check(torches[0].done and stage._trial_count == 1 and progress_label.text.contains("횃불 1 / 4"), "%.1f초 서 있으면 횃불이 켜짐 → 1 / 4" % StageManager.IGNITE_TIME)
	for m in torches.slice(1):
		await _survive(110, func() -> void: player.global_position = m.global_position)
	_check(gate.is_open(), "횃불 4개를 모두 밝히면 보스방 해방")
	await _frames(150)
	# 정예 (6 오크 요새: 오크 족장)
	stage.go_to_stage(6)
	await _frames(3)
	stage._do_enter_field()
	await _frames(4)
	var elites: Array = get_tree().get_nodes_in_group(&"enemies").filter(func(e: Node) -> bool: return e.has_meta(&"gate_elite"))
	var elite: Enemy = elites[0] if not elites.is_empty() else null
	_check(stage.gate_trial == T.ELITE and elite != null and elite.display_name == "오크 족장" and elite.scene_file_path.ends_with("orc_warrior.tscn") and elite.scale.x > 1.4 and not gate.is_open(),
		"6스테이지: 정예 「%s」 등장 (오크 전사가 크고 금빛 · 체력 x%d)" % [elite.display_name if elite != null else "?", roundi(StageManager.ELITE_HP)])
	if elite != null:
		elite.take_damage(999999999, Vector2.ZERO, false, 99999)
	await _frames(3)
	_check(gate.is_open(), "정예를 쓰러뜨리면 보스방 해방")
	await _frames(150)
	# 수호 (9 마계의 문: 봉인진 20초)
	stage.go_to_stage(9)
	await _frames(3)
	stage._do_enter_field()
	await _frames(4)
	var altar := stage.get_altar()
	_check(stage.gate_trial == T.ALTAR and altar != null and not gate.is_open() and is_equal_approx(stage.trial_time(), 20.0), "9스테이지: 마계의 문 봉인진 (20초)")
	if altar != null:
		player.global_position = altar.global_position + Vector2(GateAltar.RADIUS + 30.0, 0)
		await _survive(30)
		_check(stage._altar_progress == 0.0, "원 밖에서는 봉인이 차오르지 않음")
		await _survive(60, func() -> void: player.global_position = altar.global_position)
		_check(stage._altar_progress > 0.5 and altar.active and progress_label.text.contains("마계의 문 봉인"), "원 안에 서 있으면 봉인이 차오름 (%s)" % progress_label.text)
		stage._altar_progress = stage.trial_time() - 0.05
		await _survive(10, func() -> void: player.global_position = altar.global_position)
		_check(gate.is_open(), "봉인을 마치면 보스방 해방")
	await _frames(150)
	# 버티기 (14 시간의 회랑: 35초)
	stage.go_to_stage(14)
	await _frames(3)
	var normal_alive := stage.get_max_alive()
	stage._do_enter_field()
	await _frames(4)
	_check(stage.gate_trial == T.SURVIVE and stage.get_max_alive() > normal_alive and progress_label.text.contains("시간의 틈") and progress_label.text.contains("초 남음"),
		"14스테이지: 시간의 틈 버티기 — 몬스터가 더 많이 (%d → %d) · 「%s」" % [normal_alive, stage.get_max_alive(), progress_label.text])
	await _survive(60)
	_check(stage._survive_time > 0.5 and not gate.is_open(), "살아 있는 동안 시간이 흐름")
	stage._survive_time = stage.trial_time() - 0.05
	await _survive(10)
	_check(gate.is_open() and stage.get_max_alive() == normal_alive, "다 버티면 보스방 해방 · 몬스터 수는 원래대로")
	await _frames(150)
	stage.go_to_stage(1)
	await _frames(3)


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


## 11~100스테이지: 잡몹 · 보스 패턴 · 보스 기믹 (+ 30~35 고대 용의 비늘 → 35스테이지 뒤 히든 던전). 100스테이지 보스(현재 마지막 보스)를 쓰러뜨리지 않은 채 돌려줌
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
		23: ["하위 뱀파이어", "흡혈 박쥐", "구울"],
		24: ["독 도마뱀", "독두꺼비", "맹독 거미"],
		25: ["태양 사제", "월광 궁수", "별빛 정령"],
		26: ["서리 늑대", "얼음 골렘", "설인"],
		27: ["그림자 추적자", "어둠 박쥐", "심연의 눈"],
		28: ["공허 유충", "공허 사도", "균열 짐승"],
		29: ["몽마 하수인", "꿈먹는 맥", "잠의 요정"],
		30: ["불꽃 정령", "물의 정령", "바위 정령"],
		31: ["실프", "폭풍 하피", "폭풍 매"],
		32: ["바위 도마뱀", "대지 골렘", "수정 정령"],
		33: ["얼음 정령", "빙하 거북", "얼음 비룡"],
		34: ["살라만더", "용암 골렘", "불꽃 술사"],
		35: ["해골 용병", "묘지 구울", "원혼"],
		36: ["천사 병사", "오파님", "성가대 인형"],
		37: ["광신도", "타락 사제", "날개 꺾인 천사"],
		38: ["청동 병사", "바위 게", "청동 사수"],
		39: ["황소 전사", "미궁 파수꾼", "미궁 망령"],
		40: ["사티로스", "님프", "페가수스"],
		41: ["늪 뱀", "히드라 새끼", "늪지 주술사"],
		42: ["어린 키클롭스", "동굴 늑대", "키클롭스 투석병"],
		43: ["명계 개", "망령 병사", "카론의 망령"],
		44: ["해협 상어", "바다뱀 전사", "해협의 마녀"],
		45: ["리비아 투사", "사막 하이에나", "모래 정령"],
		46: ["거미 시녀", "동굴 거미", "실 뽑는 거미"],
		47: ["둥지 독사", "괴물 유모 하피", "둥지 파수꾼"],
		48: ["영웅 견습생", "켄타우로스 궁수", "네메아 새끼사자"],
		49: ["바위산 독수리", "사슬 감시자", "불씨 정령"],
		50: ["청동 자동인형", "키클롭스 대장장이", "청동 사냥개"],
		51: ["청동부리 새", "늪지 사냥꾼", "깃털 정령"],
		52: ["스파르토이 전사", "테베 창병", "밭의 뱀"],
		53: ["콜키스 청동 황소", "콜키스 전사", "숲의 독사"],
		54: ["아마존 궁수", "아마존 기마병", "아마존 방패병"],
		55: ["어린 거인", "바위 투척병", "산 늑대"],
		56: ["새끼 멧돼지", "쿠레테스 전사", "칼리돈 사냥꾼"],
		57: ["해골 순례자", "해골 기사", "백조 망령"],
		58: ["용암 거인병", "불 뱀", "기간테스 주술사"],
		59: ["전쟁 늑대", "마르스의 딱따구리", "늑대 전사"],
		60: ["로마 군단병", "투창병", "백인대장"],
		61: ["오이칼리아 궁수", "오이칼리아 창병", "오이칼리아 사냥개"],
		62: ["델포이 독사", "신탁의 연기 정령", "피톤의 새끼"],
		63: ["불꽃 말", "불타는 마부", "태양 불씨 정령"],
		64: ["트로이 파수병", "저주받은 예언자", "목마 병사"],
		65: ["검은 까마귀", "깃털 망령", "까마귀 사냥꾼"],
		66: ["미르미돈 전사", "미르미돈 방패병", "그리스 투창병"],
		67: ["황금 병사", "당나귀 귀 시종", "황금 갈대 정령"],
		68: ["트로이 근위병", "트로이 궁수", "트로이 전차병"],
		69: ["신탁 수호병", "연기 무녀", "델포이 순례자"],
		70: ["델포이 신전 수호병", "태양 사제", "빛의 정령"],
		71: ["바다뱀 새끼", "트로이 사제", "해변 게"],
		72: ["그리스 기습병", "그리스 중장보병", "횃불 병사"],
		73: ["아르고스 창병", "안개 망령", "아르고스 전차마"],
		74: ["어린 키마이라", "솔리모이 전사", "리키아 궁수"],
		75: ["살라미스 방패병", "살라미스 투석병", "트로이 돌격병"],
		76: ["구혼자", "구혼자 궁수", "키르케의 돼지"],
		77: ["테베 전사", "테베 궁수", "테베 들개"],
		78: ["밤올빼미", "그림자 정찰병", "어둠의 정령"],
		79: ["청동 호플리테스", "아크로폴리스 궁수", "청동 올빼미"],
		80: ["아테네 호플리테스", "지혜의 올빼미", "아테나의 사도"],
		81: ["탐욕의 임프", "황금 도둑", "보물 상자 미믹"],
		82: ["졸음 정령", "꾸벅이는 구울", "거대 달팽이"],
		83: ["파리 떼", "식탐 구울", "구더기"],
		84: ["서큐버스 창병", "매혹의 정령", "사슬 사냥개"],
		85: ["역병의 기병", "굶주린 망자", "전쟁의 사냥개"],
		86: ["표 받은 광신도", "예언자의 시종", "짐승의 우상"],
		87: ["사막의 진", "감시자 천사", "네피림"],
		88: ["무저갱의 기어 나오는 것", "연기 악마", "타락한 병사"],
		89: ["우박 정령", "핏빛 물결", "쓴 별의 정령"],
		90: ["타락한 천사병", "지옥의 망령", "무저갱의 메뚜기"],
		91: ["불칼의 파수꾼", "생명나무 정령", "에덴의 뱀"],
		92: ["눈의 정령", "불바퀴", "보좌의 파수병"],
		93: ["바빌론 창병", "갈대아 점성술사", "풀무불 정령"],
		94: ["블레셋 창병", "블레셋 투석병", "가드의 거인병"],
		95: ["여리고 궁수", "여리고 방패병", "성벽 경비견"],
		96: ["홍수의 거인병", "물의 정령", "바다 괴어"],
		97: ["바알의 사제", "바알의 춤꾼", "아세라 목상"],
		98: ["빛의 치유사", "천상의 수호병", "천상의 사슴"],
		99: ["천군 창병", "천군 궁수", "붉은 용의 새끼"],
		100: ["백합의 정령", "계시의 천사", "스랍"],
	}
	var stage_names := {11: "금단의 연구소", 12: "마도 공장", 13: "가라앉은 신전", 14: "시간의 회랑", 15: "거울의 미궁", 16: "바람의 봉우리", 17: "거인의 감옥", 18: "인형 극장", 19: "폭풍의 바다", 20: "대마법사의 탑", 21: "기계 신전", 22: "모래 폭풍의 사막", 23: "피의 성", 24: "맹독의 늪", 25: "해와 달의 신전", 26: "빙결의 궁전", 27: "심연", 28: "공허의 둥지", 29: "꿈의 경계", 30: "정령의 성역", 31: "폭풍의 협곡", 32: "대지의 균열", 33: "얼어붙은 호수", 34: "용암 화산", 35: "용의 묘지", 36: "천상의 법정", 37: "타락한 신전", 38: "청동의 해안", 39: "크노소스의 미궁", 40: "구름 위의 길", 41: "레르나의 늪", 42: "키클롭스의 동굴", 43: "명계의 문", 44: "메시나 해협", 45: "리비아의 투기장", 46: "거미줄 신전", 47: "괴물들의 둥지", 48: "영웅의 시련장", 49: "코카서스의 바위산", 50: "헤파이스토스의 대장간", 51: "스팀팔로스 호수", 52: "카드모스의 밭", 53: "아레스의 숲", 54: "테미스키라", 55: "거인의 들판", 56: "칼리돈의 사냥터", 57: "해골 신전", 58: "플레그라 들판", 59: "군신의 숲", 60: "군신의 전장", 61: "오이칼리아의 활터", 62: "델포이의 갈라진 땅", 63: "태양의 길", 64: "불타는 트로이", 65: "까마귀의 숲", 66: "트로이의 해변", 67: "팍톨로스 강가", 68: "트로이 성벽", 69: "델포이 신전", 70: "델포이의 태양 신전", 71: "트로이 해안", 72: "트로이 성문", 73: "안개의 전장", 74: "리키아의 하늘", 75: "그리스 진영", 76: "이타카의 궁전", 77: "테베의 일곱 성문", 78: "올빼미의 밤", 79: "아크로폴리스", 80: "파르테논", 81: "탐욕의 금고", 82: "나태의 늪", 83: "폭식의 연회장", 84: "색욕의 궁전", 85: "묵시록의 들판", 86: "거짓 신전", 87: "광야", 88: "무저갱의 문", 89: "일곱 나팔의 하늘", 90: "무저갱", 91: "에덴의 동쪽", 92: "바퀴의 하늘", 93: "두라 평지", 94: "엘라 골짜기", 95: "여리고", 96: "홍수", 97: "갈멜산", 98: "치유의 하늘", 99: "하늘의 전쟁", 100: "백합의 정원"}
	var boss_names := {11: "금단의 실험체 키메라", 12: "폭주한 마도기신 레기온", 13: "심해의 포식자 크라켄", 14: "모래시계의 파수꾼 아르케오스", 15: "거울에 갇힌 미혹의 도플갱어", 16: "천공의 수호자 그리핀", 17: "추방된 자 티탄", 18: "꼭두각시 마리오네트", 19: "폭풍의 지배자 레비아탄", 20: "대마법사 아르카나", 21: "기계의 정점 테모스", 22: "사막의 암살자 스콜피언", 23: "피의 군주 벨", 24: "맹독의 패주 바실리스크", 25: "해의 쌍둥이 솔", 26: "빙결의 여왕 글라시아", 27: "심연의 군주 녹스", 28: "공허의 포식자 보이드 웜", 29: "몽마 나이트메어", 30: "대정령 벨페르 가이아", 31: "바람의 드래곤 제피로스", 32: "대지의 드래곤 테라곤", 33: "얼음의 드래곤 코퀴로스", 34: "화염의 드래곤 베르단", 35: "언데드 드래곤 헬리시온", 36: "심판의 천사 세라핀", 37: "타락한 신 아스타로트", 38: "청동 거인 탈로스", 39: "미궁의 미노타우로스", 40: "전령의 신 헤르메스", 41: "머리 아홉의 히드라", 42: "외눈 거인 폴리페모스", 43: "명계의 문지기 케르베로스", 44: "스킬라와 카립디스", 45: "대지의 거인 안타이오스", 46: "거미 여인 아라크네", 47: "괴물의 어머니 에키드나", 48: "영웅 헤라클레스", 49: "사슬에 묶인 티탄 프로메테우스", 50: "대장장이 신 헤파이스토스", 51: "스팀팔로스의 괴조", 52: "용의 이빨 전사 스파르토이", 53: "잠들지 않는 콜키스의 용", 54: "아마존 여왕 히폴리테", 55: "거인 형제 오토스와 에피알테스", 56: "칼리돈의 영웅 멜레아그로스", 57: "해골 신전의 기사 키크노스", 58: "불의 거인 엔켈라도스", 59: "마르스의 늑대 루푸스", 60: "전쟁의 신 마르스", 61: "활의 왕 에우리토스", 62: "델포이의 거대 뱀 피톤", 63: "태양 전차를 몬 파에톤", 64: "예언자 카산드라", 65: "코로니스의 까마귀", 66: "영웅 아킬레우스", 67: "황금 손의 왕 미다스", 68: "트로이의 영웅 헥토르", 69: "델포이의 여사제 피티아", 70: "태양의 신 아폴론", 71: "라오콘의 바다뱀 포르케스와 카리보이아", 72: "트로이 목마", 73: "영웅 디오메데스", 74: "페가수스를 탄 벨레로폰", 75: "큰 아이아스", 76: "오디세우스", 77: "티데우스", 78: "아테나의 올빼미 글라우크스", 79: "아크로폴리스의 청동 수호상", 80: "지혜의 신 아테나", 81: "탐욕의 마왕 마몬", 82: "나태의 마왕 벨페고르", 83: "폭식의 마왕 바알제붑", 84: "색욕의 마왕 아스모데우스", 85: "묵시록의 네 기사", 86: "거짓 예언자", 87: "광야의 타락천사 아자젤", 88: "무저갱의 열쇠를 든 타락한 별", 89: "일곱 나팔의 천사", 90: "마왕 아바돈", 91: "에덴의 문지기 케루빔", 92: "바퀴 천사 오파님", 93: "느부갓네살의 금 신상", 94: "거인 골리앗", 95: "여리고 성의 수비대장", 96: "노아 홍수의 네피림 왕", 97: "갈멜산의 바알 대예언자", 98: "치유의 대천사 라파엘", 99: "천군의 장 대천사 미카엘", 100: "대천사 가브리엘"}
	var final_boss: Enemy = null
	for n in range(first, 101):
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
		await _survive(240, func() -> void:
			player._invincible_left = 1.0)  # 후반 잡몹 두 마리가 한 프레임에 겹쳐 때리면 장비 없는 테스트 캐릭터가 쓰러짐 — 패턴 실행만 확인
		_check(not _gm.is_player_dead, "%d스테이지 잡몹 패턴 실행" % n)
		if _gm.DRAGON_SCALE_STAGES.has(n):
			var scale_node: DragonScale = null
			for node in get_tree().get_nodes_in_group(&"dragon_scales"):
				scale_node = node as DragonScale
			var spot := stage.get_dragon_scale_spot(n)
			var placed := scale_node != null and scale_node.global_position.distance_to(spot) < 1.0 and spot.distance_to(stage.get_dragon_scale_spot(n)) < 0.01
			var before_scales: int = _gm.get_dragon_scale_count()
			player.global_position = spot
			await _frames(4)
			_check(placed and _gm.has_dragon_scale(n) and _gm.get_dragon_scale_count() == before_scales + 1 and get_tree().get_nodes_in_group(&"dragon_scales").is_empty(),
					"[히든] %d스테이지 사냥터 구석의 고대 용의 비늘 (%d/6)" % [n, _gm.get_dragon_scale_count()])
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
				chimera.tail.take_damage(999999999)
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
					t.take_damage(999999999)
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
				doppel.mirror.take_damage(999999999)
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
				_check(player.is_armor_broken() and player.get_effective_defense() == maxi(def_before - Balance.scale(griffin.roar_armor_break), 0) and _gm.player_status.contains("방어력 감소"), "[기믹] 포효: 플레이어 방어력 감소 (%d → %d · %s)" % [def_before, player.get_effective_defense(), _gm.player_status])
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
					w.take_damage(999999999)
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
					var cover_before := 0
					for r in titan.get_cover_rocks():
						cover_before += r.hits
					titan.throw_boulder()
					await _frames(150)
					var cover_after := 0
					for r in titan.get_cover_rocks():
						cover_after += r.hits
					# 던진 바위는 앞을 가로막은 바위(꼭 rock 이 아니어도)가 대신 맞음
					_check(cover_after < cover_before and _gm.hp >= hp_cover - 2, "[기믹] 박힌 바위 뒤에 숨으면 던진 바위를 막아 줌 (피해 %d)" % (hp_cover - _gm.hp))
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
				_check(player.is_puppeted() and mario.get_threads() == 4 and is_equal_approx(player.get_puppet_strength(), BossMarionette.STRENGTH_BY_THREADS[4]) and not player.can_attack() and not player.can_guard() and _gm.player_status.contains("꼭두각시"), "[기믹] 꼭두각시 조종: 실 4가닥, 공격·가드 불가 (%s)" % _gm.player_status)
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
					m.take_damage(999999999)
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
				scorp._burrow_cooldown = 999.0
			23:
				var bel := boss as BossVampire
				await _survive(5)
				_check(bel.get_node("DarkMist") != null, "피의 군주 벨: 검은 안개를 두름")
				for e in get_tree().get_nodes_in_group(&"enemies"):
					if not (e as Enemy).is_boss:
						(e as Enemy).despawn()
				bel.take_damage(6000, Vector2.ZERO, false, 9999)
				var hp_bel := bel.hp
				var near := bel.global_position + Vector2(0, 70)
				player.global_position = near
				bel.begin_drain()
				_check(bel.is_draining(), "[기믹] 흡혈: 벨과 플레이어가 핏줄기로 이어짐")
				await _survive(100, func() -> void:
					player.global_position = near)
				_check(bel.get_drained_total() > 0 and bel.get_healed_total() > 0 and bel.hp > hp_bel, "흡혈: 플레이어 체력을 빨아 벨이 회복 (-%d / +%d)" % [bel.get_drained_total(), bel.get_healed_total()])
				await _survive(120)
				var far := bel.global_position + Vector2(0, bel.drain_range + 60.0)
				var arena23 := stage.boss_room.get_arena_rect()
				if not arena23.has_point(far):
					far = bel.global_position + Vector2(bel.drain_range + 60.0 if bel.global_position.x < arena23.get_center().x else -bel.drain_range - 60.0, 0.0)
				player.global_position = bel.global_position + Vector2(0, 60)
				bel._drain_left = 0.0
				bel.begin_drain()
				var breaks0 := bel.get_break_count()
				player.global_position = far
				await _survive(5, func() -> void:
					player.global_position = far)
				_check(bel.get_break_count() == breaks0 + 1 and not bel.is_draining(), "멀리 떨어지면 핏줄기가 끊어짐 (거리 %.0f)" % bel.global_position.distance_to(player.global_position))
				bel._drain_cooldown = 3.0
				var drains0 := bel.get_drain_count()
				var seen23 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen23["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen23["shot"] = true)
				_check(seen23["aoe"] and seen23["shot"] and bel.get_drain_count() > drains0, "벨 패턴: 박쥐 떼 · 핏빛 낫 · 안개화 · 피의 비 · 흡혈 반복")
			24:
				var basil := boss as BossBasilisk
				await _survive(5)
				var fog := basil.get_fog()
				_check(basil.has_gland() and basil.gland.max_hp == roundi(basil.max_hp * basil.gland_hp_ratio) and fog != null, "[기믹] 바실리스크 머리의 독샘 (체력 따로) + 독안개 시작")
				if fog != null:
					var cov0 := fog.get_coverage()
					fog.advance(basil.fog_time * 0.6)
					await _frames(2)
					_check(fog.get_coverage() > cov0 + 0.4, "독안개가 점점 보스방을 덮어감 (%.0f%% → %.0f%%)" % [cov0 * 100.0, fog.get_coverage() * 100.0])
					var arena24 := stage.boss_room.get_arena_rect()
					var corner := arena24.position + Vector2(10, 10)
					await _survive(70, func() -> void:
						player.global_position = corner)
					_check(fog.is_in_fog(corner) and player.is_burning() and _gm.player_status.contains("독") and is_equal_approx(_gm.potion_heal_multiplier, 0.5), "독안개 속에서는 독 + 포션 회복 -50%% (%s)" % _gm.player_status)
					_gm.potions[&"small_potion"] = 3
					_gm.hp = roundi(_gm.max_hp * 0.3)
					var hp_p: int = _gm.hp
					_gm.use_potion(ItemDB.get_potion(&"small_potion"))
					_check(_gm.hp - hp_p == roundi(ItemDB.get_potion(&"small_potion").get_heal(_gm.max_hp) * 0.5), "독에 걸리면 포션 회복량 절반 (+%d)" % (_gm.hp - hp_p))
					fog.advance(basil.fog_time)
					await _frames(2)
					_check(fog.get_coverage() >= 0.99, "끝내 보스방 전체가 독안개로 덮임")
				var b0 := basil.get_breath_count()
				basil.breath()
				var poison_shot := {"shot": false}
				await _survive(30, func() -> void:
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							poison_shot["shot"] = true)
				_check(basil.get_breath_count() == b0 + 1 and poison_shot["shot"], "[기믹] 독샘이 있으면 독 브레스")
				basil.set_physics_process(false)
				var spot24 := boss_center + Vector2(0, 90)
				player.global_position = spot24
				await _frames(2)
				basil.gaze()
				await _survive(60, func() -> void:
					player.global_position = spot24)
				_check(basil.get_petrify_count() == 1 and player.is_charmed() and _gm.player_status.contains("석화"), "석화의 눈에 맞으면 석화 (조작 불가)")
				basil.set_physics_process(true)
				basil.gland.take_damage(999999999)
				await _frames(3)
				_check(basil.is_gland_broken() and fog != null and is_instance_valid(fog) and fog.is_receding(), "[기믹] 독샘을 부수면 독안개가 걷힘")
				var b1 := basil.get_breath_count()
				basil.breath()
				await _survive(100)
				_check(basil.get_breath_count() == b1 and basil.get_fog() == null, "독샘이 없으면 독 브레스도 못 씀, 안개는 사라짐")
				var seen24 := {"aoe": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen24["aoe"] = true)
				_check(seen24["aoe"], "바실리스크 패턴: 석화의 눈 · 꼬리 휩쓸기 · 독니 돌진 · 소환")
			25:
				var sol := boss as BossTwin
				await _survive(10)
				var luna := sol.partner
				_check(luna != null and is_instance_valid(luna) and luna.display_name == "달의 쌍둥이 루나" and luna.max_hp == sol.max_hp, "[기믹] 해의 쌍둥이 솔이 달의 쌍둥이 루나를 불러냄 (체력 따로)")
				if luna != null:
					sol.set_physics_process(false)
					luna.set_physics_process(false)
					luna.global_position = sol.global_position + Vector2(40, 0)
					sol._update_resonance()
					luna._update_resonance()
					_check(sol.is_resonating() and sol.defense == sol._base_defense + sol.resonance_defense and luna.defense == luna._base_defense + luna.resonance_defense, "[기믹] 공명: 둘이 붙어 있으면 둘 다 방어력 +%d" % sol.resonance_defense)
					luna.global_position = sol.global_position + Vector2(200, 60)
					sol._update_resonance()
					luna._update_resonance()
					_check(not sol.is_resonating() and sol.defense == sol._base_defense, "떨어뜨리면 공명이 풀림")
					luna.take_damage(999999, Vector2.ZERO, false, 9999)
					var hp_fallen := luna.hp
					luna.take_damage(500, Vector2.ZERO, false, 9999)
					_check(luna.is_fallen() and not luna.is_dead() and luna.hp == hp_fallen and sol.is_reviving_partner(), "[기믹] 한쪽 체력이 다 닳으면 「쓰러짐」 (공격이 닿지 않음), 다른 쪽이 되살릴 준비")
					sol.set_physics_process(true)
					sol._revive_left = 0.05
					await _survive(10)
					_check(not luna.is_fallen() and luna.hp == roundi(luna.max_hp * luna.revive_ratio) and luna.get_revive_count() == 1, "제때 쓰러뜨리지 못하면 쓰러진 쪽이 되살아남 (체력 50%%)")
					sol.take_damage(999999, Vector2.ZERO, false, 9999)
					await _frames(2)
					_check(sol.is_fallen() and not sol.is_dead() and not next_portal.enabled and luna.is_reviving_partner(), "솔이 먼저 쓰러져도 루나가 살아 있으면 끝나지 않음")
					luna.set_physics_process(true)
					luna._revive_left = 0.05
					await _survive(10)
					_check(not sol.is_fallen() and sol.hp > 0, "루나도 솔을 되살림")
					var seen25 := {"aoe": false, "shot": false}
					await _survive(600, func() -> void:
						if _count_nodes_of("AoeStrike") > 0:
							seen25["aoe"] = true
						for c in pool.get_children():
							if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
								seen25["shot"] = true)
					_check(seen25["aoe"] and seen25["shot"], "쌍둥이 패턴: 솔(돌진·플레어·햇살) · 루나(달빛 탄막·초승달 화살·서리)")
					luna.take_damage(999999, Vector2.ZERO, false, 9999)
					await _frames(2)
					sol.take_damage(999999, Vector2.ZERO, false, 9999)
					await _frames(4)
					_check(sol.is_dead() and (not is_instance_valid(luna) or luna.is_dead()) and next_portal.enabled, "[기믹] 한쪽이 쓰러진 동안 다른 쪽도 쓰러뜨리면 함께 소멸 → 토벌")
			26:
				var gla := boss as BossGlacia
				await _survive(5)
				_check(gla.get_pillars().size() == 4, "[기믹] 빙결의 궁전에 얼음 기둥 4개 (엄폐물)")
				gla._blizzard_cooldown = 999.0
				gla.set_physics_process(false)
				gla.set_physics_process(true)
				var hold26 := boss_center + Vector2(0, 100)
				gla.chill = 0.0
				await _survive(120, func() -> void:
					player.global_position = hold26
					player.velocity = Vector2.ZERO)
				_check(gla.chill > 35.0 and _gm.player_status.contains("냉기"), "[기믹] 가만히 있으면 냉기가 쌓임 (%.0f%% · %s)" % [gla.chill, _gm.player_status])
				gla.add_chill(100.0)
				_check(player.is_charmed() and _gm.player_status.contains("빙결") and gla.get_freeze_count() == 1, "냉기가 가득 차면 빙결 (조작 불가)")
				await _survive(int(gla.freeze_time * 60) + 10)
				player.global_position = boss_center + Vector2(-80, 100)
				gla.chill = 60.0
				Input.action_press(&"move_right")
				await _survive(40)
				Input.action_release(&"move_right")
				_check(gla.chill < 50.0, "움직이면 냉기가 빠짐 (%.0f%%)" % gla.chill)
				gla.chill = 0.0
				var open_spot := boss_center + Vector2(-40, 100)
				for cand in [Vector2(-40, 100), Vector2(0, 40), Vector2(-100, 0), Vector2(0, 200), Vector2(-140, 120)]:
					var sheltered := false
					for pp in gla.get_pillars():
						if pp.shelters(boss_center + cand, Vector2.RIGHT):
							sheltered = true
					if not sheltered:
						open_spot = boss_center + cand
						break
				player.global_position = open_spot
				gla.begin_blizzard()
				gla._wind = Vector2.RIGHT
				await _survive(62, func() -> void:
					player.global_position = open_spot)
				var x0 := player.global_position.x
				await _survive(45, func() -> void:
					player.global_position.y = open_spot.y
					gla.chill = 0.0)
				_check(gla.is_blizzard() and player.global_position.x > x0 + 15.0 and gla.get_pushed_frames() > 0, "[기믹] 눈보라: 바람에 밀려남 (+%.0f, %d프레임)" % [player.global_position.x - x0, gla.get_pushed_frames()])
				var pil := gla.get_pillars()[0]
				var behind := pil.global_position + Vector2(30, 0)
				var sheltered0 := gla.get_sheltered_frames()
				await _survive(30, func() -> void:
					player.global_position = behind
					gla.chill = 0.0)
				_check(gla.get_sheltered_frames() > sheltered0 + 20, "바람이 오는 쪽에 기둥을 두고 뒤에 서면 바람을 피함")
				gla._blizzard_left = 0.01
				gla._blizzard_cooldown = 999.0
				await _survive(5)
				gla.mirror()
				var reflected := {"shot": false}
				await _survive(50, func() -> void:
					for c in pool.get_children():
						var pr := c as Projectile
						if pr.is_active and pr.get_team() == ProjectileSpec.Team.ENEMY:
							for pp in gla.get_pillars():
								if pr.global_position.distance_to(pp.global_position) < 60.0:
									reflected["shot"] = true)
				_check(reflected["shot"], "[기믹] 얼음 거울: 기둥이 냉기를 사방으로 반사")
				var seen26 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					gla.chill = 0.0
					if _count_nodes_of("AoeStrike") > 0:
						seen26["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen26["shot"] = true)
				_check(seen26["aoe"] and seen26["shot"], "글라시아 패턴: 고드름 · 서리 폭발 · 얼음 파편 · 얼음 거울")
			27:
				var nox := boss as BossNox
				await _survive(5)
				var torches := nox.get_torches()
				var all_off := torches.size() == 4
				for t in torches:
					if t.lit:
						all_off = false
				_check(nox.get_veil() != null and all_off, "[기믹] 보스방이 어둠에 잠김 + 꺼진 횃불 4개")
				nox.set_physics_process(false)
				var torch0 := torches[0]
				player.global_position = torch0.global_position
				await _frames(3)
				_check(torch0.lit, "[기믹] 횃불을 밟으면 불이 붙음")
				player.global_position = boss_center + Vector2(0, 100)
				nox.global_position = torch0.global_position + Vector2(30, 20)
				nox._update_exposed()
				_check(nox.is_exposed() and nox.defense == roundi(nox._base_defense * (1.0 - nox.exposed_reduction)), "[기믹] 녹스가 횃불 빛 안에 들어오면 빛에 드러나 방어력 -%d%% (%d)" % [roundi(nox.exposed_reduction * 100.0), nox.defense])
				nox.global_position = torches[3].global_position + Vector2(0, -60)
				if torches[3].global_position.distance_to(torch0.global_position) < 200.0:
					nox.global_position = boss_center + Vector2(0, 260)
				nox._update_exposed()
				_check(not nox.is_exposed() and nox.defense == nox._base_defense, "어둠 속에서는 방어력 그대로")
				nox.set_physics_process(true)
				nox.extinguish()
				await _survive(90)
				_check(not torch0.lit and nox.get_extinguish_count() == 1, "[기믹] 녹스가 그림자 손으로 횃불을 끔")
				var glow := {"seen": false}
				await _survive(600, func() -> void:
					for node in get_tree().current_scene.get_children():
						if node is AoeStrike and (node as Node2D).z_index > 90:
							glow["seen"] = true)
				_check(glow["seen"], "녹스 패턴: 그림자 발톱 · 공허의 고리 · 그림자 습격 (어둠 위로 빛나는 예고)")
			28:
				var worm := boss as BossVoidWorm
				await _survive(5)
				var spot28 := boss_center + Vector2(0, 90)
				player.global_position = spot28
				worm.begin_swallow()
				var hp_w0 := worm.hp
				worm.take_damage(5000, Vector2.ZERO, false, 9999)
				_check(worm.get_swallow_state() == BossVoidWorm.Swallow.BURROW and not worm.sprite.visible and worm.hp == hp_w0 and not worm.can_be_hit_by(Enemy.HitKind.BOW), "[기믹] 보이드 웜이 땅속으로 파고듦 (공격이 닿지 않음)")
				await _survive(int((worm.burrow_time + worm.mouth_warn) * 60) + 10, func() -> void:
					player.global_position = spot28)
				_check(worm.is_player_inside() and player.is_rooted() and not player.can_attack() == false and _gm.player_status.contains("삼켜짐") and worm.get_wall() != null, "[기믹] 발밑의 입을 못 피하면 삼켜짐 (이동 불가 · 공격 가능 · 위벽 등장)")
				_gm.hp = _gm.max_hp
				var hp_in: int = _gm.hp
				await _frames(40)
				_check(_gm.hp < hp_in, "삼켜진 동안 소화되며 체력이 깎임 (-%d)" % (hp_in - _gm.hp))
				_gm.hp = _gm.max_hp
				var hp_burst := worm.hp
				if worm.get_wall() != null:
					worm.get_wall().take_damage(999999999)
				await _frames(3)
				_check(not worm.is_player_inside() and worm.get_escape_count() == 1 and not player.is_rooted() and worm.hp < hp_burst and worm.is_stunned(), "위벽을 부수면 탈출 + 웜이 속이 터져 큰 피해·기절")
				worm._stun_left = 0.0
				worm.begin_swallow()
				worm._swallow_left = 0.01
				var spot28b := player.global_position
				await _survive(int(worm.mouth_warn * 60) + 10, func() -> void:
					player.global_position = spot28b)
				var inside_again := worm.is_player_inside()
				worm._swallow_left = 0.01
				await _survive(5)
				_check(inside_again and not worm.is_player_inside() and not player.is_rooted() and worm.get_escape_count() == 1, "위벽을 못 부수면 시간이 지나 뱉어냄")
				for i in 3:
					stage._add_enemy((load("res://scenes/enemies/void_larva.tscn") as PackedScene).instantiate() as Enemy, worm.global_position + Vector2.from_angle(TAU * i / 3.0) * 50.0, stage.boss_room.get_arena_rect())
				await _frames(3)
				var power0 := worm.power
				var eaten := worm.devour()
				_check(eaten >= 3 and worm.growth == mini(eaten, BossVoidWorm.MAX_GROWTH) and worm.power > power0 * 1.25, "[기믹] 포식: 잡몹을 삼킬수록 성장 (%d마리 · 공격력 x%.2f)" % [eaten, worm.power / power0])
				worm._swallow_cooldown = 999.0
				var seen28 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen28["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen28["shot"] = true)
				_check(seen28["aoe"] and seen28["shot"], "보이드 웜 패턴: 공허 토사물 · 몸통 내려치기 · 소환 · 포식")
			29:
				var mare := boss as BossNightmare
				await _survive(5)
				mare.begin_illusion()
				await _frames(3)
				var ills := mare.get_illusions()
				var no_shadow := not ills.is_empty()
				for ill in ills:
					if (ill.get_node("Shadow") as CanvasItem).visible:
						no_shadow = false
				_check(ills.size() == mare.illusion_count and no_shadow and (mare.get_node("Shadow") as CanvasItem).visible, "[기믹] 환각: 똑같은 환영 %d개 — 진짜만 그림자가 있음" % ills.size())
				ills[0].take_damage(100)
				await _frames(2)
				_check(mare.get_illusions().size() == mare.illusion_count - 1 and mare.is_illusion_active() and mare.get_caught_count() == 0, "환영을 때리면 흩어질 뿐")
				mare.take_damage(500, Vector2.ZERO, false, 9999)
				await _frames(2)
				_check(not mare.is_illusion_active() and mare.get_illusions().is_empty() and mare.get_caught_count() == 1 and mare.is_stunned(), "진짜를 때리면 「들켰다!」 → 환영이 모두 사라지고 휘청임")
				mare._stun_left = 0.0
				mare.set_physics_process(false)
				var spot29 := mare.get_hit_center() + Vector2(0, 80)
				player.global_position = spot29
				await _frames(1)
				mare.sleep_orbs()
				var slept := {"sleep": false}
				await _survive(120, func() -> void:
					player.global_position = spot29
					if player.is_charmed() and _gm.player_status.contains("수면"):
						slept["sleep"] = true)
				_check(slept["sleep"], "[기믹] 수면 구체에 맞으면 잠듦 (조작 불가)")
				mare.set_physics_process(true)
				var seen29 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen29["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen29["shot"] = true)
				_check(seen29["aoe"] and seen29["shot"], "나이트메어 패턴: 꿈의 고리 · 악몽의 손 · 수면 구체 · 환각")
				if mare.is_illusion_active():
					mare.end_illusion(false)
			30:
				var gaia := boss as BossGaia
				await _survive(5)
				_check(gaia.get_cores().size() == 4 and gaia.get_blessing_names().size() == 4 and gaia.defense == gaia._base_defense + 20 and is_equal_approx(gaia.move_speed, gaia._base_speed * 1.5) and gaia.burn_damage > 0, "[기믹] 네 원소의 정령핵 → 가호 4개 (방어력 +20 · 이속 1.5배 · 화상 · 재생)")
				gaia.take_damage(6000, Vector2.ZERO, false, 9999)
				var hp_r := gaia.hp
				await _survive(90)
				_check(gaia.hp > hp_r, "물의 가호: 체력 재생 (+%d)" % (gaia.hp - hp_r))
				gaia.get_core(BossGaia.Element.EARTH).take_damage(999999999)
				await _frames(3)
				_check(not gaia.has_blessing(BossGaia.Element.EARTH) and gaia.defense == gaia._base_defense, "대지의 핵을 부수면 방어력 가호가 사라짐")
				gaia.get_core(BossGaia.Element.FIRE).take_damage(999999999)
				gaia.get_core(BossGaia.Element.WIND).take_damage(999999999)
				await _frames(3)
				_check(gaia.burn_damage == 0 and is_equal_approx(gaia.move_speed, gaia._base_speed) and not gaia.is_earth_breath(), "불·바람의 핵을 부수면 화상·이속 가호도 사라짐")
				gaia.get_core(BossGaia.Element.WATER).take_damage(999999999)
				await _frames(3)
				_check(gaia.get_cores().is_empty() and gaia.is_earth_breath(), "[기믹] 핵이 모두 부서지면 「대지의 숨결」 시작")
				gaia.set_physics_process(false)
				var spot30 := boss_center + Vector2(-60, 90)
				player.global_position = spot30
				gaia.begin_collapse()
				var warned := gaia.field.get_warned().has(gaia.field.tile_of(spot30))
				gaia.set_physics_process(true)
				gaia._collapse_timer = 999.0
				var hits0 := gaia.get_collapse_hits()
				await _survive(int(gaia.collapse_warn * 60) + 6, func() -> void:
					player.global_position = spot30)
				_check(warned and gaia.get_collapse_hits() == hits0 + 1, "금 간 구역이 무너질 때 그 위에 있으면 큰 피해")
				gaia.take_damage(gaia.hp - roundi(gaia.max_hp * 0.08), Vector2.ZERO, false, 999999)
				await _frames(3)
				_check(gaia.is_seed_planted() and gaia.get_seed() != null, "[기믹] 체력 10%% 이하 → 세계수의 씨앗을 심음")
				var hp_s := gaia.hp
				gaia._seed_left = 0.01
				await _survive(3)
				_check(gaia.did_seed_heal() and gaia.hp >= hp_s + roundi(gaia.max_hp * gaia.seed_heal) - 5, "씨앗을 못 부수면 크게 회복 (+%d)" % (gaia.hp - hp_s))
				gaia._seed_planted = false
				gaia._seed_healed = false
				gaia.plant_seed()
				await _frames(3)
				var hp_s2 := gaia.hp
				if gaia.get_seed() != null:
					gaia.get_seed().take_damage(999999999)
				gaia._seed_left = 0.01
				await _survive(3)
				_check(not gaia.did_seed_heal() and gaia.hp <= hp_s2 + 50, "씨앗을 부수면 회복하지 못함")
				gaia._collapse_timer = 0.5
				var seen30 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen30["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen30["shot"] = true)
				_check(seen30["aoe"] and seen30["shot"] and gaia.get_collapse_count() >= 2, "가이아 패턴: 불꽃 · 물결 · 돌풍 · 지진 · 대지의 숨결 반복")
			31:
				var zeph := boss as BossZephyros
				await _survive(5)
				var wf := zeph.get_wind()
				_check(wf != null and WindField.active == wf and wf.area.has_point(boss_center), "[기믹] 돌풍: 보스방 전체에 바람 (%s)" % (wf.get_arrow() if wf != null else "-"))
				var spec31 := ProjectileSpec.new()
				spec31.team = ProjectileSpec.Team.PLAYER
				spec31.origin = boss_center + Vector2(0, 100)
				spec31.direction = wf.direction.orthogonal() if wf != null else Vector2.UP
				spec31.speed = 200.0
				spec31.max_distance = 600.0
				spec31.damage = 1
				spec31.hit_kind = Enemy.HitKind.BOW
				var arrow31 := pool.spawn(spec31)
				await _frames(20)
				var bend := arrow31._velocity.normalized().dot(wf.direction) if wf != null and arrow31 != null else 0.0
				_check(bend > 0.2 and is_equal_approx(arrow31._velocity.length(), 200.0), "바람에 화살이 휨 (바람 쪽 성분 %.2f, 속력 그대로)" % bend)
				if arrow31 != null:
					arrow31.release()
				var dir31 := wf.direction if wf != null else Vector2.ZERO
				zeph.change_wind()
				_check(zeph.get_wind() != null and zeph.get_wind().direction.dot(dir31) < 0.99 and zeph.get_wind_change_count() >= 2, "바람의 방향이 무작위로 바뀜")
				var push_from := player.global_position
				await _survive(30)
				_check(player.global_position.distance_to(push_from) > 3.0, "플레이어도 바람에 밀림")
				zeph.soar()
				await _frames(2)
				_check(zeph.is_soaring() and not zeph.can_be_hit_by(Enemy.HitKind.MELEE) and zeph.can_be_hit_by(Enemy.HitKind.BOW), "[기믹] 비상: 하늘로 날아오름 → 활로만 맞음")
				zeph._soar_left = 0.01
				await _survive(70)
				_check(not zeph.is_soaring() and zeph.can_be_hit_by(Enemy.HitKind.MELEE), "비상이 끝나면 급강하 후 착지")
				zeph._soar_cooldown = 999.0
				zeph.set_physics_process(false)  # 회오리만 검사 (보스 공격과 겹쳐 한 프레임에 쓰러지지 않게)
				pool.release_all()
				zeph.summon_tornadoes()
				await _frames(2)
				var tornadoes := get_tree().get_nodes_in_group(&"tornadoes")
				_check(tornadoes.size() == 2, "[기믹] 회오리 2개")
				var caught31 := {"hit": false}
				if not tornadoes.is_empty():
					var tor := tornadoes[0] as Tornado
					await _survive(60, func() -> void:
						if is_instance_valid(tor):
							player.global_position = tor.global_position
						if _gm.player_status.contains("휘말림"):
							caught31["hit"] = true)
				_check(caught31["hit"], "회오리에 닿으면 휘말림 (조작 불가 · 피해)")
				zeph.set_physics_process(true)
				var seen31 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen31["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen31["shot"] = true)
				_check(seen31["aoe"] and seen31["shot"], "제피로스 패턴: 바람 칼날 · 돌풍 · 할퀴기 · 비상")
			32:
				var terra := boss as BossTerragon
				await _survive(5)
				_check(terra.get_pillars().size() == 3 and terra.defense == terra._base_defense + terra.scale_armor and not terra.is_armor_broken(), "[기믹] 암석 비늘 (방어력 +%d) · 돌기둥 3개" % terra.scale_armor)
				terra.set_physics_process(false)
				for p in terra.get_pillars():
					p.queue_free()
				await _frames(2)
				terra.raise_pillar(boss_center + Vector2(70, 0))
				terra.global_position = boss_center + Vector2(-70, 0)
				player.global_position = boss_center + Vector2(0, 110)
				terra._bstate = PatternBoss.BossState.CASTING
				terra._btimer = 5.0
				terra.begin_charge(Vector2.RIGHT)
				terra.set_physics_process(true)
				await _survive(int(terra.charge_windup * 60) + 40, func() -> void:
					player.global_position = boss_center + Vector2(0, 110))
				_check(terra.get_crash_count() == 1 and terra.is_stunned() and terra.is_armor_broken() and terra.defense == terra._base_defense, "[기믹] 돌진하다 돌기둥에 처박힘 → 기절 + 비늘이 깨져 방어력 -%d" % terra.scale_armor)
				_check(terra.get_pillars().is_empty(), "부딪힌 돌기둥은 부서짐")
				terra._break_left = 0.01
				await _frames(3)
				_check(not terra.is_armor_broken() and terra.defense == terra._base_defense + terra.scale_armor, "시간이 지나면 비늘이 다시 굳음")
				terra._stun_left = 0.0
				var seen32 := {"aoe": false, "shot": false, "charge": false}
				await _survive(700, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen32["aoe"] = true
					if terra.is_charging():
						seen32["charge"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen32["shot"] = true)
				_check(seen32["aoe"] and seen32["shot"] and seen32["charge"], "테라곤 패턴: 돌진 · 낙석 · 돌기둥 · 대지의 가시")
			33:
				var coq := boss as BossCoquiros
				await _survive(5)
				coq._zero_cooldown = 999.0
				coq.cast(BossCoquiros.Pattern.BREATH)
				await _frames(3)
				var ices := coq.get_ice_floors()
				_check(ices.size() >= 3, "[기믹] 서리 숨결이 닿은 바닥이 빙판이 됨 (%d곳)" % ices.size())
				var slipped := {"slip": false}
				if not ices.is_empty():
					var ice := ices[0]
					await _survive(10, func() -> void:
						if is_instance_valid(ice):
							player.global_position = ice.global_position
						if player.is_slippery() and _gm.player_status.contains("빙판"):
							slipped["slip"] = true)
				_check(slipped["slip"], "빙판을 밟으면 미끄러짐")
				coq.begin_absolute_zero()
				await _frames(3)
				var crystals := coq.get_crystals()
				_check(coq.is_charging_zero() and crystals.size() == 3, "[기믹] 절대영도 충전 + 서리 결정 3개")
				for c in crystals:
					c.take_damage(999999999)
				await _frames(3)
				_check(not coq.is_charging_zero() and coq.get_zero_cancels() == 1 and coq.is_stunned() and coq.get_zero_hits() == 0, "결정을 모두 부수면 절대영도 취소 + 코퀴로스가 휘청임")
				coq._stun_left = 0.0
				coq.begin_absolute_zero()
				await _frames(3)
				_gm.hp = _gm.max_hp
				var hp33: int = _gm.hp
				coq._zero_left = 0.01
				await _frames(3)
				_check(coq.get_zero_hits() == 1 and _gm.hp <= hp33 - roundi(_gm.max_hp * coq.zero_ratio) + 5 and player.is_charmed() and _gm.player_status.contains("빙결"), "결정을 못 부수면 절대영도: 큰 피해 + 빙결")
				_gm.hp = _gm.max_hp
				var seen33 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen33["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen33["shot"] = true)
				_check(seen33["aoe"] and seen33["shot"], "코퀴로스 패턴: 서리 숨결 · 고드름 · 꼬리 · 소환")
			34:
				var verd := boss as BossVerdan
				await _survive(5)
				verd.cast(BossVerdan.Pattern.BREATH)
				await _frames(3)
				_check(verd.get_pools().size() >= 3, "[기믹] 화염 숨결이 지나간 자리에 용암 웅덩이 (%d곳)" % verd.get_pools().size())
				await _survive(45)
				var puffs := pool.get_children().filter(func(c: Node) -> bool: return (c as Projectile).is_active and (c as Projectile)._spec.texture == BossVerdan.BREATH_TEXTURE)
				var grown := puffs.filter(func(c: Node) -> bool: return (c as Projectile).scale.x > (c as Projectile)._spec.scale * 1.3)
				_check(puffs.size() >= 8 and not grown.is_empty() and puffs.all(func(c: Node) -> bool: return (c as Projectile)._spec.grow > 2.0),
					"[브레스] 베르단: 둥근 탄 대신 업화 숨결 덩어리 %d개가 원뿔로 — 날아가며 커짐 (%d개가 1.3배 넘게)" % [puffs.size(), grown.size()])
				var dragons_ok := true
				for dragon in ["wyvern", "zephyros", "terragon", "coquiros", "verdan", "helicion", "colchian", "arche"]:
					var src := FileAccess.get_file_as_string("res://scripts/enemies/boss_%s.gd" % dragon)
					if not src.contains("breathe(") or not src.contains("res://assets/sprites/projectiles/breath_"):
						dragons_ok = false
						print("    브레스 없음: %s" % dragon)
				_check(dragons_ok, "용 8마리 모두 고유 브레스 (와이번 불길 · 제피로스 돌풍 · 테라곤 모래 · 코퀴로스 서리 · 베르단 업화 · 헬리시온 망령 · 콜키스 독가스 · 아르케 원소+금빛)")
				verd.set_physics_process(false)
				verd._facing_right = true
				player.global_position = verd.global_position + Vector2(50, 10)
				var hp34 := verd.hp
				verd.take_damage(1000, Vector2.ZERO, false, 9999)
				var front := hp34 - verd.hp
				player.global_position = verd.global_position + Vector2(-50, 10)
				hp34 = verd.hp
				verd.take_damage(1000, Vector2.ZERO, false, 9999)
				var back := hp34 - verd.hp
				_check(front == 1000 and back == roundi(1000 * verd.back_multiplier) and verd.get_back_hits() == 1, "[기믹] 역린: 등 뒤에서 때리면 %.1f배 (%d → %d)" % [verd.back_multiplier, front, back])
				for i in verd.rage_hits:
					verd.take_damage(100, Vector2.ZERO, false, 9999)
				_check(verd.get_rage_bursts() == 1 and verd.is_enraged(), "역린을 %d번 맞으면 분노 폭발 + 빨라짐" % verd.rage_hits)
				verd.set_physics_process(true)
				player.global_position = boss_center + Vector2(0, 90)
				var seen34 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen34["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen34["shot"] = true)
				_check(seen34["aoe"] and seen34["shot"], "베르단 패턴: 화염 숨결 · 분화 · 꼬리 · 소환")
			35:
				var heli := boss as BossHelicion
				await _survive(5)
				heli.take_damage(999999999, Vector2.ZERO, false, 999999)
				await _frames(3)
				_check(heli.is_fallen() and not heli.is_dead() and heli.hp == 0 and heli.get_soul() != null, "[기믹] 불사: 체력이 0 이 되어도 뼈더미로 무너지고 영혼이 빠져나옴")
				heli.take_damage(5000, Vector2.ZERO, false, 999999)
				_check(heli.hp == 0 and not heli.can_be_hit_by(Enemy.HitKind.MELEE), "뼈더미에는 공격이 닿지 않음")
				var soul_from := heli.get_soul().global_position if heli.get_soul() != null else Vector2.ZERO
				await _frames(60)
				_check(heli.get_soul() != null and heli.get_soul().global_position.distance_to(heli.get_hit_center()) < soul_from.distance_to(heli.get_hit_center()), "영혼이 뼈더미로 돌아감")
				heli._soul_left = 0.01
				await _frames(3)
				_check(not heli.is_fallen() and heli.get_revive_count() == 1 and heli.hp == roundi(heli.max_hp * heli.revive_ratio), "영혼을 못 부수면 되살아남 (체력 %d%%)" % roundi(heli.revive_ratio * 100.0))
				player.apply_decay(3.0)
				await _frames(2)
				_gm.hp = _gm.max_hp - 100
				var potions35: int = _gm.get_total_potions()
				_check(not _gm.use_potion() and _gm.get_total_potions() == potions35 and _gm.player_status.contains("부패"), "[기믹] 부패: 포션으로 회복할 수 없음 (포션도 소모되지 않음)")
				player._decay_left = 0.0
				heli.set_physics_process(false)
				player.global_position = heli.get_hit_center() + Vector2(0, 70)
				await _frames(1)
				heli._shoot_decay(heli.direction_to_player(), 130.0)
				var decayed := {"d": false}
				await _survive(90, func() -> void:
					player.global_position = heli.get_hit_center() + Vector2(0, 70)
					if player.is_decayed():
						decayed["d"] = true)
				_check(decayed["d"], "부패탄에 맞으면 부패")
				heli.set_physics_process(true)
				var seen35 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen35["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen35["shot"] = true)
				_check(seen35["aoe"] and seen35["shot"], "헬리시온 패턴: 부패의 숨결 · 뼈 창 · 저주의 땅 · 망자 부활")
			36:
				var sera := boss as BossSeraphine
				await _survive(5)
				var scale36 := sera.get_judgement_scale()
				_check(scale36 != null, "[기믹] 천칭: 보스방 왼쪽·오른쪽에 쌓이는 피해의 저울")
				player.global_position = boss_center + Vector2(-140, 70)
				sera.take_damage(2000, Vector2.ZERO, false, 999999)
				player.global_position = boss_center + Vector2(140, 70)
				sera.take_damage(2000, Vector2.ZERO, false, 999999)
				_check(not sera.is_judging() and scale36 != null and absf(scale36.get_tilt()) < 0.1, "양쪽에서 번갈아 때리면 천칭이 기울지 않음")
				player.global_position = boss_center + Vector2(-140, 70)
				sera.take_damage(roundi(sera.max_hp * sera.tilt_limit) + 500, Vector2.ZERO, false, 999999)
				_check(sera.is_judging() and sera._judge_side == JudgementScale.Side.LEFT, "[기믹] 한쪽(왼쪽)에서만 때리면 천칭이 기울어 그쪽에 심판 예고")
				_gm.hp = _gm.max_hp
				var hp36: int = _gm.hp
				var spot36 := boss_center + Vector2(-140, 70)
				await _frames(int(sera.judge_warn * 60) + 6)
				_check(sera.get_judge_hits() == 1 and _gm.hp <= hp36 - roundi(_gm.max_hp * sera.judge_ratio) + 5 and scale36.get_tilt() == 0.0, "심판의 빛: 기운 쪽에 있으면 큰 피해 (가드·대시 불가), 저울은 다시 0")
				_gm.hp = _gm.max_hp
				player.global_position = spot36
				sera.begin_judgement(JudgementScale.Side.RIGHT)
				await _frames(int(sera.judge_warn * 60) + 6)
				_check(sera.get_judge_hits() == 1 and sera.get_judgement_count() == 2, "반대쪽에 있으면 심판을 피함")
				sera.set_physics_process(false)
				player.apply_stigma(5.0)
				await _frames(2)
				_gm.hp = _gm.max_hp - 30
				var hp_s36: int = _gm.hp
				var pot36: int = _gm.get_total_potions()
				_check(_gm.use_potion() and _gm.hp < hp_s36 and _gm.get_total_potions() == pot36 - 1 and _gm.player_status.contains("성흔"), "[기믹] 성흔: 포션을 마시면 회복 대신 피해")
				player._stigma_left = 0.0
				_gm.potions[_gm.choose_potion().id if _gm.choose_potion() != null else &"small_potion"] = 2
				player.global_position = sera.get_hit_center() + Vector2(0, 70)
				await _frames(1)
				sera._shoot_stigma(sera.direction_to_player())
				var stig := {"s": false}
				await _survive(90, func() -> void:
					player.global_position = sera.get_hit_center() + Vector2(0, 70)
					if player.is_stigmatized():
						stig["s"] = true)
				_check(stig["s"], "성흔 구체에 맞으면 성흔")
				player._stigma_left = 0.0
				sera.set_physics_process(true)
				var seen36 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen36["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen36["shot"] = true)
				_check(seen36["aoe"] and seen36["shot"], "세라핀 패턴: 성창 · 깃털 비 · 후광 · 성흔 · 소환")
			37:
				var asta := boss as BossAstaroth
				await _survive(5)
				var statues := asta.get_statues()
				_check(statues.size() == 4 and asta.defense == asta._base_defense + asta.statue_armor * 4, "[기믹] 신상 4개 — 신상마다 방어력 +%d" % asta.statue_armor)
				asta.set_physics_process(false)
				var near := statues[0].global_position + Vector2(0, 20)
				player.global_position = near
				asta.set_physics_process(true)
				await _survive(60, func() -> void:
					player.global_position = near)
				_check(asta.faith > 5.0 and is_equal_approx(_gm.faith_damage_bonus, player.get_faith() / 100.0 * Player.FAITH_MAX_BONUS) and _gm.faith_damage_bonus > 0.0 and _gm.player_status.contains("신앙"),
						"[기믹] 신상 근처에 있으면 신앙이 차오름 → 공격력 +%d%%" % roundi(_gm.faith_damage_bonus * 100.0))
				player.global_position = boss_center + Vector2(0, 150)
				var faith_before := asta.faith
				await _survive(30, func() -> void:
					player.global_position = boss_center + Vector2(0, 150))
				_check(asta.faith < faith_before, "신상에서 멀어지면 신앙이 줄어듦")
				asta.faith = 99.5
				await _survive(10, func() -> void:
					player.global_position = near)
				_check(asta.get_fanatic_count() == 1 and player.is_charmed() and _gm.player_status.contains("광신") and asta.faith < 1.0, "신앙이 가득 차면 「광신화」: 조작 불가 (신앙은 0 으로)")
				var spot37 := statues[1].global_position
				statues[1].take_damage(999999999)
				await _frames(3)
				var curse := false
				for zone in get_tree().get_nodes_in_group(&"hostile_zones"):
					if (zone as GroundZone).kind == GroundZone.Kind.CURSE and (zone as GroundZone).global_position.distance_to(spot37) < 1.0:
						curse = true
				_check(asta.get_broken_count() == 1 and asta.defense == asta._base_defense + asta.statue_armor * 3 and curse, "[기믹] 신상을 부수면 아스타로트가 약해지고 그 자리에 저주의 땅")
				var seen37 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen37["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen37["shot"] = true)
				_check(seen37["aoe"] and seen37["shot"], "아스타로트 패턴: 타락의 고리 · 천벌 · 속박의 사슬 · 소환")
			38:
				var talos := boss as BossTalos
				await _survive(5)
				_check(talos.get_nail() != null and talos.defense == talos._base_defense + talos.nail_armor and talos.pools.size() == 2,
						"[기믹] 발목의 청동 못 (방어력 +%d) · 물웅덩이 2곳" % talos.nail_armor)
				var nail_hp0 := talos.get_nail().max_hp if talos.get_nail() != null else 0
				if talos.get_nail() != null:
					talos.get_nail().take_damage(9999999)
				await _frames(3)
				_check(talos.get_nails_broken() == 1 and talos.is_bleeding() and talos.is_stunned() and talos.defense == talos._base_defense, "청동 못을 부수면 이코르가 흘러 무너짐 (기절 · 방어력 보너스 사라짐)")
				var hp38 := talos.hp
				await _survive(40)
				_check(talos.hp < hp38, "이코르 출혈로 체력이 계속 줄어듦 (-%d)" % (hp38 - talos.hp))
				talos._bleed_left = 0.01
				await _survive(140)
				_check(talos.get_nail() != null and talos.get_nail().max_hp > nail_hp0 and talos.defense == talos._base_defense + talos.nail_armor, "출혈이 끝나면 더 단단한 새 못을 박음")
				talos._stun_left = 0.0
				talos.heat = 60.0
				await _frames(2)
				_check(talos.burn_damage > 0 and talos.get_status_text().begins_with("열"), "[기믹] 열 50%% 이상이면 공격에 화상")
				talos.global_position = talos.pools[0].global_position
				await _frames(3)
				_check(talos.get_cool_count() == 1 and talos.heat < 5.0 and talos.burn_damage == 0, "물웅덩이에 들어가면 식음")
				talos._stun_left = 0.0
				talos.heat = 100.0
				talos._blaze_timer = 0.01
				talos.global_position = boss_center + Vector2(0, -60)
				await _frames(3)
				_check(_count_nodes_of("AoeStrike") > 0, "열 100%% 「작열」: 몸 주위 폭발")
				var seen38 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen38["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen38["shot"] = true)
				_check(seen38["aoe"] and seen38["shot"], "탈로스 패턴: 발 구르기 · 바위 던지기 · 주먹 · 소환")
			39:
				var mino := boss as BossMinotaur
				await _survive(5)
				_check(mino.get_maze() != null and mino.get_maze().walls.size() >= 4, "[기믹] 움직이는 미궁: 벽 %d개" % (mino.get_maze().walls.size() if mino.get_maze() != null else 0))
				mino._maze_left = 999.0
				mino._trap_cooldown = 999.0
				var built := mino.get_maze().get_rebuild_count()
				mino.shift_maze()
				_check(mino.get_maze().is_warning(), "미궁이 바뀔 자리를 점선으로 예고")
				await _survive(110)
				_check(mino.get_maze().get_rebuild_count() == built + 1 and not mino.get_maze().is_warning(), "예고 뒤 벽이 새 자리로 옮겨 감")
				mino._maze_left = 999.0
				var wall39: Array[Rect2] = [Rect2(boss_center + Vector2(60, -60), Vector2(10, 120))]
				mino.get_maze()._apply(wall39)
				mino.global_position = boss_center + Vector2(-60, 0)
				player.global_position = boss_center + Vector2(-60, 120)
				mino._bstate = PatternBoss.BossState.CASTING
				mino._btimer = 5.0
				mino.begin_charge(Vector2.RIGHT)
				await _survive(int(mino.charge_windup * 60) + 40, func() -> void:
					player.global_position = boss_center + Vector2(-60, 120))
				_check(mino.get_stuck_count() == 1 and mino.is_stuck() and mino.is_stunned(), "[기믹] 돌진하다 벽에 들이받으면 뿔이 박힘 (무방비)")
				var hp39 := mino.hp
				mino.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp39 - mino.hp == roundi(1000 * mino.stuck_multiplier), "뿔이 박힌 동안 받는 피해 x%.1f" % mino.stuck_multiplier)
				mino._stun_left = 0.0
				mino._stuck_left = 0.0
				var no_walls: Array[Rect2] = []
				mino.get_maze()._apply(no_walls)
				mino.begin_trap()
				var thread39 := mino.get_thread()
				_check(thread39 != null and thread39.points.size() >= 3, "[기믹] 미궁의 함정: 바닥에 아리아드네의 실")
				if thread39 != null:
					var on := thread39.points[2]
					await _survive(int(mino.trap_warn * 60) + 6, func() -> void:
						player.global_position = on)
				_check(mino.get_trap_dodges() == 1 and mino.get_trap_hits() == 0, "실 위에 서 있으면 함정을 피함")
				mino.begin_trap()
				var thread39b := mino.get_thread()
				var off := boss_center
				if thread39b != null:
					var area39 := stage.boss_room.get_arena_rect()
					for cand in [area39.position + Vector2(30, 30), area39.end - Vector2(30, 30), Vector2(area39.position.x + 30, area39.end.y - 30), Vector2(area39.end.x - 30, area39.position.y + 30)]:
						if not thread39b.is_on_thread(cand):
							off = cand
							break
				_gm.hp = _gm.max_hp
				var hp_t: int = _gm.hp
				player.global_position = off
				await _frames(int(mino.trap_warn * 60) + 6)
				_check(mino.get_trap_hits() == 1 and _gm.hp <= hp_t - roundi(_gm.max_hp * mino.trap_ratio) + 5, "실 밖에 있으면 함정에 큰 피해 (가드·대시 불가)")
				_gm.hp = _gm.max_hp
				player.global_position = boss_center + Vector2(0, 90)
				var seen39 := {"aoe": false, "shot": false, "charge": false}
				await _survive(700, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen39["aoe"] = true
					if mino.is_charging():
						seen39["charge"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen39["shot"] = true)
				_check(seen39["aoe"] and seen39["shot"] and seen39["charge"], "미노타우로스 패턴: 돌진 · 양날 도끼 · 발 구르기 · 소환")
			40:
				var herm := boss as BossHermes
				await _survive(5)
				var bow40 := ItemDB.get_item(&"hunter_bow") as WeaponData
				_gm.add_item(bow40)
				_gm.equip_item(bow40)
				herm._bstate = PatternBoss.BossState.CHASE
				var hp40 := herm.hp
				herm.take_damage(1000, Vector2.ZERO, false, 999999)
				var moving_loss := hp40 - herm.hp
				herm._bstate = PatternBoss.BossState.CASTING
				herm._btimer = 5.0
				hp40 = herm.hp
				herm.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(moving_loss == roundi(1000 * herm.moving_ratio) and hp40 - herm.hp == 1000, "[기믹] 신속: 달리는 동안엔 피해 %d%%만, 멈춰서 패턴을 쓸 때는 그대로" % roundi(herm.moving_ratio * 100.0))
				_check(_gm.equipped_weapon == bow40, "(준비) 활을 손에 듦")
				_check(herm.try_steal() and _gm.stolen_weapon == bow40 and not _gm.items.has(bow40) and not _gm.weapon_slots.has(bow40) and _gm.equipped_weapon != null and _gm.equipped_weapon != bow40,
						"[기믹] 도둑의 손: 손에 든 무기(활)를 빼앗김 → 남은 무기로 바뀜")
				herm.take_damage(roundi(herm.max_hp * herm.recover_ratio) + 200, Vector2.ZERO, false, 999999)
				_check(_gm.stolen_weapon == null and _gm.items.has(bow40) and _gm.weapon_slots.has(bow40) and not herm.has_stolen(), "헤르메스를 충분히 때리면 무기를 되찾음")
				_gm.unequip_item(bow40)
				_gm.gold = 500
				_check(herm.try_steal() and herm.stolen_gold == 300 and _gm.gold == 200, "무기가 하나뿐이면 골드를 훔쳐 감")
				herm.give_back()
				_check(_gm.gold == 500, "되찾으면 골드도 돌아옴")
				herm.send_letters()
				await _frames(3)
				var letters := herm.get_letters()
				_check(letters.size() == 3, "[기믹] 전령의 편지 3통")
				if not letters.is_empty():
					letters[0].take_damage(9999999)
				herm.letter_speed = 3000.0
				var speed40 := herm.move_speed
				await _frames(12)
				_check(herm.blessings == 2 and herm.move_speed > speed40, "떨어뜨리지 못한 편지가 도착하면 「전령의 축복」 (빨라짐 · 강해짐)")
				herm.letter_speed = 55.0
				var seen40 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen40["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen40["shot"] = true)
				_check(seen40["aoe"] and seen40["shot"], "헤르메스 패턴: 뱀 지팡이 · 질풍 차기 · 도둑의 손 · 편지 · 소환")
			41:
				var hydra := boss as BossHydra
				await _survive(5)
				var lit_count := 0
				for b in hydra.braziers:
					if b.lit:
						lit_count += 1
				_check(hydra.get_heads().size() == hydra.start_heads and lit_count == 4 and hydra.defense == hydra._base_defense + hydra.head_armor * hydra.start_heads,
						"[기믹] 히드라 머리 %d개 (머리마다 방어력 +%d) · 성화대 4개" % [hydra.start_heads, hydra.head_armor])
				hydra.get_heads()[0].take_damage(9999999)
				await _frames(3)
				var stumps := hydra.get_stumps()
				_check(hydra.get_cut_count() == 1 and stumps.size() == 1 and hydra.get_heads().size() == hydra.start_heads - 1, "머리를 자르면 잘린 목이 남음")
				if not stumps.is_empty():
					stumps[0].take_damage(500)
				await _frames(2)
				_check(hydra.get_burned_count() == 0 and hydra.get_stumps().size() == 1, "불 없이 잘린 목을 때리면 소용없음")
				if not stumps.is_empty():
					hydra._stump_left[stumps[0]] = 0.01
				await _frames(4)
				_check(hydra.get_regrown_count() == 1 and hydra.get_stumps().is_empty() and hydra.get_heads().size() == hydra.start_heads + 1, "[기믹] 지지지 않은 목에서 머리 두 개가 돋아남 (%d개)" % hydra.get_heads().size())
				var brazier := hydra.braziers[0]
				await _survive(5, func() -> void:
					player.global_position = brazier.global_position + Vector2(0, 6))
				_check(player.has_fire_enchant() and _gm.player_status.contains("불꽃 부여"), "[기믹] 성화대에 다가가면 무기에 「불꽃 부여」")
				var heads_now := hydra.get_heads().size()
				hydra.get_heads()[0].take_damage(9999999)
				await _frames(3)
				var hp41 := hydra.hp
				var stumps2 := hydra.get_stumps()
				if not stumps2.is_empty():
					stumps2[0].take_damage(1)
				await _frames(2)
				_check(hydra.get_burned_count() == 1 and hydra.get_stumps().is_empty() and hydra.get_heads().size() == heads_now - 1 and hydra.hp < hp41,
						"불꽃 부여 중에 잘린 목을 때리면 지져짐 → 다시 자라지 않음 + 히드라가 피해")
				var doused := hydra.douse_brazier()
				_check(doused != null and not doused.lit, "히드라의 물줄기가 성화대를 꺼 버림")
				if doused != null:
					doused._relight_left = 0.01
				await _frames(3)
				_check(doused != null and doused.lit, "꺼진 성화대는 잠시 뒤 다시 붙음")
				player._fire_enchant_left = 0.0
				var flame41 := ItemDB.get_item(&"flame_blade") as WeaponData
				_gm.add_item(flame41)
				_gm.equip_item(flame41)
				var by_weapon_off := hydra.can_cauterize()
				hydra.fire_weapons_cauterize = true
				var by_weapon_on := hydra.can_cauterize()
				hydra.fire_weapons_cauterize = false
				_check(not by_weapon_off and by_weapon_on, "불속성 무기로 지지기는 기본으로 꺼져 있음 (설정으로 켤 수 있음)")
				player.global_position = boss_center + Vector2(0, 90)
				var seen41 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen41["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen41["shot"] = true)
				_check(seen41["aoe"] and seen41["shot"], "히드라 패턴: 독니 · 독 늪 · 물줄기 · 소환")
			42:
				var poly := boss as BossPolyphemus
				await _survive(5)
				_check(poly.get_eye() != null and poly.defense == poly._base_defense + poly.eye_armor and poly.get_sheep().size() == poly.sheep_count and poly.aim_point() == player.global_position,
						"[기믹] 이마의 외눈 (방어력 +%d) · 양 %d마리 · 앞이 보일 땐 플레이어를 노림" % [poly.eye_armor, poly.sheep_count])
				var hp42 := poly.hp
				poly.get_eye().take_damage(9999999)
				await _frames(3)
				_check(poly.blind and poly.is_stunned() and poly.defense == poly._base_defense and poly.hp < hp42, "[기믹] 눈을 부수면 「실명」: 큰 피해 · 기절 · 방어력 보너스 사라짐")
				poly._stun_left = 0.0
				var area42 := stage.boss_room.get_arena_rect()
				var loud := area42.get_center()
				for cand in [area42.position + Vector2(40, 40), area42.end - Vector2(40, 40), Vector2(area42.position.x + 40, area42.end.y - 40), Vector2(area42.end.x - 40, area42.position.y + 40), area42.get_center() + Vector2(0, 120)]:
					var ok := true
					for sh in poly.get_sheep():
						if sh.global_position.distance_to(cand) < 60.0:
							ok = false
					if ok:
						loud = cand
						break
				player.global_position = loud
				await _frames(1)
				_gm.report_player_attacked(_gm.equipped_weapon, Vector2.RIGHT)
				_check(poly.get_heard_count() == 1 and poly.heard_at.distance_to(loud) < 2.0 and poly.aim_point() == poly.heard_at, "[기믹] 눈이 먼 뒤엔 공격 소리가 난 곳을 노림")
				var flock := poly.get_sheep()
				if not flock.is_empty():
					player.global_position = flock[0].global_position
					await _frames(1)
					player.global_position = flock[0].global_position
					_gm.report_player_attacked(_gm.equipped_weapon, Vector2.RIGHT)
				_check(poly.get_muffled_count() == 1 and poly.get_heard_count() == 1 and poly.heard_at.distance_to(loud) < 2.0, "[기믹] 양 곁에서는 소리가 양털에 묻혀 들키지 않음")
				player.global_position = boss_center + Vector2(0, 90)
				var seen42 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen42["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen42["shot"] = true)
				_check(seen42["aoe"] and seen42["shot"], "폴리페모스 패턴: 바위 던지기 · 몽둥이 · 발 구르기 · 더듬기 · 소환")
			43:
				var cerb := boss as BossCerberus
				await _survive(5)
				var heads_ok := cerb.lyre != null
				for h in cerb.heads:
					if h == null or not is_instance_valid(h):
						heads_ok = false
				_check(heads_ok, "[기믹] 불·얼음·독의 세 머리 + 리라")
				var hp43 := cerb.hp
				cerb.take_damage(1000, Vector2.ZERO, false, 999999)
				var body_loss := hp43 - cerb.hp
				hp43 = cerb.hp
				cerb.heads[0].take_damage(1000, Vector2.ZERO, false, 999999)
				_check(body_loss == roundi(1000 * cerb.body_ratio) and hp43 - cerb.hp == 1000, "몸통은 단단해서 %d%%만 · 머리를 때리면 그대로 들어감" % roundi(cerb.body_ratio * 100.0))
				var lyre_at := cerb.lyre.global_position
				await _survive(int(cerb.lyre.play_time * 60) + 20, func() -> void:
					player.global_position = lyre_at)
				var asleep := -1
				for i in 3:
					if cerb.is_head_asleep(i):
						asleep = i
				_check(cerb.get_sleep_count() == 1 and asleep >= 0, "[기믹] 리라 곁에 서 있으면 연주가 쌓여 머리 하나가 잠듦")
				if asleep >= 0:
					hp43 = cerb.hp
					cerb.heads[asleep].take_damage(1000, Vector2.ZERO, false, 999999)
					_check(hp43 - cerb.hp == roundi(1000 * cerb.sleep_multiplier), "잠든 머리를 때리면 피해 %d배" % roundi(cerb.sleep_multiplier))
					cerb._sleep_left[asleep] = 0.01
					await _frames(3)
					_check(not cerb.is_head_asleep(asleep) and is_equal_approx(cerb.heads[asleep].relay_ratio, 1.0), "시간이 지나면 다시 깸")
				player.global_position = boss_center + Vector2(0, 60)
				var seen43 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen43["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen43["shot"] = true)
				_check(seen43["aoe"] and seen43["shot"], "케르베로스 패턴: 세 머리 · 물어뜯기 · 울부짖음 · 소환")
			44:
				var scy := boss as BossScylla
				await _survive(150)
				var wp := scy.get_whirlpool()
				var area44 := stage.boss_room.get_arena_rect()
				_check(wp != null and wp.global_position.distance_to(area44.get_center()) < 1.0 and scy.in_edge_band(scy.global_position), "[기믹] 한가운데 카립디스의 소용돌이 · 스킬라는 가장자리를 따라 움직임")
				_check(scy.in_edge_band(area44.position + Vector2(20, 120)) and not scy.in_edge_band(area44.get_center()) and scy.in_edge_band(scy.edge_point(area44.get_center() + Vector2(10, 5))), "가장자리 띠(스킬라의 머리가 닿는 곳) 판정")
				scy._swallow_cooldown = 999.0
				scy.set_physics_process(false)
				player.global_position = area44.get_center() + Vector2(110, 0)
				await _survive(40)
				var d_after := player.global_position.distance_to(area44.get_center())
				_check(d_after < 109.0, "소용돌이가 플레이어를 가운데로 끌어당김 (%.0f → %.0f)" % [110.0, d_after])
				scy.set_physics_process(true)
				scy.begin_swallow()
				_check(wp != null and wp.is_swallowing(), "카립디스가 거세게 빨아들임")
				player.global_position = area44.get_center()
				_gm.hp = _gm.max_hp
				await _frames(40)
				_check(wp != null and wp.core_hits >= 1, "소용돌이 한가운데에 빠지면 큰 피해 (가드·대시 불가)")
				_gm.hp = _gm.max_hp
				player.global_position = area44.get_center() + Vector2(0, 130)
				scy._swallow_cooldown = 3.0
				var seen44 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen44["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen44["shot"] = true)
				_check(seen44["aoe"] and seen44["shot"] and scy.get_swallow_count() >= 2, "스킬라·카립디스 패턴: 여섯 머리 · 늘어나는 목 · 삼키기 · 토해내기")
			45:
				var ant := boss as BossAntaeus
				await _survive(5)
				_check(ant.pads.size() == 3 and ant.defense == ant._base_defense + ant.ground_armor, "[기믹] 대지의 힘 (방어력 +%d) · 상승 기류 발판 3개" % ant.ground_armor)
				ant.take_damage(6000, Vector2.ZERO, false, 999999)
				var hp45 := ant.hp
				await _survive(60)
				_check(ant.hp > hp45, "땅에 닿아 있으면 체력이 회복됨 (+%d)" % (ant.hp - hp45))
				ant._stack_timer = ant.ground_stack_time
				var power45 := ant.power
				await _frames(2)
				_check(ant.stacks == 1 and ant.power > power45, "시간이 지날수록 대지의 힘으로 공격력이 오름")
				ant._bstate = PatternBoss.BossState.CHASE
				ant.global_position = ant.pads[0].global_position
				await _frames(3)
				_check(ant.is_lifted() and ant.get_lift_count() == 1 and ant.defense == ant._base_defense and ant.stacks == 0, "[기믹] 상승 기류 발판에 올라서면 떠올라 대지의 힘이 끊김")
				var hp45b := ant.hp
				ant.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp45b - ant.hp == roundi(1000 * ant.lift_multiplier), "떠 있는 동안 받는 피해 x%.1f" % ant.lift_multiplier)
				hp45b = ant.hp
				await _frames(30)
				_check(ant.hp == hp45b, "떠 있는 동안엔 회복하지 못함")
				ant._lift_left = 0.01
				await _frames(3)
				_check(not ant.is_lifted() and ant.defense == ant._base_defense + ant.ground_armor and _count_nodes_of("AoeStrike") > 0, "내려오면 땅을 울리며 대지의 힘이 돌아옴")
				ant.global_position = boss_center + Vector2(0, -80)
				var grab_at := boss_center + Vector2(60, 60)
				player.global_position = grab_at
				ant.cast(BossAntaeus.Pattern.GRAB)
				var grabbed := {"g": false}
				await _survive(70, func() -> void:
					player.global_position = grab_at
					if player.is_rooted():
						grabbed["g"] = true)
				_check(grabbed["g"], "붙잡기 예고 자리에 있으면 붙잡혀 묶임")
				player.global_position = boss_center + Vector2(0, -50)  # 발판에서 떨어진 곳 (끌려와 떠오르지 않게)
				var seen45 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen45["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen45["shot"] = true)
				_check(seen45["aoe"] and seen45["shot"], "안타이오스 패턴: 붙잡기 · 땅 울림 · 모래 뿌리기 · 소환")
			46:
				var ara := boss as BossArachne
				await _survive(5)
				_check(ara.get_loom() != null, "[기믹] 보스방 위쪽의 베틀")
				ara._weave_left = 999.0
				var web := ara.weave()
				var spot46 := boss_center + Vector2(-120, 90)
				web.global_position = spot46
				var slowed := {"s": false, "r": false}
				await _survive(100, func() -> void:
					if not player.is_rooted():
						player.global_position = spot46
					if player.is_slowed() and _gm.player_status.contains("거미줄"):
						slowed["s"] = true
					if player.is_rooted():
						slowed["r"] = true)
				_check(slowed["s"] and slowed["r"], "[기믹] 거미줄을 밟으면 느려지고, 오래 서 있으면 묶임")
				player.release_root()
				ara.get_loom().take_damage(9999999)
				await _frames(3)
				_check(ara.is_loom_broken() and ara.is_stunned(), "[기믹] 베틀을 부수면 직조가 멈추고 아라크네가 휘청임")
				ara._weave_left = 0.01
				await _frames(120)
				_check(ara.get_webs().is_empty(), "베틀이 부서지면 거미줄이 걷히고 다시 짜지 못함")
				player.global_position = boss_center + Vector2(0, 90)
				var seen46 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen46["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen46["shot"] = true)
				_check(seen46["aoe"] and seen46["shot"], "아라크네 패턴: 거미줄 탄 · 덮치기 · 독니 · 소환")
			47:
				var ech := boss as BossEchidna
				await _survive(5)
				ech.lay_eggs()
				await _frames(3)
				var eggs := ech.get_eggs()
				_check(eggs.size() == ech.egg_count, "[기믹] 괴물의 알 %d개" % ech.egg_count)
				var power47 := ech.power
				eggs[0].take_damage(9999999)
				await _frames(2)
				_check(ech.rage == 1 and ech.power > power47, "[기믹] 알을 부수면 「어미의 분노」 (공격력 상승)")
				var before47 := get_tree().get_nodes_in_group(&"enemies").size()
				if eggs.size() > 1:
					ech._eggs[eggs[1]] = 0.01
				await _frames(4)
				var babies := 0
				for e in get_tree().get_nodes_in_group(&"enemies"):
					if (e as Enemy).display_name in ["꼬마 키메라", "히드라 새끼", "꼬마 케르베로스"]:
						babies += 1
				_check(ech.get_hatched_count() == 1 and babies >= 1 and ech.get_eggs().size() == ech.egg_count - 2, "부수지 못한 알은 부화 → 지난 보스의 새끼 (%d → %d)" % [before47, get_tree().get_nodes_in_group(&"enemies").size()])
				var seen47 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen47["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen47["shot"] = true)
				_check(seen47["aoe"] and seen47["shot"], "에키드나 패턴: 알 낳기 · 독 침 · 똬리 · 꼬리")
			48:
				var her := boss as BossHeracles
				await _survive(5)
				_check(not her.can_be_hit_by(Enemy.HitKind.MELEE) and her.can_be_hit_by(Enemy.HitKind.BOW) and her.can_be_hit_by(Enemy.HitKind.MAGIC), "[기믹] 네메아 사자 가죽: 검(근접)이 통하지 않음 · 활·마법만")
				her.take_damage(roundi(her.max_hp * 0.27), Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(her.labor == 1 and her.is_resting() and her.can_be_hit_by(Enemy.HitKind.MELEE) and her.is_stunned(), "[기믹] 과업이 바뀌면 숨 고르기 — 가죽을 벗어 검도 통함")
				var hp48 := her.hp
				her.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp48 - her.hp == roundi(1000 * her.rest_multiplier), "숨 고르는 동안 받는 피해 x%.1f" % her.rest_multiplier)
				her._rest_left = 0.01
				her._stun_left = 0.0
				await _frames(3)
				_check(not her.is_resting() and not her.can_be_hit_by(Enemy.HitKind.MELEE) and her.get_status_text().contains("레르나"), "숨을 고르면 다시 가죽을 두르고 다음 과업 「레르나의 히드라」")
				var seen48 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					if _count_nodes_of("AoeStrike") > 0:
						seen48["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen48["shot"] = true)
				_check(seen48["aoe"] and seen48["shot"], "헤라클레스 패턴: 과업별 공격 · 몽둥이 · 소환")
			49:
				var pro := boss as BossPrometheus
				await _survive(5)
				var chains := pro.get_chains()
				_check(chains.size() == 4 and pro.defense == pro._base_defense + pro.chain_armor * 4 and pro.freed == 0 and pro.leash_radius() < 1000.0, "[기믹] 사슬 4개 — 사슬마다 방어력 +%d, 묶인 범위만 움직임" % pro.chain_armor)
				var power49 := pro.power
				chains[0].take_damage(9999999)
				await _frames(3)
				_check(pro.freed == 1 and pro.defense == pro._base_defense + pro.chain_armor * 3 and pro.power > power49, "사슬을 끊으면 방어력이 떨어지지만 「해방」으로 사나워짐")
				for c in pro.get_chains():
					c.take_damage(9999999)
				await _frames(3)
				_check(pro.freed == 4 and pro.leash_radius() == INF and pro.get_status_text().contains("완전 해방"), "사슬을 모두 끊으면 완전 해방")
				var seen49 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0  # 완전 해방 불기둥(×1.48)은 장비 없는 테스트 캐릭터를 한 방에 쓰러뜨림 — 패턴 확인만
					if _count_nodes_of("AoeStrike") > 0:
						seen49["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen49["shot"] = true)
				_check(seen49["aoe"] and seen49["shot"], "프로메테우스 패턴: 훔친 불 · 불기둥 · 불의 고리 · 소환")
			50:
				var heph := boss as BossHephaestus
				await _survive(5)
				_check(heph.channels != null and heph.get_anvil() != null and heph.weapon == BossHephaestus.Weapon.HAMMER, "[기믹] 바닥의 쇳물 홈 · 모루 · 무기 「망치」")
				heph._pour_cooldown = 999.0
				heph.begin_pour(0)
				_check(heph.channels.is_warning() and heph.channels.lanes.size() == 2, "[기믹] 용광로: 쇳물이 흐를 홈이 달아오름 (예고)")
				var lane_at := heph.channels.lane_rect(heph.channels.lanes[0], false).get_center()
				await _survive(int(heph.pour_warn * 60) + 20, func() -> void:
					player.global_position = lane_at)
				_check(heph.channels.is_pouring() and heph.channels.hits >= 1, "쇳물이 흐르는 홈 위에 있으면 큰 피해 + 화상 (가드·대시 불가)")
				var safe := false
				for y in range(int(heph.channels.area.position.y) + 10, int(heph.channels.area.end.y), 12):  # 가로 홈 → 세로로 훑기
					var p50 := Vector2(heph.channels.area.get_center().x, y)
					if not heph.channels.is_in_flow(p50):
						safe = true
				_check(safe, "홈 사이에는 쇳물이 흐르지 않는 빈 땅이 있음")
				await _survive(int(heph.pour_time * 60) + 5)
				heph.take_damage(roundi(heph.max_hp * 0.35), Vector2.ZERO, false, 999999)
				await _frames(3)
				_check(heph.is_forging(), "[기믹] 담금질: 체력 2/3 에서 모루로 가 새 무기를 벼림")
				var power50 := heph.power
				heph._forging_left = 0.01
				await _frames(3)
				_check(heph.weapon == BossHephaestus.Weapon.AXE and heph.get_forge_count() == 1 and heph.power > power50, "담금질을 막지 못하면 새 무기 「도끼」 (공격력 상승)")
				heph.get_anvil().take_damage(9999999)
				await _frames(2)
				heph.take_damage(roundi(heph.max_hp * 0.35), Vector2.ZERO, false, 999999)
				await _frames(3)
				_check(not heph.is_forging() and heph.weapon == BossHephaestus.Weapon.AXE and heph.is_stunned(), "모루를 부숴 두면 다음 무기(창)를 벼리지 못함")
				heph._stun_left = 0.0
				player.global_position = boss_center + Vector2(-80, 90)
				await _frames(1)
				_check(heph.trap_in_net(), "(그물 던지기)")
				await _frames(3)
				_check(player.is_rooted() and heph.get_net() != null and _gm.player_status.contains("그물"), "[기믹] 황금 그물에 갇히면 움직일 수 없음")
				heph.get_net().take_damage(9999999)
				await _frames(3)
				_check(not player.is_rooted() and heph.get_net_escapes() == 1, "그물을 공격해 찢으면 빠져나옴")
				heph.trap_in_net()
				await _frames(3)
				heph._net_left = 0.01
				await _frames(3)
				_check(not player.is_rooted() and heph.get_net() == null and heph.get_net_escapes() == 1, "찢지 못해도 시간이 지나면 풀림")
				player.global_position = boss_center + Vector2(0, 90)
				var seen50 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0  # 무기가 바뀐 공격(×1.15~1.3)은 장비 없는 테스트 캐릭터를 한 방에 쓰러뜨림 — 패턴 확인만
					if _count_nodes_of("AoeStrike") > 0:
						seen50["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen50["shot"] = true)
				_check(seen50["aoe"] and seen50["shot"], "헤파이스토스 패턴: 무기 공격 · 황금 그물 · 불똥 · 소환")
			51:
				var sty := boss as BossStymphalian
				await _survive(5)
				_check(not player.is_rooted(), "앞 스테이지의 그물·묶임이 남지 않음")
				_check(sty.gongs.size() == 3 and sty.airborne and not sty.can_be_hit_by(Enemy.HitKind.MELEE) and sty.can_be_hit_by(Enemy.HitKind.BOW), "[기믹] 하늘 높이 — 활만 닿음 · 청동 징 3개")
				sty.gongs[0].take_damage(100)
				await _frames(2)
				_check(sty.is_grounded() and sty.can_be_hit_by(Enemy.HitKind.MELEE) and sty.is_stunned() and sty.get_ring_count() == 1, "[기믹] 징을 울리면 괴조가 땅으로 떨어짐 (기절 · 근접 공격도 통함)")
				sty._ground_left = 0.01
				sty._stun_left = 0.0
				await _frames(3)
				_check(sty.airborne and not sty.can_be_hit_by(Enemy.HitKind.MELEE), "시간이 지나면 다시 날아오름")
				sty.gongs[0].take_damage(100)
				await _frames(2)
				_check(sty.airborne and sty.get_ring_count() == 1, "한 번 울린 징은 잠시 다시 울리지 않음")
				sty.gongs[1].take_damage(100)
				await _frames(2)
				_check(sty.is_grounded() and sty.get_ring_count() == 2, "다른 징은 바로 울릴 수 있음")
				var seen51 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen51["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen51["shot"] = true)
				_check(seen51["aoe"] and seen51["shot"], "괴조 패턴: 청동 깃털 · 급강하 · 독 오물 · 소환")
			52:
				var sp := boss as BossSpartoi
				await _survive(5)
				_check(sp.get_warriors().size() == 4 and sp.defense == sp._base_defense + sp.phalanx_defense * 4 and sp.stones.size() == 4, "[기믹] 용의 이빨 전사 4명 — 방진: 전사 1명마다 방어력 +%d · 던질 돌 4개" % sp.phalanx_defense)
				sp.get_warriors()[0].take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(sp.get_warriors().size() == 3 and sp.defense == sp._base_defense + sp.phalanx_defense * 3, "전사가 쓰러지면 방진이 약해짐")
				if not sp._revives.is_empty():
					sp._revives[0]["left"] = 0.01
				await _frames(3)
				_check(sp.get_warriors().size() == 4 and sp.get_revived_count() == 1, "[기믹] 쓰러진 전사는 용의 이빨에서 다시 솟아남")
				var hp52 := sp.hp
				player._invincible_left = 2.0
				player.global_position = sp.stones[0].global_position
				await _frames(30)
				_check(sp.get_discord_count() == 1 and sp.hp < hp52 and sp.is_in_discord() and not sp.stones[0].available, "[기믹] 돌을 주우면 전사들 한가운데로 던짐 → 「불화」 (대장 -%d)" % (hp52 - sp.hp))
				var stunned52 := not sp.get_warriors().is_empty()
				for w in sp.get_warriors():
					if not w.is_stunned() or w.hp > roundi(w.max_hp * 0.71):
						stunned52 = false
				_check(stunned52, "불화 중 전사들은 서로 싸우느라 멈추고 체력 30%%를 잃음")
				player.global_position = boss_center + Vector2(0, 90)
				var seen52 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen52["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen52["shot"] = true)
				_check(seen52["aoe"] and seen52["shot"], "스파르토이 패턴: 방진 돌격 · 창 세례 · 용의 이빨 · 소환")
			53:
				var col := boss as BossColchian
				await _survive(5)
				_check(col.fleece != null and col.ship != null and col.fleece.available and not col.fleece.is_carried(), "[기믹] 참나무에 걸린 황금 양털 · 아르고호")
				col._stun_left = 99.0  # 제자리에 붙잡아 둠
				col.global_position = col.fleece.home + Vector2(0, 70)
				col.take_damage(roundi(col.max_hp * 0.2), Vector2.ZERO, false, 999999)
				var hp53 := col.hp
				player.global_position = boss_center + Vector2(150, 120)
				await _survive(60)
				_check(col.is_guarding_fleece() and col.hp > hp53 and col.get_healed_total() > 0, "양털 곁에서는 용이 회복함 (+%d)" % (col.hp - hp53))
				player._invincible_left = 2.0
				player.global_position = col.fleece.global_position
				await _frames(3)
				_check(col.fleece.is_carried() and not col.is_guarding_fleece(), "[기믹] 양털을 집어 듦 — 그동안 회복 멈춤")
				player.global_position = boss_center + Vector2(150, 120)
				await _frames(2)
				player._invincible_left = 0.0
				player.take_hit(10, player.global_position + Vector2(10, 0))
				await _frames(2)
				_check(not col.fleece.is_carried() and col.fleece.global_position.distance_to(col.fleece.home) < 1.0, "양털을 든 채 맞으면 떨어뜨리고 참나무로 돌아감")
				player._invincible_left = 2.0
				player.global_position = col.fleece.global_position
				await _frames(3)
				player.global_position = col.ship_position()
				await _frames(3)
				var hp53b := col.hp
				await _survive(40)
				_check(col.is_fleece_stashed() and col.get_stash_count() == 1 and col.hp == hp53b and not col.fleece.available, "[기믹] 양털을 아르고호에 실으면 회복이 멈춤")
				col._stun_left = 0.0
				col.stun(5.0)
				_check(col._stun_left < 1.0, "잠들지 않는 용: 기절이 아주 짧음 (%.1f초)" % col._stun_left)
				col._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen53 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen53["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen53["shot"] = true)
				_check(seen53["aoe"] and seen53["shot"], "콜키스의 용 패턴: 물기 · 독액 · 휘감기 · 소환")
			54:
				var hip := boss as BossHippolyta
				await _survive(5)
				_check(hip.has_girdle() and hip.defense == hip._base_defense + hip.girdle_defense and is_equal_approx(hip.power, hip._base_power * (1.0 + hip.girdle_power)), "[기믹] 전쟁의 허리띠: 공격력 +%d%% · 방어력 +%d" % [roundi(hip.girdle_power * 100.0), hip.girdle_defense])
				hip.stun(3.0)
				_check(not hip.is_stunned(), "허리띠를 찬 동안에는 기절하지 않음")
				hip.get_girdle().take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not hip.has_girdle() and hip.defense == hip._base_defense and is_equal_approx(hip.power, hip._base_power) and hip.is_stunned(), "[기믹] 허리띠를 끊으면 효과가 사라지고 크게 휘청임")
				hip._stun_left = 0.0
				var seen54 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen54["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen54["shot"] = true)
				_check(seen54["aoe"] and seen54["shot"], "히폴리테 패턴: 도끼 · 화살 세례 · 돌격 · 소환")
			55:
				var otus := boss as BossAloadae
				await _survive(5)
				var eph := otus.partner
				_check(otus.has_partner() and eph.role == BossAloadae.Role.EPHIALTES and otus.defense == otus._base_defense + otus.brother_defense and eph.defense == eph._base_defense + eph.brother_defense,
						"[기믹] 거인 형제 오토스와 에피알테스 — 둘 다 서 있으면 서로 방어력 +%d" % otus.brother_defense)
				player.global_position = boss_center + Vector2(0, 170)
				otus.global_position = boss_center + Vector2(-120, 0)
				eph.global_position = boss_center + Vector2(120, 0)
				_check(otus.hind_between_brothers(boss_center) and not otus.hind_between_brothers(boss_center + Vector2(0, 80)), "[기믹] 황금 사슴이 형제 사이에 있는지 판정")
				var hp_o := otus.hp
				var hp_e := eph.hp
				otus.hind = GoldenHind.spawn(otus, boss_center, otus._area())
				await _frames(2)
				_check(otus.get_clash_count() == 1 and otus.hp < hp_o and eph.hp < hp_e and otus.is_stunned() and eph.is_stunned() and otus.defense == otus._base_defense and eph.defense == eph._base_defense,
						"[기믹] 사슴을 형제 사이로 몰면 서로를 찌름 (피해 · 기절 · 형제의 힘 사라짐)")
				otus._stun_left = 0.0
				eph._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen55 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen55["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen55["shot"] = true)
				_check(seen55["aoe"] and is_instance_valid(eph), "거인 형제 패턴: 창 찌르기 · 발 구르기 · 바위 던지기 · 소환")
			56:
				var mel := boss as BossMeleager
				await _survive(5)
				_check(mel.brand != null and mel.hearth != null and mel.boar != null and mel.get_burned_count() == 0, "[기믹] 생명의 장작 · 화로 · 칼리돈의 멧돼지")
				var hp56 := mel.hp
				var def56 := mel.defense
				var pow56 := mel.power
				player._invincible_left = 2.0
				player.global_position = mel.brand.global_position
				await _frames(3)
				_check(mel.brand.is_carried(), "장작을 집어 듦")
				player.global_position = mel.hearth_position()
				await _frames(3)
				_check(mel.get_burned_count() == 1 and mel.hp < hp56 and mel.defense == def56 - mel.burn_defense and mel.power < pow56 and not mel.brand.is_carried(),
						"[기믹] 장작을 화로에 태우면 멜레아그로스가 약해짐 (피해 · 방어력 -%d · 공격력 -%d%%)" % [mel.burn_defense, roundi(mel.burn_power * 100.0)])
				for k in 3:
					mel.burn_brand()
				await _frames(2)
				_check(mel.get_burned_count() == 4 and mel.is_stunned() and mel.get_status_text().contains("꺼져"), "장작 4개를 모두 태우면 「꺼져 가는 목숨」")
				mel._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen56 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen56["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen56["shot"] = true)
				_check(seen56["aoe"] and seen56["shot"], "멜레아그로스 패턴: 사냥창 · 투창 · 멧돼지 돌격 · 소환")
			57:
				var cyc := boss as BossCycnus
				await _survive(5)
				_check(cyc.get_altars().size() == 3 and cyc.is_warded(), "[기믹] 해골 제단 3개 — 제단의 가호")
				var hp57 := cyc.hp
				cyc.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp57 - cyc.hp == roundi(1000 * cyc.ward_ratio), "제단이 서 있으면 받는 피해 %d%%만 (-%d)" % [roundi(cyc.ward_ratio * 100.0), hp57 - cyc.hp])
				for a in cyc.get_altars():
					a.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not cyc.is_warded() and cyc.is_stunned(), "[기믹] 제단을 모두 부수면 가호가 깨지며 휘청임")
				hp57 = cyc.hp
				cyc.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp57 - cyc.hp == 1000, "가호가 깨지면 피해가 그대로 들어감")
				cyc._rebuild_left = 0.01
				await _frames(3)
				_check(cyc.get_altars().size() == 1 and cyc.get_rebuilt_count() == 1 and cyc.is_warded(), "[기믹] 시간이 지나면 해골 순례자가 제단을 다시 쌓아 올림")
				cyc._stun_left = 0.0
				var seen57 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen57["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen57["shot"] = true)
				_check(seen57["aoe"] and seen57["shot"], "키크노스 패턴: 창 돌진 · 해골 탄막 · 백조의 날개 · 소환")
			58:
				var enc := boss as BossEnceladus
				await _survive(5)
				_check(enc.get_rocks().size() == 3, "[기믹] 보스방 가장자리에 시칠리아의 바위 3개")
				enc._stun_left = 99.0  # 제자리에 붙잡아 둠
				var hp58 := enc.hp
				player.global_position = boss_center + Vector2(0, 150)
				enc.get_rocks()[0].take_damage(100)
				await _frames(int(enc.drop_delay * 60) + 6)
				_check(enc.get_bury_count() == 1 and enc.is_buried() and enc.hp < hp58 and enc.defense == enc._base_defense - enc.bury_defense,
						"[기믹] 바위를 치면 거인 위로 떨어져 「묻힘」 (피해 · 방어력 -%d)" % enc.bury_defense)
				enc._buried_left = 0.01
				await _frames(2)
				_check(enc.defense == enc._base_defense and enc.get_rocks().size() == 2, "묻힘이 풀리면 방어력이 돌아옴 · 떨어뜨린 바위는 없어짐")
				enc._stun_left = 0.0
				enc.drop_rock(1)
				enc.global_position += Vector2(120, 0)
				await _frames(int(enc.drop_delay * 60) + 6)
				_check(enc.get_miss_count() == 1 and enc.get_bury_count() == 1, "거인이 비켜서면 바위가 빗나감")
				enc._rock_left[0] = 0.01
				await _frames(3)
				_check(enc.get_rocks().size() == 2, "떨어뜨린 바위는 잠시 뒤 다시 솟음")
				player.global_position = boss_center + Vector2(0, 90)
				var seen58 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen58["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen58["shot"] = true)
				_check(seen58["aoe"] and seen58["shot"], "엔켈라도스 패턴: 화산 분화 · 용암 주먹 · 마그마 비 · 소환")
			59:
				var lup := boss as BossLupus
				await _survive(5)
				_check(lup.get_pack().size() == 4 and lup.defense == lup._base_defense + lup.pack_defense * 4 and lup.power > lup._base_power, "[기믹] 늑대 무리 4마리 — 무리의 힘 (방어력 +%d)" % (lup.pack_defense * 4))
				lup.mark_player()
				var charging := not lup.get_pack().is_empty()
				for w in lup.get_pack():
					if w.get_command() != Enemy.Command.CHARGE:
						charging = false
				_check(lup.is_player_marked() and charging, "[기믹] 딱따구리의 표식: 무리 전체가 플레이어에게 돌격")
				for w in lup.get_pack():
					w.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(lup.get_pack().is_empty() and lup.get_scatter_count() == 1 and lup.is_stunned() and lup.defense == lup._base_defense and is_equal_approx(lup.power, lup._base_power),
						"[기믹] 무리를 흩으면 우두머리가 휘청이고 힘이 빠짐")
				lup._stun_left = 0.0
				lup.cast(BossLupus.Pattern.HOWL)
				await _frames(3)
				_check(lup.get_pack().size() == lup.pack_max, "울부짖으면 무리가 %d마리까지 다시 모임" % lup.pack_max)
				var seen59 := {"aoe": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen59["aoe"] = true)
				_check(seen59["aoe"], "루푸스 패턴: 물기 · 울부짖음 · 딱따구리 · 소환")
			60:
				var mars := boss as BossMars
				await _survive(5)
				var true_count := 0
				for s in mars.get_shields():
					if s == mars.true_shield:
						true_count += 1
				_check(mars.get_shields().size() == 12 and mars.has_sacred_shield() and true_count == 1 and mars.defense == mars._base_defense + mars.sacred_defense,
						"[기믹] 앙킬레: 방패 12개 중 진짜는 하나 — 방어력 +%d" % mars.sacred_defense)
				var fake: BossPart = null
				for s in mars.get_shields():
					if s != mars.true_shield:
						fake = s
				var shots_before := 0
				for c in pool.get_children():
					if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
						shots_before += 1
				fake.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				var shots_after := 0
				for c in pool.get_children():
					if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
						shots_after += 1
				_check(mars.get_fakes_broken() == 1 and mars.has_sacred_shield() and shots_after >= shots_before + 5, "가짜 방패를 부수면 필룸이 날아옴 (가호는 그대로)")
				mars.true_shield.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not mars.has_sacred_shield() and mars.defense == mars._base_defense and mars.is_stunned(), "[기믹] 진짜 방패를 부수면 가호가 사라지고 크게 휘청임")
				mars.fear_player()
				await _frames(2)
				var pos60 := player.global_position
				Input.action_press(&"move_right")
				await _survive(12)
				Input.action_release(&"move_right")
				_check(player.is_charmed() and not player.can_attack() and not player.can_guard() and player.global_position.distance_to(pos60) < 2.0 and _gm.player_status.contains("공포") and _gm.player_status.contains("행동불능"),
						"[기믹] 「공포」 — 행동불능 (이동 · 공격 · 가드 불가)")
				player._charm_left = 0.0
				await _frames(2)
				mars._stun_left = 0.0
				for node in get_tree().get_nodes_in_group(&"aoe_strikes"):
					node.queue_free()
				pool.release_all()
				for e in get_tree().get_nodes_in_group(&"enemies"):
					if e != mars and not e is BossPart:
						(e as Enemy).despawn()
				mars.global_position = player.global_position + Vector2(-90, 0)
				player._invincible_left = 0.0
				mars._start_charge()
				for i in 80:
					_gm.hp = 9999  # 전차(100)는 장비 없는 테스트 캐릭터(100)를 한 방에 쓰러뜨림
					await get_tree().physics_frame
				_gm.hp = _gm.max_hp
				_check(mars.get_fear_count() == 2 and player.is_charmed() and not _gm.is_player_dead, "[기믹] 포보스와 데이모스의 전차에 치이면 「공포」")
				player._charm_left = 0.0
				mars._frenzy = 0.0
				mars.add_frenzy(100.0)
				_check(mars.is_frenzied() and mars.power > mars._base_power and mars.move_speed > mars._base_speed, "[기믹] 전쟁의 광기: 분노가 가득 차면 광기 (공격력 · 속도 상승)")
				mars._frenzy_left = 0.01
				await _frames(2)
				_check(not mars.is_frenzied() and mars.get_frenzy() < 1.0 and is_equal_approx(mars.power, mars._base_power), "광기가 끝나면 분노 게이지가 비워짐")
				var f60 := mars.get_frenzy()
				player._invincible_left = 0.0
				player.take_hit(60, player.global_position + Vector2(10, 0))
				var f60b := mars.get_frenzy()
				mars.take_damage(roundi(mars.max_hp * 0.05), Vector2.ZERO, false, 999999)
				_check(f60b >= f60 + 5.0 and mars.get_frenzy() >= f60b + 4.0, "플레이어가 맞아도, 마르스가 맞아도 분노가 참 (%.0f → %.0f → %.0f)" % [f60, f60b, mars.get_frenzy()])
				player.global_position = boss_center + Vector2(0, 90)
				var seen60 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					player._charm_left = 0.0
					if _count_nodes_of("AoeStrike") > 0:
						seen60["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen60["shot"] = true)
				_check(seen60["aoe"] and seen60["shot"], "마르스 패턴: 군신의 창 · 전차 · 필룸 비 · 전쟁의 함성 · 소환")
				player.release_charm()
			61:
				var eur := boss as BossEurytus
				await _survive(5)
				_check(eur.targets.size() == 3 and eur.count_owned(BossEurytus.Owner.NONE) == 3, "[기믹] 궁술 경연 — 과녁 3개")
				eur.targets[0].take_damage(10)
				await _frames(2)
				_check(eur.owners[0] == BossEurytus.Owner.PLAYER, "과녁을 맞히면 내 차지")
				eur.claim_target(1, BossEurytus.Owner.BOSS)
				_check(not eur.claim_target(1, BossEurytus.Owner.PLAYER), "이미 맞힌 과녁은 빼앗을 수 없음")
				eur.targets[2].take_damage(10)
				await _frames(2)
				_check(eur.get_player_wins() == 1 and eur.defense == eur._base_defense - eur.lose_defense and eur.is_stunned(), "[기믹] 과녁 2개를 먼저 맞히면 경연 승리 → 에우리토스가 휘청 · 방어력 -%d" % eur.lose_defense)
				eur._round_rest_left = 0.01
				eur._stun_left = 0.0
				await _frames(3)
				_check(eur.count_owned(BossEurytus.Owner.NONE) == 3, "잠시 뒤 새 과녁이 섬")
				eur.claim_target(0, BossEurytus.Owner.BOSS)
				eur.claim_target(1, BossEurytus.Owner.BOSS)
				eur.claim_target(2, BossEurytus.Owner.PLAYER)
				_check(eur.get_boss_wins() == 1 and eur.power > eur._base_power, "[기믹] 에우리토스가 경연에서 이기면 공격력 상승")
				var at61 := player.global_position + Vector2(-60, -60)
				var es := ProjectileSpec.enemy_bullet(at61, Vector2.RIGHT, 1.0, 10, null)
				var ps := ProjectileSpec.enemy_bullet(at61 + Vector2(3, 0), Vector2.LEFT, 1.0, 10, null)
				ps.team = ProjectileSpec.Team.PLAYER
				pool.spawn(es)
				pool.spawn(ps)
				await _frames(3)
				_check(eur.get_parry_count() >= 1, "[기믹] 내 탄이 에우리토스의 화살에 닿으면 둘 다 떨어짐")
				var seen61 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen61["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen61["shot"] = true)
				_check(seen61["aoe"] and seen61["shot"], "에우리토스 패턴: 화살 세례 · 꿰뚫는 화살 · 화살비 · 경연 · 소환")
			62:
				var py := boss as BossPython
				await _survive(5)
				_check(py.fissures.size() == 5 and py.open_fissures().size() == 5 and py.branch != null, "[기믹] 갈라진 땅 틈 5곳 · 월계수 가지")
				if py.is_hiding():
					py.emerge()
				_check(py.dive() and py.is_hiding() and not py.can_be_hit_by(Enemy.HitKind.BOW), "[기믹] 피톤이 틈으로 숨음 — 무적")
				var hp62 := py.hp
				py.take_damage(5000, Vector2.ZERO, false, 999999)
				_check(py.hp == hp62, "숨어 있는 동안 피해 없음")
				var from62 := py._current
				py.emerge()
				_check(not py.is_hiding() and py._current != from62 and py.can_be_hit_by(Enemy.HitKind.MELEE), "다른 틈에서 솟아오름")
				player._invincible_left = 3.0
				player.global_position = py.branch.global_position
				await _frames(3)
				var hole := py.open_fissures()[0]
				player.global_position = py.fissures[hole].global_position
				await _frames(3)
				_check(py.get_plug_count() == 1 and py.fissures[hole].plugged and py.open_fissures().size() == 4, "[기믹] 월계수 가지를 들고 가 틈을 막음")
				if py.is_hiding():
					py.emerge()
				for i in py.open_fissures():
					py.plug(i)
				await _frames(2)
				_check(py.open_fissures().is_empty() and py.is_stunned() and not py.dive(), "[기믹] 틈이 모두 막히면 숨을 곳을 잃고 휘청임")
				py._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen62 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen62["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen62["shot"] = true)
				_check(seen62["aoe"] and seen62["shot"], "피톤 패턴: 휘감기 · 독액 · 물기 · 소환")
			63:
				var ph := boss as BossPhaethon
				await _survive(5)
				_check(ph.get_pillars().size() == 4 and not ph.is_fallen(), "[기믹] 고삐 기둥 4개")
				var speed63 := ph.chariot_speed()
				ph._stun_left = 0.0
				player.global_position = ph.global_position + Vector2(150, 0)
				ph.start_charge()
				await _survive(70, func() -> void:
					player._invincible_left = 1.0)
				_check(ph.get_trail_count() > 3 and not get_tree().get_nodes_in_group(&"hostile_zones").is_empty(), "[기믹] 폭주 전차가 지나간 자리에 불타는 궤적 (%d)" % ph.get_trail_count())
				ph.get_pillars()[0].take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(ph.chariot_speed() < speed63 and not ph.is_fallen(), "고삐를 끊을수록 전차가 느려짐")
				for p in ph.get_pillars():
					p.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(ph.is_fallen() and ph.is_stunned() and ph.defense == ph._base_defense - ph.fall_defense, "[기믹] 고삐를 모두 끊으면 파에톤이 떨어짐 (기절 · 방어력 -%d)" % ph.fall_defense)
				ph._stun_left = 0.0
				ph.cast(BossPhaethon.Pattern.CHARGE)
				_check(not ph.is_charging(), "떨어진 뒤에는 돌진하지 못함")
				player.global_position = boss_center + Vector2(0, 90)
				var seen63 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen63["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen63["shot"] = true)
				_check(seen63["aoe"] and seen63["shot"], "파에톤 패턴: 폭주 전차 · 태양 불꽃 · 작열 · 소환")
			64:
				var cas := boss as BossCassandra
				await _survive(5)
				cas.prophesy(1)
				_check(cas.last_true and cas.last_marks.size() >= 6 and cas.last_strikes == cas.last_marks, "[기믹] 푸른 목소리(참 예언): 표식 자리가 터짐")
				await _survive(int(cas.prophecy_delay * 60) + 10)
				var c64 := player.global_position
				cas.prophesy(0)
				var mirrored := true
				for i in cas.last_marks.size():
					if cas.last_strikes[i].distance_to(c64 * 2.0 - cas.last_marks[i]) > 0.5:
						mirrored = false
				_check(not cas.last_true and mirrored, "[기믹] 붉은 목소리(거짓 예언): 표식은 안전하고 플레이어 반대쪽이 터짐")
				var first64 := cas.last_strikes[0]
				await _frames(int(cas.prophecy_delay * 60) + 2)
				var struck := false
				for node in get_tree().get_nodes_in_group(&"aoe_strikes"):
					var st := node as AoeStrike
					if not st.harmless and st.global_position.distance_to(first64) < 1.0:
						struck = true
				_check(struck, "예언한 시간이 되면 실제로 그 자리가 터짐")
				var seen64 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen64["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen64["shot"] = true)
				_check(seen64["aoe"] and seen64["shot"], "카산드라 패턴: 예언 · 저주의 구슬 · 불타는 트로이 · 소환")
			65:
				var rav := boss as BossCoronisRaven
				await _survive(5)
				if rav.is_black():
					rav.turn_white()
				rav.turn_black()
				await _frames(3)
				var clones := rav.get_clones()
				var no_shadow := clones.size() == rav.clone_count
				for c in clones:
					if (c.get_node(^"Shadow") as CanvasItem).visible:
						no_shadow = false
				_check(rav.is_black() and no_shadow and (rav.get_node(^"Shadow") as CanvasItem).visible, "[기믹] 검은 깃털 — 분신 %d마리, 분신에게는 그림자가 없음" % rav.clone_count)
				clones[0].take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(rav.get_clones().size() == rav.clone_count - 1 and rav.is_black(), "분신을 때리면 깃털을 흩뿌리며 사라짐")
				rav.take_damage(1000, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not rav.is_black() and rav.get_clones().is_empty() and rav.is_stunned() and rav.get_reveal_count() == 1, "[기믹] 그림자가 있는 진짜를 때리면 분신이 사라지고 정체가 드러남")
				rav._stun_left = 0.0
				rav._phase_left = 0.01
				await _frames(3)
				_check(rav.is_black(), "시간이 지나면 다시 검게 변함")
				var seen65 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen65["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen65["shot"] = true)
				_check(seen65["aoe"] and seen65["shot"], "까마귀 패턴: 깃털 세례 · 급강하 · 울음 · 소환")
			66:
				var ach := boss as BossAchilles
				await _survive(5)
				ach._stun_left = 99.0
				ach.facing = ach.global_position.direction_to(player.global_position)
				var hp66 := ach.hp
				ach.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp66 - ach.hp <= 1 and ach.get_blocked_hits() == 1, "[기믹] 불사의 몸: 앞에서 때리면 통하지 않음")
				ach.facing = -ach.global_position.direction_to(player.global_position)
				hp66 = ach.hp
				ach.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp66 - ach.hp == roundi(1000 * ach.heel_multiplier) and ach.get_heel_hits() == 1, "[기믹] 등 뒤의 뒤꿈치를 때리면 피해 x%.1f" % ach.heel_multiplier)
				ach._stun_left = 0.0
				var face66 := ach.facing
				ach.cast(BossAchilles.Pattern.RUSH)
				await _survive(45, func() -> void:
					player._invincible_left = 1.0)
				_check(ach._recover_left > 0.0, "[기믹] 돌진 뒤에는 멈춰 숨을 고름 (천천히 돌아섬)")
				var seen66 := {"aoe": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen66["aoe"] = true)
				_check(seen66["aoe"] and face66 != Vector2.ZERO, "아킬레우스 패턴: 창 찌르기 · 돌진 · 방패 밀치기 · 소환")
				ach.facing = -ach.global_position.direction_to(player.global_position)  # 마지막 일격은 뒤꿈치로
			67:
				var mid := boss as BossMidas
				await _survive(5)
				_check(mid.field != null and mid.field.river.has_area() and mid.field.reeds.has_area(), "[기믹] 팍톨로스 강 · 갈대밭")
				mid._stun_left = 99.0
				player.global_position = mid.field.area.get_center() + Vector2(110, -20)
				mid.field.add_puddle(player.global_position, 10.0)
				await _survive(40, func() -> void:
					player._invincible_left = 1.0)
				_check(mid.gild > 15.0 and player.is_slowed() and _gm.player_status.contains("황금화"), "[기믹] 황금 웅덩이를 밟으면 「황금화」가 쌓이고 느려짐 (%d%%)" % roundi(mid.gild))
				mid.add_gild(100.0)
				await _frames(2)
				_check(player.is_charmed() and not player.can_attack() and _gm.player_status.contains("행동불능") and mid.get_freeze_count() == 1, "[기믹] 황금화 100%%: 굳어 버림 (행동불능)")
				player.release_charm()
				player.global_position = mid.field.river.get_center()
				await _frames(3)
				_check(mid.gild == 0.0, "[기믹] 팍톨로스 강에 들어가면 황금이 씻겨 나감")
				player.global_position = boss_center + Vector2(0, 60)
				mid._stun_left = 0.0
				mid.global_position = mid.field.reeds.get_center()
				await _frames(3)
				_check(mid.is_confused() and mid.is_stunned() and mid.defense == mid._base_defense - mid.confuse_defense, "[기믹] 갈대밭의 속삭임: 미다스가 혼란 (휘청 · 방어력 -%d)" % mid.confuse_defense)
				mid._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen67 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					player._charm_left = 0.0
					if _count_nodes_of("AoeStrike") > 0:
						seen67["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen67["shot"] = true)
				_check(seen67["aoe"] and seen67["shot"], "미다스 패턴: 황금의 손 · 금화 · 왕홀 · 소환")
			68:
				var hec := boss as BossHector
				await _survive(5)
				_check(hec.get_altars().size() == 3, "[기믹] 빛의 제단 3개")
				hec.take_damage(roundi(hec.max_hp * 0.4), Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(hec.is_veiled() and not hec.can_be_hit_by(Enemy.HitKind.MELEE), "[기믹] 체력 2/3 아래로 떨어지면 아폴론의 안개에 감싸여 사라짐 (무적)")
				var hp68 := hec.hp
				hec._veil_left = 0.01
				await _frames(3)
				_check(not hec.is_veiled() and hec.hp - hp68 == roundi(hec.max_hp * hec.heal_per_altar * 3), "다른 곳에서 나타나며 빛의 제단 3개만큼 회복 (+%d)" % (hec.hp - hp68))
				for a in hec.get_altars():
					a.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				hec.take_damage(hec.hp - roundi(hec.max_hp * 0.3), Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not hec.is_veiled() and hec.get_failed_veils() == 1 and hec.is_stunned(), "[기믹] 제단을 모두 부숴 두면 안개가 모이지 않아 사라지지 못하고 휘청임")
				hec._stun_left = 0.0
				var seen68 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen68["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen68["shot"] = true)
				_check(seen68["aoe"] and seen68["shot"], "헥토르 패턴: 창 · 성벽 궁수 · 번쩍이는 투구 · 소환")
			69:
				var pyt := boss as BossPythia
				await _survive(5)
				_check(pyt.get_tripods().size() == 3 and pyt.is_shielded(), "[기믹] 신탁의 삼발이 3개 — 신탁이 내린 삼발이가 서 있으면 보호막")
				var hp69 := pyt.hp
				pyt.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp69 - pyt.hp == roundi(1000 * pyt.shield_ratio), "보호막: 받는 피해 %d%%만" % roundi(pyt.shield_ratio * 100.0))
				var other69: BossPart = null
				for t in pyt.get_tripods():
					if t != pyt.oracle:
						other69 = t
				other69.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(pyt.is_shielded() and pyt.get_tripods().size() == 2, "다른 삼발이를 부숴도 보호막은 그대로")
				pyt.oracle.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not pyt.is_shielded() and pyt.is_stunned() and pyt.get_break_count() == 1, "[기믹] 신탁이 내린 삼발이를 부수면 보호막이 걷히고 휘청임")
				hp69 = pyt.hp
				pyt.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp69 - pyt.hp == 1000, "보호막이 걷히면 피해가 그대로 들어감")
				player._invincible_left = 2.0
				player.global_position = pyt.get_tripods()[0].global_position + Vector2(24, 0)
				await _frames(3)
				_check(player.is_in_smoke() and _gm.player_status.contains("연기"), "[기믹] 삼발이 곁 신탁의 연기 속에서는 조준이 흔들림")
				pyt._oracle_left = 0.01
				await _frames(3)
				_check(pyt.is_shielded(), "다음 신탁이 남은 삼발이에 내림")
				pyt._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen69 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen69["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen69["shot"] = true)
				_check(seen69["aoe"] and seen69["shot"], "피티아 패턴: 신탁의 구슬 · 땅의 증기 · 연기 구름 · 소환")
				for t in pyt.get_tripods():
					t.take_damage(9999999, Vector2.ZERO, false, 999999)  # 보호막을 걷어 마지막 일격이 그대로 들어가게
				await _frames(2)
			70:
				var apo := boss as BossApollo
				await _survive(5)
				_check(apo.sundial != null and apo.sundial.pillars.size() == 4, "[기믹] 해시계 — 돌기둥 4개와 그림자")
				apo._stun_left = 99.0
				apo._noon_left = 999.0
				var pil := apo.sundial.pillars[0]
				_check(apo.sundial.is_in_shade(pil.global_position - apo.sundial.sun_dir() * 50.0) and not apo.sundial.is_in_shade(pil.global_position + apo.sundial.sun_dir() * 50.0),
						"기둥 그림자는 태양 반대쪽으로 드리움")
				var open70 := boss_center
				for x in range(-200, 201, 40):
					for y in range(-100, 101, 40):
						var p70 := boss_center + Vector2(x, y)
						if not apo.sundial.is_in_shade(p70) and not apo.sundial.is_in_shade(p70 + Vector2(10, 10)):
							open70 = p70
				apo.sunstroke = 0.0
				player.global_position = open70
				await _survive(60, func() -> void:
					player._invincible_left = 1.0
					player.global_position = open70)
				var stroke70 := apo.sunstroke
				_check(stroke70 > 8.0 and _gm.player_status.contains("일사"), "[기믹] 햇빛 아래에 있으면 「일사」가 쌓임 (%d%%)" % roundi(stroke70))
				await _survive(30, func() -> void:
					player._invincible_left = 1.0
					player.global_position = pil.global_position - apo.sundial.sun_dir() * 50.0)
				_check(apo.sunstroke < stroke70, "기둥 그림자 속에서는 일사가 식음")
				apo.sunstroke = 100.0
				apo._stroke_tick = 0.0
				player.global_position = open70
				await _frames(3)
				_check(player.is_burning(), "일사가 100%%가 되면 화상")
				apo.begin_noon()
				_check(apo.sundial.noon and apo.is_noon_coming(), "[기믹] 정오 예고 — 그림자가 기둥 바로 아래로 줄어듦")
				player.global_position = pil.global_position + Vector2(0, 18)
				player._invincible_left = 0.0
				apo._noon_warn_left = 0.01
				await _frames(3)
				_check(apo.get_noon_count() == 1 and apo.get_noon_hits() == 0, "[기믹] 정오: 기둥 바로 아래에 있으면 무사 (거리 %.0f)" % player.global_position.distance_to(pil.global_position))
				apo.begin_noon()
				player.global_position = open70
				player._invincible_left = 0.0
				apo._noon_warn_left = 0.01
				_gm.hp = 9999
				await _frames(3)
				_gm.hp = _gm.max_hp
				_check(apo.get_noon_count() == 2 and apo.get_noon_hits() == 1, "정오: 기둥 아래가 아니면 큰 피해 (가드 불가)")
				var spec70 := ProjectileSpec.enemy_bullet(player.global_position + Vector2(-8, 0), Vector2.RIGHT, 20.0, 10, null)
				spec70.plague_duration = apo.plague_time
				player._invincible_left = 0.0
				pool.spawn(spec70)
				await _frames(6)
				_check(player.is_plagued() and is_equal_approx(_gm.potion_heal_multiplier, 0.5) and _gm.player_status.contains("역병"), "[기믹] 역병의 화살에 맞으면 「역병」 — 포션 회복 절반")
				await _survive(140, func() -> void:
					player._invincible_left = 1.0)
				_check(not get_tree().get_nodes_in_group(&"hostile_zones").is_empty(), "역병에 걸리면 발밑에 역병 장판이 퍼짐")
				apo._stun_left = 0.0
				apo._noon_left = 20.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen70 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen70["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen70["shot"] = true)
				_check(seen70["aoe"] and seen70["shot"], "아폴론 패턴: 햇살 화살 · 역병의 화살 · 태양의 고리 · 소환")
				player.cure_plague()
			71:
				var ser := boss as BossLaocoonSerpents
				await _survive(10)
				_check(ser.twin != null and ser.pools.size() == 2 and ser.up == 0, "[기믹] 두 물웅덩이의 쌍둥이 바다뱀 — 포르케스가 먼저 솟음")
				ser._surface_left = 999.0
				var hp71 := ser.hp
				ser.swap()
				await _frames(2)
				ser.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(ser.hp == hp71 and ser.collision_layer == 0, "[기믹] 물속에 잠긴 뱀은 맞지 않음")
				ser.twin.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(ser.hp == hp71 - 1000, "솟아 있는 카리보이아를 때리면 본체가 피해")
				ser._surface_left = 999.0
				player._invincible_left = 0.0
				ser.bind()
				await _frames(2)
				_check(ser.is_binding() and player.is_rooted() and _gm.player_status.contains("휘감김"), "[기믹] 휘감기 — 움직일 수 없음")
				for i in ser.escape_hits:
					player.attacked.emit()
				await _frames(2)
				_check(not ser.is_binding() and not player.is_rooted() and ser.get_escape_count() == 1, "공격을 %d번 연타하면 빠져나옴" % ser.escape_hits)
				var seen71 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if ser.is_binding():
						ser._release(false)
					if _count_nodes_of("AoeStrike") > 0:
						seen71["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen71["shot"] = true)
				_check(seen71["aoe"] and seen71["shot"], "바다뱀 패턴: 물기 · 물결 · 바닷물 · 휘감기")
				if ser.up == 1:
					ser.swap()  # 마지막 일격은 솟아 있는 본체에
			72:
				var th := boss as BossTrojanHorse
				await _survive(10)
				_check(th.get_wheels().size() == 4 and not th.is_stopped(), "[기믹] 트로이 목마의 바퀴 4개")
				var speed72 := th.move_speed
				th.get_wheels()[0].take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(th.move_speed < speed72, "바퀴를 부술수록 느려짐")
				var before72 := get_tree().get_nodes_in_group(&"enemies").size()
				th._hatch_left = 999.0
				th.open_hatch()
				await _frames(3)
				_check(th.is_hatch_open() and th.hatch != null and get_tree().get_nodes_in_group(&"enemies").size() >= before72 + 3, "[기믹] 해치가 열리며 그리스 병사가 쏟아짐")
				var hp72 := th.hp
				th.hatch.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp72 - th.hp == roundi(1000 * th.hatch_multiplier), "[기믹] 열린 해치를 때리면 피해 x%.1f" % th.hatch_multiplier)
				th._hatch_open_left = 0.01
				await _frames(3)
				_check(not th.is_hatch_open() and th.hatch == null, "해치가 다시 닫힘")
				for w in th.get_wheels():
					w.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(th.is_stopped() and th.is_stunned() and th.defense == th._base_defense - th.stop_defense, "[기믹] 바퀴를 모두 부수면 멈춰 섬 (휘청 · 방어력 -%d)" % th.stop_defense)
				th._stun_left = 0.0
				var seen72 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen72["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen72["shot"] = true)
				_check(seen72["aoe"] and seen72["shot"], "트로이 목마 패턴: 창 세례 · 내려찍기 · 횃불")
			73:
				var dio := boss as BossDiomedes
				await _survive(10)
				_check(dio.lamp != null and dio.veil != null, "[기믹] 안개의 전장 · 아테나의 등불")
				dio._stun_left = 99.0
				dio.global_position = dio.light_position() + Vector2(240, -150)
				await _frames(3)
				var hp73 := dio.hp
				dio.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(not dio.is_lit(dio.global_position) and hp73 - dio.hp == roundi(1000 * dio.fog_ratio) and dio.sprite.modulate.a < 0.5, "[기믹] 등불 밖 안개 속에서는 보이지 않고 공격이 빗맞음 (피해 %d%%)" % roundi(dio.fog_ratio * 100.0))
				dio.global_position = dio.light_position() + Vector2(30, 0)
				await _frames(3)
				hp73 = dio.hp
				dio.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp73 - dio.hp == 1000 and dio.sprite.modulate.a > 0.9, "등불 둘레에서는 드러나 피해가 그대로")
				player._invincible_left = 3.0
				player.global_position = dio.lamp.global_position
				await _frames(3)
				player.global_position = boss_center + Vector2(-150, 60)
				await _frames(2)
				_check(dio.lamp.is_carried() and dio.light_position().distance_to(player.global_position) < 40.0, "[기믹] 등불을 들고 다니면 그 둘레의 안개가 걷힘")
				dio._stun_left = 0.0
				var seen73 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen73["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen73["shot"] = true)
				_check(seen73["aoe"] and seen73["shot"], "디오메데스 패턴: 창 · 투창 · 바위 · 소환")
			74:
				var bel := boss as BossBellerophon
				await _survive(10)
				_check(bel.airborne and not bel.can_be_hit_by(Enemy.HitKind.MELEE) and bel.can_be_hit_by(Enemy.HitKind.BOW) and bel.bridle != null, "[기믹] 천마를 타고 하늘 높이 — 활만 닿음 · 황금 굴레")
				player._invincible_left = 3.0
				player.global_position = bel.bridle.global_position
				await _frames(3)
				_check(bel.bridle.is_carried(), "황금 굴레를 집어 듦")
				bel.global_position = player.global_position + Vector2(20, 0)
				await _frames(2)
				_check(bel.is_fallen() and not bel.airborne and bel.can_be_hit_by(Enemy.HitKind.MELEE) and bel.is_stunned() and bel.defense == bel._base_defense - bel.fall_defense,
						"[기믹] 굴레를 씌우면 페가수스가 길들여져 벨레로폰이 떨어짐 (근접도 통함 · 방어력 -%d)" % bel.fall_defense)
				bel._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen74 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen74["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen74["shot"] = true)
				_check(seen74["aoe"] and seen74["shot"], "벨레로폰 패턴: 창 · 급강하 · 날갯바람 · 소환")
			75:
				var aj := boss as BossAjax
				await _survive(10)
				aj._stun_left = 99.0
				var dir75 := aj.global_position.direction_to(player.global_position)
				aj.facing = dir75
				var hp75 := aj.hp
				var layer75 := aj.layer_hp
				aj.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(aj.hp == hp75 and aj.layer_hp == layer75 - 1000 and aj.layers == 7, "[기믹] 앞에서 때리면 본체 대신 소가죽 방패가 받음")
				aj.take_damage(aj.layer_hp + 10, Vector2.ZERO, false, 999999)
				_check(aj.layers == 6, "한 겹을 다 찢으면 남은 겹 6/7")
				aj.facing = -dir75
				hp75 = aj.hp
				aj.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp75 - aj.hp == 1000, "[기믹] 옆 · 뒤에서 때리면 그대로 본체로")
				aj.facing = dir75
				aj._brace_left = 1.0
				layer75 = aj.layer_hp
				aj.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(aj.layer_hp == layer75 and aj.hp == hp75 - 1000, "[기믹] 방패를 박고 버티는 동안은 앞쪽 공격이 통하지 않음")
				aj._brace_left = 0.0
				aj.layers = 1
				aj.layer_hp = 10
				aj.take_damage(100, Vector2.ZERO, false, 999999)
				_check(aj.layers == 0 and aj.defense == aj._base_defense - aj.bare_defense, "[기믹] 일곱 겹을 모두 찢으면 무방비 (방어력 -%d)" % aj.bare_defense)
				aj._stun_left = 0.0
				var seen75 := {"aoe": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen75["aoe"] = true)
				_check(seen75["aoe"], "아이아스 패턴: 창 · 버티기 · 바위 · 소환")
			76:
				var ody := boss as BossOdysseus
				await _survive(10)
				_check(ody.standing_axes() == 12, "[기믹] 열두 도끼가 일렬로 섬")
				_check(ody.shoot_through_axes(true) == 12, "[기믹] 도끼 줄을 따라 화살이 꿰뚫음 (12자리)")
				ody.axes[0].take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(ody.shoot_through_axes(true) == 0 and ody.shoot_through_axes(false) == 11, "[기믹] 끝의 도끼를 쓰러뜨리면 그쪽에서 쏜 화살이 막힘")
				ody.axes[5].take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(ody.shoot_through_axes(false) == 6, "가운데를 끊으면 끊긴 자리까지만 꿰뚫음")
				ody._restand_left = 0.01
				await _frames(3)
				_check(ody.standing_axes() == 12, "쓰러진 도끼는 잠시 뒤 다시 섬")
				ody.disguise()
				await _frames(3)
				_check(ody.is_disguised() and ody.sprite.texture == ody.beggar_texture and ody.decoys.size() == ody.decoy_count, "[기믹] 거지로 변장해 거지 %d명과 섞임" % ody.decoy_count)
				ody.take_damage(100, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not ody.is_disguised() and ody.is_stunned() and ody.get_reveal_count() == 1, "진짜를 때리면 정체가 드러나며 휘청")
				ody._stun_left = 0.0
				var seen76 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen76["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen76["shot"] = true)
				_check(seen76["aoe"] and seen76["shot"], "오디세우스 패턴: 열두 도끼 · 활 세례 · 변장 · 소환")
			77:
				var ty := boss as BossTydeus
				await _survive(10)
				ty._potion_left = 999.0
				ty._stun_left = 99.0
				ty.drop_potion(boss_center + Vector2(150, 100))
				await _frames(80)
				_check(ty.has_potion(), "[기믹] 아테나의 불사의 약병이 떨어짐")
				ty._stun_left = 0.0
				ty.global_position = ty.potion.global_position
				await _frames(2)
				_check(ty.get_drink_count() == 1 and ty.is_immortal() and not ty.has_potion(), "[기믹] 티데우스가 먼저 닿으면 약을 마셔 불사")
				var hp77 := ty.hp
				ty.take_damage(5000, Vector2.ZERO, false, 999999)
				_check(ty.hp == hp77, "불사 동안 피해 없음")
				ty._immortal_left = 0.0
				ty._stun_left = 99.0
				ty.drop_potion(boss_center + Vector2(-150, 100))
				await _frames(80)
				player._invincible_left = 2.0
				player.global_position = ty.potion.global_position
				await _frames(3)
				_check(ty.get_smash_count() == 1 and not ty.has_potion() and ty.get_drink_count() == 1, "[기믹] 플레이어가 먼저 닿으면 약병을 깨뜨림")
				ty._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen77 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					ty._potion_left = 999.0
					if _count_nodes_of("AoeStrike") > 0:
						seen77["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen77["shot"] = true)
				_check(seen77["aoe"] and seen77["shot"], "티데우스 패턴: 창 · 방패 밀치기 · 돌팔매 · 소환")
				ty._immortal_left = 0.0
			78:
				var gl := boss as BossGlaukos
				await _survive(10)
				_check(gl.pillars.size() == 5, "[기믹] 어둠 속 돌기둥 5개")
				gl._stun_left = 99.0
				var open78 := gl.global_position + Vector2(0, 90)
				for k in 16:
					var cand := gl.global_position + Vector2.from_angle(TAU * k / 16.0) * 90.0
					gl.gaze = gl.global_position.direction_to(cand)
					if gl.can_see(cand) and gl._area().has_point(cand):
						open78 = cand
						break
				player.global_position = open78
				gl.gaze = gl.global_position.direction_to(open78)
				await _survive(40, func() -> void:
					player._invincible_left = 1.0
					player.global_position = open78)
				_check(gl.is_player_marked() and gl.get_spotted_count() == 1, "[기믹] 올빼미의 시선에 걸리면 들켜 「표식」")
				gl._mark_left = 0.0
				gl._spot = 0.0
				gl.gaze = -gl.global_position.direction_to(player.global_position)
				var hp78 := gl.hp
				gl.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp78 - gl.hp == roundi(1000 * gl.ambush_multiplier) and gl.get_ambush_count() == 1 and gl.is_stunned(), "[기믹] 들키지 않은 채 때리면 기습 (피해 x%.1f · 휘청)" % gl.ambush_multiplier)
				var pil78 := gl.pillars[0]
				var behind := pil78.global_position + gl.global_position.direction_to(pil78.global_position) * 26.0
				gl.gaze = gl.global_position.direction_to(behind)
				_check(not gl.can_see(behind), "[기믹] 돌기둥 뒤에 숨으면 시선이 가려짐")
				gl._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen78 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen78["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen78["shot"] = true)
				_check(seen78["aoe"] and seen78["shot"], "글라우크스 패턴: 급강하 · 깃털 · 울음 · 소환")
			79:
				var stt := boss as BossBronzeStatue
				await _survive(10)
				stt._until_glow = 999.0
				stt._glow_left = 0.0
				var start79 := stt.global_position
				var at79 := stt.get_hit_center() + Vector2(-40, 0)
				var ps79 := ProjectileSpec.enemy_bullet(at79, Vector2.RIGHT, 1.0, 10, null)
				ps79.team = ProjectileSpec.Team.PLAYER
				pool.spawn(ps79)
				await _frames(3)
				_check(stt.get_reflect_count() == 0, "방패가 빛나지 않을 때는 원거리도 통함")
				stt.begin_glow()
				var ps79b := ProjectileSpec.enemy_bullet(at79, Vector2.RIGHT, 1.0, 10, null)
				ps79b.team = ProjectileSpec.Team.PLAYER
				pool.spawn(ps79b)
				await _frames(3)
				_check(stt.is_glowing() and stt.get_reflect_count() >= 1, "[기믹] 방패가 빛나면 화살 · 마법탄이 되받아쳐짐")
				_check(stt.global_position.distance_to(start79) < 1.0, "[기믹] 움직이지 않는 신상")
				var seen79 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen79["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen79["shot"] = true)
				_check(seen79["aoe"] and seen79["shot"], "청동 수호상 패턴: 창 휩쓸기 · 내지르기 · 청동 비 · 소환")
			80:
				var ath := boss as BossAthena
				await _survive(10)
				_check(ath.living_shields() == 6 and ath.board != null, "[기믹] 팔랑크스 방패병 6명 · 전략의 판")
				ath._stun_left = 99.0
				ath._reform_left = 999.0
				var slot80 := ath.slot_of(player.global_position)
				ath.insight.clear()
				var hp80 := ath.hp
				ath.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp80 - ath.hp == roundi(1000 * ath.wall_ratio), "[기믹] 방패병이 서 있는 쪽에서 때리면 방패벽 (피해 %d%%)" % roundi(ath.wall_ratio * 100.0))
				ath.shields[slot80].take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				ath.insight.clear()
				hp80 = ath.hp
				ath.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp80 - ath.hp == 1000 and ath.living_shields() == 5, "[기믹] 방패병을 쓰러뜨린 빈틈 쪽에서는 피해가 그대로")
				ath.insight.clear()
				for i in 5:
					ath.take_damage(1000, Vector2.ZERO, false, 999999)
				hp80 = ath.hp
				ath.take_damage(1000, Vector2.ZERO, false, 999999)
				var cut80 := hp80 - ath.hp
				_check(cut80 == roundi(1000 * (1.0 - ath.insight_step * 5)), "[기믹] 간파: 같은 무기로만 계속 때리면 피해가 줄어듦 (%d)" % cut80)
				var sword80 := GameManager.equipped_weapon
				var other80 := sword80.duplicate() as WeaponData
				other80.weapon_type = WeaponData.WeaponType.BOW if sword80.weapon_type != WeaponData.WeaponType.BOW else WeaponData.WeaponType.SWORD
				GameManager.equipped_weapon = other80
				hp80 = ath.hp
				ath.take_damage(1000, Vector2.ZERO, false, 999999)
				var fresh80 := hp80 - ath.hp
				GameManager.equipped_weapon = sword80
				_check(fresh80 == 1000 and int(ath.insight.get(sword80.weapon_type, 0)) == 4, "다른 무기로 때리면 그대로 들어가고 꿰뚫린 정도가 풀림")
				for i in 2:
					for s in ath.shields:
						if s != null and is_instance_valid(s) and not s.is_dead():
							s.take_damage(9999999, Vector2.ZERO, false, 999999)
							break
				await _frames(2)
				ath._reform_left = 0.01
				await _frames(3)
				_check(ath.living_shields() == 5, "[기믹] 진형을 다시 짜지만 인원이 한 명 줄어듦 (%d명)" % ath.living_shields())
				ath.board.plan(3, 5, 0.3, 0.2)
				(ath.board.moves[0]["cells"] as Array).append(ath.board.cell_of(player.global_position))
				player._invincible_left = 0.0
				for i in 60:
					_gm.hp = 9999
					await get_tree().physics_frame
				_gm.hp = _gm.max_hp
				_check(ath.get_strategy_hits() >= 1 and ath.board.moves.is_empty(), "[기믹] 전략의 수: 표시된 칸이 번호 순서대로 터짐")
				ath._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen80 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen80["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen80["shot"] = true)
				_check(seen80["aoe"] and seen80["shot"], "아테나 패턴: 지혜의 창 · 전략의 수 · 올빼미 깃 · 소환")
				for s in ath.shields:
					if s != null and is_instance_valid(s):
						s.take_damage(9999999, Vector2.ZERO, false, 999999)  # 마지막 일격이 방패벽에 막히지 않게
				ath.insight.clear()
				await _frames(2)
			81:
				var mam := boss as BossMammon
				await _survive(10)
				mam._pile_left = 999.0
				mam.scatter_piles([mam.global_position + Vector2(10, 0), boss_center + Vector2(-220, 110), boss_center + Vector2(220, 110)])
				await _frames(3)
				_check(mam.greed == 1 and mam.get_eaten_count() == 1 and mam.defense == mam._base_defense + mam.greed_defense and mam.power > mam._base_power, "[기믹] 마몬이 금화 더미를 먹으면 탐욕 +1 (몸집 · 방어력 · 공격력)")
				var gold81: int = _gm.gold
				player._invincible_left = 2.0
				player.global_position = mam.live_piles()[0].global_position
				await _frames(3)
				_check(mam.greed == 0 and _gm.gold == gold81 + mam.pile_gold and mam.get_stolen_count() == 1, "[기믹] 플레이어가 먼저 주우면 골드를 얻고 마몬의 탐욕 -1")
				player.global_position = boss_center + Vector2(0, 90)
				var seen81 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen81["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen81["shot"] = true)
				_check(seen81["aoe"] and seen81["shot"], "마몬 패턴: 금화 비 · 금화 자루 · 황금 탄막 · 소환")
			82:
				var bp := boss as BossBelphegor
				await _survive(10)
				player.global_position = bp.global_position + Vector2(0, 50)
				await _frames(3)
				_check(player.is_slowed() and _gm.player_status.contains("나태"), "[기믹] 나태의 오라 안에서는 느려짐")
				bp.take_damage(roundi(bp.max_hp * 0.2), Vector2.ZERO, false, 999999)
				bp.fall_asleep()
				var hp82 := bp.hp
				await _survive(60, func() -> void:
					player._invincible_left = 1.0)
				_check(bp.is_asleep() and bp.hp > hp82 and bp.get_healed_total() > 0, "[기믹] 깊은 잠에 빠지면 회복 (+%d)" % bp.get_healed_total())
				hp82 = bp.hp
				bp.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(not bp.is_asleep() and hp82 - bp.hp == roundi(1000 * bp.wake_multiplier) and bp.is_stunned(), "[기믹] 잠든 벨페고르를 때리면 깨어나며 휘청 (피해 x%.1f)" % bp.wake_multiplier)
				bp._stun_left = 0.0
				bp._idle = 0.0
				await _survive(int(bp.sleep_after * 60) + 10, func() -> void:
					player._invincible_left = 1.0)
				_check(bp.is_asleep() and bp.get_sleep_count() == 2, "공격받지 않으면 다시 잠듦")
				bp.take_damage(10, Vector2.ZERO, false, 999999)
				bp._stun_left = 0.0
				var seen82 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if bp.is_asleep():
						bp.take_damage(10, Vector2.ZERO, false, 999999)
					if _count_nodes_of("AoeStrike") > 0:
						seen82["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen82["shot"] = true)
				_check(seen82["aoe"] and seen82["shot"], "벨페고르 패턴: 하품 · 털썩 · 졸음 구슬 · 소환")
			83:
				var bz := boss as BossBeelzebub
				await _survive(10)
				_check(bz.swarm != null, "[기믹] 파리 떼가 플레이어를 따라다님")
				bz.swarm.global_position = player.global_position
				await _frames(2)
				_check(player.is_slowed() and _gm.player_status.contains("파리"), "파리 떼 안에서는 시야가 가려지고 느려짐")
				bz._devour_left = 999.0
				for e in get_tree().get_nodes_in_group(&"enemies"):
					if e != bz:
						(e as Enemy).despawn()
				var food := (load("res://scenes/enemies/maggot.tscn") as PackedScene).instantiate() as Enemy
				stage._add_enemy(food, bz.global_position + Vector2(30, 0), stage.boss_room.get_arena_rect())
				await _frames(3)
				bz.take_damage(roundi(bz.max_hp * 0.1), Vector2.ZERO, false, 999999)
				var hp83 := bz.hp
				var pow83 := bz.power
				_check(bz.devour() and bz.feasts == 1 and bz.hp > hp83 and bz.power > pow83, "[기믹] 폭식: 졸개를 잡아먹어 회복하고 강해짐")
				await _frames(2)
				_check(not bz.devour(), "먹을 졸개가 없으면 잡아먹지 못함")
				bz.global_position = boss_center
				player.global_position = boss_center + Vector2(0, 90)
				var seen83 := {"aoe": false, "shot": false}
				bz.cast(BossBeelzebub.Pattern.MAGGOTS)  # 탄막 패턴은 순서상 늦게 나옴
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					player.global_position = bz.global_position + Vector2(0, 90)  # 보스가 플레이어 위에 겹치면 탄이 쏘자마자 맞아 사라짐
					if _count_nodes_of("AoeStrike") > 0:
						seen83["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen83["shot"] = true)
				_check(seen83["aoe"] and seen83["shot"], "바알제붑 패턴: 토사물 · 날갯짓 · 구더기 · 소환")
			84:
				var asm := boss as BossAsmodeus
				await _survive(10)
				_check(asm.get_pillars().size() == 3 and asm.is_chained(), "[기믹] 욕망의 사슬 — 사슬 기둥 3개")
				asm._stun_left = 99.0
				var dir84 := Vector2.RIGHT if asm.global_position.x < boss_center.x else Vector2.LEFT
				player._invincible_left = 2.0
				player.global_position = asm.global_position + dir84 * (asm.tether() + 70.0)
				await _frames(1)
				var d84 := asm.global_position.distance_to(player.global_position)
				await _frames(8)
				_check(d84 > asm.tether() and asm.get_pull_count() > 0 and asm.global_position.distance_to(player.global_position) < d84, "[기믹] 사슬 길이보다 멀어지면 끌려감")
				for p in asm.get_pillars():
					p.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not asm.is_chained() and asm.is_stunned(), "[기믹] 사슬 기둥을 모두 부수면 사슬이 끊어지고 휘청")
				asm._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen84 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					player._charm_left = 0.0
					if _count_nodes_of("AoeStrike") > 0:
						seen84["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen84["shot"] = true)
				_check(seen84["aoe"] and seen84["shot"], "아스모데우스 패턴: 사슬 채찍 · 매혹의 입맞춤 · 욕망의 불꽃 · 소환")
			85:
				var hm := boss as BossHorsemen
				await _survive(10)
				_check(hm.rider == BossHorsemen.Rider.CONQUEST and hm.sprite.texture == BossHorsemen.RIDER_TEXTURES[0], "[기믹] 흰 말의 기사 「정복」부터")
				hm.take_damage(roundi(hm.max_hp * 0.27), Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(hm.rider == BossHorsemen.Rider.WAR and hm.sprite.texture == BossHorsemen.RIDER_TEXTURES[1], "[기믹] 체력이 1/4 깎일 때마다 다음 기사로 교대 (붉은 말 「전쟁」)")
				var hp85 := hm.hp
				hm.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hm.hp == hp85, "기사가 바뀌는 동안은 무적")
				hm._swap_left = 0.0
				hm.take_damage(roundi(hm.max_hp * 0.25), Vector2.ZERO, false, 999999)
				_check(hm.rider == BossHorsemen.Rider.FAMINE, "검은 말 「기근」")
				hm._swap_left = 0.0
				hm.take_damage(roundi(hm.max_hp * 0.25), Vector2.ZERO, false, 999999)
				await _survive(int(1.3 * 60) + 6, func() -> void:
					player._invincible_left = 1.0)
				_check(hm.rider == BossHorsemen.Rider.DEATH and hm.is_reviving(), "[기믹] 창백한 말 「죽음」이 쓰러진 기사들을 되살리려 의식을 올림")
				hm.take_damage(roundi(hm.max_hp * hm.revive_break) + 10, Vector2.ZERO, false, 999999)
				_check(not hm.is_reviving() and hm.get_interrupt_count() == 1 and hm.is_stunned(), "[기믹] 의식 동안 크게 몰아치면 의식이 끊기며 휘청")
				hm._stun_left = 0.0
				var seen85 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen85["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen85["shot"] = true)
				_check(seen85["aoe"] and seen85["shot"], "네 기사 패턴: 기사마다 다른 공격 · 소환")
			86:
				var fp := boss as BossFalseProphet
				await _survive(10)
				fp.mark_player()
				var hp86 := fp.hp
				fp.take_damage(1000, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(fp.is_player_marked() and fp.hp == hp86 and _gm.player_status.contains("짐승의 표"), "[기믹] 짐승의 표가 찍히면 공격이 들어가지 않음")
				player._invincible_left = 2.0
				player.global_position = fp.springs[0].global_position
				await _frames(3)
				_check(not fp.is_player_marked() and fp.get_cleanse_count() == 1, "[기믹] 정화의 샘에 들어가면 표가 씻겨 나감")
				hp86 = fp.hp
				fp.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp86 - fp.hp == 1000, "표를 씻으면 다시 공격이 들어감")
				player.global_position = boss_center + Vector2(0, 90)
				var seen86 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					fp._mark_left = 0.0
					if _count_nodes_of("AoeStrike") > 0:
						seen86["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen86["shot"] = true)
				_check(seen86["aoe"] and seen86["shot"], "거짓 예언자 패턴: 하늘의 불 · 짐승의 표 · 거짓말 탄막 · 소환")
				fp._mark_left = 0.0
			87:
				var az := boss as BossAzazel
				await _survive(10)
				_check(az.has_goat() and az.gate != null, "[기믹] 속죄양(검은 염소) · 광야의 문")
				var hp87 := az.hp
				az.take_damage(10000, Vector2.ZERO, false, 999999)
				var kept87 := roundi(10000 * az.shield_ratio)
				_check(hp87 - az.hp == kept87 and az.goat.sins == 10000 - kept87, "[기믹] 속죄양이 피해를 떠안음 (본체 %d%%만)" % roundi(az.shield_ratio * 100.0))
				hp87 = az.hp
				player.global_position = boss_center + Vector2(0, 120)
				az.goat.global_position = az.gate_position()
				await _frames(3)
				_check(not az.has_goat() and az.get_exile_count() == 1 and hp87 - az.hp == 10000 - kept87 and az.is_stunned(), "[기믹] 염소를 광야의 문으로 몰아내면 떠안은 죄가 한꺼번에 아자젤에게")
				az._goat_left = 0.01
				await _frames(3)
				_check(az.has_goat(), "염소는 잠시 뒤 다시 나타남")
				az._stun_left = 0.0
				var seen87 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen87["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen87["shot"] = true)
				_check(seen87["aoe"] and seen87["shot"], "아자젤 패턴: 칼날 · 모래 폭풍 · 검은 날개 · 소환")
				az.exile_goat()
				az._goat_left = 999.0
			88:
				var fs := boss as BossFallenStar
				await _survive(10)
				_check(fs.is_gate_open() and fs.holds_key(), "[기믹] 무저갱의 문이 열려 있고 별이 열쇠를 쥠")
				var n88 := get_tree().get_nodes_in_group(&"enemies").size()
				fs._crawl_left = 0.01
				await _frames(3)
				_check(get_tree().get_nodes_in_group(&"enemies").size() > n88, "열린 문에서 졸개가 기어 나옴")
				fs.key_part.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(3)
				_check(not fs.holds_key() and fs.dropped_key != null and fs.dropped_key.available, "[기믹] 별이 쥔 열쇠를 부수면 바닥에 떨어짐")
				player._invincible_left = 3.0
				player.global_position = fs.dropped_key.global_position
				await _frames(3)
				_check(fs.dropped_key.is_carried(), "열쇠를 집어 듦")
				player.global_position = fs.gate_position()
				await _frames(3)
				_check(not fs.is_gate_open() and fs.is_stunned() and fs.defense == fs._base_defense - fs.close_defense, "[기믹] 열쇠를 문으로 가져가면 무저갱의 문이 닫힘 (휘청 · 방어력 -%d)" % fs.close_defense)
				fs._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen88 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen88["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen88["shot"] = true)
				_check(seen88["aoe"] and seen88["shot"], "타락한 별 패턴: 별빛 · 연기 · 열쇠 휘두르기 · 소환")
			89:
				var ta := boss as BossTrumpetAngel
				await _survive(10)
				player._invincible_left = 5.0
				_check(ta.has_trumpet() and ta.next_plague == BossTrumpetAngel.Plague.HAIL, "[기믹] 천사의 나팔 · 첫 재앙 「우박과 불」")
				_check(ta.blow_trumpet() and ta.next_plague == BossTrumpetAngel.Plague.BLOOD_SEA, "나팔을 불면 순서대로 재앙이 내림 (① 우박과 불)")
				var zones89 := get_tree().get_nodes_in_group(&"hostile_zones").size()
				ta.blow_trumpet()
				_check(get_tree().get_nodes_in_group(&"hostile_zones").size() > zones89, "② 피로 물든 바다")
				ta.blow_trumpet()
				ta.blow_trumpet()
				_check(ta.is_dark() and ta.veil != null, "④ 어두워진 해 — 시야가 좁아짐")
				var e89 := get_tree().get_nodes_in_group(&"enemies").size()
				ta.blow_trumpet()
				await _frames(3)
				_check(get_tree().get_nodes_in_group(&"enemies").size() >= e89 + 3 and ta.next_plague == BossTrumpetAngel.Plague.HAIL, "⑤ 무저갱 — 메뚜기가 기어 나오고 재앙이 처음으로 돌아감")
				ta.trumpet.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not ta.has_trumpet() and ta.get_skipped_count() == 1 and ta.next_plague == BossTrumpetAngel.Plague.BLOOD_SEA and not ta.blow_trumpet(), "[기믹] 나팔을 부수면 다음 재앙(우박과 불)이 끊기고 휘청")
				ta._regrow_left = 0.01
				await _frames(3)
				_check(ta.has_trumpet(), "나팔은 잠시 뒤 다시 듦")
				ta._stun_left = 0.0
				_gm.hp = _gm.max_hp
				ta.global_position = boss_center
				player.global_position = boss_center + Vector2(0, 90)
				var seen89 := {"aoe": false, "shot": false}
				ta.cast(BossTrumpetAngel.Pattern.FEATHER)  # 탄막 패턴은 순서상 늦게 나옴
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					player.global_position = ta.global_position + Vector2(0, 90)  # 보스가 플레이어 위에 겹치면 탄이 쏘자마자 맞아 사라짐
					if _count_nodes_of("AoeStrike") > 0:
						seen89["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen89["shot"] = true)
				_check(seen89["aoe"] and seen89["shot"], "나팔 천사 패턴: 나팔 · 빛의 창 · 합창 · 깃털")
			90:
				var ab := boss as BossAbaddon
				await _survive(10)
				_check(ab.is_seated() and ab.throne != null and not ab.can_be_hit_by(Enemy.HitKind.MELEE), "[등장] 마왕 아바돈이 옥좌에 앉아 있음 (무적)")
				var hp90 := ab.hp
				ab.take_damage(5000, Vector2.ZERO, false, 999999)
				_check(ab.hp == hp90, "옥좌에 앉아 있는 동안 피해 없음")
				await _survive(int(ab.intro_time * 60) + 10, func() -> void:
					player._invincible_left = 1.0)
				_check(not ab.is_seated() and ab.pit != null and ab.can_be_hit_by(Enemy.HitKind.MELEE), "[등장] 잠시 뒤 옥좌에서 일어나며 싸움이 시작됨 · 무저갱이 열림")
				var r90 := ab.pit.radius
				await _survive(60, func() -> void:
					player._invincible_left = 1.0
					player.global_position = boss_center + Vector2(200, 120))
				_check(ab.pit.radius > r90, "[기믹] 바닥 없는 구덩이가 점점 넓어짐 (%.0f → %.0f)" % [r90, ab.pit.radius])
				player._invincible_left = 0.0
				var falls90 := ab.get_fall_count()
				player.global_position = ab.pit.global_position
				await _frames(3)
				_check(ab.get_fall_count() == falls90 + 1 and not ab.pit.contains(player.global_position), "[기믹] 구덩이에 빠지면 큰 피해를 입고 가장자리로 튕겨 나옴")
				_gm.hp = _gm.max_hp
				_check(ab.current_sin == BossAbaddon.Sin.GREED and ab.coins.size() == 4, "[기믹] 일곱 대죄의 힘 — 「탐욕」: 금화 더미 쟁탈")
				ab._sin_left = 999.0
				ab.next_sin()
				ab._sin_left = 999.0
				player._invincible_left = 2.0
				player.global_position = ab.global_position + Vector2(40, 0)
				await _frames(3)
				_check(ab.current_sin == BossAbaddon.Sin.SLOTH and player.is_slowed(), "「나태」: 느려지는 오라")
				ab.next_sin()
				ab._sin_left = 999.0
				var food90 := (load("res://scenes/enemies/hell_wraith.tscn") as PackedScene).instantiate() as Enemy
				stage._add_enemy(food90, ab.global_position + Vector2(40, 20), stage.boss_room.get_arena_rect())
				await _frames(2)
				ab._sin_tick = 0.0
				await _frames(3)
				_check(ab.current_sin == BossAbaddon.Sin.GLUTTONY and food90.is_dead(), "「폭식」: 졸개를 잡아먹음")
				ab.next_sin()
				ab._sin_left = 999.0
				var dir90 := Vector2.RIGHT if ab.global_position.x < boss_center.x else Vector2.LEFT
				player.global_position = ab.global_position + dir90 * 230.0
				await _frames(1)
				var d90 := ab.global_position.distance_to(player.global_position)
				await _frames(6)
				_check(ab.current_sin == BossAbaddon.Sin.LUST and ab.global_position.distance_to(player.global_position) < d90, "「색욕」: 사슬로 끌어당김")
				ab.take_damage(ab.hp - roundi(ab.max_hp * 0.45), Vector2.ZERO, false, 999999)
				await _frames(3)
				_check(ab.phase_two and ab.veil != null, "[기믹] 체력 50% 이하 — 파괴자 아폴리온 각성 · 무저갱의 연기")
				ab._ground_left = 0.01
				await _frames(3)
				_check(ab.is_flying() and ab.airborne and not ab.can_be_hit_by(Enemy.HitKind.MELEE) and ab.can_be_hit_by(Enemy.HitKind.BOW), "아폴리온이 날아오르면 활만 닿음")
				player.global_position = boss_center + Vector2(-200, 120)
				var seen90 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen90["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen90["shot"] = true)
				_check(seen90["aoe"] and seen90["shot"], "아바돈 패턴: 전갈 꼬리 · 지옥불 · 무저갱 탄막 · 소환")
			91:
				var ch := boss as BossCherubim
				await _survive(10)
				ch._face_left = 999.0
				player._invincible_left = 2.0
				var hd91 := ch.human_direction()
				player.global_position = ch.get_hit_center() + hd91 * 70.0
				await _frames(1)
				_check(ch.face_toward(player.global_position) == BossCherubim.Face.MAN, "[기믹] 네 얼굴 — 사람 얼굴이 바라보는 쪽")
				var hp91 := ch.hp
				ch.take_damage(1000, Vector2.ZERO, false, 999999)
				var full91 := hp91 - ch.hp
				player.global_position = ch.get_hit_center() - hd91 * 70.0
				await _frames(1)
				hp91 = ch.hp
				ch.take_damage(1000, Vector2.ZERO, false, 999999)
				var side91 := hp91 - ch.hp
				_check(full91 >= 900 and side91 > 0 and side91 <= roundi(full91 * 0.35) and ch.get_guarded_count() >= 1, "[기믹] 사람 얼굴 쪽에서만 피해가 제대로 들어감 (%d / 다른 얼굴 %d)" % [full91, side91])
				var off91 := ch.face_offset
				ch._face_left = 0.01
				await _frames(2)
				_check(ch.face_offset == (off91 + 1) % 4, "[기믹] 얼굴이 한 칸씩 돌아감")
				ch._face_left = 999.0
				ch.sword_angle = 0.0
				ch._sword_cd = 0.0
				var hits91 := ch.get_sword_hits()
				player._invincible_left = 0.0
				player.global_position = ch.get_hit_center() + Vector2(90, 0)
				for i in 3:
					_gm.hp = 9999
					await get_tree().physics_frame
				_gm.hp = _gm.max_hp
				_check(ch.get_sword_hits() > hits91, "[기믹] 두루 도는 불칼에 닿으면 큰 피해")
				player.global_position = boss_center + Vector2(0, 90)
				for k in 4:
					if ch.face_toward(player.global_position) != BossCherubim.Face.EAGLE:
						ch.rotate_faces()
				ch.cast(BossCherubim.Pattern.FACE)  # 독수리 얼굴: 깃털 탄막
				var seen91 := {"aoe": false, "shot": false, "t": 0}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					seen91["t"] += 1
					player.global_position = ch.get_hit_center() + Vector2(0, 90)  # 보스가 플레이어 위에 겹치면 탄이 쏘자마자 맞아 사라짐
					if seen91["t"] % 100 == 0:
						ch.rotate_faces()  # 얼굴마다 다른 공격이 나오게
					if _count_nodes_of("AoeStrike") > 0:
						seen91["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen91["shot"] = true)
				_check(seen91["aoe"] and seen91["shot"], "케루빔 패턴: 얼굴마다 다른 공격 · 날개 바람 · 소환")
				ch._face_left = 999.0
				player.global_position = ch.get_hit_center() + ch.human_direction() * 60.0  # 마지막 일격은 사람 얼굴 쪽에서
				await _frames(1)
			92:
				var op := boss as BossOphanim
				await _survive(20)
				_check(op.has_wheel() and not op.is_meshed(), "[기믹] 둘째 바퀴가 따로 굴러다님")
				op._mesh_left = 999.0
				var hp92 := op.hp
				var eyes92 := op.open_eyes()
				op.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp92 - op.hp <= 200 and op.open_eyes() == eyes92 - 1, "[기믹] 바퀴가 떨어져 있으면 피해 15%% · 때린 자리의 눈이 감김 (%d)" % (hp92 - op.hp))
				op.begin_mesh()
				await _frames(2)
				hp92 = op.hp
				op.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(op.is_meshed() and hp92 - op.hp >= 900, "[기믹] 두 바퀴가 맞물리면 피해가 제대로 들어감")
				hp92 = op.hp
				await _frames(1)
				op.take_damage(1000, Vector2.ZERO, false, 999999)
				op.wheel.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp92 - op.hp <= 1100, "같은 공격이 본체와 둘째 바퀴에 함께 닿아도 한 번만")
				op._mesh_left = 0.01
				await _frames(2)
				_check(not op.is_meshed() and op.get_mesh_count() == 1, "맞물림이 풀림")
				op._mesh_left = 0.01
				await _survive(200, func() -> void:
					player._invincible_left = 1.0)
				_check(op.get_mesh_count() == 2, "[기믹] 주기마다 둘째 바퀴가 굴러와 다시 맞물림")
				op._mesh_left = 0.01
				await _frames(2)
				player.global_position = boss_center + Vector2(0, 90)
				var seen92 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen92["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen92["shot"] = true)
				_check(seen92["aoe"], "오파님 패턴: 눈들의 빛줄기 · 불바퀴 구르기 · 바퀴 테 · 소환")
				op.begin_mesh()
				op._mesh_left = 999.0
			93:
				var gs := boss as BossGoldStatue
				await _survive(20)
				_check(gs.sections.size() == 4 and gs.living_feet().size() == 2, "[기믹] 금 · 은 · 놋 · 철 부위 + 진흙 발 둘")
				gs._stone_left = 999.0
				var hp93 := gs.hp
				gs.sections[0].take_damage(1000, Vector2.ZERO, false, 999999)
				var head93 := hp93 - gs.hp
				await _frames(1)
				hp93 = gs.hp
				gs.sections[3].take_damage(1000, Vector2.ZERO, false, 999999)
				var legs93 := hp93 - gs.hp
				_check(head93 > 0 and legs93 > head93 * 2, "[기믹] 부위마다 단단함이 다름 (금 머리 %d · 철 다리 %d)" % [head93, legs93])
				await _frames(1)
				hp93 = gs.hp
				gs.sections[0].take_damage(1000, Vector2.ZERO, false, 999999)
				gs.sections[3].take_damage(1000, Vector2.ZERO, false, 999999)
				gs.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(absi(hp93 - gs.hp - legs93) <= 2, "한 공격이 여러 부위에 닿으면 가장 무른 부위 하나만 셈 (%d)" % (hp93 - gs.hp))
				for f in gs.living_feet():
					f.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(gs.is_collapsed() and gs.get_collapse_count() == 1 and gs.is_stunned(), "[기믹] 진흙 발 둘을 깨면 신상이 무너짐")
				await _frames(1)
				hp93 = gs.hp
				gs.sections[3].take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp93 - gs.hp >= 1150, "무너진 동안 피해 x1.6 (%d)" % (hp93 - gs.hp))
				gs._collapse_left = 0.01
				await _frames(2)
				gs._regrow_left = 0.01
				await _frames(4)
				_check(gs.living_feet().size() == 2 and not gs.is_collapsed(), "진흙 발이 다시 붙음")
				var hits93 := gs.get_stone_hits()
				gs._stun_left = 3.0
				player.global_position = boss_center + Vector2(0, 150)
				gs.roll_stone(gs.global_position + Vector2(-300, -16), gs.global_position + Vector2(300, -16), 0.2)
				await _survive(150, func() -> void:
					player._invincible_left = 1.0)
				_check(gs.get_stone_hits() == hits93 + 1 and gs.is_collapsed(), "[기믹] 뜨인 돌이 신상을 치면 발이 깨지고 신상이 무너짐")
				gs._collapse_left = 0.01
				gs._stun_left = 0.0
				await _frames(2)
				gs._regrow_left = 999.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen93 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen93["aoe"] = true)
				_check(seen93["aoe"], "금 신상 패턴: 금 머리의 빛줄기 · 은 팔 · 놋 배의 울림 · 소환")
				gs.collapse()
			94:
				var gl := boss as BossGoliath
				await _survive(20)
				_check(gl.brook != null and gl.stones.size() == gl.stone_count and gl.has_shieldbearer(), "[기믹] 시냇가의 매끄러운 돌 5개 · 방패 든 자")
				var hp94 := gl.hp
				gl.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp94 - gl.hp <= 520, "[기믹] 비늘 갑옷: 몸통 피해 절반 (%d)" % (hp94 - gl.hp))
				player._invincible_left = 3.0
				player.global_position = gl.stones[0].global_position
				await _frames(3)
				_check(gl.carried_stone() != null, "시냇돌을 집어 듦")
				player.global_position = gl.global_position + Vector2(0, 120)
				await _frames(1)
				var aim94 := (gl.head_position() - (player.global_position + Vector2(0, -10))).normalized()
				_check(not gl.throw_stone(aim94) and gl.get_blocked_count() == 1, "[기믹] 방패 든 자가 살아 있으면 돌이 방패에 막힘")
				gl.shieldbearer.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(not gl.has_shieldbearer(), "방패 든 자를 쓰러뜨림")
				player._invincible_left = 3.0
				player.global_position = gl.stones[1].global_position
				await _frames(3)
				player.global_position = gl.global_position + Vector2(0, 120)
				await _frames(1)
				hp94 = gl.hp
				aim94 = (gl.head_position() - (player.global_position + Vector2(0, -10))).normalized()
				_check(gl.throw_stone(aim94) and gl.is_stunned() and gl.get_head_hits() == 1 and hp94 - gl.hp >= roundi(gl.max_hp * 0.035), "[기믹] 물맷돌이 이마에 맞으면 크게 기절 + 큰 피해")
				hp94 = gl.hp
				gl.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp94 - gl.hp >= 900, "기절한 동안은 갑옷이 통하지 않음")
				player._invincible_left = 3.0
				player.global_position = gl.stones[2].global_position
				await _frames(3)
				_check(not gl.throw_stone(Vector2.DOWN) and gl.get_miss_count() == 1, "엉뚱한 쪽으로 던지면 빗나감")
				player.global_position = gl.stones[3].global_position
				await _frames(3)
				player.attacked.emit()
				_check(gl.carried_stone() == null and gl.get_miss_count() + gl.get_head_hits() + gl.get_blocked_count() == 4, "돌을 든 채 공격하면 조준한 쪽으로 돌을 던짐")
				player.global_position = gl.stones[4].global_position
				await _frames(3)
				gl.throw_stone(Vector2.DOWN)
				_check(gl._respawn_left > 0.0, "돌을 다 쓰면 잠시 뒤 다시 생김")
				gl._respawn_left = 0.01
				gl._shield_left = 0.01
				await _frames(4)
				_check(gl._stones_left() == gl.stone_count and gl.has_shieldbearer(), "시냇돌이 다시 생기고 방패 든 자가 돌아옴")
				gl._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen94 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen94["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen94["shot"] = true)
				_check(seen94["aoe"] and seen94["shot"], "골리앗 패턴: 창 · 땅 구르기 · 단창 · 조롱")
			95:
				var jc := boss as BossJerichoCaptain
				await _survive(20)
				_check(jc.is_walled() and jc.wall != null and jc.living_archers().size() == 4, "[기믹] 성벽 위의 수비대장 · 궁수 4명")
				var hp95 := jc.hp
				jc.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp95 - jc.hp <= 220, "[기믹] 성벽이 서 있는 동안 피해 20%% (%d)" % (hp95 - jc.hp))
				var c95 := jc.center
				player.global_position = c95 + Vector2(150, 0)
				await _frames(2)
				jc._lap_progress = 0.0  # 순간이동으로 건너뛴 각도는 빼고
				for i in 66:
					player.global_position = c95 + Vector2.from_angle(TAU * (i + 1) / 64.0) * 150.0
					player._invincible_left = 1.0
					_gm.hp = _gm.max_hp
					await get_tree().physics_frame
				_check(jc.laps == 1 and jc.wall.cracks == 1, "[기믹] 성벽 바깥 길을 한 바퀴 돌면 성벽에 금이 감")
				for i in 20:
					player.global_position = c95 + Vector2.from_angle(TAU * (i + 3) / 64.0) * 150.0
					player._invincible_left = 1.0
					await get_tree().physics_frame
				player.global_position = c95 + Vector2(70, 20)
				await _frames(2)
				_check(jc._lap_progress == 0.0 and jc.laps == 1, "행진 길 안쪽으로 들어서면 이번 바퀴는 처음부터")
				for i in 5:
					jc.add_lap()
				_check(jc.laps == 6 and jc.is_walled(), "여섯 바퀴까지는 성벽이 버팀")
				jc.add_lap()
				await _frames(3)
				_check(not jc.is_walled() and jc.living_archers().is_empty() and jc.wall.collapsed and jc.is_stunned(), "[기믹] 일곱 바퀴 — 성벽이 무너지고 수비대장이 떨어짐")
				hp95 = jc.hp
				jc.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp95 - jc.hp >= 900, "성벽이 무너진 뒤로는 피해가 그대로")
				jc._stun_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen95 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen95["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen95["shot"] = true)
				_check(seen95["aoe"] and seen95["shot"], "수비대장 패턴: 화살 비 · 끓는 기름 · 돌 던지기 · 소환")
			96:
				var nk := boss as BossNephilimKing
				await _survive(10)
				_check(nk.flood != null and nk.flood.planks.size() == 4 and nk.flood_state == BossNephilimKing.Flood.DRY, "[기믹] 방주의 판자 4개 · 아직 마른 땅")
				nk.start_flood()
				nk._state_left = 0.01
				await _frames(3)
				_check(nk.flood_state == BossNephilimKing.Flood.HIGH and nk.water_level() == 1.0, "[기믹] 물이 차올라 홍수")
				var wet96 := boss_center
				for k in 12:
					wet96 = boss_center + Vector2.from_angle(TAU * k / 12.0) * 60.0
					if not nk.flood.is_on_plank(wet96):
						break
				player._invincible_left = 0.0
				var drown96 := nk.get_drown_ticks()
				for i in 60:
					_gm.hp = 9999
					player.global_position = wet96
					await get_tree().physics_frame
				_gm.hp = _gm.max_hp
				_check(nk.get_drown_ticks() > drown96 and player.is_slowed(), "[기믹] 판자 밖에서는 물에 잠겨 느려지고 피해")
				drown96 = nk.get_drown_ticks()
				for i in 60:
					_gm.hp = 9999
					player.global_position = nk.flood.planks[0]
					await get_tree().physics_frame
				_gm.hp = _gm.max_hp
				_check(nk.get_drown_ticks() == drown96, "[기믹] 방주의 판자 위에서는 안전")
				var hp96 := nk.hp
				nk.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp96 - nk.hp <= 620, "[기믹] 물속을 걷는 네피림 왕 — 피해 60%")
				nk._state_left = 0.01
				await _frames(2)
				nk._state_left = 0.01
				await _frames(3)
				_check(nk.is_stuck_in_mud() and nk.flood_state == BossNephilimKing.Flood.DRY and nk.water_level() == 0.0 and nk.is_stunned(), "[기믹] 물이 빠지면 진흙에 발이 빠져 기절")
				hp96 = nk.hp
				nk.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(hp96 - nk.hp >= 1400, "진흙에 빠진 동안 피해 1.5배")
				nk._mud_left = 0.0
				nk._stun_left = 0.0
				nk._state_left = 999.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen96 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen96["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen96["shot"] = true)
				_check(seen96["aoe"] and seen96["shot"], "네피림 왕 패턴: 내려치기 · 물결 · 바위 · 소환")
			97:
				var bpr := boss as BossBaalProphet
				await _survive(10)
				_check(bpr.baal_altar != null and bpr.elijah_altar != null and bpr.jar != null, "[기믹] 바알의 제단 · 엘리야의 제단 · 우물의 물동이")
				bpr._dance_cd = 999.0
				player._invincible_left = 3.0
				player.global_position = bpr.jar.global_position
				await _frames(3)
				_check(bpr.jar.is_carried(), "물동이를 듦")
				player.global_position = bpr.elijah_position()
				await _frames(3)
				_check(bpr.pours == 1 and not bpr.jar.is_carried(), "[기믹] 엘리야의 제단에 물을 부음 (1/3)")
				bpr.pour_water()
				var hp97 := bpr.hp
				bpr.pour_water()
				await _frames(2)
				_check(bpr.get_fire_count() == 1 and bpr.pours == 0 and hp97 - bpr.hp >= roundi(bpr.max_hp * 0.09) and bpr.is_stunned(), "[기믹] 세 번 부으면 하늘에서 불이 내려 큰 피해 + 휘청")
				bpr._stun_left = 0.0
				var pow97 := bpr.power
				bpr.begin_dance()
				await _frames(4)
				_check(bpr.is_dancing() and bpr.living_dancers().size() == bpr.dancer_count and bpr.power > pow97, "[기믹] 바알의 춤: 춤꾼마다 공격력 상승")
				bpr.take_damage(roundi(bpr.max_hp * 0.05), Vector2.ZERO, false, 999999)
				var hp97b := bpr.hp
				await _survive(60, func() -> void:
					player._invincible_left = 1.0)
				_check(bpr.hp > hp97b, "춤추는 동안 대예언자가 회복함")
				for d in bpr.living_dancers():
					d.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(3)
				_check(not bpr.is_dancing() and is_equal_approx(bpr.power, pow97), "[기믹] 춤꾼을 모두 쓰러뜨리면 춤이 끊김")
				bpr._dance_cd = 999.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen97 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen97["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen97["shot"] = true)
				_check(seen97["aoe"] and seen97["shot"], "바알 대예언자 패턴: 외침 · 칼과 창 · 황소 뿔 · 소환")
			98:
				var rp := boss as BossRaphael
				await _survive(10)
				_check(rp.springs.size() == 2 and rp.stone != null, "[기믹] 치유의 샘 둘 · 넓적한 돌")
				rp._fish_left = 999.0
				rp.take_damage(roundi(rp.max_hp * 0.2), Vector2.ZERO, false, 999999)
				await _frames(2)
				_check(rp.mode == BossRaphael.Mode.FLYING, "[기믹] 체력이 깎이면 치유의 샘으로 날아감")
				rp.global_position = rp.spring_position(rp._heal_spring)
				await _frames(3)
				var hp98 := rp.hp
				await _survive(60, func() -> void:
					player._invincible_left = 1.0)
				_check(rp.is_healing() and rp.hp > hp98 and rp.get_healed() > 0, "샘에서 회복함")
				rp.burn_fish(rp.global_position)
				hp98 = rp.hp
				await _survive(60, func() -> void:
					player._invincible_left = 1.0)
				_check(rp.hp == hp98 and rp.get_heal_blocked() >= 1, "[기믹] 토비아의 물고기 쓸개 연기 안에서는 치유가 끊김")
				var spring98 := rp._heal_spring
				player._invincible_left = 3.0
				player.global_position = rp.stone.global_position
				await _frames(3)
				_check(rp.stone.is_carried(), "넓적한 돌을 듦")
				player.global_position = rp.spring_position(spring98)
				await _frames(3)
				_check(rp.is_sealed(spring98) and rp.mode == BossRaphael.Mode.FIGHT and rp.is_stunned(), "[기믹] 회복 중인 샘을 돌로 덮으면 회복이 끊기고 휘청")
				rp.seal_spring(1 - spring98)
				rp._stun_left = 0.0
				rp.seek_spring()
				_check(rp.mode == BossRaphael.Mode.FIGHT and rp.is_stunned(), "[기믹] 샘이 모두 덮여 있으면 갈 곳을 잃고 휘청")
				rp._smoke_left = 0.0
				rp._spawn_fish()
				await _frames(2)
				player.global_position = rp.fish.global_position
				await _frames(3)
				_check(rp._smoke_left > 0.0 and rp.in_smoke(player.global_position), "[기믹] 토비아의 물고기를 주우면 그 자리에 쓸개 연기")
				rp._stun_left = 0.0
				rp._smoke_left = 0.0
				rp._next_heal_hp = -999999
				player.global_position = boss_center + Vector2(0, 90)
				var seen98 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen98["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen98["shot"] = true)
				_check(seen98["aoe"] and seen98["shot"], "라파엘 패턴: 순례자의 지팡이 · 치유의 고리 · 깃털 · 소환")
			99:
				var mc := boss as BossMichael
				await _survive(10)
				_check(mc.dragon != null, "[기믹] 붉은 용이 보스방 둘레를 낢")
				mc._breath_left = 999.0
				mc._shield_cd = 999.0
				player.global_position = boss_center + Vector2(0, 150)
				mc._stun_left = 3.0
				var hp99 := mc.hp
				mc.breathe_at(mc.get_hit_center(), 0.3)
				await _survive(40, func() -> void:
					player._invincible_left = 1.0)
				_check(mc.get_dragon_hits() == 1 and hp99 - mc.hp >= roundi(mc.max_hp * 0.03), "[기믹] 붉은 용의 불길이 미카엘을 덮치면 큰 피해")
				mc._stun_left = 0.0
				player.global_position = mc.get_hit_center() + Vector2(0, 70)
				await _frames(1)
				mc.raise_shield()
				var hp99b := mc.hp
				player._invincible_left = 0.0
				_gm.hp = _gm.max_hp
				mc.take_damage(99999999, Vector2.ZERO, false, 999999)
				var reflected_hp: int = _gm.max_hp - _gm.hp
				_check(mc.hp == hp99b and mc.get_reflected() == 1 and mc.is_shielded() and not _gm.is_player_dead
					and absf(reflected_hp - _gm.max_hp * mc.reflect_hp_ratio * (1.0 - _gm.get_damage_reduction())) <= 2.0,
					"[기믹] 「누가 하나님과 같으랴」 — 방패 앞에서 때리면 막히고 반사 (아무리 세게 때려도 최대 체력의 %d%%만: %d)" % [roundi(mc.reflect_hp_ratio * 100), reflected_hp])
				_gm.hp = _gm.max_hp
				player._invincible_left = 1.0
				player.global_position = mc.get_hit_center() - mc.shield_dir * 70.0
				await _frames(1)
				mc.take_damage(1000, Vector2.ZERO, false, 999999)
				_check(mc.hp < hp99b, "[기믹] 방패 뒤로 돌아가 때리면 통함")
				mc._shield_left = 0.0
				player.global_position = boss_center + Vector2(0, 90)
				var seen99 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen99["aoe"] = true)
				_check(seen99["aoe"], "미카엘 패턴: 불칼 · 심판의 빛 · 천군의 창 비 · 소환")
				mc._shield_left = 0.0
			100:
				var gb := boss as BossGabriel
				await _survive(10)
				_check(gb.is_descending() and not gb.can_be_hit_by(Enemy.HitKind.BOW), "[등장] 하늘에서 빛기둥이 내림 — 내려오는 동안 무적")
				var hp100 := gb.hp
				gb.take_damage(5000, Vector2.ZERO, false, 999999)
				_check(gb.hp == hp100, "내려오는 동안 피해 없음")
				await _survive(int(gb.descend_time * 60) + 10, func() -> void:
					player._invincible_left = 1.0)
				_check(not gb.is_descending() and gb.lilies.size() == 5 and gb.can_be_hit_by(Enemy.HitKind.MELEE), "[등장] 가브리엘이 내려오며 백합이 피어남")
				gb._wither_left = 999.0
				gb._bstate = PatternBoss.BossState.CHASE
				gb._btimer = 999.0  # 전언 기믹을 확인하는 동안 가브리엘 스스로의 패턴은 멈춤
				await _survive(int(gb.announce_time * 60) + 10, func() -> void:
					player._invincible_left = 1.0)
				player.global_position = gb.center + Vector2(160, 40)
				player._invincible_left = 0.0
				var hits100 := gb.get_revelation_hits()
				var actual100 := gb.announce(BossGabriel.Region.EAST, false)
				for i in int(gb.announce_time * 60) + 10:
					_gm.hp = 9999
					player.global_position = gb.center + Vector2(160, 40)
					await get_tree().physics_frame
				_gm.hp = _gm.max_hp
				_check(actual100 == BossGabriel.Region.EAST and gb.get_revelation_hits() == hits100 + 1, "[기믹] 하늘의 전언 — 선포한 곳(동쪽)에 빛이 내림")
				hits100 = gb.get_revelation_hits()
				actual100 = gb.announce(BossGabriel.Region.EAST, true)
				for i in int(gb.announce_time * 60) + 10:
					_gm.hp = 9999
					player._invincible_left = 0.0
					player.global_position = gb.center + Vector2(160, 40)
					await get_tree().physics_frame
				_gm.hp = _gm.max_hp
				_check(actual100 == BossGabriel.Region.WEST and gb.get_revelation_hits() == hits100 and gb.get_sealed_count() == 1, "[기믹] 봉인된 계시 — 선포한 곳의 반대쪽에 빛 (동쪽은 안전)")
				var lily100 := gb.lilies[0].global_position + Vector2(4, 4)
				var saves100 := gb.get_lily_saves()
				gb.announce(BossGabriel.Region.EAST if lily100.x > gb.center.x else BossGabriel.Region.WEST, false)
				for i in int(gb.announce_time * 60) + 10:
					_gm.hp = 9999
					player._invincible_left = 0.0
					player.global_position = lily100
					await get_tree().physics_frame
				_gm.hp = _gm.max_hp
				_check(gb.get_lily_saves() == saves100 + 1, "[기믹] 백합 곁에서는 전언의 빛 피해가 줄어듦")
				gb._wither_left = 0.01
				await _frames(2)
				_check(not gb.near_lily(player.global_position) and gb.withered[0] > 0.0, "[기믹] 가브리엘이 플레이어에게 가장 가까운 백합을 시들게 함")
				gb._wither_left = 999.0
				player._invincible_left = 1.0
				gb.take_damage(gb.hp - roundi(gb.max_hp * 0.45), Vector2.ZERO, false, 999999)
				await _frames(4)
				_check(gb.phase_two and gb.is_flying() and gb.living_wings().size() == 6 and not gb.can_be_hit_by(Enemy.HitKind.MELEE) and gb.can_be_hit_by(Enemy.HitKind.BOW), "[기믹] 체력 50% — 여섯 날개를 펴고 날아오름 (활만 닿음)")
				for w in gb.living_wings():
					w.take_damage(9999999, Vector2.ZERO, false, 999999)
				await _frames(3)
				_check(not gb.is_flying() and gb.can_be_hit_by(Enemy.HitKind.MELEE) and gb.is_stunned(), "[기믹] 날개를 모두 떨어뜨리면 땅에 내려와 휘청")
				gb._stun_left = 0.0
				gb._btimer = 0.5
				player.global_position = boss_center + Vector2(0, 90)
				var seen100 := {"aoe": false, "shot": false}
				await _survive(600, func() -> void:
					player._invincible_left = 1.0
					if _count_nodes_of("AoeStrike") > 0:
						seen100["aoe"] = true
					for c in pool.get_children():
						if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
							seen100["shot"] = true)
				_check(seen100["aoe"] and seen100["shot"], "가브리엘 패턴: 하늘의 전언 · 빛의 창 · 깃털 · 소환")
				final_boss = gb
		if n == 35:
			await _test_hidden_dungeon(main, boss as BossHelicion)
		elif n < 100:
			if n == 50:
				_check(_gm.key_items.has(&"prometheus_ember") and not _gm.has_relic(&"primal_flame"), "프로메테우스를 쓰러뜨리면 보물 「프로메테우스의 불씨」")
			boss.take_damage(999999999, Vector2.ZERO, false, 9999999)
			await _frames(4)
			_check(not _gm.is_game_cleared and next_portal.enabled, "%d스테이지 보스 토벌 → 다음 스테이지 텔레포트" % n)
			if n == 50:
				_check(not _gm.key_items.has(&"prometheus_ember") and _gm.has_relic(&"primal_flame"), "헤파이스토스가 불씨를 제련 → 「원초의 불꽃」 (신화 사용 아이템)")
				_check(not _gm.use_relic(ItemDB.get_relic(&"primal_flame")) and not _gm.has_buff("원초의 불꽃"), "원초의 불꽃은 100스테이지 클리어 전까지 봉인 (쓸 수 없음)")
	return final_boss


## 35스테이지: 고대 용의 비늘 6개 → 헬리시온 토벌 → 고대의 문 → 히든 보스 아르케 → 36스테이지 텔레포트
func _test_hidden_dungeon(main: Node2D, heli_end: BossHelicion) -> void:
	var player := main.get_node("Entities/Player") as Player
	var pool := main.get_node("ProjectilePool") as ProjectilePool
	var stage := main.get_node("StageManager") as StageManager
	print("  [히든 던전 - 고대 용의 비늘 6개 + 35스테이지 보스 토벌]")
	var next_portal_end := main.get_node("Entities/NextStagePortal") as Portal
	stage.ending_delay = 600.0
	_check(_gm.has_all_dragon_scales() and stage.is_hidden_gate_ready(), "고대 용의 비늘 6개를 모두 모음")
	if heli_end != null:
		heli_end.take_damage(999999999, Vector2.ZERO, false, 999999)
		await _frames(3)
		if heli_end.get_soul() != null:
			heli_end.get_soul().take_damage(999999999)
		await _frames(4)
	_check(heli_end != null and heli_end.is_dead(), "영혼을 부수면 헬리시온이 진짜로 쓰러짐")
	var hidden_portal := stage.get_hidden_portal()
	_check(stage.get_state() == StageManager.State.CLEARED and not _gm.is_game_cleared and stage.get_chest() != null and next_portal_end.enabled and not hidden_portal.enabled,
			"비늘을 모두 모은 채 35스테이지 보스 토벌 → 보물상자 + 텔레포트 (아직 고대의 문은 닫힘)")
	stage.get_chest()._interact()
	await _frames(4)
	_check(hidden_portal.enabled and hidden_portal.visible, "[히든] 보물상자를 열면 「고대의 문」이 열림")
	hidden_portal.interacted.emit()
	await _frames(int(stage.boss_entry_delay * 60) + 10)
	var arche := _find_boss() as BossArche
	_check(arche != null and arche.display_name == "고대 드래곤 아르케" and _gm.location_name == "고대 용의 둥지" and stage.is_in_hidden_dungeon(), "고대의 문 → 고대 용의 둥지 · 히든 보스 고대 드래곤 아르케")
	_check(get_tree().get_nodes_in_group(&"enemies").size() == 1, "히든 던전에는 잡몹 없음")
	if arche != null:
		var center_h := stage.boss_room.get_arena_rect().get_center()
		player.global_position = center_h + Vector2(0, 90)
		await _survive(5)
		_check(arche.get_aspect() == BossArche.Aspect.WIND and arche.get_wind() != null, "[기믹] 원소 순환: 바람 — 보스방에 바람")
		arche.set_aspect(BossArche.Aspect.EARTH)
		_check(arche.get_wind() == null and arche.defense == arche._base_defense + arche.earth_armor, "대지 — 방어력 +%d (바람은 그침)" % arche.earth_armor)
		arche.set_aspect(BossArche.Aspect.ICE)
		arche._hazard_timer = 0.01
		await _frames(3)
		_check(arche.defense == arche._base_defense and not get_tree().get_nodes_in_group(&"ice_floors").is_empty(), "얼음 — 플레이어 발밑에 빙판")
		arche.set_aspect(BossArche.Aspect.FIRE)
		_check(arche.burn_damage > 0 and arche.get_aspect_changes() >= 4, "화염 — 공격에 화상")
		arche._aspect_left = 0.01
		await _frames(3)
		_check(arche.get_aspect() == BossArche.Aspect.WIND, "시간이 지나면 다음 원소로 (화염 → 바람)")
		arche._rune_cooldown = 999.0
		arche.begin_runes(2)
		await _frames(2)
		var runes := arche.get_runes()
		_check(runes != null and runes.centers.size() == 4 and arche.get_status_text().contains("얼음"), "[기믹] 고대 용언: 룬 원 4개 + 외친 원소 「얼음」")
		if runes != null:
			var safe_at := runes.centers[2]
			player.global_position = safe_at
			arche._rune_left = 0.01
			await _survive(3, func() -> void:
				player.global_position = safe_at)
		_check(arche.get_rune_dodges() == 1 and arche.get_rune_hits() == 0 and arche.get_runes() == null, "외친 원소의 원 안에 있으면 용언을 견딤")
		arche.begin_runes(0)
		await _frames(2)
		var runes2 := arche.get_runes()
		_gm.hp = _gm.max_hp
		var hp_h: int = _gm.hp
		if runes2 != null:
			player.global_position = runes2.centers[3]
			arche._rune_left = 0.01
			await _frames(3)
		_check(arche.get_rune_hits() == 1 and _gm.hp <= hp_h - roundi(_gm.max_hp * arche.rune_ratio) + 5, "다른 원에 있으면 용언에 큰 피해 (가드·대시 불가)")
		_gm.hp = _gm.max_hp
		arche.set_aspect(BossArche.Aspect.EARTH)  # 대지 = 낙석 장판이 나오는 원소
		var seen_h := {"aoe": false, "shot": false}
		await _survive(600, func() -> void:
			if _count_nodes_of("AoeStrike") > 0:
				seen_h["aoe"] = true
			for c in pool.get_children():
				if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
					seen_h["shot"] = true)
		_check(seen_h["aoe"] and seen_h["shot"], "아르케 패턴: 원소 공격 · 고대의 고리 · 원소 숨결")
		arche.take_damage(999999999, Vector2.ZERO, false, 999999)
		await _frames(4)
	_check(_gm.hidden_cleared and not stage.is_in_hidden_dungeon() and stage.get_chest() != null and next_portal_end.enabled and next_portal_end.prompt_text.contains("36") and not _gm.is_game_cleared, "아르케 토벌 → 고대 용의 보물상자 + 36스테이지 텔레포트")
	_check(_gm.get_potion_count(&"dragon_blood") == StageManager.DRAGON_BLOOD_REWARD, "[히든] 아르케 토벌 → 신화 포션 「고대 용의 피」 %d병" % _gm.get_potion_count(&"dragon_blood"))
	_gm.damage_player(100)
	_check(ItemDB.get_potion(&"dragon_blood").is_sealed() and not _gm.use_potion(ItemDB.get_potion(&"dragon_blood")) and _gm.get_potion_count(&"dragon_blood") == StageManager.DRAGON_BLOOD_REWARD, "고대 용의 피는 100스테이지 클리어 전까지 봉인 (마실 수 없음)")
	_gm.heal_full()
	_check(WindField.active == null and get_tree().get_nodes_in_group(&"storm_fields").is_empty(), "아르케가 쓰러지면 바람·룬·빙판이 정리됨")
	var items_before := _item_pickups(main.get_node("Entities")).size()
	stage.hidden_chest_item_chances = [1.0, 1.0, 0.0]
	stage.get_chest()._interact()
	await _frames(4)
	_check(_item_pickups(main.get_node("Entities")).size() == items_before + 2 and stage.last_chest_gold >= roundi(Balance.chest_gold(_gm.stage) * 3 * 0.8 * stage.get_gold_multiplier()) - 1,
		"고대 용의 보물상자: 골드 %d (보통 상자의 3배) + 장비 (100%% · 60%% · 30%% 확률 → 이번엔 2개로 고정)" % stage.last_chest_gold)


## 최종장: 100스테이지 보스를 쓰러뜨린 뒤 상인 → 멀티버스의 주인. 쓰러뜨리지 않은 채 돌려줌
func _test_finale(main: Node2D) -> BossMultiverseMaster:
	var player := main.get_node("Entities/Player") as Player
	var stage := main.get_node("StageManager") as StageManager
	var pool := main.get_node("ProjectilePool") as ProjectilePool
	print("[최종장 - 멀티버스의 끝]")
	await _survive(int(stage.finale_delay * 60) + 10, func() -> void:
		player._invincible_left = 1.0)
	await _survive(int(stage.boss_entry_delay * 60) + 10, func() -> void:
		player._invincible_left = 1.0)
	var master := _find_boss() as BossMultiverseMaster
	_check(stage.is_in_finale() and master != null and stage.get_state() == StageManager.State.BOSS and _gm.stage_name.contains("멀티버스의 끝"), "[최종장] 대천사가 쓰러지자 보스방에 상인이 나타남")
	if master == null:
		return null
	var center := master.center
	_check(master.mode == BossMultiverseMaster.Mode.MERCHANT and master.sprite.texture == master.merchant_texture and not master.can_be_hit_by(Enemy.HitKind.MELEE), "[최종장] 처음엔 야영지의 상인 모습 (무적)")
	var hp := master.hp
	master.take_damage(5000, Vector2.ZERO, false, 999999)
	_check(master.hp == hp, "상인 모습일 때는 피해 없음")
	await _survive(int(master.line_time * 60 * 2) + 30, func() -> void:
		player._invincible_left = 1.0)
	_check(master._line >= 2, "[최종장] 상인이 정체를 털어놓음 (대사 %d줄)" % master._line)
	master._line = BossMultiverseMaster.LINES.size()
	master._mode_left = 0.01
	await _frames(3)
	_check(master.mode == BossMultiverseMaster.Mode.TRANSFORM, "[최종장] 상인의 모습이 일그러지며 변신 시작")
	await _survive(int(master.transform_time * 60) + 10, func() -> void:
		player._invincible_left = 1.0)
	_check(master.is_revealed() and master.sprite.texture == master.true_texture and master.display_name == "멀티버스의 주인" and master.world >= 0 and master.can_be_hit_by(Enemy.HitKind.MELEE), "[최종장] 멀티버스의 주인으로 변신 · 첫 세계 전환")
	master._shift_left = 999.0
	var worlds_ok := true
	for w in BossMultiverseMaster.WORLD_STAGES.size():
		master.shift_world(w)
		await _frames(2)
		var data := stage.get_stage_data(BossMultiverseMaster.WORLD_STAGES[w])
		if master.world != w or stage.boss_room._floor.texture != data.floor_texture:
			worlds_ok = false
		match w:
			BossMultiverseMaster.World.SLIME:
				worlds_ok = worlds_ok and master._zones.size() == 7
			BossMultiverseMaster.World.FOG:
				worlds_ok = worlds_ok and master.veil != null
			BossMultiverseMaster.World.ABYSS:
				worlds_ok = worlds_ok and master.pit != null
			BossMultiverseMaster.World.FLOOD:
				worlds_ok = worlds_ok and master.flood != null
	master._shift_left = 999.0
	_check(worlds_ok and master.world2 == -1 and master.get_shift_count() >= 10, "[기믹] 세계 전환: 9개 세계의 보스방과 기믹으로 차례로 바뀜 (앞 세계 기믹은 정리)")
	master._stun_left = 3.0
	master.shift_world(BossMultiverseMaster.World.SLOTH)
	player.global_position = master.global_position + Vector2(0, 60)
	await _frames(3)
	_check(player.is_slowed(), "[기믹] 나태의 늪 — 주인 곁에서 느려짐")
	master.shift_world(BossMultiverseMaster.World.CHAIN)
	player.global_position = master.global_position + Vector2(230, 0)
	await _frames(1)
	var d0 := master.global_position.distance_to(player.global_position)
	await _frames(6)
	_check(master.global_position.distance_to(player.global_position) < d0, "[기믹] 색욕의 궁전 — 멀어지면 사슬에 끌려감")
	master.shift_world(BossMultiverseMaster.World.STONES)
	master._stone_left = 999.0
	master._stun_left = 3.0
	player.global_position = center + Vector2(0, 150)
	var hits := master.get_stone_hits()
	hp = master.hp
	master.roll_stone(master.get_hit_center() + Vector2(-300, 0), master.get_hit_center() + Vector2(300, 0), 0.2)
	await _survive(150, func() -> void:
		player._invincible_left = 1.0)
	_check(master.get_stone_hits() == hits + 1 and master.hp < hp, "[기믹] 두라 평지 — 뜨인 돌이 주인을 치면 큰 피해 + 휘청")
	master.shift_world(BossMultiverseMaster.World.REVELATION)
	master._light_left = 999.0
	player.global_position = center + Vector2(150, 40)
	player._invincible_left = 0.0
	master.announce_light(0)
	var lit := false
	for i in 110:
		_gm.hp = 9999
		player.global_position = center + Vector2(150, 40)
		await get_tree().physics_frame
		if _gm.hp < 9999:
			lit = true
	_gm.hp = _gm.max_hp
	_check(lit, "[기믹] 백합의 정원 — 주인이 흉내 낸 전언: 선포한 곳에 빛")
	master.shift_world(BossMultiverseMaster.World.ABYSS)
	master.pit.radius = 40.0
	player._invincible_left = 0.0
	player.global_position = master.pit.global_position
	var fell := false
	for i in 3:
		_gm.hp = 9999
		await get_tree().physics_frame
		if _gm.hp < 9999:
			fell = true
	_gm.hp = _gm.max_hp
	_check(fell and not master.pit.contains(player.global_position), "[기믹] 무저갱 — 구덩이에 빠지면 큰 피해 + 가장자리로")
	master.shift_world(BossMultiverseMaster.World.SLIME)
	master._shift_left = 999.0
	master._stun_left = 0.0
	player._invincible_left = 1.0
	player.global_position = center + Vector2(0, 120)
	# 관람석
	master.take_damage(roundi(master.max_hp * 0.26), Vector2.ZERO, false, 999999)
	await _frames(4)
	_check(master.mode == BossMultiverseMaster.Mode.SPECTATING and master.living_champions().size() == 3 and not master.can_be_hit_by(Enemy.HitKind.BOW), "[기믹] 체력 75% — 관람석: 서로 다른 세계의 투사 셋을 싸움 붙임")
	var champ := master.living_champions()[0]
	var base_hp := ((load(champ.scene_file_path) as PackedScene).instantiate() as Enemy)
	_check(champ.max_hp >= base_hp.max_hp * 2.9, "투사는 체력 3배")
	base_hp.free()
	hp = master.hp
	master.take_damage(5000, Vector2.ZERO, false, 999999)
	_check(master.hp == hp, "관람석에 있는 동안 주인은 무적")
	for c in master.living_champions():
		c.take_damage(99999999, Vector2.ZERO, false, 999999)
	await _frames(3)
	_check(master.mode == BossMultiverseMaster.Mode.FIGHT and master.get_fall_count() == 1 and master.is_stunned(), "[기믹] 투사를 모두 쓰러뜨리면 주인이 관람석에서 굴러떨어짐")
	hp = master.hp
	master.take_damage(1000, Vector2.ZERO, false, 999999)
	_check(hp - master.hp >= 1400, "관람석에서 떨어진 동안 피해 1.5배")
	master._fallen_left = 0.0
	master._stun_left = 0.0
	master.begin_spectate()
	await _frames(3)
	hp = master.hp
	master._spectate_left = 0.01
	await _frames(3)
	_check(master.mode == BossMultiverseMaster.Mode.FIGHT and master.hp > hp and master.living_champions().is_empty(), "[기믹] 시간 안에 투사를 못 쓰러뜨리면 주인이 회복")
	# 멀티버스의 균열
	master._spectated[1] = true
	master._spectated[2] = true
	master.take_damage(master.hp - roundi(master.max_hp * 0.6), Vector2.ZERO, false, 999999)
	await _frames(4)
	_check(master.get_phase() == 2 and master.living_rifts().size() == 2, "[기믹] 체력 2/3 이하 — 멀티버스의 균열 둘이 열림")
	_check(master.is_awakened() and master.sprite.modulate == BossMultiverseMaster.AWAKEN_TINT and master.has_node("AwakenAura"), "[각성] 2페이즈 시작 — 각성 연출 (몸이 붉은 보라로 타오르는 오라)")
	hp = master.hp
	master.take_damage(1000, Vector2.ZERO, false, 999999)
	_check(hp - master.hp <= 620, "균열이 열려 있으면 주인에게 피해 60%")
	for r in master.living_rifts():
		r.take_damage(99999999, Vector2.ZERO, false, 999999)
	await _frames(3)
	_check(master.living_rifts().is_empty() and master._rift_left > 0.0, "균열을 모두 닫음")
	master._rift_left = 0.01
	await _frames(4)
	_check(master.living_rifts().size() == 2, "닫은 균열은 잠시 뒤 다시 열림")
	# 멀티버스 붕괴
	master.hp = roundi(master.max_hp * 0.3)
	var before := master.world
	master.shift_world()
	_check(master.get_phase() == 3 and master.world2 == before and master.world != before, "[기믹] 체력 1/3 이하 — 멀티버스 붕괴: 두 세계가 겹침")
	master._shift_left = 999.0
	player.global_position = center + Vector2(0, 120)
	var seen := {"aoe": false, "shot": false}
	await _survive(600, func() -> void:
		player._invincible_left = 1.0
		player.global_position = master.get_hit_center() + Vector2(0, 100)
		if _count_nodes_of("AoeStrike") > 0:
			seen["aoe"] = true
		for c in pool.get_children():
			if (c as Projectile).is_active and (c as Projectile).get_team() == ProjectileSpec.Team.ENEMY:
				seen["shot"] = true)
	_check(seen["aoe"] and seen["shot"], "멀티버스의 주인 패턴: 금화 폭풍 · 값 매기기 · 세계의 메아리 · 소환 · 균열의 탄")
	master._spectate_left = 0.0
	return master


## 마지막 스테이지(100) 보스 토벌 → 최종장(멀티버스의 주인) 토벌 → 모든 스테이지 클리어 / 비늘 없이 35스테이지 보스를 쓰러뜨리면 히든 없음
func _test_final_and_no_hidden(main: Node2D, final_boss: Enemy) -> void:
	var player := main.get_node("Entities/Player") as Player
	var stage := main.get_node("StageManager") as StageManager
	var field_portal := main.get_node("Entities/FieldPortal") as Portal
	var gate := main.get_node("Entities/BossGate") as BossGate
	var next_portal_end := main.get_node("Entities/NextStagePortal") as Portal
	print("[100스테이지 보스 토벌 → 최종장]")
	stage.ending_delay = 600.0  # 아래 테스트가 끝난 뒤 엔딩 화면을 따로 검사
	var pending := AoeStrike.spawn(main, player.global_position, 40.0, 0.03, 9999, Color.RED)
	if final_boss != null:
		final_boss.take_damage(9999999, Vector2.ZERO, false, 999999)
	await _frames(4)
	_check(not is_instance_valid(pending) and not _gm.is_player_dead, "보스가 쓰러지면 아직 터지지 않은 예고 장판도 사라짐")
	_check(not _gm.is_game_cleared and stage.get_state() == StageManager.State.CLEARED and not next_portal_end.enabled and stage.get_chest() == null, "100스테이지 보스 토벌 → 아직 엔딩이 아님 (상자 · 텔레포트 없이 최종장을 기다림)")
	var master := await _test_finale(main)
	print("[엔딩 - 최종 보스 토벌]")
	var kills_before: int = _gm.total_kills
	pending = AoeStrike.spawn(main, player.global_position, 40.0, 0.03, 9999, Color.RED)
	if master != null:
		master.take_damage(999999999, Vector2.ZERO, false, 999999)
	await _frames(4)
	_check(not is_instance_valid(pending) and not _gm.is_player_dead and not stage.is_in_finale(), "최종 보스가 쓰러지면 남은 예고 장판도 사라짐")
	_check(_gm.is_game_cleared and stage.get_state() == StageManager.State.CLEARED, "최종 보스(멀티버스의 주인) 토벌 → 모든 스테이지 클리어")
	_check(_gm.total_kills > kills_before and _gm.play_time > 0.0, "엔딩 기록: 처치 %d마리 · 플레이 %s" % [_gm.total_kills, _gm.get_play_time_text()])
	_check(stage.get_chest() == null and not next_portal_end.enabled and get_tree().get_nodes_in_group(&"enemies").is_empty(), "마지막 스테이지: 상자 / 텔레포트 없음, 남은 졸개 정리")
	_check(_gm.faith_damage_bonus == 0.0 and get_tree().get_nodes_in_group(&"hostile_zones").is_empty() and _gm.stolen_weapon == null, "보스가 쓰러지면 신앙·장판·빼앗긴 무기 정리")
	stage.go_to_next_stage()
	await _frames(3)
	_check(not _gm.key_items.has(&"prometheus_ember") and _gm.has_relic(&"primal_flame"), "49스테이지 프로메테우스의 불씨 → 50스테이지 헤파이스토스가 쓰러지며 「원초의 불꽃」으로 제련")
	_check(_gm.has_relic(&"last_trumpet"), "100스테이지 가브리엘 → 최후의 나팔")
	_check(_gm.stage == 100 and get_tree().current_scene == main, "100스테이지 이후 반복 스테이지 없음")
	_check(get_tree().get_nodes_in_group(&"storm_fields").is_empty() and not player.is_rooted() and not player.is_charmed() and not player.is_plagued(), "마지막 보스가 쓰러지면 보스방 장치 정리 · 공포 풀림 (fields %d · 묶임 %s %s)" % [get_tree().get_nodes_in_group(&"storm_fields").size(), player.is_rooted(), player._root_label])

	print("[히든 조건 없이 35스테이지 보스 토벌]")
	_gm.dragon_scales.clear()
	stage.go_to_stage(35)
	await _frames(3)
	field_portal.interacted.emit()
	await _frames(3)
	_check(not get_tree().get_nodes_in_group(&"dragon_scales").is_empty(), "주운 적 없는 스테이지면 비늘이 다시 숨어 있음")
	gate.open()
	gate.interacted.emit()
	await _frames(int(stage.boss_entry_delay * 60) + 10)
	var heli2 := _find_boss() as BossHelicion
	if heli2 != null:
		heli2.take_damage(9999999, Vector2.ZERO, false, 999999)
		await _frames(3)
		if heli2.get_soul() != null:
			heli2.get_soul().take_damage(9999999)
	await _frames(4)
	if stage.get_chest() != null:
		stage.get_chest()._interact()
	await _frames(4)
	_check(stage.get_state() == StageManager.State.CLEARED and not stage.get_hidden_portal().enabled and next_portal_end.prompt_text.contains("36"), "비늘이 모자라면 상자를 열어도 고대의 문이 열리지 않음 (36스테이지 텔레포트만)")


## 대화창 · 대본 (자동 테스트는 대사를 끈 채 돌고, 여기서만 잠깐 켬)
func _test_dialogue(main: Node2D) -> void:
	print("[대화창 · 대본]")
	var shop_ui := main.get_node("ShopUI")
	var keeper := main.get_node("Entities/ShopKeeper") as ShopKeeper
	_check(FileAccess.file_exists(Story.STORY_PATH) and Story.sections.has("1스테이지 도착") and Story.sections.has("100스테이지 보스 토벌") and Story.sections.has("50스테이지 상인") and Story.sections.has("히든 보스 등장") and Story.sections.has("최종장 등장") and Story.sections.has("엔딩"), "대본 파일: 1~100스테이지 · 히든 · 최종장 · 엔딩 구간이 모두 있음")
	Story.enabled = true
	Story.load_text("@초상화 해설 = res://assets/sprites/characters/merchant_boss.png\n[테스트]\n성기사: 첫 줄입니다. 이 줄은 글자가 한 자씩 나오는지 보려고 일부러 아주 길게 써 둔 대사입니다. 끝까지 나오려면 시간이 꽤 걸립니다.\n슬라임 킹: 꾸르르\n해설: 세 번째\n그냥 해설 줄\n@장면: 화면이 하얗게 번쩍인다\n# 메모\n[빈 구간]\n@장면 보스가 내려온다\n")
	_check(Story.has_lines("테스트") and (Story.sections["테스트"] as Array).size() == 4 and not Story.has_lines("빈 구간"), "대본 읽기: 「이름: 대사」 · 이름 없는 줄 · 메모 · 빈 구간")
	_check(not Story.play("빈 구간"), "빈 구간은 아무것도 나오지 않음")
	_check(Story.scene_notes.size() == 2 and Story.scene_notes[0]["section"] == "테스트" and Story.scene_notes[0]["index"] == 4 and Story.scene_notes[0]["text"] == "화면이 하얗게 번쩍인다" and Story.scene_notes[1]["text"] == "보스가 내려온다", "@장면 줄은 대사로 나오지 않고 장면 메모로 모임 (구간 · 순서 함께)")
	_check(Story.play("테스트") and get_tree().paused and Story.is_playing(), "대화창이 뜨면 게임이 멈춤")
	var box := Story.get_box()
	_check(Story.portrait_for("성기사") != null and Story.portrait_for("슬라임 킹") != null and Story.portrait_for("해설") == Story.portraits["해설"] and Story.portrait_for("아무도아닌이름") == null, "초상화: 주인공 · 보스 이름으로 자동 · @초상화로 지정")
	await get_tree().process_frame
	_check(box.is_typing(), "글자가 한 자씩 나옴")
	box.advance()
	_check(not box.is_typing() and box.current_line()["name"] == "성기사", "넘기면 먼저 그 줄을 다 보여 줌")
	box.advance()
	_check(box.current_line()["name"] == "슬라임 킹", "다시 넘기면 다음 줄")
	Story.skip()
	_check(not Story.is_playing() and not get_tree().paused, "마지막 줄을 넘기면 대화창이 닫히고 게임이 다시 움직임")
	_check(not Story.play("테스트"), "한 번 본 대사는 같은 모험에서 다시 나오지 않음")
	_gm.set_hero_name("  아서  ")
	Story.load_text("[3스테이지 보스 등장]\n보스: 크아아…!\n용사: 간다!\n상인: 용사님, 힘내세요\n[히든 보스 토벌]\n보스: 크윽\n[최종장 등장]\n보스: 짝, 짝\n[최종장 토벌]\n보스: 이럴 수가\n")
	var lines := Story.resolve_lines("3스테이지 보스 등장")
	_check(lines[0]["name"] == "원소의 거신 아르케온" and Story.portrait_for(lines[0]["name"]) != null, "대본의 「보스」 → 그 스테이지의 보스 이름 · 초상화 (%s)" % lines[0]["name"])
	_check(lines[1]["name"] == "아서" and Story.portrait_for("아서") == Story.portrait_for("성기사") and lines[2]["text"] == "아서님, 힘내세요", "대본의 「용사」 → 플레이어가 지은 이름 (이름 · 대사 모두, 주인공 초상화)")
	_check(Story.resolve_lines("히든 보스 토벌")[0]["name"] == "고대 드래곤 아르케" and Story.resolve_lines("최종장 등장")[0]["name"] == "상인" and Story.resolve_lines("최종장 토벌")[0]["name"] == "멀티버스의 주인", "히든 · 최종장 구간의 「보스」도 알맞은 이름으로")
	_gm.set_hero_name("   ")
	_check(_gm.hero_name == "용사" and Story.resolve_lines("3스테이지 보스 등장")[1]["name"] == "용사", "이름을 비워 두면 그대로 「용사」")
	_gm.set_hero_name("가나다라마바사아자차카타파하")
	_check(_gm.hero_name.length() == 12, "용사의 이름은 12자까지")
	_gm.set_hero_name("")
	Story.load_text("[1스테이지 도착]\n성기사: 도착했다\n")
	get_tree().paused = true
	Story.queue("1스테이지 도착")
	for i in 3:
		await get_tree().process_frame
	_check(not Story.is_playing(), "상점 등으로 멈춰 있는 동안은 대사가 기다림")
	get_tree().paused = false
	for i in 3:
		await get_tree().process_frame
	_check(Story.is_playing(), "멈춤이 풀리면 이어서 대화창")
	Story.skip()
	Story.load_text("[상인]\n상인: 좋은 물건이 많이 있어\n[%d스테이지 상인]\n상인: 이 스테이지 전용\n" % _gm.stage)
	keeper._interact()
	_check(Story.is_playing() and Story.get_box().current_line()["text"] == "이 스테이지 전용", "상인에게 처음 말을 걸면 그 스테이지 전용 대사가 상점보다 먼저")
	Story.skip()
	for i in 3:
		await get_tree().process_frame
	_check(shop_ui.visible and get_tree().paused, "대사가 끝나면 상점이 열림")
	shop_ui.close()
	for n in 2:
		keeper._interact()
		_check(Story.is_playing() and Story.get_box().current_line()["text"] == "좋은 물건이 많이 있어", "다시 말을 걸면 [상인] 대사 — 말을 걸 때마다 (%d번째)" % (n + 2))
		Story.skip()
		for i in 3:
			await get_tree().process_frame
		shop_ui.close()
	# 표정 · 긴 대사 · @연출
	Story.load_text("@초상화 상인[미소] = res://assets/sprites/characters/merchant_smirk.png\n[표정]\n상인[미소]: 흐흐\n상인[미소]: 또 흐흐\n상인[없는표정]: 그냥\n[긴 대사]\n보스: %s\n[연출]\n성기사: 시작\n@연출: 장비빛남\n빛이 난다\n[연출만]\n@연출: 장비빛남\n[최종장 정체]\n상인: 자 그럼\n" % "가나다라마 ".repeat(40))
	lines = Story.resolve_lines("표정")
	_check(lines[0]["name"] == "상인" and lines[0]["face"] == "상인[미소]" and Story.portrait_for("상인[미소]") == load("res://assets/sprites/characters/merchant_smirk.png") and Story.portrait_for("상인[없는표정]") == Story.portrait_for("상인"), "이름[표정]: 이름은 그대로, 초상화는 표정 그림 (없으면 평소 얼굴)")
	Story.play("표정")
	box = Story.get_box()
	_check(box.current_portrait() == Story.portrait_for("상인"), "표정이 바뀌는 줄은 평소 얼굴이 먼저 보이고")
	await get_tree().create_timer(DialogueBox.FACE_CHANGE_TIME + 0.2).timeout
	_check(box.current_portrait() == Story.portrait_for("상인[미소]"), "…잠시 뒤 표정 그림으로 바뀜 (입꼬리가 올라감)")
	box.advance()
	box.advance()
	_check(box.current_portrait() == Story.portrait_for("상인[미소]"), "같은 표정이 이어지면 바로 표정 그림")
	Story.skip()
	lines = Story.resolve_lines("긴 대사")
	var fits := true
	for l in lines:
		fits = fits and (l["text"] as String).length() <= Story.PAGE_CHARS
	_check(lines.size() >= 3 and fits, "긴 대사는 대화창 한 칸씩 나눠서 나옴 (%d칸)" % lines.size())
	_check(Story.resolve_lines("최종장 정체")[0]["name"] == "상인" and Story.portrait_for(Story.resolve_lines("최종장 정체")[0]["face"]) == Story.portrait_for("멀티버스의 주인"), "변신한 뒤 최종장 구간의 「상인」은 멀티버스의 주인 얼굴")
	var cue_seen: Array[String] = []
	var on_cue := func(n: String) -> void: cue_seen.append(n)
	Story.cue.connect(on_cue)
	Story.play("연출")
	box = Story.get_box()
	box.advance()
	box.advance()
	_check(cue_seen == ["장비빛남"] and box.current_line()["text"] == "빛이 난다", "@연출 줄은 장면을 틀고 바로 다음 대사로")
	var glow := (main.get_node("Entities/Player") as Node).get_children().filter(func(c: Node) -> bool: return c is StoryCues.EquipmentGlow)
	_check(glow.size() == 1 and (glow[0] as StoryCues.EquipmentGlow).icons.size() >= 2, "[장면] 장비빛남: 용사 둘레에 가진 장비가 떠올라 빛남 (장비 %d개)" % ((glow[0] as StoryCues.EquipmentGlow).icons.size() if glow.size() == 1 else 0))
	var glow_time: float = (glow[0] as StoryCues.EquipmentGlow)._time if glow.size() == 1 else 0.0
	await get_tree().create_timer(0.3).timeout
	_check(glow.size() == 1 and (glow[0] as StoryCues.EquipmentGlow)._time > glow_time and get_tree().paused, "대화창이 떠 있어도 (게임 일시정지) 장면은 움직임")
	Story.skip()
	_check(Story.play("연출만") and not Story.is_playing() and not get_tree().paused and cue_seen.size() == 2, "@연출 만 있는 구간도 멈추지 않고 끝남")
	Story.cue.disconnect(on_cue)
	await get_tree().create_timer(StoryCues.GLOW_TIME + 0.2).timeout
	_check((main.get_node("Entities/Player") as Node).get_children().filter(func(c: Node) -> bool: return c is StoryCues.EquipmentGlow).is_empty() and (main.get_node("Entities/Player") as CanvasItem).modulate == Color.WHITE, "장면이 끝나면 사라지고 용사의 빛도 원래대로")
	# 키 고정: 가드 = 우클릭 · 대시 = Shift · 인벤토리 = Tab · 무기 = 1/2/3 · 스킬 = Q · 대화 = Enter
	var binds := func(action: StringName) -> Array:
		var out := []
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				out.append("key:%d" % (e as InputEventKey).physical_keycode)
			elif e is InputEventMouseButton:
				out.append("mouse:%d" % (e as InputEventMouseButton).button_index)
			else:
				out.append("other")
		return out
	_check(binds.call(&"guard") == ["mouse:%d" % MOUSE_BUTTON_RIGHT], "방어 가드: 마우스 오른쪽 버튼만 %s" % str(binds.call(&"guard")))
	_check(binds.call(&"dash") == ["key:%d" % KEY_SHIFT], "대시: Shift 만 %s" % str(binds.call(&"dash")))
	_check(binds.call(&"inventory") == ["key:%d" % KEY_TAB], "인벤토리: Tab 만 %s" % str(binds.call(&"inventory")))
	_check(binds.call(&"weapon_slot_1") == ["key:%d" % KEY_1] and binds.call(&"weapon_slot_2") == ["key:%d" % KEY_2] and binds.call(&"weapon_slot_3") == ["key:%d" % KEY_3], "무기 칸: 1 · 2 · 3 키만")
	_check(binds.call(&"skill") == ["key:%d" % KEY_Q], "액티브 스킬: Q")
	_check(binds.call(&"dialogue_next") == ["key:%d" % KEY_ENTER, "key:%d" % KEY_KP_ENTER], "대화 넘기기: Enter (숫자패드 Enter 포함)")
	_check(binds.call(&"voice_talk") == ["key:%d" % KEY_T] and binds.call(&"party_quit") == ["key:%d" % KEY_F], "음성 채팅 눌러서 말하기: T (멀티 전멸 화면의 끝내기는 F)")
	_check(VoiceChat.MODE_NAMES.size() == 3 and VoiceChat.MODE_NAMES[VoiceChat.Mode.OFF] == "끄기" and VoiceChat.MODE_NAMES[VoiceChat.Mode.OPEN] == "항상 켜기" and VoiceChat.MODE_NAMES[VoiceChat.Mode.PUSH_TO_TALK].contains("[T]"),
		"음성 채팅 3가지: %s" % " / ".join(VoiceChat.MODE_NAMES))
	# 대화는 Enter 로만 넘어감 + 오른쪽 위 [스킵] 버튼
	Story.load_text("[키 테스트]\n성기사: 하나\n성기사: 둘 — 이 줄은 일부러 길게 써서 글자가 한 자씩 나오는 동안 Enter 를 눌러 보는 대사입니다\n성기사: 셋\n@연출: 장비빛남\n성기사: 넷\n")
	cue_seen.clear()
	Story.cue.connect(on_cue)
	_check(Story.play("키 테스트"), "키 테스트 대화 시작")
	box = Story.get_box()
	box.advance()  # 글자를 다 보이게
	for other in [&"interact", &"attack", &"ui_accept", &"dash", &"skill"]:
		await _press_action(other)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(4, 4)
	click.pressed = true
	Input.parse_input_event(click)
	await get_tree().process_frame
	click = click.duplicate() as InputEventMouseButton
	click.pressed = false
	Input.parse_input_event(click)
	await get_tree().process_frame
	_check(Story.is_playing() and box.current_line()["text"] == "하나", "E · 클릭 · Space · Shift · Q 로는 대사가 넘어가지 않음")
	await _press_action(&"dialogue_next")
	_check(box.current_line()["text"].begins_with("둘") and box.is_typing(), "Enter → 다음 대사")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await get_tree().process_frame
	enter = enter.duplicate() as InputEventKey
	enter.pressed = false
	Input.parse_input_event(enter)
	await get_tree().process_frame
	_check(box.current_line()["text"].begins_with("둘") and not box.is_typing(), "실제 Enter 키: 글자가 나오는 중이면 먼저 다 보여 줌")
	var skip_rect := box.skip_button.get_global_rect()
	var view_size := box.skip_button.get_viewport_rect().size
	_check(box.skip_button.visible and box.skip_button.is_visible_in_tree() and skip_rect.end.x > view_size.x * 0.75 and skip_rect.position.y < view_size.y - 96.0 and skip_rect.position.y > view_size.y * 0.5, "대화창 오른쪽 위에 [스킵] 버튼 (%s)" % str(skip_rect))
	_check(box.skip_button.text.contains("스킵"), "버튼 글자 「스킵」")
	box.skip_button.pressed.emit()
	_check(not Story.is_playing() and not get_tree().paused and cue_seen == ["장비빛남"], "[스킵] → 남은 대사를 건너뛰고 닫힘 (연출 장면은 그대로 · 게임 다시 움직임)")
	Story.cue.disconnect(on_cue)
	await get_tree().create_timer(StoryCues.GLOW_TIME + 0.2).timeout
	# 첫 장면: 하늘에서 떨어짐 → (대화창은 장면이 끝난 뒤) → 상인의 선물
	Story.load_text("[첫 장면]\n@연출: 하늘에서떨어짐\n용사: 으윽\n상인: 선물입니다\n@연출: 선물\n용사: 감사합니다\n[흔적]\n@연출: 도전자의흔적\n일지: 「…」\n")
	var body := (main.get_node("Entities/Player") as Player).get_node("BodySprite") as Node2D
	var body_y := body.position.y
	Story.play("첫 장면")
	box = Story.get_box()
	await get_tree().process_frame
	_check(box.is_waiting_cue() and body.position.y < body_y - 100.0 and not box.get_child(0).visible, "[장면] 하늘에서떨어짐: 용사가 하늘 높이에서 시작 · 그동안 대화창은 숨김")
	box.advance()
	_check(box.is_waiting_cue(), "장면 중에는 Enter 로 넘어가지 않음")
	await get_tree().create_timer(StoryCues.wait_time("하늘에서떨어짐") + 0.2).timeout
	_check(not box.is_waiting_cue() and is_equal_approx(body.position.y, body_y) and is_zero_approx(body.rotation) and box.current_line()["text"] == "으윽",
		"떨어져 쿵 → 쓰러졌다 일어남 → 그다음 대화창 「으윽」")
	box.advance()
	box.advance()
	box.advance()
	_check(box.is_waiting_cue(), "[장면] 선물: 상인 쪽에서 장비가 날아가는 동안 대화창 숨김")
	await get_tree().create_timer(StoryCues.wait_time("선물") + 0.2).timeout
	_check(box.current_line()["text"] == "감사합니다", "선물 장면이 끝나면 다음 대사")
	Story.skip()
	Story.play("흔적")
	await get_tree().process_frame
	_check(main.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is StoryCues.ChallengerRelic).size() == 1, "[장면] 도전자의흔적: 용사 곁에 녹슨 갑옷과 일지가 놓임")
	Story.skip()
	# 실제 대본
	Story.load_file(Story.STORY_PATH)
	var speakers_ok := true
	for key in ["1스테이지 도착", "5스테이지 보스 등장", "7스테이지 도착", "10스테이지 보스 등장", "26스테이지 도착", "31스테이지 상인", "36스테이지 상인", "46스테이지 도착", "50스테이지 보스 토벌", "51스테이지 도착", "63스테이지 상인", "68스테이지 도착", "88스테이지 도착", "91스테이지 상인", "95스테이지 보스 토벌", "97스테이지 보스 토벌", "98스테이지 보스 토벌", "99스테이지 상인", "99스테이지 보스 토벌", "100스테이지 보스 토벌", "히든 보스 토벌", "최종장 등장", "최종장 정체", "최종장 2페이즈", "최종장 토벌", "상인"]:
		_check(Story.has_lines(key), "대본 [%s] 에 대사가 있음" % key)
		for l in Story.resolve_lines(key):
			if l.has("cue"):
				continue
			if l["name"] != "" and Story.portrait_for(l["face"]) == null:
				speakers_ok = false
				print("    초상화 없음: [%s] %s" % [key, l["face"]])
	_check(speakers_ok, "대본의 모든 이름에 초상화가 있음")
	_check(Story.resolve_lines("5스테이지 보스 등장")[0]["name"] != Story.BOSS_WORD and Story.resolve_lines("51스테이지 도착")[0]["face"] == "상인[미소]" and Story.resolve_lines("100스테이지 보스 토벌").any(func(l: Dictionary) -> bool: return l.get("cue", "") == "장비빛남"), "대본: 「보스」 이름 · 51스테이지 상인의 미소 · 100스테이지 장비빛남 연출")
	Story.reset()
	Story.load_file(Story.STORY_PATH)
	Story.enabled = false


## 튜토리얼 한 바퀴 + ESC 설정창 + 저장 / 이어하기
func _test_tutorial_and_save() -> void:
	print("[튜토리얼]")
	_gm.start_new_game(_gm.Difficulty.NORMAL)
	_gm.tutorial_mode = true
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(3)
	var tutorial := main.get_node_or_null("Tutorial") as TutorialDirector
	var pause_menu := main.get_node("PauseMenu") as PauseMenu
	var player := main.get_node("Entities/Player") as Player
	_check(tutorial != null and tutorial.get_step_id() == "move" and not Story.enabled, "튜토리얼 모드로 메인 씬 → 1단계 「이동」 (이야기 대사는 끔)")
	if tutorial == null:
		main.queue_free()
		return
	tutorial.return_to_title = false
	await _frames(30)
	Input.action_press(&"move_right")
	await _frames(50)
	Input.action_release(&"move_right")
	await _frames(2)
	_check(tutorial.get_step_id() == "attack", "움직이면 → 「공격」")
	Input.action_press(&"attack")
	await _frames(110)
	Input.action_release(&"attack")
	await _frames(2)
	_check(tutorial.get_step_id() == "dash", "좌클릭 공격 3번 → 「대시」")
	Input.action_press(&"move_right")
	await _press_action(&"dash")
	Input.action_release(&"move_right")
	await _frames(2)
	_check(tutorial.get_step_id() == "guard", "대시 → 「가드」")
	await _frames(40)
	Input.action_press(&"guard")
	await _frames(50)
	Input.action_release(&"guard")
	await _frames(2)
	_check(tutorial.get_step_id() == "switch" and _gm.weapon_slots[1] != null and _gm.active_weapon_slot == _gm.WeaponSlot.BOW, "가드를 누르고 있으면 → 「무기 전환」 (연습용 활을 손에 듦)")
	await _press_action(&"weapon_slot_1")
	await _frames(2)
	_check(tutorial.get_step_id() == "potion" and _gm.hp < _gm.max_hp, "1 키로 검 → 「포션」 (체력이 깎임)")
	await _press_action(&"use_potion")
	await _frames(2)
	_check(tutorial.get_step_id() == "inventory", "H 로 포션 → 「인벤토리」")
	await _press_action(&"inventory")
	await _frames(2)
	await _press_action(&"inventory")
	await _frames(3)
	_check(tutorial.get_step_id() == "shop", "인벤토리를 열었다 닫으면 → 「상점」")
	_gm.request_shop("상점", [])
	await _frames(2)
	(main.get_node("ShopUI") as ShopUI).close()
	_check(tutorial.get_step_id() == "hunt", "상점을 열면 → 「사냥」")
	for i in tutorial.KILL_TARGET:
		_gm.report_kill()
	for _i in 60:  # 튜토리얼은 매 프레임 처치 수를 봄 — 엔진 버전에 따라 몇 프레임 늦을 수 있음
		if tutorial.get_step_id() == "done":
			break
		await _frames(1)
	_check(tutorial.get_step_id() == "done", "몬스터 %d마리 → 「완료」" % tutorial.KILL_TARGET)
	await _frames(int(tutorial.DONE_DELAY * 60) + 10)
	_check(Profile.tutorial_done and not _gm.tutorial_mode and _gm.weapon_slots[1] == null, "튜토리얼 완료 → 프로필에 기록, 튜토리얼에서 받은 것은 초기화 → 타이틀로")

	print("[ESC 설정창 · 저장]")
	_gm.reset_game()
	await _press_action(&"ui_cancel")
	_check(pause_menu.is_open() and get_tree().paused, "게임 도중 ESC → 일시정지 · 설정창")
	pause_menu.show_settings()
	_check(pause_menu.is_settings_open(), "설정 화면 (화면 흔들림 · 전체 화면 · 대사 속도)")
	pause_menu._shake_check.button_pressed = false
	player.shake_camera(6.0)
	_check(not bool(Profile.get_setting("screen_shake")) and player._shake_strength == 0.0, "화면 흔들림 끄기 → 흔들리지 않음 (설정 저장)")
	pause_menu._shake_check.button_pressed = true
	var speed0 := float(Profile.get_setting("text_speed"))
	pause_menu.cycle_text_speed()
	_check(not is_equal_approx(float(Profile.get_setting("text_speed")), speed0) and pause_menu._speed_button.text.begins_with("대사 속도"), "대사 속도 바꾸기 (%s)" % pause_menu._speed_button.text)
	_check(pause_menu.volume_sliders.has("master_volume") and pause_menu.volume_sliders.has("bgm_volume") and pause_menu.volume_sliders.has("sfx_volume")
		and pause_menu.volume_sliders.has("voice_volume"), "설정: 마스터 음량 · 배경음 · 효과음 · 음성 채팅 음량 슬라이더")
	(pause_menu.volume_sliders["voice_volume"] as HSlider).value = 50.0
	_check(is_equal_approx(VoiceChat.playback_db(), 2.0 + linear_to_db(0.5)), "음성 채팅 음량 50% → 동료 목소리 작게")
	(pause_menu.volume_sliders["voice_volume"] as HSlider).value = 100.0
	(pause_menu.volume_sliders["bgm_volume"] as HSlider).value = 35.0
	(pause_menu.volume_sliders["master_volume"] as HSlider).value = 50.0
	_check(is_equal_approx(float(Profile.get_setting("bgm_volume")), 0.35) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.5),
		"슬라이더를 끌면 바로 적용 · 저장 (배경음 35% · 마스터 50% → Master 버스)")
	(pause_menu.volume_sliders["master_volume"] as HSlider).value = 0.0
	_check(AudioServer.is_bus_mute(0), "마스터 0% → 모든 소리 끔")
	(pause_menu.volume_sliders["master_volume"] as HSlider).value = 100.0
	(pause_menu.volume_sliders["bgm_volume"] as HSlider).value = 70.0
	_check(pause_menu._voice_option.item_count == 3 and pause_menu._voice_option.get_item_text(0) == "끄기" and pause_menu._voice_option.get_item_text(1).begins_with("눌러서 말하기")
		and pause_menu._voice_option.get_item_text(2) == "항상 켜기", "설정: 음성 채팅 끄기 / 눌러서 말하기 [T] / 항상 켜기")
	var voice_before := VoiceChat.get_mode()
	pause_menu._voice_option.item_selected.emit(0)
	_check(VoiceChat.get_mode() == 0, "음성 채팅 끄기 선택 → 적용")
	pause_menu.set_voice_mode(voice_before)
	Profile.set_setting("text_speed", 1.0)
	pause_menu._story_check.button_pressed = false
	Story.enabled = true
	_check(not bool(Profile.get_setting("story")) and not Story.play("1스테이지 도착", "*") and not Story.is_playing(), "설정에서 「스토리 대사」 끄기 → 대사가 나오지 않음")
	Story.enabled = false
	pause_menu._story_check.button_pressed = true
	_check(bool(Profile.get_setting("story")), "다시 켜기")
	await _press_action(&"ui_cancel")
	_check(pause_menu.is_open() and not pause_menu.is_settings_open(), "설정에서 ESC → 일시정지 메뉴로")
	# 저장할 모험 만들기
	_gm.stage = 7
	_gm.gold = 12345
	for id in [&"knight_sword", &"mithril_ring", &"knight_crossbow"]:
		_gm.add_item(ItemDB.get_item(id))
		_gm.equip_item(ItemDB.get_item(id))
	_gm.add_potion(ItemDB.get_item(&"potion") as PotionData, 3)
	_gm.dragon_scales.assign([30, 31])
	_gm.total_kills = 321
	Story.set_played_marks(["1스테이지 도착", "7스테이지 도착"])
	var potions_before: int = _gm.get_potion_count(&"potion")
	_check(pause_menu.save_now() and Profile.has_save(), "「저장하기」 → 저장 파일 생성")
	_gm.is_player_dead = true
	pause_menu._refresh_save_button()
	_check(not pause_menu.save_now() and pause_menu._save_button.disabled, "쓰러진 상태에서는 저장할 수 없음")
	_gm.is_player_dead = false
	pause_menu.close()
	_check(not get_tree().paused, "계속하기 → 게임 재개")
	_gm.reset_game()
	Story.reset()
	_check(_gm.stage == 1 and not _gm.owns_item(&"knight_sword"), "(초기화)")
	_check(Profile.get_save_summary().begins_with("7스테이지") and Profile.load_game(), "이어하기 요약: %s" % Profile.get_save_summary())
	_check(_gm.stage == 7 and _gm.gold == 12345 and _gm.weapon_slots[0].id == &"knight_sword" and _gm.weapon_slots[1].id == &"knight_crossbow"
		and _gm.accessory_slots[1] != null and _gm.accessory_slots[1].id == &"mithril_ring" and _gm.get_potion_count(&"potion") == potions_before
		and _gm.dragon_scales == [30, 31] and _gm.total_kills == 321 and _gm.hp == _gm.max_hp and _gm.equipped_shield != null,
		"불러오기: 스테이지 · 골드 · 장비 · 장신구 · 포션 · 비늘 · 처치 수 복원, 체력은 가득")
	_check(Story.was_played("7스테이지 도착") and not Story.was_played("8스테이지 도착"), "본 대사 기록도 복원")
	var title: Control = (load("res://scenes/title/title.tscn") as PackedScene).instantiate()
	title.scene_changes = false
	get_tree().root.add_child(title)
	await get_tree().process_frame
	title.open_single()
	_check(not (title.get_node("%ContinueButton") as Button).disabled and (title.get_node("%SaveInfo") as Label).text.contains("7스테이지"), "타이틀 싱글플레이: 이어하기 활성 (%s)" % (title.get_node("%SaveInfo") as Label).text)
	_gm.reset_game()
	_check(title.continue_game() and _gm.stage == 7 and title.last_scene_request == title.MAIN_SCENE, "이어하기 → 7스테이지 야영지부터")
	title.queue_free()
	Profile.delete_save()
	_check(not Profile.has_save(), "저장 파일 삭제")
	main.queue_free()
	await _frames(3)
	get_tree().paused = false
	Story.enabled = false
	_gm.reset_game()


func _test_gear(main: Node2D) -> void:
	print("[장비 · 등급 · 세트 · 신화 · 딜 인플레]")
	var stage := main.get_node("StageManager") as StageManager
	var player := main.get_node("Entities/Player") as Player
	var shop_ui := main.get_node("ShopUI") as ShopUI
	_check(Balance.K == 10 and _gm.BASE_MAX_HP == 1000, "딜 인플레: 전투 수치 ×%d · 기본 체력 %d" % [Balance.K, _gm.BASE_MAX_HP])
	_check(ItemData.max_rarity_for_stage(1) == ItemData.Rarity.COMMON and ItemData.max_rarity_for_stage(10) == ItemData.Rarity.COMMON
		and ItemData.max_rarity_for_stage(11) == ItemData.Rarity.RARE and ItemData.max_rarity_for_stage(40) == ItemData.Rarity.RARE
		and ItemData.max_rarity_for_stage(41) == ItemData.Rarity.EPIC and ItemData.max_rarity_for_stage(70) == ItemData.Rarity.EPIC
		and ItemData.max_rarity_for_stage(71) == ItemData.Rarity.LEGENDARY and ItemData.max_rarity_for_stage(100) == ItemData.Rarity.LEGENDARY,
		"상점 해금: 1~10 일반 · 11~40 희귀 · 41~70 레어 · 71~100 전설")
	# 종류 × 등급마다 하급 · 중하급 · 중급 · 중상급 · 상급, 윗 단계일수록 강하고 비쌈
	var shop_items := ItemDB.get_shop_items()
	var grid_ok := true
	var order_ok := true
	for cat in range(ShopUI.Category.SWORD, ShopUI.Category.PENDANT + 1):
		for r in 4:
			var tiers: Array[ItemData] = []
			for item in shop_items:
				if ShopUI.category_of(item) == cat and item.rarity == r:
					tiers.append(item)
			if tiers.size() != 5:
				grid_ok = false
				print("    %s %s: %d개" % [ShopUI.CATEGORY_NAMES[cat], ItemData.RARITY_NAMES[r], tiers.size()])
				continue
			tiers.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.tier < b.tier)
			for i in 5:
				if int(tiers[i].tier) != i:
					grid_ok = false
				if i > 0 and tiers[i - 1].price > tiers[i].price:
					order_ok = false
			if not order_ok:
				print("    값 순서: %s" % [tiers.map(func(x: ItemData) -> String: return "%s %d" % [x.display_name, x.price])])
	_check(grid_ok and shop_items.filter(func(it: ItemData) -> bool: return not (it is PotionData)).size() == 200, "장비 10종류 × 4등급마다 5단계씩 (상점 %d개)" % shop_items.size())
	_check(order_ok, "같은 등급 안에서 윗 단계일수록 비쌈")
	var drop_only: Array = ItemDB.get_all().filter(func(it: ItemData) -> bool: return it.is_drop_only())
	var drop_grid := true
	for r in 4:
		var cats := {}
		for it in drop_only:
			if it.rarity == r:
				cats[ShopUI.category_of(it)] = true
		drop_grid = drop_grid and cats.size() == 10
	_check(drop_only.size() == 40 and drop_grid and not drop_only.any(func(it: ItemData) -> bool: return shop_items.has(it)), "드랍 전용 장비 40개 (등급마다 종류별 하나 · 상점에 없음)")
	var swords: Array = shop_items.filter(func(it: ItemData) -> bool: return ShopUI.category_of(it) == ShopUI.Category.SWORD)
	swords.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.get_fit_stage() < b.get_fit_stage())
	var rising := true
	for i in range(1, swords.size()):
		rising = rising and (swords[i] as WeaponData).damage > (swords[i - 1] as WeaponData).damage
	_check(rising and (swords.back() as WeaponData).damage >= 5000, "검 공격력이 단계마다 오름 (%d → %d)" % [(swords[0] as WeaponData).damage, (swords.back() as WeaponData).damage])
	var mithril := ItemDB.get_item(&"mithril_sword")
	_check(mithril.get_grade_text() == "희귀" and mithril.get_fit_stage() == 31 and ItemDB.get_item(&"rusty_sword").get_grade_text() == "일반"
		and ItemDB.get_item(&"abyss_sword").get_grade_text() == "레어 · 드랍", "등급 표시: 단계는 숨기고 등급만 ([희귀] 미스릴 검 · [레어 · 드랍] 심연의 검)")
	# 상점 탭
	_gm.request_shop("상점", [])
	await get_tree().process_frame
	shop_ui.set_category(ShopUI.Category.BOW)
	var bows := shop_ui.get_visible_stock()
	_check(shop_ui.visible and bows.size() == 20 and bows.all(func(it: ItemData) -> bool: return it is WeaponData and (it as WeaponData).is_bow()), "상점 탭: 활 탭에는 활 20개만")
	shop_ui.set_category(ShopUI.Category.POTION)
	_check(shop_ui.get_visible_stock().all(func(it: ItemData) -> bool: return it is PotionData) and shop_ui.get_visible_stock().size() == 4, "포션 탭 (작은 · 보통 · 고급 · 전설의 엘릭서)")
	var tab_names := PackedStringArray()
	for b in shop_ui.get_node("%CategoryTabs").get_children():
		tab_names.append((b as Button).text)
	_check(tab_names.size() == 12 and tab_names[0] == "전체" and tab_names[2] == "검" and tab_names[4] == "지팡이", "탭 12개 (맨 앞 「전체」): %s" % " · ".join(tab_names))
	shop_ui.set_category(ShopUI.Category.ALL)
	var all_stock := shop_ui.get_visible_stock()
	_check(all_stock.size() == shop_items.size() and all_stock[0] is PotionData and all_stock.back() is AccessoryData, "「전체」 탭: 모든 장비 · 포션 %d개를 종류 순서대로" % all_stock.size())
	_gm.gold = 999999
	_check(not _gm.buy_item(mithril) and not _gm.owns_item(&"mithril_sword"), "1스테이지에서는 희귀 장비를 살 수 없음 (11스테이지부터)")
	_check(_gm.buy_item(ItemDB.get_item(&"bronze_sword")) and _gm.weapon_slots[0].id == &"bronze_sword", "일반 상급 청동 검 구매 → 바로 장착")
	shop_ui.close()
	# 세트 효과
	var def0: int = _gm.get_total_defense()
	_gm.add_item(ItemDB.get_item(&"bronze_shield"))
	_gm.equip_item(ItemDB.get_item(&"bronze_shield"))
	var bronze := ItemSets.SETS[&"bronze"]
	_check(int(_gm.get_set_counts().get(&"bronze", 0)) == 2 and _gm.get_total_defense() == ItemDB.get_item(&"bronze_shield").defense + int(bronze["bonuses"][0][1]["defense"]),
		"세트 효과: 청동 2개 → 방어력 +%d (%d → %d)" % [int(bronze["bonuses"][0][1]["defense"]), def0, _gm.get_total_defense()])
	var atk0: float = _gm.damage_multiplier
	for id in [&"bronze_helmet", &"bronze_armor"]:
		_gm.add_item(ItemDB.get_item(id))
		_gm.equip_item(ItemDB.get_item(id))
	_check(is_equal_approx(_gm.damage_multiplier, atk0 + 0.05) and ItemSets.describe(&"bronze").contains("청동 세트 4/10"), "청동 4개 → 공격력 +5%% (%s)" % ItemSets.describe(&"bronze"))
	var set_tiers_ok := true
	for r in 4:
		for t in [ItemData.Tier.MID_LOW, ItemData.Tier.MID, ItemData.Tier.MID_HIGH, ItemData.Tier.HIGH]:
			if r == ItemData.Rarity.COMMON and t == ItemData.Tier.MID:
				continue
			var tier_items := ItemDB.get_all().filter(func(it: ItemData) -> bool: return it.rarity == r and it.tier == t and it.in_shop and not (it is PotionData))
			var ids := {}
			for it in tier_items:
				ids[(it as ItemData).set_id] = true
			if ids.size() != 1 or ids.has(&"") or not ItemSets.SETS.has(ids.keys()[0]) or ItemSets.get_piece_count(ids.keys()[0]) != 10:
				set_tiers_ok = false
				print("    세트 없음/섞임: %s %s → %s" % [ItemData.RARITY_NAMES[r], ItemData.TIER_NAMES[t], str(ids.keys())])
	_check(set_tiers_ok and ItemSets.SETS.size() == 16, "중하급 · 중상급에도 세트 (등급마다 4세트 · 일반은 중급 대신 3세트 · 세트마다 10부위, 모두 %d세트)" % ItemSets.SETS.size())
	for id in [&"militia_helmet", &"militia_armor"]:
		_gm.add_item(ItemDB.get_item(id))
	var counts_before: Dictionary = _gm.get_set_counts()
	_check(not counts_before.has(&"militia"), "민병대 장비는 가방에 있을 땐 세트로 안 셈")
	# 경제: 스테이지 수입 곡선 · 처치 골드 · 장비 값
	var income_ok := true
	for st in range(2, 101):
		if Balance.stage_income(st) <= Balance.stage_income(st - 1):
			income_ok = false
	_check(income_ok and is_equal_approx(Balance.MOB_SHARE + Balance.BOSS_SHARE + Balance.CHEST_SHARE, 1.0) and roundi(Balance.stage_income(1)) == 220 and Balance.stage_income(100) > 40000.0,
		"골드 수입 곡선: 스테이지마다 늘어남 (1스테이지 %d · 50스테이지 %d · 100스테이지 %d) = 몬스터 45%% + 보스 25%% + 상자 30%%" % [roundi(Balance.stage_income(1)), roundi(Balance.stage_income(50)), roundi(Balance.stage_income(100))])
	var price_ok := true
	for item in ItemDB.get_all():
		var cat := ItemDB.price_category(item)
		if cat == "" or item.is_mythic():
			continue
		var stages_worth := float(item.price) / Balance.stage_income(item.get_fit_stage())
		var want := float(Balance.PRICE_STAGES[cat]) * (Balance.COMMON_PRICE_MULT if item.rarity == ItemData.Rarity.COMMON else 1.0) * (1.0 if item.in_shop else Balance.DROP_ONLY_PRICE_MULT) * Balance.PRICE_MULT
		if absf(stages_worth - want) > 0.05 * want + 0.02:
			price_ok = false
			print("    값 어긋남: %s %d (%.2f스테이지 수입, 목표 %.2f)" % [item.display_name, item.price, stages_worth, want])
	_check(price_ok, "장비 값 = 그 장비가 쓰일 스테이지 수입 × 비중 × %.0f (무기 %.1f · 갑옷 %.1f스테이지)" % [Balance.PRICE_MULT, Balance.PRICE_STAGES["sword"] * Balance.PRICE_MULT, Balance.PRICE_STAGES["armor"] * Balance.PRICE_MULT])
	var genesis_sword := ItemDB.get_item(&"genesis_sword")
	var holy_sword := ItemDB.get_item(&"holy_sword")
	_check(genesis_sword.price > holy_sword.price and genesis_sword.price > roundi(Balance.stage_income(90)) and ItemDB.get_item(&"ancient_sword").price > ItemDB.get_item(&"seraph_sword").price,
		"전설 무기도 후반 수입에 맞춰 비쌈 (성검 %d · 창세의 검 %d) · 드랍 전용은 같은 단계 상점 장비보다 비쌈" % [holy_sword.price, genesis_sword.price])
	var easy_mob := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	stage._apply_gold(easy_mob, false)
	var mob_center := Balance.mob_gold(_gm.stage, stage.get_stage_data().kill_target) * stage.get_gold_multiplier()
	_check(absf((easy_mob.gold_min + easy_mob.gold_max) * 0.5 - mob_center) <= 1.0 and easy_mob.gold_max > easy_mob.gold_min, "사냥터 몬스터 골드 = 스테이지 수입 × 45%% ÷ 처치 목표 (%d~%d)" % [easy_mob.gold_min, easy_mob.gold_max])
	var minion_gold := easy_mob.duplicate() as Enemy
	stage._apply_gold(minion_gold, true)
	_check(minion_gold.gold_max < easy_mob.gold_max, "보스가 부른 졸개는 골드가 적음 (%d)" % minion_gold.gold_max)
	var decoy := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	decoy.gold_min = 0
	decoy.gold_max = 0
	stage._apply_gold(decoy, false)
	_check(decoy.gold_max == 0, "골드 0 으로 정해 둔 것(분신 · 미끼)은 그대로 0")
	easy_mob.free()
	minion_gold.free()
	decoy.free()
	_check(_gm.DIFFICULTY_INFO[_gm.Difficulty.HARD]["gold"] == 1.0 and _gm.DIFFICULTY_INFO[_gm.Difficulty.VERY_HARD]["gold"] == 1.0 and is_equal_approx(Balance.party_gold_multiplier(4), 2.8)
		and _gm.DIFFICULTY_INFO[_gm.Difficulty.VERY_HARD]["enemy_hp"] > _gm.DIFFICULTY_INFO[_gm.Difficulty.HARD]["enemy_hp"] and _gm.DIFFICULTY_INFO[_gm.Difficulty.HARD]["enemy_damage"] > 1.0,
		"골드는 난이도와 상관없이 같음 (하드 · 베리하드는 몬스터만 강해짐) · 4명이면 총량 x2.8 (먼저 줍는 사람이)")
	# 피해 ×10
	var hp0: int = _gm.hp
	player._invincible_left = 0.0
	player.take_hit(50, player.global_position + Vector2(20, 0))
	_check(hp0 - _gm.hp == mini(maxi(1, 50 * Balance.K - player.get_effective_defense()), _gm.get_hit_cap()), "몬스터 공격 50 → 실제 %d 피해 (×%d − 방어력 %d, 한 방 상한 %d)" % [hp0 - _gm.hp, Balance.K, player.get_effective_defense(), _gm.get_hit_cap()])
	_gm.heal_full()
	player._invincible_left = 0.0
	var hp_cap0: int = _gm.hp
	player.take_hit(5000, player.global_position + Vector2(20, 0))
	_check(hp_cap0 - _gm.hp == _gm.get_hit_cap() and _gm.hp > 0 and _gm.get_hit_cap() == roundi(_gm.max_hp * 0.35),
		"한 방 상한: 아무리 센 공격도 노멀에선 최대 체력의 35%%까지 (%d) — 한 대에 쓰러지지 않음" % (hp_cap0 - _gm.hp))
	_check(_gm.DIFFICULTY_INFO[_gm.Difficulty.NORMAL]["enemy_damage"] < 1.0 and _gm.DIFFICULTY_INFO[_gm.Difficulty.HARD]["hit_cap"] == 0.5 and _gm.DIFFICULTY_INFO[_gm.Difficulty.VERY_HARD]["hit_cap"] == 0.75,
		"난이도 완화: 노멀 몬스터 공격력 x0.7 · 한 방 상한 노멀 35%% / 하드 50%% / 베리하드 75%%")
	_gm.heal_full()
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	var slime_hp: int = slime.max_hp
	slime.apply_difficulty(_gm.get_difficulty_info())
	_check(slime.max_hp == slime_hp * Balance.K and slime.calc_damage(1000) == 1000 - slime.defense * Balance.K, "몬스터 체력 ×%d (%d) · 방어력 ×%d (%d)" % [Balance.K, slime.max_hp, Balance.K, slime.get_defense_value()])
	slime.free()
	# 드랍 · 보물상자 단계
	var pool11 := ItemDB.get_drop_pool(11)
	var pool35 := ItemDB.get_drop_pool(35)
	_check(not pool11.is_empty() and pool11.all(func(it: ItemData) -> bool: return it.rarity == ItemData.Rarity.RARE and it.tier == ItemData.Tier.LOW)
		and pool35.any(func(it: ItemData) -> bool: return it.tier == ItemData.Tier.HIGH) and pool35.all(func(it: ItemData) -> bool: return not it.is_mythic()),
		"몬스터 드랍: 11스테이지는 희귀 하급만, 35스테이지는 상급까지 (신화 없음)")
	_check(pool35.any(func(it: ItemData) -> bool: return it.is_drop_only()) and not pool11.any(func(it: ItemData) -> bool: return it.is_drop_only())
		and not pool35.any(func(it: ItemData) -> bool: return ItemDB.MONSTER_ONLY.has(it.id)), "드랍 전용 장비도 몬스터가 떨어뜨림 (희귀는 21스테이지부터)")
	_check(ItemDB.get_drop_pool(1, [&"goblin_dagger"]).any(func(it: ItemData) -> bool: return it.id == &"goblin_dagger"), "고블린 단검 같은 드랍 전용 장비는 그 몬스터만 떨어뜨림")
	# 신화
	var mythics: Array = ItemDB.get_all().filter(func(it: ItemData) -> bool: return it.is_mythic() and not (it is PotionData) and not (it is RelicData))
	var stage_ok := true
	for s in range(10, 101, 10):
		var m := ItemDB.get_mythic_for_stage(s)
		stage_ok = stage_ok and m != null and m.is_mythic() and not m.in_shop
	_check(mythics.size() == 10 and stage_ok and ItemDB.get_mythic_for_stage(10).id == &"king_pendant" and ItemDB.get_mythic_for_stage(100).id == &"gabriel_ring"
		and ItemDB.get_mythic_for_stage(55) == null and not ItemDB.get_shop_items().any(func(it: ItemData) -> bool: return it.is_mythic()),
		"신화 장비 10개 — 10스테이지마다 보스가 하나씩 (상점에 없음)")
	var abaddon := ItemDB.get_item(&"abaddon_sword") as WeaponData
	_check(abaddon.damage > (ItemDB.get_item(&"genesis_sword") as WeaponData).damage * 1.5 and abaddon.get_grade_text() == "신화", "신화 아바돈의 검 공격력 %d (전설 상급 창세의 검 %d)" % [abaddon.damage, (ItemDB.get_item(&"genesis_sword") as WeaponData).damage])
	_gm.stage = 10
	stage._boss_fall_position = player.global_position
	stage._grant_mythic(10)
	var pendant := ItemDB.get_item(&"king_pendant")
	_check(_gm.owns_item(&"king_pendant") and pendant.is_sealed(), "10스테이지 보스 → 왕의 펜던트 (봉인)")
	_check(not _gm.equip_item(pendant) and not _gm.is_equipped(pendant) and not _gm.can_sell(pendant), "봉인된 신화 장비는 착용 · 판매 불가")
	_gm.stage = 100
	stage._grant_mythic(100)
	_check(_gm.mythic_unlocked and _gm.owns_item(&"gabriel_ring") and not pendant.is_sealed() and _gm.equip_item(pendant) and _gm.is_equipped(pendant),
		"100스테이지 보스 → 가브리엘의 반지 + 봉인 해제 → 착용 가능")
	_check(StoryCues.equipment_icons().size() == 2, "100스테이지 「장비빛남」은 받은 신화 장비들이 빛남")
	for item in mythics:
		_gm.add_item(item)
		_gm.equip_item(item)
	_check(int(_gm.get_set_counts().get(&"mythic", 0)) == 10 and is_equal_approx(_gm.get_master_damage_bonus(), 0.3) and _gm.get_damage_reduction() > 0.0,
		"신화의 유산 10세트: 「억제의 권능」 멀티버스의 주인에게 주는 피해 +30%% · 받는 피해 -%d%%" % roundi(_gm.get_damage_reduction() * 100.0))
	_check(_gm.weapon_slots[0].id == &"abaddon_sword" and player.get_dash_cooldown() < player.dash_cooldown, "헤르메스의 신발: 대시 대기시간 %.2f초 → %.2f초" % [player.dash_cooldown, player.get_dash_cooldown()])
	var inv_ui := main.get_node("InventoryUI")
	inv_ui.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var inv_panel := inv_ui.get_node("Panel") as Control
	_check(Rect2(Vector2.ZERO, inv_panel.get_viewport_rect().size).encloses(inv_panel.get_global_rect()), "긴 장비 이름 · 세트 설명이 있어도 인벤토리 창이 화면 안에 (%s)" % inv_panel.get_global_rect())
	inv_ui.close()
	# 사용 아이템 · 포션
	var elixir := ItemDB.get_potion(&"elixir")
	_check(elixir.rarity == ItemData.Rarity.LEGENDARY and elixir.get_unlock_stage() == 71 and ItemDB.get_shop_items().has(elixir) and elixir.get_heal(_gm.max_hp) >= _gm.max_hp, "전설 포션 「전설의 엘릭서」: 71스테이지부터 상점 · 체력 전부 + 재생")
	# [G] 마실 포션 고르기: 여러 등급을 섞어 가지면 원하는 것으로 고정
	var saved_potions: Dictionary = _gm.potions.duplicate()
	_gm.potions = {&"small_potion": 2, &"potion": 1, &"greater_potion": 1}
	_gm.selected_potion = &""
	_gm.hp = _gm.max_hp - 1
	_check(_gm.is_potion_auto() and _gm.choose_potion().id == &"small_potion", "[G] 처음엔 자동 — 조금 다치면 작은 포션")
	_check(_gm.cycle_potion() == &"small_potion" and _gm.cycle_potion() == &"potion" and _gm.choose_potion().id == &"potion" and not _gm.is_potion_auto(),
		"[G] 누를 때마다 작은 → 회복 포션으로 고정 (체력이 거의 차 있어도 고른 것을 마심)")
	_check(_gm.use_potion() and _gm.get_potion_count(&"potion") == 0 and _gm.is_potion_auto() and _gm.choose_potion() != null, "고른 포션을 다 마시면 다시 자동")
	_gm.selected_potion = &"greater_potion"
	_check(StringName(_gm.to_save_data().get("selected_potion", "")) == &"greater_potion", "고른 포션은 저장됨")
	_gm.cycle_potion()
	_check(_gm.is_potion_auto(), "[G] 마지막(고급 포션) 다음은 다시 자동")
	_gm.potions = saved_potions
	_gm.selected_potion = &""
	_gm.hp = _gm.max_hp
	var blood := ItemDB.get_potion(&"dragon_blood")
	_gm.add_potion(blood, 5)
	_check(blood.is_mythic() and not ItemDB.get_shop_items().has(blood) and _gm.choose_potion() != blood and _gm.get_potion_count(&"dragon_blood") == 5, "고대 용의 피: 신화 · 상점에 없음 · [H] 자동 선택에서 빠짐 (5병)")
	player.apply_burn(10, 5.0)
	_gm.damage_player(roundi(_gm.max_hp * 0.8))
	_check(_gm.use_potion(blood) and _gm.hp == _gm.max_hp and not player.is_burning() and _gm.has_buff(blood.display_name) and _gm.get_damage_reduction() >= 0.3,
		"고대 용의 피: 체력 전부 · 상태 이상 해제 · %d초 재생 + 받는 피해 -%d%% + 공격력 +%d%%" % [roundi(blood.buff_duration), roundi(blood.buff_reduction * 100.0), roundi(blood.buff_attack * 100.0)])
	_gm.damage_player(500)
	var hp_regen0: int = _gm.hp
	await _frames(40)
	_check(_gm.hp > hp_regen0, "용의 피 재생: 초당 최대 체력의 %d%%" % roundi(blood.regen_percent * 100.0))
	var flame := ItemDB.get_relic(&"primal_flame")
	var trumpet := ItemDB.get_relic(&"last_trumpet")
	_check(flame.is_mythic() and trumpet.is_mythic() and _gm.has_relic(&"last_trumpet") and not flame.is_sealed(), "신화 사용 아이템: 원초의 불꽃 · 최후의 나팔 (100스테이지 보스가 나팔도 줌)")
	_gm.add_relic(flame)
	var dummy := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	dummy.max_hp = 99999
	dummy.move_speed = 0.0
	stage._add_enemy(dummy, player.global_position + Vector2(40, 0), stage.camp_room.get_arena_rect())
	await _frames(2)
	var atk_mult: float = 1.0 + _gm.faith_damage_bonus + _gm.get_buff_value("attack")
	_check(_gm.use_relic(flame) and _gm.get_buff_value("attack") > atk_mult - 1.0 and _gm.get_buff_value("burn_immune") > 0.0 and not _gm.use_relic(flame), "원초의 불꽃 [Z]: 공격력 +%d%% · 화상 면역 · 다시 쓰려면 %d초" % [roundi(flame.attack_bonus * 100.0), roundi(flame.cooldown)])
	_check(flame.charges == 10 and _gm.get_relic_charges(flame) == 9, "원초의 불꽃: 10개 — 쓰면 하나씩 줄어듦 (남은 %d개)" % _gm.get_relic_charges(flame))
	player.apply_burn(10, 3.0)
	_check(not player.is_burning(), "원초의 불꽃: 화상에 걸리지 않음")
	var dummy_hp := dummy.hp
	Enemy.on_player_hit(dummy, 1000)
	await _frames(40)
	_check(dummy.is_ignited() and dummy.hp < dummy_hp, "원초의 불꽃: 맞힌 적이 불탐 (0.5초마다 일격의 %d%%)" % roundi(flame.burn_ratio * 100.0))
	var mob_hp := dummy.hp
	_check(_gm.use_relic(trumpet) and dummy.is_stunned() and mob_hp - dummy.hp >= roundi(dummy.max_hp * trumpet.normal_damage_ratio) and player._invincible_left > 2.0, "최후의 나팔 [X]: 모든 적 기절 · 일반 몬스터 최대 체력의 %d%% · 용사 무적" % roundi(trumpet.normal_damage_ratio * 100.0))
	_gm.relic_charges[flame.id] = 1
	_gm.relic_cooldowns.clear()
	_check(_gm.use_relic(flame) and not _gm.has_relic(flame.id) and _gm.get_relic_charges(flame) == 0, "원초의 불꽃: 마지막 하나를 쓰면 사라짐")
	_check(_gm.add_relic(flame) and _gm.get_relic_charges(flame) == 10, "다시 얻으면 10개")
	_check(int((_gm.to_save_data()["relic_charges"] as Dictionary).get(flame.id, 0)) == 10, "남은 개수는 저장 파일에도")
	dummy.despawn()
	print("[신화 장비 스테이지 보상]")
	stage.go_to_stage(20)
	stage._do_enter_boss_room()
	await _frames(int(stage.boss_entry_delay * 60) + 20)
	var boss20 := stage.get_boss()
	var count_pickups := func() -> int: return main.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Pickup).size()
	var pickups_before: int = count_pickups.call()
	_check(boss20 != null and stage.is_mythic_reward_stage(), "20스테이지 보스 = 신화 장비 스테이지")
	if boss20 != null:
		boss20.take_damage(999999999)
	await _frames(5)
	_check(stage.get_chest() == null and stage.next_stage_portal.enabled and _gm.owns_item(&"archmage_staff") and count_pickups.call() == pickups_before,
		"신화 장비 스테이지: 보상은 신화 장비(대마법사의 지팡이)뿐 — 보물상자 · 골드 · 장비 드랍 없음 · 텔레포트는 열림")
	stage.go_to_stage(1)
	await _frames(2)
	# 원래대로
	var location: String = _gm.location_name
	var stage_title: String = _gm.stage_name
	_gm.reset_game()
	_gm.stage = 1
	_gm.location_name = location
	_gm.stage_name = stage_title
	await get_tree().process_frame


func _run() -> void:
	_gm = get_node("/root/GameManager")
	Story.enabled = false  # 대본에 대사가 채워져 있어도 자동 테스트가 대화창에서 멈추지 않게

	print("[타이틀 / 이름 / 메뉴 / 난이도]")
	# 실제 저장 파일을 건드리지 않도록 테스트용 경로
	Profile.profile_path = "user://_test_profile.cfg"
	Profile.save_path = "user://_test_save.json"
	for path in [Profile.profile_path, Profile.save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.load_profile()
	var title: Control = (load("res://scenes/title/title.tscn") as PackedScene).instantiate()
	title.scene_changes = false
	get_tree().root.add_child(title)
	await get_tree().process_frame
	_check(title.get_screen() == "name" and not Profile.has_hero_name(), "처음 켜면 용사의 이름부터 정함")
	_check((title.get_node("Background") as TextureRect).texture != null, "전투 배경 일러스트")
	var name_edit := title.get_node("%HeroNameEdit") as LineEdit
	_check(name_edit.max_length == 0, "이름 칸에 글자 수 제한 없음 (한글 입력기와 부딪히지 않게 — 결정할 때 %d자로 자름)" % _gm.HERO_NAME_MAX)
	var samples := {"dydtk": "용사", "gksrmf": "한글", "fostmffht": "랜슬롯", "rkqtdl": "값이", "rkqtl": "갑시", "ekfr": "닭", "dhkdwk": "왕자", "아서 rltk 2": "아서 기사 2"}
	var hangul_ok := true
	for typed in samples:
		if Hangul.from_qwerty(typed) != samples[typed]:
			hangul_ok = false
			print("    ", typed, " → ", Hangul.from_qwerty(typed))
	_check(hangul_ok, "영문 자판으로 친 글자 → 한글 (dydtk → 용사 · fostmffht → 랜슬롯 · 겹받침 · 숫자 그대로)")
	name_edit.text = "fostmffht"
	(title.find_child("HangulButton", true, false) as Button).pressed.emit()
	_check(name_edit.text == "랜슬롯", "이름 칸 아래 [영문 자판 → 한글] 버튼 (한글 입력기가 말썽일 때)")
	# 게임 안 한글 입력: 윈도우 한글 입력기 대신 게임이 자판 위치대로 직접 조합
	HangulInput.set_korean(true)
	name_edit.text = ""
	name_edit.caret_column = 0
	title._name_hangul.type_keys("fostmffh")
	var mid := name_edit.text
	title._name_hangul.type_keys("t")
	var full := name_edit.text
	title._name_hangul.type_keys("<")
	var back := name_edit.text
	title._name_hangul.type_keys("t gksrmf")
	_check(mid == "랜슬로" and full == "랜슬롯" and back == "랜슬로" and name_edit.text == "랜슬롯 한글",
		"이름 칸에서 한글이 여러 글자 들어감 — 치는 대로 조합 (랜슬로 → 랜슬롯, Backspace 는 자모 하나씩) 「%s」" % name_edit.text)
	HangulInput.toggle()
	title._name_hangul.type_keys("ab")
	_check(not HangulInput.korean and name_edit.text == "랜슬롯 한글" and (title.find_child("HangulToggle", true, false) as Button).text == "영",
		"한/영 바꾸기 (Shift+Space · 버튼) — 영문일 때는 그대로 영문 입력")
	HangulInput.set_korean(true)
	name_edit.text = "랜슬롯"
	title.confirm_name()
	_check(_gm.hero_name == "랜슬롯" and Profile.hero_name == "랜슬롯" and title.last_scene_request == title.MAIN_SCENE and _gm.tutorial_mode,
		"이름을 정하면 → 처음 하는 유저라 튜토리얼 시작")
	var cfg := ConfigFile.new()
	_check(cfg.load(Profile.profile_path) == OK and cfg.get_value("player", "hero_name", "") == "랜슬롯" and not cfg.get_value("player", "tutorial_done", true), "이름은 프로필 파일에 저장 (튜토리얼은 아직)")
	_gm.tutorial_mode = false
	Profile.complete_tutorial()
	title.queue_free()
	await get_tree().process_frame
	title = (load("res://scenes/title/title.tscn") as PackedScene).instantiate()
	title.scene_changes = false
	get_tree().root.add_child(title)
	await get_tree().process_frame
	_check(title.get_screen() == "menu" and (title.get_node("%HeroLabel") as Label).text.contains("랜슬롯"), "다시 켜면 이름 · 튜토리얼 없이 메뉴 (싱글 / 멀티)")
	(title.get_node("%MultiButton") as Button).pressed.emit()
	_check(title.get_screen() == "multi" and not Net.is_online(), "멀티플레이 → 방 만들기 / IP 로 참가 화면")
	# 초대 코드 (주소 · 포트 · 방 열쇠를 13글자로)
	var code := NetInvite.encode("192.168.0.10", 24570, 4321)
	var decoded := NetInvite.decode(code)
	_check(code.length() == 15 and decoded == {"ip": "192.168.0.10", "port": 24570, "key": 4321}, "초대 코드 만들기 · 풀기: %s" % code)
	_check(NetInvite.decode(code.to_lower().replace("0", "o")) == decoded and NetInvite.decode("ABCD") == {} and NetInvite.encode("not an ip", 1, 1) == ""
		and NetInvite.looks_like_code(code) and not NetInvite.looks_like_code("192.168.0.10"), "소문자 · 헷갈리는 글자(O→0)도 읽음, 잘못된 코드는 거절")
	_check(NetInvite.decode(NetInvite.encode("10.0.0.255", 24570, 65535))["ip"] == "10.0.0.255" and NetInvite.decode(NetInvite.encode("255.255.255.254", 65000, 1))["port"] == 65000, "주소 끝까지 (255 · 65535)")
	Net.port = 24600 + randi() % 900
	_check(title.host_room(false) and Net.is_host() and Net.players.size() == 1 and title._multi_lobby.visible and title._lobby_start.visible and not Net.room_public,
		"비공개 방 만들기 → 대기실 (방장 1명 · 난이도 · 시작 버튼, 포트 %d)" % Net.port)
	var room_code := Net.get_invite_code("127.0.0.1")
	_check(NetInvite.decode(room_code)["key"] == Net.room_key and Net.room_key > 0 and title._lobby_code.text.contains("초대 코드") and title._lobby_info.text.contains("비공개"),
		"대기실에 초대 코드 (방 열쇠 포함) · 「비공개 방」 안내")
	_check(title.copy_invite_code() == Net.get_invite_code(), "코드 복사")
	title._cycle_lobby_difficulty()
	_check(Net.difficulty == 1 and title._lobby_difficulty.text.contains("하드"), "방장이 대기실에서 난이도 바꾸기")
	title.leave_room()
	_check(not Net.is_online() and title._multi_connect.visible, "방 나가기")
	Net.difficulty = 0
	_check(not title.join_room("") and title._multi_status.text.contains("초대 코드"), "코드를 비우면 안내")
	_check(not title.join_room("ZZZZ-ZZZZ-ZZZZZ") and title._multi_status.text.contains("올바르지"), "잘못된 초대 코드는 안내")
	# 공개 방: 같은 네트워크에 방 정보를 뿌림 → 공개 방 목록
	title._finder.stop()
	var finder := RoomFinder.new()
	get_tree().root.add_child(finder)
	var listening := finder.start()
	Net.discovery_targets = ["127.0.0.1"]
	_check(title.host_room(true) and Net.room_public and title._lobby_info.text.contains("공개 방"), "공개 방 만들기")
	for i in 90:
		await get_tree().process_frame
		if not finder.rooms.is_empty():
			break
	var found: Array = finder.get_room_list()
	_check(listening and found.size() == 1 and String(found[0]["name"]) == _gm.hero_name and int(found[0]["port"]) == Net.host_port and int(found[0]["count"]) == 1,
		"공개 방이 같은 네트워크의 방 목록에 보임 (%s)" % str(found))
	title.leave_room()
	finder.queue_free()
	Net.discovery_targets = ["255.255.255.255"]
	title.open_menu()
	(title.get_node("%SingleButton") as Button).pressed.emit()
	_check(title.get_screen() == "single" and (title.get_node("%ContinueButton") as Button).disabled, "싱글플레이 → 이어하기(저장 없음 → 비활성) / 새 게임")
	(title.get_node("%NewGameButton") as Button).pressed.emit()
	_check(title.get_screen() == "difficulty", "새 게임 → 난이도 선택")
	title.select_difficulty(_gm.Difficulty.HARD)
	_check(title.get_screen() == "help", "난이도 선택 → 조작 안내 표시")
	_check(title.get_node("%KeyGrid").get_child_count() == title.CONTROLS.size() * 2, "조작 키 %d개 안내" % title.CONTROLS.size())
	_check((title.get_node("%HelpTitle") as Label).text.contains("하드"), "안내 제목에 선택 난이도")
	title.start_game()
	_check(_gm.difficulty == _gm.Difficulty.HARD and _gm.get_difficulty_name() == "하드" and _gm.hero_name == "랜슬롯" and not _gm.tutorial_mode, "하드 난이도로 새 게임 (이름 유지)")
	(title.get_node("%RenameButton") as Button).pressed.emit()
	name_edit = title.get_node("%HeroNameEdit") as LineEdit
	_check(title.get_screen() == "name" and name_edit.text == "랜슬롯", "이름 바꾸기 → 이름 화면")
	name_edit.text = ""
	title.confirm_name()
	_check(_gm.hero_name == _gm.DEFAULT_HERO_NAME and title.get_screen() == "menu", "이름을 비우면 「용사」 · 튜토리얼을 마쳤으니 메뉴로")
	Profile.set_hero_name("랜슬롯")
	_gm.set_hero_name("")
	title.queue_free()
	await get_tree().process_frame
	await _test_tutorial_and_save()
	_gm.start_new_game(_gm.Difficulty.NORMAL)

	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _frames(3)

	var player := main.get_node("Entities/Player") as Player
	var entities := main.get_node("Entities") as Node2D
	var pool := main.get_node("ProjectilePool") as ProjectilePool
	await _test_dialogue(main)
	await _test_gear(main)
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
	_check(hud.get_node("%Hotbar").get_child_count() == 16, "HUD 단축바 (스킬 칸 + 무기 3 + 방어구 4 + 장신구 3 + 포션)")
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
	_check(rusty_damage >= rusty_weapon.damage - front.get_defense_value(), "정면 적 타격 (데미지 %d, 슬라임 방어력 %d)" % [rusty_damage, front.get_defense_value()])
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
	var orc_def := orc_test.get_defense_value()
	_check(orc_def == orc_test.defense * Balance.K and orc_test.calc_damage(200) == 200 - orc_def, "방어력만큼 피해 감소 (200 → %d, 방어력 %d)" % [orc_test.calc_damage(200), orc_def])
	_check(orc_test.calc_damage(200, 40) == 200 - (orc_def - 40), "방깍 40 → 방어력 무시 (200 → %d)" % orc_test.calc_damage(200, 40))
	_check(orc_test.calc_damage(200, 9999) == 200, "방깍이 방어력보다 크면 피해 그대로")
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
			if sw.rarity == b.rarity and sw.tier == b.tier and sw.in_shop == b.in_shop and (b.damage >= sw.damage or b.attack_cooldown + b.windup_time >= sw.attack_cooldown):
				specialized = false
				print("    %s vs %s" % [b.display_name, sw.display_name])
		if b.armor_pen <= 0:
			specialized = false
	_check(specialized, "활: 같은 등급 · 단계 검보다 공격력 낮고 공속 빠름 + 방깍 보유")
	var all_aoe := true
	for st in staffs:
		if st.explosion_radius <= 0.0:
			all_aoe = false
	_check(all_aoe and staffs.size() >= 15, "지팡이 %d종 모두 범위(폭발) 공격" % staffs.size())
	var sword_top := true
	for sw in swords:
		for item in ItemDB.get_all():
			var w2 := item as WeaponData
			if w2 != null and w2 != sw and w2.rarity == sw.rarity and w2.tier == sw.tier and w2.in_shop == sw.in_shop and w2.get_dps() > sw.get_dps():
				sword_top = false
				print("    %s(%.0f) > %s(%.0f)" % [w2.display_name, w2.get_dps(), sw.display_name, sw.get_dps()])
	_check(sword_top, "검: 같은 등급 · 단계에서 단일 대상 초당 피해가 가장 높음")

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
	await _press_action(&"weapon_slot_3")
	_check(_gm.equipped_weapon == staff, "3 키 → 지팡이")
	_check(not InputMap.has_action(&"weapon_next") and not InputMap.has_action(&"weapon_prev"), "무기 전환은 1 · 2 · 3 키로만 (Q · 휠 순환 없음)")
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

	print("[액티브 스킬 Q - 레어 기본형 · 전설 진화형 · 신화 전용]")
	var skill_weapons: Dictionary = {}  # 스킬 id → 무기
	var low_weapon: WeaponData = null
	var skill_flags_ok := true
	var icons_ok := true
	for item in ItemDB.get_all():
		var sw := item as WeaponData
		if sw == null:
			continue
		if sw.has_skill() != (sw.rarity >= ItemData.Rarity.EPIC) or sw.has_skill() != sw.get_stat_text().contains("[Q]"):
			skill_flags_ok = false
		if sw.has_skill():
			if sw.get_skill_icon() == null or sw.get_skill_name() == "":
				icons_ok = false
			if not skill_weapons.has(sw.get_skill_id()):
				skill_weapons[sw.get_skill_id()] = sw
		if sw.rarity == ItemData.Rarity.RARE and low_weapon == null:
			low_weapon = sw
	_check(skill_flags_ok and icons_ok, "레어 · 전설 · 신화 무기에만 스킬 (장비 설명에 [Q] 줄 · 스킬마다 아이콘)")
	# 단검은 지금 일반 등급뿐 — 레어 · 전설 단검이 생겼을 때를 위해 복사본으로 시험
	for dagger_rarity in [ItemData.Rarity.EPIC, ItemData.Rarity.LEGENDARY]:
		var test_dagger := ItemDB.get_weapon(&"goblin_dagger").duplicate() as WeaponData
		test_dagger.id = StringName("_test_dagger_%d" % dagger_rarity)
		test_dagger.rarity = dagger_rarity
		skill_weapons[test_dagger.get_skill_id()] = test_dagger
	_check(skill_weapons.size() == WeaponData.SKILLS.size(), "스킬 %d종이 모두 쓰임 (%s)" % [WeaponData.SKILLS.size(), ", ".join(skill_weapons.keys().map(func(k: StringName) -> String: return WeaponData.SKILLS[k]["name"]))])
	var abaddon := ItemDB.get_weapon(&"abaddon_sword")
	var apollo := ItemDB.get_weapon(&"apollo_bow")
	var archmage := ItemDB.get_weapon(&"archmage_staff")
	_check(abaddon.get_skill_id() == &"abyss_descent" and apollo.get_skill_id() == &"helios" and archmage.get_skill_id() == &"meteor_swarm",
		"신화 무기마다 전용 스킬: 아바돈의 검 「%s」 · 아폴론의 활 「%s」 · 대마법사의 지팡이 「%s」" % [abaddon.get_skill_name(), apollo.get_skill_name(), archmage.get_skill_name()])
	var tier_ok := true
	for chain in [[&"whirlwind", &"holy_tempest", &"abyss_descent"], [&"volley", &"meteor_rain", &"helios"], [&"blast", &"cataclysm", &"meteor_swarm"], [&"flurry", &"shadow_dance"]]:
		for i in range(1, chain.size()):
			var lo: WeaponData = skill_weapons[chain[i - 1]]
			var hi: WeaponData = skill_weapons[chain[i]]
			if hi.get_skill_power() <= lo.get_skill_power() or WeaponData.SKILLS[chain[i]]["desc"] == WeaponData.SKILLS[chain[i - 1]]["desc"]:
				tier_ok = false
	_check(tier_ok, "등급이 오를수록 다른 기술로 진화하고 더 셈 (회전 베기 → 성검 폭풍 → 마왕강림 …)")
	_check(InputMap.action_get_events(&"skill").size() == 1 and (InputMap.action_get_events(&"skill")[0] as InputEventKey).physical_keycode == KEY_Q, "스킬 키는 Q")
	_check(not attack.use_skill(low_weapon) and _gm.get_skill_cooldown(low_weapon) == 0.0, "희귀 이하 무기는 Q 를 눌러도 스킬 없음")
	var skill_aim := player.get_aim_direction()
	var skill_origin := player.get_attack_origin()
	var muzzle := player.get_muzzle_position()
	for skill_id in WeaponData.SKILLS.keys():
		var sw: WeaponData = skill_weapons[skill_id]
		_gm.skill_cooldowns.clear()
		seed(7)
		var spots: Array[Vector2] = []
		var need := 0  # 맞아야 하는 최소 수 (0 = 모두)
		match skill_id:
			&"whirlwind", &"holy_tempest", &"flurry", &"shadow_dance", &"abyss_descent":
				# 앞 · 뒤 · 옆 — 360° 모두
				for dir in [skill_aim, -skill_aim, skill_aim.orthogonal()]:
					spots.append(skill_origin + dir * 30.0)
			&"volley", &"helios":
				# 한 줄로 선 셋 — 꿰뚫음
				for dist in [40.0, 60.0, 80.0]:
					spots.append(muzzle + skill_aim * dist)
			&"blast":
				var blast_at := player.get_aim_point(sw.projectile_range)
				spots.append(blast_at)
				spots.append(blast_at + skill_aim.orthogonal() * 30.0)
			&"meteor_rain", &"meteor_swarm":
				need = 2  # 하늘에서 떨어지는 자리를 보고 나서 그 자리에 세움 (아래)
			&"cataclysm":
				var cata_at := player.get_aim_point(sw.projectile_range * 1.2)
				spots.append(cata_at)
				spots.append(muzzle.lerp(cata_at, 0.5))
		var targets: Array[Enemy] = []
		for spot in spots:
			var target := slime_scene.instantiate() as Enemy
			target.move_speed = 0.0
			target.max_hp = 999999999
			stage._add_enemy(target, _enemy_pos_for_hit_center(spot), camp_arena)
			targets.append(target)
		await _frames(3)
		var used: bool = attack.use_skill(sw)
		if skill_id == &"meteor_rain" or skill_id == &"meteor_swarm":
			# 떨어질 자리(하늘에서 오는 화살 · 별 · 운석) 셋에 적을 세움
			var falling := get_tree().get_nodes_in_group(&"sky_strikes")
			for k in mini(3, falling.size()):
				var target := slime_scene.instantiate() as Enemy
				target.move_speed = 0.0
				target.max_hp = 999999999
				var drop_at: Vector2 = (falling[falling.size() - 1 - k] as Node2D).global_position
				stage._add_enemy(target, _enemy_pos_for_hit_center(drop_at), Rect2(drop_at - Vector2(500, 500), Vector2(1000, 1000)))
				targets.append(target)
			await _frames(2)
		var after_first: Array[int] = []
		for t in targets:
			after_first.append(t.hp)
		for f in 170:
			await get_tree().physics_frame
		var hit_count := 0
		for t in targets:
			if is_instance_valid(t) and t.hp < t.max_hp:
				hit_count += 1
		_check(used and hit_count >= (need if need > 0 else targets.size()), "%s(%s) [Q] %s: 적 %d명 중 %d명 피해" % [sw.display_name, sw.get_rarity_name(), sw.get_skill_name(), targets.size(), hit_count])
		if skill_id == &"flurry":
			_check(targets[0].hp < after_first[0], "그림자 난무: 첫 베기 뒤에도 연달아 벰")
		if skill_id == &"abyss_descent":
			_check(targets.any(func(t: Enemy) -> bool: return is_instance_valid(t) and t.hp < after_first[targets.find(t)]), "마왕강림: 암흑 참격 뒤 마계의 손아귀 · 암흑 기둥이 이어서 때림")
		_check(_gm.get_skill_cooldown(sw) > 0.0 and not attack.use_skill(sw), "%s: 쓰면 대기시간 %d초 — 그동안 다시 못 씀" % [sw.get_skill_name(), roundi(sw.get_skill_cooldown())])
		for t in targets:
			if is_instance_valid(t):
				t.despawn()
		await _frames(5)
	_gm.heal_full()
	# 실제 Q 키 · HUD 스킬 칸 (무기 단축바 왼쪽)
	var skill_sword: WeaponData = skill_weapons[&"whirlwind"]
	var legend_bow: WeaponData = skill_weapons[&"meteor_rain"]
	_gm.skill_cooldowns.clear()
	var keep_slots: Array[WeaponData] = _gm.weapon_slots.duplicate()
	var keep_active: int = _gm.active_weapon_slot
	var keep_items: Array[ItemData] = _gm.items.duplicate()
	_gm.add_item(skill_sword)
	_gm.equip_item(skill_sword)
	await _frames(12)
	var skill_slot := hud.get_node("%Hotbar").get_child(0)
	var skill_icon := skill_slot.find_child("SkillIcon", true, false) as TextureRect
	var skill_time := skill_slot.find_child("SkillTime", true, false) as Label
	_check(skill_slot.name == "SkillSlot" and skill_icon != null and skill_icon.texture == skill_sword.get_skill_icon(), "HUD: 무기 단축바 왼쪽에 손에 든 무기의 스킬 아이콘 (%s)" % skill_sword.get_skill_name())
	_check(skill_time != null and skill_time.text == "Q", "스킬 준비됨 → 「Q」")
	await _press_action(&"skill")
	await _frames(3)
	_check(_gm.get_skill_cooldown(skill_sword) > 0.0, "Q 키 → 손에 든 무기의 스킬 (%s)" % skill_sword.get_skill_name())
	var shade := skill_slot.find_child("SkillShade", true, false) as Control
	_check(skill_time.text.is_valid_int() and shade != null and shade.visible and shade.size.y > 1.0, "대기시간: 아이콘 위에 어두운 게이지 + 남은 초 (%s초)" % skill_time.text)
	_gm.add_item(legend_bow)
	_gm.equip_item(legend_bow)
	await _frames(6)
	skill_icon = hud.get_node("%Hotbar").get_child(0).find_child("SkillIcon", true, false) as TextureRect
	_check(skill_icon != null and skill_icon.texture == legend_bow.get_skill_icon(), "무기를 바꾸면 스킬 아이콘도 바뀜 (%s)" % legend_bow.get_skill_name())
	_gm.select_weapon_slot(0)
	await _frames(4)
	skill_icon = hud.get_node("%Hotbar").get_child(0).find_child("SkillIcon", true, false) as TextureRect
	_check(skill_icon != null and skill_icon.texture == skill_sword.get_skill_icon(), "1 키로 검을 들면 다시 회전 베기 아이콘")
	_gm.skill_cooldowns.clear()
	# 뒤 테스트를 위해 무기 칸 · 가방을 스킬 시험 전으로 되돌림
	for i in 3:
		_gm.weapon_slots[i] = keep_slots[i]
	_gm.items = keep_items
	_gm.select_weapon_slot(keep_active)
	_gm.inventory_changed.emit()
	await _frames(70)
	print("[시인성 - 내 공격 · 적 탄 · 예고 장판]")
	var vis_pool := ProjectilePool.find(get_tree())
	var enemy_shot := vis_pool.spawn(ProjectileSpec.enemy_bullet(player.global_position + Vector2(200, 0), Vector2.RIGHT, 10.0, 1, load("res://assets/sprites/projectiles/orb.png")))
	var my_shot := vis_pool.spawn(ProjectileSpec.from_weapon(ItemDB.get_weapon(&"hunter_bow"), player.global_position + Vector2(-200, 0), Vector2.LEFT, {"amount": 1, "crit": false}))
	_check(enemy_shot != null and enemy_shot._back.visible and enemy_shot._glow.visible and enemy_shot._back.modulate.r == 0.0,
		"적 탄: 검은 실루엣 테두리 + 붉은 위험 빛 (어느 바닥에서도 또렷)")
	_check(my_shot != null and my_shot._glow.visible and not my_shot._back.visible and my_shot._trail.emitting, "내 탄: 일반 등급도 빛 + 꼬리")
	enemy_shot.release()
	my_shot.release()
	var warn := AoeStrike.spawn(player, player.global_position + Vector2(150, 0), 24.0, 0.8, 1, Color(1.0, 0.3, 0.2))
	_check(warn != null, "예고 장판: 검은 바깥 테두리 + 깜빡이는 밝은 테두리 + 십자 조준선")
	if warn != null:
		warn.harmless = true
	await _frames(60)
	if OS.get_environment("SMOKE_STOP") == "skills":  # 빠른 확인용: 여기까지만
		print("FAILURES: %d" % _failures)
		get_tree().quit(1 if _failures > 0 else 0)
		return
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
	for p in _item_pickups(entities):
		p.queue_free()
	if is_instance_valid(front):
		front.despawn()
	await _frames(2)
	var epic_dropper := slime_scene.instantiate() as Enemy
	epic_dropper.item_drop_chance = 1.0
	epic_dropper.item_drop_ids = [&"flame_blade"]
	stage._add_enemy(epic_dropper, player.global_position + Vector2(-80, 0), camp_arena)
	await _frames(3)
	epic_dropper.take_damage(99999999, Vector2.ZERO, false, 999999)
	await _frames(3)
	var item_drops := _item_pickups(entities)
	_check(item_drops.size() == 1 and (item_drops[0] as Pickup).item.rarity == ItemData.Rarity.COMMON and (item_drops[0] as Pickup).item.id != &"flame_blade",
		"1스테이지 잡몹은 일반 등급만 드랍 (레어 화염검은 안 나옴 — 받은 것: %s)" % ((item_drops[0] as Pickup).item.display_name if item_drops.size() == 1 else "없음"))
	var dropped_item: ItemData = (item_drops[0] as Pickup).item if item_drops.size() == 1 else null
	for p in entities.get_children():
		if p is Pickup:
			(p as Pickup).global_position = player.global_position
	await _frames(40)
	_check(_gm.gold > gold_before, "골드 확정 드랍 획득")
	_check(_gm.items.size() == items_before + 1 or (dropped_item != null and _gm.owns_item(dropped_item.id)), "드랍 장비 가방에 추가")

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
	var guard_shield: ShieldData = _gm.equipped_shield
	var raw_hit := 10 * Balance.K
	var expected_guard_hp := hp1 - maxi(1, raw_hit - roundi(raw_hit * guard_shield.block_ratio) - player.get_effective_defense())
	_check(_gm.hp == expected_guard_hp, "정면 가드: %s %d%% 막음 (HP %d → %d)" % [guard_shield.display_name, roundi(guard_shield.block_ratio * 100.0), hp1, _gm.hp])
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
	_check(not _gm.buy_item(medium) and not _gm.buy_item(greater) and small.get_unlock_stage() == 1 and medium.get_unlock_stage() == 11 and greater.get_unlock_stage() == 41,
		"포션도 등급 구간대로 풀림: 작은(일반) 1 · 회복(희귀) 11 · 고급(레어) 41 · 엘릭서(전설) 71스테이지")
	_check(small.price < medium.price and medium.price < greater.price and greater.price < ItemDB.get_potion(&"elixir").price, "포션 값도 풀리는 스테이지 수입에 맞춤 (%d · %d · %d · %d G)" % [small.price, medium.price, greater.price, ItemDB.get_potion(&"elixir").price])
	_gm.add_potion(medium, 2)
	_check(_gm.get_potion_count(&"potion") == 2, "회복 포션 2개 (보상으로)")
	for i in 10:
		_gm.buy_potion(small)
	_check(_gm.get_potion_count(&"small_potion") == _gm.POTION_MAX_STACK, "종류별 최대 %d개" % _gm.POTION_MAX_STACK)
	_gm.damage_player(roundi(_gm.max_hp * 0.35))
	_check(_gm.choose_potion() == medium, "많이 잃으면 큰 포션 자동 선택")
	await _frames(60)
	_gm.use_potion()
	_check(_gm.hp == _gm.max_hp and _gm.get_potion_count(&"potion") == 1, "회복 포션: 최대 체력의 %d%% 회복" % roundi(medium.heal_percent * 100.0))
	var potion_slot := hud.get_node("%Hotbar").get_child(hud.get_node("%Hotbar").get_child_count() - 1)
	var shown_own: int = _gm.get_potion_count(_gm.choose_potion().id)
	var want_count: String = ("x%d/%d" % [shown_own, _gm.get_total_potions()]) if shown_own != _gm.get_total_potions() else "x%d" % shown_own
	_check((potion_slot.get_node("PotionCount") as Label).text == want_count and (potion_slot.get_node("PotionMode") as Label).text == "자동",
		"HUD 포션 칸: 마실 포션 개수 / 전체 「%s」 · 「자동」" % want_count)

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

	print("[장비 버리기]")
	_check(not _gm.can_drop(iron) and not _gm.drop_item(iron, player.global_position), "마지막 무기는 버릴 수 없음")
	_check(inventory.drop(bow) and not _gm.owns_item(bow.id), "인벤토리 「버리기」 → 가방에서 빠짐")
	await _frames(2)
	var dropped_bow: Pickup = null
	for node in entities.get_children():
		if node is Pickup and (node as Pickup).item == bow:
			dropped_bow = node
	_check(dropped_bow != null and dropped_bow.dropped_by == 1 and dropped_bow.global_position.distance_to(player.global_position) < 20.0, "버린 장비가 발밑에 떨어짐")
	await _frames(60)
	_check(not _gm.owns_item(bow.id) and is_instance_valid(dropped_bow), "버린 사람은 잠깐 다시 줍지 않음 (동료가 주울 시간)")
	await _frames(150)
	_check(_gm.owns_item(bow.id), "잠시 뒤에는 다시 주울 수 있음")

	print("[상점 - 구매 / 판매 / 스테이지 잠금 / 갑옷]")
	_gm.add_gold(20000)
	_gm.request_shop("테스트 상점", [&"traveler_bow", &"rapid_crossbow", &"royal_aegis", &"solaris_bow", &"leather_armor", &"traveler_shield", &"small_potion"])
	await get_tree().process_frame
	_check(shop.is_open() and get_tree().paused, "상점 열림 + 일시정지")
	shop.set_category(ShopUI.Category.BOW)
	await get_tree().process_frame
	var rows := shop.get_node("%BuyList").get_children()
	_check(rows.size() == 3 and _row_bg(rows, 0) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.COMMON] and _row_bg(rows, 1) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.RARE] and _row_bg(rows, 2) == ItemData.RARITY_BG_COLORS[ItemData.Rarity.LEGENDARY], "활 탭 · 등급 배경색: 일반 회색 / 희귀 파랑 / 전설 노랑")
	_check(_row_button(rows, 1).disabled and _row_button(rows, 1).text == "11스테이지" and _row_button(rows, 2).text == "71스테이지", "1스테이지: 희귀는 11스테이지 · 전설은 71스테이지까지 잠김")
	_check(not _gm.buy_item(ItemDB.get_item(&"royal_aegis")), "잠긴 장비는 구매 불가")
	shop.set_category(ShopUI.Category.POTION)
	await get_tree().process_frame
	_check(_row_button(shop.get_node("%BuyList").get_children(), 0).text == "가득 참" and _row_button(shop.get_node("%BuyList").get_children(), 0).disabled, "상점: 포션이 가득 차면 구매 불가 표시")
	shop.set_category(ShopUI.Category.BOW)
	# 아래쪽 장비에 마우스를 올려 긴 설명이 나와도 목록·버튼 위치가 바뀌면 안 됨 (설명칸 높이 고정)
	await get_tree().process_frame
	await get_tree().process_frame
	rows = shop.get_node("%BuyList").get_children()
	var buy_scroll := shop.get_node("%BuyList").get_parent() as Control
	var list_rect_before := buy_scroll.get_global_rect()
	var bottom_button := _row_button(rows, 2)
	var button_rect_before := bottom_button.get_global_rect()
	bottom_button.mouse_entered.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(shop.get_node("%Detail").text.contains(ItemDB.get_item(&"solaris_bow").display_name), "아래쪽 장비에 마우스 → 설명 표시")
	_check(buy_scroll.get_global_rect() == list_rect_before and bottom_button.get_global_rect() == button_rect_before, "설명이 길어도 구매 목록·버튼 위치 그대로 (가려지지 않음)")
	var shop_panel := shop.get_node("Panel") as Control
	_check(Rect2(Vector2.ZERO, shop_panel.get_viewport_rect().size).encloses(shop_panel.get_global_rect()), "상점 창이 화면 밖으로 늘어나지 않음")
	var leather := ItemDB.get_item(&"leather_armor") as ArmorData
	var round_shield := ItemDB.get_item(&"traveler_shield") as ShieldData
	var max_hp_before: int = _gm.max_hp
	var gold_pre: int = _gm.gold
	shop._on_buy_pressed(leather)
	shop._on_buy_pressed(round_shield)
	await get_tree().process_frame
	_check(_gm.gold == gold_pre - leather.price - round_shield.price, "구매 골드 차감")
	_check(_gm.equipped_armor == leather and _gm.max_hp == max_hp_before + leather.bonus_max_hp, "갑옷 구매 → 갑옷 칸 장착, 최대 HP +%d" % leather.bonus_max_hp)
	_check((player.get_node("BodySprite/ArmorSprite") as Sprite2D).visible, "플레이어 몸에 갑옷 표시")
	var def_sum := 0
	for gear in [_gm.equipped_shield, _gm.equipped_helmet, _gm.equipped_armor, _gm.equipped_boots]:
		if gear != null:
			def_sum += gear.defense
	_check(_gm.equipped_shield == round_shield and _gm.get_total_defense() == def_sum + roundi(_gm.get_set_value("defense")), "방어력 합산 (방패 + 갑옷 + …: %d)" % _gm.get_total_defense())
	var rusty := ItemDB.get_item(&"rusty_sword")
	var gold_before_sell: int = _gm.gold
	var sold: int = _gm.sell_item(rusty)
	_check(sold == rusty.get_sell_value() and _gm.gold == gold_before_sell + sold and not _gm.owns_item(rusty.id), "녹슨 검 판매 +%dG" % sold)
	_check(_gm.sell_item(_gm.equipped_shield) == 0, "장착 중인 장비는 판매 불가")
	await get_tree().process_frame
	shop.set_category(ShopUI.Category.ARMOR)
	await get_tree().process_frame
	_check(shop.get_node("%InventoryList").get_child_count() == _gm.items.filter(func(it: ItemData) -> bool: return it is ArmorData).size(), "상점 보유 장비 목록 — 탭에 맞는 종류만 (장착 / 판매 버튼)")
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
	slime_king.take_damage(999999999)
	await _frames(4)
	_check(stage.get_state() == StageManager.State.CLEARED and next_portal.visible and next_portal.enabled, "보스 토벌 → 다음 스테이지 텔레포트 등장")
	var chest := stage.get_chest()
	_check(chest != null and not chest.is_opened(), "보물상자 등장")
	_check(_item_pickups(entities).filter(func(p: Pickup) -> bool: return stage.boss_room.get_bounds().has_point(p.global_position)).is_empty(), "보스는 장비를 직접 떨어뜨리지 않음 (상자로 보상)")
	stage.chest_item_chances = [1.0, 0.0]
	chest._interact()
	await _frames(3)
	var chest_drop := _item_pickups(entities).filter(func(p: Pickup) -> bool: return p.global_position.distance_to(chest.global_position) < 40.0)
	var chest_item: ItemData = (chest_drop[0] as Pickup).item if chest_drop.size() == 1 else null
	_check(chest_item != null and chest_item.rarity == ItemData.Rarity.COMMON and chest_item.get_fit_stage() <= 7, "1스테이지 보스 상자 → 일반 등급 (상급까지): %s" % (chest_item.get_grade_text() + " " + chest_item.display_name if chest_item else "없음"))
	_check(chest_item != null and not chest_item.is_mythic() and not ItemDB.MONSTER_ONLY.has(chest_item.id), "상자 장비: 상점 · 드랍 전용 장비 중에서 (신화 · 몬스터 고유 장비 제외)")
	next_portal.interacted.emit()
	await _frames(3)
	_check(_gm.stage == 2 and stage.get_state() == StageManager.State.CAMP and _gm.location_name == "야영지", "다음 스테이지 텔레포트 → 2스테이지 야영지")
	_check(chest_item != null and _gm.owns_item(chest_item.id), "보스방에 남은 상자 보상 자동 회수")
	_check(not gate.is_open() and not next_portal.visible, "새 스테이지: 보스문 재봉인 · 텔레포트 숨김")

	print("[2스테이지 - 불타는 지옥문]")
	_check(_gm.stage_name == "불타는 지옥문", "스테이지 이름")
	_gm.add_gold(10000)
	_gm.request_shop("테스트 상점", [&"bronze_armor", &"chain_mail"])
	await get_tree().process_frame
	shop.set_category(ShopUI.Category.ARMOR)
	await get_tree().process_frame
	rows = shop.get_node("%BuyList").get_children()
	_check(not _row_button(rows, 0).disabled or _gm.owns_item(&"bronze_armor"), "2스테이지: 일반 상급까지 구매 가능")
	_check(_row_button(rows, 1).disabled and _row_button(rows, 1).text == "11스테이지", "2스테이지: 희귀는 11스테이지까지 잠김")
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
	gatekeeper.take_damage(999999999)
	await _frames(4)
	var items_before2 := _item_pickups(entities).size()
	stage.chest_item_chances = [0.0, 0.0]
	stage.get_chest()._interact()
	await _frames(3)
	var base_gold := Balance.chest_gold(_gm.stage) * stage.get_gold_multiplier()
	_check(_item_pickups(entities).size() == items_before2 and stage.last_chest_items.is_empty() and stage.last_chest_gold >= roundi(base_gold * 1.6) - 1 and stage.last_chest_gold <= roundi(base_gold * 2.4) + 1,
		"보스 상자 장비는 확률 — 장비가 안 나오면 골드 두 배 (%d)" % stage.last_chest_gold)
	stage.chest_item_chances = [0.35, 0.1]
	var fresh_stage := (load("res://scenes/main/main.tscn") as PackedScene).instantiate().get_node("StageManager") as StageManager
	_check(fresh_stage.chest_item_chances == [0.35, 0.1] and ItemData.max_rarity_for_stage(10) == ItemData.Rarity.COMMON and ItemData.max_rarity_for_stage(11) == ItemData.Rarity.RARE
		and ItemData.max_rarity_for_stage(40) == ItemData.Rarity.RARE and ItemData.max_rarity_for_stage(41) == ItemData.Rarity.EPIC and ItemData.max_rarity_for_stage(70) == ItemData.Rarity.EPIC
		and ItemData.max_rarity_for_stage(71) == ItemData.Rarity.LEGENDARY, "보상 등급: 1~10 일반 · 11~40 희귀 · 41~70 레어 · 71~100 전설, 상자 장비 확률 35% · 10%")
	fresh_stage.get_parent().free()
	var rolls := {0: 0, 1: 0, 2: 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 1000:
		var n := 0
		for chance in stage.chest_item_chances:
			if rng.randf() < chance:
				n += 1
		rolls[n] += 1
	_check(rolls[0] > 500 and rolls[0] < 670 and rolls[2] < 80 and rolls[0] > rolls[1] and rolls[1] > rolls[2], "보스 상자 기본 확률: 대개는 골드만 — 장비 0개 %d · 1개 %d · 2개 %d (1000번)" % [rolls[0], rolls[1], rolls[2]])
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
	archeon.take_damage(999999999)
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

	dryad.take_damage(999999999)
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
		head.take_damage(999999999)
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
		dullahan.get_thrown_head().take_damage(999999999)
		await _frames(2)
		dullahan.take_damage(999999999)
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
					var base_power := {}
					for m in orc_king.get_minions():
						if not m.has_meta(&"war_cry"):
							base_power[m] = m.power
					orc_king.cast(BossOrcKing.Pattern.WAR_CRY)
					await _frames(4)
					var rallied_ok := orc_king.get_minions().size() > before_rally
					for m in orc_king.get_minions():
						# 난이도 배율(노멀 x0.7)이 곱해진 기본 공격력에서 x1.4 (새로 부른 부하는 enemy 기본값 기준)
						var was: float = base_power.get(m, m.power / BossOrcKing.WAR_CRY_POWER)
						if not m.has_meta(&"war_cry") or m.power < was * 1.39 or m.defense < 8:
							rallied_ok = false
					_check(rallied_ok, "[기믹] 족장의 함성: 오크킹이 부른 부하 %d명 강화 (공격력 x1.4 · 방어력 +8)" % orc_king.get_minions().size())
					var calm_power := orc_king.power
					orc_king.take_damage(roundi(orc_king.hp * 0.7), Vector2.ZERO, false, 999)
					orc_king.set_physics_process(true)
					await _survive(100)
					_check(orc_king.power > calm_power * 1.1 and orc_king.power <= calm_power * (1.0 + BossOrcKing.BERSERK_MAX) + 0.001 and orc_king.get_status_text().contains("광폭화"), "[기믹] 광폭화: 체력이 줄수록 공격력 증가 — 최대 +%d%% 상한 (지금 x%.2f · %s)" % [roundi(BossOrcKing.BERSERK_MAX * 100.0), orc_king.power / calm_power, orc_king.get_status_text()])
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
				king.crown.take_damage(999999999)
				await _frames(3)
				_check(king.is_crown_broken() and not king.is_barrier_up(), "왕관을 부수면 가호가 사라짐")
				hp_k = king.hp
				king.take_damage(500, Vector2.ZERO, false, 99)
				king.raise_barrier()
				_check(king.hp < hp_k and not king.is_barrier_up(), "왕관이 없으면 피해가 들어가고 가호를 다시 못 씀")
		boss.take_damage(999999999, Vector2.ZERO, false, 9999999)
		await _frames(4)
		_check(not _gm.is_game_cleared and next_portal.enabled, "%d스테이지 보스 토벌 → 다음 스테이지 텔레포트" % n)

	final_boss = await _test_late_stages(main)

	await _test_final_and_no_hidden(main, final_boss)

	await _test_gate_trials(main)

	print("[업적 (스팀 업적과 같은 id)]")
	for id in [&"FIRST_BOSS", &"STAGE_10", &"STAGE_40", &"STAGE_70", &"STAGE_100", &"FIRST_MYTHIC", &"ALL_TRIALS"]:
		_check(Achievements.is_unlocked(id), "업적 「%s」 달성됨" % Achievements.ACHIEVEMENTS[id]["name"])
	_check(not Achievements.unlock(&"FIRST_BOSS") and not Achievements.unlock(&"NO_SUCH"), "이미 이룬 업적 · 없는 id 는 다시 달성되지 않음")
	var saved := ConfigFile.new()
	_check(saved.load(Profile.profile_path) == OK and Array(saved.get_value("player", "achievements", [])).has("STAGE_100"), "업적은 프로필 파일에 저장")
	_check(Achievements.ACHIEVEMENTS.keys().all(func(id: StringName) -> bool: return String(id) == String(id).to_upper() and not String(id).contains(" ")),
		"업적 id 는 스팀 API 이름 규칙 (대문자 · 공백 없음)")
	_check(not SteamApi.is_running() and SteamApi.steam() == null and SteamApi.get_steam_id() == 0 and SteamApi.status_text != "",
		"GodotSteam 이 없으면 스팀 연결 없이도 그대로 동작 (%s)" % SteamApi.status_text)

	await _test_admin(main)

	await _test_bgm(main)

	await _test_sfx(main)

	print("[난이도 배율]")
	_gm.difficulty = _gm.Difficulty.VERY_HARD
	var tough := slime_scene.instantiate() as Enemy
	var base_hp := tough.max_hp
	stage._add_enemy(tough, player.global_position + Vector2(0, -80), camp_arena)
	await _frames(2)
	var hp_mult: float = _gm.DIFFICULTY_INFO[_gm.Difficulty.VERY_HARD]["enemy_hp"]
	_check(tough.max_hp == roundi(base_hp * hp_mult) * Balance.K, "베리하드: 몬스터 체력 %d → %d (×%.1f · 딜 인플레 ×%d)" % [base_hp, tough.max_hp, hp_mult, Balance.K])
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
	_gm.hidden_cleared = true
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
		var story_box := ending.get_node("%StoryBox") as VBoxContainer
		var last_line := (story_box.get_child(story_box.get_child_count() - 1) as Label).text
		_check((ending.get_node("%RecordTitle") as Label).text.contains("히든 클리어") and last_line.contains("아르케"), "히든 보스를 쓰러뜨렸으면 엔딩 마지막 줄과 기록에 표시")
		(ending.get_node("%ReturnButton") as Button).pressed.emit()
		await _frames(10)
		var title_after := get_tree().current_scene
		_check(title_after != null and title_after.name == "Title" and title_after.get_screen() == "menu", "엔딩 → 타이틀 메뉴")
		_check(not _gm.is_game_cleared and _gm.stage == 1 and _gm.total_kills == 0 and _gm.dragon_scales.is_empty() and not _gm.hidden_cleared, "새 모험을 위해 GameManager 초기화 (비늘·히든 포함)")

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
