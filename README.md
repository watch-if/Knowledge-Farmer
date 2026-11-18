# farmer

farmer 是一款原生中文桌面学习游戏。启动后选择 **Python** 或 **Math**，随时可返回选路。两条路线各自保存进度。

## 第一次玩

首次选择 Python 时，先运行 `print` 示例，再动手改一句话。进入车间后，从修改 `name` 和 `price` 两项开始，按 `i` 看输入和预期输出。

首次选择 Math 时，先完成独立的 **Lean 4 入门**。十课从读懂证明目标、补齐证明开始，依次练习假设、改写、定义、计算、递归、归纳和导入。每课可对照例子，点击「检查 Lean」查看真实目标或报错。毕业练习通过后进入数学正课。途中退出会保存当前课和草稿，开始界面的「Lean 4 入门」也可用来复习。

## Python · 发货车间

用一个项目练文件自动化与简单采集。先把供应商给的 CSV 清成统一格式，再用 Python 向本机练习网页发出 HTTP 请求，把网页商品数据写成同格式的报表。每关在两批数据上运行脚本，给出真实错误或报表预览。

- **整理报价**：补完 `clean_quotes.py`，读 `products.csv`，清理商品名，把价格格式化为两位小数，输出 `report.csv`。
- **采集目录**：补完 `collect_catalog.py` 的 HTML 解析，从练习页提取商品编号、名称、价格，输出相同的 CSV。
- 点击「运行脚本」生成装车清单。验收通过后，选择「装一箱」或「开始装车」，在输送带上看对应的货箱进入货车。点击「i 订单与提示」检查清单或逐级看写法。草稿和进度自动保存。

## Math · Lean 4 证明工坊

首个可玩章节包括「读懂等式 → 有限累加 → 归纳证明 · 奇数和 → 改写两项」。知识树展示通往 11/12 和 7/8 预印本精读的路线。此前 Zeta Lab 的 Math 存档路径保留。

- 修改 Lean 文件，点击窗口上的三角按钮或底部「检查 Lean」。
- `−` 收起文件，点文件牌恢复，拖动标题可移动窗口。
- `+` 新建 Lean 文件，可以用 `import Notebook1` 调用另一个草稿。
- `i` 查看任务、分级提示和图解，`⌃` 展开知识树。点资源栏查看已归档的定义和定理。
- Lean 的诊断来自实际检查，机械臂回放本关推荐的推导路线。

## 从源码运行

需要 Godot 4.6.3。Python 路线需要 Python 3.9 或更新版本，Math 路线使用 Lean 4.19.0。游戏优先使用 `FARMER_PYTHON` 或 `ZETA_LEAN` 指定的可执行文件，其次使用随 Windows 包提供的运行时，再尝试系统 PATH。代码在本机运行，请提交自己编写或信任的源码。

```bash
godot --headless --editor --import --path . --quit
godot --path .
```

Windows 用 Godot 的同版本模板和 `Windows 64` 导出预设，导出为 `farmer.exe`。独立试玩包目录包含 `python/python.exe`、`lean/bin/lean.exe` 以及各自的标准库。解压后保持该目录结构。

## 验证

```bash
export ZETA_LEAN=/path/to/lean FARMER_PYTHON=/path/to/python3
godot --headless --path . --script tests/workshop_check.gd
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . --script tests/workshop_flow.gd
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . --script tests/farmer_routes.gd
```

## GitHub 自动发布

每次推送到 `main` 后，GitHub Actions 会测试两条路线，再构建 Windows x64 ZIP 和 Android ARM64 APK。两个附件上传完成后，才会公开同一条 GitHub 预发行。常规联发使用仓库配置的 Android 长期签名。

可以手动运行「Windows and Android prerelease」并选择 Android 安装试装模式。此模式仍在同一预发行页提供两个包，APK 使用独立包名和临时签名。
