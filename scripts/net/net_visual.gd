class_name NetVisual
## 멀티플레이 화면 복제: 노드(와 그 자식들)의 「보이는 상태」를 바이트로 적고(capture), 다른 컴퓨터의 복제본에 그대로 입힘(apply).
##
## 방장 → 참가자: 몬스터 · 보스 · 탄 · 장판 · 줍는 아이템 · 남의 용사 등 화면에 보이는 모든 것
## 참가자 → 방장: 자기 용사의 모습 (방장 컴퓨터의 PUPPET 에 입혀지고, 다시 다른 참가자에게 복제됨)
##
## 노드마다: 위치 · 회전 · 크기 · 색 · 표시 여부 · z, 그리고 종류별로 텍스처 · 프레임 · 선/다각형 점 · 글자 등.
## 스크립트에 _draw() 가 있는 노드(장판 · 예고 원 등)는 스크립트 변수도 함께 보내서 같은 그림이 그려지게 합니다.
## 텍스처 같은 경로 문자열은 번호로 바꿔 보내고(intern), 번호표는 따로 한 번만 보냄.

enum Cls { NODE2D, SPRITE, ANIM_SPRITE, LINE, POLYGON, LABEL, PARTICLES, CONTROL }

const MAX_NODES := 64
const MAX_VARS_BYTES := 1500
const ROOT := 255

const F_VISIBLE := 1
const F_FLIP_H := 2
const F_FLIP_V := 4
const F_VARS := 8
const F_REGION := 16
const F_CENTERED := 32
const F_MOD_WHITE := 64
const F_SELF_WHITE := 128

## 스크립트별로 보낼 변수 이름 (스크립트 경로 → Array[String])
static var _var_cache: Dictionary = {}
## 클래스별로 꼭 보낼 변수 (그림은 안 그리지만 참가자 쪽에서 필요한 값)
const CLASS_VARS := {
	"Enemy": ["hp", "max_hp", "airborne", "immune_text", "display_name", "is_boss"],
	"Interactable": ["prompt_text", "enabled"],
}


# ============================================================ 적기
## node 와 자식들을 buf 에 적음. intern: Callable(String) -> int (0 = 없음)
static func capture(node: Node, buf: StreamPeerBuffer, intern: Callable, use_global_root: bool = true) -> void:
	var list: Array = []  # [node, parent_ord, child_idx]
	_collect(node, ROOT, 0, list)
	buf.put_u8(list.size())
	for i in list.size():
		var entry: Array = list[i]
		_write_node(entry[0], entry[1], entry[2], buf, intern, i == 0 and use_global_root)


static func _collect(node: Node, parent_ord: int, child_idx: int, list: Array) -> void:
	if list.size() >= MAX_NODES:
		return
	if not (node is CanvasItem) or node is CollisionShape2D or node is CollisionPolygon2D or node is Camera2D or node is Marker2D or node.has_meta(&"net_skip"):
		return
	var ord := list.size()
	list.append([node, parent_ord, child_idx])
	if node is CPUParticles2D or not (node as CanvasItem).visible:
		return  # 숨은 노드는 「숨음」만 보내고 자식은 생략
	var children := node.get_children()
	for i in children.size():
		_collect(children[i], ord, i, list)


static func class_of(node: Node) -> Cls:
	if node is Sprite2D:
		return Cls.SPRITE
	if node is AnimatedSprite2D:
		return Cls.ANIM_SPRITE
	if node is Line2D:
		return Cls.LINE
	if node is Polygon2D:
		return Cls.POLYGON
	if node is Label:
		return Cls.LABEL
	if node is CPUParticles2D:
		return Cls.PARTICLES
	if node is Control:
		return Cls.CONTROL
	return Cls.NODE2D


static func _write_node(node: CanvasItem, parent_ord: int, child_idx: int, buf: StreamPeerBuffer, intern: Callable, global_root: bool) -> void:
	var cls := class_of(node)
	var flags := 0
	if node.visible:
		flags |= F_VISIBLE
	if node.modulate == Color.WHITE:
		flags |= F_MOD_WHITE
	if node.self_modulate == Color.WHITE:
		flags |= F_SELF_WHITE
	var var_bytes := PackedByteArray()
	if node.get_script() != null and node.visible:
		var values := script_values(node)
		if not values.is_empty():
			var_bytes = var_to_bytes(values)
			if var_bytes.size() <= MAX_VARS_BYTES:
				flags |= F_VARS
	match cls:
		Cls.SPRITE:
			var s := node as Sprite2D
			if s.flip_h:
				flags |= F_FLIP_H
			if s.flip_v:
				flags |= F_FLIP_V
			if s.region_enabled:
				flags |= F_REGION
			if s.centered:
				flags |= F_CENTERED
		Cls.ANIM_SPRITE:
			var a := node as AnimatedSprite2D
			if a.flip_h:
				flags |= F_FLIP_H
			if a.flip_v:
				flags |= F_FLIP_V
	buf.put_u8(parent_ord)
	buf.put_u16(child_idx)
	buf.put_u8(cls)
	buf.put_u8(flags)
	if node is Node2D:
		var n2 := node as Node2D
		if global_root:
			buf.put_float(n2.global_position.x)
			buf.put_float(n2.global_position.y)
		else:
			buf.put_half(n2.position.x)
			buf.put_half(n2.position.y)
		buf.put_half(n2.rotation)
		buf.put_half(n2.scale.x)
		buf.put_half(n2.scale.y)
		buf.put_16(n2.z_index)
	else:
		var c := node as Control
		if global_root:
			buf.put_float(c.position.x)
			buf.put_float(c.position.y)
		else:
			buf.put_half(c.position.x)
			buf.put_half(c.position.y)
		buf.put_half(c.rotation)
		buf.put_half(c.size.x)
		buf.put_half(c.size.y)
		buf.put_16(0)
	if not flags & F_MOD_WHITE:
		_put_color(buf, node.modulate)
	if not flags & F_SELF_WHITE:
		_put_color(buf, node.self_modulate)
	match cls:
		Cls.SPRITE:
			var s := node as Sprite2D
			buf.put_u16(_res_id(s.texture, intern))
			buf.put_u8(s.hframes)
			buf.put_u8(s.vframes)
			buf.put_u16(s.frame)
			buf.put_half(s.offset.x)
			buf.put_half(s.offset.y)
			if s.region_enabled:
				buf.put_float(s.region_rect.position.x)
				buf.put_float(s.region_rect.position.y)
				buf.put_float(s.region_rect.size.x)
				buf.put_float(s.region_rect.size.y)
		Cls.ANIM_SPRITE:
			var a := node as AnimatedSprite2D
			buf.put_u16(_res_id(a.sprite_frames, intern))
			buf.put_u16(intern.call(String(a.animation)))
			buf.put_u16(a.frame)
			buf.put_half(a.offset.x)
			buf.put_half(a.offset.y)
		Cls.LINE:
			var l := node as Line2D
			buf.put_half(l.width)
			_put_color(buf, l.default_color)
			_put_points(buf, l.points)
		Cls.POLYGON:
			var p := node as Polygon2D
			_put_color(buf, p.color)
			buf.put_u16(_res_id(p.texture, intern))
			_put_points(buf, p.polygon)
		Cls.LABEL:
			var lb := node as Label
			buf.put_utf8_string(lb.text)
			var settings := lb.label_settings
			var font_color: Color = settings.font_color if settings != null else lb.get_theme_color(&"font_color")
			var outline_color: Color = settings.outline_color if settings != null else lb.get_theme_color(&"font_outline_color")
			_put_color(buf, font_color)
			_put_color(buf, outline_color)
			buf.put_u8(clampi(settings.font_size if settings != null else lb.get_theme_font_size(&"font_size"), 0, 255))
			buf.put_u8(clampi(settings.outline_size if settings != null else lb.get_theme_constant(&"outline_size"), 0, 255))
			buf.put_u8(lb.horizontal_alignment)
			buf.put_half(lb.size.x)
			buf.put_half(lb.size.y)
		Cls.PARTICLES:
			buf.put_u8(1 if (node as CPUParticles2D).emitting else 0)
		Cls.CONTROL:
			buf.put_u8(1 if node is ColorRect else 0)
			if node is ColorRect:
				_put_color(buf, (node as ColorRect).color)
	if flags & F_VARS:
		buf.put_u16(var_bytes.size())
		buf.put_data(var_bytes)


static func _res_id(res: Resource, intern: Callable) -> int:
	if res == null or res.resource_path == "" or res.resource_path.contains("::"):
		return 0
	return intern.call(res.resource_path)


static func _put_color(buf: StreamPeerBuffer, c: Color) -> void:
	buf.put_half(c.r)
	buf.put_half(c.g)
	buf.put_half(c.b)
	buf.put_half(c.a)


static func _get_color(buf: StreamPeerBuffer) -> Color:
	return Color(buf.get_half(), buf.get_half(), buf.get_half(), buf.get_half())


static func _put_points(buf: StreamPeerBuffer, points: PackedVector2Array) -> void:
	var n := mini(points.size(), 255)
	buf.put_u8(n)
	for i in n:
		buf.put_float(points[i].x)
		buf.put_float(points[i].y)


static func _get_points(buf: StreamPeerBuffer) -> PackedVector2Array:
	var n := buf.get_u8()
	var points := PackedVector2Array()
	points.resize(n)
	for i in n:
		points[i] = Vector2(buf.get_float(), buf.get_float())
	return points


# ============================================================ 스크립트 변수
## 이 노드에서 보낼 스크립트 변수 값들 (이름 순서는 script_var_names)
static func script_values(node: Object) -> Array:
	var names := script_var_names(node)
	var values: Array = []
	for name in names:
		var v: Variant = node.get(name)
		values.append(_plain(v))
	return values


## 객체가 섞인 값은 보내지 않음 (null 로)
static func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return null
		TYPE_ARRAY:
			var arr: Array = v
			if arr.size() > 64:
				return null
			for e in arr:
				if typeof(e) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID, TYPE_ARRAY, TYPE_DICTIONARY]:
					return null
			return arr
		TYPE_DICTIONARY:
			return null
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return v if v.size() <= 128 else null
	return v


const _OK_TYPES := [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_COLOR,
	TYPE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_COLOR_ARRAY]


## 보낼 변수 이름: 그림을 직접 그리는(_draw) 스크립트는 단순 값 변수 전부, 아니면 CLASS_VARS 에 정한 것만
static func script_var_names(node: Object) -> Array:
	var script := node.get_script() as Script
	if script == null:
		return []
	var key := script.resource_path
	if _var_cache.has(key):
		return _var_cache[key]
	var names: Array = []
	var draws := _script_defines(script, &"_draw")
	if draws:
		for prop in node.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["type"] in _OK_TYPES:
				if prop["type"] == TYPE_ARRAY:
					var cur: Variant = node.get(prop["name"])
					if cur is Array and (cur as Array).get_typed_builtin() == TYPE_OBJECT:
						continue  # 노드 목록 같은 배열은 못 보냄
				names.append(prop["name"])
	for cls_name in CLASS_VARS:
		if _is_class(node, cls_name):
			for n in CLASS_VARS[cls_name]:
				if not names.has(n):
					names.append(n)
	_var_cache[key] = names
	return names


static func _script_defines(script: Script, method: StringName) -> bool:
	for m in script.get_script_method_list():
		if m["name"] == method:
			return true
	return false


static func _is_class(node: Object, cls_name: String) -> bool:
	match cls_name:
		"Enemy":
			return node is Enemy
		"Interactable":
			return node is Interactable
	return false


static func _apply_vars(node: Object, values: Array) -> void:
	var names := script_var_names(node)
	if names.size() != values.size():
		return
	for i in names.size():
		var v: Variant = values[i]
		if v == null:
			continue
		var cur: Variant = node.get(names[i])
		if typeof(cur) == TYPE_ARRAY:
			if typeof(v) == TYPE_ARRAY:
				(cur as Array).assign(v)
			continue
		if typeof(cur) != typeof(v) and not (typeof(cur) in [TYPE_FLOAT, TYPE_INT] and typeof(v) in [TYPE_FLOAT, TYPE_INT]) and not (typeof(cur) in [TYPE_STRING, TYPE_STRING_NAME] and typeof(v) in [TYPE_STRING, TYPE_STRING_NAME]):
			continue
		node.set(names[i], v)


# ============================================================ 입히기
## buf 에서 하나를 읽어 root 에 입힘. created: 복제본에 새로 만든 자식들 { "부모/번호": 노드 }
## lookup: Callable(int) -> String (번호 → 경로). position_root=false 면 루트 위치는 건드리지 않고 돌려줌
static func apply(root: Node, buf: StreamPeerBuffer, lookup: Callable, created: Dictionary, position_root: bool = true) -> Vector2:
	var count := buf.get_u8()
	var nodes: Array = []
	var root_pos := Vector2.ZERO
	for i in count:
		var parent_ord := buf.get_u8()
		var child_idx := buf.get_u16()
		var cls := buf.get_u8()
		var flags := buf.get_u8()
		var node: Node = null
		if i == 0:
			node = root
		elif parent_ord < nodes.size() and nodes[parent_ord] != null:
			node = _find_or_create(nodes[parent_ord], child_idx, cls, created, "%d/%d" % [parent_ord, child_idx])
		nodes.append(node)
		_read_node(node as CanvasItem, cls, flags, buf, lookup, i == 0, position_root)
		if i == 0:
			root_pos = _last_pos
	return root_pos


static var _last_pos := Vector2.ZERO


static func _find_or_create(parent: Node, child_idx: int, cls: int, created: Dictionary, key: String) -> Node:
	if created.has(key) and is_instance_valid(created[key]):
		return created[key]
	if child_idx < parent.get_child_count():
		var existing := parent.get_child(child_idx)
		if existing is CanvasItem and class_of(existing) == cls:
			return existing
	var node: CanvasItem
	match cls:
		Cls.SPRITE:
			node = Sprite2D.new()
		Cls.ANIM_SPRITE:
			node = AnimatedSprite2D.new()
		Cls.LINE:
			node = Line2D.new()
		Cls.POLYGON:
			node = Polygon2D.new()
		Cls.LABEL:
			node = Label.new()
		Cls.PARTICLES:
			return null  # 설정을 모르는 파티클은 만들지 않음
		Cls.CONTROL:
			node = ColorRect.new()
		_:
			node = Node2D.new()
	node.set_meta(&"net_clone", true)
	parent.add_child(node)
	created[key] = node
	return node


static func _read_node(node: CanvasItem, cls: int, flags: int, buf: StreamPeerBuffer, lookup: Callable, is_root: bool, position_root: bool) -> void:
	var x := buf.get_float() if is_root else buf.get_half()
	var y := buf.get_float() if is_root else buf.get_half()
	var rot := buf.get_half()
	var sx := buf.get_half()
	var sy := buf.get_half()
	var z := buf.get_16()
	var modulate := Color.WHITE if flags & F_MOD_WHITE else _get_color(buf)
	var self_modulate := Color.WHITE if flags & F_SELF_WHITE else _get_color(buf)
	if is_root:
		_last_pos = Vector2(x, y)
	if node != null:
		node.visible = flags & F_VISIBLE != 0
		node.modulate = modulate
		node.self_modulate = self_modulate
		if node is Node2D:
			var n2 := node as Node2D
			if not is_root:
				n2.position = Vector2(x, y)
			elif position_root:
				n2.global_position = Vector2(x, y)
			n2.rotation = rot
			n2.scale = Vector2(sx, sy)
			n2.z_index = z
		elif node is Control:
			var c := node as Control
			c.position = Vector2(x, y)
			c.rotation = rot
			c.size = Vector2(sx, sy)
	match cls:
		Cls.SPRITE:
			var tex := buf.get_u16()
			var hf := buf.get_u8()
			var vf := buf.get_u8()
			var frame := buf.get_u16()
			var off := Vector2(buf.get_half(), buf.get_half())
			var region := Rect2()
			if flags & F_REGION:
				region = Rect2(buf.get_float(), buf.get_float(), buf.get_float(), buf.get_float())
			var s := node as Sprite2D
			if s != null:
				var texture := _load_res(tex, lookup) as Texture2D
				if texture != null and s.texture != texture:
					s.texture = texture
				s.hframes = maxi(hf, 1)
				s.vframes = maxi(vf, 1)
				s.frame = clampi(frame, 0, s.hframes * s.vframes - 1)
				s.offset = off
				s.flip_h = flags & F_FLIP_H != 0
				s.flip_v = flags & F_FLIP_V != 0
				s.centered = flags & F_CENTERED != 0
				s.region_enabled = flags & F_REGION != 0
				if s.region_enabled:
					s.region_rect = region
		Cls.ANIM_SPRITE:
			var frames_id := buf.get_u16()
			var anim_id := buf.get_u16()
			var frame := buf.get_u16()
			var off := Vector2(buf.get_half(), buf.get_half())
			var a := node as AnimatedSprite2D
			if a != null:
				var frames := _load_res(frames_id, lookup) as SpriteFrames
				if frames != null and a.sprite_frames != frames:
					a.sprite_frames = frames
				var anim := StringName(lookup.call(anim_id))
				if a.sprite_frames != null and anim != &"" and a.sprite_frames.has_animation(anim):
					a.animation = anim
					a.frame = clampi(frame, 0, a.sprite_frames.get_frame_count(anim) - 1)
				a.offset = off
				a.flip_h = flags & F_FLIP_H != 0
				a.flip_v = flags & F_FLIP_V != 0
		Cls.LINE:
			var width := buf.get_half()
			var color := _get_color(buf)
			var points := _get_points(buf)
			var l := node as Line2D
			if l != null:
				l.width = width
				l.default_color = color
				l.points = points
		Cls.POLYGON:
			var color := _get_color(buf)
			var tex := buf.get_u16()
			var points := _get_points(buf)
			var p := node as Polygon2D
			if p != null:
				p.color = color
				var texture := _load_res(tex, lookup) as Texture2D
				if texture != null:
					p.texture = texture
				p.polygon = points
		Cls.LABEL:
			var text := buf.get_utf8_string()
			var font_color := _get_color(buf)
			var outline_color := _get_color(buf)
			var font_size := buf.get_u8()
			var outline_size := buf.get_u8()
			var align := buf.get_u8()
			var size := Vector2(buf.get_half(), buf.get_half())
			var lb := node as Label
			if lb != null:
				lb.text = text
				if lb.label_settings == null:
					lb.label_settings = LabelSettings.new()
				lb.label_settings.font_color = font_color
				lb.label_settings.outline_color = outline_color
				lb.label_settings.font_size = maxi(font_size, 1)
				lb.label_settings.outline_size = outline_size
				lb.horizontal_alignment = align as HorizontalAlignment
				lb.size = size
		Cls.PARTICLES:
			var emitting := buf.get_u8() == 1
			var pt := node as CPUParticles2D
			if pt != null and pt.emitting != emitting:
				pt.emitting = emitting
		Cls.CONTROL:
			var is_rect := buf.get_u8() == 1
			if is_rect:
				var color := _get_color(buf)
				if node is ColorRect:
					(node as ColorRect).color = color
	if flags & F_VARS:
		var size := buf.get_u16()
		var data: Array = buf.get_data(size)
		if node != null and data[0] == OK:
			var values: Variant = bytes_to_var(data[1])
			if values is Array:
				_apply_vars(node, values)
				node.queue_redraw()


static var _res_cache: Dictionary = {}


static func _load_res(id: int, lookup: Callable) -> Resource:
	if id == 0:
		return null
	var path: String = lookup.call(id)
	if path == "":
		return null
	if _res_cache.has(path):
		return _res_cache[path]
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	_res_cache[path] = res
	return res
