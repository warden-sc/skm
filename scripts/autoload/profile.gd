extends Node
## 이 컴퓨터의 플레이어 정보 (Profile 오토로드)
##   - 용사의 이름 · 튜토리얼을 마쳤는지 · 설정 → user://profile.cfg
##   - 모험 저장 파일 (살아 있을 때만 저장) → user://save.json
## 처음 게임을 켜면 이름이 비어 있으므로 타이틀이 이름 짓기 → 튜토리얼 순서로 안내합니다.

signal settings_changed

const PROFILE_PATH := "user://profile.cfg"
const SAVE_PATH := "user://save.json"
## 설정 기본값 — screen_shake: 화면 흔들림 · fullscreen: 전체 화면 · text_speed: 대사 글자 속도 배율 · story: 스토리 대사 보기
const DEFAULT_SETTINGS := {"screen_shake": true, "fullscreen": false, "text_speed": 1.0, "story": true, "voice": 1, "master_volume": 1.0, "sfx_volume": 0.8, "bgm_volume": 0.7, "trials_done": []}

## 테스트에서 실제 파일을 건드리지 않도록 경로를 바꿀 수 있음
var profile_path: String = PROFILE_PATH
var save_path: String = SAVE_PATH

var hero_name: String = ""
var tutorial_done: bool = false
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
## 달성한 업적 id 목록 (Achievements)
var achievements: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()


## 파일에서 다시 읽음 (없으면 처음 켠 상태)
func load_profile() -> void:
	hero_name = ""
	tutorial_done = false
	settings = DEFAULT_SETTINGS.duplicate(true)
	achievements = []
	var cfg := ConfigFile.new()
	if cfg.load(profile_path) == OK:
		hero_name = String(cfg.get_value("player", "hero_name", "")).strip_edges()
		tutorial_done = bool(cfg.get_value("player", "tutorial_done", false))
		achievements = Array(cfg.get_value("player", "achievements", []))
		for key in DEFAULT_SETTINGS:
			settings[key] = cfg.get_value("settings", key, DEFAULT_SETTINGS[key])
	if hero_name != "":
		GameManager.set_hero_name(hero_name)
	apply_settings()


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "hero_name", hero_name)
	cfg.set_value("player", "tutorial_done", tutorial_done)
	cfg.set_value("player", "achievements", achievements)
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(profile_path)


func has_hero_name() -> bool:
	return hero_name != ""


## 이름 짓기 (비우면 「용사」)
func set_hero_name(new_name: String) -> void:
	GameManager.set_hero_name(new_name)
	hero_name = GameManager.hero_name
	save_profile()


func complete_tutorial() -> void:
	tutorial_done = true
	save_profile()


func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_profile()


func apply_settings() -> void:
	# 마스터 음량 = 모든 소리(배경음 · 효과음 · 음성 채팅)가 지나는 Master 버스
	var master := clampf(float(get_setting("master_volume")), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	AudioServer.set_bus_mute(0, master <= 0.0)
	if DisplayServer.get_name() != "headless":
		var want_full := bool(get_setting("fullscreen"))
		var is_full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		if want_full != is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()


# ============================================================ 모험 저장
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## 지금 모험을 저장 (죽었거나 튜토리얼 중이면 false)
func save_game() -> bool:
	if not GameManager.can_save():
		return false
	var data := GameManager.to_save_data()
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## 저장 파일 내용 (없거나 깨졌으면 빈 Dictionary)
func read_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return parsed if parsed is Dictionary else {}


## 타이틀의 「이어하기」 버튼에 쓰는 한 줄 요약
func get_save_summary() -> String:
	var data := read_save()
	if data.is_empty():
		return ""
	var diff := clampi(int(data.get("difficulty", 0)), 0, GameManager.Difficulty.size() - 1)
	var minutes := int(float(data.get("play_time", 0.0)) / 60.0)
	@warning_ignore("integer_division")
	return "%d스테이지 · %s · %d시간 %02d분 · %s" % [int(data.get("stage", 1)), GameManager.DIFFICULTY_INFO[diff]["name"],
		minutes / 60, minutes % 60, String(data.get("saved_at", "")).left(16)]


## 저장한 모험을 GameManager 에 불러옴 (메인 씬으로 가는 건 부르는 쪽에서)
func load_game() -> bool:
	var data := read_save()
	if data.is_empty():
		return false
	GameManager.tutorial_mode = false
	return GameManager.apply_save_data(data)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
