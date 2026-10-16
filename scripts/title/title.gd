extends Control
## 타이틀 화면
## 1) 난이도 선택 (노멀 / 하드 / 베리하드) — 배경: 전사와 몬스터의 전투 일러스트 + 불티
## 2) 선택하면 조작 키 / 진행 방법 안내
## 3) 「모험 시작」 → GameManager.start_new_game(난이도) → 메인 씬

const MAIN_SCENE := "res://scenes/main/main.tscn"

const CONTROLS := [
	["WASD / 방향키", "이동"],
	["마우스", "조준"],
	["좌클릭 (누르고 있기)", "공격 — 검: 강한 베기 · 활: 빠른 연사 + 방깍 · 지팡이: 영창 후 범위 폭발"],
	["우클릭 / F (누르고 있기)", "방패 가드 — 방패가 금빛일 때 맞으면 퍼펙트 가드 (탄 반사 + 기절)"],
	["Space / Shift", "대시 (무적)"],
	["1 / 2 / 3 · Q / 휠", "무기 칸 전환 (검 · 활 · 지팡이)"],
	["H", "회복 포션 사용 (잃은 체력에 맞는 포션 자동 선택)"],
	["E", "상호작용 — 상인 · 텔레포트 · 보스문 · 보물상자"],
	["I / Tab", "인벤토리 — 장비 · 장신구(팔찌·반지·펜던트) 장착 / 해제"],
	["ESC", "창 닫기"],
	["R / T", "쓰러졌을 때 다시 시작 / 타이틀로"],
]
const FLOW_TEXT := "진행: 야영지 상인에게서 장비 구매·판매 → 텔레포트로 사냥터 → 몬스터를 처치해 보스방 봉인 해제 → 보스 토벌 → 보물상자(다음 등급 장비) → 다음 스테이지 … 10스테이지 보스를 쓰러뜨리면 엔딩"

@onready var _title_label: Label = %TitleLabel
@onready var _difficulty_panel: Control = %DifficultyPanel
@onready var _difficulty_desc: Label = %DifficultyDesc
@onready var _help_panel: Control = %HelpPanel
@onready var _help_title: Label = %HelpTitle
@onready var _key_grid: GridContainer = %KeyGrid
@onready var _flow_label: Label = %FlowLabel
@onready var _start_button: Button = %StartButton

var _selected: GameManager.Difficulty = GameManager.Difficulty.NORMAL
var _time: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	var buttons := {
		GameManager.Difficulty.NORMAL: %NormalButton as Button,
		GameManager.Difficulty.HARD: %HardButton as Button,
		GameManager.Difficulty.VERY_HARD: %VeryHardButton as Button,
	}
	for difficulty in buttons:
		var button: Button = buttons[difficulty]
		var info: Dictionary = GameManager.DIFFICULTY_INFO[difficulty]
		button.text = info["name"]
		button.add_theme_color_override(&"font_color", info["color"])
		button.add_theme_color_override(&"font_hover_color", (info["color"] as Color).lightened(0.4))
		button.pressed.connect(select_difficulty.bind(difficulty))
		button.mouse_entered.connect(_show_description.bind(difficulty))
		button.focus_entered.connect(_show_description.bind(difficulty))
	(%BackButton as Button).pressed.connect(_back_to_difficulty)
	_start_button.pressed.connect(start_game)
	_build_help()
	_add_embers()
	(%NormalButton as Button).grab_focus()
	_show_description(GameManager.Difficulty.NORMAL)


func _process(delta: float) -> void:
	_time += delta
	_title_label.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.85, 0.6), (sin(_time * 2.0) + 1.0) * 0.25)


## 난이도 선택 → 조작 안내 표시
func select_difficulty(difficulty: GameManager.Difficulty) -> void:
	_selected = difficulty
	var info: Dictionary = GameManager.DIFFICULTY_INFO[difficulty]
	_help_title.text = "조작 안내 — 난이도: %s" % info["name"]
	_help_title.add_theme_color_override(&"font_color", info["color"])
	_difficulty_panel.hide()
	_help_panel.show()
	_start_button.grab_focus()


func start_game() -> void:
	GameManager.start_new_game(_selected)
	get_tree().change_scene_to_file(MAIN_SCENE)


func get_selected_difficulty() -> GameManager.Difficulty:
	return _selected


func _back_to_difficulty() -> void:
	_help_panel.hide()
	_difficulty_panel.show()
	(%NormalButton as Button).grab_focus()


func _show_description(difficulty: GameManager.Difficulty) -> void:
	_difficulty_desc.text = GameManager.DIFFICULTY_INFO[difficulty]["desc"]


func _build_help() -> void:
	for pair in CONTROLS:
		var key := Label.new()
		key.text = pair[0]
		key.add_theme_font_size_override(&"font_size", 9)
		key.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.45))
		_key_grid.add_child(key)
		var action := Label.new()
		action.text = pair[1]
		action.add_theme_font_size_override(&"font_size", 9)
		_key_grid.add_child(action)
	_flow_label.text = FLOW_TEXT


## 화면 아래에서 피어오르는 불티
func _add_embers() -> void:
	var embers := Fx.make_aura(Color(1.0, 0.55, 0.2), 40, 4.0, Vector2(0, -25), 4.0)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(330, 6)
	embers.initial_velocity_min = 10.0
	embers.initial_velocity_max = 30.0
	embers.scale_amount_min = 0.6
	embers.scale_amount_max = 1.4
	embers.position = Vector2(320, 368)
	add_child(embers)
	move_child(embers, 2)
	embers.emitting = true
