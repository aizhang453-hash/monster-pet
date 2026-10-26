class_name QuizGame
extends MiniGame
## 答题 (第五版: 上课和几份工作用): 一共 5 道题, 每道三个选项, 下面三个按钮就是三个选项。答对 3 题以上算赢。

const WIN := 3
const SHOW := 0.9      # 答完一题, 停多久显示对错

var kind := "smart"    # smart 数学 / style 美术 / kind 品德
var hard := false      # 医生、老师上班出难一点的 (有乘法)
var questions: Array = []
var current := 0
var picked := -1       # 这一题选了第几个 (-1 = 还没选)
var right := false
var _wait := 0.0


func start() -> void:
	questions = School.make_questions(kind, rng, hard)


func question() -> Dictionary:
	return questions[mini(current, questions.size() - 1)]


## 按钮跟着题目变: 「0」「1」「2」是第几个选项, 字是选项本身
func buttons() -> Array:
	var q := question()
	return [["0", q.options[0]], ["1", q.options[1]], ["2", q.options[2]]]


func press(action: String) -> void:
	if done or picked >= 0:
		return
	picked = int(action)
	right = picked == question().answer
	if right:
		score += 1
	_wait = SHOW


func step(dt: float) -> void:
	t += dt
	if picked >= 0:
		_wait -= dt
		if _wait <= 0:
			picked = -1
			current += 1
			buttons_version += 1  # 换题了, 按钮上的字要换
			if current >= questions.size():
				done = true


func won() -> bool:
	return score >= WIN


func status_text() -> String:
	return "第 %d/%d 题   答对 %d" % [mini(current + 1, questions.size()), questions.size(), score]
