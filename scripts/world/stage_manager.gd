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


func _ready() -> void:
	assert(entities_root != null and player != null, "StageManager: entities_root / player 를 지정하세요.")
	assert(not stages.is_empty() and pickup_scene != null and chest_scene != null, "StageManager: stages / pickup_scene / chest_scene 을 지정하세요.")
	assert(camp_room != null and field_room != null and boss_room != null, "StageManager: 방 3개를 지정하세요.")
	GameManager.player_died.connect(_on_player_died)
	field_portal.interacted.connect(enter_field)
	camp_portal.interacted.connect(return_to_camp)
	boss_gate.interacted.connect(enter_boss_room)
	next_stage_portal.interacted.connect(go_to_next_stage)
	_ending_timer = Timer.new()
	_ending_timer.one_shot = true
	_ending_timer.timeout.connect(go_to_ending)
	add_child(_ending_timer)
	_ambient = CanvasModulate.new()
	_ambient.name = "Ambient"
	add_child(_ambient)
	_setup_stage(GameManager.stage)
	_arrive_at_camp()
	_notice_later("STAGE %d 「%s」 — 상인에게서 장비를 갖추고 텔레포트[E]로 사냥터에 가세요" % [GameManager.stage, GameManager.stage_name], Color(0.6, 1.0, 0.7), 0.3)


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


## 보스방 → 다음 스테이지 야영지 (보스 토벌 후, 마지막 스테이지가 아닐 때)
func go_to_next_stage() -> void:
	if _state == State.CLEARED and not is_final_stage():
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
	var boss := get_stage_data().boss_scene.instantiate() as Enemy
	assert(boss != null, "boss_scene 루트에는 Enemy 계열 스크립트가 필요합니다.")
	_boss = boss
	boss.health_changed.connect(_on_boss_health_changed)
	var data := get_stage_data()
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
	if is_final_stage():
		_on_final_boss_defeated()
		return
	# 보물상자 + 다음 스테이지 텔레포트
	var chest := chest_scene.instantiate() as Chest
	chest.opened.connect(_on_chest_opened)
	_chest = chest
	_add_entity(chest, chest_spot.global_position)
	next_stage_portal.set_prompt("[E] STAGE %d 로 이동" % (GameManager.stage + 1))
	next_stage_portal.enabled = true
	GameManager.show_notice("보스 토벌! 보물상자를 열고 텔레포트로 다음 스테이지로 가세요", Color(1.0, 0.85, 0.4))


## 마지막 보스 토벌: 상자/텔레포트 대신 잠시 뒤 엔딩
func _on_final_boss_defeated() -> void:
	next_stage_portal.enabled = false
	GameManager.report_game_cleared()
	Fx.explosion(player, player.global_position, Color(1.0, 0.9, 0.5), 80.0, 3)
	GameManager.show_notice("모든 스테이지 클리어! 세상에 평화가 찾아옵니다…", Color(1.0, 0.9, 0.45))
	_ending_timer.start(maxf(ending_delay, 0.05))


func _on_chest_opened(chest: Chest) -> void:
	var rarity := ItemData.max_rarity_for_stage(GameManager.stage + 1)
	var candidates := ItemDB.get_chest_candidates(rarity)
	var not_owned := candidates.filter(func(it: ItemData) -> bool: return not GameManager.owns_item(it.id))
	var pool: Array = not_owned if not not_owned.is_empty() else candidates
	if not pool.is_empty():
		var item: ItemData = pool.pick_random()
		var drop := pickup_scene.instantiate() as Pickup
		drop.setup_item(item)
		_add_entity(drop, chest.global_position + Vector2(0, 14))
		GameManager.show_notice("보물상자: [%s] %s" % [item.get_rarity_name(), item.display_name], item.get_rarity_color())
	var gold := roundi(60.0 * GameManager.stage * float(GameManager.get_difficulty_info()["gold"]))
	for i in 4:
		var coin := pickup_scene.instantiate() as Pickup
		@warning_ignore("integer_division")
		coin.setup_gold(gold / 4)
		_add_entity(coin, chest.global_position)


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
	for group in [&"ground_zones", &"sky_strikes", &"cover_rocks", &"puppet_switches", &"storm_fields", &"ice_pillars", &"abyss_torches"]:
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


# ============================================================ 기타
func _rarity_unlocked_at(stage: int) -> String:
	var names := PackedStringArray()
	for rarity in ItemData.RARITY_UNLOCK_STAGE:
		if ItemData.RARITY_UNLOCK_STAGE[rarity] == stage:
			names.append(ItemData.RARITY_NAMES[rarity])
	return ", ".join(names)


func _notice_later(text: String, color: Color, delay: float) -> void:
	get_tree().create_timer(delay, false).timeout.connect(GameManager.show_notice.bind(text, color))
