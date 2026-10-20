extends Control
## 타이틀 화면 — 배경: 전사와 몬스터의 전투 일러스트 + 불티
## 0) 처음 켰을 때(Profile 에 이름이 없을 때): 용사의 이름 짓기 → 처음 하는 유저면 튜토리얼 한 번 → 다시 타이틀
## 1) 메뉴: 싱글플레이 / 멀티플레이(준비 중) / 튜토리얼 다시 하기 / 이름 바꾸기 / 게임 종료
## 2) 싱글플레이: 이어하기(저장 파일이 있을 때) / 새 게임
## 3) 새 게임 → 난이도 선택 (노멀 / 하드 / 베리하드) → 조작 키 · 진행 방법 안내 → 「모험 시작」 → 메인 씬

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
	["C", "고대 용의 피 마시기 (히든 보스 보상 — 체력 전부 + 재생 · 상태 이상 해제)"],
	["Z / X", "신화 사용 아이템 — 원초의 불꽃 (50스테이지) / 최후의 나팔 (100스테이지)"],
	["ESC", "창 닫기 · 게임 도중엔 일시정지 / 저장 / 설정"],
	["R / T", "쓰러졌을 때 다시 시작 / 타이틀로"],
]
const FLOW_TEXT := "진행: 야영지 상인에게서 장비 구매·판매 → 텔레포트로 사냥터 → 몬스터를 처치해 보스방 봉인 해제 → 보스 토벌 → 보물상자(골드 + 확률로 장비) · 10스테이지마다 신화 장비 → 다음 스테이지 … 100스테이지 보스(신화 봉인 해제) → 최종장까지 쓰러뜨리면 엔딩"

@onready var _title_label: Label = %TitleLabel
@onready var _difficulty_panel: Control = %DifficultyPanel
@onready var _difficulty_desc: Label = %DifficultyDesc
@onready var _help_panel: Control = %HelpPanel
@onready var _help_title: Label = %HelpTitle
@onready var _key_grid: GridContainer = %KeyGrid
@onready var _flow_label: Label = %FlowLabel
@onready var _start_button: Button = %StartButton
@onready var _hero_name_edit: LineEdit = %HeroNameEdit
@onready var _name_panel: Control = %NamePanel
@onready var _menu_panel: Control = %MenuPanel
@onready var _single_panel: Control = %SinglePanel
@onready var _menu_note: Label = %MenuNote
@onready var _continue_button: Button = %ContinueButton
@onready var _save_info: Label = %SaveInfo

const MULTI_NOTE := "멀티플레이(협동 · 최대 4명 · 방장이 방을 만들고 IP 로 접속)는 다음 업데이트에서 열립니다"

## false 면 씬을 바꾸지 않고 last_scene_request 에만 남김 (자동 테스트용)
var scene_changes: bool = true
var last_scene_request: String = ""
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
	(%NameConfirmButton as Button).pressed.connect(confirm_name)
	_hero_name_edit.text_submitted.connect(func(_t: String) -> void: confirm_name())
	(%SingleButton as Button).pressed.connect(open_single)
	(%MultiButton as Button).pressed.connect(func() -> void: _menu_note.text = MULTI_NOTE)
	(%TutorialButton as Button).pressed.connect(start_tutorial)
	(%RenameButton as Button).pressed.connect(open_name)
	(%QuitButton as Button).pressed.connect(func() -> void: get_tree().quit())
	(%QuitButton as Button).visible = not OS.has_feature("web")
	_continue_button.pressed.connect(continue_game)
	(%NewGameButton as Button).pressed.connect(open_difficulty)
	(%SingleBackButton as Button).pressed.connect(open_menu)
	(%DifficultyBackButton as Button).pressed.connect(open_single)
	_build_help()
	_add_embers()
	_show_description(GameManager.Difficulty.NORMAL)
	GameManager.tutorial_mode = false
	if Profile.has_hero_name():
		open_menu()
	else:
		open_name()


func _process(delta: float) -> void:
	_time += delta
	_title_label.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.85, 0.6), (sin(_time * 2.0) + 1.0) * 0.25)


## 난이도 선택 → 조작 안내 표시
func select_difficulty(difficulty: GameManager.Difficulty) -> void:
	_selected = difficulty
	var info: Dictionary = GameManager.DIFFICULTY_INFO[difficulty]
	_help_title.text = "조작 안내 — 난이도: %s" % info["name"]
	_help_title.add_theme_color_override(&"font_color", info["color"])
	_show_only(_help_panel)
	_start_button.grab_focus()


func start_game() -> void:
	GameManager.start_new_game(_selected)
	GameManager.tutorial_mode = false
	_go(MAIN_SCENE)


## 입력한 용사의 이름 (비워 두면 「용사」)
func get_hero_name() -> String:
	return _hero_name_edit.text


## 지금 보이는 화면: "name" · "menu" · "single" · "difficulty" · "help"
func get_screen() -> String:
	for pair in [["name", _name_panel], ["menu", _menu_panel], ["single", _single_panel], ["difficulty", _difficulty_panel], ["help", _help_panel]]:
		if (pair[1] as Control).visible:
			return pair[0]
	return ""


func _show_only(panel: Control) -> void:
	for p in [_name_panel, _menu_panel, _single_panel, _difficulty_panel, _help_panel]:
		(p as Control).visible = p == panel


func open_name() -> void:
	_hero_name_edit.text = Profile.hero_name
	_show_only(_name_panel)
	_hero_name_edit.grab_focus()


## 이름 결정 → 처음이면 튜토리얼, 아니면 메뉴
func confirm_name() -> void:
	if not _name_panel.visible:
		return
	Profile.set_hero_name(get_hero_name())
	if Profile.tutorial_done:
		open_menu()
	else:
		start_tutorial()


func open_menu() -> void:
	(%HeroLabel as Label).text = "용사 「%s」" % GameManager.hero_name
	_menu_note.text = ""
	_show_only(_menu_panel)
	(%SingleButton as Button).grab_focus()


func open_single() -> void:
	var summary := Profile.get_save_summary()
	_continue_button.disabled = summary == ""
	_save_info.text = ("저장: " + summary) if summary != "" else "저장된 모험이 없습니다"
	_show_only(_single_panel)
	(_continue_button if summary != "" else %NewGameButton as Button).grab_focus()


func open_difficulty() -> void:
	_show_only(_difficulty_panel)
	(%NormalButton as Button).grab_focus()


## 튜토리얼: 노멀 1스테이지 야영지에서 안내를 따라 해 보고, 끝나면 타이틀로
func start_tutorial() -> void:
	GameManager.start_new_game(GameManager.Difficulty.NORMAL)
	GameManager.tutorial_mode = true
	_go(MAIN_SCENE)


## 저장한 모험 이어하기 (그 스테이지 야영지부터)
func continue_game() -> bool:
	if not Profile.load_game():
		_save_info.text = "저장 파일을 읽을 수 없습니다"
		return false
	_go(MAIN_SCENE)
	return true


func _go(path: String) -> void:
	last_scene_request = path
	if scene_changes:
		get_tree().change_scene_to_file(path)


func get_selected_difficulty() -> GameManager.Difficulty:
	return _selected


func _back_to_difficulty() -> void:
	open_difficulty()


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
