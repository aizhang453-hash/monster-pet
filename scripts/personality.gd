class_name Personality
extends RefCounted
## 性格 (第八版, 学拓麻歌子 Uni 选性格)。长成小孩的时候你帮它选一个, 选了就不改。
## 每种性格有一点小小的好处, 屏幕上走路的样子也不一样。种类、名字、好处都是我们定的, 改这里就行。
## speed: 在屏幕上走一步要多久 (秒; 平时 0.7)

const LIST := {
	"lively": {"name": "活泼", "help": "玩小游戏赢了多拿三成魔晶", "speed": 0.45},
	"shy": {"name": "害羞", "help": "摸摸它隔一小时就能再摸", "speed": 0.9},
	"mellow": {"name": "悠闲", "help": "变脏得慢一半", "speed": 1.2},
	"spoiled": {"name": "爱撒娇", "help": "吃零食不会胖", "speed": 0.7},
	"diligent": {"name": "认真", "help": "上课多涨 1", "speed": 0.6},
}
const ORDER := ["lively", "shy", "mellow", "spoiled", "diligent"]


static func name_of(id: String) -> String:
	return LIST[id].name if LIST.has(id) else ""
