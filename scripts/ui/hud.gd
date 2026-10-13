class_name HUD
extends CanvasLayer
## 화면 HUD. GameManager 시그널만 구독해서 갱신합니다 (게임 로직을 직접 참조하지 않음).
##
## hud.tscn 의 노드들은 "고유 이름(%)" 으로 접근하므로 레이아웃을 바꿔도 경로가 깨지지 않습니다.

const NOTICE_TIME := 2.5

@onready var _hp_bar: TextureProgressBar = %HPBar
@onready var _hp_label: Label = %HPLabel
@onready var _dash_bar: TextureProgressBar = %DashBar
@onready var _dash_label: Label = %DashLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _weapon_icon: TextureRect = %WeaponIcon
@onready var _weapon_label: Label = %WeaponLabel
@onready var _stage_label: Label = %StageLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _boss_box: Control = %BossBox
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: TextureProgressBar = %BossBar
@onready var _notice_label: Label = %NoticeLabel
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _game_over: Control = %GameOver

var _hp_tween: Tween
var _notice_tween: Tween


func _ready() -> void:
	GameManager.player_hp_changed.connect(_on_hp_changed)
	GameManager.player_damaged.connect(_on_player_damaged)
	GameManager.player_died.connect(_on_player_died)
	GameManager.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.weapon_equipped.connect(_on_weapon_equipped)
	GameManager.stage_changed.connect(_on_stage_changed)
	GameManager.kill_progress_changed.connect(_on_kill_progress_changed)
	GameManager.intermission_changed.connect(_on_intermission_changed)
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_hp_changed.connect(_on_boss_hp_changed)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.notice_requested.connect(_on_notice_requested)

	_boss_box.hide()
	_game_over.hide()
	_notice_label.modulate.a = 0.0
	_damage_flash.modulate.a = 0.0

	# 현재 값으로 초기 동기화
	_hp_bar.max_value = GameManager.max_hp
	_hp_bar.value = GameManager.hp
	_on_hp_changed(GameManager.hp, GameManager.max_hp)
	_on_dash_cooldown_changed(GameManager.dash_cooldown_remaining, GameManager.dash_cooldown_total)
	_on_gold_changed(GameManager.gold)
	_on_weapon_equipped(GameManager.equipped_weapon)
	_on_stage_changed(GameManager.stage)
	_progress_label.text = ""


func _on_hp_changed(current: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_label.text = "%d / %d" % [current, max_hp]
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(_hp_bar, "value", float(current), 0.15)


func _on_player_damaged(_amount: int) -> void:
	_damage_flash.modulate.a = 0.35
	create_tween().tween_property(_damage_flash, "modulate:a", 0.0, 0.3)


func _on_dash_cooldown_changed(remaining: float, total: float) -> void:
	_dash_bar.max_value = 100.0
	_dash_bar.value = (1.0 - remaining / maxf(total, 0.001)) * 100.0
	_dash_label.text = "READY" if remaining <= 0.0 else "%.1fs" % remaining


func _on_gold_changed(gold: int) -> void:
	_gold_label.text = "%d G" % gold


func _on_weapon_equipped(weapon: WeaponData) -> void:
	if weapon == null:
		_weapon_icon.texture = null
		_weapon_label.text = "무기 없음"
		return
	_weapon_icon.texture = weapon.icon
	_weapon_label.text = "%s  ATK %d" % [weapon.display_name, weapon.damage]
	_weapon_label.add_theme_color_override(&"font_color", weapon.get_rarity_color())


func _on_stage_changed(stage: int) -> void:
	_stage_label.text = "STAGE %d" % stage


func _on_kill_progress_changed(kills: int, target: int) -> void:
	_progress_label.text = "" if target <= 0 else "처치 %d / %d" % [kills, target]


func _on_intermission_changed(seconds_left: int) -> void:
	if seconds_left > 0:
		_progress_label.text = "다음 웨이브까지 %d초" % seconds_left


func _on_boss_spawned(boss_name: String, max_hp: int) -> void:
	_boss_name.text = boss_name
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_progress_label.text = "보스전"
	_boss_box.show()


func _on_boss_hp_changed(current: int, max_hp: int) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = current


func _on_boss_defeated() -> void:
	_boss_box.hide()


func _on_notice_requested(text: String, color: Color) -> void:
	_notice_label.text = text
	_notice_label.add_theme_color_override(&"font_color", color)
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_label.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_TIME)
	_notice_tween.tween_property(_notice_label, "modulate:a", 0.0, 0.5)


func _on_player_died() -> void:
	_game_over.show()
