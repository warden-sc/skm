extends Node
## 운영자 모드 (오토로드 Admin) — 개발자 본인만, 원할 때만 켜는 개입 · 구제 도구.
##
## [안전장치 — 두 겹]
##   1) 빌드: 에디터에서 실행(OS 기능 "editor")했거나, 「Windows (운영자)」 내보내기 설정처럼 사용자 기능 "admin_build" 를 넣은 빌드에서만.
##      스팀 · 일반 배포용 「Windows Desktop」 · 「Web」 빌드에는 이 기능이 없으므로 아래 2) 를 맞춰도 절대 켜지지 않음.
##   2) 신원: 다음 중 하나가 맞아야 함
##      - 환경변수 CRUSADER_ADMIN_KEY = 운영자 키 (키의 SHA-256 이 ADMIN_KEY_SHA256 과 같아야 — 저장소에는 해시만 있음)
##      - user://admin.key 파일에 운영자 키 한 줄 (Windows: %APPDATA%\Godot\app_userdata\Sefirah-like Topdown Action\admin.key)
##      - 스팀판(GodotSteam)이면 내 스팀 ID 가 DEV_STEAM_IDS 에 있음
##   3) (선택) 개발자 PC: DEV_MACHINE_CODES 에 「이 PC 코드」를 넣으면 키가 맞아도 그 PC 에서만
##   → 일반 플레이어는 물론 멀티플레이 방장 · 참가자도 키가 없으면 절대 못 씀. 운영자 = 게임을 만든 사람 한 명.
##   권한이 없으면 단축키를 눌러도 아무 일도 일어나지 않고(알림도 없음) 운영자 UI 는 만들어지지도 않음.
##   키를 바꾸려면 python3 tools/make_admin_key.py → 나온 해시를 ADMIN_KEY_SHA256 에.
##
## [사용] 게임은 항상 일반 플레이어 모드로 시작. 저장되지 않음.
##   Ctrl + Shift + A : 운영자 모드 켜기 / 끄기 (켜지면 화면 왼쪽 아래 작은 「ADMIN MODE」)
##   F11              : 운영자 패널 (운영자 모드일 때만) — 스테이지 이동 · 보스문 열기 · 운영자 장비 · 강림 이벤트
##   Ctrl + Shift + D : 개발자 강림 (패널에 적어 둔 대사 · 선물로 바로)
##   멀티플레이에서는 개발자가 방을 만든(방장) 경우에만 쓸 수 있고, 강림 이벤트는 RPC 로 모든 참가자 화면 · 버프에 똑같이 적용.
##   개발자가 아닌 사람이 방장이면 그 방에서는 아무도 운영자 기능을 못 씀 (방장이라는 것만으로는 권한 없음).
##   운영자 모드가 켜져 있는 동안에는 업적이 달성되지 않음.

signal mode_changed(on: bool)
signal descent_finished

const ADMIN_KEY_SHA256 := "e6ef828eb4f2b1e6fca252c27803f017642ee40011ac14de3ecc76ff149ad82c"
## 개발자 스팀 ID(64비트 숫자). 스팀판에서 이 계정이면 키 없이도 권한 (빌드 조건은 그대로)
const DEV_STEAM_IDS: Array[int] = []
## 운영자 PC 등록 (비어 있으면 키만으로). 패널 맨 위의 「이 PC 코드」를 여기에 넣으면 키가 새어 나가도 그 PC 에서만 켜짐
const DEV_MACHINE_CODES: Array[String] = []
const ENV_KEY := "CRUSADER_ADMIN_KEY"
const KEY_FILE := "user://admin.key"
const BUILD_FEATURE := "admin_build"

const DEV_NAME := "개발자"
const DEV_TEXTURE: Texture2D = preload("res://assets/sprites/characters/developer.png")
const DEV_SCALE := 2.0
const LIGHT := Color(1.0, 0.92, 0.6)
const PILLAR_HEIGHT := 420.0
const PILLAR_WIDTH := 46.0

const GEAR_DAMAGE := AdminGear.WEAPON_DAMAGE

## 운영자의 가호 — 운영자가 수치를 정해서 주는 버프. 키: [표시 이름, 최댓값, 버프 효과 키]
const BLESSING_NAME := "운영자의 가호"
const BLESSING_STATS := {
	"attack": ["공격력 +%", 10000.0, "attack"],
	"max_hp": ["최대 체력 +%", 10000.0, "max_hp_pct"],
	"defense": ["방어력 +%", 10000.0, "defense_pct"],
	"reduction": ["받는 피해 -%", 95.0, "admin_reduction"],
	"move": ["이동 속도 +%", 200.0, "move"],
	"regen": ["초당 체력 회복 %", 50.0, "regen_pct"],
}
const BLESSING_MAX_TIME := 3600.0
const SHIELD_NAME := "개발자의 보호막"
const MAX_LINES := 6
const MAX_LINE_CHARS := 160
const MAX_GOLD := 100000000

## 운영자 키의 SHA-256 (자동 테스트는 시험용 키로 바꿔 씀 — 그래도 빌드 조건은 그대로)
var key_hash: String = ADMIN_KEY_SHA256
var authorized: bool = false
## 권한을 준 것: "env" · "file" · "steam" (없으면 "")
var auth_source: String = ""
var enabled: bool = false
## 운영자의 갑옷을 입고 있음 — 무적
var god: bool:
	get:
		return AdminGear.is_admin_armor(GameManager.equipped_armor)
var descent_active: bool = false
## 패널에 적어 둔 다음 강림 내용 (Ctrl+Shift+D 도 이것으로)
var preset: Dictionary = {
	"lines": ["용사여, 잠시 손을 빌려주지.", "이 축복으로 다시 일어서라!"],
	"heal": true, "invincible": true, "shield_time": 15.0, "gold": 0, "item": "", "count": 1,
	"blessing": {"attack": 100.0, "max_hp": 0.0, "defense": 0.0, "reduction": 0.0, "move": 0.0, "regen": 0.0, "time": 60.0},
	"chat": true,
}

var _layer: CanvasLayer
var _badge: Label
var _panel: Control
var _saved_equipment: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_authorization()


# ============================================================ 권한
## 이 빌드에서 운영자 기능이 들어갈 수 있는지 (에디터 실행 · 운영자 빌드만)
static func is_build_allowed() -> bool:
	return OS.has_feature("editor") or OS.has_feature(BUILD_FEATURE)


func key_matches(key: String) -> bool:
	key = key.replace("\ufeff", "").strip_edges()  # 메모장이 붙이는 BOM 은 빼고
	return key != "" and key.sha256_text() == key_hash


## 권한을 다시 확인 (시작할 때 한 번 — 환경변수 · 키 파일 · 스팀 ID)
func refresh_authorization() -> void:
	authorized = false
	auth_source = ""
	if is_build_allowed():
		if key_matches(OS.get_environment(ENV_KEY)):
			auth_source = "env"
		elif FileAccess.file_exists(KEY_FILE) and key_matches(FileAccess.get_file_as_string(KEY_FILE)):
			auth_source = "file"
		elif _steam_id_allowed():
			auth_source = "steam"
		if auth_source != "" and not DEV_MACHINE_CODES.is_empty() and not DEV_MACHINE_CODES.has(machine_code()):
			auth_source = ""  # 키는 맞지만 등록한 개발자 PC 가 아님
		authorized = auth_source != ""
	if not authorized:
		set_enabled(false)
		if _layer != null:
			_layer.queue_free()
			_layer = null
			_badge = null
			_panel = null
	# 에디터 · 운영자 빌드에서만 단축키를 봄 (권한이 없으면 출력 창에 이유만 — 화면에는 아무것도 안 나옴)
	set_process_input(is_build_allowed())


## 권한이 없을 때 왜 없는지 (에디터 · 운영자 빌드의 출력 창에만)
func explain_denied() -> String:
	if not is_build_allowed():
		return "이 빌드는 운영자 기능이 없는 일반 빌드입니다 (운영자 빌드는 run_admin.bat 로 실행)"
	if auth_source == "" and not DEV_MACHINE_CODES.is_empty():
		return "이 PC 코드(%s)가 DEV_MACHINE_CODES 에 없습니다" % machine_code()
	return "운영자 키를 찾지 못했습니다 — 환경변수 %s 또는 %s (%s) 에 키 한 줄. 스팀 ID: %s" % [
		ENV_KEY, KEY_FILE, ProjectSettings.globalize_path(KEY_FILE),
		("연결됨 %d (DEV_STEAM_IDS 에 없음)" % SteamApi.get_steam_id()) if SteamApi.is_running() else "스팀 연결 안 됨"]


## 이 PC 를 나타내는 코드 (기기 고유 id 의 해시 앞 16자 — 기기 id 자체는 드러나지 않음)
static func machine_code() -> String:
	return OS.get_unique_id().sha256_text().left(16)


func _steam_id_allowed() -> bool:
	if DEV_STEAM_IDS.is_empty() or not SteamApi.is_running():
		return false
	return DEV_STEAM_IDS.has(SteamApi.get_steam_id())


## 지금 운영자 기능을 쓸 수 있는지 (멀티플레이 참가자는 안 됨 — 방장만)
func can_act() -> bool:
	return authorized and enabled and not Net.is_client()


# ============================================================ 모드
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var combo := key.ctrl_pressed and key.shift_pressed
	if not authorized:
		if combo and _is_key(key, KEY_A):
			print("[Admin] 운영자 모드를 켤 수 없음: ", explain_denied())
		return
	if combo and _is_key(key, KEY_A):
		set_enabled(not enabled)
	elif enabled and _is_key(key, KEY_F11):
		toggle_panel()
	elif enabled and combo and _is_key(key, KEY_D):
		descend(preset)
	else:
		return
	get_viewport().set_input_as_handled()


## 한글 입력 상태 · 다른 자판에서도 같은 자리의 키면 인정
static func _is_key(key: InputEventKey, code: Key) -> bool:
	return key.keycode == code or key.physical_keycode == code


## 운영자 모드 켜기 / 끄기. 권한이 없거나 멀티플레이 참가자면 켜지지 않음
func set_enabled(on: bool) -> bool:
	if on and (not authorized or Net.is_client()):
		return false
	if on == enabled:
		return true
	enabled = on
	if not on:
		set_gear(false)
		_close_panel()
	_ensure_ui()
	if _badge != null:
		_badge.visible = on
	if on:
		GameManager.show_notice("운영자 모드 ON — [F11] 패널 · [Ctrl+Shift+D] 강림 · [Ctrl+Shift+A] 끄기", Color(1.0, 0.5, 0.45))
	elif authorized:
		GameManager.show_notice("운영자 모드 OFF — 일반 플레이어로 돌아감", Color(0.8, 0.8, 0.85))
	mode_changed.emit(on)
	return true


func _ensure_ui() -> void:
	if _layer != null or not authorized:
		return
	_layer = CanvasLayer.new()
	_layer.name = "AdminLayer"
	_layer.layer = 110
	add_child(_layer)
	_badge = Label.new()
	_badge.name = "AdminBadge"
	_badge.text = "ADMIN MODE"
	_badge.add_theme_font_size_override(&"font_size", 9)
	_badge.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.3, 0.75))
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 4)
	_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_badge.visible = false
	_layer.add_child(_badge)


func get_badge() -> Label:
	return _badge


# ============================================================ 패널
func toggle_panel() -> void:
	if is_panel_open():
		_close_panel()
	elif can_act():
		_ensure_ui()
		_panel = AdminPanel.new()
		_panel.name = "AdminPanel"
		_layer.add_child(_panel)
		Net.pause_tree(get_tree(), true)


func is_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


func get_panel() -> Control:
	return _panel if is_panel_open() else null


func _close_panel() -> void:
	if is_panel_open():
		_panel.queue_free()
		_panel = null
		Net.pause_tree(get_tree(), false)


func close_panel() -> void:
	_close_panel()


# ============================================================ 운영자 권한: 스테이지 · 보스문
func _stage_manager() -> StageManager:
	return get_tree().get_first_node_in_group(&"stage_manager") as StageManager


## 원하는 스테이지의 야영지로 바로
func teleport_to_stage(stage: int) -> bool:
	var manager := _stage_manager()
	if not can_act() or manager == null:
		return false
	manager.go_to_stage(stage)
	GameManager.show_notice("[운영자] %d스테이지로 이동" % GameManager.stage, Color(1.0, 0.5, 0.45))
	return true


## 지금 스테이지의 보스방 시련을 건너뛰고 문을 엶
func open_boss_gate() -> bool:
	var manager := _stage_manager()
	if not can_act() or manager == null or manager.boss_gate.is_open():
		return false
	manager._unlock_boss_gate()
	return true


# ============================================================ 운영자 장비
## 운영자 장비 10종 (AdminGear) — 무기 3 · 방패 · 투구 · 갑옷(날개 · 무적) · 신발 · 반지 · 팔찌 · 펜던트
func get_gear() -> Array[ItemData]:
	return AdminGear.get_all()


## 운영자 장비 한 벌 착용 / 벗기(원래 장비로). 저장 · 판매 · 버리기 불가
func set_gear(on: bool) -> bool:
	if on == god:
		return true
	if on:
		if not can_act():
			return false
		_saved_equipment = {
			"weapons": GameManager.weapon_slots.duplicate(), "slot": GameManager.active_weapon_slot,
			"accessories": GameManager.accessory_slots.duplicate(),
			"shield": GameManager.equipped_shield, "helmet": GameManager.equipped_helmet,
			"armor": GameManager.equipped_armor, "boots": GameManager.equipped_boots,
		}
		for item in get_gear():
			GameManager.add_item(item)
			GameManager.equip_item(item)
		GameManager.select_weapon_slot(GameManager.WeaponSlot.MELEE)
		GameManager.heal_full()
		GameManager.show_notice("[운영자] 운영자 장비 착용 — 날개 · 무적 · 즉사급 공격", AdminGear.COLOR)
	else:
		remove_admin_items()
	return true


## 가방 · 장비 칸의 운영자 장비를 모두 치우고 (운영자 장비를 입기 전의) 원래 장비로
func remove_admin_items() -> void:
	var saved := _saved_equipment
	var weapons: Array = saved.get("weapons", [])
	for i in GameManager.weapon_slots.size():
		var w := GameManager.weapon_slots[i]
		if w != null and w.admin_only:
			var before: WeaponData = weapons[i] if i < weapons.size() else null
			GameManager.weapon_slots[i] = before if before != null and GameManager.owns_item(before.id) else null
	var accessories: Array = saved.get("accessories", [])
	for i in GameManager.accessory_slots.size():
		var a = GameManager.accessory_slots[i]
		if a != null and a.admin_only:
			var before = accessories[i] if i < accessories.size() else null
			GameManager.accessory_slots[i] = before if before != null and GameManager.owns_item(before.id) else null
	for key in ["shield", "helmet", "armor", "boots"]:
		var current: ItemData = GameManager.get("equipped_" + key)
		if current != null and current.admin_only:
			var before: ItemData = saved.get(key)
			GameManager.set("equipped_" + key, before if before != null and GameManager.owns_item(before.id) else null)
	for item in GameManager.items.duplicate():
		if item.admin_only:
			GameManager.items.erase(item)
	var slot := int(saved.get("slot", GameManager.active_weapon_slot))
	if GameManager.weapon_slots[slot] == null:
		for i in GameManager.weapon_slots.size():
			if GameManager.weapon_slots[i] != null:
				slot = i
				break
	GameManager.equipped_weapon = null
	GameManager._set_active_weapon_slot(slot)
	GameManager.shield_equipped.emit(GameManager.equipped_shield)
	GameManager.helmet_equipped.emit(GameManager.equipped_helmet)
	GameManager.armor_equipped.emit(GameManager.equipped_armor)
	GameManager.boots_equipped.emit(GameManager.equipped_boots)
	GameManager._recalculate_stats()
	GameManager.hp = mini(GameManager.hp, GameManager.max_hp)
	GameManager.player_hp_changed.emit(GameManager.hp, GameManager.max_hp)
	GameManager.equipment_changed.emit()
	GameManager.inventory_changed.emit()
	_saved_equipment = {}


# ============================================================ 개발자 강림
## 강림 내용을 정리 (모르는 값 · 너무 긴 대사는 잘라냄) — 방장이 보낸 것도 참가자 쪽에서 다시 거름
static func sanitize(payload: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	for line in payload.get("lines", []):
		var text := String(line).strip_edges().left(MAX_LINE_CHARS)
		if text != "" and lines.size() < MAX_LINES:
			lines.append(text)
	var item_id := String(payload.get("item", ""))
	if item_id != "" and AdminGear.find(StringName(item_id)) == null:
		item_id = ""
	var at: Variant = payload.get("at", Vector2.ZERO)
	var raw_blessing: Variant = payload.get("blessing", {})
	var blessing := {}
	if raw_blessing is Dictionary:
		for key in BLESSING_STATS:
			blessing[key] = clampf(float((raw_blessing as Dictionary).get(key, 0.0)), 0.0, float(BLESSING_STATS[key][1]))
		blessing["time"] = clampf(float((raw_blessing as Dictionary).get("time", 60.0)), 1.0, BLESSING_MAX_TIME)
	return {
		"lines": lines,
		"heal": bool(payload.get("heal", false)),
		"invincible": bool(payload.get("invincible", false)),
		"shield_time": clampf(float(payload.get("shield_time", 15.0)), 1.0, BLESSING_MAX_TIME),
		"blessing": blessing,
		"gold": clampi(int(payload.get("gold", 0)), 0, MAX_GOLD),
		"item": item_id,
		"count": clampi(int(payload.get("count", 1)), 1, 99),
		"chat": bool(payload.get("chat", true)),
		"at": at if at is Vector2 else Vector2.ZERO,
	}


## 가호에 실제로 오르는 능력치가 있는지
static func has_blessing(blessing: Dictionary) -> bool:
	for key in BLESSING_STATS:
		if float(blessing.get(key, 0.0)) > 0.0:
			return true
	return false


## 가호 → GameManager 버프 효과 (백분율 → 비율)
static func blessing_effects(blessing: Dictionary) -> Dictionary:
	var effects := {}
	for key in BLESSING_STATS:
		var value := float(blessing.get(key, 0.0))
		if value > 0.0:
			effects[BLESSING_STATS[key][2]] = value / 100.0
	return effects


## 「공격력 +100% · 최대 체력 +50% …」
static func blessing_text(blessing: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in BLESSING_STATS:
		var value := float(blessing.get(key, 0.0))
		if value > 0.0:
			var label: String = BLESSING_STATS[key][0]
			parts.append("%s%s%%" % [label.trim_suffix("%"), str(snappedf(value, 0.1)).trim_suffix(".0")])
	return " · ".join(parts)


## 개발자 강림 (운영자 모드 · 방장만). 하늘에서 빛기둥 → 개발자 등장 → 대사 → 선물 · 버프 → 역 빛기둥으로 퇴장
func descend(payload: Dictionary = {}) -> bool:
	if not can_act() or descent_active:
		return false
	var me := _local_player()
	if me == null:
		return false
	var data := payload.duplicate() if not payload.is_empty() else preset.duplicate()
	data["at"] = me.global_position + Vector2(0, -34)
	data = sanitize(data)
	Net.admin_descent(data)  # 멀티플레이: 모든 참가자 화면에도 (같은 내용 · 같은 버프)
	play_descent(data)
	return true


## 참가자 쪽에서도 부르는 실제 연출 + 선물 (Net._admin_descent)
func play_descent(data: Dictionary) -> void:
	if descent_active:
		return
	descent_active = true
	Story.portraits[DEV_NAME] = DEV_TEXTURE
	var root := get_tree().current_scene
	if root == null:
		descent_active = false
		return
	var at: Vector2 = data["at"]
	var dev := _spawn_developer(root, at)
	await _pillar_down(root, at)
	if is_instance_valid(dev):
		var tween := dev.create_tween()
		tween.tween_property(dev, "modulate:a", 1.0, 0.35)
		tween.parallel().tween_property(dev, "scale", Vector2.ONE * DEV_SCALE, 0.35).from(Vector2(0.4, 3.0) * DEV_SCALE).set_trans(Tween.TRANS_BACK)
		await tween.finished
	if data.get("chat", true):
		for line in data["lines"]:
			Chat.add_message(DEV_NAME, String(line), Chat.Kind.ADMIN)  # 대사는 채팅창에도 남음
	var lines: Array = (data["lines"] as Array).map(func(t: String) -> Dictionary: return {"name": DEV_NAME, "face": DEV_NAME, "text": t})
	if not lines.is_empty() and Story.play_lines(lines, "admin_descent"):
		await Story.finished
	if not is_inside_tree():
		return
	apply_gifts(data)
	await _pillar_up(root, at, dev)
	descent_active = false
	descent_finished.emit()


## 선물 · 버프를 이 컴퓨터의 용사에게 (모든 참가자가 각자)
func apply_gifts(data: Dictionary) -> void:
	var got := PackedStringArray()
	if data.get("heal", false):
		if GameManager.is_player_dead and Net.is_online():
			Net._revive_local()
		GameManager.heal_full()
		got.append("체력 완전 회복")
	var blessing: Dictionary = data.get("blessing", {})
	if has_blessing(blessing):
		GameManager.add_buff(BLESSING_NAME, blessing_effects(blessing), float(blessing.get("time", 60.0)))
		if data.get("heal", false):
			GameManager.heal_full()  # 최대 체력이 늘었으면 늘어난 만큼까지
		got.append("%s %d초 (%s)" % [BLESSING_NAME, int(blessing.get("time", 60.0)), blessing_text(blessing)])
	if data.get("invincible", false):
		GameManager.add_buff(SHIELD_NAME, {"invincible": 1.0}, float(data.get("shield_time", 15.0)))
		got.append("%s %d초" % [SHIELD_NAME, int(data.get("shield_time", 15.0))])
	if int(data.get("gold", 0)) > 0:
		GameManager.add_gold(int(data["gold"]))
		got.append("%dG" % int(data["gold"]))
	var item := AdminGear.find(StringName(data.get("item", "")))
	if item != null:
		if item is PotionData:
			GameManager.add_potion(item as PotionData, int(data.get("count", 1)))
		elif item is RelicData:
			GameManager.add_relic(item as RelicData)
		else:
			GameManager.add_item(item)
		got.append(item.display_name)
	if not got.is_empty():
		GameManager.show_notice("[개발자의 선물] " + " · ".join(got), LIGHT)
		Chat.system("개발자의 선물: " + " · ".join(got))
	var me := _local_player()
	if me != null:
		_local_fx(func() -> void:
			Fx.explosion(me, me.global_position, LIGHT, 34.0, 2)
			Fx.pillar(me, me.global_position, LIGHT, 22.0, 90.0, 0.7))


func _local_player() -> Player:
	for p in Player.get_all(get_tree()):
		if p.is_local():
			return p
	return get_tree().get_first_node_in_group(&"player") as Player


## 각 참가자가 자기 화면에서 그리는 효과 (방장의 Fx 가 RPC 로 한 번 더 그려지지 않게)
func _local_fx(draw: Callable) -> void:
	Net.fx_muted = true
	draw.call()
	Net.fx_muted = false


func _spawn_developer(root: Node, at: Vector2) -> Sprite2D:
	var dev := Sprite2D.new()
	dev.name = "Developer"
	dev.texture = DEV_TEXTURE
	dev.offset = Vector2(0, -12)
	dev.z_index = 62
	dev.modulate = Color(1, 1, 1, 0)
	dev.scale = Vector2.ONE * DEV_SCALE
	dev.add_to_group(&"admin_developer")
	root.add_child(dev)
	dev.global_position = at
	var halo := Fx.make_aura(LIGHT, 12, 14.0, Vector2(0, -30), 0.9)
	halo.position = Vector2(0, -10)
	dev.add_child(halo)
	halo.emitting = true
	return dev


## 빛기둥 조각 (위가 하늘에 붙어 있고 아래로 늘어남)
func _make_beam(root: Node, at: Vector2, width: float, color: Color) -> Sprite2D:
	var beam := Sprite2D.new()
	beam.texture = Fx.GLOW_TEXTURE
	beam.material = Fx.additive_material()
	beam.modulate = color
	beam.z_index = 61
	beam.centered = false
	beam.offset = Vector2(-16, 0)
	root.add_child(beam)
	beam.global_position = at + Vector2(0, -PILLAR_HEIGHT)
	beam.scale = Vector2(width / 32.0, 0.0)
	return beam


## 등장: 하늘에서 빛기둥이 내리꽂힘 → 착지 섬광 · 충격파 · 화면 흔들림
func _pillar_down(root: Node, at: Vector2) -> void:
	Sfx.play(&"descent", 0.9)
	var beams: Array[Sprite2D] = [_make_beam(root, at, PILLAR_WIDTH, Color(1.0, 0.85, 0.45, 0.55)), _make_beam(root, at, PILLAR_WIDTH * 0.35, Color(1, 1, 1, 0.9))]
	var fall := 0.55
	var tween := root.create_tween().set_parallel(true)
	for beam in beams:
		tween.tween_property(beam, "scale:y", (PILLAR_HEIGHT + 12.0) / 32.0, fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	_impact(root, at, 1.0)
	_local_fx(func() -> void: Fx.burst(root, at + Vector2(0, -40), LIGHT, 40, 80.0, 1.2, Vector2(0, -60), 1.4))
	var fade := root.create_tween().set_parallel(true)
	for beam in beams:
		fade.tween_property(beam, "modulate:a", 0.0, 1.4).set_delay(0.5)
		fade.tween_property(beam, "scale:x", beam.scale.x * 0.3, 1.4).set_delay(0.5)
	fade.chain().tween_callback(func() -> void:
		for beam in beams:
			beam.queue_free())


## 퇴장: 발밑에서 빛기둥이 솟아 개발자를 감싸고, 개발자와 함께 하늘로 거두어짐 (역 빛기둥)
func _pillar_up(root: Node, at: Vector2, dev: Sprite2D) -> void:
	Sfx.play(&"ascend", 0.9)
	var beams: Array[Sprite2D] = [_make_beam(root, at, PILLAR_WIDTH, Color(1.0, 0.85, 0.45, 0.55)), _make_beam(root, at, PILLAR_WIDTH * 0.35, Color(1, 1, 1, 0.9))]
	for beam in beams:
		# 아래에서 위로 자라도록: 바닥에 붙이고 위로(음수) 늘림
		beam.global_position = at + Vector2(0, 12)
		beam.scale.y = 0.0
	var grow := root.create_tween().set_parallel(true)
	for beam in beams:
		grow.tween_property(beam, "scale:y", -(PILLAR_HEIGHT + 12.0) / 32.0, 0.4).set_ease(Tween.EASE_OUT)
	_impact(root, at, 0.6)
	await grow.finished
	if is_instance_valid(dev):
		var rise := dev.create_tween().set_parallel(true)
		rise.tween_property(dev, "global_position:y", at.y - PILLAR_HEIGHT * 0.8, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		rise.tween_property(dev, "scale", Vector2(0.4, 3.0) * DEV_SCALE, 0.9).set_ease(Tween.EASE_IN)
		rise.tween_property(dev, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
		await rise.finished
		dev.queue_free()
	# 기둥 아래 끝이 위로 거두어지며 사라짐
	var lift := root.create_tween().set_parallel(true)
	for beam in beams:
		lift.tween_property(beam, "global_position:y", at.y - PILLAR_HEIGHT, 0.45).set_ease(Tween.EASE_IN)
		lift.tween_property(beam, "scale:y", -0.1, 0.45).set_ease(Tween.EASE_IN)
	await lift.finished
	for beam in beams:
		beam.queue_free()
	_local_fx(func() -> void: Fx.cross_glint(root, at + Vector2(0, -PILLAR_HEIGHT * 0.6), Color(1, 1, 1), 60.0, 0.5))


func _impact(root: Node, at: Vector2, power: float) -> void:
	_local_fx(func() -> void:
		Fx.flash(root, at, Color(1, 1, 1, 0.5), 45.0 * power, 0.45)
		Fx.shockwave(root, at, LIGHT, 110.0 * power, 0.6)
		Fx.shockwave(root, at, Color(1, 1, 1), 60.0 * power, 0.4)
		Fx.burst(root, at, LIGHT, roundi(36 * power), 160.0, 0.6, Vector2.ZERO, 1.3))
	var me := _local_player()
	if me != null:
		me.shake_camera(6.0 * power)
