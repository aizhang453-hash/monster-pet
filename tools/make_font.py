"""把思源黑体 (Noto Sans SC) 里游戏用到的字挑出来, 做成一个小字体文件放进 fonts/ (第四版, 手机上没有电脑里的字体)。

用法 (要先装 fonttools, 装在临时文件夹就行: python3 -m pip install --target <临时文件夹> fonttools):
    PYTHONPATH=<临时文件夹> python3 tools/make_font.py <NotoSansSC-Medium.otf 的位置>

字体从 https://github.com/notofonts/noto-cjk 的 Sans2.004 下载 (18_NotoSansSC.zip), 许可是 SIL OFL 1.1 (免费商用, 见 fonts/OFL.txt)。
**改了游戏里的字 (加了新的中文) 就要重跑一次**, 测试 test_font.gd 会检查有没有缺字。
"""
import pathlib
import sys

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "fonts" / "NotoSansSC-Medium-subset.otf"


def used_chars() -> str:
    chars = set(chr(c) for c in range(0x20, 0x7F))  # 英文字母、数字、标点
    chars.update("，。、！？：；「」『』（）《》…—·～×←→↑↓★☆○●♪")
    for f in (ROOT / "scripts").glob("*.gd"):  # 屏幕上显示的字都在 scripts 里 (测试里的字不显示)
        chars.update(c for c in f.read_text(encoding="utf-8") if ord(c) > 0x7F)
    return "".join(sorted(chars))


def main() -> None:
    src = pathlib.Path(sys.argv[1])
    text = used_chars()
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    font = subset.load_font(str(src), opts)
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    OUT.parent.mkdir(exist_ok=True)
    subset.save_font(font, str(OUT), opts)
    print(f"{len(text)} 个字 -> {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
