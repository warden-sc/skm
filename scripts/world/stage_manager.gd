class_name StageManager
extends Node
## 스테이지 진행 / 몬스터 스폰 / 드랍 처리
##
## 흐름:  INTERMISSION(정비, 상점 이용) → WAVE(일반 몹, 목표 처치 수) → BOSS → 클리어 → 다음 스테이지
## 스테이지 구성(몬스터, 보스, 바닥, 처치 목표)은 data/stages/*.tres (StageData) 에 있습니다.
##   1스테이지 「초록 들판」    : 슬라임 · 고블린            / 보스 슬라임 킹
##   2스테이지 「불타는 지옥문」: 헬하운드 · 오크            / 보스 지옥의 수문장
##   3스테이지 「원소의 유적」  : 화염·빙결·뇌전·대지 골렘   / 보스 원소의 거신 아르케온
## 마지막 스테이지를 깬 뒤에는 마지막 스테이지를 반복하며 몬스터가 점점 강해집니다.
##
## Node 상속이므로 자신의 위치 함수는 쓰지 않고,
## 위치는 entities_root(Node2D) 와 player(Player) 의 global_position 만 사용합니다.

enum State { INTERMISSION, WAVE, BOSS, GAME_OVER }

@export var entities_root: Node2D
@export var player: Player
## 스테이지마다 바닥 텍스처 / 벽 색을 바꿀 대상
@export var floor_sprite: Sprite2D
@export var walls: CanvasItem
## 몬스터가 스폰/이동할 수 있는 영역 (월드 좌표)
@export var arena_rect: Rect2 = Rect2(-440, -280, 880, 560)
@export var stages: Array[StageData] = []
@export var pickup_scene: PackedScene

@export_group("Balance")
@export var min_spawn_distance: float = 150.0
@export var intermission_time: float = 8.0
## 무기 드랍이 여러 개 겹치지 않도록 금화 개수 상한
@export var max_coin_pickups_per_kill: int = 4

var _state: State = State.INTERMISSION
var _spawn_timer: float = 0.0
var _intermission_left: float = 0.0
var _last_shown_second: int = -1
var _kills: int = 0
var _kill_target: int = 0
var _boss: Enemy


func _ready() -> void:
	assert(entities_root != null, "StageManager: entities_root 를 지정하세요.")
	assert(player != null, "StageManager: player 를 지정하세요.")
	assert(not stages.is_empty() and pickup_scene != null, "StageManager: stages 와 pickup_scene 을 지정하세요.")
	GameManager.player_died.connect(_on_player_died)
	_apply_stage(GameManager.stage)
	_begin_intermission()


func _physics_process(delta: float) -> void:
	match _state:
		State.INTERMISSION:
			_intermission_left -= delta
			var sec := ceili(maxf(_intermission_left, 0.0))
			if sec != _last_shown_second:
				_last_shown_second = sec
				GameManager.set_intermission(sec)
			if _intermission_left <= 0.0:
				_begin_wave()
		State.WAVE:
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				var data := get_stage_data()
				_spawn_timer = data.spawn_interval * randf_range(0.7, 1.2)
				if get_tree().get_nodes_in_group(&"enemies").size() < data.max_alive:
					_spawn_regular_enemy()
		_:
			pass


func get_state() -> State:
	return _state


## 현재 스테이지의 구성 데이터 (마지막 이후에는 마지막 데이터를 반복)
func get_stage_data(stage: int = -1) -> StageData:
	if stage < 0:
		stage = GameManager.stage
	return stages[clampi(stage - 1, 0, stages.size() - 1)]


## 마지막 스테이지를 몇 바퀴째 반복 중인지 (몬스터 강화 단계)
func get_scaling_level(stage: int = -1) -> int:
	if stage < 0:
		stage = GameManager.stage
	return maxi(stage - stages.size(), 0)


## 지정 스테이지의 정비 시간으로 바로 이동 (디버그 / 테스트 / 이어하기용)
func go_to_stage(stage: int) -> void:
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var leftover := node as Enemy
		if leftover != null and not leftover.is_dead():
			leftover.despawn()
	if _boss != null and is_instance_valid(_boss):
		GameManager.report_boss_defeated()
	_boss = null
	_apply_stage(stage)
	_begin_intermission()


# ============================================================ 단계 전환
func _apply_stage(stage: int) -> void:
	var data := get_stage_data(stage)
	var title := data.stage_name
	if get_scaling_level(stage) > 0:
		title += " +%d" % get_scaling_level(stage)
	GameManager.set_stage(stage, title)
	GameManager.set_kill_progress(0, 0)
	if floor_sprite != null and data.floor_texture != null:
		floor_sprite.texture = data.floor_texture
	if walls != null:
		walls.modulate = data.wall_tint


func _begin_intermission() -> void:
	_state = State.INTERMISSION
	_intermission_left = intermission_time
	_last_shown_second = -1
	GameManager.show_notice("STAGE %d 「%s」 준비!  상인에게 [E] 로 장비를 구매하세요" % [GameManager.stage, GameManager.stage_name], Color(0.6, 1.0, 0.7))


func _begin_wave() -> void:
	_state = State.WAVE
	GameManager.set_intermission(0)
	_kills = 0
	_kill_target = get_stage_data().kill_target
	GameManager.set_kill_progress(_kills, _kill_target)
	_spawn_timer = 0.0
	GameManager.show_notice("STAGE %d 「%s」 시작!" % [GameManager.stage, GameManager.stage_name], Color(1.0, 0.9, 0.5))


func _begin_boss() -> void:
	_state = State.BOSS
	var boss := get_stage_data().boss_scene.instantiate() as Enemy
	assert(boss != null, "boss_scene 루트에는 Enemy 계열 스크립트가 필요합니다.")
	boss.apply_scaling(get_scaling_level())
	_boss = boss
	boss.health_changed.connect(_on_boss_health_changed)
	var pos := arena_rect.get_center() + Vector2(0, -60)
	_add_enemy(boss, pos)
	GameManager.report_boss_spawned(boss.display_name, boss.max_hp)
	GameManager.show_notice("보스 등장: %s" % boss.display_name, Color(1.0, 0.4, 0.5))


func _on_boss_defeated() -> void:
	_boss = null
	GameManager.report_boss_defeated()
	var pool := ProjectilePool.find(get_tree())
	if pool != null:
		pool.release_all(ProjectileSpec.Team.ENEMY)
	GameManager.heal_full()
	# 남은 졸개 정리 (드랍 없이 사라짐)
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var leftover := node as Enemy
		if leftover != null and not leftover.is_dead():
			leftover.despawn()
	GameManager.show_notice("STAGE %d 클리어!  체력이 회복되었습니다" % GameManager.stage, Color(0.6, 1.0, 0.7))
	var next_stage := GameManager.stage + 1
	_apply_stage(next_stage)
	_intermission_left = intermission_time
	_state = State.INTERMISSION
	_last_shown_second = -1
	if next_stage <= stages.size():
		var unlocked := _rarity_unlocked_at(next_stage)
		if unlocked != "":
			_notice_later("상점에 %s 등급 장비가 입고되었습니다!" % unlocked, Color(1.0, 0.85, 0.4))


func _on_player_died() -> void:
	_state = State.GAME_OVER


func _rarity_unlocked_at(stage: int) -> String:
	var names := PackedStringArray()
	for rarity in ItemData.RARITY_UNLOCK_STAGE:
		if ItemData.RARITY_UNLOCK_STAGE[rarity] == stage:
			names.append(ItemData.RARITY_NAMES[rarity])
	return ", ".join(names)


func _notice_later(text: String, color: Color) -> void:
	get_tree().create_timer(3.0, false).timeout.connect(GameManager.show_notice.bind(text, color))


# ============================================================ 스폰
func _spawn_regular_enemy() -> void:
	var scene := get_stage_data().pick_enemy_scene()
	if scene == null:
		return
	var enemy := scene.instantiate() as Enemy
	assert(enemy != null, "적 씬 루트에는 Enemy 계열 스크립트가 필요합니다.")
	enemy.apply_scaling(get_scaling_level())
	_add_enemy(enemy, _pick_spawn_position())


func _add_enemy(enemy: Enemy, at_global: Vector2) -> void:
	enemy.arena_rect = arena_rect
	enemy.died.connect(_on_enemy_died)
	enemy.summon_requested.connect(_on_summon_requested)
	_add_entity(enemy, at_global)


## 충돌 콜백 도중에도 안전하도록 항상 call_deferred 로 트리에 추가합니다.
func _add_entity(node: Node2D, at_global: Vector2) -> void:
	node.position = entities_root.to_local(at_global)
	entities_root.add_child.call_deferred(node)


func _pick_spawn_position() -> Vector2:
	var best := arena_rect.get_center()
	for i in 12:
		var candidate := Vector2(
			randf_range(arena_rect.position.x + 16.0, arena_rect.end.x - 16.0),
			randf_range(arena_rect.position.y + 16.0, arena_rect.end.y - 16.0))
		best = candidate
		if candidate.distance_to(player.global_position) >= min_spawn_distance:
			break
	return best


func _on_summon_requested(scene: PackedScene, at_global: Vector2) -> void:
	if scene == null or _state == State.GAME_OVER:
		return
	var minion := scene.instantiate() as Enemy
	if minion == null:
		return
	minion.apply_scaling(get_scaling_level())
	# 소환된 졸개는 드랍이 적습니다
	minion.item_drop_chance *= 0.3
	_add_enemy(minion, at_global.clamp(arena_rect.position, arena_rect.end))


# ============================================================ 사망 / 드랍
func _on_enemy_died(enemy: Enemy) -> void:
	_spawn_drops(enemy.global_position, enemy)

	if enemy == _boss:
		_on_boss_defeated()
		return

	if _state == State.WAVE:
		_kills += 1
		GameManager.set_kill_progress(_kills, _kill_target)
		if _kills >= _kill_target:
			_begin_boss()


func _on_boss_health_changed(current: int, max_hp: int) -> void:
	GameManager.report_boss_hp(current, max_hp)


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

	# 2) 장비(무기/방패/투구): 확률 드랍
	if not enemy.item_drop_ids.is_empty() and randf() < enemy.item_drop_chance:
		var item_id: StringName = enemy.item_drop_ids.pick_random()
		var item := ItemDB.get_item(item_id)
		if item != null:
			var drop := pickup_scene.instantiate() as Pickup
			drop.setup_item(item)
			_add_entity(drop, at_global)
