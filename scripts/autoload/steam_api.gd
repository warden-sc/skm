extends Node
## 스팀 연결 (오토로드 SteamApi) — GodotSteam(GDExtension 판, addons/godotsteam)이 들어 있을 때만 동작.
## 없으면(웹 · 일반 빌드 · 에디터에 안 깔림) 아무것도 하지 않고 is_running() 은 false.
##   - 시작할 때 Steam.steamInitEx 로 스팀에 연결 (APP_ID — 앱 ID 를 받으면 여기에, 0 이면 실행 파일 옆 steam_appid.txt)
##   - 매 프레임 Steam.run_callbacks()
##   - 업적(Achievements) · 운영자 개발자 스팀 ID(Admin) 가 is_running() 일 때 씀
## 개발 중 시험: 실행 파일(또는 프로젝트 폴더) 옆에 steam_appid.txt 를 만들고 480(스팀 시험용 앱 Spacewar)을 적은 뒤 스팀을 켜고 실행.

## 스팀웍스에서 받은 앱 ID (받기 전에는 0 → steam_appid.txt)
const APP_ID := 0

var _steam: Object
var _running: bool = false
## 연결 결과 문구 (설정 · 로그 확인용)
var status_text: String = "GodotSteam 없음"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton(&"Steam"):
		set_process(false)
		return
	_steam = Engine.get_singleton(&"Steam")
	var result: Variant = _init_steam()
	var ok := result is Dictionary and int((result as Dictionary).get("status", 1)) == 0
	_running = ok
	status_text = "스팀 연결됨 (%s)" % get_persona_name() if ok else "스팀 연결 실패: %s" % (str((result as Dictionary).get("verbal", result)) if result is Dictionary else str(result))
	print("[SteamApi] ", status_text)
	set_process(ok)


## GodotSteam 버전마다 steamInitEx 인자가 달라서 이름으로 맞춤
##   4.6 이상: steamInitEx(app_id, embed_callbacks) · 그 전: steamInitEx(retrieve_current_stats, app_id, embed_callbacks)
func _init_steam() -> Variant:
	if not _steam.has_method(&"steamInitEx"):
		return _steam.call(&"steamInit")
	for method in _steam.get_method_list():
		if method["name"] == "steamInitEx":
			var args: Array = method["args"]
			if not args.is_empty() and String(args[0]["name"]).begins_with("retrieve"):
				return _steam.call(&"steamInitEx", true, APP_ID, false)
			break
	return _steam.call(&"steamInitEx", APP_ID, false)


func _process(_delta: float) -> void:
	_steam.call(&"run_callbacks")


## 스팀에 연결되어 있는지
func is_running() -> bool:
	return _running


## 스팀 객체 (연결 안 됐으면 null)
func steam() -> Object:
	return _steam if _running else null


func get_steam_id() -> int:
	return int(_steam.call(&"getSteamID")) if _running else 0


func get_persona_name() -> String:
	return String(_steam.call(&"getPersonaName")) if _steam != null and _steam.has_method(&"getPersonaName") else ""


## 업적 달성 (Achievements 가 부름)
func set_achievement(id: String) -> void:
	if not _running:
		return
	_steam.call(&"setAchievement", id)
	_steam.call(&"storeStats")
