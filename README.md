# Zeta Lab

Zeta Lab 是一款原生中文桌面数学游戏。玩家在黄铜工坊中编写 Lean 4 定义和证明，完成练习后可在后面的文件里调用自己已证的定理。

首个可玩章节包括「读懂等式 → 有限累加 → 归纳证明 · 奇数和 → 改写两项」。知识树展示了数学分析、复变和数论一直到 11/12 与 7/8 预印本精读的课程方向。当前可进入四个练习。

## 开始玩

Windows x64 试玩包解压后，运行 `ZetaLab.exe`。请保留旁边的 `lean` 目录，游戏用其中的 Lean 4.19.0 在本机检查 Lean 源码。试玩包面向 Windows 10 及更新版本。

- 修改 Lean 文件，点击窗口上的三角按钮或底部「检查 Lean」。
- `−` 收起文件。点击左上方的文件牌恢复窗口。拖动文件标题可移动窗口。
- `+` 新建独立 Lean 文件，可以通过 `import Notebook1` 调用另一个草稿文件。
- `i` 打开学习目标、分级提示和图解。可以从「查看诊断」读 Lean 的真实报错。
- `⌃` 展开知识树。点击资源栏可查看已归档的定理和定义。改写关卡可以点击工作台上的项，定位对应的 Lean 代码。
- 游戏在本地自动保存进度、草稿和代码窗位置。检查 Lean 源码时会运行本机 Lean，包括源码中的求值命令，请使用自己编写或信任的源码。

## 从源码运行

需要 Godot 4.6.3 和 Lean 4.19.0。将 `ZETA_LEAN` 设为 Lean 可执行程序的路径，也可以把 Lean 加到系统 PATH。

```bash
godot --headless --editor --import --path . --quit
godot --path .
```

如果 Lean 通过 Elan 安装，请在运行 Godot 前选定 Lean 4.19.0。Windows 导出使用 Godot 的 4.6.3 官方模板，导出预设名为 `Windows 64`。向玩家分发时，需把 Lean 运行时与 `ZetaLab.exe` 放在一起，目录结构为 `lean/bin/lean.exe` 和 `lean/lib/lean`。

## 验证

`workshop_check.gd` 用真实 Lean 验证四关的正确答案，以及错误类型、未完成证明和公理占位。流程测试写入自动存档，使用新的数据目录运行。

```bash
export ZETA_LEAN=/path/to/lean
godot --headless --path . --script tests/workshop_check.gd
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . --script tests/workshop_flow.gd
```

机械臂当前播放与关卡成功结果对应的演示。Lean 诊断显示真实检查结果，改写台展示本关推荐的推导路线。
