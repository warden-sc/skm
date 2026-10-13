class_name Layers
## 물리 레이어 비트값 모음 (project.godot 의 layer_names 와 1:1 대응).
## 숫자를 씬/스크립트에 흩뿌리지 않고 여기서만 관리합니다.

const WORLD := 1               # layer 1: 벽, 장애물
const PLAYER := 2              # layer 2: 플레이어 몸체 (CharacterBody2D)
const ENEMY := 4               # layer 3: 적 (Area2D)
const PLAYER_PROJECTILE := 8   # layer 4: 플레이어 투사체
const ENEMY_PROJECTILE := 16   # layer 5: 적 투사체
const PICKUP := 32             # layer 6: 드랍 아이템
