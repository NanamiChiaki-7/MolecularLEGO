# 分子乐高 / Molecular LEGO

**沉浸式交互化学结构建模科普系统**

Interactive Molecular Structure Modeling for Chemistry Education

---

## 简介 | Introduction

**分子乐高**是一款基于 Godot 4 引擎开发的交互式化学教学工具。用户通过拖拽原子、点击成键等操作，像搭乐高积木一样构建有机分子模型。系统内建价键理论验证引擎、70+ 化合物智能识别库、实时 IUPAC 命名、手性 R/S 自动标定，并支持 2D 球棍模型、3D 立体模型和键线式结构三种视图一键切换。

**Molecular LEGO** is an interactive chemistry education tool built with the Godot 4 engine. Users build organic molecules by dragging atoms and clicking to form bonds — just like assembling LEGO bricks. The system features a valence validation engine, 70+ compound recognition library, real-time IUPAC naming, chiral R/S labeling, and one-click switching between 2D ball-and-stick, 3D, and skeletal formula views.

## 功能特性 | Features

- **原子拖拽与成键** — 拖拽 C/H/O/N 等原子到画布，点击成键，支持单/双/三键
- **价键验证引擎** — 实时校验八隅体规则（C≤4、O≤2、N≤3、H≤1），超限弹窗警告
- **基团快速拼接** — 预置 8 种官能团（-OH、-CH₃、-COOH 等）+ 酯键/肽键片段
- **化合物智能识别** — 70+ 内置化合物库，搭出结构自动识别并显示科普介绍
- **IUPAC 命名** — 自动生成直链烷烃/烯烃/炔烃系统命名
- **键线式渲染** — 一键将球棍模型转为标准化学结构式（C/H 自动隐藏、手性楔形键）
- **手性分析** — 递归比较取代基结构，自动标定 *R/*S 构型，绘制楔形键
- **稳定性预警** — 检测过氧键(O-O)、累积双烯(C=C=C)、偶氮/叠氮(N=N)
- **三视图切换** — 2D 球棍 / 3D 立体（旋转缩放）/ 键线式（骨架式）
- **多选编辑** — 框选、Shift 追加选择、整体拖拽、右键批量操作

## 运行 | Run

需要 [Godot 4.3+](https://godotengine.org/)（GL Compatibility 渲染器）。

Requires [Godot 4.3+](https://godotengine.org/) with GL Compatibility renderer.

```bash
git clone https://github.com/NanamiChiaki-7/MolecularLEGO.git
# 用 Godot 打开 project.godot 即可运行
# Open project.godot with Godot to run
```

## 项目结构 | Structure

```
分子乐高/
├── project.godot          # 引擎配置
├── scenes/
│   ├── Main.tscn          # 主场景
│   └── Atom.tscn          # 原子预制体
├── scripts/
│   ├── Global.gd          # Autoload：全局状态 + 化合物库 + IUPAC + 手性检测
│   ├── Main.gd            # 主 UI：布局构建 + 交互路由
│   ├── CanvasWorld.gd     # 画布核心：拖拽、成键、框选、基团拼接、键线式渲染
│   ├── Atom.gd            # 原子节点：自绘制 + 价态显示 + 手性标记
│   └── Mol3DView.gd       # 3D 分子渲染视图
├── kepu/                  # 科普配图资源
└── README.md
```

## 许可证 | License

MIT License © 2026 CK

详见 [LICENSE](./LICENSE) 文件。
