class_name TutorialDirector
extends CanvasLayer
## 처음 하는 유저를 위한 튜토리얼 (GameManager.tutorial_mode 일 때 메인 씬이 만듦)
## 1스테이지 야영지에서 시작해 단계마다 화면 위 안내를 띄우고, 해냈는지 확인하면 다음 단계로.
## 모두 마치거나(또는 ESC → 「튜토리얼 건너뛰기」) 하면 Profile 에 기록하고 타이틀로 돌아감.
## 튜토리얼에서 얻은 것은 남지 않음 (타이틀로 갈 때 GameManager 초기화).

signal step_changed(index: int)
signal finished

const TITLE_SCENE := "res://scenes/title/title.tscn"
const KILL_TARGET := 3
## 연습용으로 잠깐 쥐여 주는 활 (2 키 무기 전환 연습)
const PRACTICE_BOW := &"hunter_bow"
const STEPS := [
	{"id": "move", "text": "WASD / 방향키로 움직여 보세요"},
	{"id": "attack", "text": "마우스로 조준하고 좌클릭으로 공격하세요 (3번)"},
	{"id": "dash", "text": "Space(또는 Shift)로 대시하세요 — 대시 중에는 무적"},
	{"id": "guard", "text": "우클릭(또는 F)을 누르고 있으면 방패로 막습니다 — 잠시 누르고 있어 보세요"},
	{"id": "switch", "text": "연습용 활을 드렸습니다. 2 키로 활, 1 키로 검으로 바꿔 보세요"},
	{"id": "potion", "text": "체력이 줄었습니다! H 키로 회복 포션을 마시세요"},
	{"id": "inventory", "text": "I(또는 Tab)로 인벤토리를 열었다가 닫아 보세요 — 장비 · 장신구를 갈아 끼우는 곳"},
	{"id": "shop", "text": "상인에게 다가가 E 로 상점을 열어 보세요 — 장비를 사고팔 수 있음 (ESC 로 닫기)"},
	{"id": "hunt", "text": "텔레포트로 가서 E → 사냥터에서 몬스터 %d마리를 처치하세요" % KILL_TARGET},
	{"id": "done", "text": "튜토리얼 완료! 보스방 봉인을 풀고 보스를 쓰러뜨리며 100스테이지까지 나아가세요. 잠시 뒤 타이틀로 돌아갑니다"},
]
const GUARD_HOLD := 0.6
const MOVE_DISTANCE := 60.0
const DONE_DELAY := 3.0

var player: Player
var step: int = 0
## false 면 끝나도 타이틀로 가지 않음 (자동 테스트용)
var return_to_title: bool = true

var _panel: PanelContainer
var _label: Label
var _progress: Label
var _moved: float = 0.0
var _last_pos: Vector2
var _attacks: int = 0
var _guard_time: float = 0.0
var _switched: Dictionary = {}
var _kills_at_start: int = 0
var _inventory_opened: bool = false
var _done_left: float = -1.0
var _story_was_enabled: bool = true


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_story_was_enabled = Story.enabled
	Story.enabled = false  # 튜토리얼 동안은 이야기 대사를 띄우지 않음
	GameManager.player_attacked.connect(func(_w: WeaponData, _a: Vector2) -> void: _attacks += 1)
	GameManager.potion_used.connect(func(_p: PotionData, _h: int) -> void:
		if _current_id() == "potion":
			_advance())
	GameManager.shop_open_requested.connect(func(_n: String, _s: Array) -> void:
		if _current_id() == "shop":
			_advance())
	if player != null:
		_last_pos = player.global_position
	_show_step()


func _exit_tree() -> void:
	Story.enabled = _story_was_enabled


func _process(delta: float) -> void:
	_panel.visible = not get_tree().paused  # 상점 · 인벤토리 · 설정창이 열리면 그 창을 가리지 않게
	if _done_left >= 0.0:
		_done_left -= delta
		if _done_left <= 0.0:
			finish()
		return
	if get_tree().paused and _current_id() != "inventory":
		return
	match _current_id():
		"move":
			if player != null:
				_moved += player.global_position.distance_to(_last_pos)
				_last_pos = player.global_position
			if _moved >= MOVE_DISTANCE:
				_advance()
		"attack":
			_progress.text = "%d / 3" % mini(_attacks, 3)
			if _attacks >= 3:
				_advance()
		"dash":
			if player != null and player.is_dashing():
				_advance()
		"guard":
			if player != null and player.is_guarding():
				_guard_time += delta
			_progress.text = "%.1f / %.1f초" % [minf(_guard_time, GUARD_HOLD), GUARD_HOLD]
			if _guard_time >= GUARD_HOLD:
				_advance()
		"switch":
			_switched[GameManager.active_weapon_slot] = true
			if _switched.has(GameManager.WeaponSlot.MELEE) and _switched.has(GameManager.WeaponSlot.BOW):
				_advance()
		"inventory":
			var inventory := get_parent().get_node_or_null(^"InventoryUI") as CanvasLayer
			if inventory != null and inventory.visible:
				_inventory_opened = true
			elif _inventory_opened:
				_advance()
		"hunt":
			var count := GameManager.total_kills - _kills_at_start
			_progress.text = "%d / %d마리" % [mini(count, KILL_TARGET), KILL_TARGET]
			if count >= KILL_TARGET:
				_advance()


func get_step_id() -> String:
	return _current_id()


func _current_id() -> String:
	return STEPS[clampi(step, 0, STEPS.size() - 1)]["id"]


func _advance() -> void:
	if step >= STEPS.size() - 1:
		return
	step += 1
	_show_step()
	step_changed.emit(step)


func _show_step() -> void:
	var id := _current_id()
	_label.text = "튜토리얼 %d/%d — %s" % [step + 1, STEPS.size(), STEPS[step]["text"]]
	_progress.text = ""
	match id:
		"switch":
			var bow := ItemDB.get_weapon(PRACTICE_BOW)
			if bow != null and not GameManager.owns_item(bow.id):
				GameManager.add_item(bow)
				GameManager.equip_item(bow)  # 활 칸에 들어가며 손에 듦
			_switched = {GameManager.active_weapon_slot: true}
		"potion":
			GameManager.heal_full()
			GameManager.damage_player(roundi(GameManager.max_hp * 0.4))
		"hunt":
			_kills_at_start = GameManager.total_kills
		"done":
			GameManager.show_notice("튜토리얼 완료!", Color(1.0, 0.9, 0.5))
			_done_left = DONE_DELAY


## 튜토리얼을 마치고(또는 건너뛰고) 타이틀로
func finish() -> void:
	_done_left = -1.0
	Profile.complete_tutorial()
	finished.emit()
	GameManager.tutorial_mode = false
	GameManager.reset_game()
	Story.enabled = _story_was_enabled
	get_tree().paused = false
	if return_to_title:
		get_tree().change_scene_to_file(TITLE_SCENE)


func _build() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.85, 1.0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override(&"panel", style)
	# 화면 아래, 무기 · 장비 단축칸 바로 위 (위쪽은 스테이지 이름 · 알림 문구 자리)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -200.0
	_panel.offset_right = 200.0
	_panel.offset_top = -100.0
	_panel.offset_bottom = -44.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	_panel.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 10)
	_label.add_theme_color_override(&"font_color", Color(0.85, 0.95, 1.0))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(388, 0)
	box.add_child(_label)
	_progress = Label.new()
	_progress.add_theme_font_size_override(&"font_size", 9)
	_progress.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.45))
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_progress)
	var hint := Label.new()
	hint.text = "ESC → 튜토리얼 건너뛰기"
	hint.add_theme_font_size_override(&"font_size", 7)
	hint.add_theme_color_override(&"font_color", Color(0.6, 0.65, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
