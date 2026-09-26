# Essential-Mathematic-4nd-Edition-in-Simplified-Chinese

《计算设计的基础数学》第四版中文翻译，以 Rhino 开发者网站上的版本为主，参考第四版 PDF 和第二版中文翻译。

## 目录结构

仓库根目录为使用 Typst 排版的 A5 小册子版本。

```text
├── 计算设计的基础数学.typ   # 正文与书籍信息
├── 计算设计的基础数学.pdf   # 编译输出
├── config.typ               # 全书排版与插图视觉配置
├── image.typ                # 插图几何与绘制
├── image/                   # 配图
└── archive/                 # Markdown 与早期 PDF 归档
```

## 编译

本书已在 [Typst](https://typst.app/) 0.15.1 下验证。安装以下字体和本地曲线绘图库后，在本书目录运行编译命令。

字体：Maple Mono CN、Source Han Serif SC、Source Han Sans SC。代码使用 [Maple Mono](https://github.com/subframe7536/maple-font) CN 字体。

```powershell
typst compile 计算设计的基础数学.typ
```

排版使用 [ilm](https://typst.app/universe/package/ilm) 模板和 [codly](https://typst.app/universe/package/codly) 代码块样式，插图使用 CeTZ、cetz-nurbs 和 scenery。Typst 会在首次编译时自动下载 `@preview` 依赖。

### 安装曲线绘图库

本书通过 `@local/cetz-nurbs:0.1.0` 引用本地 Typst 包。

- 下载仓库：[ArchiBC/breplot](https://github.com/ArchiBC/breplot)
- 库文档：[cetz-nurbs](https://github.com/ArchiBC/breplot/tree/main/cetz-nurbs)
- 本书验证版本：[fb45e443](https://github.com/ArchiBC/breplot/commit/fb45e443615ce0caf41085c1946a16aa5a7704a8)
- ZIP 下载：[下载已验证版本](https://github.com/ArchiBC/breplot/archive/fb45e443615ce0caf41085c1946a16aa5a7704a8.zip)

构建需要 Rust 1.96.0 或更新版本、`wasm32-unknown-unknown` target 和 Typst。以下命令使用 Git 下载源码，并构建、安装 WASM 包。在存放依赖的目录中运行（Windows PowerShell）：

```powershell
git clone https://github.com/ArchiBC/breplot.git
Set-Location breplot
git checkout fb45e443615ce0caf41085c1946a16aa5a7704a8
rustup target add wasm32-unknown-unknown
.\cetz-nurbs\scripts\build.ps1
.\cetz-nurbs\scripts\install-local.ps1
```

使用 ZIP 时，解压后进入 `breplot` 目录，从 `rustup target add` 开始执行。更新已有源码后，重新运行构建和安装脚本。

安装器默认将包复制到 `%APPDATA%\typst\packages\local\cetz-nurbs\0.1.0`；设置了 `TYPST_PACKAGE_PATH` 时，以该路径为包目录。安装完成后回到本书目录编译。

## 排版与插图配置

`config.typ` 集中管理正文、图注、代码字体、语法高亮、A5 模板、公式、列表、图片居中和插图缩放。正文通过 `book` 应用配置；书名、作者、前言和正文内容位于主文件。

- `fig`：默认居中，按正文或当前单元格宽度缩放插图。
- `comparison-grid`、`comparison-table`：图文布局的默认对齐和间距，列宽与局部调整在使用处指定。
- `palette`、`diagram-style`、`arrow-mark`：插图颜色、控制点、节点、辅助线、曲线标注和箭头样式。
- `matrix-style`、`data-table-style`：矩阵与数据表格样式。

代码高亮由 Typst `raw` 提供。C# 使用 `cs` 标记，VB.NET 使用 `config.typ` 中的 Sublime Syntax 规则。

## 插图绘制

`image.typ` 集中定义参数曲线、Bézier/Hermite、NURBS 和曲面教学图，按图意命名，使用统一的 `length` 参数。简单示例也可在正文中直接绘制。

NURBS 曲线由控制点、节点和权重定义，求点、导数及曲率使用 cetz-nurbs 接口。曲线显示采用库的三次路径转换或自适应近似，模型空间采样容差设置为 `0.0001`。图 40 根据原图进行近似重建并调整曲线形状，使两侧曲率便于对比；曲率梳按解析导数和统一倍率绘制。

曲率采样和球面网格独立于画布尺寸计算，网格按连续路径绘制。半透明柱面与截平面使用 [scenery](https://typst.app/universe/package/scenery/) 的 WASM BSP 引擎切分、排序，再由 CeTZ 绘制。

## 版权与致谢

本书版权归原作者及 McNeel 公司所有。如有错漏及翻译问题，请联系译者。

译者手动完成翻译，感谢作者 [Rajaa Issa](https://discourse.mcneel.com/u/rajaa/activity) 在翻译过程中提供的帮助和反馈。翻译时发现的部分原书排版问题已由原作者修复。

## 更新记录

- 2025.04.26　增加使用 Typst 排版的 A5 小册子版本，修复部分措辞和别字，便于打印参考。
