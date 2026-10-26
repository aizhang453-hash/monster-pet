class_name TugGame
extends MiniGame
## 拔河 (学拓麻歌子 V4.5 小孩玩的): 一直按「拉!」, 把绳子中间的标记拉到你这边 (左边) 算赢; 12 秒到了标记在你这边也算赢。

const END := 10.0
const PULL := 0.6          # 按一下拉多少
const FOE := 1.6           # 对手每秒拉多少 (上下浮动)
const LIMIT := 12.0

var mark := 0.0            # 负数 = 在你这边, 正数 = 在对手那边


func buttons() -> Array:
	return [["pull", "拉!"]]


func press(_action: String) -> void:
	if not done:
		mark -= PULL


func step(dt: float) -> void:
	if done:
		return
	t += dt
	mark += FOE * dt * rng.randf_range(0.7, 1.3)
	if absf(mark) >= END or t >= LIMIT:
		mark = clampf(mark, -END, END)
		done = true


func won() -> bool:
	return mark < 0


func reward() -> int:
	return (12 if won() else 3) + (4 if mark <= -END else 0)


func status_text() -> String:
	return "拉到你这边了!" if mark < 0 else "加油, 拉过来!"
