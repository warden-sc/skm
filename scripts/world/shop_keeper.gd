class_name ShopKeeper
extends Interactable
## 야영지에 서 있는 상인 NPC. 범위 안에서 [E] 를 누르면 상점 UI 를 엽니다.
## 실제 UI 는 ShopUI 가 GameManager.shop_open_requested 시그널을 받아서 띄웁니다.

@export var shop_name: String = "떠돌이 대장장이"
## 판매 목록 (ItemDB 의 포션·장비 id). 비워 두면 상점 장비 전부(ItemDB.get_shop_items — 신화 · 드랍 전용 제외).
## 등급에 따라 스테이지가 올라야 구매 가능해집니다 (1 일반 / 11 희귀 / 41 레어 / 71 전설).
@export var stock_ids: Array[StringName] = []


func _interact() -> void:
	super._interact()
	# 대본에 이 스테이지의 상인 대사 [N스테이지 상인] 이 있으면 스테이지마다 처음 한 번은 그 대사, 그 밖에는 [상인] 을 말을 걸 때마다
	if Story.play("%d스테이지 상인" % GameManager.stage, "상인@%d" % GameManager.stage) or Story.play("상인", "*"):
		await Story.finished
	GameManager.request_shop(shop_name, stock_ids)
