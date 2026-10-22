extends Node
## 효과음 (오토로드 Sfx). Sfx.play("gate_open") — assets/audio/sfx/<이름>.wav
## 소리 크기는 설정 「효과음」(Profile "sfx_volume", 0 ~ 1). 방장이 낸 소리는 참가자 화면에서도 남 (Net.fx_event).
## 지금 소리: gate_open(보스방 문이 열리는 굉음) · chain_break(사슬 끊김) · core_break(봉인 코어 파괴) · elite_roar(정예 등장) · trial_clear(시련 완료)

const SFX_DIR := "res://assets/audio/sfx/"
## 동시에 낼 수 있는 소리 수
const VOICES := 8

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next: int = 0
## 마지막으로 낸 소리 (테스트용)
var last_played: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


static func get_volume() -> float:
	return clampf(float(Profile.get_setting("sfx_volume")), 0.0, 1.0)


func play(sound: StringName, volume: float = 1.0) -> void:
	Net.fx_event(&"sfx", [sound, volume])
	last_played = sound
	var stream := _stream(sound)
	var master := get_volume()
	if stream == null or master <= 0.0:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(master * volume, 0.001))
	player.play()


func _stream(sound: StringName) -> AudioStream:
	if not _cache.has(sound):
		var path := SFX_DIR + String(sound) + ".wav"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]
