class_name StoryCues
extends RefCounted
## 대본의 @연출 장면들. 대화창이 떠 있는 동안(게임 일시정지) 에도 움직이도록 PROCESS_MODE_ALWAYS 로 만듭니다.
##   장비빛남 : 용사가 금빛으로 빛나고, 보스들에게 받은 신화 장비들이 용사 둘레에 떠올라 빛나며 돎 (100스테이지 보스 토벌)
##   각성     : 보스(없으면 용사) 자리에서 빛 기둥 · 충격파 · 번쩍임
##   하늘에서떨어짐 : 용사가 하늘에서 떨어져 쿵 — 먼지 · 잠깐 쓰러져 있다 일어남 (새 게임 첫 장면)
##   선물     : 상인 쪽에서 용사의 시작 장비가 떠올라 용사에게 날아감
##   도전자의흔적 : 용사 곁에 녹슨 성기사 갑옷과 낡은 일지가 놓여 있음 (이전 도전자의 일지 구간)
## 대사를 잠깐 멈추고 장면을 먼저 보여 줘야 하는 것은 WAIT 에 시간(초)

const GLOW_TIME := 3.6
const FALL_TIME := 0.9
## 장면이 끝날 때까지 대화창을 숨기고 기다리는 시간
const WAIT := {"하늘에서떨어짐": 1.9, "선물": 1.5}
const RELIC_TEXTURE := preload("res://assets/sprites/armors/knight_armor.png")


static func wait_time(cue_name: String) -> float:
	return float(WAIT.get(cue_name, 0.0))


static func run(cue_name: String, tree: SceneTree) -> Node2D:
	var manager := tree.get_first_node_in_group(&"stage_manager") as StageManager
	if manager == null or manager.player == null:
		return null
	match cue_name:
		"장비빛남":
			return equipment_glow(manager.player)
		"각성":
			var boss := manager.get_boss()
			var target: Node2D = boss if boss != null else manager.player
			awaken_burst(target, Color(1.0, 0.45, 0.9))
			return target
		"하늘에서떨어짐":
			return fall_from_sky(manager.player)
		"선물":
			return merchant_gift(manager)
		"도전자의흔적":
			return challenger_relic(manager.player)
	return null


## 용사가 하늘에서 떨어짐: 몸(그림)만 위에서 떨어뜨리고, 그림자는 점점 커짐 → 쿵 · 먼지 · 흔들림 → 옆으로 누웠다가 일어남
static func fall_from_sky(player: Player) -> Node2D:
	var body := player.get_node_or_null(^"BodySprite") as Node2D
	var weapon := player.get_node_or_null(^"WeaponPivot") as Node2D
	var shadow := player.get_node_or_null(^"Shadow") as Node2D
	if body == null:
		return player
	var body_base := body.position
	var weapon_base := weapon.position if weapon != null else Vector2.ZERO
	var shadow_scale := shadow.scale if shadow != null else Vector2.ONE
	const HEIGHT := 260.0
	body.position = body_base + Vector2(0, -HEIGHT)
	if weapon != null:
		weapon.visible = false
	if shadow != null:
		shadow.scale = shadow_scale * 0.2
	var t := player.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(body, "position", body_base, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if shadow != null:
		t.parallel().tween_property(shadow, "scale", shadow_scale, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		body.rotation = PI / 2.0  # 쓰러짐
		_land_dust(player)
		Sfx.play_local(&"boss_hit"))
	t.tween_interval(0.6)
	t.tween_property(body, "rotation", 0.0, 0.25)
	t.tween_callback(func() -> void:
		if weapon != null:
			weapon.position = weapon_base
			weapon.visible = true)
	return player


static func _land_dust(player: Node2D) -> void:
	var at := player.global_position + Vector2(0, 4)
	for i in 2:
		var ring := _always_sprite(player, Fx.RING_TEXTURE, at, Color(0.85, 0.8, 0.7, 0.8))
		ring.scale = Vector2(0.3, 0.12)
		var t := ring.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		t.tween_property(ring, "scale", Vector2(5.0 + i * 2.0, 1.8 + i), 0.5).set_delay(i * 0.1).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.5).set_delay(i * 0.1)
		t.chain().tween_callback(ring.queue_free)


## 상인이 주는 시작 장비: 상인 머리 위에서 장비 그림이 떠올라 용사에게 날아가 반짝임
static func merchant_gift(manager: StageManager) -> Node2D:
	var player := manager.player
	var merchant: Node2D = null
	for node in manager.entities_root.find_children("*", "ShopKeeper", true, false):
		merchant = node as Node2D
		break
	var from := (merchant.global_position if merchant != null else player.global_position + Vector2(60, -20)) + Vector2(0, -26)
	var icons: Array[Texture2D] = []
	for item in [GameManager.equipped_weapon, GameManager.equipped_shield]:
		if item != null and (item as ItemData).icon != null:
			icons.append((item as ItemData).icon)
	var i := 0
	for tex in icons:
		var s := Sprite2D.new()
		s.texture = tex
		s.z_index = 60
		s.process_mode = Node.PROCESS_MODE_ALWAYS
		player.get_parent().add_child(s)
		s.global_position = from
		s.scale = Vector2.ONE * 0.2
		var to := player.global_position + Vector2(-8 + i * 16, -14)
		var t := s.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_interval(i * 0.15)
		t.tween_property(s, "scale", Vector2.ONE * 1.3, 0.3).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "global_position", from + Vector2(0, -18), 0.25)
		t.tween_property(s, "global_position", to, 0.45).set_trans(Tween.TRANS_SINE)
		t.tween_callback(func() -> void:
			awaken_burst(player, Color(1.0, 0.9, 0.5)))
		t.tween_property(s, "modulate:a", 0.0, 0.3)
		t.tween_callback(s.queue_free)
		i += 1
	return player


## 이전 도전자의 흔적: 녹슨 성기사 갑옷과 낡은 일지 (잠시 뒤 흐려짐)
static func challenger_relic(player: Node2D) -> Node2D:
	var relic := ChallengerRelic.new()
	player.get_parent().add_child(relic)
	relic.global_position = player.global_position + Vector2(34, 10)
	return relic


## 빛나는 장비 그림 — 10스테이지마다 보스에게 받은 신화 장비 (없으면 지금 장착한 장비)
static func equipment_icons() -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
	for item in GameManager.get_mythic_items():
		if item.icon != null:
			icons.append(item.icon)
	if not icons.is_empty():
		return icons
	var gear: Array = []
	gear.append_array(GameManager.weapon_slots)
	gear.append_array([GameManager.equipped_shield, GameManager.equipped_helmet, GameManager.equipped_armor, GameManager.equipped_boots])
	gear.append_array(GameManager.accessory_slots)
	for item in gear:
		if item != null and (item as ItemData).icon != null:
			icons.append((item as ItemData).icon)
	return icons


static func equipment_glow(player: Node2D) -> Node2D:
	var glow := EquipmentGlow.new()
	glow.icons = equipment_icons()
	player.add_child(glow)
	return glow


static func awaken_burst(target: Node2D, color: Color) -> void:
	var at := target.global_position + Vector2(0, -20)
	for i in 3:
		var ring := _always_sprite(target, Fx.RING_TEXTURE, at, color)
		ring.scale = Vector2.ONE * 0.1
		var t := ring.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		t.tween_property(ring, "scale", Vector2.ONE * (14.0 + i * 4.0), 0.9).set_delay(i * 0.18).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.9).set_delay(i * 0.18)
		t.chain().tween_callback(ring.queue_free)
	var flash := _always_sprite(target, Fx.GLOW_TEXTURE, at, Color(1.0, 0.85, 1.0))
	flash.scale = Vector2.ONE * 3.0
	var f := flash.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	f.tween_property(flash, "scale", Vector2.ONE * 16.0, 0.6)
	f.tween_property(flash, "modulate:a", 0.0, 0.6)
	f.chain().tween_callback(flash.queue_free)


static func _always_sprite(context: Node, texture: Texture2D, at: Vector2, color: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.material = Fx.additive_material()
	s.z_index = 60
	s.modulate = color
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	var root := context.get_parent() if context.get_parent() != null else context
	root.add_child(s)
	s.global_position = at
	return s


## 용사 둘레에 장비가 떠올라 빛나며 도는 장면
class EquipmentGlow extends Node2D:
	var icons: Array[Texture2D] = []
	var _time: float = 0.0
	var _sprites: Array[Sprite2D] = []
	var _halo: Sprite2D

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		z_index = 60
		position = Vector2(0, -12)
		_halo = Sprite2D.new()
		_halo.texture = Fx.GLOW_TEXTURE
		_halo.material = Fx.additive_material()
		_halo.modulate = Color(1.0, 0.85, 0.35, 0.0)
		add_child(_halo)
		for tex in icons:
			var s := Sprite2D.new()
			s.texture = tex
			s.modulate = Color(1, 1, 1, 0)
			s.scale = Vector2.ONE * 1.4
			add_child(s)
			_sprites.append(s)

	func _process(delta: float) -> void:
		_time += delta
		var appear := clampf(_time / 0.6, 0.0, 1.0)
		var fade := clampf((StoryCues.GLOW_TIME - _time) / 0.8, 0.0, 1.0)
		var a := appear * fade
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		_halo.scale = Vector2.ONE * (5.0 + pulse * 1.2)
		_halo.modulate.a = a * (0.55 + 0.3 * pulse)
		var parent := get_parent() as CanvasItem
		if parent != null:
			parent.modulate = Color.WHITE.lerp(Color(1.6, 1.4, 0.8), a * (0.5 + 0.5 * pulse))
		var n := maxi(_sprites.size(), 1)
		var radius := 10.0 + 26.0 * appear
		for i in _sprites.size():
			var ang := _time * 1.6 + TAU * i / n
			var s := _sprites[i]
			s.position = Vector2(cos(ang), sin(ang) * 0.6) * radius + Vector2(0, -6.0 * appear)
			s.modulate = Color(1.0 + pulse * 0.6, 1.0 + pulse * 0.5, 0.8, a)
		queue_redraw()
		if _time >= StoryCues.GLOW_TIME:
			if parent != null:
				parent.modulate = Color.WHITE
			queue_free()

	func _draw() -> void:
		var a := clampf(_time / 0.6, 0.0, 1.0) * clampf((StoryCues.GLOW_TIME - _time) / 0.8, 0.0, 1.0)
		for k in 3:
			var r := fmod(_time * 26.0 + k * 13.0, 40.0)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, a * (1.0 - r / 40.0)), 1.5)
		# 위로 떠오르는 금빛 반짝이 (일시정지 중에도 움직이도록 직접 그림)
		for k in 14:
			var life := fmod(_time * 0.9 + k * 0.37, 1.0)
			var x := sin(k * 12.9898) * 24.0
			var p := Vector2(x, 14.0 - life * 46.0)
			var c := Color(1.0, 0.92, 0.55, a * (1.0 - life))
			draw_rect(Rect2(p - Vector2(0.5, 1.5), Vector2(1, 3)), c)
			draw_rect(Rect2(p - Vector2(1.5, 0.5), Vector2(3, 1)), c)


## 녹슨 갑옷 + 낡은 일지 (일시정지 중에도 그려지고, 대화가 끝나고 얼마 뒤 흐려짐)
class ChallengerRelic extends Node2D:
	const LIFE := 14.0
	var _time: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		z_index = -2
		var armor := Sprite2D.new()
		armor.texture = StoryCues.RELIC_TEXTURE
		armor.modulate = Color(0.62, 0.45, 0.32)
		armor.rotation = -0.35
		armor.position = Vector2(0, -6)
		add_child(armor)

	func _process(delta: float) -> void:
		_time += delta
		modulate.a = clampf((LIFE - _time) / 2.0, 0.0, 1.0)
		queue_redraw()
		if _time >= LIFE:
			queue_free()

	func _draw() -> void:
		draw_circle(Vector2(0, 2), 9.0, Color(0, 0, 0, 0.25))
		# 낡은 일지
		draw_rect(Rect2(10, -2, 9, 7), Color(0.42, 0.28, 0.16))
		draw_rect(Rect2(10, -2, 9, 7), Color(0.12, 0.08, 0.04), false, 1.0)
		draw_line(Vector2(14.5, -2), Vector2(14.5, 5), Color(0.78, 0.7, 0.5), 1.0)
		var glow := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(Vector2(14.5, 1.5), 8.0, Color(1.0, 0.85, 0.5, 0.08 + 0.06 * glow))
