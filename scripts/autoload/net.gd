extends Node
## 멀티플레이 (Net 오토로드) — 협동, 최대 4명, 방장이 방을 만들고 다른 사람이 방장 IP 로 접속.
##
## 방식: 방장 컴퓨터가 서버를 겸함 (호스트-클라이언트 · 「리슨 서버」. 흔히 P2P 라고 부르는 방식 — 따로 서버를 빌리지 않음)
##   - 방장(host): 게임 세계 전체(몬스터 · 보스 · 기믹 · 스테이지 진행)를 직접 돌리고, 화면에 보이는 것을 1초에 20번 참가자에게 보냄
##   - 참가자(client): 자기 용사만 직접 조작 (이동 · 공격 · 가드 · 장비 · 골드 · 인벤토리는 각자 자기 컴퓨터에)
##       · 자기 용사의 위치 · 모습 · 상태를 방장에게 보냄 → 방장 컴퓨터에 그 사람의 「분신」(Player.NetMode.PUPPET)
##       · 방장 화면의 적이 그 분신을 때리면 → 「맞음」을 그 사람 컴퓨터로 보내서 진짜 용사가 맞음 (가드 · 방어력은 그 사람 것)
##       · 참가자가 적(복제본)을 때리면 → 피해를 방장에게 보내서 진짜 적이 맞음
##   - 줍는 아이템: 가장 먼저 닿은 사람이 가짐. 인벤토리에서 「버리기」한 장비는 동료가 주울 수 있음
##
## 포트: PORT (UDP). 인터넷으로 하려면 방장 공유기에서 이 포트를 열어야(포트 포워딩) 함. 같은 와이파이면 그대로.
##
## 들어가기: 방장이 「초대 코드」(NetInvite — 주소 · 포트 · 방 열쇠를 13글자로)를 친구에게 알려 주면 코드로 참가.
##   - 비공개 방: 코드(열쇠)를 아는 사람만
##   - 공개 방: 같은 네트워크에 1초마다 방 정보를 뿌려 「공개 방 목록」(RoomFinder)에 보이고, 코드 없이 목록에서 바로 참가
## 쓰러지면: 유령이 되어 살아 있는 동료를 관전(Spectator) → 남은 동료가 보스를 쓰러뜨리고 다음 스테이지 야영지에 도착하면
##   장비 · 골드 그대로 부활. 모두 쓰러지면(전멸) 게임 오버 — 방장이 1스테이지부터 다시 하거나 끝냄

signal lobby_changed
signal join_failed(reason: String)
signal session_closed(reason: String)

const PORT := 24570
const MAX_PLAYERS := 4
const PROTOCOL := 2
const MAIN_SCENE := "res://scenes/main/main.tscn"
const TITLE_SCENE := "res://scenes/title/title.tscn"
## 몇 물리 프레임마다 화면 · 상태를 보내는지 (60fps 기준 3 → 1초에 20번)
const SEND_INTERVAL := 3
## 같이 하는 사람이 한 명 늘 때마다 몬스터 체력 +50%
const HP_PER_EXTRA_PLAYER := 0.5
## 참가자 컴퓨터에서 방장에게 보내도 되는 적 함수
const ENEMY_CALLS := [&"take_damage", &"apply_slow", &"apply_knockback", &"ignite", &"stun"]
## 방장이 참가자의 용사에게 걸 수 있는 함수 (Player 의 _forwarded 대상)
const PLAYER_CALLS := [&"apply_charm", &"release_charm", &"set_puppet", &"release_puppet", &"apply_push", &"set_chill", &"apply_root",
	&"mark_slippery", &"mark_smoke", &"apply_plague", &"cleanse", &"cure_plague", &"apply_decay", &"apply_stigma", &"set_faith",
	&"apply_fire_enchant", &"release_root", &"add_death_mark", &"apply_slow", &"apply_armor_break", &"apply_burn", &"mark_floor_status",
	&"shake_camera", &"_net_take_hit", &"_net_unblockable_hit"]

## 용사 상태를 보낼 때 이름 대신 순서로 (Player.get_net_status 의 키)
const STATUS_KEYS := ["aim", "dead", "dashing", "guarding", "invincible", "perfect", "block_arc", "charmed", "smoke", "plagued", "slippery",
	"decayed", "stigma", "faith", "fire_enchant", "rooted", "chill", "puppeted", "puppet_strength", "sentenced", "winding_up", "armor_broken",
	"defense", "slowed", "burning", "burn_tick", "can_attack", "can_guard", "death_marks", "hp", "max_hp"]

## peer id → {"name": String}
var players: Dictionary = {}
var in_game: bool = false
var difficulty: int = 0
var last_error: String = ""
## 방 설정: 공개 방이면 같은 네트워크의 방 목록에 보임. 방 열쇠는 초대 코드에 들어감 (비공개 방은 열쇠가 맞아야 들어옴)
var room_public: bool = false
var room_key: int = 0
var host_port: int = PORT
## 공개 방 소식을 뿌릴 주소 (테스트에서 127.0.0.1 로 바꿈)
var discovery_targets: PackedStringArray = ["255.255.255.255"]
## 모두 쓰러짐(전멸) → 게임 오버
var party_wiped: bool = false
## 같이 하는 사람들의 생사 { peer: [쓰러졌는지, 방장 컴퓨터의 용사 노드 id] } — 방장이 바뀔 때마다 보내 줌
var party: Dictionary = {}
var spectator: Spectator
var _join_key: int = 0
var _broadcast: PacketPeerUDP
var _broadcast_left: float = 0.0
var _party_sent: Dictionary = {}
var _end_reason: String = ""
## 방을 열거나 접속할 포트 (테스트에서 바꿀 수 있음)
var port: int = PORT

var _peer: ENetMultiplayerPeer
## 음성 채팅 ([V] 눌러서 말하기 · 설정에서 끄기 / 항상 켜기)
var voice: VoiceChat
var _main: Node
var _entities: Node2D
var _stage: Node
var _frame: int = 0
var _snap_seq: int = 0
var _last_snap_seq: int = -1

# 문자열 번호표 (텍스처 경로 등): 내가 보내는 쪽 / 받은 쪽(보낸 사람별)
var _strings_out: Dictionary = {}
var _strings_out_list: Array[String] = [""]
var _strings_new: Array[String] = []
var _strings_in: Dictionary = {}

# 방장
var _puppets: Dictionary = {}          # peer → Player
var _puppet_created: Dictionary = {}   # peer → {}
var _pending_calls: Dictionary = {}    # peer → {"r": [], "u": {}}
var _hud_state: Dictionary = {}
var _room_themes: Dictionary = {}
var _wipe_left: float = -1.0

# 참가자
var _mirrors: Dictionary = {}          # 방장 노드 id → {"node", "created", "target"}
var _my_puppet_id: int = 0
var _pending: Array = []               # 메인 씬이 준비되기 전에 받은 일들 [Callable]
var _spawning: Node = null
var _proj_root: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	voice = VoiceChat.new()
	voice.name = "Voice"
	add_child(voice)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# 방장일 때 화면 위 정보(스테이지 · 위치 · 처치 수 · 보스 체력)를 참가자에게 그대로 전함
	for signal_name in [&"stage_changed", &"location_changed", &"kill_progress_changed", &"boss_spawned", &"boss_hp_changed", &"boss_defeated"]:
		GameManager.connect(signal_name, _hud_relay(signal_name))
	GameManager.player_died.connect(_on_local_died)


# ============================================================ 상태
func is_online() -> bool:
	return _peer != null and multiplayer.multiplayer_peer == _peer and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func is_client() -> bool:
	return is_online() and not multiplayer.is_server()


## 이 컴퓨터의 peer id (혼자 할 때는 1)
func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func has_peer(peer_id: int) -> bool:
	if not is_online():
		return peer_id == 1
	return peer_id == my_id() or multiplayer.get_peers().has(peer_id)


func get_player_name(peer_id: int) -> String:
	return String(players.get(peer_id, {}).get("name", "용사"))


func get_player_count() -> int:
	return maxi(players.size(), 1)


## 게임 중 몬스터 체력 배율 (같이 하는 사람 수에 따라)
func get_enemy_hp_multiplier() -> float:
	if not in_game or not is_online():
		return 1.0
	return 1.0 + HP_PER_EXTRA_PLAYER * (get_player_count() - 1)


## 이 컴퓨터의 IP 주소들 (방장이 친구에게 알려 줄 주소)
func get_local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			result.append(address)
	return result


## 멀티플레이 중 상점 · 인벤토리 · 설정창이 열려 있으면 용사 조작을 막음 (멀티에서는 게임을 멈추지 않으므로)
func ui_blocks_input() -> bool:
	if not is_online() or _main == null or not is_instance_valid(_main):
		return false
	for path in [^"ShopUI", ^"InventoryUI", ^"PauseMenu"]:
		var ui := _main.get_node_or_null(path)
		if ui != null and ui.has_method(&"is_open") and ui.is_open():
			return true
	return false


## 창이 열릴 때 게임을 멈출지: 혼자 할 때만 멈춤 (멀티에서는 세상이 계속 움직임)
func pause_tree(tree: SceneTree, paused: bool) -> void:
	if is_online() and in_game:
		return
	tree.paused = paused


# ============================================================ 방 만들기 / 참가 / 나가기
## 방 만들기. public 이면 같은 네트워크의 공개 방 목록에 보임
func host_game(hero_name: String, use_port: int = 0, public: bool = false) -> Error:
	leave()
	if use_port <= 0:
		use_port = port
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(use_port, MAX_PLAYERS - 1)
	if err != OK:
		last_error = "방을 만들 수 없습니다 (포트 %d 사용 중?)" % use_port
		_peer = null
		return err
	_peer.host.compress(ENetConnection.COMPRESS_ZSTD)
	multiplayer.multiplayer_peer = _peer
	players = {1: {"name": hero_name}}
	in_game = false
	host_port = use_port
	room_public = public
	room_key = 1 + randi() % 65535
	_broadcast_left = 0.0
	lobby_changed.emit()
	return OK


## 초대 코드 (ip 를 비우면 이 컴퓨터의 내부 IP) — 방장만
func get_invite_code(ip: String = "") -> String:
	if not is_host():
		return ""
	if ip == "":
		var addresses := get_local_addresses()
		ip = addresses[0] if not addresses.is_empty() else "127.0.0.1"
	return NetInvite.encode(ip, host_port, room_key)


## 초대 코드로 참가 (IP 를 넣어도 됨 — 그때는 공개 방만)
func join_by_code(code: String, hero_name: String) -> Error:
	if not NetInvite.looks_like_code(code):
		return join_game(code, hero_name)
	var info := NetInvite.decode(code)
	if info.is_empty():
		last_error = "초대 코드가 올바르지 않습니다 (13글자 · 예: 6R4K-02M8-1ZQ7P)"
		return ERR_INVALID_PARAMETER
	return join_game(info["ip"], hero_name, info["port"], info["key"])


func join_game(address: String, hero_name: String, use_port: int = 0, key: int = 0) -> Error:
	leave()
	if use_port <= 0:
		use_port = port
	_join_key = key
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address.strip_edges(), use_port)
	if err != OK:
		last_error = "접속할 수 없습니다: %s" % address
		_peer = null
		return err
	_peer.host.compress(ENetConnection.COMPRESS_ZSTD)
	multiplayer.multiplayer_peer = _peer
	players = {}
	set_meta(&"join_name", hero_name)
	in_game = false
	return OK


## 연결 끊기 (방장이면 방이 닫힘)
func leave() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	in_game = false
	room_public = false
	room_key = 0
	_reset_runtime()


func _reset_runtime() -> void:
	if spectator != null and is_instance_valid(spectator):
		spectator.queue_free()
	spectator = null
	party_wiped = false
	party.clear()
	_party_sent.clear()
	_main = null
	_entities = null
	_stage = null
	_puppets.clear()
	_puppet_created.clear()
	_pending_calls.clear()
	_mirrors.clear()
	_pending.clear()
	_hud_state.clear()
	_room_themes.clear()
	_strings_out.clear()
	_strings_out_list = [""]
	_strings_new.clear()
	_strings_in.clear()
	_my_puppet_id = 0
	_last_snap_seq = -1
	_wipe_left = -1.0
	if voice != null:
		voice.reset()


func _on_connected_to_server() -> void:
	_register.rpc_id(1, String(get_meta(&"join_name", "용사")), PROTOCOL, _join_key)


func _on_connection_failed() -> void:
	last_error = "방장에게 접속하지 못했습니다 (IP · 포트 · 방화벽 확인)"
	leave()
	join_failed.emit(last_error)


func _on_server_disconnected() -> void:
	var was_in_game := in_game
	var reason := _end_reason if _end_reason != "" else "방장과 연결이 끊겼습니다"
	_end_reason = ""
	leave()
	session_closed.emit(reason)
	if was_in_game:
		_back_to_title(reason)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	voice.forget(id)
	if not multiplayer.is_server():
		return
	var who := get_player_name(id)
	players.erase(id)
	if _puppets.has(id):
		var puppet: Player = _puppets[id]
		if is_instance_valid(puppet):
			puppet.queue_free()
		_puppets.erase(id)
	_pending_calls.erase(id)
	_strings_in.erase(id)
	_lobby_sync.rpc(players, difficulty)
	lobby_changed.emit()
	if in_game:
		announce("%s 님이 나갔습니다" % who, Color(1.0, 0.7, 0.5))


@rpc("any_peer", "reliable")
func _register(hero_name: String, protocol: int, key: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var reason := ""
	if protocol != PROTOCOL:
		reason = "게임 버전이 다릅니다"
	elif not room_public and key != room_key:
		reason = "초대 코드가 맞지 않습니다 (비공개 방)"
	elif in_game:
		reason = "이미 게임이 시작된 방입니다"
	elif players.size() >= MAX_PLAYERS:
		reason = "방이 가득 찼습니다 (최대 %d명)" % MAX_PLAYERS
	if reason != "":
		_rejected.rpc_id(id, reason)
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if _peer != null and multiplayer.get_peers().has(id):
				_peer.disconnect_peer(id))
		return
	hero_name = hero_name.strip_edges().left(GameManager.HERO_NAME_MAX)
	players[id] = {"name": hero_name if hero_name != "" else "용사"}
	_lobby_sync.rpc(players, difficulty)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	last_error = reason
	leave()
	join_failed.emit(reason)


@rpc("authority", "reliable")
func _lobby_sync(new_players: Dictionary, new_difficulty: int) -> void:
	players = new_players
	difficulty = new_difficulty
	lobby_changed.emit()


## 방장: 대기실에서 난이도 고르기
func set_difficulty(value: int) -> void:
	difficulty = value
	if is_host():
		_lobby_sync.rpc(players, difficulty)
	lobby_changed.emit()


## 방장: 모두 함께 1스테이지부터 새 게임 시작
func start_game() -> void:
	if not is_host():
		return
	_start.rpc(difficulty)


@rpc("authority", "call_local", "reliable")
func _start(new_difficulty: int) -> void:
	_reset_runtime()
	in_game = true
	difficulty = new_difficulty
	GameManager.start_new_game(new_difficulty as GameManager.Difficulty)
	GameManager.tutorial_mode = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE)


func _back_to_title(reason: String) -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().change_scene_to_file(TITLE_SCENE)
	if reason != "":
		get_tree().create_timer(0.3).timeout.connect(func() -> void: GameManager.show_notice(reason, Color(1.0, 0.6, 0.5)))


# ============================================================ 메인 씬 연결
## 메인 씬이 준비되면 main.gd 가 부름
func bind_main(main: Node) -> void:
	_main = main
	_entities = main.get_node(^"Entities") as Node2D
	_stage = main.get_node(^"StageManager")
	if is_host():
		_bind_host()
	elif is_client():
		_bind_client()


func _bound() -> bool:
	return _main != null and is_instance_valid(_main) and _main.is_inside_tree()


func _physics_process(delta: float) -> void:
	if not in_game or not is_online() or not _bound():
		return
	_frame += 1
	if is_host():
		_flush_calls()
		if _frame % SEND_INTERVAL == 0:
			_send_snapshot()
		_update_party()
		_check_wipe(delta)
	elif _frame % SEND_INTERVAL == 0:
		_send_state()


var _prompt: Label


func _process(delta: float) -> void:
	_tick_broadcast(delta)
	if not in_game or not is_client() or not _bound():
		return
	_update_prompt()
	var weight := 1.0 - exp(-20.0 * delta)
	for id in _mirrors:
		var m: Dictionary = _mirrors[id]
		var node := m["node"] as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var target: Vector2 = m["target"]
		if node.global_position.distance_to(target) > 64.0:
			node.global_position = target
		else:
			node.global_position = node.global_position.lerp(target, weight)


# ============================================================ 문자열 번호표
func _intern(text: String) -> int:
	if text == "":
		return 0
	if _strings_out.has(text):
		return _strings_out[text]
	var id := _strings_out_list.size()
	if id > 65000:
		return 0
	_strings_out_list.append(text)
	_strings_out[text] = id
	_strings_new.append(text)
	return id


func _flush_strings(to_peer: int = 0) -> void:
	if _strings_new.is_empty():
		return
	var start := _strings_out_list.size() - _strings_new.size()
	if to_peer == 0:
		_strings_add.rpc(start, _strings_new)
	else:
		_strings_add.rpc_id(to_peer, start, _strings_new)
	_strings_new = []


@rpc("any_peer", "reliable")
func _strings_add(start: int, list: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _strings_in.has(sender):
		_strings_in[sender] = [""]
	var table: Array = _strings_in[sender]
	while table.size() < start + list.size():
		table.append("")
	for i in list.size():
		table[start + i] = String(list[i])


func _lookup_from(sender: int) -> Callable:
	return func(id: int) -> String:
		var table: Array = _strings_in.get(sender, [])
		return String(table[id]) if id > 0 and id < table.size() else ""


# ============================================================ 방장
func _bind_host() -> void:
	var local := _main.get_node_or_null(^"Entities/Player") as Player
	var index := 1
	for id in players:
		if id == 1:
			continue
		var puppet := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
		puppet.net_mode = Player.NetMode.PUPPET
		puppet.peer_id = id
		puppet.name = "Remote_%d" % id
		_entities.add_child(puppet)
		for child in puppet.get_children():
			if child is AttackController or child is GuardController:
				child.process_mode = Node.PROCESS_MODE_DISABLED
		if local != null:
			puppet.set_net_target(local.global_position + party_offset(index), true)
		_puppets[id] = puppet
		_puppet_created[id] = {}
		_your_puppet.rpc_id(id, puppet.get_instance_id())
		index += 1


## 시그널 인자 수가 달라서 이름별로 받아 넘기는 함수를 만듦
func _hud_relay(signal_name: StringName) -> Callable:
	match signal_name:
		&"stage_changed":
			return func(stage: int) -> void: _on_host_hud(signal_name, [stage, GameManager.stage_name])
		&"location_changed":
			return func(location: String) -> void: _on_host_hud(signal_name, [location])
		&"kill_progress_changed":
			return func(k: int, t: int) -> void: _on_host_hud(signal_name, [k, t])
		&"boss_spawned":
			return func(n: String, hp: int) -> void: _on_host_hud(signal_name, [n, hp])
		&"boss_hp_changed":
			return func(c: int, m: int) -> void: _on_host_hud(signal_name, [c, m])
	return func() -> void: _on_host_hud(signal_name, [])


func _on_host_hud(signal_name: StringName, args: Array = []) -> void:
	if not is_host() or not in_game:
		return
	if signal_name == &"boss_defeated":
		_hud_state.erase(&"boss_spawned")
		_hud_state.erase(&"boss_hp_changed")
	else:
		_hud_state[signal_name] = args
	if signal_name == &"boss_hp_changed":
		_hud_u.rpc(signal_name, args)
	else:
		_hud.rpc(signal_name, args)


## 남의 용사가 설 자리 (방장 기준 옆으로)
static func party_offset(index: int) -> Vector2:
	return [Vector2.ZERO, Vector2(-20, 6), Vector2(20, 6), Vector2(0, 16)][clampi(index, 0, 3)]


## 방장의 용사가 순간이동하면(야영지 · 사냥터 · 보스방 · 다음 스테이지) 모두 함께
func on_host_teleport(at_global: Vector2, bounds: Rect2) -> void:
	if not in_game:
		return
	var index := 1
	for id in _puppets:
		var puppet: Player = _puppets[id]
		if is_instance_valid(puppet):
			puppet.set_net_target(at_global + party_offset(index), true)
		index += 1
	_travel.rpc(at_global, bounds)


func _player_index(peer_id: int) -> int:
	var index := 0
	for id in players:
		if id == peer_id:
			return index
		index += 1
	return 0


func _collect_roots() -> Array:
	var roots: Array = []
	for child in _entities.get_children():
		if child is CanvasItem and not child.has_meta(&"net_local"):
			roots.append([child, 0])
	for child in _main.get_children():
		if child.owner == null and child is CanvasItem and not child.has_meta(&"net_local") and not (child is CPUParticles2D and child.get_script() == null):
			roots.append([child, 1])
	var pool := ProjectilePool.find(get_tree())
	if pool != null:
		for child in pool.get_children():
			var projectile := child as Projectile
			if projectile != null and projectile.is_active:
				roots.append([projectile, 2])
	return roots


func _spawn_info(node: Node) -> Array:
	if node.scene_file_path != "":
		return [0, node.scene_file_path]
	var script := node.get_script() as Script
	if script != null and script.resource_path != "":
		return [1, script.resource_path]
	return [2, node.get_class()]


## 한 번에 보내는 화면 조각 크기 (MTU 1392 보다 작게 — 조각 하나가 사라져도 나머지는 도착)
const PART_BYTES := 1150
const HEADER_BYTES := 14


func _send_snapshot() -> void:
	_snap_seq += 1
	var ambient := Color.WHITE
	var canvas := _stage.get_node_or_null(^"Ambient") as CanvasModulate
	if canvas != null:
		ambient = canvas.color
	var intern := _intern
	var parts: Array[PackedByteArray] = []
	var part := _new_part(ambient)
	var count := 0
	for entry in _collect_roots():
		var node: Node = entry[0]
		var info := _spawn_info(node)
		var rb := StreamPeerBuffer.new()
		rb.put_u64(node.get_instance_id())
		rb.put_u8(entry[1])
		rb.put_u8(info[0])
		rb.put_u16(_intern(info[1]))
		NetVisual.capture(node, rb, intern)
		if count > 0 and part.get_size() + rb.get_size() > PART_BYTES:
			parts.append(_finish_part(part, count))
			part = _new_part(ambient)
			count = 0
		part.put_data(rb.data_array)
		count += 1
	parts.append(_finish_part(part, count))
	_flush_strings()
	for data in parts:
		_snapshot.rpc(data)


func _new_part(ambient: Color) -> StreamPeerBuffer:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(_snap_seq)
	NetVisual._put_color(buf, ambient)
	buf.put_u16(0)  # 이 조각에 든 개수 (나중에 채움)
	return buf


func _finish_part(buf: StreamPeerBuffer, count: int) -> PackedByteArray:
	buf.seek(12)
	buf.put_u16(count)
	return buf.data_array


## 남의 용사에게 걸린 효과를 모아 두었다가 한 프레임에 한 번 보냄 (매 프레임 거는 효과는 마지막 것만)
func forward_player_call(peer_id: int, method: StringName, args: Array, every_frame: bool) -> void:
	if not is_host():
		return
	if not _pending_calls.has(peer_id):
		_pending_calls[peer_id] = {"r": [], "u": {}}
	var queue: Dictionary = _pending_calls[peer_id]
	if every_frame:
		(queue["u"] as Dictionary)[method] = args
	else:
		(queue["r"] as Array).append([method, args])


func _flush_calls() -> void:
	for peer_id in _pending_calls:
		var queue: Dictionary = _pending_calls[peer_id]
		var reliable: Array = queue["r"]
		var unreliable: Dictionary = queue["u"]
		if not reliable.is_empty():
			_calls.rpc_id(peer_id, reliable)
			queue["r"] = []
		if not unreliable.is_empty():
			var list: Array = []
			for method in unreliable:
				list.append([method, unreliable[method]])
			_calls_u.rpc_id(peer_id, list)
			queue["u"] = {}


## 방장 쪽 노드를 참가자에게 가리킬 때 (참가자 쪽 복제본으로 바뀜)
func node_ref(node: Object) -> Variant:
	if node == null or not is_instance_valid(node):
		return null
	return {"__nid": node.get_instance_id()}


@rpc("any_peer", "unreliable_ordered")
func _c_state(at_global: Vector2, status_values: Array, visual: PackedByteArray) -> void:
	if not is_host():
		return
	var status := {}
	for i in mini(status_values.size(), STATUS_KEYS.size()):
		status[STATUS_KEYS[i]] = status_values[i]
	var sender := multiplayer.get_remote_sender_id()
	var puppet: Player = _puppets.get(sender)
	if puppet == null or not is_instance_valid(puppet):
		return
	puppet.net_status = status
	puppet.set_net_target(at_global)
	var buf := StreamPeerBuffer.new()
	buf.data_array = visual
	NetVisual.apply(puppet, buf, _lookup_from(sender), _puppet_created[sender], false)


@rpc("any_peer", "reliable")
func _enemy_call(target_id: int, method: StringName, args: Array) -> void:
	if not is_host() or not ENEMY_CALLS.has(method):
		return
	var enemy := instance_from_id(target_id) as Enemy
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_dead():
		return
	enemy.callv(method, args)


@rpc("any_peer", "reliable")
func _drop(item_id: String, at_global: Vector2) -> void:
	if not is_host() or not _bound():
		return
	var item := ItemDB.get_item(StringName(item_id)) if ItemDB.has_item(StringName(item_id)) else null
	if item != null and _stage.has_method(&"spawn_dropped_item"):
		_stage.spawn_dropped_item(item, multiplayer.get_remote_sender_id(), at_global)


@rpc("any_peer", "reliable")
func _interact_request(target_id: int) -> void:
	if not is_host():
		return
	var target := instance_from_id(target_id) as Interactable
	if target != null and is_instance_valid(target) and target.is_inside_tree() and target.enabled and not (target is ShopKeeper):
		target._interact()


@rpc("any_peer", "reliable")
func _clear_hostile() -> void:
	if is_host() and _bound():
		_stage.clear_hostile_attacks()


@rpc("any_peer", "reliable")
func _hello() -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	# 처음부터 다시 보낼 문자열 번호표
	_strings_add.rpc_id(sender, 1, _strings_out_list.slice(1))
	for room_name in _room_themes:
		var theme: Array = _room_themes[room_name]
		_room_theme.rpc_id(sender, room_name, theme[0], theme[1])
	for signal_name in _hud_state:
		_hud.rpc_id(sender, signal_name, _hud_state[signal_name])
	var local := _main.get_node_or_null(^"Entities/Player") as Player
	if local != null:
		var bounds := Rect2()
		var cam := local.get_node_or_null(^"Camera2D") as Camera2D
		if cam != null:
			bounds = Rect2(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top)
		_travel.rpc_id(sender, local.global_position, bounds)
	if _puppets.has(sender):
		_your_puppet.rpc_id(sender, (_puppets[sender] as Player).get_instance_id())


# ---- 방장 → 모두
## 모두에게 알림 문구 (스테이지 · 보스 등 게임 진행)
func announce(text: String, color: Color = Color.WHITE) -> void:
	GameManager.show_notice(text, color)
	if is_host() and in_game:
		_notice.rpc(text, color)


func room_theme(room: Node, texture: Texture2D, tint: Color) -> void:
	if not is_host() or not in_game:
		return
	var path := texture.resource_path if texture != null else ""
	_room_themes[String(room.name)] = [path, tint]
	_room_theme.rpc(String(room.name), path, tint)


func fx_event(fx_name: StringName, args: Array) -> void:
	if is_host() and in_game:
		_fx.rpc(fx_name, args)


func story_event(key: String, mark: String) -> void:
	if is_host() and in_game:
		_story.rpc(key, mark)


func story_done() -> void:
	if is_host() and in_game:
		_story_end.rpc()


## 모두에게 장비 · 사용 아이템 · 포션 지급 (신화 장비 · 원초의 불꽃 · 고대 용의 피 등은 각자 하나씩)
func grant_all(kind: String, item_id: StringName, count: int = 1) -> void:
	if is_host() and in_game:
		_grant.rpc(kind, String(item_id), count)


func grant_pickup(peer_id: int, kind: int, gold: int, item_id: String) -> void:
	if is_host():
		_grant_pickup.rpc_id(peer_id, kind, gold, item_id)


func broadcast_ending() -> void:
	if is_host() and in_game:
		_ending.rpc()


# ============================================================ 쓰러짐 · 관전 · 부활 · 전멸
## 공개 방: 1초마다 같은 네트워크에 방 정보를 뿌림 (RoomFinder 가 받음)
func _tick_broadcast(delta: float) -> void:
	if not is_host() or not room_public or OS.has_feature("web"):
		return
	_broadcast_left -= delta
	if _broadcast_left > 0.0:
		return
	_broadcast_left = 1.0
	if _broadcast == null:
		_broadcast = PacketPeerUDP.new()
		_broadcast.set_broadcast_enabled(true)
	var packet := RoomFinder.make_packet(host_port, get_player_name(1), players.size(), MAX_PLAYERS, difficulty, in_game).to_utf8_buffer()
	for target in discovery_targets:
		_broadcast.set_dest_address(target, RoomFinder.DISCOVERY_PORT)
		_broadcast.put_packet(packet)


## 방장: 모두의 생사를 모아 바뀌면 알려 줌
func _update_party() -> void:
	var state := {}
	var local := _main.get_node_or_null(^"Entities/Player") as Player
	state[1] = [GameManager.is_player_dead, local.get_instance_id() if local != null else 0]
	for id in _puppets:
		var puppet: Player = _puppets[id]
		if is_instance_valid(puppet):
			state[id] = [puppet.is_net_dead(), puppet.get_instance_id()]
	if state != _party_sent:
		_party_sent = state
		_party_state.rpc(state)


@rpc("authority", "call_local", "reliable")
func _party_state(state: Dictionary) -> void:
	party = state


## 모두 쓰러졌는지 (혼자면 내 용사)
func is_party_dead() -> bool:
	if not is_online() or not in_game:
		return GameManager.is_player_dead
	if party.is_empty():
		return GameManager.is_player_dead
	for id in party:
		if not bool(party[id][0]):
			return false
	return true


## 모두 쓰러지면 잠시 뒤 게임 오버 (방장이 1스테이지부터 다시 하거나 끝냄)
func _check_wipe(delta: float) -> void:
	if party_wiped or party.size() < 1 or not is_party_dead():
		_wipe_left = -1.0
		return
	if _wipe_left < 0.0:
		_wipe_left = 1.5
	_wipe_left -= delta
	if _wipe_left <= 0.0:
		_wipe_left = -1.0
		_game_over.rpc()


@rpc("authority", "call_local", "reliable")
func _game_over() -> void:
	party_wiped = true
	if not _bound():
		return
	if is_host() and _stage.has_method(&"on_party_wiped"):
		_stage.on_party_wiped()
	var hud := _main.get_node_or_null(^"HUD")
	if hud != null and hud.has_method(&"show_party_game_over"):
		hud.show_party_game_over(is_host())


## 방장: 전멸 뒤 다 함께 1스테이지부터 다시
func restart_party() -> void:
	if is_host() and party_wiped:
		_start.rpc(difficulty)


## 방장: 게임을 끝내고 모두 타이틀로
func end_party() -> void:
	if not is_host():
		return
	_session_end.rpc("방장이 게임을 끝냈습니다")
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		leave()
		_back_to_title(""))


## 참가자: 나가기
func quit_party() -> void:
	leave()
	_back_to_title("")


@rpc("authority", "reliable")
func _session_end(reason: String) -> void:
	_end_reason = reason


## 내 용사가 쓰러짐 → 유령이 되어 살아 있는 동료를 관전
func _on_local_died() -> void:
	if not is_online() or not in_game or not _bound():
		return
	get_tree().create_timer(0.8, false).timeout.connect(start_spectating)


func start_spectating() -> void:
	if not _bound() or not GameManager.is_player_dead or (spectator != null and is_instance_valid(spectator)):
		return
	spectator = Spectator.new()
	spectator.name = "Spectator"
	spectator.candidates = spectate_candidates
	var local := _local_player()
	if local != null:
		spectator.limits_from = local.get_node_or_null(^"Camera2D") as Camera2D
		spectator.global_position = local.global_position
	_main.add_child(spectator)


func is_spectating() -> bool:
	return spectator != null and is_instance_valid(spectator)


## 관전할 수 있는 살아 있는 동료 [[이름, 노드], …]
func spectate_candidates() -> Array:
	var list: Array = []
	for id in party:
		if id == my_id() or bool(party[id][0]):
			continue
		var node: Node2D = null
		if is_host():
			node = _puppets.get(id)
		else:
			var entry: Dictionary = _mirrors.get(int(party[id][1]), {})
			node = entry.get("node") if not entry.is_empty() else null
		if node != null and is_instance_valid(node):
			list.append([get_player_name(id), node])
	return list


## 쓰러진 사람을 모두 일으킴 — 남은 동료가 보스를 쓰러뜨리고 다음 스테이지 야영지에 도착했을 때 (장비 · 골드는 그대로)
func revive_all() -> void:
	if not is_host() or not in_game:
		return
	_revive.rpc()
	_revive_local()


func _revive_local() -> void:
	if spectator != null and is_instance_valid(spectator):
		spectator.queue_free()
	spectator = null
	if not GameManager.is_player_dead:
		return
	GameManager.revive_player()
	for p in Player.get_all(get_tree()):
		if p.is_local():
			p.revive()
			var cam := p.get_node_or_null(^"Camera2D") as Camera2D
			if cam != null:
				cam.make_current()
	GameManager.show_notice("다시 일어났습니다! (장비 · 골드 그대로)", Color(0.6, 1.0, 0.7))


# ============================================================ 참가자
func _bind_client() -> void:
	# 내 컴퓨터의 고정 오브젝트(상인 · 텔레포트 등)는 지우고 방장 화면의 복제본을 씀
	for child in _entities.get_children():
		if not (child is Player and (child as Player).is_local()):
			child.queue_free()
	_proj_root = Node2D.new()
	_proj_root.name = "NetProjectiles"
	_main.add_child(_proj_root)
	for root in [_entities, _main]:
		(root as Node).child_entered_tree.connect(_on_client_child_entered)
	_hello.rpc_id(1)
	var pending := _pending.duplicate()
	_pending.clear()
	for call in pending:
		(call as Callable).call()


## 복제본이 _ready 에서 만들어 내는 부산물(소환 · 이펙트 등)은 지움 — 방장 화면에서 따로 옴
func _on_client_child_entered(node: Node) -> void:
	if _spawning != null and node != _spawning and not node.is_ancestor_of(_spawning):
		node.queue_free.call_deferred()


func _local_player() -> Player:
	if not _bound():
		return null
	for p in Player.get_all(get_tree()):
		if p.is_local():
			return p
	return null


func _send_state() -> void:
	var player := _local_player()
	if player == null:
		return
	var buf := StreamPeerBuffer.new()
	NetVisual.capture(player, buf, _intern)
	_flush_strings(1)
	var status := player.get_net_status()
	var values: Array = []
	for key in STATUS_KEYS:
		values.append(status.get(key))
	_c_state.rpc_id(1, player.global_position, values, buf.data_array)


@rpc("authority", "unreliable_ordered")
func _snapshot(data: PackedByteArray) -> void:
	if not _bound() or not is_client():
		return
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var seq := buf.get_u32()
	if seq < _last_snap_seq:
		return
	_last_snap_seq = seq
	var ambient := NetVisual._get_color(buf)
	var canvas := _stage.get_node_or_null(^"Ambient") as CanvasModulate
	if canvas != null:
		canvas.color = ambient
	var lookup := _lookup_from(1)
	var count := buf.get_u16()
	for i in count:
		var id := buf.get_u64()
		var kind := buf.get_u8()
		var spawn_type := buf.get_u8()
		var path: String = lookup.call(buf.get_u16())
		var entry: Dictionary = _mirrors.get(id, {})
		if id == _my_puppet_id:
			NetVisual.apply(null, buf, lookup, {}, false)
			continue
		var is_new := false
		if entry.is_empty() or not is_instance_valid(entry["node"]):
			var node := _spawn_mirror(spawn_type, path, kind)
			if node == null:
				NetVisual.apply(null, buf, lookup, {}, false)
				continue
			node.set_meta(&"net_id", id)
			entry = {"node": node, "created": {}, "target": Vector2.ZERO}
			_mirrors[id] = entry
			is_new = true
		entry["seen"] = seq
		var target := NetVisual.apply(entry["node"], buf, lookup, entry["created"], false)
		entry["target"] = target
		if is_new and entry["node"] is Node2D:
			(entry["node"] as Node2D).global_position = target
	# 최근 화면 몇 장에 안 나온 것은 사라진 것
	for id in _mirrors.keys():
		if int(_mirrors[id].get("seen", 0)) < seq - 2:
			var gone: Node = _mirrors[id]["node"]
			if is_instance_valid(gone):
				gone.queue_free()
			_mirrors.erase(id)


func _spawn_mirror(spawn_type: int, path: String, kind: int) -> Node:
	if path == "":
		return null
	var node: Node = null
	match spawn_type:
		0:
			if not ResourceLoader.exists(path):
				return null
			var scene := load(path) as PackedScene
			if scene == null:
				return null
			node = scene.instantiate()
		1:
			if not ResourceLoader.exists(path):
				return null
			var script := load(path) as GDScript
			if script == null or not script.can_instantiate():
				return null
			node = script.new()
		2:
			if not ClassDB.can_instantiate(path):
				return null
			node = ClassDB.instantiate(path)
	if node == null:
		return null
	if not (node is CanvasItem):
		node.free()
		return null
	_mark_mirror(node)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	var parent: Node = _entities if kind == 0 else (_proj_root if kind == 2 else _main)
	_spawning = node
	parent.add_child(node)
	_spawning = null
	_neutralize(node)
	return node


func _mark_mirror(node: Node) -> void:
	node.set_meta(&"net_mirror", true)
	if node is CollisionObject2D:
		# 처리를 꺼도 충돌 판정에는 남아 있게 (적은 맞아야 하고, 단단한 벽은 막아야 함)
		(node as CollisionObject2D).disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	for child in node.get_children():
		_mark_mirror(child)


## 복제본은 아무것도 건드리지 않게 (적은 맞을 수 있게 남겨 둠, 단단한 벽 · 바위는 길을 막게 남겨 둠)
func _neutralize(node: Node) -> void:
	if node is CollisionObject2D and not (node is Enemy) and not (node is StaticBody2D):
		var body := node as CollisionObject2D
		body.set_deferred(&"collision_layer", 0)
		body.set_deferred(&"collision_mask", 0)
		if body is Area2D:
			body.set_deferred(&"monitoring", false)
			body.set_deferred(&"monitorable", false)
	elif node is Enemy:
		(node as Enemy).set_deferred(&"collision_mask", 0)
	if node is CPUParticles2D:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	if node is Timer:
		(node as Timer).stop()
	for child in node.get_children():
		_neutralize(child)


## 참가자: 적(복제본)에게 한 일을 방장에게
func forward_enemy_call(enemy: Enemy, method: StringName, args: Array) -> void:
	if not is_client() or not enemy.has_meta(&"net_id"):
		return
	_enemy_call.rpc_id(1, int(enemy.get_meta(&"net_id")), method, args)


func request_drop(item_id: StringName, at_global: Vector2) -> void:
	if is_client():
		_drop.rpc_id(1, String(item_id), at_global)


func request_clear_hostile() -> void:
	if is_client():
		_clear_hostile.rpc_id(1)


## 참가자가 [E]: 가까운 상호작용 오브젝트(복제본) — 상인은 내 상점을 열고, 텔레포트 · 보스문 · 상자는 방장에게 부탁
func client_interact() -> bool:
	var player := _local_player()
	if player == null or player.is_net_dead():
		return false
	var best: Interactable = null
	var best_dist := 30.0
	for id in _mirrors:
		var node := _mirrors[id]["node"] as Interactable
		if node == null or not is_instance_valid(node) or not node.enabled or not node.visible:
			continue
		var d := node.global_position.distance_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	if best == null:
		return false
	if best is ShopKeeper:
		GameManager.request_shop((best as ShopKeeper).shop_name, (best as ShopKeeper).stock_ids)
	else:
		_interact_request.rpc_id(1, int(best.get_meta(&"net_id")))
	return true


## 참가자 화면: 가까운 상호작용 오브젝트 안내를 내 용사 머리 위에
func _update_prompt() -> void:
	var player := _local_player()
	if player == null:
		return
	if _prompt == null or not is_instance_valid(_prompt):
		_prompt = Label.new()
		_prompt.set_meta(&"net_skip", true)
		_prompt.z_index = 50
		_prompt.size = Vector2(140, 12)
		_prompt.position = Vector2(-70, -48)
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.add_theme_font_size_override(&"font_size", 8)
		_prompt.add_theme_constant_override(&"outline_size", 3)
		_prompt.add_theme_color_override(&"font_outline_color", Color(0.1, 0.1, 0.17))
		player.add_child(_prompt)
	_prompt.text = client_nearest_prompt()


## 참가자: 가까운 상호작용 오브젝트의 안내 문구 (방장 쪽 안내는 방장 용사 기준이라 따로 띄움)
func client_nearest_prompt() -> String:
	var player := _local_player()
	if player == null:
		return ""
	for id in _mirrors:
		var node := _mirrors[id]["node"] as Interactable
		if node != null and is_instance_valid(node) and node.enabled and node.visible and node.global_position.distance_to(player.global_position) < 30.0:
			return node.prompt_text
	return ""


func _resolve(value: Variant) -> Variant:
	if value is Dictionary and (value as Dictionary).has("__nid"):
		for id in _mirrors:
			if id == int(value["__nid"]):
				return _mirrors[id]["node"]
		return null
	return value


func _run_calls(list: Array) -> void:
	var player := _local_player()
	if player == null:
		return
	for entry in list:
		var method := StringName(entry[0])
		if not PLAYER_CALLS.has(method):
			continue
		var args: Array = []
		for a in entry[1]:
			args.append(_resolve(a))
		if method == &"set_puppet" and args[0] == null:
			continue
		player.callv(method, args)


@rpc("authority", "reliable")
func _calls(list: Array) -> void:
	_run_calls(list)


@rpc("authority", "unreliable_ordered")
func _calls_u(list: Array) -> void:
	_run_calls(list)


@rpc("authority", "reliable")
func _your_puppet(id: int) -> void:
	_my_puppet_id = id


@rpc("authority", "reliable")
func _travel(at_global: Vector2, bounds: Rect2) -> void:
	var run := func() -> void:
		var player := _local_player()
		if player != null:
			player.teleport_to(at_global + party_offset(_player_index(my_id())), bounds)
	if _bound():
		run.call()
	else:
		_pending.append(run)


@rpc("authority", "reliable")
func _hud(signal_name: StringName, args: Array) -> void:
	var run := func() -> void: _apply_hud(signal_name, args)
	if _bound():
		run.call()
	else:
		_pending.append(run)


@rpc("authority", "unreliable_ordered")
func _hud_u(signal_name: StringName, args: Array) -> void:
	if _bound():
		_apply_hud(signal_name, args)


func _apply_hud(signal_name: StringName, args: Array) -> void:
	match signal_name:
		&"stage_changed":
			GameManager.set_stage(int(args[0]), String(args[1]))
		&"location_changed":
			GameManager.set_location(String(args[0]))
		&"kill_progress_changed":
			GameManager.set_kill_progress(int(args[0]), int(args[1]))
		&"boss_spawned":
			GameManager.report_boss_spawned(String(args[0]), int(args[1]))
		&"boss_hp_changed":
			GameManager.report_boss_hp(int(args[0]), int(args[1]))
		&"boss_defeated":
			GameManager.report_boss_defeated()


@rpc("authority", "reliable")
func _room_theme(room_name: String, texture_path: String, tint: Color) -> void:
	var run := func() -> void:
		var room := _main.get_node_or_null(NodePath("Rooms/" + room_name))
		if room != null and room.has_method(&"apply_theme"):
			var texture: Texture2D = load(texture_path) if texture_path != "" and ResourceLoader.exists(texture_path) else null
			room.apply_theme(texture, tint)
	if _bound():
		run.call()
	else:
		_pending.append(run)


@rpc("authority", "unreliable")
func _fx(fx_name: StringName, args: Array) -> void:
	if not _bound():
		return
	var m := _main
	match fx_name:
		&"burst":
			Fx.burst(m, args[0], args[1], args[2], args[3], args[4], args[5], args[6])
		&"flash":
			Fx.flash(m, args[0], args[1], args[2], args[3])
		&"shockwave":
			Fx.shockwave(m, args[0], args[1], args[2], args[3])
		&"flying_sprites":
			var texture: Texture2D = load(args[1]) if String(args[1]) != "" and ResourceLoader.exists(args[1]) else null
			Fx.flying_sprites(m, args[0], texture, args[2], args[3], args[4], args[5], args[6])
		&"pillar":
			Fx.pillar(m, args[0], args[1], args[2], args[3], args[4])
		&"cross_glint":
			Fx.cross_glint(m, args[0], args[1], args[2], args[3])


@rpc("authority", "reliable")
func _notice(text: String, color: Color) -> void:
	GameManager.show_notice(text, color)


@rpc("authority", "reliable")
func _story(key: String, mark: String) -> void:
	if _bound():
		Story.play(key, mark)


@rpc("authority", "reliable")
func _story_end() -> void:
	if Story.is_playing():
		Story.skip()


@rpc("authority", "reliable")
func _grant(kind: String, item_id: String, count: int) -> void:
	match kind:
		"item":
			if ItemDB.has_item(StringName(item_id)):
				GameManager.add_item(ItemDB.get_item(StringName(item_id)))
		"relic":
			var relic := ItemDB.get_relic(StringName(item_id))
			if relic != null:
				GameManager.add_relic(relic)
		"potion":
			var potion := ItemDB.get_potion(StringName(item_id))
			if potion != null:
				GameManager.add_potion(potion, count)
		"unlock_mythic":
			GameManager.unlock_mythic()


@rpc("authority", "reliable")
func _grant_pickup(kind: int, gold: int, item_id: String) -> void:
	var item: ItemData = ItemDB.get_item(StringName(item_id)) if item_id != "" and ItemDB.has_item(StringName(item_id)) else null
	Pickup.receive(kind as Pickup.Kind, gold, item)
	if kind == Pickup.Kind.GOLD:
		GameManager.show_notice("+%dG" % gold, Color(1.0, 0.85, 0.3))


@rpc("authority", "reliable")
func _revive() -> void:
	_revive_local()


@rpc("authority", "reliable")
func _ending() -> void:
	GameManager.report_game_cleared()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ending/ending.tscn")
