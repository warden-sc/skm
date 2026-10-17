class_name LaserSweep
extends Node2D
## 회전 레이저 (12스테이지 레기온): 한 줄기 레이저를 쏜 뒤, 그 레이저가 시전자를 중심으로 한 바퀴(sweep) 돕니다.
##   1) warn_time 동안 시작 방향에 가는 예고선
##   2) duration 동안 굵은 레이저가 start_angle 에서 start_angle + sweep 까지 회전
## 레이저에 닿은 플레이어는 피해 (피격 무적시간 동안은 다시 맞지 않음 · 대시로 통과 · 방패로 막을 수 있음).
## 위치는 매 프레임 caster 의 get_muzzle() / get_hit_center() 를 따라갑니다. 판정은 선분과의 거리라 물리 콜백 문제가 없습니다.

var caster: Enemy
## 레이저가 나오는 부위 (null 이면 caster 몸 중심)
var muzzle: Node2D
var start_angle: float = 0.0
## 회전량 (라디안, 음수면 반시계)
var sweep: float = TAU
var warn_time: float = 0.8
var duration: float = 3.0
var length: float = 260.0
var width: float = 7.0
var damage: int = 30
var color: Color = Color(1.0, 0.3, 0.35)

var _elapsed: float = 0.0
var _hits: int = 0


static func spawn(from: Enemy, beam_start_angle: float, beam_sweep: float, beam_duration: float, beam_damage: int,
		beam_length: float = 260.0, beam_color: Color = Color(1.0, 0.3, 0.35), from_muzzle: Node2D = null) -> LaserSweep:
	if from == null or not from.is_inside_tree():
		return null
	var tree := from.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	var laser := LaserSweep.new()
	laser.caster = from
	laser.muzzle = from_muzzle
	laser.start_angle = beam_start_angle
	laser.sweep = beam_sweep
	laser.duration = beam_duration
	laser.damage = beam_damage
	laser.length = beam_length
	laser.color = beam_color
	laser.z_index = 30
	laser.add_to_group(&"sky_strikes")  # 스테이지가 바뀌면 함께 정리
	root.add_child(laser)
	laser.global_position = laser._origin()
	return laser


func _origin() -> Vector2:
	if muzzle != null and is_instance_valid(muzzle):
		return muzzle.global_position + Vector2(0, -4)
	if caster != null and is_instance_valid(caster):
		return caster.get_hit_center()
	return global_position


func is_firing() -> bool:
	return _elapsed >= warn_time and _elapsed < warn_time + duration


## 지금 레이저가 가리키는 각도
func get_angle() -> float:
	var t := clampf((_elapsed - warn_time) / maxf(duration, 0.01), 0.0, 1.0)
	return start_angle + sweep * t


func get_hit_count() -> int:
	return _hits


func _physics_process(delta: float) -> void:
	if caster == null or not is_instance_valid(caster) or caster.is_dead():
		queue_free()
		return
	_elapsed += delta
	global_position = _origin()
	queue_redraw()
	if is_firing():
		_try_hit()
	if _elapsed >= warn_time + duration + 0.15:
		queue_free()


func _try_hit() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	var dir := Vector2.from_angle(get_angle())
	var to_player := player.global_position + Vector2(0, -5) - global_position
	var along := to_player.dot(dir)
	if along < 0.0 or along > length:
		return
	if absf(to_player.cross(dir)) > width + 5.0:
		return
	if player.take_hit(roundi(damage * caster.power), global_position + dir * maxf(along - 8.0, 0.0), caster) == Player.HitResult.DAMAGED:
		_hits += 1
		Fx.burst(caster, player.global_position, color, 6, 50.0, 0.25)


func _draw() -> void:
	if _elapsed < warn_time:
		var blink := 0.35 + 0.35 * absf(sin(_elapsed * 14.0))
		var d := Vector2.from_angle(start_angle) * length
		draw_line(Vector2.ZERO, d, Color(color, blink), 1.0)
		# 회전 방향 화살표 대신, 앞으로 쓸고 지나갈 쪽에 옅은 부채꼴
		draw_arc(Vector2.ZERO, 30.0, start_angle, start_angle + signf(sweep) * 0.9, 12, Color(color, blink * 0.6), 1.0)
		return
	var fade := 1.0 if is_firing() else clampf(1.0 - (_elapsed - warn_time - duration) / 0.15, 0.0, 1.0)
	var tip := Vector2.from_angle(get_angle()) * length
	draw_line(Vector2.ZERO, tip, Color(color, 0.35 * fade), width * 2.2)
	draw_line(Vector2.ZERO, tip, Color(color, 0.85 * fade), width)
	draw_line(Vector2.ZERO, tip, Color(1.0, 0.95, 0.95, fade), width * 0.35)
	draw_circle(Vector2.ZERO, width * 1.1, Color(1.0, 0.9, 0.9, 0.8 * fade))
