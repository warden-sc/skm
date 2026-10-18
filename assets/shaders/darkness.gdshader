shader_type canvas_item;
// 심연의 군주 녹스 보스방의 어둠 (27스테이지): 빛 원(플레이어 주변 · 켜진 횃불) 안쪽만 보이고 나머지는 칠흑
uniform vec2 lights[8];
uniform float radii[8];
uniform int count = 0;
uniform float darkness = 0.9;
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float a = darkness;
	for (int i = 0; i < 8; i++) {
		if (i >= count) {
			break;
		}
		float d = distance(local_pos, lights[i]);
		a = min(a, darkness * smoothstep(radii[i] * 0.55, radii[i], d));
	}
	COLOR = vec4(0.02, 0.0, 0.04, a);
}
