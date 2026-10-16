class_name BossSuccubus
extends PatternBoss
## 9스테이지 보스: 상급마족 서큐버스
##   HEARTS : 하트 탄막 (맞으면 감속)
##   GUST   : 날갯짓 — 원형 암흑탄
##   BLINK  : 박쥐 떼처럼 흩어졌다 다른 곳에서 나타남
##   SUMMON : 하급 서큐버스 소환
##
## [기믹] 매혹: charm_interval 마다
##   1) 분홍빛으로 매혹을 모음 (예고, 머리 위 "매혹…")
##   2) 커다란 매혹의 하트를 발사 — 맞으면 charm_time 동안 조작 불가 (플레이어가 서큐버스 쪽으로 끌려감)
##      · 대시로 피하거나, 막 올린 방패(퍼펙트 가드)로 튕겨낼 수 있음 (일반 가드로 막아도 매혹되지 않음)
##   3) 매혹에 걸리면 서큐버스가 플레이어 등 뒤로 순간이동해 공격
## 체력 50% 이하: 매혹 주기 단축, 하트 수 증가

enum Pattern { HEARTS, GUST, BLINK, SUMMON, CHARM }

@export var heart_texture: Texture2D
@export var bolt_texture: Texture2D
@export var minion_scene: PackedScene
@export var heart_damage: int = 24
@export var charm_damage: int = 20
@export var backstab_damage: int = 40
@export var charm_interval: float = 8.0
@export var charm_time: float = 1.8

var _charm_cooldown: float = 0.0
var _player_was_charmed: bool = false


func _ready() -> void:
	super._ready()
	pattern_order = [Pattern.HEARTS, Pattern.GUST, Pattern.BLINK, Pattern.HEARTS, Pattern.SUMMON]
	_charm_cooldown = charm_interval * 0.5


func _get_move_velocity(delta: float) -> Vector2:
	if has_target():
		_check_charm_landed()
		_charm_cooldown -= delta
		if _charm_cooldown <= 0.0 and not is_casting():
			_charm_cooldown = charm_interval * (0.7 if phase_two else 1.0)
			cast(Pattern.CHARM)
			return Vector2.ZERO
	return super._get_move_velocity(delta)


func _chase_velocity(_delta: float) -> Vector2:
	# 거리를 두고 요염하게 맴돎
	var away := _player.global_position.direction_to(global_position)
	var target := _player.global_position + away.rotated(0.6) * 100.0
	return global_position.direction_to(target) * move_speed


func _run_pattern(pattern: int) -> float:
	match pattern:
		Pattern.HEARTS:
			var count := 9 if phase_two else 7
			var aim := direction_to_player()
			for i in count:
				var t := float(i) / float(count - 1) - 0.5
				shoot(aim.rotated(t * 1.4), 120.0, heart_damage, heart_texture, 0.8, Elements.Type.ARCANE)
			return 0.9
		Pattern.GUST:
			for i in 18:
				shoot(Vector2.RIGHT.rotated(TAU * i / 18.0), 100.0, heart_damage, bolt_texture, 0.0, Elements.Type.DARK)
			return 0.9
		Pattern.BLINK:
			_blink_to(_player.global_position + Vector2.from_angle(randf() * TAU) * 110.0)
			return 0.8
		Pattern.SUMMON:
			if minion_scene != null:
				for i in 2:
					request_summon(minion_scene, global_position + Vector2(-30.0 + 60.0 * i, 10.0))
			return 0.9
		Pattern.CHARM:
			set_status("매혹…", Color(1.0, 0.5, 0.85))
			_after(0.8, _fire_charm)
			return 1.2
	return 1.0


# ============================================================ 기믹: 매혹
func _fire_charm() -> void:
	set_status("", Color.WHITE)
	if is_dead() or not has_target():
		return
	var pool := ProjectilePool.find(get_tree())
	if pool == null:
		return
	var spec := ProjectileSpec.enemy_bullet(get_hit_center(), direction_to_player(), 170.0, roundi(charm_damage * power), heart_texture, 0.0, Elements.Type.ARCANE)
	spec.scale = 2.4
	spec.charm_duration = charm_time
	spec.charmer = self
	pool.spawn(spec)
	Fx.flash(self, get_hit_center(), Color(1.0, 0.5, 0.85), 30.0, 0.3)


## 플레이어가 막 매혹되면 → 등 뒤로 순간이동해 베기
func _check_charm_landed() -> void:
	var charmed := _player.is_charmed()
	if charmed and not _player_was_charmed:
		_backstab()
	_player_was_charmed = charmed


func _backstab() -> void:
	var behind := _player.global_position - _player.get_aim_direction() * 34.0
	_blink_to(behind)
	set_status("뒤를 잡았어♡", Color(1.0, 0.5, 0.85))
	_after(1.0, set_status.bind("", Color.WHITE))
	telegraph_strike(_player.global_position, 20.0, 0.55, backstab_damage, Elements.Type.DARK)
	_bstate = BossState.CASTING
	_btimer = 1.0


func _blink_to(at: Vector2) -> void:
	if arena_rect.has_area():
		at = at.clamp(arena_rect.position, arena_rect.end)
	Fx.burst(self, get_hit_center(), Color(0.6, 0.2, 0.5), 16, 50.0, 0.5)
	global_position = at
	Fx.burst(self, get_hit_center(), Color(1.0, 0.5, 0.85), 16, 50.0, 0.5)


func _on_phase_two() -> void:
	GameManager.show_notice("서큐버스: 후후… 이제 진심으로 놀아줄게", Color(1.0, 0.5, 0.85))
