extends Control
## 엔딩 화면 (모든 스테이지 클리어 후 StageManager 가 전환)
##
## 0) 엔딩 장면 (EndingCinematic): 세계들의 귀환 → 균열이 아묾 → 포탈이 닫힘 → 빈 관리자의 자리에 누군가 앉음 → 포탈이 다시 열림
## 1) 이야기 문장이 한 줄씩 떠오름
## 2) 모험 기록 (난이도 / 클리어 시간 / 처치 수 / 골드 / 최종 장비)
## 3) 「타이틀로 돌아가기」 → GameManager 초기화 후 타이틀 메뉴
##
## 아무 키나 누르면 연출을 건너뛰고 기록을 바로 보여 줍니다.

const TITLE_SCENE := "res://scenes/title/title.tscn"
const LINE_INTERVAL := 1.1
const STORY := [
	"초록 들판을 뒤덮던 슬라임 킹이 쓰러지고,",
	"불타는 지옥문을 지키던 수문장의 업화가 꺼졌다.",
	"원소의 거신 아르케온이 깊은 잠에 들어 원소는 균형을 되찾았고,",
	"숲의 주인 드라이어드가 무릎을 꿇자 숲의 아이들도 고요해졌다.",
	"빈 옥좌를 지키던 기사단장 듀라한은 끝까지 왕의 귀환을 기다리다 쓰러졌다.",
	"오크킹의 요새와 사신의 묘지, 와이번의 둥지와 마계의 문을 차례로 넘어,",
	"마침내 그 옥좌의 주인, 옥좌 잃은 왕의 저주받은 왕관이 부서지자",
	"왕은 충직한 기사단장의 이름을 부르며 잠들었고, 오랜 저주가 풀렸다.",
	"금단의 연구소와 마도 공장, 가라앉은 신전과 시간의 회랑, 거울의 미궁을 지나",
	"그리핀과 티탄, 마리오네트와 레비아탄, 아르카나와 테모스, 스콜피언과 벨, 바실리스크를 넘어",
	"쌍둥이와 빙결의 여왕, 심연의 녹스, 나이트메어와 가이아, 다섯 용과 불사의 헬리시온을 지나",
	"올림포스의 신들과 대죄의 마왕, 천사들을 넘어 — 백 개의 세계를 구경하던 상인, 멀티버스의 주인마저 쓰러졌다.",
	"이름 없는 성기사의 전설은 그렇게 시작되었다.",
]
## 히든 보스(고대 드래곤 아르케)를 쓰러뜨렸으면 마지막 줄이 바뀜
const HIDDEN_LAST_LINE := "…그리고 아무도 모르는 고대 용 아르케의 이름이, 그 전설의 맨 끝에 새겨졌다."

@onready var _the_end: Label = %TheEnd
@onready var _story_box: VBoxContainer = %StoryBox
@onready var _record_panel: Control = %RecordPanel
@onready var _record_title: Label = %RecordTitle
@onready var _record: Label = %Record
@onready var _return_button: Button = %ReturnButton

var _story_labels: Array[Label] = []
var _cinematic: EndingCinematic
var _sequence: Tween
var _finished: bool = false
var _time: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	_return_button.pressed.connect(return_to_difficulty_select)
	_record.text = build_record_text()
	var info := GameManager.get_difficulty_info()
	_record_title.text = "모험 기록 — 난이도: %s%s" % [info["name"], "  · 히든 클리어" if GameManager.hidden_cleared else ""]
	_record_title.add_theme_color_override(&"font_color", info["color"])
	var story: Array = STORY.duplicate()
	if GameManager.hidden_cleared:
		story[story.size() - 1] = HIDDEN_LAST_LINE
	for line in story:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 11)
		label.add_theme_constant_override(&"outline_size", 3)
		label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.04, 0.1))
		label.modulate.a = 0.0
		_story_box.add_child(label)
		_story_labels.append(label)
	_the_end.modulate.a = 0.0
	_record_panel.modulate.a = 0.0
	_record_panel.hide()
	_add_light_particles()
	if Story.play("엔딩"):
		await Story.finished
	if _finished:
		return
	_play_cinematic()


func _play_cinematic() -> void:
	var layout := _story_box.get_parent() as Control
	layout.modulate.a = 0.0
	_cinematic = EndingCinematic.new()
	add_child(_cinematic)
	_cinematic.finished.connect(func() -> void:
		var fade := create_tween()
		fade.tween_property(_cinematic, "modulate:a", 0.0, 1.0)
		fade.parallel().tween_property(layout, "modulate:a", 1.0, 1.0)
		fade.tween_callback(_cinematic.queue_free)
		_play_sequence())


## 엔딩 장면 (테스트용)
func get_cinematic() -> EndingCinematic:
	return _cinematic if is_instance_valid(_cinematic) else null


func _process(delta: float) -> void:
	_time += delta
	_the_end.modulate = Color(1.0, 0.92, 0.6, _the_end.modulate.a).lerp(Color(1, 1, 1, _the_end.modulate.a), (sin(_time * 2.0) + 1.0) * 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		skip()


func _play_sequence() -> void:
	_sequence = create_tween()
	_sequence.tween_property(_the_end, "modulate:a", 1.0, 1.2)
	for label in _story_labels:
		_sequence.tween_interval(LINE_INTERVAL * 0.4)
		_sequence.tween_property(label, "modulate:a", 1.0, LINE_INTERVAL * 0.6)
	_sequence.tween_interval(0.6)
	_sequence.tween_callback(_show_record)


## 연출 건너뛰기: 모든 문장과 기록을 즉시 표시
func skip() -> void:
	if is_instance_valid(_cinematic):
		_cinematic.queue_free()
		_cinematic = null
		(_story_box.get_parent() as Control).modulate.a = 1.0
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	_the_end.modulate.a = 1.0
	for label in _story_labels:
		label.modulate.a = 1.0
	_show_record()


func is_finished() -> bool:
	return _finished


func _show_record() -> void:
	if _finished:
		return
	_finished = true
	_record_panel.show()
	create_tween().tween_property(_record_panel, "modulate:a", 1.0, 0.6)
	_return_button.grab_focus()


func build_record_text() -> String:
	var lines := PackedStringArray()
	lines.append("클리어 시간  %s" % GameManager.get_play_time_text())
	lines.append("처치한 몬스터  %d마리" % GameManager.total_kills)
	lines.append("보유 골드  %d G" % GameManager.gold)
	var weapons := PackedStringArray()
	for weapon in GameManager.weapon_slots:
		if weapon != null:
			weapons.append(weapon.display_name)
	lines.append("최종 무기  %s" % (" · ".join(weapons) if not weapons.is_empty() else "-"))
	return "\n".join(lines)


## 새 모험을 위해 데이터를 초기화하고 난이도 선택 화면(타이틀)으로
func return_to_difficulty_select() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file(TITLE_SCENE)


## 화면 아래에서 떠오르는 금빛 빛가루
func _add_light_particles() -> void:
	var lights := Fx.make_aura(Color(1.0, 0.85, 0.4), 50, 4.0, Vector2(0, -18), 5.0)
	lights.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	lights.emission_rect_extents = Vector2(330, 6)
	lights.initial_velocity_min = 8.0
	lights.initial_velocity_max = 24.0
	lights.scale_amount_min = 0.6
	lights.scale_amount_max = 1.4
	lights.position = Vector2(320, 368)
	add_child(lights)
	move_child(lights, 2)
	lights.emitting = true
