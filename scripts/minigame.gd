class_name MiniGame
extends RefCounted
## 小游戏的底子: 每种小游戏 extends 它。只管规矩 (位置、分数、赢没赢), 画在 ScreenView 里。
## 坐标都是小屏幕上的点 (48 × 32)。step(秒) 让时间走; press / release 是按下 / 松开按钮。
## 哪个阶段能玩哪个、怎么做出来, 在 MiniGames 里。

var id := ""
var done := false
var score := 0
var t := 0.0
var rng := RandomNumberGenerator.new()
var buttons_version := 0   # 按钮要换的时候加一 (答题: 每道题的选项不一样)


func start() -> void:
	pass


## 下面的按钮: [[代号, 字], ...]
func buttons() -> Array:
	return []


## 按住才动的小游戏 (接果子) 回 true, 画面就用按下 / 松开; 不然只用按一下
func hold_buttons() -> bool:
	return false


func press(_action: String) -> void:
	pass


func release(_action: String) -> void:
	pass


func step(_dt: float) -> void:
	pass


func won() -> bool:
	return false


## 玩完给多少魔晶
func reward() -> int:
	return 0


## 屏幕上面那一行字
func status_text() -> String:
	return ""
