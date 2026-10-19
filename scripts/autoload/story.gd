extends Node
## 스토리 (오토로드 Story): 대본 파일의 [구간] 마다 적힌 「이름: 대사」 줄을 대화창(DialogueBox)으로 보여 줍니다.
## 대사가 나오는 동안 게임은 일시정지. 빈 구간은 아무것도 하지 않음.
##
## 대본 파일: res://data/story/story.txt
##   Windows 버전은 실행 파일(Crusader.exe) 옆에 story.txt 를 두면 그 파일을 먼저 읽음 (다시 빌드하지 않고 대사를 고칠 수 있게)
## 형식
##   # 로 시작하는 줄은 메모 (게임에 안 나옴)
##   [구간 이름]          ← 예: [1스테이지 도착] [1스테이지 보스 등장] [1스테이지 보스 토벌] [1스테이지 상인] [상인] [최종장 등장] [엔딩]
##   이름: 대사            ← 이름 없이 대사만 쓰면 이름 · 초상화 없이 나옴
##   @초상화 이름 = res://assets/sprites/characters/그림.png   ← 그 이름의 초상화를 바꿈

signal finished(key: String)

const STORY_PATH := "res://data/story/story.txt"
const OVERRIDE_FILE := "story.txt"
const CHARACTERS := "res://assets/sprites/characters/"
const PLAYER_NAMES := ["성기사", "주인공", "나", "플레이어"]
const MERCHANT_NAMES := ["상인", "떠돌이 대장장이", "수상한 상인"]

## false 면 대사를 건너뜀 (자동 테스트용)
var enabled: bool = true
var sections: Dictionary = {}
var portraits: Dictionary = {}
var source_path: String = ""
var _played: Dictionary = {}
var _cache: Dictionary = {}
var _box: DialogueBox
var _key: String = ""
var _queue: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var override := OS.get_executable_path().get_base_dir().path_join(OVERRIDE_FILE)
	if not OS.has_feature("editor") and FileAccess.file_exists(override):
		load_file(override)
	else:
		load_file(STORY_PATH)


func load_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	source_path = path
	load_text(FileAccess.get_file_as_string(path))


## 대본 글을 읽어 구간별 대사로 나눔
func load_text(text: String) -> void:
	sections.clear()
	portraits.clear()
	_cache.clear()
	var key := ""
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			key = line.substr(1, line.length() - 2).strip_edges()
			if not sections.has(key):
				sections[key] = []
			continue
		if line.begins_with("@초상화"):
			var eq := line.find("=")
			if eq > 0:
				var who := line.substr(4, eq - 4).strip_edges()
				var path := line.substr(eq + 1).strip_edges()
				if ResourceLoader.exists(path):
					portraits[who] = load(path) as Texture2D
			continue
		if key == "":
			continue
		var speaker := ""
		var said := line
		var colon := line.find(":")
		if colon > 0 and colon <= 24:
			speaker = line.left(colon).strip_edges()
			said = line.substr(colon + 1).strip_edges()
		(sections[key] as Array).append({"name": speaker, "text": said})


func has_lines(key: String) -> bool:
	return sections.has(key) and not (sections[key] as Array).is_empty()


func is_playing() -> bool:
	return _box != null and is_instance_valid(_box) and _box.visible


func was_played(mark: String) -> bool:
	return _played.has(mark)


## 새 게임을 시작하면 다시 볼 수 있게
func reset() -> void:
	_played.clear()
	_queue.clear()


## 지금 바로 못 보여 주면(상점 · 다른 대화 중) 끝나는 대로 보여 줌
func queue(key: String) -> void:
	if enabled and has_lines(key) and not _played.has(key) and not _queue.has(key):
		_queue.append(key)


func _process(_delta: float) -> void:
	if _queue.is_empty() or is_playing() or get_tree().paused:
		return
	play(_queue.pop_front())


## key 구간의 대사를 대화창으로 보여 줌. 실제로 시작했으면 true (끝나면 finished)
## mark: 이미 본 대사인지 기억하는 이름 (기본은 key — 한 번 본 대사는 다시 나오지 않음). "*" 이면 매번 나옴
func play(key: String, mark: String = "") -> bool:
	if mark == "" and not key.is_empty():
		mark = key
	if not enabled or not has_lines(key) or is_playing() or get_tree().paused or (mark != "*" and _played.has(mark)):
		return false
	_played[mark] = true
	_key = key
	if _box == null or not is_instance_valid(_box):
		_box = DialogueBox.new()
		_box.done.connect(_on_box_done)
		get_tree().root.add_child(_box)
	_box.start(sections[key])
	get_tree().paused = true
	return true


## 지금 대화창을 끝까지 넘김 (테스트용)
func skip() -> void:
	while is_playing():
		_box.advance()


func get_box() -> DialogueBox:
	return _box


func _on_box_done() -> void:
	get_tree().paused = false
	finished.emit(_key)


# ============================================================ 초상화
## 이름에 맞는 초상화 — 대본의 @초상화 → 주인공 · 상인 → 지금 게임의 보스 · 몬스터 이름
func portrait_for(speaker: String) -> Texture2D:
	if speaker == "":
		return null
	if portraits.has(speaker):
		return portraits[speaker]
	if _cache.has(speaker):
		return _cache[speaker]
	var tex: Texture2D = null
	if speaker in PLAYER_NAMES:
		tex = load(CHARACTERS + "player.png") as Texture2D
	elif speaker in MERCHANT_NAMES:
		tex = load(CHARACTERS + "merchant.png") as Texture2D
	elif speaker == "멀티버스의 주인":
		tex = load(CHARACTERS + "multiverse_master.png") as Texture2D
	else:
		tex = _find_enemy_texture(speaker)
	_cache[speaker] = tex
	return tex


func _find_enemy_texture(speaker: String) -> Texture2D:
	var manager := get_tree().get_first_node_in_group(&"stage_manager") as StageManager
	if manager == null:
		return null
	var scenes: Array[PackedScene] = []
	var all: Array[StageData] = []
	all.append_array(manager.stages)
	for extra in [manager.hidden_stage, manager.finale_stage]:
		if extra != null:
			all.append(extra as StageData)
	for data in all:
		if data.boss_scene != null:
			scenes.append(data.boss_scene)
		scenes.append_array(data.enemy_scenes)
	var partial: Texture2D = null
	for scene in scenes:
		var info := _scene_info(scene)
		if info.is_empty():
			continue
		if info["name"] == speaker:
			return info["texture"]
		if partial == null and (speaker in info["name"] or info["name"] in speaker):
			partial = info["texture"]
	return partial


## 씬을 만들지 않고 이름(display_name)과 그림(Sprite2D 의 texture)만 읽음
func _scene_info(scene: PackedScene) -> Dictionary:
	var state := scene.get_state()
	var name_value := ""
	var texture: Texture2D = null
	for i in state.get_node_count():
		for p in state.get_node_property_count(i):
			var prop := state.get_node_property_name(i, p)
			if i == 0 and prop == &"display_name":
				name_value = str(state.get_node_property_value(i, p))
			elif state.get_node_name(i) == &"Sprite2D" and prop == &"texture" and texture == null:
				texture = state.get_node_property_value(i, p) as Texture2D
	if name_value == "" or texture == null:
		return {}
	return {"name": name_value, "texture": texture}
