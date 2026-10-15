class_name StageData
extends Resource
## 스테이지 1개의 구성 (data/stages/*.tres).
## StageManager 가 순서대로 사용합니다. 마지막 스테이지의 보스를 쓰러뜨리면 엔딩입니다.

@export var stage_name: String = "스테이지"
@export var floor_texture: Texture2D
@export var wall_tint: Color = Color.WHITE
## 화면 전체 밝기/색조 (CanvasModulate). 어두운 스테이지는 낮게
@export var ambient_color: Color = Color.WHITE

@export_group("Boss Room")
## 보스방 장식 (예: 5스테이지 빈 옥좌). 보스 등장 지점 뒤에 놓임
@export var boss_decor_texture: Texture2D
@export var boss_decor_offset: Vector2 = Vector2.ZERO
## 보스가 실제로 나타나는 위치 (보스 등장 지점 기준)
@export var boss_spawn_offset: Vector2 = Vector2.ZERO
## 보스 등장 문구 (비워두면 "보스 등장: 이름")
@export var boss_intro_text: String = ""

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
