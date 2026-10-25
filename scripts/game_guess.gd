class_name GuessGame
extends MiniGame
## 猜左右 (原版第一代就有): 猜它往左还是往右跳, 一共 5 次, 猜中 3 次以上算赢。

const ROUNDS := 5
const WIN := 3
const SHOW := 0.9   # 跳过去以后停多久再下一次

var round_no := 0
var turn := 0       # 这一次它跳向哪边: -1 左, 1 右, 0 还没跳
var hit := false
var _wait := 0.0


func start() -> void:
	pass


func buttons() -> Array:
	return [["left", "← 左边"], ["right", "右边 →"]]


func press(action: String) -> void:
	if done or turn != 0:
		return
	var guess := -1 if action == "left" else 1
	turn = -1 if rng.randf() < 0.5 else 1
	hit = turn == guess
	if hit:
		score += 1
	round_no += 1
	_wait = SHOW


func step(dt: float) -> void:
	t += dt
	if turn != 0:
		_wait -= dt
		if _wait <= 0:
			turn = 0
			if round_no >= ROUNDS:
				done = true


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score * 3 + (5 if won() else 0)


func status_text() -> String:
	return "第 %d/%d 次   猜中 %d" % [mini(round_no + (0 if turn != 0 else 1), ROUNDS), ROUNDS, score]
