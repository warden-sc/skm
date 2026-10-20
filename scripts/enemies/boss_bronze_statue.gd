class_name BossBronzeStatue
extends PatternBoss
## 79스테이지 보스: 아크로폴리스의 청동 수호상 — 아테나 프로마코스(앞에서 싸우는 아테나) 상. 바다에서도 창끝이 보였다는 거대한 신상.
##   SWEEP    : 거대한 창 휩쓸기 — 신상 둘레를 따라 차례로 터지는 반원
##   THRUST   : 창 내지르기 (일직선)
##   BRONZE   : 청동 비 — 플레이어 주변에 떨어지는 청동 조각
##   SUMMON   : 청동 호플리테스 · 청동 올빼미 호출
##
## [기믹] 빛나는 방패: glow_interval 초마다 방패가 glow_time 초 동안 빛남
##   빛나는 동안 신상 가까이(reflect_radius) 날아온 플레이어의 화살·마법탄은 그대로 되받아쳐져 플레이어에게 돌아옴 → 근접 공격만 통함
## [기믹] 움직이지 않는 신상: 제자리에 서서 싸움 (휩쓸기 안쪽으로 파고들기)
## 체력 50% 이하: 방패가 더 오래 빛남

enum Pattern { SWEEP, THRUST, BRONZE, SUMMON }

@export var minion_scenes: Array[PackedScene] = []
@export var shard_texture: Texture2D
@export var sweep_damage: int = 100
@export var thrust_damage: int = 98
@export var bronze_damage: int = 70
@export var reflect_damage: int = 60
@export var glow_interval: float = 9.0
@export var glow_time: float = 4.5
@export var reflect_radius: float = 60.0

var _glow_left: float = 0.0
var _until_glow: float = 4.0
var _reflects: int = 0


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.SWEEP, Pattern.THRUST, Pattern.BRONZE, Pattern.SWEEP, Pattern.SUMMON]


func is_glowing() -> bool:
	return _glow_left > 0.0


func get_reflect_count() -> int:
	return _reflects


func _get_move_velocity(delta: float) -> Vector2:
	super._get_move_velocity(delta)
	return Vector2.ZERO


## 방패를 빛냄 (테스트에서도 직접 호출)
func begin_glow() -> void:
	_glow_left = glow_time * (1.35 if phase_two else 1.0)
	_until_glow = glow_interval
	base_tint = Color(1.4, 1.3, 0.9)
	Net.announce("수호상의 방패가 빛난다! 화살과 마법이 되받아쳐진다 — 근접으로", Color(1.0, 0.9, 0.5))


func _physics_process(delta: float) -> void:
	if not is_dead() and has_target():
		if _glow_left > 0.0:
			_glow_left -= delta
			if _glow_left <= 0.0:
				base_tint = Color.WHITE
			_reflect_shots()
		else:
			_until_glow -= delta
			if _until_glow <= 0.0:
				begin_glow()
		set_status("방패가 빛남 — 원거리 반사!" if is_glowing() else "청동 수호상", Color(1.0, 0.9, 0.5) if is_glowing() else Color(0.9, 0.8, 0.6))
	super._physics_process(delta)


func _reflect_shots() -> void:
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	for c in pool.get_children():
		var p := c as Projectile
		if p == null or not p.is_active or p.get_team() == ProjectileSpec.Team.ENEMY:
			continue
		if p.global_position.distance_to(get_hit_center()) <= reflect_radius:
			var at := p.global_position
			p.release()
			_reflects += 1
			Fx.flash(self, at, Color(1.0, 0.95, 0.6), 14.0, 0.25)
			shoot(at.direction_to(_player.global_position), 220.0, reflect_damage, shard_texture, 0.0, Elements.Type.HOLY, at)


func _run_pattern(pattern: int) -> float:
	if not has_target():
		return 0.5
	var dir := direction_to_player()
	match pattern:
		Pattern.SWEEP:
			var start := dir.angle() - PI * 0.5
			for i in 14:
				var a := start + PI * i / 13.0
				for r in [60.0, 100.0]:
					telegraph_strike(get_hit_center() + Vector2.from_angle(a) * r, 20.0, 0.7 + 0.07 * i, sweep_damage, Elements.Type.NONE)
			return 1.8
		Pattern.THRUST:
			for i in 14:
				telegraph_strike(get_hit_center() + dir * (26.0 + 22.0 * i), 16.0, 0.6 + 0.03 * i, thrust_damage, Elements.Type.NONE)
			return 1.1
		Pattern.BRONZE:
			for i in 8:
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 80.0)
				telegraph_strike(at, 18.0, 0.8 + 0.07 * i, bronze_damage, Elements.Type.EARTH)
			return 1.2
		Pattern.SUMMON:
			if not minion_scenes.is_empty():
				for i in 2:
					request_summon(minion_scenes.pick_random(), global_position + Vector2(-60.0 + 120.0 * i, 40.0))
			return 0.9
	return 1.0


func _on_phase_two() -> void:
	Net.announce("청동 수호상의 눈이 빛난다! 방패가 더 오래 빛난다", Color(1.0, 0.9, 0.5))
