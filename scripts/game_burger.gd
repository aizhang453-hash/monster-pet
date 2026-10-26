class_name BurgerGame
extends MiniGame
## 做汉堡 (学拓麻歌子 Uni 的快餐店): 客人点的汉堡从下往上是什么, 就照着顺序按 (面包、肉、菜、芝士)。
## 一共 5 份, 每份 10 秒, 按错或者超时这份就不算。做好 3 份以上算赢。

const ORDERS := 5
const WIN := 3
const LIMIT := 10.0
const NAMES := {"bun": "面包", "meat": "肉", "veg": "菜", "cheese": "芝士"}
const COLORS := {"bun": Color("e0a050"), "meat": Color("8a4a2a"), "veg": Color("6fbf4a"), "cheese": Color("ffd84a")}

var order: Array = []      # 这一份要的, 从下往上
var built: Array = []      # 已经放上去的
var served := 0
var failed := 0
var result := ""           # 刚做完这一份: ok / bad (画面显示一下)
var _left := LIMIT
var _wait := 0.0


func start() -> void:
	_new_order()


func _new_order() -> void:
	order = ["bun"]
	for i in rng.randi_range(2, 3):
		order.append(["meat", "veg", "cheese"][rng.randi() % 3])
	order.append("bun")
	built = []
	_left = LIMIT


func buttons() -> Array:
	return [["bun", "面包"], ["meat", "肉"], ["veg", "菜"], ["cheese", "芝士"]]


func press(action: String) -> void:
	if done or _wait > 0:
		return
	if order[built.size()] != action:
		_close(false)
		return
	built.append(action)
	if built.size() == order.size():
		_close(true)


func _close(ok: bool) -> void:
	result = "ok" if ok else "bad"
	if ok:
		score += 1
	else:
		failed += 1
	served += 1
	_wait = 0.8


func step(dt: float) -> void:
	if done:
		return
	t += dt
	if _wait > 0:
		_wait -= dt
		if _wait <= 0:
			result = ""
			if served >= ORDERS:
				done = true
			else:
				_new_order()
		return
	_left -= dt
	if _left <= 0:
		_close(false)


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score * 4 + (5 if won() else 0)


func status_text() -> String:
	return "第 %d/%d 份   做好 %d   还剩 %d 秒" % [mini(served + 1, ORDERS), ORDERS, score, maxi(0, ceili(_left))]
