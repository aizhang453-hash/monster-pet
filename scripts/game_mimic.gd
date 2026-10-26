class_name MimicGame
extends MiniGame
## 模仿姿势 (学拓麻歌子 V4): 对面摆一个姿势 (往左、举手、往右), 你的魔物一直换姿势, 换到一样的时候按「就是这个!」。5 次对 3 次以上算赢。
## 一次 5 秒没按算没学对; 越到后面换得越快。

const POSES := ["left", "up", "right"]
const ARROWS := {"left": "←", "up": "↑", "right": "→"}
const ROUNDS := 5
const WIN := 3
const CHANGE := 0.55       # 你的魔物多久换一个姿势 (一开始; 每一次快 0.04 秒)
const SHOW := 0.9
const ROUND_LIMIT := 5.0

var target := "up"
var mine := 0              # 你的魔物现在是第几个姿势
var round_no := 0
var hit := false
var picked := false
var _clock := 0.0
var _wait := 0.0
var _round_t := 0.0


func start() -> void:
	target = POSES[rng.randi() % 3]
	mine = rng.randi() % 3


func buttons() -> Array:
	return [["pick", "就是这个!"]]


func pose() -> String:
	return POSES[mine]


func press(_action: String) -> void:
	if done or picked:
		return
	_pick(pose() == target)


func _pick(ok: bool) -> void:
	picked = true
	hit = ok
	if hit:
		score += 1
	round_no += 1
	_wait = SHOW


func step(dt: float) -> void:
	t += dt
	if picked:
		_wait -= dt
		if _wait <= 0:
			picked = false
			if round_no >= ROUNDS:
				done = true
			else:
				target = POSES[rng.randi() % 3]
				_round_t = 0.0
		return
	_round_t += dt
	if _round_t >= ROUND_LIMIT:
		_pick(false)
		return
	_clock += dt
	var change := CHANGE - 0.04 * round_no
	if _clock >= change:
		_clock -= change
		mine = (mine + 1) % 3


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score * 3 + (5 if won() else 0)


func status_text() -> String:
	return "第 %d/%d 次   学对 %d" % [mini(round_no + (0 if picked else 1), ROUNDS), ROUNDS, score]
