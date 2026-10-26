class_name FlagGame
extends MiniGame
## 举旗 (学拓麻歌子 V4): 听口令举旗: 「举红旗」按红旗, 「举白旗」按白旗, 「都别动」就什么都别按。越来越快。8 次对 6 次以上算赢。

const ROUNDS := 8
const WIN := 6
const SHOW := 0.7
const NAMES := {"red": "举红旗!", "white": "举白旗!", "none": "都别动!"}

var order := ""            # 现在的口令: red / white / none (空 = 等下一个)
var window := 1.5          # 多久之内要按
var round_no := 0
var hit := false
var answered := false
var raised := ""           # 这一次举了哪面旗 (画面用)
var _left := 0.0
var _wait := 0.6


func buttons() -> Array:
	return [["red", "红旗"], ["white", "白旗"]]


func press(action: String) -> void:
	if done or order == "" or answered:
		return
	raised = action
	_finish(action == order)


func _finish(ok: bool) -> void:
	answered = true
	hit = ok
	if ok:
		score += 1
	round_no += 1
	_wait = SHOW


func step(dt: float) -> void:
	if done:
		return
	t += dt
	if order != "" and not answered:
		_left -= dt
		if _left <= 0:
			_finish(order == "none")  # 「都别动」的时候忍住没按, 算对
		return
	_wait -= dt
	if _wait <= 0:
		if round_no >= ROUNDS:
			done = true
			return
		var r := rng.randf()
		order = "none" if r < 0.2 else ("red" if r < 0.6 else "white")
		answered = false
		raised = ""
		_left = window
		window = maxf(0.8, window - 0.08)


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score * 2 + (5 if won() else 0)


func status_text() -> String:
	return "第 %d/%d 次   对了 %d" % [mini(round_no + (0 if answered else 1), ROUNDS), ROUNDS, score]
