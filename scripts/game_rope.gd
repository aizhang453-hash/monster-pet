class_name RopeGame
extends MiniGame
## 跳绳 (学拓麻歌子 V4 宝宝玩的): 绳子一圈一圈甩, 甩到脚下的时候要在空中。跳过 10 下以上算赢, 最多 20 下, 绊到就结束。

const MAX := 20
const WIN := 10
const AIR := 0.5           # 跳一下在空中多久
const SAFE := [0.06, 0.44] # 跳起来以后, 这段时间绳子过脚下算跳过

var phase := 0.3           # 绳子转到哪了 (0 / 1 = 在脚下, 0.5 = 在头上)
var period := 1.3          # 绳子转一圈多久, 越来越快
var jump_t := -1.0
var tripped := false


func buttons() -> Array:
	return [["jump", "跳!"]]


func press(_action: String) -> void:
	if not done and jump_t < 0:
		jump_t = 0.0


func height() -> float:
	if jump_t < 0:
		return 0.0
	return 8.0 * sin(PI * jump_t / AIR)


func step(dt: float) -> void:
	if done:
		return
	t += dt
	if jump_t >= 0:
		jump_t += dt
		if jump_t >= AIR:
			jump_t = -1.0
	var before := phase
	phase += dt / period
	if phase >= 1.0:  # 绳子刚过脚下
		phase -= 1.0
		if jump_t >= SAFE[0] and jump_t <= SAFE[1]:
			score += 1
			period = maxf(0.6, period - 0.04)
			if score >= MAX:
				done = true
		elif before > 0.0:
			tripped = true
			done = true


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score + (5 if won() else 0)


func status_text() -> String:
	return "跳了 %d 下" % score + ("   绊倒了!" if tripped else "")
