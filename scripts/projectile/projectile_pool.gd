class_name ProjectilePool
extends Node
## 투사체 오브젝트 풀.
##
## 시작할 때 initial_size 개의 Projectile 을 미리 만들어 두고,
## spawn() 으로 꺼내 쓰고, Projectile 이 finished 시그널을 보내면 다시 대기열로 돌려받습니다.
## (instantiate / queue_free 를 반복하지 않으므로 탄막이 많아도 GC/할당 스파이크가 없습니다.)
##
## Node 를 상속하지만 위치 관련 함수는 전혀 쓰지 않습니다. 위치는 ProjectileSpec.origin 으로 전달.

const GROUP: StringName = &"projectile_pool"

@export var projectile_scene: PackedScene
@export var initial_size: int = 96
## 풀이 바닥났을 때 새로 만들지 여부
@export var can_grow: bool = true
@export var max_size: int = 400

var _available: Array[Projectile] = []
var _total_count: int = 0


static func find(tree: SceneTree) -> ProjectilePool:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as ProjectilePool


func _enter_tree() -> void:
	# _ready 보다 먼저 그룹에 등록해서, 형제 노드의 _ready 에서도 찾을 수 있게 합니다.
	add_to_group(GROUP)


func _ready() -> void:
	assert(projectile_scene != null, "ProjectilePool: projectile_scene 을 지정하세요.")
	for i in initial_size:
		_available.append(_create_projectile())


## 명세대로 투사체 1개를 발사. 풀이 가득 차서 못 꺼내면 null.
func spawn(spec: ProjectileSpec) -> Projectile:
	var projectile: Projectile
	if _available.is_empty():
		if not can_grow or _total_count >= max_size:
			return null
		projectile = _create_projectile()
	else:
		projectile = _available.pop_back()
	projectile.activate(spec)
	return projectile


## 특정 팀(또는 전부)의 활성 투사체를 즉시 회수 (스테이지 클리어 등)
func release_all(team: int = -1) -> void:
	for child in get_children():
		var projectile := child as Projectile
		if projectile != null and projectile.is_active and (team < 0 or projectile.get_team() == team):
			projectile.release()


func get_available_count() -> int:
	return _available.size()


func get_total_count() -> int:
	return _total_count


func _create_projectile() -> Projectile:
	var projectile := projectile_scene.instantiate() as Projectile
	assert(projectile != null, "ProjectilePool: projectile_scene 의 루트에 projectile.gd 가 붙어 있어야 합니다.")
	add_child(projectile)
	projectile.finished.connect(_on_projectile_finished)
	_total_count += 1
	return projectile


func _on_projectile_finished(projectile: Projectile) -> void:
	if not _available.has(projectile):
		_available.append(projectile)
