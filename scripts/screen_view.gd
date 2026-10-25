class_name ScreenView
extends Control
## 魔物蛋的小屏幕: 48 × 32 个点 (原版是 32 × 16 的黑白屏, 我们大一点、带颜色)。
## 画魔物走来走去、便便、生病的骷髅、睡觉的 Z、关灯; 也画「状态」那一页和猜左右的小游戏。

const W := 48
const H := 32

var game: Game
var mode := "pet"            # pet 平时 / status 看状态 / play 小游戏
var t := 0.0                 # 动画用的时间 (秒)
var pet_x := 16.0
var facing := 1              # 1 朝右, -1 朝左
var effect := ""             # 刚做完动作, 旁边冒一个小图标 (meal snack medicine note angry)
var effect_until := 0.0
var status_until := 0.0
var _move_timer := 0.0
var _rng := RandomNumberGenerator.new()

# 小游戏: 猜它往左还是往右 (照原版)
var play_round := 0
var play_wins := 0
var play_turn := 0           # 这一回合它跳向哪边: -1 左, 1 右, 0 还没跳
var play_hit := false
var play_until := 0.0


func px() -> float:
	return size.x / W


func _process(delta: float) -> void:
	t += delta
	if mode == "status" and t > status_until:
		mode = "pet"
	if mode == "play" and play_turn != 0 and t > play_until and play_round < Rules.GAME_ROUNDS:
		play_turn = 0
	_walk(delta)
	queue_redraw()


func _walk(delta: float) -> void:
	_move_timer += delta
	if _move_timer < 0.7:
		return
	_move_timer = 0.0
	var pet := game.pet if game != null else null
	if pet == null or not pet.can_act() or pet.asleep or mode != "pet":
		return
	if _rng.randf() < 0.3:
		facing = -facing
	pet_x += facing * 2
	var right := 23.0 if pet.poop > 0 else 31.0  # 有便便的话右边留给便便
	if pet_x <= 1.0 or pet_x >= right:
		pet_x = clampf(pet_x, 1.0, right)
		facing = -facing


func show_effect(name: String) -> void:
	effect = name
	effect_until = t + 1.6


func show_status() -> void:
	mode = "pet" if mode == "status" else "status"
	status_until = t + 6.0


func start_play() -> void:
	mode = "play"
	play_round = 0
	play_wins = 0
	play_turn = 0
	_rng.randomize()


## 猜一次 (-1 左, 1 右)。猜完 5 次回 true
func guess(dir: int) -> bool:
	if mode != "play" or play_turn != 0 or play_round >= Rules.GAME_ROUNDS:
		return false
	play_turn = -1 if _rng.randf() < 0.5 else 1
	play_hit = play_turn == dir
	if play_hit:
		play_wins += 1
	play_round += 1
	play_until = t + 0.9
	return play_round >= Rules.GAME_ROUNDS


# ---------------------------------------------------------------- 画

func _draw() -> void:
	var p := px()
	var pet := game.pet if game != null else null
	var dark := pet != null and not pet.lights and not pet.is_over()
	draw_rect(Rect2(Vector2.ZERO, size), Look.LCD_DARK if dark else Look.LCD)
	if pet == null:
		return
	match mode:
		"status":
			_draw_status(p, pet)
		"play":
			_draw_play(p, pet)
		_:
			_draw_pet(p, pet, dark)


func _text(pos: Vector2, s: String, p: float, color := Look.INK, scale := 4.2) -> void:
	draw_string(Look.font(), pos * p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(p * scale), color)


func _draw_pet(p: float, pet: Pet, dark: bool) -> void:
	var tint := Color(0.35, 0.35, 0.45) if dark else Color.WHITE
	if pet.stage == "dead":
		Art.draw(self, "ghost", Vector2(16, 10 + round(sin(t * 2.0) * 1.5)) * p, p)
		return
	if pet.stage == "gone":
		# 背着小包往右走, 走出屏幕
		var x := fmod(t * 5.0, W + 24.0) - 18.0
		Art.draw(self, pet.species, Vector2(x, 14 + (int(t * 2) % 2)) * p, p)
		Art.draw(self, "bag", Vector2(x - 3, 21) * p, p)
		return
	if pet.sitting():
		# 托给别人照看了: 屏幕上是别人家的小房子
		Art.draw(self, "house", Vector2(4, 6) * p, p * 2)
		_text(Vector2(23, 13), "托人照看中", p, Look.INK, 3.6)
		_text(Vector2(23, 21), "还剩", p, Look.INK, 3.2)
		_text(Vector2(23, 28), Game.sitter_text(pet.sitter_left()), p, Look.INK, 3.2)
		return
	if pet.stage == "egg":
		var left := pet.stage_at + Rules.STAGE_TIME.egg - pet.now
		var wobble := 0.0
		if left < 60 or int(t) % 4 == 0:
			wobble = round(sin(t * 14.0))  # 快孵了就一直摇, 平时偶尔摇一下
		Art.draw(self, "egg", Vector2(16 + wobble, 14) * p, p, false, tint)
		return
	for i in pet.poop:
		Art.draw(self, "poop", Vector2(41, 25 - i * 7) * p, p, false, tint)
	if pet.asleep:
		Art.draw(self, pet.species, Vector2(pet_x, 15) * p, p, facing < 0, tint * Color(0.85, 0.85, 0.9))
		var n := int(t * 1.5) % 3 + 1
		for i in n:
			Art.draw(self, "z", Vector2(pet_x + 14 + i * 4, 11 - i * 4) * p, p, false, Color.WHITE,
				Color("e8e8ff") if dark else Color(0, 0, 0, 0))
	else:
		var bob := 1 if int(t * 2.0) % 2 == 0 else 0
		Art.draw(self, pet.species, Vector2(pet_x, 14 + bob) * p, p, facing < 0, tint)
	if pet.sick:
		Art.draw(self, "skull", Vector2(1, 1) * p, p, false, tint)
	if pet.wants_leave:
		Art.draw(self, "bag", Vector2(pet_x + 16, 23) * p, p, false, tint)
	if effect != "" and t < effect_until:
		Art.draw(self, effect, Vector2(minf(pet_x + 17, W - 9), 5) * p, p, false, tint)


func _draw_status(p: float, pet: Pet) -> void:
	if pet.stage == "egg":
		var left := maxi(0, pet.stage_at + Rules.STAGE_TIME.egg - pet.now)
		_text(Vector2(3, 12), "还在蛋里", p)
		_text(Vector2(3, 22), "大约 %d 分钟后孵出来" % ceili(left / 60.0), p, Look.INK, 3.4)
		return
	if pet.is_over():
		_text(Vector2(3, 10), pet.display_name(), p)
		_text(Vector2(3, 19), "活了 %d 岁" % pet.age(), p, Look.INK, 3.6)
		_text(Vector2(3, 27), "离开了" if pet.stage == "gone" else "已经不在了", p, Look.INK, 3.6)
		return
	var lines := [["饿", pet.hunger], ["开心", pet.happy]]
	for i in lines.size():
		var y := 2 + i * 8
		_text(Vector2(2, y + 6), lines[i][0], p)
		for h in 4:
			Art.draw(self, "heart" if h < lines[i][1] else "heart_empty", Vector2(18 + h * 7, y) * p, p)
	_text(Vector2(2, 24), "管教", p)
	for b in 4:
		Art.draw(self, "block" if b < pet.discipline else "block_empty", Vector2(19 + b * 7, 19) * p, p)
	_text(Vector2(2, 31), "%d 岁   %d 克" % [pet.age(), pet.weight], p, Look.INK, 3.6)


func _draw_play(p: float, pet: Pet) -> void:
	_text(Vector2(2, 6), "第 %d/%d 次   猜中 %d" % [mini(play_round + (0 if play_turn != 0 else 1), Rules.GAME_ROUNDS),
		Rules.GAME_ROUNDS, play_wins], p, Look.INK, 3.6)
	var x := 16.0 + play_turn * 12
	Art.draw(self, pet.species, Vector2(x, 13) * p, p, play_turn < 0)
	if play_turn != 0:
		_text(Vector2(14 if play_turn > 0 else 2, 12), "猜中!" if play_hit else "没猜中", p, Look.INK, 3.6)
	elif play_round < Rules.GAME_ROUNDS:
		_text(Vector2(9, 12), "它会往哪边跳?", p, Look.INK, 3.4)
