class_name StageManager
extends Node
## 스테이지 진행 / 몬스터 스폰 / 드랍 / 텔레포트 처리
##
## 스테이지 하나의 흐름
##   야영지(CAMP)  : 상인에게서 장비 구매·판매. 안전 지대. 텔레포트[E] → 사냥터
##   사냥터(FIELD) : 스테이지마다 다른 「해방 시련」을 이루면 북쪽 보스문의 봉인이 풀림 (귀환 텔레포트로 야영지 복귀 가능)
##                   처치(몬스터 N마리) · 봉인 코어 파괴(사냥터 곳곳 수정 3개) · 정예 처치(강해진 정예 하나) · 제단 정화(원 안에서 버티기)
##                   — gate_trial_for(stage). 1~2스테이지와 튜토리얼은 처치. 시련을 이루면 문이 웅장하게 열림 (BossGate.open)
##   보스방(BOSS)  : 보스문[E]으로 입장 → 보스 등장
##   토벌(CLEARED) : 보스 처치 → 보물상자(다음 스테이지 등급 장비 1개) + 다음 스테이지 텔레포트 등장
##   다음 스테이지 텔레포트[E] → 다음 스테이지 야영지
##   마지막 스테이지 보스 토벌 → 「모든 스테이지 클리어」 → ending_delay 초 뒤 엔딩 화면 → 타이틀 메뉴로
##
## 히든 던전 (이스터에그)
##   30~35스테이지 사냥터의 정해진 구석에 「고대 용의 비늘」이 하나씩 희미하게 숨겨져 있음 (닿으면 주움)
##   6개를 모두 모은 채 HIDDEN_GATE_STAGE(35) 보스를 쓰러뜨리면, 보물상자를 연 뒤 「고대의 문」이 열림
##   고대의 문[E] → 보스방이 고대 용의 둥지로 바뀌고 히든 보스(hidden_stage.boss_scene) 등장 (잡몹 없음)
##   히든 보스 토벌 → 특별 보물상자(장비 2개) + 다음 스테이지 텔레포트 (마지막 스테이지면 엔딩)
##
## 최종장
##   마지막 스테이지 보스 토벌 → finale_delay 초 뒤 같은 보스방에 야영지의 상인이 나타나 최종 보스전(finale_stage.boss_scene)
##   최종 보스 토벌 → 「모든 스테이지 클리어」 → 엔딩
##
## 드랍 등급
##   일반 몬스터: 그 스테이지 등급(1~10 일반 · 11~40 희귀 · 41~70 레어 · 71~100 전설)에서 이미 풀린 단계 + 드랍 전용 장비 (ItemDB.get_drop_pool)
##   보물상자   : 골드 + 칸마다 확률로 장비 (chest_item_chances 35% · 10% — 대개는 골드만, 히든 100% · 60% · 30%) — 다음 스테이지 등급에서
##                조금 앞선 단계까지, 드랍 전용 포함, 아직 없는 것 우선. 장비가 하나도 안 나오면 골드 두 배
##   신화       : 10스테이지마다 보스가 하나씩 바로 가방으로 (_grant_mythic) — 100스테이지 보스를 쓰러뜨리면 봉인 해제
##
## Node 상속이므로 자신의 위치 함수는 쓰지 않고, 타입이 지정된 Node2D 참조(방, 마커, 플레이어)만 사용합니다.

enum State { CAMP, FIELD, BOSS, CLEARED, GAME_OVER }

const LOCATION_CAMP := "야영지"
const LOCATION_FIELD := "사냥터"
const LOCATION_BOSS := "보스방"
const ENDING_SCENE := "res://scenes/ending/ending.tscn"
const LOCATION_HIDDEN := "고대 용의 둥지"
const PORTAL_SCENE := "res://scenes/world/portal.tscn"
const ANCIENT_PORTAL_TEXTURE := "res://assets/sprites/world/portal_ancient.png"
## 이 스테이지 보스를 비늘을 모두 모은 채 쓰러뜨리면 히든 던전이 열림
const HIDDEN_GATE_STAGE := 35

@export var entities_root: Node2D
@export var player: Player
@export var stages: Array[StageData] = []

@export_group("Rooms")
@export var camp_room: Room
@export var field_room: Room
@export var boss_room: Room

@export_group("Points")
@export var camp_spawn: Marker2D
@export var field_spawn: Marker2D
@export var boss_arrival: Marker2D
@export var boss_spawn: Marker2D
@export var chest_spot: Marker2D

@export_group("Objects")
@export var field_portal: Portal
@export var camp_portal: Portal
@export var next_stage_portal: Portal
@export var boss_gate: BossGate
@export var screen_fade: ScreenFade
@export var pickup_scene: PackedScene
@export var chest_scene: PackedScene
## 히든 던전 구성 (보스·바닥·분위기). 비워 두면 히든 던전 없음
@export var hidden_stage: StageData
## 최종장 구성 (마지막 스테이지 보스를 쓰러뜨린 뒤의 최종 보스). 비워 두면 마지막 스테이지 보스 토벌로 바로 엔딩
@export var finale_stage: StageData

@export_group("Balance")
@export var min_spawn_distance: float = 150.0
## 무기 드랍이 여러 개 겹치지 않도록 금화 개수 상한
@export var max_coin_pickups_per_kill: int = 4
@export var boss_entry_delay: float = 1.2
## 마지막 보스를 쓰러뜨린 뒤 엔딩 화면으로 넘어가기까지의 시간(초)
@export var ending_delay: float = 4.0
## 마지막 스테이지 보스를 쓰러뜨린 뒤 최종 보스가 나타나기까지의 시간(초)
@export var finale_delay: float = 3.0
## 보스 상자의 장비 칸별 확률 (칸마다 따로 굴림). 장비가 하나도 안 나오면 골드 두 배
@export var chest_item_chances: Array[float] = [0.35, 0.1]
## 히든 보스(고대 용의 보물) 상자
@export var hidden_chest_item_chances: Array[float] = [1.0, 0.6, 0.3]

## true 면 텔레포트 시 화면 전환 없이 즉시 이동 (테스트용)
var instant_travel: bool = false
var chest_rng := RandomNumberGenerator.new()
## 마지막으로 연 상자의 골드 · 장비 (테스트 · 안내용)
var last_chest_gold: int = 0
var last_chest_items: Array[ItemData] = []

var _state: State = State.CAMP
var _spawn_timer: float = 0.0
var _kills: int = 0
var _kill_target: int = 0

# ---- 보스방 해방 시련
enum GateTrial { KILL, SEAL_CORES, ELITE, ALTAR }
const GATE_TRIAL_NAMES := ["몬스터 처치", "봉인 코어 파괴", "정예 처치", "제단 정화"]
const SEAL_CORE_SCENE := preload("res://scenes/enemies/seal_core.tscn")
const SEAL_CORE_COUNT := 3
## 봉인 코어 체력 = 그 스테이지 사냥터 몬스터 체력 × 이만큼
const SEAL_CORE_HP_MOBS := 7.0
## 정예: 체력 · 공격력 · 크기 · 골드 배율
const ELITE_HP := 12.0
const ELITE_POWER := 1.35
const ELITE_SCALE := 1.55
const ELITE_GOLD := 6.0
## 제단 정화에 필요한 시간(초, 원 안에 서 있는 동안만 참)
const ALTAR_TIME := 18.0
var gate_trial: GateTrial = GateTrial.KILL
var _trial_count: int = 0           # 부순 코어 수 / 정예 처치(0·1)
var _altar_progress: float = 0.0    # 0 ~ ALTAR_TIME
var _altar: GateAltar
var _elite_name: String = ""
var _altar_report: float = 0.0
var _boss: Enemy
## 히든 보스(고대 드래곤 아르케)가 주는 고대 용의 피 개수
const DRAGON_BLOOD_REWARD := 5
## 마지막으로 쓰러진 보스의 자리 (신화 장비가 여기서 날아옴)
var _boss_fall_position: Vector2 = Vector2.ZERO
var _chest: Chest
var _ending_timer: Timer
## 스테이지 분위기 (어두운 스테이지는 화면을 어둡게)
var _ambient: CanvasModulate
## 보스방 장식 (빈 옥좌 등)
var _boss_decor: Sprite2D
## 히든 던전: 고대의 문 / 열릴 차례인지 / 지금 히든 보스전인지 / 이번 스테이지에서 이미 깼는지
var _hidden_portal: Portal
var _hidden_pending: bool = false
var _hidden_active: bool = false
var _hidden_done: bool = false
## 최종장: 지금 최종 보스전인지 / 이번 스테이지에서 이미 깼는지
var _finale_active: bool = false
var _finale_done: bool = false


func _ready() -> void:
	if Net.is_client():
		_ready_client()
		return
	assert(entities_root != null and player != null, "StageManager: entities_root / player 를 지정하세요.")
	assert(not stages.is_empty() and pickup_scene != null and chest_scene != null, "StageManager: stages / pickup_scene / chest_scene 을 지정하세요.")
	assert(camp_room != null and field_room != null and boss_room != null, "StageManager: 방 3개를 지정하세요.")
	GameManager.player_died.connect(_on_player_died)
	GameManager.item_dropped.connect(spawn_dropped_item)
	chest_rng.randomize()
	field_portal.interacted.connect(enter_field)
	camp_portal.interacted.connect(return_to_camp)
	boss_gate.interacted.connect(enter_boss_room)
	next_stage_portal.interacted.connect(go_to_next_stage)
	_create_hidden_portal()
	add_to_group(&"stage_manager")
	_ending_timer = Timer.new()
	_ending_timer.one_shot = true
	_ending_timer.timeout.connect(go_to_ending)
	add_child(_ending_timer)
	_ambient = CanvasModulate.new()
	_ambient.name = "Ambient"
	add_child(_ambient)
	_setup_stage(GameManager.stage)
	_arrive_at_camp()
	# 문구는 띄우는 순간의 스테이지로 만듦 (그 사이 스테이지가 바뀌어도 맞는 번호가 나오게)
	get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
		Net.announce("STAGE %d 「%s」 — 상인에게서 장비를 갖추고 텔레포트[E]로 사냥터에 가세요" % [GameManager.stage, GameManager.stage_name], Color(0.6, 1.0, 0.7))
		Story.queue("%d스테이지 도착" % GameManager.stage))


## 멀티플레이 참가자: 스테이지 진행은 방장 컴퓨터에서 — 여기서는 화면 색(어둠)만 받아서 씀
func _ready_client() -> void:
	add_to_group(&"stage_manager")
	_ambient = CanvasModulate.new()
	_ambient.name = "Ambient"
	add_child(_ambient)
	set_process(false)
	set_physics_process(false)


func _process(delta: float) -> void:
	if _state != State.GAME_OVER and not GameManager.is_game_cleared:
		GameManager.play_time += delta


func _physics_process(delta: float) -> void:
	if _state != State.FIELD:
		return
	_update_altar(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		var data := get_stage_data()
		_spawn_timer = data.spawn_interval * randf_range(0.7, 1.2)
		if get_tree().get_nodes_in_group(&"enemies").size() < get_max_alive():
			_spawn_regular_enemy()


func get_state() -> State:
	return _state


## 현재 스테이지의 구성 데이터
func get_stage_data(stage: int = -1) -> StageData:
	if stage < 0:
		stage = GameManager.stage
	return stages[clampi(stage - 1, 0, stages.size() - 1)]


## 전체 스테이지 수 (= 엔딩까지 쓰러뜨려야 할 보스 수)
func get_final_stage() -> int:
	return stages.size()


func is_final_stage(stage: int = -1) -> bool:
	if stage < 0:
		stage = GameManager.stage
	return stage >= get_final_stage()


func get_max_alive() -> int:
	return get_stage_data().max_alive + int(GameManager.get_difficulty_info()["max_alive_bonus"])


func get_kill_progress() -> Vector2i:
	return Vector2i(_kills, _kill_target)


func get_chest() -> Chest:
	return _chest if is_instance_valid(_chest) else null


# ============================================================ 이동 (텔레포트)
## 야영지 → 사냥터
func enter_field() -> void:
	if _state == State.CAMP:
		_travel(_do_enter_field)


## 사냥터 → 야영지 (진행도는 유지)
func return_to_camp() -> void:
	if _state == State.FIELD:
		_travel(_do_return_to_camp)


## 사냥터 → 보스방 (보스문 해방 후)
func enter_boss_room() -> void:
	if _state == State.FIELD and boss_gate.is_open():
		_travel(_do_enter_boss_room)


## 보스방 → 다음 스테이지 야영지 (보스 토벌 후). 마지막 스테이지에서 히든 던전이 열렸던 경우엔 엔딩으로
func go_to_next_stage() -> void:
	if _state != State.CLEARED:
		return
	if is_final_stage():
		if not next_stage_portal.enabled:
			return
		if not GameManager.is_game_cleared:
			GameManager.report_game_cleared()
		go_to_ending()
		return
	_travel(_do_go_to_next_stage)


## 모든 스테이지 클리어 → 엔딩 화면 (엔딩에서 난이도 선택 화면으로 돌아감)
func go_to_ending() -> void:
	if not GameManager.is_game_cleared or Net.is_party_dead():
		return
	_ending_timer.stop()
	_travel(_do_go_to_ending)


func _do_go_to_ending() -> void:
	Net.broadcast_ending()
	get_tree().paused = false
	get_tree().change_scene_to_file(ENDING_SCENE)


## 지정 스테이지의 야영지로 즉시 이동 (디버그 / 테스트용)
func go_to_stage(stage: int) -> void:
	stage = clampi(stage, 1, get_final_stage())
	_clear_enemies()
	if _boss != null and is_instance_valid(_boss):
		GameManager.report_boss_defeated()
	_boss = null
	_setup_stage(stage)
	_arrive_at_camp()


func _travel(action: Callable) -> void:
	Sfx.play(&"teleport")
	if instant_travel or screen_fade == null:
		action.call()
	elif not screen_fade.is_busy():
		screen_fade.transition(action)


func _do_enter_field() -> void:
	_release_projectiles()
	player.teleport_to(field_spawn.global_position, field_room.get_bounds())
	_state = State.FIELD
	_spawn_timer = 0.6
	GameManager.set_location(LOCATION_FIELD)
	_place_dragon_scale()
	if boss_gate.is_open():
		Net.announce("보스방이 열려 있습니다! 사냥터 북쪽의 문으로 가세요", Color(1.0, 0.6, 0.5))
	else:
		_spawn_trial_objects()
		Net.announce(get_trial_description(), Color(1.0, 0.9, 0.5))


func _do_return_to_camp() -> void:
	_clear_enemies()
	_arrive_at_camp()
	Net.announce("야영지로 귀환했습니다", Color(0.6, 1.0, 0.7))


func _do_enter_boss_room() -> void:
	_clear_enemies()
	_release_projectiles()
	player.teleport_to(boss_arrival.global_position, boss_room.get_bounds())
	_state = State.BOSS
	GameManager.set_location(LOCATION_BOSS)
	Net.announce("무언가 다가온다…", Color(1.0, 0.5, 0.5))
	get_tree().create_timer(boss_entry_delay, false).timeout.connect(_spawn_boss)


func _do_go_to_next_stage() -> void:
	# 보스방에 남은 전리품은 자동으로 회수
	for node in entities_root.get_children():
		var pickup := node as Pickup
		if pickup != null:
			pickup.collect()
	var next_stage := GameManager.stage + 1
	_setup_stage(next_stage)
	_arrive_at_camp()
	Net.revive_all()  # 멀티플레이: 남은 동료가 보스를 쓰러뜨려 다음 스테이지에 왔으니 쓰러졌던 동료가 장비 · 골드 그대로 부활
	Net.announce("STAGE %d 「%s」 도착!" % [next_stage, GameManager.stage_name], Color(0.6, 1.0, 0.7))
	Story.queue("%d스테이지 도착" % next_stage)
	var unlocked := _rarity_unlocked_at(next_stage)
	if unlocked != "":
		_notice_later("상점에 %s 등급 장비가 입고되었습니다!" % unlocked, Color(1.0, 0.85, 0.4), 2.8)


func _arrive_at_camp() -> void:
	_release_projectiles()
	player.teleport_to(camp_spawn.global_position, camp_room.get_bounds())
	_state = State.CAMP
	GameManager.set_location(LOCATION_CAMP)


# ============================================================ 스테이지 준비
func _setup_stage(stage: int) -> void:
	var data := get_stage_data(stage)
	GameManager.return_stolen_weapon()  # 헤르메스에게 빼앗긴 무기가 남아 있으면 돌려받음 (안전장치)
	GameManager.set_stage(stage, data.stage_name)
	for room in [camp_room, field_room, boss_room]:
		(room as Room).apply_theme(data.floor_texture, data.wall_tint)
	_ambient.color = data.ambient_color
	_set_boss_decor(data)
	_hidden_pending = false
	_hidden_active = false
	_hidden_done = false
	_finale_active = false
	_finale_done = false
	if _hidden_portal != null:
		_hidden_portal.enabled = false
	_kills = 0
	_kill_target = data.kill_target
	gate_trial = gate_trial_for(stage)
	_trial_count = 0
	_altar_progress = 0.0
	_elite_name = ""
	_clear_trial_objects()
	boss_gate.seal(_kills, _kill_target)
	_report_trial_progress()
	next_stage_portal.enabled = false
	if is_instance_valid(_chest):
		_chest.queue_free()
	_chest = null


## 보스방 장식 (5스테이지 빈 옥좌 등). 스테이지가 바뀌면 교체
func _set_boss_decor(data: StageData) -> void:
	if is_instance_valid(_boss_decor):
		_boss_decor.queue_free()
	_boss_decor = null
	if data.boss_decor_texture == null:
		return
	_boss_decor = Sprite2D.new()
	_boss_decor.name = "BossDecor"
	_boss_decor.texture = data.boss_decor_texture
	_boss_decor.z_index = -2
	_add_entity(_boss_decor, boss_spawn.global_position + data.boss_decor_offset)


## 지금 싸우는 보스 (없으면 null)
func get_boss() -> Enemy:
	return _boss if is_instance_valid(_boss) else null


func get_boss_decor() -> Sprite2D:
	return _boss_decor if is_instance_valid(_boss_decor) else null


# ============================================================ 보스
func _spawn_boss() -> void:
	if _state != State.BOSS or _boss != null:
		return
	var data := hidden_stage if _hidden_active else (finale_stage if _finale_active else get_stage_data())
	var boss := data.boss_scene.instantiate() as Enemy
	assert(boss != null, "boss_scene 루트에는 Enemy 계열 스크립트가 필요합니다.")
	_boss = boss
	boss.health_changed.connect(_on_boss_health_changed)
	var at := boss_spawn.global_position + data.boss_spawn_offset
	_add_enemy(boss, at, boss_room.get_arena_rect())
	Fx.explosion(player, at, Color(1.0, 0.4, 0.4), 50.0, 3)
	GameManager.report_boss_spawned("%s  · 방어력 %d" % [boss.display_name, boss.get_defense_value()], boss.max_hp)
	Net.announce(data.boss_intro_text if data.boss_intro_text != "" else "보스 등장: %s" % boss.display_name, Color(1.0, 0.4, 0.5))
	if _hidden_active:
		Story.queue("히든 보스 등장")
	elif not _finale_active:  # 최종장은 최종 보스가 직접 [최종장 등장] 대사를 띄움
		Story.queue("%d스테이지 보스 등장" % GameManager.stage)


func _on_boss_defeated() -> void:
	_boss = null
	_state = State.CLEARED
	Story.queue("히든 보스 토벌" if _hidden_active else ("최종장 토벌" if _finale_active else "%d스테이지 보스 토벌" % GameManager.stage))
	GameManager.report_boss_defeated()
	_release_projectiles()
	GameManager.heal_full()
	_clear_enemies()
	if _hidden_active:
		_on_hidden_boss_defeated()
		return
	if _finale_active:
		_finale_active = false
		_finale_done = true
		_on_final_boss_defeated()
		return
	if not GameManager.tutorial_mode:
		Achievements.on_stage_cleared(GameManager.stage)
	_grant_mythic(GameManager.stage)
	_hidden_pending = is_hidden_gate_ready()
	if is_final_stage() and not _hidden_pending:
		if finale_stage != null and not _finale_done:
			_begin_finale()
		else:
			_on_final_boss_defeated()
		return
	next_stage_portal.set_prompt(_next_portal_prompt())
	next_stage_portal.enabled = true
	if is_mythic_reward_stage() and not _hidden_pending:
		# 신화 장비 스테이지: 보상은 신화 장비 하나뿐 (보물상자 · 골드 없음)
		Net.announce("보스 토벌! 보상은 신화 장비 — 텔레포트로 다음 스테이지로 가세요", Color(1.0, 0.45, 0.5))
		return
	# 보물상자 + 다음 스테이지 텔레포트 (히든 던전이 열릴 차례면 상자를 연 뒤 고대의 문)
	_spawn_chest(false)
	if _hidden_pending:
		Net.announce("보스 토벌! …고대 용의 비늘들이 떨리기 시작한다. 보물상자를 열어 보세요", Color(1.0, 0.9, 0.6))
	else:
		Net.announce("보스 토벌! 보물상자를 열고 텔레포트로 다음 스테이지로 가세요", Color(1.0, 0.85, 0.4))


## 이 스테이지 보스가 신화 장비를 주는지 (10스테이지마다 — 히든 · 최종장 제외)
func is_mythic_reward_stage() -> bool:
	return not _hidden_active and not _finale_active and ItemDB.get_mythic_for_stage(GameManager.stage) != null


func _spawn_chest(hidden_reward: bool) -> void:
	var chest := chest_scene.instantiate() as Chest
	chest.opened.connect(_on_chest_opened.bind(hidden_reward))
	_chest = chest
	_add_entity(chest, chest_spot.global_position)


func _next_portal_prompt() -> String:
	return "[E] 여정을 마치기 (엔딩)" if is_final_stage() else "[E] STAGE %d 로 이동" % (GameManager.stage + 1)


# ============================================================ 신화 장비
## 10스테이지마다 보스가 신화 장비를 넘겨줌 (가방으로 바로). 100스테이지 보스를 쓰러뜨리면 봉인이 모두 풀림
func _grant_mythic(stage: int) -> void:
	var mythic := ItemDB.get_mythic_for_stage(stage)
	if mythic != null:
		Net.grant_all("item", mythic.id)  # 멀티플레이: 동료들도 하나씩
	if mythic != null and not GameManager.owns_item(mythic.id):
		GameManager.add_item(mythic)
		Achievements.unlock(&"FIRST_MYTHIC")
		if mythic.icon != null:
			_fly_icon(mythic.icon, _boss_fall_position if _boss_fall_position != Vector2.ZERO else player.global_position)
		Fx.explosion(player, player.global_position + Vector2(0, -8), mythic.get_rarity_color(), 40.0, 3)
		_notice_later("[신화] %s 을(를) 받았다 — %s" % [mythic.display_name, "봉인됨 · 100스테이지를 클리어하면 착용 가능" if not GameManager.mythic_unlocked and stage < 100 else "가방에 들어감"],
			mythic.get_rarity_color(), 1.2)
	if is_final_stage(stage):
		Net.grant_all("relic", &"last_trumpet")
		Net.grant_all("unlock_mythic", &"")
	if is_final_stage(stage) and GameManager.add_relic(ItemDB.get_relic(&"last_trumpet")):
		_notice_later("[신화] 최후의 나팔을 받았다 — [X] 하늘의 심판", ItemData.RARITY_COLORS[ItemData.Rarity.MYTHIC], 1.9)
	if is_final_stage(stage) and not GameManager.mythic_unlocked:
		GameManager.unlock_mythic()
		_notice_later("신화 장비 %d개의 봉인이 풀렸다! [Tab] 인벤토리에서 장착하세요" % GameManager.get_mythic_items().size(), ItemData.RARITY_COLORS[ItemData.Rarity.MYTHIC], 2.6)


## 보스가 쓰러진 자리에서 장비 그림이 떠올라 용사에게 날아감
func _fly_icon(texture: Texture2D, from: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = texture
	s.z_index = 60
	s.scale = Vector2.ONE * 1.5
	entities_root.add_child(s)
	s.global_position = from
	var tween := s.create_tween()
	tween.tween_property(s, "global_position", from + Vector2(0, -24), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(s, "global_position", player.global_position + Vector2(0, -8), 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(s.queue_free)


# ============================================================ 최종장
func is_in_finale() -> bool:
	return _finale_active


## 마지막 스테이지 보스 토벌 → 잠시 뒤 최종 보스전
func _begin_finale() -> void:
	next_stage_portal.enabled = false
	Net.announce("대천사가 쓰러졌다… 그런데 어디선가 느릿한 박수 소리가 들려온다", Color(1.0, 0.85, 0.5))
	get_tree().create_timer(maxf(finale_delay, 0.05), false).timeout.connect(start_finale)


## 최종 보스 등장 (테스트에서도 직접 호출)
func start_finale() -> void:
	if _state != State.CLEARED or _finale_done or _finale_active or Net.is_party_dead() or finale_stage == null:
		return
	_finale_active = true
	_state = State.BOSS
	GameManager.set_stage(GameManager.stage, "최종장 · " + finale_stage.stage_name)
	apply_world(finale_stage)
	_spawn_boss()


## 보스방을 다른 세계(스테이지)의 모습으로 바꿈 — 최종 보스의 세계 전환
func apply_world(data: StageData) -> void:
	if data == null:
		return
	boss_room.apply_theme(data.floor_texture, data.wall_tint)
	_ambient.color = data.ambient_color


## 마지막 보스 토벌: 상자/텔레포트 대신 잠시 뒤 엔딩
func _on_final_boss_defeated() -> void:
	next_stage_portal.enabled = false
	GameManager.report_game_cleared()
	Fx.explosion(player, player.global_position, Color(1.0, 0.9, 0.5), 80.0, 3)
	Net.announce("모든 스테이지 클리어! 세상에 평화가 찾아옵니다…", Color(1.0, 0.9, 0.45))
	_ending_timer.start(maxf(ending_delay, 0.05))


func _on_chest_opened(chest: Chest, hidden_reward: bool = false) -> void:
	# 골드는 항상, 장비는 칸마다 확률로 (다음 스테이지 등급에서, 조금 앞선 단계까지 · 드랍 전용 장비 포함)
	var rarity := ItemData.max_rarity_for_stage(GameManager.stage + 1)
	var candidates := ItemDB.get_chest_candidates(rarity, GameManager.stage + 6 + (10 if hidden_reward else 0), true)
	var not_owned := candidates.filter(func(it: ItemData) -> bool: return not GameManager.owns_item(it.id))
	var pool: Array = not_owned if not not_owned.is_empty() else candidates
	pool = pool.duplicate()
	pool.shuffle()
	var chances: Array[float] = hidden_chest_item_chances if hidden_reward else chest_item_chances
	var picked: Array[ItemData] = []
	for chance in chances:
		if picked.size() < pool.size() and chest_rng.randf() < chance:
			picked.append(pool[picked.size()])
	var names := PackedStringArray()
	for i in picked.size():
		var item := picked[i]
		var drop := pickup_scene.instantiate() as Pickup
		drop.setup_item(item)
		_add_entity(drop, chest.global_position + Vector2(-12.0 * i + 6.0 * (picked.size() - 1), 14))
		names.append("[%s] %s" % [item.get_grade_text(), item.display_name])
	# 장비가 하나도 안 나오면 골드를 두 배로
	var gold := roundi(Balance.chest_gold(GameManager.stage) * get_gold_multiplier() * (3.0 if hidden_reward else 1.0)
		* chest_rng.randf_range(0.8, 1.2) * (2.0 if picked.is_empty() else 1.0))
	last_chest_gold = gold
	last_chest_items = picked
	if names.is_empty():
		Net.announce("%s골드 %d" % ["고대 용의 보물: " if hidden_reward else "보물상자: ", gold], Color(1.0, 0.86, 0.35))
	else:
		Net.announce(("고대 용의 보물: " if hidden_reward else "보물상자: ") + ", ".join(names) + " · 골드 %d" % gold,
			Color(1.0, 0.9, 0.55) if hidden_reward else picked[0].get_rarity_color())
	for i in 4:
		var coin := pickup_scene.instantiate() as Pickup
		@warning_ignore("integer_division")
		coin.setup_gold(gold / 4 + (gold % 4 if i == 0 else 0))
		_add_entity(coin, chest.global_position)
	if _hidden_pending and not hidden_reward:
		open_hidden_portal()


func _on_boss_health_changed(current: int, max_hp: int) -> void:
	GameManager.report_boss_hp(current, max_hp)


func _on_player_died() -> void:
	if Net.is_online():
		return  # 멀티플레이: 동료가 살아 있으면 계속 (모두 쓰러지면 Net 이 게임 오버 → on_party_wiped)
	_state = State.GAME_OVER


## 멀티플레이 전멸 → 게임 오버 (몬스터는 더 나오지 않음)
func on_party_wiped() -> void:
	_state = State.GAME_OVER


# ============================================================ 스폰
func _spawn_regular_enemy() -> void:
	var scene := get_stage_data().pick_enemy_scene()
	if scene == null:
		return
	var enemy := scene.instantiate() as Enemy
	assert(enemy != null, "적 씬 루트에는 Enemy 계열 스크립트가 필요합니다.")
	var arena := field_room.get_arena_rect()
	_add_enemy(enemy, _pick_spawn_position(arena), arena)


## 모든 몬스터는 여기서 난이도 배율을 적용받고 트리에 들어갑니다.
## summoned: 보스 · 몬스터가 부른 졸개 (골드가 적음)
func _add_enemy(enemy: Enemy, at_global: Vector2, arena: Rect2, summoned: bool = false) -> void:
	enemy.apply_difficulty(GameManager.get_difficulty_info())
	_apply_gold(enemy, summoned)
	enemy.arena_rect = arena
	enemy.died.connect(_on_enemy_died)
	enemy.summon_requested.connect(_on_summon_requested)
	_add_entity(enemy, at_global)


## 처치 골드: 스테이지 수입 곡선(Balance.stage_income)에서 — 사냥터 몬스터는 처치 목표 수로 나눠 45%, 보스 25%
## 난이도 배율 · 같이 하는 사람 수 배율을 곱함. 씬에 골드 0 으로 적힌 것(분신 · 미끼 · 부서지는 부위 등)은 그대로 0
func _apply_gold(enemy: Enemy, summoned: bool) -> void:
	if enemy.gold_max <= 0:
		return
	var data := get_stage_data()
	var center: float
	if enemy.is_boss and not summoned:
		center = Balance.boss_gold(GameManager.stage)
	else:
		center = Balance.mob_gold(GameManager.stage, data.kill_target if data != null else 12) * (Balance.SUMMON_RATIO if summoned else 1.0)
	center *= get_gold_multiplier()
	enemy.gold_min = maxi(1, roundi(center * (1.0 - Balance.GOLD_SPREAD)))
	enemy.gold_max = maxi(enemy.gold_min, roundi(center * (1.0 + Balance.GOLD_SPREAD)))


## 골드 배율 = 난이도 × 같이 하는 사람 수
func get_gold_multiplier() -> float:
	return float(GameManager.get_difficulty_info()["gold"]) * Balance.party_gold_multiplier(Net.get_player_count() if Net.is_online() else 1)


## 충돌 콜백 도중에도 안전하도록 항상 call_deferred 로 트리에 추가합니다.
## 인벤토리에서 버린 장비를 바닥에 (멀티플레이 참가자가 버린 것도 방장이 여기로)
func spawn_dropped_item(item: ItemData, by_peer: int, at_global: Vector2) -> Pickup:
	if item == null:
		return null
	var drop := pickup_scene.instantiate() as Pickup
	drop.setup_dropped(item, by_peer)
	_add_entity(drop, at_global + Vector2(randf_range(-6, 6), 10))
	return drop


func _add_entity(node: Node2D, at_global: Vector2) -> void:
	node.position = entities_root.to_local(at_global)
	entities_root.add_child.call_deferred(node)


func _pick_spawn_position(arena: Rect2) -> Vector2:
	var best := arena.get_center()
	for i in 12:
		var candidate := Vector2(randf_range(arena.position.x, arena.end.x), randf_range(arena.position.y, arena.end.y))
		best = candidate
		if candidate.distance_to(player.global_position) >= min_spawn_distance:
			break
	return best


func _on_summon_requested(scene: PackedScene, at_global: Vector2, summoner: Enemy) -> void:
	if scene == null or _state == State.GAME_OVER:
		return
	var minion := scene.instantiate() as Enemy
	if minion == null:
		return
	minion.commander = summoner
	# 소환된 졸개는 드랍이 적습니다
	minion.item_drop_chance *= 0.3
	var arena := boss_room.get_arena_rect() if _state == State.BOSS else field_room.get_arena_rect()
	_add_enemy(minion, at_global.clamp(arena.position, arena.end), arena, true)
	if summoner != null and is_instance_valid(summoner):
		summoner.register_minion(minion)


func _clear_enemies() -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var leftover := node as Enemy
		if leftover != null and not leftover.is_dead():
			leftover.despawn()
	# 바닥 장판(점액·불바다·마법 장판)과 떨어지던 마법, 티탄이 박아 둔 바위, 마리오네트 스위치, 레비아탄 폭풍 지대도 함께 정리
	for group in [&"ground_zones", &"sky_strikes", &"cover_rocks", &"puppet_switches", &"storm_fields", &"ice_pillars", &"abyss_torches", &"dragon_scales"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()


## 최후의 나팔: 적의 탄 · 예고 장판 · 해로운 장판을 모두 지움
func clear_hostile_attacks() -> void:
	if Net.is_client():
		Net.request_clear_hostile()
		return
	_release_projectiles()


func _release_projectiles() -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool != null:
		pool.release_all()
	# 보스가 쓰러진 뒤 아직 터지지 않은 예고 장판 · 보스가 남긴 해로운 장판이 플레이어를 때리지 않도록 정리
	for strike in get_tree().get_nodes_in_group(&"aoe_strikes"):
		strike.queue_free()
	for zone in get_tree().get_nodes_in_group(&"hostile_zones"):
		zone.queue_free()


# ============================================================ 사망 / 드랍
func _on_enemy_died(enemy: Enemy) -> void:
	# 신화 장비를 주는 보스(10스테이지마다)는 신화 장비 말고는 아무것도 떨어뜨리지 않음
	if not (enemy == _boss and is_mythic_reward_stage()):
		_spawn_drops(enemy.global_position, enemy)
	GameManager.report_kill()
	if enemy == _boss:
		_boss_fall_position = enemy.get_hit_center()
		_on_boss_defeated()
		return
	if _state == State.FIELD and not boss_gate.is_open():
		if enemy.has_meta(&"gate_core"):
			_trial_count += 1
			Sfx.play(&"core_break")
			Fx.explosion(enemy, enemy.get_hit_center(), Color(0.8, 0.55, 1.0), 40.0, 3)
			Fx.pillar(enemy, enemy.global_position, Color(0.8, 0.6, 1.0), 20.0, 120.0, 0.6)
			if _trial_count < SEAL_CORE_COUNT:
				Net.announce("봉인 코어 파괴! (%d / %d)" % [_trial_count, SEAL_CORE_COUNT], Color(0.85, 0.65, 1.0))
		elif enemy.has_meta(&"gate_elite"):
			_trial_count = 1
		else:
			_kills += 1
		_report_trial_progress()
		if is_trial_complete():
			_unlock_boss_gate()


## 보스방 해방 시련 (스테이지마다) — 1~2스테이지 · 튜토리얼은 처치, 그 뒤로는 네 가지가 돌아가며
static func gate_trial_for(stage: int) -> GateTrial:
	if stage <= 2 or GameManager.tutorial_mode:
		return GateTrial.KILL
	return [GateTrial.SEAL_CORES, GateTrial.ELITE, GateTrial.ALTAR, GateTrial.KILL][stage % 4]


func is_trial_complete() -> bool:
	match gate_trial:
		GateTrial.SEAL_CORES:
			return _trial_count >= SEAL_CORE_COUNT
		GateTrial.ELITE:
			return _trial_count >= 1
		GateTrial.ALTAR:
			return _altar_progress >= ALTAR_TIME
	return _kills >= _kill_target


## 사냥터에 들어갈 때 안내 문구
func get_trial_description() -> String:
	match gate_trial:
		GateTrial.SEAL_CORES:
			return "보스방 해방 시련: 사냥터 곳곳의 봉인 코어 %d개를 부수세요" % SEAL_CORE_COUNT
		GateTrial.ELITE:
			return "보스방 해방 시련: 정예 「%s」를 쓰러뜨리세요" % _elite_name if _elite_name != "" else "보스방 해방 시련: 정예를 쓰러뜨리세요"
		GateTrial.ALTAR:
			return "보스방 해방 시련: 정화 제단의 원 안에서 %d초 동안 버티세요" % roundi(ALTAR_TIME)
	return "몬스터 %d마리를 처치하면 보스방이 열립니다" % _kill_target


## HUD · 보스문에 보일 진행도 글 (예: 「봉인 코어 파괴 1 / 3」)
func get_trial_progress_text() -> String:
	match gate_trial:
		GateTrial.SEAL_CORES:
			return "봉인 코어 파괴 %d / %d" % [_trial_count, SEAL_CORE_COUNT]
		GateTrial.ELITE:
			return "정예 %s 처치 %d / 1" % ["「%s」" % _elite_name if _elite_name != "" else "", _trial_count]
		GateTrial.ALTAR:
			return "제단 정화 %d%%" % roundi(_altar_progress / ALTAR_TIME * 100.0)
	return ""


func get_altar() -> GateAltar:
	return _altar if is_instance_valid(_altar) else null


func _report_trial_progress() -> void:
	var text := get_trial_progress_text()
	match gate_trial:
		GateTrial.SEAL_CORES:
			GameManager.set_kill_progress(_trial_count, SEAL_CORE_COUNT, text)
		GateTrial.ELITE:
			GameManager.set_kill_progress(_trial_count, 1, text)
		GateTrial.ALTAR:
			GameManager.set_kill_progress(roundi(_altar_progress / ALTAR_TIME * 100.0), 100, text)
		_:
			GameManager.set_kill_progress(_kills, _kill_target)
	boss_gate.update_progress(_kills, _kill_target, text)


## 시련 달성 → 보스문이 웅장하게 열림
func _unlock_boss_gate() -> void:
	if boss_gate.is_open():
		return
	_clear_trial_objects(true)
	Sfx.play(&"trial_clear", 0.7)
	if not GameManager.tutorial_mode:
		Achievements.on_trial_cleared(gate_trial)
	boss_gate.open()
	Net.announce("%s 완료! 보스방의 봉인이 풀렸습니다 — 사냥터 북쪽의 문으로" % GATE_TRIAL_NAMES[gate_trial], Color(1.0, 0.55, 0.45))


## 사냥터에 시련 물건을 둠 (아직 남아 있는 것만 — 야영지에 다녀오면 부서진 코어 · 쓰러진 정예는 그대로)
func _spawn_trial_objects() -> void:
	var arena := field_room.get_arena_rect()
	match gate_trial:
		GateTrial.SEAL_CORES:
			var spots := [Vector2(0.18, 0.3), Vector2(0.82, 0.3), Vector2(0.5, 0.8)]
			for i in range(_trial_count, SEAL_CORE_COUNT):
				var core := SEAL_CORE_SCENE.instantiate() as BossPart
				core.max_hp = maxi(1, roundi(_sample_mob_hp() * SEAL_CORE_HP_MOBS))
				core.set_meta(&"gate_core", true)
				_add_enemy(core, arena.position + arena.size * spots[i], arena)
				Fx.pillar(core, arena.position + arena.size * spots[i], Color(0.8, 0.55, 1.0), 16.0, 90.0, 0.6)
		GateTrial.ELITE:
			if _trial_count < 1:
				_spawn_elite(arena)
		GateTrial.ALTAR:
			if not is_instance_valid(_altar):
				_altar = GateAltar.new()
				_add_entity(_altar, arena.position + arena.size * Vector2(0.5, 0.55))


func _spawn_elite(arena: Rect2) -> void:
	var scene := get_stage_data().pick_enemy_scene()
	if scene == null:
		_trial_count = 1
		return
	var elite := scene.instantiate() as Enemy
	elite.set_meta(&"gate_elite", true)
	elite.max_hp = maxi(1, roundi(elite.max_hp * ELITE_HP))
	elite.contact_damage = roundi(elite.contact_damage * ELITE_POWER)
	elite.power *= ELITE_POWER
	elite.item_drop_chance = 1.0
	_elite_name = "정예 " + elite.display_name
	elite.display_name = _elite_name
	elite.scale = Vector2.ONE * ELITE_SCALE
	elite.base_tint = Color(1.25, 1.1, 0.75)
	var at := arena.position + arena.size * Vector2(randf_range(0.3, 0.7), randf_range(0.25, 0.45))
	_add_enemy(elite, at, arena)
	elite.gold_min *= int(ELITE_GOLD)
	elite.gold_max *= int(ELITE_GOLD)
	var aura := Fx.make_aura(Color(1.0, 0.8, 0.3), 18, 10.0, Vector2(0, -40), 0.6)
	aura.position = Vector2(0, -10)
	elite.add_child(aura)
	aura.emitting = true
	Fx.pillar(elite, at, Color(1.0, 0.75, 0.3), 20.0, 110.0, 0.6)
	Sfx.play(&"elite_roar")
	_report_trial_progress()


## 이 스테이지 사냥터 몬스터 하나의 씬 체력 (난이도 · 딜 인플레는 _add_enemy 에서 함께 곱해짐)
func _sample_mob_hp() -> float:
	var scene := get_stage_data().pick_enemy_scene()
	if scene == null:
		return 20.0
	var probe := scene.instantiate() as Enemy
	var value := float(probe.max_hp)
	probe.free()
	return value


func _clear_trial_objects(keep_altar_fade: bool = false) -> void:
	if is_instance_valid(_altar):
		if keep_altar_fade:
			var altar := _altar
			var tween := altar.create_tween()
			tween.tween_property(altar, "modulate:a", 0.0, 0.8)
			tween.tween_callback(altar.queue_free)
		else:
			_altar.queue_free()
	_altar = null


## 제단 정화: 누군가 원 안에 있으면 차오름
func _update_altar(delta: float) -> void:
	if gate_trial != GateTrial.ALTAR or boss_gate.is_open() or not is_instance_valid(_altar):
		return
	var inside := false
	for p in Player.get_all(get_tree()):
		if not p.is_net_dead() and p.global_position.distance_to(_altar.global_position) <= GateAltar.RADIUS:
			inside = true
	_altar.active = inside
	if inside:
		_altar_progress = minf(_altar_progress + delta, ALTAR_TIME)
		_altar_report -= delta
		if _altar_report <= 0.0 or _altar_progress >= ALTAR_TIME:
			_altar_report = 0.25
			_report_trial_progress()
	_altar.progress = _altar_progress / ALTAR_TIME
	if _altar_progress >= ALTAR_TIME:
		_unlock_boss_gate()


func _spawn_drops(at_global: Vector2, enemy: Enemy) -> void:
	# 1) 골드: 확정 드랍. 금액을 몇 개의 동전으로 나눠 흩뿌림
	var total_gold := randi_range(enemy.gold_min, maxi(enemy.gold_min, enemy.gold_max))
	if total_gold > 0:
		@warning_ignore("integer_division")
		var coins := clampi(total_gold / 5 + 1, 1, max_coin_pickups_per_kill)
		@warning_ignore("integer_division")
		var per_coin := total_gold / coins
		var remainder := total_gold - per_coin * coins
		for i in coins:
			var coin := pickup_scene.instantiate() as Pickup
			coin.setup_gold(per_coin + (remainder if i == 0 else 0))
			_add_entity(coin, at_global)

	# 2) 장비: 일반 몬스터만 확률 드랍 (보스는 보물상자로 대신 보상)
	#    그 스테이지 등급에서 이미 풀린 단계의 장비 + 그 몬스터만 떨어뜨리는 드랍 전용 장비(고블린 단검 등)
	if enemy.is_boss or enemy.item_drop_ids.is_empty() or randf() >= enemy.item_drop_chance:
		return
	var allowed := ItemDB.get_drop_pool(GameManager.stage, enemy.item_drop_ids)
	if allowed.is_empty():
		return
	var drop := pickup_scene.instantiate() as Pickup
	drop.setup_item(allowed.pick_random())
	_add_entity(drop, at_global)


# ============================================================ 히든 던전
func is_hidden_gate_ready() -> bool:
	return hidden_stage != null and not _hidden_done and GameManager.stage == HIDDEN_GATE_STAGE and GameManager.has_all_dragon_scales()


func is_in_hidden_dungeon() -> bool:
	return _hidden_active


func get_hidden_portal() -> Portal:
	return _hidden_portal


func _create_hidden_portal() -> void:
	var scene := load(PORTAL_SCENE) as PackedScene
	if scene == null:
		return
	_hidden_portal = scene.instantiate() as Portal
	_hidden_portal.name = "HiddenPortal"
	_hidden_portal.portal_color = Color(1.0, 0.9, 0.6)
	if ResourceLoader.exists(ANCIENT_PORTAL_TEXTURE):
		_hidden_portal.portal_texture = load(ANCIENT_PORTAL_TEXTURE) as Texture2D
	_hidden_portal.prompt_text = "[E] 고대의 문 — 고대 용의 둥지 (히든)"
	_hidden_portal.enabled = false
	_hidden_portal.position = entities_root.to_local(next_stage_portal.global_position + Vector2(-260, 0))
	_hidden_portal.interacted.connect(enter_hidden_dungeon)
	entities_root.add_child.call_deferred(_hidden_portal)


## 비늘 6개 + 35스테이지 보스 토벌 + 상자 오픈 → 고대의 문
func open_hidden_portal() -> void:
	_hidden_pending = false
	if _hidden_portal == null:
		return
	_hidden_portal.enabled = true
	Fx.explosion(player, _hidden_portal.global_position + Vector2(0, -16), Color(1.0, 0.9, 0.6), 60.0, 3)
	Net.announce("여섯 개의 고대 용의 비늘이 공명한다… 「고대의 문」이 열렸다!", Color(1.0, 0.92, 0.6))


func enter_hidden_dungeon() -> void:
	if _state == State.CLEARED and _hidden_portal != null and _hidden_portal.enabled:
		_travel(_do_enter_hidden_dungeon)


func _do_enter_hidden_dungeon() -> void:
	for node in entities_root.get_children():
		var pickup := node as Pickup
		if pickup != null:
			pickup.collect()
	if is_instance_valid(_chest):
		_chest.queue_free()
	_chest = null
	_hidden_portal.enabled = false
	next_stage_portal.enabled = false
	_hidden_active = true
	_clear_enemies()
	_release_projectiles()
	boss_room.apply_theme(hidden_stage.floor_texture, hidden_stage.wall_tint)
	_ambient.color = hidden_stage.ambient_color
	_set_boss_decor(hidden_stage)
	player.teleport_to(boss_arrival.global_position, boss_room.get_bounds())
	_state = State.BOSS
	GameManager.set_stage(GameManager.stage, "히든 · " + hidden_stage.stage_name)
	GameManager.set_location(LOCATION_HIDDEN)
	Net.announce("「%s」 — 공기가 무겁다. 무언가 아주 오래된 것이 깨어난다…" % hidden_stage.stage_name, Color(1.0, 0.9, 0.6))
	get_tree().create_timer(boss_entry_delay, false).timeout.connect(_spawn_boss)


func _on_hidden_boss_defeated() -> void:
	_hidden_active = false
	_hidden_done = true
	GameManager.hidden_cleared = true
	Achievements.unlock(&"HIDDEN_CLEAR")
	var blood := ItemDB.get_potion(&"dragon_blood")
	if blood != null:
		Net.grant_all("potion", blood.id, DRAGON_BLOOD_REWARD)
		var got := GameManager.add_potion(blood, DRAGON_BLOOD_REWARD)
		_notice_later("[신화] 고대 용의 피 %d병을 받았다 — 봉인됨 · 100스테이지를 클리어하면 [C] 로 사용" % got, blood.get_rarity_color(), 2.4)
	_spawn_chest(true)
	next_stage_portal.set_prompt(_next_portal_prompt())
	next_stage_portal.enabled = true
	Net.announce("고대 드래곤 토벌! 고대 용의 보물상자가 나타났다", Color(1.0, 0.92, 0.6))


## 30~35스테이지 사냥터: 정해진 자리에 고대 용의 비늘 (이미 주웠으면 없음)
func _place_dragon_scale() -> void:
	var stage := GameManager.stage
	if hidden_stage == null or not GameManager.DRAGON_SCALE_STAGES.has(stage) or GameManager.has_dragon_scale(stage):
		return
	var scale_node := DragonScale.new()
	scale_node.collected.connect(_on_dragon_scale_collected.bind(stage))
	_add_entity(scale_node, get_dragon_scale_spot(stage))


## 스테이지마다 정해진 비늘 자리 (사냥터 구석 — 매번 같은 곳)
func get_dragon_scale_spot(stage: int) -> Vector2:
	var arena := field_room.get_arena_rect()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9973 * stage + 31
	# 왼쪽 위 구석은 HUD 패널에 가려 보이지 않으므로 나머지 세 구석 중 하나
	var corners: Array[Vector2] = [Vector2(arena.end.x, arena.position.y), Vector2(arena.position.x, arena.end.y), arena.end]
	var corner := corners[rng.randi() % corners.size()]
	var inward := (arena.get_center() - corner).sign() * Vector2(rng.randf_range(20.0, 70.0), rng.randf_range(16.0, 46.0))
	return corner + inward


func _on_dragon_scale_collected(_scale: DragonScale, stage: int) -> void:
	if not GameManager.collect_dragon_scale(stage):
		return
	var count := GameManager.get_dragon_scale_count()
	var total := GameManager.DRAGON_SCALE_STAGES.size()
	if count >= total:
		Net.announce("고대 용의 비늘 (%d/%d) — 비늘들이 하나의 이름을 속삭인다… 「아르케」" % [count, total], Color(1.0, 0.92, 0.6))
	else:
		Net.announce("고대 용의 비늘을 주웠다 (%d/%d) — 아주 오래된 힘이 느껴진다" % [count, total], Color(1.0, 0.9, 0.6))


# ============================================================ 기타
func _rarity_unlocked_at(stage: int) -> String:
	var names := PackedStringArray()
	for rarity in ItemData.RARITY_UNLOCK_STAGE:
		if ItemData.RARITY_UNLOCK_STAGE[rarity] == stage:
			names.append(ItemData.RARITY_NAMES[rarity])
	return ", ".join(names)


func _notice_later(text: String, color: Color, delay: float) -> void:
	get_tree().create_timer(delay, false).timeout.connect(GameManager.show_notice.bind(text, color))
