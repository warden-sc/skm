class_name StageData
extends Resource
## 스테이지 1개의 구성 (data/stages/*.tres).
## StageManager 가 순서대로 사용하고, 마지막 스테이지 이후에는 마지막 데이터를 반복하면서 몬스터를 강화합니다.

@export var stage_name: String = "스테이지"
@export var floor_texture: Texture2D
@export var wall_tint: Color = Color.WHITE

@export_group("Enemies")
@export var enemy_scenes: Array[PackedScene] = []
## enemy_scenes 와 같은 순서의 출현 가중치
@export var enemy_weights: Array[float] = []
@export var boss_scene: PackedScene
@export var kill_target: int = 12
@export var spawn_interval: float = 1.3
@export var max_alive: int = 10


func pick_enemy_scene() -> PackedScene:
	if enemy_scenes.is_empty():
		return null
	var total := 0.0
	for i in enemy_scenes.size():
		total += _weight(i)
	var roll := randf() * total
	for i in enemy_scenes.size():
		roll -= _weight(i)
		if roll <= 0.0:
			return enemy_scenes[i]
	return enemy_scenes[enemy_scenes.size() - 1]


func _weight(index: int) -> float:
	return enemy_weights[index] if index < enemy_weights.size() else 1.0
