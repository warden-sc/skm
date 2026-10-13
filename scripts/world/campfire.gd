extends Sprite2D
## 야영지 모닥불: 불티 파티클 + 은은하게 일렁이는 빛


var _glow: Sprite2D
var _time: float = 0.0


func _ready() -> void:
	var embers := Fx.make_aura(Elements.color_of(Elements.Type.FIRE), 14, 4.0, Vector2(0, -45), 0.9)
	embers.position = Vector2(0, -2)
	add_child(embers)
	embers.emitting = true
	_glow = Sprite2D.new()
	_glow.texture = Fx.GLOW_TEXTURE
	_glow.material = Fx.additive_material()
	_glow.modulate = Color(1.0, 0.6, 0.25, 0.45)
	_glow.scale = Vector2(2.4, 1.6)
	_glow.show_behind_parent = true
	add_child(_glow)


func _process(delta: float) -> void:
	_time += delta
	_glow.modulate.a = 0.38 + sin(_time * 9.0) * 0.06 + sin(_time * 13.0) * 0.04
