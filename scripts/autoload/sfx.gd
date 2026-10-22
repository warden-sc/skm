extends Node
## 효과음 (오토로드 Sfx). Sfx.play("gate_open") — assets/audio/sfx/<이름>.wav
## 소리 크기는 설정 「효과음」(Profile "sfx_volume", 0 ~ 1). 방장이 낸 소리는 참가자 화면에서도 남 (Net.fx_event).
## 지금은 소리 파일이 없음 — 효과음 · 배경음악은 나중에 정해서 넣기로 해서 임시 소리를 뺐음.
## 게임 곳곳의 Sfx.play(...) 자리는 그대로 두었으니, 같은 이름의 .wav 를 넣으면 바로 나오고 설정에 「효과음」 음량도 다시 보임.
## 자리 이름: gate_open(보스방 문) · chain_break(사슬) · core_break(봉인 코어) · elite_roar(정예 등장) · trial_clear(시련 완료)
##           descent · ascend(개발자 강림 · 퇴장, 운영자 스킬)

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


## 넣어 둔 효과음 파일이 하나라도 있는지 (없으면 설정의 「효과음」 음량 버튼도 숨김)
static func has_sounds() -> bool:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return false
	for file in dir.get_files():
		if file.ends_with(".wav") or file.ends_with(".wav.import") or file.ends_with(".ogg") or file.ends_with(".ogg.import"):
			return true
	return false


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
		_cache[sound] = null
		for ext in [".wav", ".ogg"]:
			var path := SFX_DIR + String(sound) + ext
			if ResourceLoader.exists(path):
				_cache[sound] = load(path)
				break
	return _cache[sound]
