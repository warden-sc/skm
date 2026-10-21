extends Node
## 멀티플레이 통합 테스트 진행 (tests/net_test.tscn 이 /root 에 붙임). 방장이 명령을 보내고 참가자가 답함.

signal replied(command: String, data: Dictionary)

const TIMEOUT := 40.0
## 방장이 만든 초대 코드를 참가자 프로세스에 넘기는 파일 (사람이라면 메신저로 보내는 부분)
const CODE_FILE := "user://_net_invite_code.txt"

var role: String = "client"
var failures: int = 0
var _replies: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	role = "host" if OS.get_cmdline_user_args().has("--host") else "client"
	Story.enabled = false
	Profile.profile_path = "user://_net_%s_profile.cfg" % role
	Profile.save_path = "user://_net_%s_save.json" % role
	Profile.load_profile()
	_run.call_deferred()


## --shots=폴더 를 주면 그 폴더에 화면을 저장 (그래픽이 있는 실행에서만)
func snap(file_name: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.substr(8).path_join("%s_%s.png" % [role, file_name]))


func check(ok: bool, message: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + "[%s] %s" % [role, message])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func wait_until(condition: Callable, seconds: float = TIMEOUT) -> bool:
	var left := seconds
	while left > 0.0:
		if condition.call():
			return true
		await get_tree().process_frame
		left -= get_process_delta_time()
	return condition.call()


func _run() -> void:
	if role == "host":
		await _run_host()
	else:
		await _run_client()
	print("NET %s FAILURES: %d" % [role.to_upper(), failures])
	Net.leave()
	await frames(10)
	get_tree().quit(1 if failures > 0 else 0)


# ============================================================ 방장
func ask(command: String, args: Array = []) -> Dictionary:
	_replies.erase(command)
	var peer := _client_peer()
	if peer == 0:
		return {}
	_cmd.rpc_id(peer, command, args)
	await wait_until(func() -> bool: return _replies.has(command), 15.0)
	return _replies.get(command, {})


func _client_peer() -> int:
	for id in Net.players:
		if id != 1:
			return id
	return 0


func _run_host() -> void:
	print("[멀티플레이 — 방장]")
	GameManager.set_hero_name("아서")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CODE_FILE))
	check(Net.host_game("아서") == OK and Net.is_host() and not Net.room_public, "비공개 방 만들기 (포트 %d)" % Net.PORT)
	var code := Net.get_invite_code("127.0.0.1")
	var file := FileAccess.open(CODE_FILE, FileAccess.WRITE)
	file.store_string(code)
	file.close()
	check(NetInvite.decode(code)["key"] == Net.room_key, "초대 코드 %s → 참가자에게 (파일로 전달)" % code)
	check(await wait_until(func() -> bool: return Net.players.size() == 2), "참가자 접속 → 대기실 2명")
	var peer := _client_peer()
	check(Net.get_player_name(peer) == "랜슬롯", "참가자 이름: %s" % Net.get_player_name(peer))
	Net.set_difficulty(0)
	Net.start_game()
	check(await wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "Main" and Net._bound()), "게임 시작 → 모두 메인 씬")
	var main := get_tree().current_scene
	var stage := main.get_node("StageManager") as StageManager
	var me := main.get_node("Entities/Player") as Player
	stage.instant_travel = true
	await frames(60)
	var puppet: Player = Net._puppets.get(peer)
	check(puppet != null and puppet.net_mode == Player.NetMode.PUPPET and puppet.is_in_group(&"player"), "방장 화면에 참가자의 분신 (PUPPET)")
	check(Net.get_enemy_hp_multiplier() == 1.5, "2명이면 몬스터 체력 ×1.5")

	var status := {}
	for attempt in 20:  # 참가자 쪽 장면이 다 뜰 때까지
		status = await ask("status")
		if int(status.get("mirrors", 0)) >= 5 and status.get("host_mirror", false) and status.get("shop_mirror", false):
			break
		await frames(15)
	check(int(status.get("mirrors", 0)) >= 5 and status.get("host_mirror", false) and status.get("shop_mirror", false),
		"참가자 화면에 방장 화면 복제 (%d개 · 방장 용사 · 상인)" % int(status.get("mirrors", 0)))
	check(status.get("location", "") == "야영지" and Vector2(status.get("pos", Vector2.ZERO)).distance_to(me.global_position) < 60.0,
		"참가자도 야영지, 방장 곁 (%s)" % str(status.get("pos")))

	var before := puppet.global_position
	await ask("move")
	await frames(20)
	check(puppet.global_position.x - before.x > 20.0, "참가자가 움직이면 방장 화면의 분신도 움직임 (%+.0f)" % (puppet.global_position.x - before.x))
	check(String(puppet.get_node("NetName").text) == "랜슬롯", "분신 머리 위 이름표 = 참가자가 지은 이름 (랜슬롯)")
	var names := {}
	for attempt in 10:  # 이름표 글자가 화면 복제로 도착할 때까지
		names = await ask("names")
		if names.get("host", "") == "아서":
			break
		await frames(10)
	check(names.get("self", "") == "랜슬롯" and names.get("host", "") == "아서", "참가자 화면: 내 머리 위 「%s」 · 방장 머리 위 「%s」" % [names.get("self", ""), names.get("host", "")])

	# 맞음 전달
	var hp0 := int((await ask("hp")).get("hp", 0))
	puppet.net_status["invincible"] = false
	puppet.net_status["dashing"] = false
	puppet.net_status["guarding"] = false
	check(puppet.take_hit(50, puppet.global_position + Vector2(12, 0)) == Player.HitResult.DAMAGED, "방장 화면에서 분신이 맞음")
	await frames(20)
	var hp1 := int((await ask("hp")).get("hp", 0))
	check(hp1 < hp0, "→ 참가자 컴퓨터의 용사 체력이 깎임 (%d → %d)" % [hp0, hp1])
	puppet.apply_burn(5, 1.0)
	await frames(10)
	check((await ask("burning")).get("burning", false), "분신에게 건 화상이 참가자 용사에게 걸림")

	# 골드 줍기
	var gold0 := int((await ask("gold")).get("gold", 0))
	var coin := stage.pickup_scene.instantiate() as Pickup
	coin.setup_gold(77)
	stage._add_entity(coin, puppet.global_position)
	await frames(60)
	var gold1 := int((await ask("gold")).get("gold", 0))
	check(gold1 == gold0 + 77, "분신이 주운 골드는 참가자에게 (%d → %d)" % [gold0, gold1])

	# 버리기 → 방장이 줍기
	await ask("drop")
	await frames(20)
	var dropped: Pickup = null
	for node in main.get_node("Entities").get_children():
		if node is Pickup and (node as Pickup).item != null and (node as Pickup).item.id == &"knight_sword":
			dropped = node
	check(dropped != null and dropped.dropped_by == peer, "참가자가 버린 장비가 방장 세계 바닥에 (버린 사람 표시)")
	if dropped != null:
		me.global_position = dropped.global_position
		await frames(40)
	check(GameManager.owns_item(&"knight_sword"), "다른 사람(방장)이 그 장비를 주움")

	# 사냥터로 함께 이동
	stage.enter_field()
	await frames(30)
	status = await ask("status")
	check(status.get("location", "") == "사냥터" and Vector2(status.get("pos", Vector2.ZERO)).distance_to(me.global_position) < 80.0, "방장이 사냥터로 가면 참가자도 함께 (%s)" % status.get("location", ""))

	# 참가자가 적을 공격
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	slime.max_hp = 999999
	stage._add_enemy(slime, puppet.global_position + Vector2(22, 0), stage.field_room.get_arena_rect())
	await frames(30)
	var reply := await ask("attack", [slime.get_instance_id()])
	await frames(30)
	await snap("field")
	await ask("snap", ["field"])
	check(reply.get("hit", false) and is_instance_valid(slime) and slime.hp < slime.max_hp, "참가자가 적(복제본)을 때리면 방장 세계의 진짜 적이 맞음 (%d/%d)" % [slime.hp if is_instance_valid(slime) else -1, slime.max_hp if is_instance_valid(slime) else -1])
	await frames(10)
	var mirror_hp := int((await ask("enemy_hp", [slime.get_instance_id()])).get("hp", -1))
	check(is_instance_valid(slime) and mirror_hp == slime.hp, "참가자 화면의 적 체력도 갱신 (%d)" % mirror_hp)

	# 적의 탄이 참가자 화면에도
	slime.shoot(Vector2.RIGHT, 40.0, 1, null)
	await frames(8)
	check(int((await ask("projectiles")).get("count", 0)) >= 1, "적의 탄이 참가자 화면에도 보임")
	slime.despawn()

	# 쓰러짐 → 유령 관전 → 다음 스테이지에서 부활 (장비 · 골드 그대로)
	var gold_before := int((await ask("gold")).get("gold", 0))
	await ask("die")
	await frames(70)
	check(puppet.is_net_dead() and Net.party.has(peer) and bool(Net.party[peer][0]), "참가자가 쓰러지면 방장 화면의 분신도 쓰러짐 (적이 노리지 않음)")
	var ghost := await ask("spectate")
	check(ghost.get("spectating", false) and ghost.get("target", "") == "아서" and float(ghost.get("alpha", 1.0)) < 0.8,
		"참가자는 유령이 되어 살아 있는 동료(%s)를 관전" % ghost.get("target", ""))
	check(puppet.modulate.a < 0.8, "방장 화면에서도 반투명한 유령으로 보임")
	await snap("ghost")
	await ask("snap", ["ghost"])
	stage._do_return_to_camp()
	await frames(20)
	check((await ask("status")).get("dead", false), "야영지로 돌아가는 것만으로는 부활하지 않음")
	stage._do_go_to_next_stage()
	await frames(30)
	var revived := await ask("status")
	check(not revived.get("dead", true) and not revived.get("spectating", true) and int((await ask("gold")).get("gold", -1)) == gold_before and GameManager.stage == 2,
		"동료가 보스를 깨고 다음 스테이지(2) 야영지에 오면 부활 — 골드 · 장비 그대로 (%dG)" % gold_before)
	check(not puppet.is_net_dead() and puppet.modulate.a > 0.9, "분신도 다시 일어남")

	# 1 ~ 100스테이지 보스방을 차례로 열어 참가자 화면에 복제 (복제본 오류 확인)
	var tour := OS.get_cmdline_user_args().has("--tour")
	var stages: Array = range(1, stage.get_final_stage() + 1) if tour else [1, 5, 18, 35, 50, 90]
	for s in stages:
		stage.go_to_stage(s)
		await frames(5)
		stage._do_enter_boss_room()
		await frames(int(stage.boss_entry_delay * 60) + 50)
		_hold_players()
	var tour_status := await ask("status")
	check(tour_status.get("location", "") == "보스방", "보스방 %d곳을 돌며 참가자 화면에 복제 (마지막 %d스테이지)" % [stages.size(), stages.back()])
	check(int((await ask("errors")).get("count", -1)) == 0, "참가자 쪽 복제 중 오류 없음")

	# 전멸 → 게임 오버 → 방장이 1스테이지부터 다시
	_hold_players()
	await ask("die")
	await frames(10)
	me._invincible_left = 0.0
	GameManager.damage_player(99999999)
	check(await wait_until(func() -> bool: return Net.party_wiped, 5.0), "모두 쓰러지면 게임 오버 (방장)")
	await frames(10)
	check((await ask("wiped")).get("wiped", false), "참가자 화면도 게임 오버")
	await snap("gameover")
	await ask("snap", ["gameover"])
	Net.restart_party()
	check(await wait_until(func() -> bool: return Net._bound() and not Net.party_wiped and not GameManager.is_player_dead and GameManager.stage == 1 and not Net._puppets.is_empty(), 15.0),
		"방장 [R] → 다 함께 1스테이지부터 다시")
	var again := {}
	for attempt in 20:
		again = await ask("status")
		if again.get("location", "") == "야영지" and not again.get("dead", true):
			break
		await frames(15)
	check(not again.get("dead", true) and again.get("location", "") == "야영지" and not again.get("spectating", true), "참가자도 1스테이지 야영지에서 다시 시작")

	# 나가기
	await ask("leave")
	check(await wait_until(func() -> bool: return Net._puppets.is_empty() and Net.players.size() == 1, 10.0), "참가자가 나가면 분신이 사라짐")


## 보스방 순회 중 용사들이 죽지 않게
func _hold_players() -> void:
	GameManager.heal_full()
	for p in Player.get_all(get_tree()):
		if p.is_local():
			p._invincible_left = 99.0


@rpc("any_peer", "reliable")
func _reply(command: String, data: Dictionary) -> void:
	_replies[command] = data
	replied.emit(command, data)


# ============================================================ 참가자
func _run_client() -> void:
	print("[멀티플레이 — 참가자]")
	GameManager.set_hero_name("랜슬롯")
	await frames(30)  # 방장이 먼저 방을 열 시간
	check(await wait_until(func() -> bool: return FileAccess.file_exists(CODE_FILE), 20.0), "방장에게 초대 코드를 받음")
	var code := FileAccess.get_file_as_string(CODE_FILE).strip_edges()
	var info := NetInvite.decode(code)
	# 열쇠가 틀린 코드 → 비공개 방이라 거절
	var rejected := {"reason": ""}
	var on_fail := func(reason: String) -> void: rejected["reason"] = reason
	Net.join_failed.connect(on_fail)
	Net.join_by_code(NetInvite.encode("127.0.0.1", int(info["port"]), (int(info["key"]) + 1) % 65536), "랜슬롯")
	await wait_until(func() -> bool: return String(rejected["reason"]) != "", 10.0)
	check(String(rejected["reason"]).contains("초대 코드가 맞지 않습니다") and not Net.is_online(), "틀린 초대 코드 → 「%s」" % rejected["reason"])
	Net.join_failed.disconnect(on_fail)
	var joined := false
	for attempt in 10:
		Net.join_by_code(code, "랜슬롯")
		if await wait_until(func() -> bool: return Net.players.size() >= 2, 3.0):
			joined = true
			break
	check(joined and Net.is_client(), "초대 코드로 참가 → 대기실")
	check(Net.get_player_name(1) == "아서", "대기실에 방장 이름")
	check(await wait_until(func() -> bool: return Net.in_game and Net._bound()), "방장이 시작 → 메인 씬")
	# 방장이 명령을 다 보낼 때까지 (나가기 명령이 오면 끝)
	await wait_until(func() -> bool: return _left, 900.0)


var _left: bool = false


@rpc("any_peer", "reliable")
func _cmd(command: String, args: Array) -> void:
	var data := await _do(command, args)
	if command != "leave":
		_reply.rpc_id(1, command, data)


func _player() -> Player:
	return Net._local_player()


func _mirror_of(host_id: int) -> Node:
	var entry: Dictionary = Net._mirrors.get(host_id, {})
	return entry.get("node") if not entry.is_empty() else null


func _do(command: String, args: Array = []) -> Dictionary:
	var player := _player()
	match command:
		"status":
			var host_mirror := false
			var shop_mirror := false
			for id in Net._mirrors:
				var node: Node = Net._mirrors[id]["node"]
				if node is Player:
					host_mirror = true
				if node is ShopKeeper:
					shop_mirror = true
			return {"mirrors": Net._mirrors.size(), "host_mirror": host_mirror, "shop_mirror": shop_mirror,
				"location": GameManager.location_name, "pos": player.global_position if player != null else Vector2.ZERO, "dead": GameManager.is_player_dead,
				"spectating": Net.is_spectating()}
		"move":
			Input.action_press(&"move_right")
			await frames(40)
			Input.action_release(&"move_right")
			return {}
		"hp":
			return {"hp": GameManager.hp}
		"burning":
			return {"burning": player != null and player.is_burning()}
		"gold":
			return {"gold": GameManager.gold}
		"drop":
			var sword := ItemDB.get_item(&"knight_sword")
			GameManager.add_item(sword)
			var ok := GameManager.drop_item(sword, player.global_position)
			return {"ok": ok}
		"attack":
			var target := _mirror_of(int(args[0])) as Enemy
			if target == null or player == null:
				return {"hit": false}
			player.global_position = target.global_position + Vector2(-14, 0)
			await frames(2)
			player._aim_direction = player.get_attack_origin().direction_to(target.get_hit_center())  # 머리 없는 실행: 마우스 대신 직접 조준
			(player.get_node("AttackController") as AttackController).perform_attack()
			return {"hit": true}
		"enemy_hp":
			var mirror := _mirror_of(int(args[0])) as Enemy
			return {"hp": mirror.hp if mirror != null else -1}
		"projectiles":
			var count := 0
			var root := get_tree().current_scene.get_node_or_null("NetProjectiles")
			if root != null:
				count = root.get_child_count()
			return {"count": count}
		"names":
			var host_name := ""
			for id in Net._mirrors:
				var node := Net._mirrors[id]["node"] as Player
				if node == null:
					continue
				for child in node.get_children():  # 이름표 (복제 중 새로 만든 것일 수도 있어 글자로 찾음)
					if child is Label and (child as Label).text != "" and host_name == "":
						host_name = (child as Label).text
			return {"self": (player.get_node("NetName") as Label).text, "host": host_name}
		"snap":
			await snap(String(args[0]))
			return {}
		"spectate":
			var spec := Net.spectator
			return {"spectating": Net.is_spectating(), "target": spec.target_name if spec != null else "", "alpha": player.modulate.a}
		"wiped":
			return {"wiped": Net.party_wiped}
		"errors":
			return {"count": 0}
		"die":
			GameManager.damage_player(999999)
			return {}
		"leave":
			_left = true
			Net.leave()
			return {}
	return {}
