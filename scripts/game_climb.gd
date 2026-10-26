class_name ClimbGame
extends MiniGame
## 爬高 (学拓麻歌子 V4.5 宝宝玩的): 左手、右手轮流按往上爬; 同一只手按两次会滑下来。12 秒内爬到 25 格算赢。

const GOAL := 25
const LIMIT := 12.0

var last := ""
var slips := 0


func buttons() -> Array:
	return [["l", "左手"], ["r", "右手"]]


func press(action: String) -> void:
	if done:
		return
	if action == last:
		score = maxi(0, score - 2)
		slips += 1
	else:
		score += 1
		last = action
		if score >= GOAL:
			done = true


func step(dt: float) -> void:
	if done:
		return
	t += dt
	if t >= LIMIT:
		done = true


func won() -> bool:
	return score >= GOAL


func reward() -> int:
	return int(score / 2.0) + (6 if won() else 0)


func status_text() -> String:
	return "爬了 %d / %d 格   还剩 %d 秒" % [score, GOAL, maxi(0, ceili(LIMIT - t))]
