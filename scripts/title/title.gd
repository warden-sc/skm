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
	["우클릭 (누르고 있기)", "방패 가드 — 방패가 금빛일 때 맞으면 퍼펙트 가드 (탄 반사 + 기절)"],
	["Shift", "대시 (무적)"],
	["1 / 2 / 3", "무기 칸 전환 (검 · 활 · 지팡이)"],
	["Q", "액티브 스킬 (레어 등급 이상 무기) — 검: 회전 베기 · 단검: 그림자 난무 · 활: 화살비 · 지팡이: 대폭발"],
	["H", "회복 포션 사용 (기본: 잃은 체력에 맞는 포션 자동 선택)"],
	["G", "마실 포션 바꾸기 — 자동 → 작은 · 회복 · 고급 · 엘릭서 중 하나로 고정 → 자동"],
	["E", "상호작용 — 상인 · 텔레포트 · 보스문 · 보물상자"],
	["Tab", "인벤토리 — 장비 · 장신구(팔찌·반지·펜던트) 장착 / 해제"],
	["C", "고대 용의 피 마시기 (히든 보스 보상 — 체력 전부 + 재생 · 상태 이상 해제)"],
	["Z / X", "신화 사용 아이템 — 원초의 불꽃 (50스테이지) / 최후의 나팔 (100스테이지)"],
	["Enter", "대화 넘기기 (대화창 오른쪽 위 [스킵] 버튼으로 건너뛰기)"],
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

## 멀티플레이 창 (코드로 만듦): 방 만들기 / IP 로 참가 → 대기실 (방장이 난이도 고르고 시작)
var _multi_panel: PanelContainer
var _multi_connect: VBoxContainer
var _multi_lobby: VBoxContainer
var _ip_edit: LineEdit
var _multi_status: Label
var _lobby_list: Label
var _lobby_info: Label
var _lobby_difficulty: Button
var _lobby_start: Button
var _lobby_code: Label
var _copy_button: Button
var _internet_button: Button
var _internet_code: String = ""
var _room_list: VBoxContainer
var _finder: RoomFinder
var _http: HTTPRequest

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
	# 한글 입력기(IME): LineEdit 에 max_length 를 두면 조합 중인 글자와 부딪혀 한 글자만 들어가는 경우가 있어
	# 입력 칸에는 제한을 두지 않고, 결정할 때 GameManager.HERO_NAME_MAX(12자)로 자름
	_add_hangul_button()
	_add_version_label()
	(%SingleButton as Button).pressed.connect(open_single)
	(%MultiButton as Button).text = "멀티플레이 (협동 · 최대 4명)"
	(%MultiButton as Button).pressed.connect(open_multi)
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
	_build_multi_panel()
	Net.lobby_changed.connect(_refresh_lobby)
	Net.join_failed.connect(_on_join_failed)
	if Net.in_game:
		Net.leave()  # 게임을 마치고(엔딩 · 나가기) 돌아오면 방을 닫음
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
	for pair in [["name", _name_panel], ["menu", _menu_panel], ["single", _single_panel], ["difficulty", _difficulty_panel], ["help", _help_panel], ["multi", _multi_panel]]:
		if (pair[1] as Control).visible:
			return pair[0]
	return ""


func _show_only(panel: Control) -> void:
	for p in [_name_panel, _menu_panel, _single_panel, _difficulty_panel, _help_panel, _multi_panel]:
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


# ============================================================ 멀티플레이
func _build_multi_panel() -> void:
	_multi_panel = PanelContainer.new()
	_multi_panel.name = "MultiPanel"
	_multi_panel.add_theme_stylebox_override(&"panel", _menu_panel.get_theme_stylebox(&"panel"))
	_multi_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_multi_panel.offset_left = -160.0
	_multi_panel.offset_right = 160.0
	_multi_panel.offset_top = -8.0  # 내용만큼 위로 자람
	_multi_panel.offset_bottom = -8.0
	_multi_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_multi_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_multi_panel.visible = false
	add_child(_multi_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	_multi_panel.add_child(box)
	box.add_child(_make_label("멀티플레이 — 협동 (최대 4명)", 12, Color(1.0, 0.86, 0.45)))

	# ---- 접속 전: 방 만들기 · 초대 코드로 참가 · 공개 방 목록
	_multi_connect = VBoxContainer.new()
	_multi_connect.add_theme_constant_override(&"separation", 4)
	box.add_child(_multi_connect)
	var host_row := HBoxContainer.new()
	host_row.name = "HostRow"
	host_row.add_theme_constant_override(&"separation", 4)
	var public_button := _make_button("공개 방 만들기", func() -> void: host_room(true))
	public_button.tooltip_text = "같은 네트워크(와이파이)의 공개 방 목록에 보이고, 초대 코드로도 들어올 수 있음"
	public_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var private_button := _make_button("비공개 방 만들기", func() -> void: host_room(false))
	private_button.tooltip_text = "초대 코드를 아는 사람만 들어올 수 있음"
	private_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_row.add_child(public_button)
	host_row.add_child(private_button)
	_multi_connect.add_child(host_row)
	var row := HBoxContainer.new()
	row.name = "JoinRow"
	row.add_theme_constant_override(&"separation", 4)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "초대 코드 (예: 6R4K-02M8-1ZQ7P)"
	_ip_edit.add_theme_font_size_override(&"font_size", 10)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text_submitted.connect(func(_t: String) -> void: join_room(_ip_edit.text))
	row.add_child(_ip_edit)
	row.add_child(_make_button("참가", func() -> void: join_room(_ip_edit.text)))
	_multi_connect.add_child(row)
	_multi_connect.add_child(_make_label("같은 네트워크의 공개 방", 9, Color(1.0, 0.86, 0.45)))
	_room_list = VBoxContainer.new()
	_room_list.add_theme_constant_override(&"separation", 2)
	_multi_connect.add_child(_room_list)
	_multi_connect.add_child(_make_button("← 뒤로", open_menu))

	# ---- 대기실
	_multi_lobby = VBoxContainer.new()
	_multi_lobby.add_theme_constant_override(&"separation", 4)
	box.add_child(_multi_lobby)
	_lobby_code = _make_label("", 13, Color(1.0, 0.95, 0.6))
	_multi_lobby.add_child(_lobby_code)
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override(&"separation", 4)
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_copy_button = _make_button("코드 복사", copy_invite_code)
	code_row.add_child(_copy_button)
	_internet_button = _make_button("인터넷용 코드", make_internet_code)
	_internet_button.tooltip_text = "다른 동네 친구용: 방장의 공인 IP 로 코드를 만듦 (공유기 포트 포워딩 필요)"
	code_row.add_child(_internet_button)
	_multi_lobby.add_child(code_row)
	_lobby_info = _make_label("", 8, Color(0.75, 0.9, 1.0))
	_multi_lobby.add_child(_lobby_info)
	_lobby_list = _make_label("", 10, Color(1, 1, 1))
	_multi_lobby.add_child(_lobby_list)
	_lobby_difficulty = _make_button("", _cycle_lobby_difficulty)
	_multi_lobby.add_child(_lobby_difficulty)
	_lobby_start = _make_button("게임 시작 ▶", func() -> void: Net.start_game())
	_multi_lobby.add_child(_lobby_start)
	_multi_lobby.add_child(_make_button("방 나가기", leave_room))

	_multi_status = _make_label("", 8, Color(1.0, 0.75, 0.5))
	box.add_child(_multi_status)

	_finder = RoomFinder.new()
	_finder.name = "RoomFinder"
	add_child(_finder)
	_finder.rooms_changed.connect(_refresh_room_list)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	return label


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 10)
	button.pressed.connect(callback)
	return button


func open_multi() -> void:
	_multi_status.text = ""
	_show_only(_multi_panel)
	_refresh_lobby()
	if OS.has_feature("web"):
		# 브라우저에서는 이 방식(ENet · UDP)의 네트워크를 쓸 수 없음
		_multi_connect.get_node(^"HostRow").hide()
		_multi_connect.get_node(^"JoinRow").hide()
		_multi_status.text = "웹 버전에서는 멀티플레이를 할 수 없습니다 — 윈도우 버전으로 하세요"
		return
	if not Net.is_online() and not _finder.start():
		_multi_status.text = "공개 방 목록을 열 수 없습니다 (이미 다른 창이 쓰는 중?) — 초대 코드로는 참가할 수 있어요"
	_refresh_room_list()


## 방 만들기: 이 컴퓨터가 방장(서버)이 됨. public 이면 같은 네트워크의 공개 방 목록에 보임
func host_room(public: bool = false) -> bool:
	_finder.stop()
	if Net.host_game(GameManager.hero_name, 0, public) != OK:
		_multi_status.text = Net.last_error
		return false
	_internet_code = ""
	_multi_status.text = "%s 방을 만들었습니다. 친구에게 초대 코드를 알려 주세요" % ("공개" if public else "비공개")
	_refresh_lobby()
	return true


## 초대 코드(또는 방장 IP)로 참가
func join_room(code: String) -> bool:
	if code.strip_edges() == "":
		_multi_status.text = "방장에게 받은 초대 코드를 입력하세요"
		return false
	_finder.stop()
	if Net.join_by_code(code, GameManager.hero_name) != OK:
		_multi_status.text = Net.last_error
		return false
	_multi_status.text = "접속하는 중…"
	_refresh_lobby()
	return true


## 공개 방 목록에서 바로 참가
func join_listed_room(room: Dictionary) -> bool:
	_finder.stop()
	if Net.join_game(String(room["ip"]), GameManager.hero_name, int(room["port"])) != OK:
		_multi_status.text = Net.last_error
		return false
	_multi_status.text = "%s 님의 방에 접속하는 중…" % room["name"]
	_refresh_lobby()
	return true


func leave_room() -> void:
	Net.leave()
	_multi_status.text = "방에서 나왔습니다"
	_refresh_lobby()
	if _multi_panel.visible and not OS.has_feature("web"):
		_finder.start()


func _on_join_failed(reason: String) -> void:
	_multi_status.text = reason
	_refresh_lobby()
	if _multi_panel.visible:
		_finder.start()


func _cycle_lobby_difficulty() -> void:
	if Net.is_host():
		Net.set_difficulty((Net.difficulty + 1) % GameManager.Difficulty.size())


## 초대 코드를 클립보드에 (인터넷용 코드를 만들었으면 그것을)
func copy_invite_code() -> String:
	var code := _internet_code if _internet_code != "" else Net.get_invite_code()
	if code != "":
		DisplayServer.clipboard_set(code)
		_multi_status.text = "초대 코드를 복사했습니다: %s" % code
	return code


## 인터넷용 초대 코드: 방장의 공인 IP 를 알아내서 코드를 만듦
func make_internet_code() -> void:
	if _http != null:
		return
	_multi_status.text = "공인 IP 를 알아보는 중…"
	_http = HTTPRequest.new()
	_http.timeout = 6.0
	add_child(_http)
	_http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var ip := body.get_string_from_utf8().strip_edges()
		_http.queue_free()
		_http = null
		if result != HTTPRequest.RESULT_SUCCESS or code != 200 or NetInvite.encode(ip, Net.host_port, 1) == "":
			_multi_status.text = "공인 IP 를 알 수 없습니다 (인터넷 연결 확인) — 같은 네트워크용 코드는 그대로 쓸 수 있어요"
			return
		_internet_code = Net.get_invite_code(ip)
		_multi_status.text = "인터넷용 코드를 만들었습니다 — 방장 공유기에서 UDP %d 포트를 이 컴퓨터로 포트 포워딩해야 합니다" % Net.host_port
		_refresh_lobby())
	if _http.request("https://api.ipify.org") != OK:
		_http.queue_free()
		_http = null
		_multi_status.text = "공인 IP 를 알 수 없습니다"


func _refresh_room_list() -> void:
	if _room_list == null:
		return
	for child in _room_list.get_children():
		_room_list.remove_child(child)
		child.queue_free()
	var rooms := _finder.get_room_list()
	if rooms.is_empty():
		_room_list.add_child(_make_label("찾는 중… (같은 와이파이의 공개 방이 여기에 나옵니다)" if _finder.is_listening() else "—", 8, Color(0.7, 0.7, 0.8)))
		return
	for room in rooms:
		var info: Dictionary = GameManager.DIFFICULTY_INFO[clampi(int(room["difficulty"]), 0, GameManager.Difficulty.size() - 1)]
		var full := int(room["count"]) >= int(room["max"]) or bool(room["in_game"])
		var text := "%s 님의 방 · %d/%d · %s%s" % [room["name"], room["count"], room["max"], info["name"], " · 게임 중" if room["in_game"] else ""]
		var button := _make_button(text, join_listed_room.bind(room))
		button.disabled = full
		_room_list.add_child(button)


func _refresh_lobby() -> void:
	if _multi_panel == null:
		return
	var connected := Net.is_online()
	_multi_connect.visible = not connected
	_multi_lobby.visible = connected
	if not connected:
		return
	var names := PackedStringArray()
	for id in Net.players:
		names.append(("★ " if id == 1 else "· ") + Net.get_player_name(id) + (" (나)" if id == Net.my_id() else ""))
	_lobby_list.text = "함께하는 용사 %d/%d\n%s" % [Net.players.size(), Net.MAX_PLAYERS, "\n".join(names)]
	var info: Dictionary = GameManager.DIFFICULTY_INFO[clampi(Net.difficulty, 0, GameManager.Difficulty.size() - 1)]
	_lobby_difficulty.text = "난이도: %s%s" % [info["name"], "  (눌러서 바꾸기)" if Net.is_host() else ""]
	_lobby_difficulty.disabled = not Net.is_host()
	_lobby_start.visible = Net.is_host()
	_lobby_code.visible = Net.is_host()
	_copy_button.get_parent().visible = Net.is_host()
	if Net.is_host():
		var local_code := Net.get_invite_code()
		_lobby_code.text = "초대 코드  %s" % local_code
		var lines := PackedStringArray()
		lines.append(("공개 방 — 같은 네트워크의 방 목록에도 보입니다" if Net.room_public else "비공개 방 — 초대 코드를 아는 사람만 들어옵니다"))
		lines.append("같은 와이파이 친구는 위 코드로 참가")
		if _internet_code != "":
			lines.append("인터넷용 코드  %s  (UDP %d 포트 포워딩 필요)" % [_internet_code, Net.host_port])
		_lobby_info.text = "\n".join(lines)
	else:
		_lobby_info.text = "방장이 게임을 시작하길 기다리는 중…" if not Net.players.is_empty() else "접속하는 중…"


## 오른쪽 아래 버전 표기 (project.godot 의 config/version — 스팀 빌드마다 올림)
func _add_version_label() -> void:
	var label := Label.new()
	label.name = "VersionLabel"
	label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	label.modulate = Color(1, 1, 1, 0.55)
	label.add_theme_font_size_override(&"font_size", 12)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(label)


## 한글 입력기가 말썽일 때: 영문 자판으로 친 글자(gksrmf)를 한글(한글)로 바꾸는 버튼 — 이름 칸 바로 아래
func _add_hangul_button() -> void:
	var button := Button.new()
	button.name = "HangulButton"
	button.text = "영문 자판으로 친 글자 → 한글  (예: dydtk → 용사)"
	button.add_theme_font_size_override(&"font_size", 9)
	button.tooltip_text = "한글이 한 글자만 들어가면: 한/영 키를 영문으로 두고 한글 자리대로 친 뒤 이 버튼"
	button.pressed.connect(convert_name_to_hangul)
	var confirm := %NameConfirmButton as Button
	confirm.get_parent().add_child(button)
	confirm.get_parent().move_child(button, confirm.get_index())


func convert_name_to_hangul() -> void:
	_hero_name_edit.text = Hangul.from_qwerty(_hero_name_edit.text)
	_hero_name_edit.caret_column = _hero_name_edit.text.length()
	_hero_name_edit.grab_focus()
