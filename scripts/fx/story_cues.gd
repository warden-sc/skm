class_name StoryCues
extends RefCounted
## 대본의 @연출 장면들. 대화창이 떠 있는 동안(게임 일시정지) 에도 움직이도록 PROCESS_MODE_ALWAYS 로 만듭니다.
##   장비빛남 : 용사가 금빛으로 빛나고, 가진 장비들이 용사 둘레에 떠올라 빛나며 돎 (100스테이지 보스 토벌)
##   각성     : 보스(없으면 용사) 자리에서 빛 기둥 · 충격파 · 번쩍임

const GLOW_TIME := 3.6


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
	return null


## 지금 가진 장비 그림 (손에 든 무기 칸 · 방어구 · 장신구)
static func equipment_icons() -> Array[Texture2D]:
	var icons: Array[Texture2D] = []
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
