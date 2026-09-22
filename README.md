# Essential-Mathematic-4nd-Edition-in-Simplified-Chinese

计算设计的基础数学第四版中文翻译

本译本以Rhino开发者网站上的版本为主，参考了第四版PDF和第二版中文翻译。

## 目录结构

仓库根目录即 **A5 小册子版（Typst 排版）主版本**：

```
├── 计算设计的基础数学.typ   # Typst 源文件
├── 计算设计的基础数学.pdf   # 编译输出
├── image/                   # 配图
└── archive/                 # 旧版本归档（markdown / 早期 PDF）
```

早期使用 markdown + Typora 主题排版的版本已归档到 `archive/` 目录，仅作留存参考。

## 编译

需要 [Typst](https://typst.app/)（已在 0.15.1 下验证；源文件使用 `chevron.l` / `chevron.r` 尖括号符号）：

```sh
typst compile 计算设计的基础数学.typ
```

排版使用 [ilm](https://typst.app/universe/package/ilm) 模板，代码高亮使用 [codly](https://typst.app/universe/package/codly)，代码字体统一为 [Maple Mono](https://github.com/subframe7536/maple-font)（CN 版，中英文 2:1 对齐）。为获得最佳效果，建议安装以下开源字体：Maple Mono、Source Han Serif SC、Source Han Sans SC。

## 版权与致谢

本书版权显然仍归属原作者及McNeel公司所有。如有错漏及翻译问题，请联系译者。

本书基本为译者使用markdown手动翻译、感谢作者***[Rajaa Issa](https://discourse.mcneel.com/u/rajaa/activity)***的帮助，我向作者询问了本书的一些问题，得到很多帮助和反馈。

翻译过程中发现了原书版本的一些排版问题，这些问题已被原作者修复。

## 更新记录

- 2025.04.26　增加了一个使用 Typst 排版的 A5 小册子版本，修复了部分措词和别字，更适合打印参考。
