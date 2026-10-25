class_name SaveGame
extends RefCounted
## 存档: 一个 JSON 文件。放在 dir 文件夹里 (平时是 Godot 给每个游戏的存档文件夹 user://)。
## 测试要把 dir 换成临时文件夹, 不碰玩家真的存档。

static var dir := "user://"
const FILE := "save.json"


static func path() -> String:
	return dir.path_join(FILE)


## 先写到旁边的临时文件, 写好了再换过去 (写到一半关掉游戏也不会坏)
static func write(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path()) == OK


## 读不到 (还没存过、坏了) 就给空的
static func read() -> Dictionary:
	if not FileAccess.file_exists(path()):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path())) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


static func erase() -> void:
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(path())
