class_name StageManager
extends Node
## 스테이지 진행 / 몬스터 스폰 / 드랍 / 텔레포트 처리
##
## 스테이지 하나의 흐름
##   야영지(CAMP)  : 상인에게서 장비 구매·판매. 안전 지대. 텔레포트[E] → 사냥터
##   사냥터(FIELD) : 일반 몬스터 처치. 처치 목표를 채우면 북쪽 보스문의 봉인이 풀림. (귀환 텔레포트로 야영지 복귀 가능)
##   보스방(BOSS)  : 보스문[E]으로 입장 → 보스 등장
##   토벌(CLEARED) : 보스 처치 → 보물상자(다음 스테이지 등급 장비 1개) + 다음 스테이지 텔레포트 등장
##   다음 스테이지 텔레포트[E] → 다음 스테이지 야영지
##   마지막 스테이지 보스 토벌 → 「모든 스테이지 클리어」 → ending_delay 초 뒤 엔딩 화면 → 난이도 선택으로
##
## 히든 던전 (이스터에그)
##   30~35스테이지 사냥터의 정해진 구석에 「고대 용의 비늘」이 하나씩 희미하게 숨겨져 있음 (닿으면 주움)
##   6개를 모두 모은 채 HIDDEN_GATE_STAGE(35) 보스를 쓰러뜨리면, 보물상자를 연 뒤 「고대의 문」이 열림
##   고대의 문[E] → 보스방이 고대 용의 둥지로 바뀌고 히든 보스(hidden_stage.boss_scene) 등장 (잡몹 없음)
##   히든 보스 토벌 → 특별 보물상자(장비 2개) + 다음 스테이지 텔레포트 (마지막 스테이지면 엔딩)
##
## 드랍 등급
##   일반 몬스터: 스테이지 등급까지만 (1스테이지 일반·희귀 / 2스테이지 레어까지 / 3스테이지 전설까지)
##   보물상자   : 다음 스테이지 등급 (1스테이지 보스 → 레어, 2스테이지 이후 → 전설) 검/활/지팡이/방패/투구/갑옷 중 하나
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

@export_group("Balance")
@export var min_spawn_distance: float = 150.0
## 무기 드랍이 여러 개 겹치지 않도록 금화 개수 상한
@export var max_coin_pickups_per_kill: int = 4
@export var boss_entry_delay: float = 1.2
## 마지막 보스를 쓰러뜨린 뒤 엔딩 화면으로 넘어가기까지의 시간(초)
@export var ending_delay: float = 4.0

## true 면 텔레포트 시 화면 전환 없이 즉시 이동 (테스트용)
var instant_travel: bool = false

var _state: State = State.CAMP
var _spawn_timer: float = 0.0
var _kills: int = 0
var _kill_target: int = 0
var _boss: Enemy
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


func _ready() -> void:
	assert(entities_root != null and player != null, "StageManager: entities_root / player 를 지정하세요.")
	assert(not stages.is_empty() and pickup_scene != null and chest_scene != null, "StageManager: stages / pickup_scene / chest_scene 을 지정하세요.")
	assert(camp_room != null and field_room != null and boss_room != null, "StageManager: 방 3개를 지정하세요.")
	GameManager.player_died.connect(_on_player_died)
	field_portal.interacted.connect(enter_field)
	camp_portal.interacted.connect(return_to_camp)
	boss_gate.interacted.connect(enter_boss_room)
	next_stage_portal.interacted.connect(go_to_next_stage)
	_create_hidden_portal()
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
		GameManager.show_notice("STAGE %d 「%s」 — 상인에게서 장비를 갖추고 텔레포트[E]로 사냥터에 가세요" % [GameManager.stage, GameManager.stage_name], Color(0.6, 1.0, 0.7)))


func _process(delta: float) -> void:
	if _state != State.GAME_OVER and not GameManager.is_game_cleared:
		GameManager.play_time += delta


func _physics_process(delta: float) -> void:
	if _state != State.FIELD:
		return
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
	if not GameManager.is_game_cleared or GameManager.is_player_dead:
		return
	_ending_timer.stop()
	_travel(_do_go_to_ending)


func _do_go_to_ending() -> void:
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
		GameManager.show_notice("보스방이 열려 있습니다! 사냥터 북쪽의 문으로 가세요", Color(1.0, 0.6, 0.5))
	else:
		GameManager.show_notice("몬스터 %d마리를 처치하면 보스방이 열립니다" % _kill_target, Color(1.0, 0.9, 0.5))


func _do_return_to_camp() -> void:
	_clear_enemies()
	_arrive_at_camp()
	GameManager.show_notice("야영지로 귀환했습니다", Color(0.6, 1.0, 0.7))


func _do_enter_boss_room() -> void:
	_clear_enemies()
	_release_projectiles()
	player.teleport_to(boss_arrival.global_position, boss_room.get_bounds())
	_state = State.BOSS
	GameManager.set_location(LOCATION_BOSS)
	GameManager.show_notice("무언가 다가온다…", Color(1.0, 0.5, 0.5))
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
	GameManager.show_notice("STAGE %d 「%s」 도착!" % [next_stage, GameManager.stage_name], Color(0.6, 1.0, 0.7))
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
	GameManager.set_stage(stage, data.stage_name)
	for room in [camp_room, field_room, boss_room]:
		(room as Room).apply_theme(data.floor_texture, data.wall_tint)
	_ambient.color = data.ambient_color
	_set_boss_decor(data)
	_hidden_pending = false
	_hidden_active = false
	_hidden_done = false
	if _hidden_portal != null:
		_hidden_portal.enabled = false
	_kills = 0
	_kill_target = data.kill_target
	GameManager.set_kill_progress(_kills, _kill_target)
	boss_gate.seal(_kills, _kill_target)
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


func get_boss_decor() -> Sprite2D:
	return _boss_decor if is_instance_valid(_boss_decor) else null


# ============================================================ 보스
func _spawn_boss() -> void:
	if _state != State.BOSS or _boss != null:
		return
	var data := hidden_stage if _hidden_active else get_stage_data()
	var boss := data.boss_scene.instantiate() as Enemy
	assert(boss != null, "boss_scene 루트에는 Enemy 계열 스크립트가 필요합니다.")
	_boss = boss
	boss.health_changed.connect(_on_boss_health_changed)
	var at := boss_spawn.global_position + data.boss_spawn_offset
	_add_enemy(boss, at, boss_room.get_arena_rect())
	Fx.explosion(player, at, Color(1.0, 0.4, 0.4), 50.0, 3)
	GameManager.report_boss_spawned("%s  · 방어력 %d" % [boss.display_name, boss.defense], boss.max_hp)
	GameManager.show_notice(data.boss_intro_text if data.boss_intro_text != "" else "보스 등장: %s" % boss.display_name, Color(1.0, 0.4, 0.5))


func _on_boss_defeated() -> void:
	_boss = null
	_state = State.CLEARED
	GameManager.report_boss_defeated()
	_release_projectiles()
	GameManager.heal_full()
	_clear_enemies()
	if _hidden_active:
		_on_hidden_boss_defeated()
		return
	_hidden_pending = is_hidden_gate_ready()
	if is_final_stage() and not _hidden_pending:
		_on_final_boss_defeated()
		return
	# 보물상자 + 다음 스테이지 텔레포트 (히든 던전이 열릴 차례면 상자를 연 뒤 고대의 문)
	_spawn_chest(false)
	next_stage_portal.set_prompt(_next_portal_prompt())
	next_stage_portal.enabled = true
	if _hidden_pending:
		GameManager.show_notice("보스 토벌! …고대 용의 비늘들이 떨리기 시작한다. 보물상자를 열어 보세요", Color(1.0, 0.9, 0.6))
	else:
		GameManager.show_notice("보스 토벌! 보물상자를 열고 텔레포트로 다음 스테이지로 가세요", Color(1.0, 0.85, 0.4))


func _spawn_chest(hidden_reward: bool) -> void:
	var chest := chest_scene.instantiate() as Chest
	chest.opened.connect(_on_chest_opened.bind(hidden_reward))
	_chest = chest
	_add_entity(chest, chest_spot.global_position)


func _next_portal_prompt() -> String:
	return "[E] 여정을 마치기 (엔딩)" if is_final_stage() else "[E] STAGE %d 로 이동" % (GameManager.stage + 1)


## 마지막 보스 토벌: 상자/텔레포트 대신 잠시 뒤 엔딩
func _on_final_boss_defeated() -> void:
	next_stage_portal.enabled = false
	GameManager.report_game_cleared()
	Fx.explosion(player, player.global_position, Color(1.0, 0.9, 0.5), 80.0, 3)
	GameManager.show_notice("모든 스테이지 클리어! 세상에 평화가 찾아옵니다…", Color(1.0, 0.9, 0.45))
	_ending_timer.start(maxf(ending_delay, 0.05))


func _on_chest_opened(chest: Chest, hidden_reward: bool = false) -> void:
	var rarity := ItemData.max_rarity_for_stage(GameManager.stage + 1)
	var candidates := ItemDB.get_chest_candidates(rarity)
	var not_owned := candidates.filter(func(it: ItemData) -> bool: return not GameManager.owns_item(it.id))
	var pool: Array = not_owned if not not_owned.is_empty() else candidates
	pool = pool.duplicate()
	pool.shuffle()
	var names := PackedStringArray()
	for i in mini(2 if hidden_reward else 1, pool.size()):
		var item: ItemData = pool[i]
		var drop := pickup_scene.instantiate() as Pickup
		drop.setup_item(item)
		_add_entity(drop, chest.global_position + Vector2(-12.0 * i if hidden_reward else 0.0, 14))
		names.append("[%s] %s" % [item.get_rarity_name(), item.display_name])
	if not names.is_empty():
		GameManager.show_notice(("고대 용의 보물: " if hidden_reward else "보물상자: ") + ", ".join(names), Color(1.0, 0.9, 0.55) if hidden_reward else (pool[0] as ItemData).get_rarity_color())
	var gold := roundi(60.0 * GameManager.stage * float(GameManager.get_difficulty_info()["gold"]) * (3.0 if hidden_reward else 1.0))
	for i in 4:
		var coin := pickup_scene.instantiate() as Pickup
		@warning_ignore("integer_division")
		coin.setup_gold(gold / 4)
		_add_entity(coin, chest.global_position)
	if _hidden_pending and not hidden_reward:
		open_hidden_portal()


func _on_boss_health_changed(current: int, max_hp: int) -> void:
	GameManager.report_boss_hp(current, max_hp)


func _on_player_died() -> void:
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
func _add_enemy(enemy: Enemy, at_global: Vector2, arena: Rect2) -> void:
	enemy.apply_difficulty(GameManager.get_difficulty_info())
	enemy.arena_rect = arena
	enemy.died.connect(_on_enemy_died)
	enemy.summon_requested.connect(_on_summon_requested)
	_add_entity(enemy, at_global)


## 충돌 콜백 도중에도 안전하도록 항상 call_deferred 로 트리에 추가합니다.
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
	_add_enemy(minion, at_global.clamp(arena.position, arena.end), arena)
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


func _release_projectiles() -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool != null:
		pool.release_all()


# ============================================================ 사망 / 드랍
func _on_enemy_died(enemy: Enemy) -> void:
	_spawn_drops(enemy.global_position, enemy)
	GameManager.report_kill()
	if enemy == _boss:
		_on_boss_defeated()
		return
	if _state == State.FIELD and not boss_gate.is_open():
		_kills += 1
		GameManager.set_kill_progress(_kills, _kill_target)
		boss_gate.update_progress(_kills, _kill_target)
		if _kills >= _kill_target:
			boss_gate.open()
			GameManager.show_notice("보스방의 봉인이 풀렸습니다! 사냥터 북쪽의 문으로 가세요", Color(1.0, 0.55, 0.45))


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
	if enemy.is_boss or enemy.item_drop_ids.is_empty() or randf() >= enemy.item_drop_chance:
		return
	var max_rarity := ItemData.max_rarity_for_stage(GameManager.stage)
	var allowed: Array[ItemData] = []
	for item_id in enemy.item_drop_ids:
		var candidate := ItemDB.get_item(item_id)
		if candidate != null and candidate.rarity <= max_rarity:
			allowed.append(candidate)
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
	GameManager.show_notice("여섯 개의 고대 용의 비늘이 공명한다… 「고대의 문」이 열렸다!", Color(1.0, 0.92, 0.6))


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
	GameManager.show_notice("「%s」 — 공기가 무겁다. 무언가 아주 오래된 것이 깨어난다…" % hidden_stage.stage_name, Color(1.0, 0.9, 0.6))
	get_tree().create_timer(boss_entry_delay, false).timeout.connect(_spawn_boss)


func _on_hidden_boss_defeated() -> void:
	_hidden_active = false
	_hidden_done = true
	GameManager.hidden_cleared = true
	_spawn_chest(true)
	next_stage_portal.set_prompt(_next_portal_prompt())
	next_stage_portal.enabled = true
	GameManager.show_notice("고대 드래곤 토벌! 고대 용의 보물상자가 나타났다", Color(1.0, 0.92, 0.6))


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
		GameManager.show_notice("고대 용의 비늘 (%d/%d) — 비늘들이 하나의 이름을 속삭인다… 「아르케」" % [count, total], Color(1.0, 0.92, 0.6))
	else:
		GameManager.show_notice("고대 용의 비늘을 주웠다 (%d/%d) — 아주 오래된 힘이 느껴진다" % [count, total], Color(1.0, 0.9, 0.6))


# ============================================================ 기타
func _rarity_unlocked_at(stage: int) -> String:
	var names := PackedStringArray()
	for rarity in ItemData.RARITY_UNLOCK_STAGE:
		if ItemData.RARITY_UNLOCK_STAGE[rarity] == stage:
			names.append(ItemData.RARITY_NAMES[rarity])
	return ", ".join(names)


func _notice_later(text: String, color: Color, delay: float) -> void:
	get_tree().create_timer(delay, false).timeout.connect(GameManager.show_notice.bind(text, color))
