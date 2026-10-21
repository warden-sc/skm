class_name HUD
extends CanvasLayer
## 화면 HUD. GameManager 시그널만 구독해서 갱신합니다 (게임 로직을 직접 참조하지 않음).
##
## - 왼쪽 위: HP / DASH / GUARD 게이지(TextureProgressBar), 골드
## - 위 가운데: 스테이지·난이도, 현재 위치(야영지/사냥터/보스방), 보스방 해방 진행도, 보스 체력
## - 아래 가운데 단축바: 무기 3칸(1/2/3, 손에 든 무기 강조) + 방어구 4칸(방패/투구/갑옷/신발) + 장신구 3칸(팔찌/반지/펜던트) + 회복 포션(H)
##
## hud.tscn 의 노드들은 "고유 이름(%)" 으로 접근하므로 레이아웃을 바꿔도 경로가 깨지지 않습니다.

const NOTICE_TIME := 2.5
const WEAPON_SLOT_SIZE := Vector2(30, 30)
const SMALL_SLOT_SIZE := Vector2(20, 20)

@onready var _hp_bar: TextureProgressBar = %HPBar
@onready var _hp_label: Label = %HPLabel
@onready var _dash_bar: TextureProgressBar = %DashBar
@onready var _dash_label: Label = %DashLabel
@onready var _guard_bar: TextureProgressBar = %GuardBar
@onready var _guard_label: Label = %GuardLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _stage_label: Label = %StageLabel
@onready var _location_label: Label = %LocationLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _boss_box: Control = %BossBox
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: TextureProgressBar = %BossBar
@onready var _notice_label: Label = %NoticeLabel
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _hotbar: HBoxContainer = %Hotbar
@onready var _game_over: Control = %GameOver

var _hp_tween: Tween
var _notice_tween: Tween
var _shown_potion: PotionData
## 신화 사용 아이템 칸의 대기시간 글자 { id: Label }
var _relic_labels: Dictionary = {}
var _status_label: Label


func _ready() -> void:
	GameManager.player_hp_changed.connect(_on_hp_changed)
	GameManager.player_damaged.connect(_on_player_damaged)
	GameManager.player_died.connect(_on_player_died)
	GameManager.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	GameManager.guard_changed.connect(_on_guard_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.equipment_changed.connect(_rebuild_hotbar)
	GameManager.potions_changed.connect(_rebuild_hotbar)
	GameManager.inventory_changed.connect(_rebuild_hotbar)
	GameManager.player_hp_changed.connect(_on_hp_changed_for_potion.unbind(2))
	GameManager.stage_changed.connect(_on_stage_changed)
	GameManager.location_changed.connect(_on_location_changed)
	GameManager.kill_progress_changed.connect(_on_kill_progress_changed)
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_hp_changed.connect(_on_boss_hp_changed)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.notice_requested.connect(_on_notice_requested)
	GameManager.player_status_changed.connect(_on_player_status_changed)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.position = Vector2(10, 62)
	_status_label.add_theme_font_size_override(&"font_size", 9)
	_status_label.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.4))
	_status_label.add_theme_color_override(&"font_outline_color", Color(0.1, 0.05, 0.05))
	_status_label.add_theme_constant_override(&"outline_size", 3)
	add_child(_status_label)
	_on_player_status_changed(GameManager.player_status)

	_boss_box.hide()
	_game_over.hide()
	GameManager.player_hp_changed.connect(_hide_game_over_on_revive)
	_notice_label.modulate.a = 0.0
	_damage_flash.modulate.a = 0.0

	# 현재 값으로 초기 동기화
	_hp_bar.max_value = GameManager.max_hp
	_hp_bar.value = GameManager.hp
	_on_hp_changed(GameManager.hp, GameManager.max_hp)
	_on_dash_cooldown_changed(GameManager.dash_cooldown_remaining, GameManager.dash_cooldown_total)
	_on_guard_changed(GameManager.guard, GameManager.max_guard)
	_on_gold_changed(GameManager.gold)
	_on_stage_changed(GameManager.stage)
	_on_location_changed(GameManager.location_name)
	_on_kill_progress_changed(GameManager.kills, GameManager.kill_target)
	_rebuild_hotbar()


func _on_hp_changed(current: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_label.text = "%d / %d" % [current, max_hp]
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(_hp_bar, "value", float(current), 0.15)


func _on_player_damaged(_amount: int) -> void:
	_damage_flash.modulate.a = 0.35
	create_tween().tween_property(_damage_flash, "modulate:a", 0.0, 0.3)


func _on_dash_cooldown_changed(remaining: float, total: float) -> void:
	_dash_bar.max_value = 100.0
	_dash_bar.value = (1.0 - remaining / maxf(total, 0.001)) * 100.0
	_dash_label.text = "READY" if remaining <= 0.0 else "%.1fs" % remaining


func _on_guard_changed(current: float, max_guard: float) -> void:
	_guard_bar.max_value = maxf(max_guard, 1.0)
	_guard_bar.value = current
	_guard_label.text = "-" if max_guard <= 0.0 else "%d / %d" % [roundi(current), roundi(max_guard)]


func _on_gold_changed(gold: int) -> void:
	_gold_label.text = "%d G" % gold


func _on_stage_changed(stage: int) -> void:
	var difficulty := "[%s]" % GameManager.get_difficulty_name()
	if GameManager.stage_name.is_empty():
		_stage_label.text = "%s STAGE %d" % [difficulty, stage]
	else:
		_stage_label.text = "%s STAGE %d · %s" % [difficulty, stage, GameManager.stage_name]
	_stage_label.add_theme_color_override(&"font_color", GameManager.get_difficulty_info()["color"])


func _on_location_changed(location_name: String) -> void:
	_location_label.text = location_name
	_update_progress_text()


func _on_kill_progress_changed(_kills: int, _target: int) -> void:
	_update_progress_text()


func _update_progress_text() -> void:
	var kills := GameManager.kills
	var target := GameManager.kill_target
	if GameManager.is_boss_active:
		_progress_label.text = "보스전"
	elif target <= 0:
		_progress_label.text = ""
	elif kills >= target:
		_progress_label.text = "보스방 해방됨 — 사냥터 북쪽 문"
	else:
		_progress_label.text = "보스방 해방까지 처치 %d / %d" % [kills, target]


func _on_boss_spawned(boss_name: String, max_hp: int) -> void:
	_boss_name.text = boss_name
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_progress_label.text = "보스전"
	_boss_box.show()


func _on_boss_hp_changed(current: int, max_hp: int) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = current


func _on_boss_defeated() -> void:
	_boss_box.hide()
	_progress_label.text = "보스 토벌 완료!"


## 화상 / 점액 바닥 / 감속 등 상태 이상 표시 (HP 바 아래)
func _on_player_status_changed(text: String) -> void:
	_status_label.text = text
	_status_label.visible = text != ""


func _on_notice_requested(text: String, color: Color) -> void:
	_notice_label.text = text
	_notice_label.add_theme_color_override(&"font_color", color)
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_label.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_TIME)
	_notice_tween.tween_property(_notice_label, "modulate:a", 0.0, 0.5)


## 멀티플레이 부활: 체력이 다시 차면 「쓰러짐」 화면을 닫음
func _hide_game_over_on_revive(current: int, _max_hp: int) -> void:
	if current > 0 and not GameManager.is_player_dead:
		_game_over.hide()


func _on_player_died() -> void:
	if Net.is_online():
		return  # 멀티플레이: 유령이 되어 동료를 관전 (Spectator) — 모두 쓰러지면 show_party_game_over
	_game_over.show()


## 멀티플레이 전멸 → 게임 오버 화면 (방장이 다시 할지 끝낼지 고름)
func show_party_game_over(is_host: bool) -> void:
	var label := _game_over.get_node(^"GameOverLabel") as Label
	if is_host:
		label.text = "전멸 — GAME OVER\n[R] 1스테이지부터 다 함께 다시   [T] 끝내기 (타이틀로)"
	else:
		label.text = "전멸 — GAME OVER\n방장이 다시 할지 고르는 중…   [T] 나가기 (타이틀로)"
	_game_over.show()


# ============================================================ 단축바
func _rebuild_hotbar() -> void:
	for child in _hotbar.get_children():
		child.queue_free()
	for i in GameManager.weapon_slots.size():
		var weapon := GameManager.weapon_slots[i]
		_hotbar.add_child(_make_slot(weapon, WEAPON_SLOT_SIZE, str(i + 1), i == GameManager.active_weapon_slot))
	_hotbar.add_child(_make_spacer())
	for item in [GameManager.equipped_shield, GameManager.equipped_helmet, GameManager.equipped_armor, GameManager.equipped_boots]:
		_hotbar.add_child(_make_slot(item, SMALL_SLOT_SIZE, "", false))
	_hotbar.add_child(_make_spacer())
	for accessory in GameManager.accessory_slots:
		_hotbar.add_child(_make_slot(accessory, SMALL_SLOT_SIZE, "", false))
	_hotbar.add_child(_make_spacer())
	_hotbar.add_child(_make_potion_slot())
	# 고대 용의 피 [C] · 원초의 불꽃 [Z] · 최후의 나팔 [X] (가지고 있을 때만)
	_relic_labels.clear()
	var blood_count := GameManager.get_potion_count(&"dragon_blood")
	if blood_count > 0:
		_hotbar.add_child(_make_spacer())
		var blood_slot := _make_slot(ItemDB.get_potion(&"dragon_blood"), WEAPON_SLOT_SIZE, "C", false)
		blood_slot.name = "DragonBloodSlot"
		if ItemDB.get_potion(&"dragon_blood").is_sealed():
			blood_slot.modulate = Color(0.45, 0.45, 0.5)
		blood_slot.add_child(_corner_label("x%d" % blood_count, Color(1.0, 0.6, 0.6)))
		_hotbar.add_child(blood_slot)
	for relic in GameManager.relics:
		_hotbar.add_child(_make_spacer())
		var slot := _make_slot(relic, WEAPON_SLOT_SIZE, relic.key_label, false)
		slot.name = "Relic_%s" % relic.id
		var cd := _corner_label("", Color(0.75, 0.85, 1.0))
		slot.add_child(cd)
		_relic_labels[relic.id] = cd
		_hotbar.add_child(slot)


func _corner_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 9)
	label.add_theme_constant_override(&"outline_size", 3)
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.1))
	label.add_theme_color_override(&"font_color", color)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	return label


## 사용 아이템 대기시간 (매 프레임)
func _process(_delta: float) -> void:
	for relic in GameManager.relics:
		var label := _relic_labels.get(relic.id) as Label
		if label != null and is_instance_valid(label):
			var cd := GameManager.get_relic_cooldown(relic)
			label.text = "봉인" if relic.is_sealed() else ("%d" % ceili(cd) if cd > 0.0 else "")
			(label.get_parent() as CanvasItem).modulate = Color(0.45, 0.45, 0.5) if relic.is_sealed() else (Color(0.55, 0.55, 0.6) if cd > 0.0 else Color.WHITE)


## 포션 칸: [H] 로 마실 포션 아이콘 + 총 개수
func _make_potion_slot() -> Control:
	var potion := GameManager.choose_potion()
	_shown_potion = potion
	var slot := _make_slot(potion, WEAPON_SLOT_SIZE, "H", false)
	var count := Label.new()
	count.name = "PotionCount"
	count.text = "x%d" % GameManager.get_total_potions()
	count.add_theme_font_size_override(&"font_size", 9)
	count.add_theme_constant_override(&"outline_size", 3)
	count.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.1))
	count.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.6) if potion != null else Color(0.7, 0.5, 0.5))
	count.size_flags_horizontal = Control.SIZE_SHRINK_END
	count.size_flags_vertical = Control.SIZE_SHRINK_END
	slot.add_child(count)
	return slot


## 체력에 따라 [H] 로 고를 포션이 바뀌므로 아이콘을 갱신
func _on_hp_changed_for_potion() -> void:
	if GameManager.choose_potion() != _shown_potion:
		_rebuild_hotbar()


func _make_slot(item: ItemData, slot_size: Vector2, key: String, active: bool) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	var style := ItemRow.rarity_style(item, active)
	style.set_content_margin_all(1)
	if item == null:
		style.bg_color = Color(0.08, 0.08, 0.12, 0.6)
	panel.add_theme_stylebox_override(&"panel", style)
	var icon := TextureRect.new()
	icon.custom_minimum_size = slot_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = item.icon if item != null else null
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not active and slot_size == WEAPON_SLOT_SIZE:
		icon.modulate = Color(0.75, 0.75, 0.8)
	panel.add_child(icon)
	if key != "":
		var label := Label.new()
		label.text = key
		label.add_theme_font_size_override(&"font_size", 8)
		label.add_theme_constant_override(&"outline_size", 3)
		label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.1))
		label.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.6) if active else Color(0.8, 0.8, 0.85))
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel.add_child(label)
	return panel


func _make_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
