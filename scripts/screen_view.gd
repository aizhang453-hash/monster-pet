class_name ScreenView
extends Control
## 魔物蛋的小屏幕: 48 × 32 个点 (原版是 32 × 16 的黑白屏, 我们大一点、带颜色)。
## 画魔物走来走去、便便、生病的骷髅、睡觉的 Z、关灯; 「状态」那一页; 小游戏;
## 第二版: 房间布置 (墙纸、地毯、家具、墙上挂的) 和魔物身上的帽子、领结。

const W := 48
const H := 32
signal pet_touched   # 第五版: 手指 (鼠标) 点到了魔物 (摸摸它)
signal pest_tapped   # 第八版: 点到了捣蛋精 (赶走它)

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
	var step_time := 0.7
	if game != null and game.pet != null and Personality.LIST.has(game.pet.personality):
		step_time = Personality.LIST[game.pet.personality].speed  # 第八版: 活泼的走得快, 悠闲的慢吞吞
	if game != null and game.pet != null and game.pet.old:
		step_time *= 1.6  # 第十版: 老了走得慢
	if _move_timer < step_time:
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


## 点到魔物身上 = 摸摸它
func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed or mode != "pet" or game == null or game.pet == null:
		return
	var at: Vector2 = event.position / px()
	if game.pet.pest_at > 0 and pest_rect().grow(2).has_point(at):
		pest_tapped.emit()
		accept_event()
		return
	if Rect2(pet_x, 12, 16, 19).has_point(at):
		pet_touched.emit()
		accept_event()


## 捣蛋精在屏幕上的位置 (右上角飘来飘去)
func pest_rect() -> Rect2:
	return Rect2(36 + round(sin(t * 1.7) * 3.0), 3 + round(sin(t * 2.9)), 8, 7)


func show_effect(name: String) -> void:
	effect = name
	effect_until = t + 1.6


## 按「状态」(照拓麻歌子: 平时屏幕上只有魔物, 名字岁数这些都在状态里看; 用户 2026-10-26 说「参考拓麻歌子系列」):
## 第一页名片 (名字、第几代、岁数、体重、在哪、难度、魔晶) → 第二页 (饿、开心、干净、管教) → 第三页 (本事和比赛级别)
## → 第四页 (聪明时尚善良和工作) → 回去
const STATUS_PAGES := 4


func show_status() -> void:
	if mode == "status" and status_page < STATUS_PAGES:
		status_page += 1
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


func start_play(id: String, rng_seed := 0, hard := false) -> void:
	minigame = MiniGames.make(id, rng_seed, hard)
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


## 你养的这只 (第七版: 带上遗传来的颜色和头上的特征)
func _draw_me(p: float, pos: Vector2, flip: bool, tint: Color) -> void:
	var pet := game.pet
	_draw_monster(p, pet.species, pos, flip, tint, pet.hue, pet.feature, pet.extra, pet.old)


## 魔物 + 它的帽子、领结 (pos 是魔物图的左上角); hue 遗传来的颜色 (-1 = 原来的), feature 头上的特征 (戴了帽子就盖住);
## extra 第九版身上的东西 (翅膀、尾巴, 少年起才有; 先画, 魔物盖在上面)
func _draw_monster(p: float, species: String, pos: Vector2, flip: bool, tint: Color, hue := -1.0, feature := "", extra := "",
		old := false) -> void:
	for part in Art.extra_parts(species, extra, flip):
		Art.draw(self, part[0], (pos + part[1]) * p, p, part[2], tint)
	if old:
		Art.draw(self, "cane", (pos + Art.cane_spot(species, flip)) * p, p, flip, tint)  # 第十版: 老了拄拐杖
	Art.draw(self, species, pos * p, p, flip, tint, Color(0, 0, 0, 0), Art.shift_for(species, hue))
	if old:
		for g in Art.glasses_pixels(species):  # 老花镜 (左右对称, 不用管翻没翻)
			draw_rect(Rect2((pos + Vector2(g)) * p, Vector2(p, p)), Art.GLASSES * tint)
	var d: Dictionary = Species.DATA[species]
	if not d.has("hat"):
		return
	if feature != "" and not game.equip.has("hat"):
		var fname := "feature_" + feature
		var fs := Art.size_of(fname)
		Art.draw(self, fname, (pos + Vector2(8 - fs.x / 2.0, d.hat - fs.y)) * p, p, flip, tint)
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
	if pet.stage == "gone" and pet.end_reason == "married" and not pet.partner.is_empty():
		# 第七版: 结婚了, 两只站在一起, 中间一颗心, 前面一颗蛋
		var pt: Dictionary = pet.partner
		_draw_me(p, Vector2(4, 13), false, Color.WHITE)
		_draw_monster(p, pt.species, Vector2(28, 13), true, Color.WHITE, float(pt.get("hue", -1.0)), str(pt.get("feature", "")),
			str(pt.get("extra", "")))
		Art.draw(self, "heart", Vector2(20.5, 4 + (int(t * 2) % 2)) * p, p)
		Art.draw(self, "egg", Vector2(20, 22) * p, p * 0.5)
		return
	if pet.stage == "gone":
		# 背着小包往右走, 走出屏幕
		var x := fmod(t * 5.0, W + 24.0) - 18.0
		_draw_me(p, Vector2(x, 14 + (int(t * 2) % 2)), false, Color.WHITE)
		Art.draw(self, "bag", Vector2(x - 3, 21) * p, p)
		return
	if pet.walking():
		# 第八版: 自己出去散步了, 家里空空的, 门口留着一串小脚印
		_draw_room(p, tint)
		for i in 4:
			Art.draw(self, "shoe", Vector2(6 + i * 8, 24 - (i % 2) * 2) * p, p * 0.5, false, Color(1, 1, 1, 0.6))
		_text(Vector2(4, 12), "出去散步啦", p, Look.INK, 4.2)
		_text(Vector2(4, 19), "大概 %s 后回来" % Game.sitter_text(maxi(60, pet.walk_until - pet.now)), p, Look.INK, 3.2)
		return
	if pet.sitting() and pet.sit_where == "parents" and not game.parents.is_empty():
		# 第七版: 在爸妈家, 屏幕上是爸妈
		var a: Dictionary = game.parents.a
		var b: Dictionary = game.parents.b
		var hop := int(t * 2) % 2
		Art.draw(self, "house", Vector2(26, 6) * p, p * 2)
		_mini(a.species, Vector2(1, 21 + hop), false, float(a.get("hue", -1.0)))
		_mini_me(Vector2(9.5, 22 + 1 - hop), false)
		_mini(b.species, Vector2(18, 21 + hop), true, float(b.get("hue", -1.0)))
		Art.draw(self, "heart", Vector2(10.5, 13 + hop) * p, p)
		_text(Vector2(1, 7), "还剩 " + Game.sitter_text(pet.sitter_left()), p, Look.INK, 3.0)
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
	var fest := game.festival()
	if fest != "":
		# 第六版: 过节的装饰挂在屏幕上面中间
		var deco: String = Festivals.LIST[fest].deco
		var ds := Art.size_of(deco)
		Art.draw(self, deco, Vector2(W / 2.0 - ds.x / 2.0, 1 + (int(t * 1.5) % 2)) * p, p, false, tint)
	if pet.stage == "egg":
		var left := pet.stage_at + Rules.STAGE_TIME.egg - pet.now
		var wobble := 0.0
		if left < 60 or int(t) % 4 == 0:
			wobble = round(sin(t * 14.0))  # 快孵了就一直摇, 平时偶尔摇一下
		Art.draw(self, "egg", Vector2(16 + wobble, 14) * p, p, false, tint)
		if Species.line_of(pet.pair) != "":
			# 第九版: 大奖的蛋闪闪发光 (两边的小星星轮流亮)
			var on := int(t * 3.0) % 2
			Art.draw(self, "twinkle", Vector2(13, 14 + on * 6) * p, p, false, tint)
			Art.draw(self, "twinkle", Vector2(32, 20 - on * 6) * p, p, false, tint)
		return
	for i in pet.poop:
		Art.draw(self, "poop", Vector2(41, 25 - i * 7) * p, p, false, tint)
	if pet.asleep:
		_draw_me(p, Vector2(pet_x, 15), facing < 0, tint * Color(0.85, 0.85, 0.9))
		var n := int(t * 1.5) % 3 + 1
		for i in n:
			Art.draw(self, "z", Vector2(pet_x + 14 + i * 4, 11 - i * 4) * p, p, false, Color.WHITE,
				Color("e8e8ff") if dark else Color(0, 0, 0, 0))
	else:
		var bob := 1 if int(t * 2.0) % 2 == 0 else 0
		_draw_me(p, Vector2(pet_x, 14 + bob), facing < 0, tint)
		if pet.tidy <= 1:
			# 第六版: 脏了身上有泥点, 脏透了头上冒臭气
			Art.draw(self, "dirt", Vector2(pet_x + 4, 24 + bob) * p, p, false, tint)
			Art.draw(self, "dirt", Vector2(pet_x + 10, 21 + bob) * p, p, false, tint)
			if pet.tidy == 0:
				for i in 2:
					var wave := 1 if (int(t * 3.0) + i) % 2 == 0 else 0
					draw_line(Vector2(pet_x + 5 + i * 5 + wave, 9 + bob) * p, Vector2(pet_x + 6 + i * 5 - wave, 12 + bob) * p,
						Color("8a9a5a") * tint, p * 0.7)
	if game.equip.has("buddy"):
		# 第八版: 小宠物跟在它旁边, 一跳一跳的
		var bud: String = Items.ICON[game.equip.buddy]
		var bx := pet_x - 7 if facing > 0 else pet_x + 17
		var hop := 0 if pet.asleep or int(t * 3.0) % 2 == 0 else 1
		Art.draw(self, bud, Vector2(clampf(bx, 0, W - 6), 24 - hop) * p, p, facing < 0, tint)
	if pet.pest_at > 0 and not pet.asleep:
		var pr := pest_rect()
		Art.draw(self, "pest", pr.position * p, p, int(t * 2) % 2 == 0, tint)
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
	if status_page == 1:
		_draw_card(p, pet)
		return
	if status_page == 3:
		_draw_status_2(p, pet)
		return
	if status_page == 4:
		_draw_status_3(p, pet)
		return
	var lines := [["饿", pet.hunger], ["开心", pet.happy]]
	for i in lines.size():
		var y := 1 + i * 7
		_text(Vector2(2, y + 6), lines[i][0], p)
		for h in 4:
			Art.draw(self, "heart" if h < lines[i][1] else "heart_empty", Vector2(18 + h * 7, y) * p, p)
	# 第六版: 干净 (泡泡)
	_text(Vector2(2, 21), "干净", p)
	for b in 4:
		Art.draw(self, "bubble", Vector2(18 + b * 7, 15) * p, p, false, Color.WHITE if b < pet.tidy else Color(0.45, 0.45, 0.5, 0.5))
	_text(Vector2(2, 28), "管教", p)
	for b in 4:
		Art.draw(self, "block" if b < pet.discipline else "block_empty", Vector2(19 + b * 7, 24) * p, p)


## 名片上的几行字 (名字, 然后三行小字); 测试也看这个
func card_lines(pet: Pet) -> Array:
	var where: String = Species.PLACES[pet.place].name
	if pet.sitting():
		where = "在爸妈家" if pet.sit_where == "parents" else "托人照看中"
	elif pet.in_hotel():
		where = "住旅馆"
	else:
		where = "住在" + where
	var gen := "第 %d 代 · " % pet.gen if pet.gen > 1 else ""
	if pet.walking():
		where = "出去散步了"
	var mood := " · 性格%s" % Personality.name_of(pet.personality) if pet.personality != "" else ""
	return [pet.display_name() + (" · 老啦" if pet.old else ""), "%s%d 岁 · %d 克" % [gen, pet.age(), pet.weight],
		where + mood, "魔晶 %d · %s" % [game.money, Rules.DIFFICULTY_NAMES[pet.difficulty]]]


## 状态第一页: 名片 (左上名字, 右上它的样子, 下面几行小字)
func _draw_card(p: float, pet: Pet) -> void:
	var lines := card_lines(pet)
	_text(Vector2(2, 8), lines[0], p, Look.INK, 5.6)
	_mini_me(Vector2(38, 1), false)
	draw_rect(Rect2(Vector2(2, 11) * p, Vector2(W - 4, 0.4) * p), Color(Look.INK, 0.4))
	_text(Vector2(2, 18), lines[1], p, Look.INK, 3.6)
	_text(Vector2(2, 24.5), lines[2], p, Look.INK, 3.6)
	Art.draw(self, "coin", Vector2(2, 26.5) * p, p * 0.6)
	_text(Vector2(7, 31), lines[3], p, Look.INK, 3.6)


## 出门的画面: 那个地方的底色和地面, 魔物走过去, 碰到的魔物站在右边, 带回来的东西冒在头上
func _draw_out(p: float, pet: Pet) -> void:
	var look: Array = Outings.LOOK.get(out_id, ["dfe9d3", "8cc06a"])
	draw_rect(Rect2(Vector2(0, 30) * p, Vector2(W, 2) * p), Color(look[1]))
	if out_id == "food":
		for i in 8:  # 美食街的小店雨棚, 红白条纹
			draw_rect(Rect2(Vector2(i * 6, 0) * p, Vector2(6, 4) * p), Color("e8483a") if i % 2 == 0 else Color("fff6ea"))
	if out_id == "night":
		for i in 6:  # 夜市的小灯笼
			Art.draw(self, "lantern", Vector2(3 + i * 8, 2 + (i % 2) * 2) * p, p)
	var elapsed := 3.5 - (out_until - t)
	var x := 2.0 + minf(elapsed * 4.0, 10.0)  # 走过去, 走到碰到的魔物跟前停下
	_draw_me(p, Vector2(x, 14 + (int(t * 3) % 2)), false, Color.WHITE)
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


## 状态第三页 (第五版): 上学练的三样本事和工作
func _draw_status_3(p: float, pet: Pet) -> void:
	var i := 0
	for s in School.SUBJECTS:
		_text(Vector2(3, 7 + i * 7.5), "%s %d" % [School.SUBJECTS[s].stat, pet.ability(s)], p, Look.INK, 3.8)
		i += 1
	var work: String = "还没有工作" if pet.job == "" else "工作: " + School.JOBS[pet.job].name
	_text(Vector2(3, 30), work, p, Look.INK, 3.6)


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
	_draw_me(p, Vector2(me_x, 14), false, Color.WHITE)
	_draw_monster(p, battle.foe_species, Vector2(foe_x, 14), true, Color.WHITE)
	if fresh:
		var target_x := 30.0 if cur.who == "me" else 4.0
		_text(Vector2(target_x, 12), "躲开!" if cur.dodge else "-%d" % cur.dmg, p, Look.CALL if not cur.dodge else Look.INK, 3.6)
	if shown >= moves.size() and moves.size() > 0 and t >= battle_next - 0.35:
		_text(Vector2(17, 12), "赢了!" if battle.won else "输了", p, Look.INK, 4.4)


## 小一号的魔物 (8 × 8 个点那么大)
func _mini(species: String, pos: Vector2, flip: bool, hue := -1.0) -> void:
	var p := px()
	Art.draw(self, species, pos * p, p * 0.5, flip, Color.WHITE, Color(0, 0, 0, 0), Art.shift_for(species, hue))


func _mini_me(pos: Vector2, flip: bool) -> void:
	_mini(game.pet.species, pos, flip, game.pet.hue)


func _rope(p: float, y: float) -> void:
	draw_rect(Rect2(Vector2(8, y) * p, Vector2(32, 0.8) * p), Color("c8504a"))


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
			_draw_me(p, Vector2(x, 13), guess.turn < 0, Color.WHITE)
			if guess.turn != 0:
				_text(Vector2(14 if guess.turn > 0 else 2, 12), "猜中!" if guess.hit else "没猜中", p, Look.INK, 3.6)
			elif not guess.done:
				_text(Vector2(9, 12), "它会往哪边跳?", p, Look.INK, 3.4)
		"catch":
			var c := g as CatchGame
			for f in c.fruits:
				Art.draw(self, "berry", Vector2(f.x, f.y) * p, p)
			_draw_me(p, Vector2(c.pet_x, 15), false, Color.WHITE)
		"jump":
			var j := g as JumpGame
			draw_rect(Rect2(Vector2(0, 30) * p, Vector2(W, 2) * p), Color("8a7a5a"))
			for r in j.rocks:
				Art.draw(self, "rock", Vector2(r.x, 24) * p, p)
			_draw_me(p, Vector2(JumpGame.PET_X, 14 - j.height()), false, Color.WHITE)
		"quiz_smart", "quiz_style", "quiz_kind":
			var qz := g as QuizGame
			var q := qz.question()
			var y := 9.0
			if q.icon != "":
				var s := Art.size_of(q.icon)
				Art.draw(self, q.icon, Vector2(24 - s.x, 2) * p, p * 2)
				y = 23.0
			_text(Vector2(2, y), q.text, p, Look.INK, 4.0 if q.icon != "" else 4.4)
			if qz.picked >= 0:
				var line: String = "答对了!" if qz.right else "答错了, 是「%s」" % q.options[q.answer]
				_text(Vector2(2, y + 7), line, p, Look.CALL if not qz.right else Look.INK, 3.6)
		"number":
			var ng := g as NumberGame
			_text(Vector2(8, 22), str(ng.current), p, Look.INK, 14.0)
			if ng.next_number != 0:
				_text(Vector2(22, 22), "→ %d" % ng.next_number, p, Look.INK, 9.0)
				_text(Vector2(8, 30), "猜中!" if ng.hit else "没猜中", p, Look.INK, 3.6)
			else:
				_text(Vector2(24, 16), "下一个", p, Look.INK, 3.6)
				_text(Vector2(24, 23), "大还是小?", p, Look.INK, 3.6)
		"rope":
			var rg := g as RopeGame
			var rope_y := 22.0 + 9.0 * cos(TAU * rg.phase)
			var behind := cos(TAU * rg.phase) < 0
			draw_rect(Rect2(Vector2(6, 14) * p, Vector2(2, 17) * p), Color("8a7a5a"))
			draw_rect(Rect2(Vector2(40, 14) * p, Vector2(2, 17) * p), Color("8a7a5a"))
			if behind:
				_rope(p, rope_y)
			_draw_me(p, Vector2(16, 14 - rg.height()), false, Color.WHITE)
			if not behind:
				_rope(p, rope_y)
		"climb":
			var cg := g as ClimbGame
			draw_rect(Rect2(Vector2(20, 0) * p, Vector2(8, 32) * p), Color("8a6a4a"))
			Art.draw(self, "trophy", Vector2(20, 0) * p, p)
			var cy := 24.0 - 22.0 * float(cg.score) / ClimbGame.GOAL
			_mini_me(Vector2(20, cy), cg.last == "r")
		"tug":
			var tg := g as TugGame
			var mark_x := 24.0 + tg.mark * 1.6
			draw_rect(Rect2(Vector2(4, 25) * p, Vector2(40, 1) * p), Color("b0804a"))
			draw_rect(Rect2(Vector2(24, 20) * p, Vector2(0.5, 10) * p), Look.INK)
			draw_rect(Rect2(Vector2(mark_x - 1, 23) * p, Vector2(2, 5) * p), Look.CALL)
			_mini_me(Vector2(0 + minf(0, tg.mark) * 0.3, 18), false)
			_mini("nigui", Vector2(40 + maxf(0, tg.mark) * 0.3, 18), true)
		"mimic":
			var mg := g as MimicGame
			_draw_me(p, Vector2(2, 14), false, Color.WHITE)
			_mini("yishou", Vector2(36, 18), true)
			_text(Vector2(9, 12), MimicGame.ARROWS[mg.pose()], p, Look.INK, 7.0)
			_text(Vector2(37, 15), MimicGame.ARROWS[mg.target], p, Look.CALL, 6.0)
			if mg.picked:
				_text(Vector2(20, 30), "学对了!" if mg.hit else "不对", p, Look.INK, 3.6)
		"flag":
			var fg := g as FlagGame
			_draw_me(p, Vector2(16, 14), false, Color.WHITE)
			# 两只手各拿一面旗: 左手红旗, 右手白旗; 举起来的那面高一点
			for side in [["red", 11.0, Color("e8483a")], ["white", 35.0, Color("ffffff")]]:
				var top: float = 8.0 if fg.raised == side[0] else 17.0
				draw_rect(Rect2(Vector2(side[1], top) * p, Vector2(0.8, 10) * p), Color("6e4a2a"))
				var flag_x: float = side[1] - 5.0 if side[0] == "red" else side[1] + 0.8
				draw_rect(Rect2(Vector2(flag_x, top) * p, Vector2(5, 3.5) * p), side[2])
				draw_rect(Rect2(Vector2(flag_x, top) * p, Vector2(5, 3.5) * p), Look.INK, false, p * 0.3)
			if fg.order != "":
				_text(Vector2(2, 9), FlagGame.NAMES[fg.order], p, Look.CALL if fg.order != "none" else Look.INK, 5.0)
			if fg.answered:
				_text(Vector2(26, 9), "对!" if fg.hit else "错!", p, Look.INK, 4.4)
		"sprint":
			var sg := g as SprintGame
			draw_rect(Rect2(Vector2(42, 8) * p, Vector2(1, 23) * p), Look.INK)
			draw_rect(Rect2(Vector2(0, 19) * p, Vector2(W, 0.5) * p), Color("8a7a5a"))
			draw_rect(Rect2(Vector2(0, 30) * p, Vector2(W, 0.5) * p), Color("8a7a5a"))
			_mini("nigui", Vector2(1 + sg.rival / SprintGame.GOAL * 33, 11), false)
			_mini_me(Vector2(1 + sg.me / SprintGame.GOAL * 33, 22), false)
		"dance":
			var dg := g as DanceGame
			var lanes := {"l": 12.0, "u": 22.0, "r": 32.0}
			draw_rect(Rect2(Vector2(6, DanceGame.LINE) * p, Vector2(36, 0.6) * p), Look.INK)
			for lane in lanes:
				_text(Vector2(lanes[lane], DanceGame.LINE + 5), DanceGame.ARROWS[lane], p,
					Look.CALL if dg.flash == lane else Color(Look.INK, 0.35), 4.4)
			for n in dg.notes:
				_text(Vector2(lanes[n.lane], n.y + 3), DanceGame.ARROWS[n.lane], p, Look.INK, 5.0)
			_mini_me(Vector2(38, 2 + (int(t * 4) % 2)), int(t * 2) % 2 == 0)
		"burger":
			var bg := g as BurgerGame
			_text(Vector2(2, 6), "客人要:", p, Look.INK, 3.2)
			for i in bg.order.size():
				draw_rect(Rect2(Vector2(4, 26 - i * 3.5) * p, Vector2(10, 3) * p), BurgerGame.COLORS[bg.order[i]])
			for i in bg.built.size():
				draw_rect(Rect2(Vector2(26, 28 - i * 3.5) * p, Vector2(14, 3) * p), BurgerGame.COLORS[bg.built[i]])
			_mini_me(Vector2(40, 22), true)
			if bg.result != "":
				_text(Vector2(18, 10), "做好了!" if bg.result == "ok" else "做错了……", p, Look.INK, 4.0)
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
