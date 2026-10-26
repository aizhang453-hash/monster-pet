class_name ScreenView
extends Control
## 魔物蛋的小屏幕: 48 × 32 个点 (原版是 32 × 16 的黑白屏, 我们大一点、带颜色)。
## 画魔物走来走去、便便、生病的骷髅、睡觉的 Z、关灯; 「状态」那一页; 小游戏;
## 第二版: 房间布置 (墙纸、地毯、家具、墙上挂的) 和魔物身上的帽子、领结。

const W := 48
const H := 32
const PLAY_COLORS := {"red": Color("e8483a"), "yellow": Color("ffd84a"), "blue": Color("2f6fd0"), "green": Color("7cd36b")}

var game: Game
var mode := "pet"            # pet 平时 / status 看状态 / play 小游戏
var t := 0.0                 # 动画用的时间 (秒)
var pet_x := 16.0
var facing := 1              # 1 朝右, -1 朝左
var effect := ""             # 刚做完动作, 旁边冒一个小图标 (meal snack medicine note angry……)
var effect_until := 0.0
var status_until := 0.0
var minigame: MiniGame = null
# 第四版: 比赛的画面 (一下一下放出来) 和第二页状态
var battle: Dictionary = {}
var battle_step := 0
var battle_next := 0.0
var battle_done_at := 0.0
var status_page := 1
# 第三版: 出门的画面 (几秒钟)
var out_id := ""
var out_npc := ""
var out_item := ""
var out_until := 0.0
var _move_timer := 0.0
var _rng := RandomNumberGenerator.new()


func px() -> float:
	return size.x / W


func _process(delta: float) -> void:
	t += delta
	if mode == "status" and t > status_until:
		mode = "pet"
	if mode == "out" and t > out_until:
		mode = "pet"
	if mode == "battle":
		if battle_step < battle.log.size() and t >= battle_next:
			battle_step += 1
			battle_next = t + 0.7
			if battle_step >= battle.log.size():
				battle_done_at = t + 1.8
		elif battle_step >= battle.log.size() and t >= battle_done_at:
			mode = "pet"
	if mode == "play" and minigame != null:
		minigame.step(delta)
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


## 按「状态」: 第一页 (饿、开心、管教、岁数体重) → 第二页 (本事和比赛级别) → 回去
func show_status() -> void:
	if mode == "status" and status_page == 1:
		status_page = 2
	elif mode == "status":
		mode = "pet"
		return
	else:
		mode = "status"
		status_page = 1
	status_until = t + 6.0


func show_battle(res: Dictionary) -> void:
	battle = res
	battle_step = 0
	battle_next = t + 0.8
	battle_done_at = t + 999.0
	mode = "battle"


func battle_over() -> bool:
	return mode != "battle"


func show_outing(id: String, npc: String, item: String) -> void:
	out_id = id
	out_npc = npc
	out_item = item
	out_until = t + 3.5
	mode = "out"


func start_play(id: String, rng_seed := 0) -> void:
	minigame = MiniGames.make(id, rng_seed)
	mode = "play"


func stop_play() -> void:
	minigame = null
	mode = "pet"


# ---------------------------------------------------------------- 画

func _draw() -> void:
	var p := px()
	var pet := game.pet if game != null else null
	var dark := pet != null and not pet.lights and not pet.is_over() and mode == "pet"
	var bg := Look.LCD
	if pet != null and Species.PLACE_LOOK.has(pet.place):
		bg = Color(Species.PLACE_LOOK[pet.place][0])  # 第三版: 住的地方不同, 底色不同
	if game != null and game.equip.has("wall"):
		bg = Color(Items.DATA[game.equip.wall].color)
	if mode == "out" and Outings.LOOK.has(out_id):
		bg = Color(Outings.LOOK[out_id][0])
	draw_rect(Rect2(Vector2.ZERO, size), Look.LCD_DARK if dark else bg)
	if pet == null:
		return
	match mode:
		"status":
			_draw_status(p, pet)
		"play":
			_draw_play(p, pet)
		"out":
			_draw_out(p, pet)
		"battle":
			_draw_battle(p, pet)
		_:
			_draw_pet(p, pet, dark)


func _text(pos: Vector2, s: String, p: float, color := Look.INK, scale := 4.2) -> void:
	draw_string(Look.font(), pos * p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(p * scale), color)


## 房间布置: 墙上挂的、地毯、左边的家具 (魔物从前面走过)
func _draw_room(p: float, tint: Color) -> void:
	if game.equip.has("decor"):
		Art.draw(self, Items.ICON[game.equip.decor], Vector2(3, 3) * p, p, false, tint)
	var ground := ""
	if game.equip.has("rug"):
		ground = Items.DATA[game.equip.rug].color
	elif Species.PLACE_LOOK.has(game.pet.place):
		ground = Species.PLACE_LOOK[game.pet.place][1]  # 没铺地毯的话, 地面是住的地方的颜色
	if ground != "":
		draw_rect(Rect2(Vector2(0, 30) * p, Vector2(W, 2) * p), Color(ground) * tint)
	if game.equip.has("furniture"):
		var id: String = game.equip.furniture
		var s := Art.size_of(Items.ICON[id])
		Art.draw(self, Items.ICON[id], Vector2(1, 30 - s.y) * p, p, false, tint)


## 魔物 + 它的帽子、领结 (pos 是魔物图的左上角)
func _draw_monster(p: float, species: String, pos: Vector2, flip: bool, tint: Color) -> void:
	Art.draw(self, species, pos * p, p, flip, tint)
	var d: Dictionary = Species.DATA[species]
	if not d.has("hat"):
		return
	if game.equip.has("neck"):
		var n: String = Items.ICON[game.equip.neck]
		var s := Art.size_of(n)
		Art.draw(self, n, (pos + Vector2(8 - s.x / 2.0, d.neck)) * p, p, flip, tint)
	if game.equip.has("hat"):
		var h: String = Items.ICON[game.equip.hat]
		var s := Art.size_of(h)
		Art.draw(self, h, (pos + Vector2(8 - s.x / 2.0, d.hat - s.y)) * p, p, flip, tint)


func _draw_pet(p: float, pet: Pet, dark: bool) -> void:
	var tint := Color(0.35, 0.35, 0.45) if dark else Color.WHITE
	if pet.stage == "dead":
		Art.draw(self, "ghost", Vector2(16, 10 + round(sin(t * 2.0) * 1.5)) * p, p)
		return
	if pet.stage == "gone":
		# 背着小包往右走, 走出屏幕
		var x := fmod(t * 5.0, W + 24.0) - 18.0
		_draw_monster(p, pet.species, Vector2(x, 14 + (int(t * 2) % 2)), false, Color.WHITE)
		Art.draw(self, "bag", Vector2(x - 3, 21) * p, p)
		return
	if pet.sitting():
		# 托给别人照看了: 屏幕上是别人家的小房子
		Art.draw(self, "house", Vector2(4, 6) * p, p * 2)
		_text(Vector2(23, 13), "托人照看中", p, Look.INK, 3.6)
		_text(Vector2(23, 21), "还剩", p, Look.INK, 3.2)
		_text(Vector2(23, 28), Game.sitter_text(pet.sitter_left()), p, Look.INK, 3.2)
		return
	if pet.in_hotel():
		# 住旅馆: 旅馆的楼
		Art.draw(self, "hotel", Vector2(4, 6) * p, p * 2)
		_text(Vector2(24, 13), "住旅馆", p, Look.INK, 3.6)
		_text(Vector2(24, 21), "去接还剩", p, Look.INK, 3.2)
		_text(Vector2(24, 28), Game.sitter_text(maxi(0, pet.hotel_until - pet.now)), p, Look.INK, 3.2)
		return
	_draw_room(p, tint)
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
		_draw_monster(p, pet.species, Vector2(pet_x, 15), facing < 0, tint * Color(0.85, 0.85, 0.9))
		var n := int(t * 1.5) % 3 + 1
		for i in n:
			Art.draw(self, "z", Vector2(pet_x + 14 + i * 4, 11 - i * 4) * p, p, false, Color.WHITE,
				Color("e8e8ff") if dark else Color(0, 0, 0, 0))
	else:
		var bob := 1 if int(t * 2.0) % 2 == 0 else 0
		_draw_monster(p, pet.species, Vector2(pet_x, 14 + bob), facing < 0, tint)
	if pet.sick:
		Art.draw(self, "skull", Vector2(33, 1) * p, p, false, tint)
	if pet.wants_leave:
		Art.draw(self, "bag", Vector2(pet_x + 16, 23) * p, p, false, tint)
	if effect != "" and t < effect_until:
		var s := Art.size_of(effect)
		Art.draw(self, effect, Vector2(minf(pet_x + 17, W - s.x - 1), 5) * p, p, false, tint)


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
	if status_page == 2:
		_draw_status_2(p, pet)
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


## 出门的画面: 那个地方的底色和地面, 魔物走过去, 碰到的魔物站在右边, 带回来的东西冒在头上
func _draw_out(p: float, pet: Pet) -> void:
	var look: Array = Outings.LOOK.get(out_id, ["dfe9d3", "8cc06a"])
	draw_rect(Rect2(Vector2(0, 30) * p, Vector2(W, 2) * p), Color(look[1]))
	if out_id == "night":
		for i in 6:  # 夜市的小灯笼
			Art.draw(self, "lantern", Vector2(3 + i * 8, 2 + (i % 2) * 2) * p, p)
	var elapsed := 3.5 - (out_until - t)
	var x := 2.0 + minf(elapsed * 4.0, 10.0)  # 走过去, 走到碰到的魔物跟前停下
	_draw_monster(p, pet.species, Vector2(x, 14 + (int(t * 3) % 2)), false, Color.WHITE)
	if out_npc != "":
		_draw_monster(p, out_npc, Vector2(29, 14), true, Color.WHITE)
	if out_item != "" and out_until - t < 2.2:
		Art.draw(self, out_item, Vector2(x + 4, 4) * p, p)


## 状态第二页: 三样本事 (练出来的 + 天生的) 和比赛级别
func _draw_status_2(p: float, pet: Pet) -> void:
	var i := 0
	for s in Training.STATS:
		var y := 1 + i * 7.5
		Art.draw(self, Training.DRILLS[s][1], Vector2(2, y) * p, p)
		_text(Vector2(12, y + 6), "%s %d" % [Training.STATS[s], pet.stat(s)], p, Look.INK, 3.8)
		i += 1
	var level := "还没赢过" if pet.rank == 0 else "赢过%s赛" % Training.RANK_NAMES[pet.rank - 1]
	Art.draw(self, "trophy", Vector2(2, 24) * p, p)
	_text(Vector2(12, 31), level, p, Look.INK, 3.6)


## 比赛: 我在左边, 对手在右边, 上面两条血, 打一下往前冲一下
func _draw_battle(p: float, pet: Pet) -> void:
	var moves: Array = battle.log
	var shown := mini(battle_step, moves.size())
	var hp_me: int = battle.full_me
	var hp_foe: int = battle.full_foe
	var cur: Dictionary = {}
	if shown > 0:
		cur = moves[shown - 1]
		hp_me = cur.hp_me
		hp_foe = cur.hp_foe
	_bar(Vector2(2, 2), float(hp_me) / battle.full_me, p)
	_bar(Vector2(26, 2), float(hp_foe) / battle.full_foe, p)
	var lunge := 0.0
	var fresh := t < battle_next - 0.35 and not cur.is_empty()
	if fresh:
		lunge = 4.0
	var me_x := 2.0 + (lunge if cur.get("who", "") == "me" else 0.0)
	var foe_x := 30.0 - (lunge if cur.get("who", "") == "foe" else 0.0)
	_draw_monster(p, pet.species, Vector2(me_x, 14), false, Color.WHITE)
	_draw_monster(p, battle.foe_species, Vector2(foe_x, 14), true, Color.WHITE)
	if fresh:
		var target_x := 30.0 if cur.who == "me" else 4.0
		_text(Vector2(target_x, 12), "躲开!" if cur.dodge else "-%d" % cur.dmg, p, Look.CALL if not cur.dodge else Look.INK, 3.6)
	if shown >= moves.size() and moves.size() > 0 and t >= battle_next - 0.35:
		_text(Vector2(17, 12), "赢了!" if battle.won else "输了", p, Look.INK, 4.4)


func _bar(pos: Vector2, frac: float, p: float) -> void:
	draw_rect(Rect2(pos * p, Vector2(20, 3) * p), Look.INK)
	draw_rect(Rect2((pos + Vector2(0.5, 0.5)) * p, Vector2(19 * clampf(frac, 0, 1), 2) * p),
		Color("7cd36b") if frac > 0.3 else Color("e8483a"))


# ---------------------------------------------------------------- 小游戏

func _draw_play(p: float, pet: Pet) -> void:
	var g := minigame
	if g == null:
		return
	match g.id:
		"guess":
			var guess := g as GuessGame
			var x := 16.0 + guess.turn * 12
			_draw_monster(p, pet.species, Vector2(x, 13), guess.turn < 0, Color.WHITE)
			if guess.turn != 0:
				_text(Vector2(14 if guess.turn > 0 else 2, 12), "猜中!" if guess.hit else "没猜中", p, Look.INK, 3.6)
			elif not guess.done:
				_text(Vector2(9, 12), "它会往哪边跳?", p, Look.INK, 3.4)
		"catch":
			var c := g as CatchGame
			for f in c.fruits:
				Art.draw(self, "berry", Vector2(f.x, f.y) * p, p)
			_draw_monster(p, pet.species, Vector2(c.pet_x, 15), false, Color.WHITE)
		"jump":
			var j := g as JumpGame
			draw_rect(Rect2(Vector2(0, 30) * p, Vector2(W, 2) * p), Color("8a7a5a"))
			for r in j.rocks:
				Art.draw(self, "rock", Vector2(r.x, 24) * p, p)
			_draw_monster(p, pet.species, Vector2(JumpGame.PET_X, 14 - j.height()), false, Color.WHITE)
		"memory":
			var m := g as MemoryGame
			for i in MemoryGame.COLORS.size():
				var c: String = MemoryGame.COLORS[i]
				var r := Rect2(Vector2(3 + i * 11, 12), Vector2(9, 15))
				var col: Color = PLAY_COLORS[c]
				if m.lit == c:
					draw_rect(Rect2((r.position - Vector2(1, 1)) * p, (r.size + Vector2(2, 2)) * p), Look.INK)
					draw_rect(Rect2(r.position * p, r.size * p), col.lightened(0.15))
				else:
					draw_rect(Rect2(r.position * p, r.size * p), col.lerp(Look.LCD, 0.65))
