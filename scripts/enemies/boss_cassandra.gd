class_name BossCassandra
extends PatternBoss
## 64스테이지 보스: 예언자 카산드라 — 아폴론에게 예언의 힘을 받았지만, 그의 사랑을 거절해 「아무도 믿지 않는」 저주를 받은 트로이의 공주.
##   PROPHECY : 예언 — 금빛 표식으로 곧 터질 자리를 미리 보여 줌
##   CURSE    : 저주의 구슬 (부채꼴)
##   TROY_FIRE: 불타는 트로이 — 몸 주위 불기둥 고리
##   SUMMON   : 트로이 파수병 · 목마 병사 호출
##
## [기믹] 예언과 저주: 예언 표식 뒤 prophecy_delay 초 뒤에 터짐. 예언하는 목소리 색이 단서
##   푸른 목소리 = 참 예언 → 표식 자리가 터짐
##   붉은 목소리 = 저주받은 거짓 예언 → 표식은 안전하고, 플레이어를 사이에 둔 반대쪽 자리가 터짐
## 체력 50% 이하: 표식이 늘고, 거짓 예언이 잦아짐

enum Pattern { PROPHECY, CURSE, TROY_FIRE, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var orb_texture: Texture2D
@export var prophecy_damage: int = 96
@export var curse_damage: int = 58
@export var fire_damage: int = 82
@export var prophecy_delay: float = 1.4
@export var false_chance: float = 0.5

var last_marks: Array[Vector2] = []
var last_strikes: Array[Vector2] = []
var last_true: bool = true
var _prophecies: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.PROPHECY, Pattern.CURSE, Pattern.PROPHECY, Pattern.TROY_FIRE, Pattern.SUMMON]
	set_status("예언자 — 푸른 목소리는 참, 붉은 목소리는 거짓", Color(0.85, 0.8, 1.0))


func get_prophecy_count() -> int:
	return _prophecies


## 예언 (테스트에서도 직접 호출). truthful 이 -1 이면 무작위
func prophesy(truthful: int = -1) -> void:
	if not has_target():
		return
	_prophecies += 1
	last_true = randf() >= false_chance * (1.3 if phase_two else 1.0) if truthful < 0 else truthful == 1
	var center := _player.global_position
	var truth := last_true
	last_marks.clear()
	last_strikes.clear()
	for i in (8 if phase_two else 6):
		var mark := center + Vector2.from_angle(TAU * i / (8.0 if phase_two else 6.0) + randf_range(-0.3, 0.3)) * randf_range(28.0, 70.0)
		last_marks.append(mark)
		var marker := AoeStrike.spawn(self, mark, 22.0, prophecy_delay, 0, Color(1.0, 0.85, 0.3))
		if marker != null:
			marker.harmless = true
		var at := mark if truth else center * 2.0 - mark
		last_strikes.append(at)
		_after(prophecy_delay, func() -> void:
			if not is_dead():
				var strike := telegraph_strike(at, 22.0, 0.05, prophecy_damage, Elements.Type.HOLY)
				if strike != null:
					strike.color = Color(0.6, 0.8, 1.0) if truth else Color(1.0, 0.4, 0.4))
	if last_true:
		FloatingText.spawn(self, global_position + Vector2(0, -52), "「이 자리에 빛이 떨어지리라」", Color(0.55, 0.75, 1.0), true)
		GameManager.show_notice("카산드라의 예언 — 푸른 목소리 (참): 표식에서 벗어나라", Color(0.55, 0.75, 1.0))
	else:
		FloatingText.spawn(self, global_position + Vector2(0, -52), "「이 자리에 빛이 떨어지리라…」", Color(1.0, 0.4, 0.4), true)
		GameManager.show_notice("카산드라의 예언 — 붉은 목소리 (저주받은 거짓): 표식 안이 안전하다", Color(1.0, 0.45, 0.45))


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.PROPHECY:
			prophesy()
			return prophecy_delay + 0.4
		Pattern.CURSE:
			for i in 7:
				shoot(dir.rotated((i - 3) * 0.16), 135.0, curse_damage, orb_texture, 0.0, Elements.Type.DARK)
			return 0.9
		Pattern.TROY_FIRE:
			for i in 12:
				telegraph_strike(get_hit_center() + Vector2.from_angle(TAU * i / 12.0) * 50.0, 20.0, 0.85, fire_damage, Elements.Type.FIRE)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-50.0 + 100.0 * i, 30.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	GameManager.show_notice("카산드라: 트로이는 불타리라… 아무도 믿지 않겠지만! 거짓 예언이 잦아진다", Color(1.0, 0.5, 0.5))
