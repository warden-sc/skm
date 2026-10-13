class_name ShopKeeper
extends Interactable
## 야영지에 서 있는 상인 NPC. 범위 안에서 [E] 를 누르면 상점 UI 를 엽니다.
## 실제 UI 는 ShopUI 가 GameManager.shop_open_requested 시그널을 받아서 띄웁니다.

@export var shop_name: String = "떠돌이 대장장이"
## 판매 목록 (ItemDB 의 장비 id). 등급에 따라 스테이지가 올라야 구매 가능해집니다.
@export var stock_ids: Array[StringName] = [
	&"iron_sword", &"flame_blade", &"holy_sword",
	&"hunter_bow", &"rapid_crossbow", &"windrunner_bow", &"solaris_bow",
	&"apprentice_staff", &"frost_staff", &"ignis_staff", &"arcana_staff",
	&"iron_shield", &"royal_aegis", &"colossus_bulwark",
	&"leather_cap", &"iron_helm", &"orc_warhelm", &"gatekeeper_horns",
	&"leather_armor", &"chain_mail", &"hellsteel_plate", &"paladin_plate",
	&"rough_ruby", &"ruby", &"sapphire", &"blood_ruby", &"star_diamond",
]


func _interact() -> void:
	super._interact()
	GameManager.request_shop(shop_name, stock_ids)
