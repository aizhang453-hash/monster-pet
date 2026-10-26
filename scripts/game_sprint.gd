class_name SprintGame
extends MiniGame
## 赛跑 (学拓麻歌子 V3): 一直按「跑!」, 比对手先跑到终点算赢 (15 秒内没跑到算输)。

const GOAL := 100.0
const STEP := 4.0          # 按一下跑多远
const RIVAL := 11.0        # 对手每秒跑多远 (上下浮动)
const LIMIT := 15.0

var me := 0.0
var rival := 0.0


func buttons() -> Array:
	return [["run", "跑!"]]


func press(_action: String) -> void:
	if not done:
		me = minf(GOAL, me + STEP)


func step(dt: float) -> void:
	if done:
		return
	t += dt
	rival = minf(GOAL, rival + RIVAL * dt * rng.randf_range(0.8, 1.2))
	if me >= GOAL or rival >= GOAL or t >= LIMIT:
		score = roundi(me)
		done = true


func won() -> bool:
	return me >= GOAL and me >= rival


func reward() -> int:
	return int(score / 10.0) + (8 if won() else 0)


func status_text() -> String:
	return "你 %d 米   对手 %d 米" % [roundi(me), roundi(rival)]
