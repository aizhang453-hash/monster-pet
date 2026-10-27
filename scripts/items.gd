class_name Items
extends RefCounted
## 商店里卖的东西 (第二版, 用户 2026-10-25 定的)。钱叫「魔晶」。
## 照拓麻歌子系列的做法 (On / Meets 那几代): 基本的饭和零食一直免费, 药也不花钱; 商店卖更好吃的、玩具、衣服配饰、房间布置。
## 衣服、配饰、家具只是好看, 不影响难度 (用户定的)。价钱都是我们定的, 改这里就行。
##
## kind: food 吃的 (吃了就没了) / toy 玩具 / hat 帽子 / neck 脖子上的 / wall 墙纸 / rug 地毯 / furniture 家具 (放左边) / decor 墙上挂的
## food 的效果: hunger 饱几颗心, happy 开心几颗心, weight 胖几克

const START_MONEY := 30            # 第一次玩送的魔晶
const MAX_STACK := 9               # 同一种吃的最多存几个
const TOY_COOLDOWN := 3 * 3600     # 一个玩具玩过以后, 过多久它才又想玩 (开心 +1, 不会胖)

const DATA := {
	"apple": {"name": "苹果", "kind": "food", "price": 8, "hunger": 1, "happy": 1, "weight": 1},
	"icecream": {"name": "冰淇淋", "kind": "food", "price": 10, "hunger": 0, "happy": 1, "weight": 1},
	"cake": {"name": "蛋糕", "kind": "food", "price": 15, "hunger": 0, "happy": 2, "weight": 3},
	"feast": {"name": "大餐", "kind": "food", "price": 20, "hunger": 4, "happy": 0, "weight": 3},
	# 第六版: 节日的吃的 (只在那个节日的商店卖, 节日礼物也会送)
	"dumpling": {"name": "饺子", "kind": "food", "price": 12, "hunger": 2, "happy": 1, "weight": 1, "festival": "spring"},
	"mooncake": {"name": "月饼", "kind": "food", "price": 12, "hunger": 1, "happy": 2, "weight": 2, "festival": "midautumn"},
	"pumpkin_candy": {"name": "南瓜糖", "kind": "food", "price": 6, "hunger": 0, "happy": 1, "weight": 1, "festival": "halloween"},

	"ball": {"name": "皮球", "kind": "toy", "price": 40},
	"blocks": {"name": "积木", "kind": "toy", "price": 60},
	"pinwheel": {"name": "小风车", "kind": "toy", "price": 80},

	"strawhat": {"name": "草帽", "kind": "hat", "price": 50},
	"wizardhat": {"name": "魔法帽", "kind": "hat", "price": 120},
	"crown": {"name": "小王冠", "kind": "hat", "price": 300},
	"bowtie": {"name": "红领结", "kind": "neck", "price": 40},
	"scarf": {"name": "毛围巾", "kind": "neck", "price": 70},

	# 第八版: 魔物养的小宠物 (学拓麻歌子 iD L、P's), 跟在它身边, 只是可爱
	"chick": {"name": "小黄鸡", "kind": "buddy", "price": 80},
	"bunny": {"name": "小白兔", "kind": "buddy", "price": 100},
	"jelly": {"name": "小果冻", "kind": "buddy", "price": 120},

	"wall_blue": {"name": "淡蓝墙纸", "kind": "wall", "price": 30, "color": "cfe6f2"},
	"wall_pink": {"name": "粉色墙纸", "kind": "wall", "price": 30, "color": "f6dbe4"},
	"wall_yellow": {"name": "淡黄墙纸", "kind": "wall", "price": 30, "color": "f5ecc8"},
	"rug_red": {"name": "红地毯", "kind": "rug", "price": 40, "color": "c8504a"},
	"rug_grass": {"name": "绿草地", "kind": "rug", "price": 40, "color": "6fb85a"},
	"plant": {"name": "盆栽", "kind": "furniture", "price": 50},
	"bed": {"name": "小床", "kind": "furniture", "price": 100},
	"painting": {"name": "挂画", "kind": "decor", "price": 60},
	"window": {"name": "小窗户", "kind": "decor", "price": 80},
}

## 东西的图 (像素图的名字); 墙纸、地毯用颜色块
const ICON := {"apple": "apple", "icecream": "icecream", "cake": "cake", "feast": "feast", "ball": "game",
	"dumpling": "dumpling", "mooncake": "mooncake", "pumpkin_candy": "snack",
	"blocks": "blocks", "pinwheel": "pinwheel", "strawhat": "strawhat", "wizardhat": "wizardhat", "crown": "crown",
	"chick": "chick", "bunny": "bunny", "jelly": "jelly",
	"bowtie": "bowtie", "scarf": "scarf", "plant": "plant", "bed": "bed", "painting": "painting", "window": "window"}


## 商店里的分类 (按顺序)
const SHOP := [["吃的", ["food"]], ["玩具", ["toy"]], ["小宠物", ["buddy"]], ["衣服配饰", ["hat", "neck"]],
	["房间", ["wall", "rug", "furniture", "decor"]]]
## 装扮: 一个地方放一样 (帽子一顶、脖子上一样、墙纸一种……)
const SLOTS := [["buddy", "小宠物"], ["hat", "帽子"], ["neck", "脖子上"], ["wall", "墙纸"], ["rug", "地毯"], ["furniture", "家具"], ["decor", "墙上"]]


static func name_of(id: String) -> String:
	return DATA[id].name


static func kind_of(id: String) -> String:
	return DATA[id].kind


## 纪念品 (第六版, 学拓麻歌子 V3): 出门偶尔带回来, 过节送一件。名字 + 图 + 在哪里得到
const SOUVENIRS := {
	"pebble": {"name": "圆石子", "icon": "pebble", "from": "公园"},
	"pinecone": {"name": "松果", "icon": "pinecone", "from": "森林"},
	"shell": {"name": "贝壳", "icon": "shell", "from": "湖边"},
	"lantern_charm": {"name": "灯笼挂件", "icon": "lantern", "from": "夜市"},
	"key": {"name": "旅馆钥匙扣", "icon": "key", "from": "旅馆"},
	"firework": {"name": "烟花徽章", "icon": "firework", "from": "新年"},
	"fu": {"name": "福字", "icon": "fu", "from": "春节"},
	"balloon": {"name": "气球", "icon": "balloon", "from": "儿童节"},
	"moon": {"name": "月亮挂饰", "icon": "moon", "from": "中秋节"},
	"pumpkin": {"name": "南瓜灯", "icon": "pumpkin", "from": "万圣节"},
	"snowman": {"name": "小雪人", "icon": "snowman", "from": "圣诞节"},
}
## 出门的地方 → 那里的纪念品
const OUTING_SOUVENIR := {"park": "pebble", "forest": "pinecone", "lakeside": "shell", "night": "lantern_charm", "hotel": "key"}


static func of_kinds(kinds: Array) -> Array:
	var out := []
	for id in DATA:
		if DATA[id].kind in kinds:
			out.append(id)
	return out


## 吃的有什么用 (写在商店按钮上)
static func food_text(id: String) -> String:
	return food_text_of(DATA[id])


static func food_text_of(d: Dictionary) -> String:
	var parts := []
	if d.hunger >= 4:
		parts.append("吃得饱饱的")
	elif d.hunger > 0:
		parts.append("饱 +%d" % d.hunger)
	if d.happy > 0:
		parts.append("开心 +%d" % d.happy)
	parts.append("胖 %d 克" % d.weight)
	return "、".join(parts)
