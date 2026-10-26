class_name NumberGame
extends MiniGame
## 猜数字 (学拓麻歌子第二代): 屏幕上一个数 (1–9), 猜下一个比它大还是小。5 次猜中 3 次以上算赢。

const ROUNDS := 5
const WIN := 3
const SHOW := 1.0

var current := 5
var next_number := 0      # 揭晓的下一个数 (0 = 还没揭晓)
var round_no := 0
var hit := false
var _wait := 0.0


func start() -> void:
	current = rng.randi_range(2, 8)


func buttons() -> Array:
	return [["big", "大"], ["small", "小"]]


func press(action: String) -> void:
	if done or next_number != 0:
		return
	next_number = rng.randi_range(1, 9)
	while next_number == current:
		next_number = rng.randi_range(1, 9)
	hit = (next_number > current) == (action == "big")
	if hit:
		score += 1
	round_no += 1
	_wait = SHOW


func step(dt: float) -> void:
	t += dt
	if next_number != 0:
		_wait -= dt
		if _wait <= 0:
			current = next_number
			next_number = 0
			if round_no >= ROUNDS:
				done = true


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score * 3 + (5 if won() else 0)


func status_text() -> String:
	return "第 %d/%d 次   猜中 %d" % [mini(round_no + (0 if next_number != 0 else 1), ROUNDS), ROUNDS, score]
