extends Node
## 업적 (오토로드 Achievements) — 스팀 출시를 염두에 둔 업적 목록 · 기록.
## 달성하면 화면 알림 + Profile(user://profile.cfg)에 기록. 스팀 버전에서 GodotSteam 이 들어 있으면
## (Engine.has_singleton("Steam")) 같은 id 로 Steam.setAchievement / storeStats 도 호출 → 스팀 업적과 바로 연결됨.
## 스팀웍스(파트너 사이트)에 아래 ACHIEVEMENTS 의 id 를 그대로 「API 이름」으로 등록하면 됨 (STEAM.md 참고).

signal unlocked(id: StringName)

const ACHIEVEMENTS := {
	&"FIRST_BOSS": {"name": "첫 토벌", "desc": "슬라임 킹을 쓰러뜨렸다"},
	&"STAGE_10": {"name": "옥좌의 주인", "desc": "10스테이지를 클리어했다"},
	&"STAGE_40": {"name": "신화의 문턱", "desc": "40스테이지 — 신화 이야기가 시작된다"},
	&"STAGE_70": {"name": "태양을 넘어", "desc": "70스테이지를 클리어했다"},
	&"STAGE_100": {"name": "하늘의 끝", "desc": "100스테이지 — 대천사 가브리엘을 쓰러뜨렸다"},
	&"GAME_CLEAR": {"name": "멀티버스의 끝", "desc": "멀티버스의 주인을 쓰러뜨리고 엔딩을 보았다"},
	&"HIDDEN_CLEAR": {"name": "고대 용의 비늘", "desc": "숨겨진 고대 드래곤 아르케를 쓰러뜨렸다"},
	&"FIRST_MYTHIC": {"name": "신화의 유산", "desc": "처음으로 신화 장비를 얻었다"},
	&"ALL_TRIALS": {"name": "네 가지 시련", "desc": "처치 · 봉인 코어 · 정예 · 제단, 네 해방 시련을 모두 이뤘다"},
	&"CO_OP_BOSS": {"name": "함께라면", "desc": "멀티플레이로 보스를 쓰러뜨렸다"},
	&"HARD_CLEAR": {"name": "베리하드 정복자", "desc": "베리하드로 엔딩을 보았다"},
}
const STAGE_MILESTONES := {1: &"FIRST_BOSS", 10: &"STAGE_10", 40: &"STAGE_40", 70: &"STAGE_70", 100: &"STAGE_100"}


func is_unlocked(id: StringName) -> bool:
	return Profile.achievements.has(String(id))


func get_unlocked_count() -> int:
	return Profile.achievements.size()


## 달성 (이미 했으면 아무것도 안 함). 처음이면 true
func unlock(id: StringName) -> bool:
	if not ACHIEVEMENTS.has(id) or is_unlocked(id):
		return false
	Profile.achievements.append(String(id))
	Profile.save_profile()
	GameManager.show_notice("업적 달성: %s — %s" % [ACHIEVEMENTS[id]["name"], ACHIEVEMENTS[id]["desc"]], Color(1.0, 0.85, 0.35))
	if Engine.has_singleton(&"Steam"):
		var steam := Engine.get_singleton(&"Steam")
		steam.call(&"setAchievement", String(id))
		steam.call(&"storeStats")
	unlocked.emit(id)
	return true


## 보스 토벌 (StageManager 가 부름)
func on_stage_cleared(stage: int) -> void:
	if STAGE_MILESTONES.has(stage):
		unlock(STAGE_MILESTONES[stage])
	if Net.is_online():
		unlock(&"CO_OP_BOSS")


## 해방 시련을 이룸 — 네 종류를 모두 이루면 업적
func on_trial_cleared(trial: int) -> void:
	var done: Array = Profile.get_setting("trials_done") if Profile.get_setting("trials_done") is Array else []
	if not done.has(trial):
		done = done.duplicate()
		done.append(trial)
		Profile.set_setting("trials_done", done)
	if done.size() >= 4:
		unlock(&"ALL_TRIALS")
