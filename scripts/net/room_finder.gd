class_name RoomFinder
extends Node
## 같은 네트워크(공유기 · 와이파이)의 「공개 방」 찾기.
## 공개 방의 방장은 1초마다 DISCOVERY_PORT 로 방 정보를 뿌리고(Net), 이 노드는 그것을 받아 목록을 만듭니다.
## (비공개 방은 뿌리지 않음 — 초대 코드로만 들어감. 인터넷 너머의 공개 방 목록은 중계 서버가 있어야 해서 없음)

signal rooms_changed

const DISCOVERY_PORT := 24571
const MAGIC := "CRUSADER1"
## 이만큼 소식이 없으면 목록에서 뺌
const EXPIRE := 3.5

## 주소 "ip:port" → {"ip", "port", "name", "count", "max", "difficulty", "in_game", "seen"}
var rooms: Dictionary = {}

var _udp: PacketPeerUDP
var _listening: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 듣기 시작 (포트를 못 열면 false — 이미 다른 창이 듣는 중 등)
func start() -> bool:
	if _listening:
		return true
	if OS.has_feature("web"):
		return false
	_udp = PacketPeerUDP.new()
	if _udp.bind(DISCOVERY_PORT) != OK:
		_udp = null
		return false
	_listening = true
	return true


func stop() -> void:
	if _udp != null:
		_udp.close()
	_udp = null
	_listening = false
	rooms.clear()


func is_listening() -> bool:
	return _listening


func get_room_list() -> Array:
	var list := rooms.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	return list


func _process(_delta: float) -> void:
	if _udp == null:
		return
	var changed := false
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet().get_string_from_utf8()
		var info := parse(packet, _udp.get_packet_ip())
		if info.is_empty():
			continue
		var key := "%s:%d" % [info["ip"], info["port"]]
		if not rooms.has(key):
			changed = true
		info["seen"] = Time.get_ticks_msec()
		rooms[key] = info
	var now := Time.get_ticks_msec()
	for key in rooms.keys():
		if now - int(rooms[key]["seen"]) > EXPIRE * 1000.0:
			rooms.erase(key)
			changed = true
	if changed:
		rooms_changed.emit()


## 방장이 뿌리는 한 줄: MAGIC|포트|방장 이름|인원|최대|난이도|게임 중(0/1)
static func make_packet(port: int, host_name: String, count: int, max_players: int, difficulty: int, in_game: bool) -> String:
	return "|".join([MAGIC, str(port), host_name.replace("|", " "), str(count), str(max_players), str(difficulty), "1" if in_game else "0"])


static func parse(packet: String, from_ip: String) -> Dictionary:
	var parts := packet.split("|")
	if parts.size() < 7 or parts[0] != MAGIC or not parts[1].is_valid_int():
		return {}
	return {"ip": from_ip, "port": int(parts[1]), "name": parts[2], "count": int(parts[3]), "max": int(parts[4]),
		"difficulty": int(parts[5]), "in_game": parts[6] == "1"}
