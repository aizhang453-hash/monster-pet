class_name DanceGame
extends MiniGame
## 跳舞 (学拓麻歌子 Uni 和 V3): 箭头从上面掉下来, 掉到线上的时候按一样的箭头。16 个踩中 10 个以上算赢。

const LANES := ["l", "u", "r"]
const ARROWS := {"l": "←", "u": "↑", "r": "→"}
const TOTAL := 16
const WIN := 10
const LINE := 26.0
const NEAR := 3.0          # 离线多近算踩中
const FALL := 18.0
const GAP := 0.8

var notes: Array = []      # [{lane, y}]
var sent := 0
var missed := 0
var flash := ""            # 刚踩中的那一道 (画面亮一下)
var _next := 0.5


func buttons() -> Array:
	return [["l", "←"], ["u", "↑"], ["r", "→"]]


func press(action: String) -> void:
	if done:
		return
	var best: Dictionary = {}
	for n in notes:
		if n.lane == action and absf(n.y - LINE) <= NEAR and (best.is_empty() or absf(n.y - LINE) < absf(best.y - LINE)):
			best = n
	if not best.is_empty():
		notes.erase(best)
		score += 1
		flash = action


func step(dt: float) -> void:
	if done:
		return
	t += dt
	_next -= dt
	if _next <= 0 and sent < TOTAL:
		notes.append({"lane": LANES[rng.randi() % 3], "y": 0.0})
		sent += 1
		_next = GAP
	for n in notes.duplicate():
		n.y += FALL * dt
		if n.y > LINE + NEAR + 0.5:
			notes.erase(n)
			missed += 1
	if sent >= TOTAL and notes.is_empty():
		done = true


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score + (5 if won() else 0)


func status_text() -> String:
	return "踩中 %d   没踩到 %d   还有 %d" % [score, missed, TOTAL - sent + notes.size()]
