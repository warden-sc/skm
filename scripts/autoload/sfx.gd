extends Node
## 효과음 (오토로드 Sfx). Sfx.play("gate_open") — assets/audio/sfx/<이름>.ogg (만드는 법: tools/build_sfx.sh, Kenney CC0 팩)
## 소리 크기는 설정 「효과음」(Profile "sfx_volume", 0 ~ 1) × 상황별 크기(VOLUMES).
##   play()       — 세상에서 나는 소리 (몬스터 타격 · 처치 · 보스방 문 · 순간이동 …). 방장이 낸 소리는 참가자 화면에서도 남 (Net.fx_event)
##   play_local() — 이 컴퓨터의 용사 · 화면에서만 (발소리 · 피격 · 가드 · 줍기 · 장착 · 상점 · 메뉴 …)
## 이름 뒤 _2 · _3 … 파일이 있으면 그중 하나를 무작위로 (같은 소리 반복이 덜 거슬리게).
## 같은 소리를 아주 짧은 사이에 여러 번 내면(여러 마리를 한꺼번에 벨 때 등) 한 번만 — MIN_GAP.
## 화면의 모든 버튼은 누르면 「ui_click」 (Sfx 가 새로 생기는 버튼마다 연결).
## 자리 이름:
##   화면   ui_click · menu_open · menu_close · inventory_open · inventory_close · dialogue_next · denied
##   아이템 gold_pickup · item_pickup(신화 장비도 같은 소리) · item_drop · equip_weapon · equip_armor · shop_buy
##   월드   footstep · chest_open · gate_open · teleport
##   전투   hit · hit_crit · boss_hit · enemy_death · boss_death · guard_block · guard_perfect · guard_break · player_hurt · skill_cast
##   (소리 파일 없음 — 넣으면 바로 나옴) chain_break · core_break · elite_roar · trial_clear · descent · ascend

const SFX_DIR := "res://assets/audio/sfx/"
## 동시에 낼 수 있는 소리 수
const VOICES := 12
## 같은 소리를 다시 낼 수 있는 최소 간격 (초)
const MIN_GAP := 0.05
## 상황별 크기 (없으면 1.0)
const VOLUMES := {
	&"ui_click": 0.45, &"dialogue_next": 0.5, &"footstep": 0.3, &"menu_open": 0.7, &"menu_close": 0.7,
	&"inventory_open": 0.7, &"inventory_close": 0.7, &"gold_pickup": 0.6, &"item_pickup": 0.8,
	&"hit": 0.55, &"hit_crit": 0.75, &"boss_hit": 0.6, &"enemy_death": 0.6, &"player_hurt": 0.8,
	&"guard_block": 0.75, &"skill_cast": 0.6, &"teleport": 0.7,
}
## 이 소리들은 MIN_GAP 대신 이만큼 띄움
const GAPS := {&"player_hurt": 0.2, &"footstep": 0.12, &"boss_hit": 0.08, &"ui_click": 0.03}

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last_time: Dictionary = {}
var _next: int = 0
## 마지막으로 낸 소리 (테스트용)
var last_played: StringName = &""
## 지금까지 낸 소리 이름들 (테스트용 — 실제로 들리지 않은 것도 포함)
var history: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	GameManager.boss_defeated.connect(func() -> void: play_local(&"boss_death"))


## 넣어 둔 효과음 파일이 하나라도 있는지
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


## 세상에서 나는 소리 — 방장이면 참가자에게도
func play(sound: StringName, volume: float = 1.0) -> void:
	if not _ready_to_play(sound):
		return
	Net.fx_event(&"sfx", [sound, volume])
	_emit(sound, volume)


## 이 컴퓨터에서만
func play_local(sound: StringName, volume: float = 1.0) -> void:
	if _ready_to_play(sound):
		_emit(sound, volume)


## 방장이 보낸 소리 (Net) — 다시 보내지 않음
func play_remote(sound: StringName, volume: float = 1.0) -> void:
	_emit(sound, volume)


## 장비 종류에 맞는 장착 소리
func play_equip(item: ItemData) -> void:
	play_local(&"equip_weapon" if item is WeaponData else &"equip_armor")


func _ready_to_play(sound: StringName) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_time.get(sound, -10.0)) < float(GAPS.get(sound, MIN_GAP)):
		return false
	_last_time[sound] = now
	return true


func _emit(sound: StringName, volume: float) -> void:
	last_played = sound
	history.append(sound)
	if history.size() > 64:
		history.pop_front()
	var variants := _variants(sound)
	var master := get_volume()
	if variants.is_empty() or master <= 0.0:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = variants.pick_random()
	player.volume_db = linear_to_db(maxf(master * volume * float(VOLUMES.get(sound, 1.0)), 0.001))
	player.play()


## sound · sound_2 · sound_3 … 중 있는 파일들
func _variants(sound: StringName) -> Array:
	if not _cache.has(sound):
		var found: Array = []
		for i in range(1, 10):
			var stream := _load(String(sound) + ("" if i == 1 else "_%d" % i))
			if stream == null:
				break
			found.append(stream)
		_cache[sound] = found
	return _cache[sound]


func _load(file_name: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var path: String = SFX_DIR + file_name + String(ext)
		if ResourceLoader.exists(path):
			return load(path)
	return null


## 화면의 버튼: 누르면 딸깍
func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(&"no_click_sfx"):
		(node as BaseButton).pressed.connect(func() -> void: play_local(&"ui_click"))
