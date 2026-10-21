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
##   보스: 대사            ← 「보스」는 그 구간 스테이지의 보스 이름 · 초상화로 바뀜 (히든 → 고대 드래곤 아르케, 최종장 → 상인 / 멀티버스의 주인)
##   용사: 대사            ← 「용사」는 이름 · 대사 모두 플레이어가 지은 용사의 이름으로 바뀜 (GameManager.hero_name)
##   이름[표정]: 대사      ← 이름은 그대로, 초상화만 「이름[표정]」 그림 (@초상화 로 지정 — 평소 얼굴이 잠깐 보였다가 바뀜)
##   @장면: 설명            ← 넣고 싶은 게임 장면 요청 (게임에는 나오지 않음, scene_notes 에 구간과 함께 모아 둠)
##   @연출: 이름            ← 그 자리에서 장면을 보여 주고 다음 대사로 (StoryCues.run)
##   그 밖의 @ 로 시작하는 줄도 게임에는 나오지 않음

signal finished(key: String)
signal cue(cue_name: String)

const STORY_PATH := "res://data/story/story.txt"
const OVERRIDE_FILE := "story.txt"
const CHARACTERS := "res://assets/sprites/characters/"
const PLAYER_NAMES := ["성기사", "주인공", "나", "플레이어", "용사"]
const BOSS_WORD := "보스"
const HERO_WORD := "용사"
const MERCHANT_NAMES := ["상인", "떠돌이 대장장이", "수상한 상인"]
const MASTER_NAME := "멀티버스의 주인"
## 대화창 한 칸에 들어가는 글자 수 — 더 길면 띄어쓰기에서 나눠 여러 칸으로
const PAGE_CHARS := 90

## false 면 대사를 건너뜀 (자동 테스트용)
var enabled: bool = true
var sections: Dictionary = {}
var portraits: Dictionary = {}
## @장면 메모: [{"section": 구간, "text": 설명}, …] — 대사 순서 사이 어디에 적혔는지도 index 로 남김
var scene_notes: Array[Dictionary] = []
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
	scene_notes.clear()
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
		if line.begins_with("@"):
			if line.begins_with("@연출"):
				var cue_name := line.substr(3).strip_edges().trim_prefix(":").strip_edges()
				if key != "" and cue_name != "":
					(sections[key] as Array).append({"name": "", "text": "", "cue": cue_name})
			elif line.begins_with("@장면"):
				var note := line.substr(3).strip_edges().trim_prefix(":").strip_edges()
				scene_notes.append({"section": key, "index": (sections[key] as Array).size() if sections.has(key) else 0, "text": note})
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


## 저장 파일용 — 이미 본 대사 목록
func get_played_marks() -> Array:
	return _played.keys()


func set_played_marks(marks: Array) -> void:
	_played.clear()
	for mark in marks:
		_played[String(mark)] = true


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
	if not enabled or not bool(Profile.get_setting("story")) or not has_lines(key) or is_playing() or get_tree().paused or (mark != "*" and _played.has(mark)):
		return false
	_played[mark] = true
	_key = key
	if _box == null or not is_instance_valid(_box):
		_box = DialogueBox.new()
		_box.done.connect(_on_box_done)
		get_tree().root.add_child(_box)
	get_tree().paused = true  # 먼저 멈춤 — @연출 만 있는 구간은 start 안에서 바로 끝남
	Net.story_event(key, mark)  # 멀티플레이: 참가자 화면에도 같은 대사
	_box.start(resolve_lines(key))
	return true


## 「보스」 · 「용사」를 실제 이름으로 바꾼 대사: [{"name": 이름, "face": 초상화 이름, "text": 대사}, …] (@연출 은 {"cue": 이름})
## 긴 대사는 PAGE_CHARS 씩 나눠 여러 줄로
func resolve_lines(key: String) -> Array:
	var out: Array = []
	var hero := GameManager.hero_name
	var transformed := key.begins_with("최종장") and key != "최종장 등장"
	for line in (sections.get(key, []) as Array):
		if line.has("cue"):
			out.append({"name": "", "face": "", "text": "", "cue": line["cue"]})
			continue
		var speaker: String = line["name"]
		var face_tag := ""
		var bracket := speaker.find("[")
		if bracket > 0 and speaker.ends_with("]"):
			face_tag = speaker.substr(bracket)
			speaker = speaker.left(bracket).strip_edges()
		if speaker == BOSS_WORD:
			speaker = boss_name_for(key)
		elif speaker == HERO_WORD:
			speaker = hero
		var face := speaker + face_tag
		if transformed and face_tag == "" and speaker in MERCHANT_NAMES:
			face = MASTER_NAME  # 변신한 뒤의 상인은 멀티버스의 주인 얼굴
		for page in split_pages((line["text"] as String).replace(HERO_WORD, hero)):
			out.append({"name": speaker, "face": face, "text": page})
	return out


## 긴 대사를 띄어쓰기에서 끊어 PAGE_CHARS 이하로 나눔
static func split_pages(text: String) -> Array[String]:
	var pages: Array[String] = []
	var rest := text.strip_edges()
	while rest.length() > PAGE_CHARS:
		var cut := rest.rfind(" ", PAGE_CHARS)
		if cut <= PAGE_CHARS / 3.0:
			cut = PAGE_CHARS
		pages.append(rest.left(cut).strip_edges())
		rest = rest.substr(cut).strip_edges()
	pages.append(rest)
	return pages


## @연출 장면을 보여 줌 (대화창이 넘어가며 호출)
func run_cue(cue_name: String) -> void:
	cue.emit(cue_name)
	StoryCues.run(cue_name, get_tree())


## 구간에 맞는 보스 이름 — [N스테이지 …] 는 N스테이지 보스, [히든 …] 은 히든 보스, [최종장 등장] 은 상인, [최종장 …] 은 멀티버스의 주인
func boss_name_for(key: String) -> String:
	var manager := get_tree().get_first_node_in_group(&"stage_manager") as StageManager
	if key.begins_with("최종장"):
		return "상인" if key == "최종장 등장" else "멀티버스의 주인"
	var data: StageData = null
	if manager != null:
		var at := key.find("스테이지")
		if key.begins_with("히든"):
			data = manager.hidden_stage
		elif at > 0 and key.left(at).is_valid_int():
			data = manager.get_stage_data(key.left(at).to_int())
		else:
			data = manager.get_stage_data()
	if data != null and data.boss_scene != null:
		var info := _scene_info(data.boss_scene)
		if not info.is_empty():
			return info["name"]
	return BOSS_WORD


## 지금 대화창을 끝까지 넘김 (대화창의 [스킵] 버튼 · 멀티플레이 방장의 대화가 끝났을 때)
func skip() -> void:
	if is_playing():
		_box.skip_all()


func get_box() -> DialogueBox:
	return _box


func _on_box_done() -> void:
	get_tree().paused = false
	Net.story_done()
	finished.emit(_key)


# ============================================================ 초상화
## 이름에 맞는 초상화 — 대본의 @초상화 → 주인공 · 상인 → 지금 게임의 보스 · 몬스터 이름
func portrait_for(speaker: String) -> Texture2D:
	if speaker == "":
		return null
	if speaker.ends_with("]") and not portraits.has(speaker) and speaker.find("[") > 0:
		speaker = speaker.left(speaker.find("[")).strip_edges()  # 표정 그림이 없으면 평소 얼굴
	if portraits.has(speaker):
		return portraits[speaker]
	if _cache.has(speaker):
		return _cache[speaker]
	var tex: Texture2D = null
	if speaker in PLAYER_NAMES or speaker == GameManager.hero_name:
		tex = load(CHARACTERS + "player.png") as Texture2D
	elif speaker in MERCHANT_NAMES:
		tex = load(CHARACTERS + "merchant.png") as Texture2D
	elif speaker == MASTER_NAME:
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
