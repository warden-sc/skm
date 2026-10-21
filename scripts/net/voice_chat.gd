class_name VoiceChat
extends Node
## 멀티플레이 음성 채팅 (Net 의 자식 「Voice」 — 모든 컴퓨터에서 같은 경로라 서로 RPC 를 주고받음).
##
## 말하기 : 마이크(AudioStreamMicrophone) → 「VoiceMic」 버스의 AudioEffectCapture 로 소리를 떠 옴
##          → 16kHz 한 줄(모노)로 줄이고 μ-law 8비트로 눌러 40ms 마다 한 묶음씩 보냄 (한 사람당 약 16KB/초)
## 듣기   : 보낸 사람마다 AudioStreamGenerator 하나 — 받은 묶음을 풀어 이어 붙여 재생
## 방식   : 설정 「음성 채팅」 = 끄기 / 눌러서 말하기([V] 누르는 동안) / 항상 켜기(소리가 클 때만 보냄)
## 방장을 거쳐 다른 참가자에게 전달됨 (SceneMultiplayer 의 서버 중계). 웹 버전은 멀티플레이가 없어 쓰지 않음.

signal speaking_changed(peer_id: int, speaking: bool)

enum Mode { OFF, PUSH_TO_TALK, OPEN }

const MODE_NAMES := ["끄기", "눌러서 말하기 [V]", "항상 켜기"]
const RATE := 16000
## 한 번에 보내는 양 (샘플 수 — 40ms)
const CHUNK := 640
const MIC_BUS := "VoiceMic"
## 「항상 켜기」에서 이 크기(RMS)보다 작은 소리는 보내지 않음 (조용할 때 숨소리 · 잡음)
const GATE := 0.02
## 받은 소리가 이보다 많이 밀려 있으면 버림 (지연이 쌓이지 않게)
const MAX_BUFFER_SEC := 0.35
## 말소리가 끊긴 뒤 「말하는 중」 표시가 꺼질 때까지
const SPEAKING_HOLD := 0.4
## 네트워크 채널 (화면 복제와 섞이지 않게)
const CHANNEL := 3

var talking: bool = false  # 이 컴퓨터가 지금 보내는 중인지
var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
var _carry: float = 0.0
var _pending := PackedFloat32Array()
var _players: Dictionary = {}       # peer → AudioStreamPlayer
var _speaking: Dictionary = {}      # peer → 남은 표시 시간
var _sent_chunks: int = 0
var _received: Dictionary = {}      # peer → 받은 샘플 수 (테스트용)
var last_peak: Dictionary = {}      # peer → 마지막 묶음의 최대 크기 (테스트용)
static var _decode_table := PackedFloat32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


static func get_mode() -> int:
	return clampi(int(Profile.get_setting("voice")), 0, MODE_NAMES.size() - 1)


## 마이크를 쓸 수 있는 버전인지 (웹은 멀티플레이 자체가 없음)
static func is_supported() -> bool:
	return not OS.has_feature("web")


func _process(delta: float) -> void:
	for peer in _speaking.keys():
		_speaking[peer] = float(_speaking[peer]) - delta
		if float(_speaking[peer]) <= 0.0:
			_speaking.erase(peer)
			speaking_changed.emit(peer, false)
	var want := Net.is_online() and get_mode() != Mode.OFF and is_supported()
	if not want:
		_stop_mic()
		talking = false
		return
	_start_mic()
	var pressed := get_mode() == Mode.OPEN or (Input.is_action_pressed(&"voice_talk") and not _typing())
	if _capture == null:
		return
	var available := _capture.get_frames_available()
	if available <= 0:
		return
	var frames := _capture.get_buffer(available)
	if not pressed:
		_set_talking(false)
		_pending.clear()
		return
	feed(frames, AudioServer.get_mix_rate())


## 마이크 소리(스테레오 프레임)를 받아 16kHz 로 줄여 쌓고, 한 묶음이 차면 보냄. 테스트는 이걸 직접 부름
func feed(frames: PackedVector2Array, mix_rate: float) -> void:
	var step := mix_rate / RATE
	var index := _carry
	while index < frames.size():
		var i := int(index)
		# 건너뛰는 사이 값들의 평균 (간단한 저역 통과 — 줄일 때 「치익」 소리 방지)
		var acc := 0.0
		var count := 0
		var end := mini(int(index + step), frames.size())
		for j in range(i, maxi(end, i + 1)):
			acc += (frames[j].x + frames[j].y) * 0.5
			count += 1
		_pending.append(acc / count)
		index += step
	_carry = index - frames.size()
	while _pending.size() >= CHUNK:
		var chunk := _pending.slice(0, CHUNK)
		_pending = _pending.slice(CHUNK)
		if get_mode() == Mode.OPEN and rms(chunk) < GATE:
			_set_talking(false)
			continue
		_set_talking(true)
		_sent_chunks += 1
		if Net.is_online():
			_voice.rpc(encode(chunk))


func _set_talking(on: bool) -> void:
	if on:
		_speaking[Net.my_id()] = SPEAKING_HOLD
		if not talking:
			speaking_changed.emit(Net.my_id(), true)
	talking = on


## 지금 말하는 중인 사람들 (나 포함)
func get_speakers() -> Array:
	return _speaking.keys()


func is_speaking(peer_id: int) -> bool:
	return _speaking.has(peer_id)


func get_sent_chunks() -> int:
	return _sent_chunks


func get_received_samples(peer_id: int) -> int:
	return int(_received.get(peer_id, 0))


@rpc("any_peer", "unreliable_ordered", "call_remote", CHANNEL)
func _voice(data: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0 or data.is_empty() or data.size() > CHUNK * 2:
		return
	var samples := decode(data)
	_received[sender] = get_received_samples(sender) + samples.size()
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	last_peak[sender] = peak
	if not _speaking.has(sender):
		speaking_changed.emit(sender, true)
	_speaking[sender] = SPEAKING_HOLD
	var player := _player_for(sender)
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	# 너무 밀려 있으면(끊겼다 한꺼번에 온 소리) 새로 시작 — 지연이 쌓이지 않게
	var queued := (player.stream as AudioStreamGenerator).buffer_length * RATE - playback.get_frames_available()
	if queued > MAX_BUFFER_SEC * RATE:
		playback.clear_buffer()
	var frames := PackedVector2Array()
	frames.resize(samples.size())
	for i in samples.size():
		frames[i] = Vector2(samples[i], samples[i])
	if playback.can_push_buffer(frames.size()):
		playback.push_buffer(frames)


func _player_for(peer_id: int) -> AudioStreamPlayer:
	var player := _players.get(peer_id) as AudioStreamPlayer
	if player != null and is_instance_valid(player):
		return player
	player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = RATE
	generator.buffer_length = 0.6
	player.stream = generator
	player.volume_db = 2.0
	add_child(player)
	player.play()
	_players[peer_id] = player
	return player


## 나간 사람의 재생기 정리 (Net 이 부름)
func forget(peer_id: int) -> void:
	var player := _players.get(peer_id) as AudioStreamPlayer
	if player != null and is_instance_valid(player):
		player.queue_free()
	_players.erase(peer_id)
	_received.erase(peer_id)
	last_peak.erase(peer_id)
	if _speaking.has(peer_id):
		_speaking.erase(peer_id)
		speaking_changed.emit(peer_id, false)


func reset() -> void:
	for peer in _players.keys():
		forget(peer)
	_stop_mic()
	_pending.clear()
	talking = false


# ============================================================ 마이크
func _start_mic() -> void:
	if _mic != null:
		return
	var bus := AudioServer.get_bus_index(MIC_BUS)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, MIC_BUS)
		AudioServer.add_bus_effect(bus, AudioEffectCapture.new())
		AudioServer.set_bus_mute(bus, true)  # 내 목소리가 내 스피커로 나오지 않게 (떠 오기는 계속됨)
	_capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture
	_capture.clear_buffer()
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = MIC_BUS
	add_child(_mic)
	_mic.play()


func _stop_mic() -> void:
	if _mic == null:
		return
	_mic.stop()
	_mic.queue_free()
	_mic = null
	_capture = null
	_set_talking(false)


## 글자를 입력하는 칸에 있으면 [V] 를 말하기로 쓰지 않음
func _typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


# ============================================================ 코덱 (μ-law 8비트)
static func rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var sum := 0.0
	for s in samples:
		sum += s * s
	return sqrt(sum / samples.size())


static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size())
	for i in samples.size():
		out[i] = _mulaw(samples[i])
	return out


static func decode(data: PackedByteArray) -> PackedFloat32Array:
	if _decode_table.is_empty():
		_decode_table.resize(256)
		for code in 256:
			_decode_table[code] = _unmulaw(code)
	var out := PackedFloat32Array()
	out.resize(data.size())
	for i in data.size():
		out[i] = _decode_table[data[i]]
	return out


const _MU := 255.0


static func _mulaw(sample: float) -> int:
	var x := clampf(sample, -1.0, 1.0)
	var y := signf(x) * log(1.0 + _MU * absf(x)) / log(1.0 + _MU)
	return clampi(roundi((y + 1.0) * 127.5), 0, 255)


static func _unmulaw(code: int) -> float:
	var y := float(code) / 127.5 - 1.0
	return signf(y) * (pow(1.0 + _MU, absf(y)) - 1.0) / _MU
