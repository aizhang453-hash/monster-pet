class_name MemoryGame
extends MiniGame
## 记颜色 (成年起): 屏幕上按顺序闪几种颜色, 记住了再按一遍。第一关 3 个, 每过一关多一个。
## 过 3 关以上算赢, 最多 6 关。按错就结束。(照拓麻歌子 V4 的「模仿」、Uni 的「跳舞」: 记住动作再做一遍)

const COLORS := ["red", "yellow", "blue", "green"]
const NAMES := {"red": "红", "yellow": "黄", "blue": "蓝", "green": "绿"}
const FIRST := 3
const MAX_ROUNDS := 6
const WIN := 3
const FLASH := 0.6
const GAP := 0.25

var seq: Array = []
var phase := "show"        # show 在闪 / input 轮到你按 / pause 过关了停一下 / over 结束
var shown := 0             # 闪到第几个
var typed := 0             # 你按对了几个
var lit := ""              # 现在亮着的颜色
var wrong := false
var _timer := 0.0


func start() -> void:
	for i in FIRST:
		seq.append(COLORS[rng.randi() % COLORS.size()])
	_begin_show()


func _begin_show() -> void:
	phase = "show"
	shown = 0
	typed = 0
	lit = ""
	_timer = 0.5


func buttons() -> Array:
	return [["red", "红"], ["yellow", "黄"], ["blue", "蓝"], ["green", "绿"]]


func press(action: String) -> void:
	if phase != "input":
		return
	lit = action
	_timer = 0.3
	if seq[typed] != action:
		wrong = true
		phase = "over"
		_timer = 0.8
		return
	typed += 1
	if typed >= seq.size():
		score += 1
		phase = "pause"
		_timer = 0.8
		if score >= MAX_ROUNDS:
			phase = "over"


func step(dt: float) -> void:
	if done:
		return
	t += dt
	_timer -= dt
	match phase:
		"show":
			if _timer <= 0:
				if lit != "":
					lit = ""
					shown += 1
					_timer = GAP
				elif shown < seq.size():
					lit = seq[shown]
					_timer = FLASH
				else:
					phase = "input"
		"input":
			if _timer <= 0:
				lit = ""
		"pause":
			if _timer <= 0:
				seq.append(COLORS[rng.randi() % COLORS.size()])
				_begin_show()
		"over":
			if _timer <= 0:
				done = true


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score * 4 + (5 if won() else 0)


func status_text() -> String:
	match phase:
		"show":
			return "第 %d 关: 记住顺序……" % (score + 1)
		"input":
			return "第 %d 关: 按一遍 (%d/%d)" % [score + 1, typed, seq.size()]
		"pause":
			return "过关了!"
	return "按错了……" if wrong else "全部过关!"
