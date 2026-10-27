class_name Outings
extends RefCounted
## 出门 (第三版, 照拓麻歌子 On / Meets): 小孩起能出门, 去不同的地方逛, 马上去马上回。
## 公园和旅馆一开始就能去; 别的地方要做点小事才解锁 (On / Meets 也是这样: 吃几次某种东西、去某个地方几次、某个时间出门)。
## 去哪、怎么解锁、给什么都是我们定的, 改这里就行。

const LIST := [
	{"id": "park", "name": "公园", "unlock": "", "help": "说不定能碰到别的魔物一起玩"},
	{"id": "food", "name": "美食街", "unlock": "", "help": "花点魔晶, 带它去吃好吃的"},
	{"id": "forest", "name": "森林", "unlock": "去公园玩 5 次", "help": "到处翻翻, 可能捡到苹果或魔晶"},
	{"id": "lakeside", "name": "湖边", "unlock": "吃 5 个苹果", "help": "坐着钓会儿鱼"},
	{"id": "night", "name": "夜市", "unlock": "晚上 7 点到 9 点之间出一次门", "help": "热热闹闹的小摊, 有好吃的"},
	{"id": "hotel", "name": "旅馆", "unlock": "", "help": "花点魔晶寄放几个小时 (旅馆不管饭)"},
]
const START := ["park", "food", "hotel"]
## 美食街的店 (第八版, 学拓麻歌子 iD L 出门吃饭): 吃什么、多少魔晶、饱几颗心、开心几颗心、胖几克
const SHOPS := {
	"bakery": {"name": "面包店", "food": "刚出炉的面包", "icon": "bread", "price": 8, "hunger": 2, "happy": 0, "weight": 1},
	"sweets": {"name": "甜品店", "food": "草莓圣代", "icon": "sundae", "price": 12, "hunger": 0, "happy": 2, "weight": 2},
	"noodle": {"name": "拉面店", "food": "热腾腾的拉面", "icon": "ramen", "price": 18, "hunger": 4, "happy": 1, "weight": 2},
}
const SHOP_ORDER := ["bakery", "sweets", "noodle"]
const COOLDOWN := 2 * 3600        # 同一个地方隔多久才又有收获
const HOTEL_PRICE := 5            # 旅馆每小时几魔晶 (On / Meets 是每小时 10 点)
const HOTEL_HOURS := [2, 4, 8]
## 出门时屏幕的底色、地面的颜色
const LOOK := {"park": ["e3f2d0", "7cc06a"], "food": ["f6e7d2", "c89a6a"], "forest": ["cfe3c4", "4f8a3e"], "lakeside": ["d4ecf5", "5aa6d6"],
	"night": ["3a3456", "6a5a8a"], "hotel": ["f2e6d8", "b0804a"]}


static func info(id: String) -> Dictionary:
	for o in LIST:
		if o.id == id:
			return o
	return {}
