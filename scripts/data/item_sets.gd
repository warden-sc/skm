class_name ItemSets
## 장비 세트. 같은 set_id 의 장비를 여러 개 장착하면 개수에 따라 세트 효과가 켜짐 (장착한 무기 칸 3개도 셈).
## 효과 이름
##   attack       공격력 +%        defense    방어력 +
##   max_hp       최대 체력 +      max_hp_pct 최대 체력 +%
##   crit_chance  치명타 확률 +%   crit_damage 치명타 피해 +%
##   armor_pen    방어력 관통 +    move       이동 속도 +%
##   regen        초당 체력 재생 + reduction  받는 피해 -%
##   master_damage 멀티버스의 주인에게 주는 피해 +%

const SETS := {
	&"bronze": {"name": "청동 세트", "bonuses": [
		[2, {"defense": 30}], [4, {"attack": 0.05}], [6, {"max_hp": 300}]]},
	&"knight": {"name": "기사단 세트", "bonuses": [
		[2, {"defense": 60}], [4, {"max_hp_pct": 0.08}], [6, {"reduction": 0.05}]]},
	&"mithril": {"name": "미스릴 세트", "bonuses": [
		[2, {"attack": 0.06}], [4, {"crit_chance": 0.05}], [6, {"move": 0.08, "crit_damage": 0.2}]]},
	&"dragonscale": {"name": "용비늘 세트", "bonuses": [
		[2, {"defense": 100}], [4, {"max_hp_pct": 0.1}], [6, {"reduction": 0.08, "regen": 20.0}]]},
	&"rune": {"name": "룬 세트", "bonuses": [
		[2, {"attack": 0.08}], [4, {"armor_pen": 60}], [6, {"crit_chance": 0.06, "crit_damage": 0.3}]]},
	&"celestial": {"name": "천상 세트", "bonuses": [
		[2, {"defense": 150}], [4, {"max_hp_pct": 0.12}], [6, {"reduction": 0.1, "regen": 40.0}]]},
	&"genesis": {"name": "창세 세트", "bonuses": [
		[2, {"attack": 0.1}], [4, {"crit_chance": 0.08}], [6, {"attack": 0.1, "crit_damage": 0.4, "move": 0.1}]]},
	&"mythic": {"name": "신화의 유산", "bonuses": [
		[2, {"attack": 0.1}], [4, {"max_hp_pct": 0.15}], [6, {"reduction": 0.1}], [8, {"crit_damage": 0.5}],
		[10, {"master_damage": 0.3}]]},
}

const EFFECT_FORMAT := {
	"attack": "공격력 +%d%%", "defense": "방어력 +%d", "max_hp": "최대 체력 +%d", "max_hp_pct": "최대 체력 +%d%%",
	"crit_chance": "치명타 확률 +%d%%", "crit_damage": "치명타 피해 +%d%%", "armor_pen": "방어력 관통 +%d",
	"move": "이동 속도 +%d%%", "regen": "체력 재생 초당 +%d", "reduction": "받는 피해 -%d%%",
	"master_damage": "「억제의 권능」 멀티버스의 주인에게 주는 피해 +%d%%",
}
const PERCENT_KEYS := ["attack", "max_hp_pct", "crit_chance", "crit_damage", "move", "reduction", "master_damage"]


static func get_set_name(set_id: StringName) -> String:
	return str((SETS.get(set_id, {}) as Dictionary).get("name", set_id))


static func get_piece_count(set_id: StringName) -> int:
	var count := 0
	for item in ItemDB.get_all():
		if item.set_id == set_id:
			count += 1
	return count


## 장착한 장비들의 세트별 개수 { set_id: 개수 }
static func count_equipped(equipped: Array) -> Dictionary:
	var counts := {}
	for item in equipped:
		if item != null and (item as ItemData).set_id != &"":
			var id: StringName = (item as ItemData).set_id
			counts[id] = int(counts.get(id, 0)) + 1
	return counts


## 켜진 세트 효과를 모두 더한 값 { 효과 이름: 값 }
static func total_bonus(equipped: Array) -> Dictionary:
	var total := {}
	var counts := count_equipped(equipped)
	for set_id in counts:
		for step in (SETS.get(set_id, {}) as Dictionary).get("bonuses", []):
			if int(counts[set_id]) >= int(step[0]):
				for key in step[1]:
					total[key] = float(total.get(key, 0.0)) + float(step[1][key])
	return total


static func effect_text(effects: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in effects:
		var value := float(effects[key])
		parts.append(EFFECT_FORMAT.get(key, key + " %d") % roundi(value * 100.0 if key in PERCENT_KEYS else value))
	return ", ".join(parts)


## 상세 정보용: 「청동 세트 (2) 방어력 +30 / (4) …」 — 지금 장착 개수와 함께
static func describe(set_id: StringName, equipped_count: int = -1) -> String:
	var info: Dictionary = SETS.get(set_id, {})
	if info.is_empty():
		return ""
	if equipped_count < 0:
		equipped_count = int(GameManager.get_set_counts().get(set_id, 0))
	var steps := PackedStringArray()
	for step in info["bonuses"]:
		steps.append("%s(%d) %s" % ["●" if equipped_count >= int(step[0]) else "○", int(step[0]), effect_text(step[1])])
	return "%s %d/%d  ·  %s" % [info["name"], equipped_count, get_piece_count(set_id), "  ".join(steps)]
