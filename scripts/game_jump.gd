class_name JumpGame
extends MiniGame
## 跳石头 (少年起): 石头从右边滚过来, 按「跳」跳过去。一共 12 块, 跳过 8 块以上算赢。
## (照原版 V4 宝宝玩的跳绳: 看准时机按一下)

const TOTAL := 12
const WIN := 8
const PET_X := 4.0         # 魔物站在左边 (16 × 16 的图)
const HIT_LEFT := 9.0      # 撞到算的范围: 魔物身子中间这一段 (宽一点就跳不过去了)
const HIT_RIGHT := 15.0
const ROCK := 6.0          # 石头画 6 × 6 个点, 撞到只算中间 4 个点 (宽松一点)
const ROCK_HIT := [1.0, 5.0]
const SAFE := 4.0          # 跳到这么高就不会撞到
const ROLL := 18.0         # 石头一开始滚多快, 之后越来越快
const JUMP_TIME := 1.1
const JUMP_HIGH := 12.0

var rocks: Array = []      # [{x}] 正在滚的石头 (左边)
var sent := 0
var hits := 0
var jump_t := -1.0         # 跳起来多久了 (-1 = 在地上)
var _next := 1.0


func start() -> void:
	pass


func buttons() -> Array:
	return [["jump", "跳!"]]


func press(_action: String) -> void:
	if jump_t < 0 and not done:
		jump_t = 0.0


## 现在跳多高 (点)
func height() -> float:
	if jump_t < 0:
		return 0.0
	return JUMP_HIGH * sin(PI * jump_t / JUMP_TIME)


func step(dt: float) -> void:
	if done:
		return
	t += dt
	if jump_t >= 0:
		jump_t += dt
		if jump_t >= JUMP_TIME:
			jump_t = -1.0
	_next -= dt
	if _next <= 0 and sent < TOTAL:
		rocks.append({"x": 48.0, "hit": false})
		sent += 1
		_next = rng.randf_range(1.3, 2.3)
	for r in rocks.duplicate():
		r.x -= speed() * dt
		var overlap: bool = r.x + ROCK_HIT[0] < HIT_RIGHT and r.x + ROCK_HIT[1] > HIT_LEFT
		if overlap and not r.hit and height() < SAFE:
			r.hit = true
			hits += 1
		if r.x + ROCK < 0:
			if not r.hit:
				score += 1
			rocks.erase(r)
	if sent >= TOTAL and rocks.is_empty():
		done = true


## 石头现在滚多快 (点 / 秒)
func speed() -> float:
	return ROLL + sent * 1.2


func won() -> bool:
	return score >= WIN


func reward() -> int:
	return score + (5 if won() else 0)


func status_text() -> String:
	return "跳过 %d   撞到 %d   还有 %d" % [score, hits, TOTAL - sent + rocks.size()]
