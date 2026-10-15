class_name Elements
## 속성 정의. 무기 이펙트 색 / 몬스터 오라 / 골렘 패턴이 모두 이 값을 공유합니다.

enum Type { NONE, FIRE, ICE, LIGHTNING, EARTH, NATURE, HOLY, ARCANE, DARK }

const NAMES := {
	Type.NONE: "무속성",
	Type.FIRE: "화염",
	Type.ICE: "빙결",
	Type.LIGHTNING: "뇌전",
	Type.EARTH: "대지",
	Type.NATURE: "자연",
	Type.HOLY: "신성",
	Type.ARCANE: "비전",
	Type.DARK: "암흑",
}

const COLORS := {
	Type.NONE: Color(1.0, 1.0, 1.0),
	Type.FIRE: Color(1.0, 0.5, 0.15),
	Type.ICE: Color(0.55, 0.88, 1.0),
	Type.LIGHTNING: Color(1.0, 0.95, 0.4),
	Type.EARTH: Color(0.75, 0.55, 0.3),
	Type.NATURE: Color(0.5, 1.0, 0.4),
	Type.HOLY: Color(1.0, 0.92, 0.6),
	Type.ARCANE: Color(0.78, 0.5, 1.0),
	Type.DARK: Color(0.62, 0.3, 0.95),
}


static func color_of(element: Type) -> Color:
	return COLORS.get(element, Color.WHITE)


static func name_of(element: Type) -> String:
	return NAMES.get(element, "?")


## 파티클이 흘러가는 방향 (불꽃은 위로, 대지는 아래로 등)
static func gravity_of(element: Type) -> Vector2:
	match element:
		Type.FIRE:
			return Vector2(0, -90)
		Type.EARTH:
			return Vector2(0, 160)
		Type.ICE:
			return Vector2(0, 40)
		Type.HOLY:
			return Vector2(0, -40)
		Type.DARK:
			return Vector2(0, -25)
	return Vector2.ZERO
