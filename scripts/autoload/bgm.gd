extends Node
## 배경음 (오토로드 Bgm) — 사냥터 16곡 · 보스 7곡 · 야영지 3곡 · 타이틀 1곡 (Suno 유료 플랜으로 제작, docs/SUNO_PROMPTS.md).
## 지금 있는 곳(GameManager 의 스테이지 · 위치)을 보고 알맞은 곡을 고름 — 멀티플레이 참가자도 방장이 보내는 위치로 같은 곡.
##   야영지     야영지 전용 곡(CAMP_TRACKS — 파일이 있으면) · 없으면 그 스테이지의 사냥터 곡을 작게
##   사냥터     컨셉별 사냥터 곡 (FIELD_GROUPS)
##   보스방     보스 곡 (10단위 · 용 · 신 · 아바돈 · 가브리엘 · 그 밖) → 보스를 쓰러뜨리면 사냥터 곡을 작게
##   최종장     최종 보스 곡 · 히든(고대 용의 둥지)은 용 보스 곡
##   타이틀     bgm_title.ogg 가 있으면 그것, 없으면 임시로 초원 곡
## 곡이 바뀔 때는 서로 겹치며 넘어가고(CROSSFADE), 곡이 끝날 때도 처음과 겹쳐 이어져서 끊기지 않음(LOOP_OVERLAP).
## 음량: 설정 「배경음」(Profile "bgm_volume").

const DIR := "res://assets/audio/bgm/"
const CROSSFADE := 1.2
const LOOP_OVERLAP := 1.5
## 야영지 · 보스 토벌 뒤에는 이만큼 작게
const QUIET := 0.55
const TITLE_TRACK := &"bgm_field_01_meadow"

## 사냥터 곡 → 스테이지
const FIELD_GROUPS := {
	&"bgm_field_01_meadow": [1, 4, 16, 30],
	&"bgm_field_02_hellfire": [2, 9, 34, 58],
	&"bgm_field_03_ruins": [3, 14, 20, 25],
	&"bgm_field_04_machine": [11, 12, 21, 50],
	&"bgm_field_05_dark_castle": [5, 10, 17, 23],
	&"bgm_field_06_war": [6, 45, 48, 54, 59, 60],
	&"bgm_field_07_undead": [7, 35, 43, 57],
	&"bgm_field_08_dragon": [8, 31, 32, 33],
	&"bgm_field_09_sea": [13, 19, 44, 71, 96],
	&"bgm_field_10_dream": [15, 18, 29, 39],
	&"bgm_field_11_swamp_ice": [24, 26, 41, 46, 47],
	&"bgm_field_12_abyss": [27, 28, 88, 90],
	&"bgm_field_13_greek": [22, 38, 40, 42, 49, 51, 52, 53, 55, 56, 61],
	&"bgm_field_14_troy": [62, 63, 64, 65, 66, 67, 68, 69, 70, 72, 73, 74, 75, 76, 77, 78, 79, 80],
	&"bgm_field_15_sin": [37, 81, 82, 83, 84, 85, 86, 87, 89],
	&"bgm_field_16_heaven": [36, 91, 92, 93, 94, 95, 97, 98, 99, 100],
}
## 야영지 전용 곡 [첫 스테이지, 끝 스테이지, 곡] — 파일이 들어오면 자동으로 씀 (없으면 사냥터 곡을 작게)
const CAMP_TRACKS: Array = [[1, 37, &"bgm_camp_01_fantasy"], [38, 80, &"bgm_camp_02_myth"], [81, 100, &"bgm_camp_03_heaven"]]
## 타이틀 전용 곡 (파일이 들어오면 자동으로, 없으면 TITLE_TRACK)
const TITLE_THEME := &"bgm_title"
const BOSS_MILESTONE := [10, 20, 30]
const BOSS_DRAGON := [8, 31, 32, 33, 34, 35, 53]
const BOSS_GOD := [40, 50, 60, 70, 80]

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _track: StringName = &""
var _gain: float = 1.0
var _boss_down: bool = false
var _cache: Dictionary = {}
var _tweens: Array = [null, null]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	GameManager.boss_defeated.connect(func() -> void: _boss_down = true)
	GameManager.boss_spawned.connect(func(_name: String, _hp: int) -> void: _boss_down = false)
	GameManager.location_changed.connect(func(_l: String) -> void: _boss_down = false)
	GameManager.stage_changed.connect(func(_s: int) -> void: _boss_down = false)


static func field_track(stage: int) -> StringName:
	for track in FIELD_GROUPS:
		if (FIELD_GROUPS[track] as Array).has(stage):
			return track
	return TITLE_TRACK


static func boss_track(stage: int) -> StringName:
	if stage == 90:
		return &"bgm_boss_05_abaddon"
	if stage == 100:
		return &"bgm_boss_06_gabriel"
	if BOSS_GOD.has(stage):
		return &"bgm_boss_04_god"
	if BOSS_DRAGON.has(stage):
		return &"bgm_boss_03_dragon"
	if BOSS_MILESTONE.has(stage):
		return &"bgm_boss_02_milestone"
	return &"bgm_boss_01_normal"


static func has_track(track: StringName) -> bool:
	return ResourceLoader.exists(DIR + String(track) + ".ogg")


static func camp_track(stage: int) -> StringName:
	for entry in CAMP_TRACKS:
		if stage >= int(entry[0]) and stage <= int(entry[1]) and has_track(entry[2]):
			return entry[2]
	return &""


static func title_track() -> StringName:
	return TITLE_THEME if has_track(TITLE_THEME) else TITLE_TRACK


## 지금 나와야 하는 곡과 음량 비율 [곡, 비율]
func desired() -> Array:
	if get_tree().get_first_node_in_group(&"stage_manager") == null:
		return [title_track(), 1.0] if get_tree().current_scene != null and String(get_tree().current_scene.scene_file_path).contains("title") else [&"", 1.0]
	var stage := GameManager.stage
	var location := GameManager.location_name
	if GameManager.stage_name.begins_with("최종장"):
		return [&"bgm_boss_07_final", 1.0]
	if location == StageManager.LOCATION_HIDDEN:
		return [&"bgm_boss_03_dragon" if not _boss_down else &"bgm_field_08_dragon", 1.0 if not _boss_down else QUIET]
	if location == StageManager.LOCATION_BOSS:
		return [boss_track(stage), 1.0] if not _boss_down else [field_track(stage), QUIET]
	if location == StageManager.LOCATION_CAMP:
		var camp := camp_track(stage)
		return [camp, 1.0] if camp != &"" else [field_track(stage), QUIET]
	return [field_track(stage), 1.0]


func get_track() -> StringName:
	return _track


static func get_volume() -> float:
	return clampf(float(Profile.get_setting("bgm_volume")), 0.0, 1.0)


func _process(_delta: float) -> void:
	var want: Array = desired()
	if want[0] != _track:
		play(want[0], want[1])
	elif not is_equal_approx(want[1], _gain):
		_gain = want[1]
		_fade(_players[_active], _target_db(), CROSSFADE)
	elif _track != &"":
		_keep_looping()
		var p := _players[_active]
		if not _tween_running(_active) and not is_equal_approx(p.volume_db, _target_db()):
			p.volume_db = _target_db()  # 설정에서 음량을 바꾸면 바로


func _target_db() -> float:
	return linear_to_db(maxf(get_volume() * _gain, 0.0001))


## 곡 바꾸기 (없는 곡 · 빈 이름이면 조용히 사라짐)
func play(track: StringName, gain: float = 1.0) -> void:
	_track = track
	_gain = gain
	var old := _players[_active]
	_fade(old, -80.0, CROSSFADE, true)
	var stream := _stream(track)
	if stream == null:
		return
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = -80.0
	p.play()
	_fade(p, _target_db(), CROSSFADE)


## 곡이 끝나기 LOOP_OVERLAP 초 전에 다른 플레이어로 처음부터 겹쳐 틀어 이어 붙임
func _keep_looping() -> void:
	var p := _players[_active]
	if p.stream == null or not p.playing:
		return
	var left := p.stream.get_length() - p.get_playback_position()
	if left > LOOP_OVERLAP:
		return
	_fade(p, -80.0, LOOP_OVERLAP, true)
	_active = 1 - _active
	var q := _players[_active]
	q.stream = p.stream
	q.volume_db = -80.0
	q.play()
	_fade(q, _target_db(), LOOP_OVERLAP * 0.6)


func _fade(p: AudioStreamPlayer, to_db: float, time: float, stop_after: bool = false) -> void:
	var index := _players.find(p)
	if _tweens[index] != null and (_tweens[index] as Tween).is_valid():
		(_tweens[index] as Tween).kill()
	if not p.playing:
		return
	var tween := create_tween()
	_tweens[index] = tween
	# 소리 크기는 dB 가 아니라 실제 크기로 줄여야 자연스럽게 겹침
	var from_lin := db_to_linear(p.volume_db)
	var to_lin := db_to_linear(to_db)
	tween.tween_method(func(v: float) -> void: p.volume_db = linear_to_db(maxf(v, 0.0001)), from_lin, to_lin, time)
	if stop_after:
		tween.tween_callback(p.stop)


func _tween_running(index: int) -> bool:
	return _tweens[index] != null and (_tweens[index] as Tween).is_valid() and (_tweens[index] as Tween).is_running()


func _stream(track: StringName) -> AudioStream:
	if track == &"":
		return null
	if not _cache.has(track):
		var path := DIR + String(track) + ".ogg"
		_cache[track] = load(path) if ResourceLoader.exists(path) else null
	return _cache[track]


## 테스트 · 확인용: 지금 실제로 들리는 플레이어
func get_active_player() -> AudioStreamPlayer:
	return _players[_active]
