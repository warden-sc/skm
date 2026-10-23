extends Node
## 보스 처치 시간 맞추기 — 스테이지마다 「그때 갖출 장비」로 보스를 쉬지 않고 때렸을 때 걸리는 시간을 규칙에 맞게.
##   일반 스테이지 20초 · 5단위(5 · 15 · 25 …) 30초 · 10단위(10 · 20 …) 40초 · 히든 40초 · 최종장 60초 (노멀 · 혼자)
##   그때 갖출 장비 = 그 스테이지 등급(1~10 일반 · 11~40 희귀 · 41~70 레어 · 71~100 전설)에서 제 실력을 내는 단계(get_fit_stage)까지의
##                   상점 장비 한 벌(검 · 방패 · 투구 · 갑옷 · 신발 · 팔찌 · 반지 · 펜던트 + 세트 효과). 최종장은 신화 장비 10개.
##   41스테이지부터(레어 이상 무기)는 액티브 스킬 [Q] 를 대기시간마다 쓰는 피해까지 넣어서 계산.
## 보스를 체력만으로 맞추지 않고:
##   방어력 = 그 장비의 평타 한 방(팔찌 · 반지 포함, 방깍 전)의 DEF_SHARE — 방깍(팔찌 · 활)이 쓸모 있게
##   체력   = 위 방어력으로 줄어든 실제 초당 피해 × 목표 시간
## 실행: Godot --headless --path . res://tools/boss_tuning.tscn  → 줄마다 「TUNE {json}」, 마지막에 「TUNE_END」
##       python3 tools/apply_boss_tuning.py <출력 파일> 로 보스 씬(max_hp · defense)에 적용.

const DEF_SHARE := 0.22
const TIME_NORMAL := 20.0
const TIME_FIVE := 30.0
const TIME_TEN := 40.0
const TIME_HIDDEN := 40.0
const TIME_FINAL := 60.0
const SKILL_FROM_STAGE := 41
const SAMPLES := 600


static func target_time(stage: int) -> float:
	if stage % 10 == 0:
		return TIME_TEN
	if stage % 5 == 0:
		return TIME_FIVE
	return TIME_NORMAL


func _ready() -> void:
	_run.call_deferred()


func _equip_fit(stage: int, mythic: bool) -> void:
	var gm = get_node("/root/GameManager")
	gm.start_new_game(gm.Difficulty.NORMAL)
	gm.mythic_unlocked = true
	var rarity: int = ItemData.Rarity.MYTHIC if mythic else ItemData.max_rarity_for_stage(stage)
	var best := {}
	for item in ItemDB.get_all():
		if item is PotionData or item is RelicData or item.rarity != rarity:
			continue
		if not mythic and (not item.in_shop or item.get_fit_stage() > stage):
			continue
		var key: String = ItemDB.price_category(item)
		if key in ["", "bow", "staff", "dagger"]:
			continue
		if not best.has(key) or int(item.tier) > int(best[key].tier):
			best[key] = item
	for key in best:
		gm.add_item(best[key])
		gm.equip_item(best[key])
	gm._recalculate_stats()


## [평타 평균(방어 전), 초당 피해(방어 적용, 스킬 포함)]
func _dps(boss: Enemy, with_skill: bool) -> Array:
	var gm = get_node("/root/GameManager")
	var w: WeaponData = gm.equipped_weapon
	var raw := 0.0
	var dealt := 0.0
	for i in SAMPLES:
		var r: Dictionary = gm.roll_weapon_damage(w)
		raw += float(r["amount"])
		dealt += boss.calc_damage(int(r["amount"]), int(r["armor_pen"]))
	raw /= SAMPLES
	dealt /= SAMPLES
	var dps := dealt / w.attack_cooldown
	if with_skill and w.has_skill():
		var skill := 0.0
		for i in SAMPLES:
			var r: Dictionary = gm.roll_weapon_damage(w)
			skill += boss.calc_damage(roundi(float(r["amount"]) * w.get_skill_multiplier()), int(r["armor_pen"]))
		skill /= SAMPLES
		dps += skill * float(w.get_skill_info().get("hits", 1)) / w.get_skill_cooldown()
	return [raw, dps]


func _tune(label: String, stage: int, data: StageData, time: float, mythic: bool) -> void:
	_equip_fit(stage, mythic)
	var gm = get_node("/root/GameManager")
	var with_skill := mythic or stage >= SKILL_FROM_STAGE
	var scene_path := data.boss_scene.resource_path
	var boss: Enemy = data.boss_scene.instantiate()
	var old_hp := boss.max_hp
	var old_def := boss.defense
	boss.apply_difficulty(gm.get_difficulty_info())
	var before: Array = _dps(boss, with_skill)
	var old_ttk: float = boss.max_hp / before[1]
	# 방어력: 평타 한 방의 DEF_SHARE (예전 단위)
	var new_def := maxi(roundi(float(before[0]) * DEF_SHARE / Balance.K), 1)
	boss.defense = new_def
	var after: Array = _dps(boss, with_skill)
	var new_hp := maxi(roundi(after[1] * time / Balance.K / 100.0) * 100, 100)
	print("TUNE " + JSON.stringify({
		"label": label, "stage": stage, "scene": scene_path, "boss": boss.display_name, "weapon": gm.equipped_weapon.display_name,
		"skill": with_skill and gm.equipped_weapon.has_skill(), "target": time,
		"old_hp": old_hp, "old_def": old_def, "old_ttk": snappedf(old_ttk, 0.1),
		"hp": new_hp, "def": new_def, "ttk": snappedf(new_hp * Balance.K / after[1], 0.1),
	}))
	boss.free()


func _run() -> void:
	for stage in range(1, 101):
		_tune(str(stage), stage, load("res://data/stages/stage_%d.tres" % stage), target_time(stage), false)
	_tune("hidden", 35, load("res://data/stages/stage_hidden.tres"), TIME_HIDDEN, false)
	_tune("finale", 100, load("res://data/stages/stage_finale.tres"), TIME_FINAL, true)
	print("TUNE_END")
	get_tree().quit()
