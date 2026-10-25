class_name CatchGame
extends MiniGame
## 接果子 (小孩起): 按住左右移动魔物, 接住从上面掉下来的果子。一共掉 15 个, 接住 10 个以上算赢。

const TOTAL := 15
const WIN := 10
const SPEED := 26.0       # 魔物左右走多快 (点 / 秒)
const FALL := 13.0        # 果子一开始掉多快, 之后越来越快
const GAP := 1.3          # 隔多久掉一个
const PET_W := 16.0

var pet_x := 16.0
var fruits: Array = []    # [{x, y}] 正在掉的果子 (左上角, 4 × 4 个点)
var dropped := 0
var missed := 0
var _hold := 0            # 按住的方向
var _next := 0.6


func start() -> void:
	pass


func buttons() -> Array:
	return [["left", "← 左"], ["right", "右 →"]]


func hold_buttons() -> bool:
	return true


func press(action: String) -> void:
	_hold = -1 if action == "left" else 1
	_move(_hold * 2.0)  # 点一下也挪一点


func release(action: String) -> void:
	if (action == "left" and _hold < 0) or (action == "right" and _hold > 0):
		_hold = 0


func _move(dx: float) -> void:
	pet_x = clampf(pet_x + dx, 0.0, 48.0 - PET_W)


func step(dt: float) -> void:
	if done:
		return
	t += dt
	_move(_hold * SPEED * dt)
	_next -= dt
	if _next <= 0 and dropped < TOTAL:
		fruits.append({"x": rng.randf_range(1.0, 43.0), "y": -4.0})
		dropped += 1
		_next = GAP
	var speed := FALL + dropped * 0.5
	for f in fruits.duplicate():
		f.y += speed * dt
		var cx: float = f.x + 2.0
		if f.y >= 15.0 and f.y <= 21.0 and cx >= pet_x + 1.0 and cx <= pet_x + PET_W - 1.0:
			fruits.erase(f)
			score += 1
		elif f.y > 32.0:
			fruits.erase(f)
			missed += 1
	if dropped >= TOTAL and fruits.is_empty():
		done = true


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score + (5 if won() else 0)


func status_text() -> String:
	return "接住 %d   掉了 %d   还有 %d" % [score, missed, TOTAL - dropped + fruits.size()]
