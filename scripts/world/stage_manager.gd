class_name StageManager
extends Node
## 스테이지 진행 / 몬스터 스폰 / 드랍 처리
##
## 흐름:  INTERMISSION(정비, 상점 이용) → WAVE(일반 몹, 목표 처치 수) → BOSS → 클리어 → 다음 스테이지
##
## Node 상속이므로 자신의 위치 함수는 쓰지 않고,
## 위치는 entities_root(Node2D) 와 player(Player) 의 global_position 만 사용합니다.

enum State { INTERMISSION, WAVE, BOSS, GAME_OVER }

@export var entities_root: Node2D
@export var player: Player
## 몬스터가 스폰/이동할 수 있는 영역 (월드 좌표)
@export var arena_rect: Rect2 = Rect2(-440, -280, 880, 560)

@export_group("Scenes")
@export var slime_scene: PackedScene
@export var goblin_scene: PackedScene
@export var boss_scene: PackedScene
@export var pickup_scene: PackedScene

@export_group("Balance")
@export var base_kill_target: int = 12
@export var kill_target_per_stage: int = 6
@export var spawn_interval: float = 1.3
@export var max_alive: int = 10
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
	assert(slime_scene != null and goblin_scene != null and boss_scene != null and pickup_scene != null, "StageManager: 씬을 모두 지정하세요.")
	GameManager.player_died.connect(_on_player_died)
	_begin_intermission()
	GameManager.show_notice("스테이지 %d 준비!  상인에게 [E] 로 무기를 구매하세요" % GameManager.stage, Color(0.6, 1.0, 0.7))


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
				_spawn_timer = spawn_interval * randf_range(0.7, 1.2)
				if get_tree().get_nodes_in_group(&"enemies").size() < max_alive:
					_spawn_regular_enemy()
		_:
			pass


func get_state() -> State:
	return _state


# ============================================================ 단계 전환
func _begin_intermission() -> void:
	_state = State.INTERMISSION
	_intermission_left = intermission_time
	_last_shown_second = -1


func _begin_wave() -> void:
	_state = State.WAVE
	GameManager.set_intermission(0)
	_kills = 0
	_kill_target = base_kill_target + kill_target_per_stage * (GameManager.stage - 1)
	GameManager.set_kill_progress(_kills, _kill_target)
	_spawn_timer = 0.0
	GameManager.show_notice("스테이지 %d 시작!" % GameManager.stage, Color(1.0, 0.9, 0.5))


func _begin_boss() -> void:
	_state = State.BOSS
	var boss := boss_scene.instantiate() as Enemy
	assert(boss != null, "boss_scene 루트에는 Enemy 계열 스크립트가 필요합니다.")
	boss.apply_stage_scaling(GameManager.stage)
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
	GameManager.show_notice("스테이지 %d 클리어!  체력이 회복되었습니다" % GameManager.stage, Color(0.6, 1.0, 0.7))
	GameManager.set_stage(GameManager.stage + 1)
	GameManager.set_kill_progress(0, 0)
	_begin_intermission()


func _on_player_died() -> void:
	_state = State.GAME_OVER


# ============================================================ 스폰
func _spawn_regular_enemy() -> void:
	# 스테이지가 오를수록 고블린 비율 증가
	var goblin_chance := clampf(0.25 + 0.1 * (GameManager.stage - 1), 0.25, 0.6)
	var scene := goblin_scene if randf() < goblin_chance else slime_scene
	var enemy := scene.instantiate() as Enemy
	assert(enemy != null, "적 씬 루트에는 Enemy 계열 스크립트가 필요합니다.")
	enemy.apply_stage_scaling(GameManager.stage)
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
	minion.apply_stage_scaling(GameManager.stage)
	# 소환된 졸개는 드랍이 적습니다
	minion.item_drop_chance *= 0.3
	_add_enemy(minion, at_global)


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

	# 2) 장비(무기/방패): 확률 드랍
	if not enemy.item_drop_ids.is_empty() and randf() < enemy.item_drop_chance:
		var item_id: StringName = enemy.item_drop_ids.pick_random()
		var item := ItemDB.get_item(item_id)
		if item != null:
			var drop := pickup_scene.instantiate() as Pickup
			drop.setup_item(item)
			_add_entity(drop, at_global)
