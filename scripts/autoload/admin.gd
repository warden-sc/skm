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
##   권한이 없으면 단축키를 눌러도 아무 일도 일어나지 않고(알림도 없음) 운영자 UI 는 만들어지지도 않음.
##   키를 바꾸려면 python3 tools/make_admin_key.py → 나온 해시를 ADMIN_KEY_SHA256 에.
##
## [사용] 게임은 항상 일반 플레이어 모드로 시작. 저장되지 않음.
##   Ctrl + Shift + A : 운영자 모드 켜기 / 끄기 (켜지면 화면 왼쪽 아래 작은 「ADMIN MODE」)
##   F11              : 운영자 패널 (운영자 모드일 때만) — 스테이지 이동 · 보스문 열기 · 운영자 장비 · 강림 이벤트
##   Ctrl + Shift + D : 개발자 강림 (패널에 적어 둔 대사 · 선물로 바로)
##   멀티플레이에서는 방장만 쓸 수 있고, 강림 이벤트는 RPC 로 모든 참가자 화면 · 버프에 똑같이 적용.
##   운영자 모드가 켜져 있는 동안에는 업적이 달성되지 않음.

signal mode_changed(on: bool)
signal descent_finished

const ADMIN_KEY_SHA256 := "e6ef828eb4f2b1e6fca252c27803f017642ee40011ac14de3ecc76ff149ad82c"
## 개발자 스팀 ID(64비트 숫자). 스팀판에서 이 계정이면 키 없이도 권한 (빌드 조건은 그대로)
const DEV_STEAM_IDS: Array[int] = []
const ENV_KEY := "CRUSADER_ADMIN_KEY"
const KEY_FILE := "user://admin.key"
const BUILD_FEATURE := "admin_build"

const DEV_NAME := "개발자"
const DEV_TEXTURE: Texture2D = preload("res://assets/sprites/characters/developer.png")
const DEV_SCALE := 2.0
const LIGHT := Color(1.0, 0.92, 0.6)
const PILLAR_HEIGHT := 420.0
const PILLAR_WIDTH := 46.0

## 운영자 장비: [id, 이름, 바탕이 될 신화 무기, 그림, 손에 든 그림]
const GEAR_SPECS := [
	[&"admin_sword", "운영자의 검", &"abaddon_sword", "res://assets/sprites/weapons/admin_sword.png", ""],
	[&"admin_bow", "운영자의 활", &"apollo_bow", "res://assets/sprites/weapons/admin_bow.png", "res://assets/sprites/weapons/admin_bow_held.png"],
	[&"admin_staff", "운영자의 지팡이", &"archmage_staff", "res://assets/sprites/weapons/admin_staff.png", ""],
]
const GEAR_DAMAGE := 99999999

## 강림 이벤트 선물 (한 번에 여러 개)
const BUFF_ATTACK := {"name": "개발자의 축복", "effects": {"attack": 1.0}, "time": 60.0}
const BUFF_GUARD := {"name": "개발자의 가호", "effects": {"reduction": 0.5}, "time": 60.0}
const BUFF_SHIELD := {"name": "개발자의 보호막", "effects": {"invincible": 1.0}, "time": 15.0}
const MAX_LINES := 6
const MAX_LINE_CHARS := 160
const MAX_GOLD := 100000000

## 운영자 키의 SHA-256 (자동 테스트는 시험용 키로 바꿔 씀 — 그래도 빌드 조건은 그대로)
var key_hash: String = ADMIN_KEY_SHA256
var authorized: bool = false
## 권한을 준 것: "env" · "file" · "steam" (없으면 "")
var auth_source: String = ""
var enabled: bool = false
## 운영자 장비 착용 중 — 무적
var god: bool = false
var descent_active: bool = false
## 패널에 적어 둔 다음 강림 내용 (Ctrl+Shift+D 도 이것으로)
var preset: Dictionary = {
	"lines": ["용사여, 잠시 손을 빌려주지.", "이 축복으로 다시 일어서라!"],
	"heal": true, "attack": true, "guard": false, "invincible": true, "gold": 0, "item": "", "count": 1,
}

var _layer: CanvasLayer
var _badge: Label
var _panel: Control
var _gear: Array[WeaponData] = []
var _saved_weapons: Array = []
var _saved_slot: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_authorization()


# ============================================================ 권한
## 이 빌드에서 운영자 기능이 들어갈 수 있는지 (에디터 실행 · 운영자 빌드만)
static func is_build_allowed() -> bool:
	return OS.has_feature("editor") or OS.has_feature(BUILD_FEATURE)


func key_matches(key: String) -> bool:
	key = key.strip_edges()
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
		authorized = auth_source != ""
	if not authorized:
		set_enabled(false)
		if _layer != null:
			_layer.queue_free()
			_layer = null
			_badge = null
			_panel = null
	set_process_input(authorized)


func _steam_id_allowed() -> bool:
	if DEV_STEAM_IDS.is_empty() or not Engine.has_singleton(&"Steam"):
		return false
	var steam_id := int(Engine.get_singleton(&"Steam").call(&"getSteamID"))
	return DEV_STEAM_IDS.has(steam_id)


## 지금 운영자 기능을 쓸 수 있는지 (멀티플레이 참가자는 안 됨 — 방장만)
func can_act() -> bool:
	return authorized and enabled and not Net.is_client()


# ============================================================ 모드
func _input(event: InputEvent) -> void:
	if not authorized:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var combo := key.ctrl_pressed and key.shift_pressed
	if combo and key.keycode == KEY_A:
		set_enabled(not enabled)
	elif enabled and key.keycode == KEY_F11:
		toggle_panel()
	elif enabled and combo and key.keycode == KEY_D:
		descend(preset)
	else:
		return
	get_viewport().set_input_as_handled()


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
## 운영자의 검 · 활 · 지팡이 (신화 무기를 바탕으로, 공격력 즉사급 · 치명타 100% · 방어 관통). 저장 · 판매 · 버리기 불가
func get_gear() -> Array[WeaponData]:
	if _gear.is_empty():
		for spec in GEAR_SPECS:
			var base := ItemDB.get_weapon(spec[2])
			if base == null:
				continue
			var weapon := base.duplicate() as WeaponData
			weapon.id = spec[0]
			weapon.display_name = spec[1]
			weapon.description = "운영자 전용 — 즉사급 공격력, 들고 있는 동안 무적. 저장 · 판매 · 버리기 불가"
			weapon.icon = load(spec[3]) as Texture2D
			if spec[4] != "":
				weapon.held_texture = load(spec[4]) as Texture2D
			weapon.damage = GEAR_DAMAGE
			weapon.crit_chance = 1.0
			weapon.armor_pen = 999999
			weapon.effect_color = LIGHT
			weapon.set_id = &""
			weapon.price = 0
			weapon.in_shop = false
			weapon.admin_only = true
			_gear.append(weapon)
	return _gear


## 운영자 장비 착용(무적 + 즉사급 무기) / 벗기(원래 무기로)
func set_gear(on: bool) -> bool:
	if on == god:
		return true
	if on:
		if not can_act():
			return false
		_saved_weapons = GameManager.weapon_slots.duplicate()
		_saved_slot = GameManager.active_weapon_slot
		for weapon in get_gear():
			GameManager.add_item(weapon)
			GameManager.equip_item(weapon)
		GameManager.select_weapon_slot(GameManager.WeaponSlot.MELEE)
		god = true
		GameManager.show_notice("[운영자] 운영자 장비 착용 — 무적 · 즉사급 공격", LIGHT)
	else:
		god = false
		for i in GameManager.weapon_slots.size():
			var before: WeaponData = _saved_weapons[i] if i < _saved_weapons.size() else null
			GameManager.weapon_slots[i] = before if before != null and GameManager.owns_item(before.id) else null
		for weapon in get_gear():
			GameManager.items.erase(weapon)
		var slot := _saved_slot
		if GameManager.weapon_slots[slot] == null:
			for i in GameManager.weapon_slots.size():
				if GameManager.weapon_slots[i] != null:
					slot = i
					break
		GameManager.equipped_weapon = null
		GameManager._set_active_weapon_slot(slot)
		GameManager._recalculate_stats()
		GameManager.equipment_changed.emit()
		GameManager.inventory_changed.emit()
	return true


# ============================================================ 개발자 강림
## 강림 내용을 정리 (모르는 값 · 너무 긴 대사는 잘라냄) — 방장이 보낸 것도 참가자 쪽에서 다시 거름
static func sanitize(payload: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	for line in payload.get("lines", []):
		var text := String(line).strip_edges().left(MAX_LINE_CHARS)
		if text != "" and lines.size() < MAX_LINES:
			lines.append(text)
	var item_id := String(payload.get("item", ""))
	if item_id != "" and (not ItemDB.has_item(StringName(item_id)) or ItemDB.get_item(StringName(item_id)).admin_only):
		item_id = ""
	var at: Variant = payload.get("at", Vector2.ZERO)
	return {
		"lines": lines,
		"heal": bool(payload.get("heal", false)),
		"attack": bool(payload.get("attack", false)),
		"guard": bool(payload.get("guard", false)),
		"invincible": bool(payload.get("invincible", false)),
		"gold": clampi(int(payload.get("gold", 0)), 0, MAX_GOLD),
		"item": item_id,
		"count": clampi(int(payload.get("count", 1)), 1, 99),
		"at": at if at is Vector2 else Vector2.ZERO,
	}


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
	for pair in [["attack", BUFF_ATTACK], ["guard", BUFF_GUARD], ["invincible", BUFF_SHIELD]]:
		if data.get(pair[0], false):
			var buff: Dictionary = pair[1]
			GameManager.add_buff(buff["name"], buff["effects"], buff["time"])
			got.append("%s %d초" % [buff["name"], int(buff["time"])])
	if int(data.get("gold", 0)) > 0:
		GameManager.add_gold(int(data["gold"]))
		got.append("%dG" % int(data["gold"]))
	var item_id := StringName(data.get("item", ""))
	if item_id != &"" and ItemDB.has_item(item_id):
		var item := ItemDB.get_item(item_id)
		if item is PotionData:
			GameManager.add_potion(item as PotionData, int(data.get("count", 1)))
		elif item is RelicData:
			GameManager.add_relic(item as RelicData)
		else:
			GameManager.add_item(item)
		got.append(item.display_name)
	if not got.is_empty():
		GameManager.show_notice("[개발자의 선물] " + " · ".join(got), LIGHT)
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
	var beams: Array[Sprite2D] = [_make_beam(root, at, PILLAR_WIDTH, Color(1.0, 0.85, 0.45, 0.9)), _make_beam(root, at, PILLAR_WIDTH * 0.4, Color(1, 1, 1, 1))]
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
	var beams: Array[Sprite2D] = [_make_beam(root, at, PILLAR_WIDTH, Color(1.0, 0.85, 0.45, 0.9)), _make_beam(root, at, PILLAR_WIDTH * 0.4, Color(1, 1, 1, 1))]
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
		Fx.flash(root, at, Color(1, 1, 1), 70.0 * power, 0.5)
		Fx.shockwave(root, at, LIGHT, 110.0 * power, 0.6)
		Fx.shockwave(root, at, Color(1, 1, 1), 60.0 * power, 0.4)
		Fx.burst(root, at, LIGHT, roundi(36 * power), 160.0, 0.6, Vector2.ZERO, 1.3))
	var me := _local_player()
	if me != null:
		me.shake_camera(6.0 * power)
