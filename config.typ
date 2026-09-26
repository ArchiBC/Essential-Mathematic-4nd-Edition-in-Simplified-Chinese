// 全书通用排版；正文只保留内容、书籍信息与局部例外。
#import "@preview/ilm:2.1.1" as theme
#import "@preview/codly:1.3.0": codly, codly-init
#import "@preview/codly-languages:0.1.8": codly-languages

// 内置 VB.NET 语法，避免依赖单独的 syntaxes 目录。
#let vb-syntax=bytes(```yaml
%YAML 1.2
---
# VB.NET syntax used by the textbook's Grasshopper script examples.
name: Visual Basic .NET
file_extensions: [vb, vbnet, visualbasic]
scope: source.vbnet
contexts:
  main:
    - match: "'[^\n]*"
      scope: comment.line.apostrophe.vbnet
    - match: '(?i)\bREM\b[^\n]*'
      scope: comment.line.rem.vbnet
    - match: '"'
      scope: punctuation.definition.string.begin.vbnet
      push: string
    - match: '(?i)\b(Sub|Function)\s+([\p{L}_][\p{L}\p{N}_]*)'
      captures:
        1: keyword.declaration.function.vbnet
        2: entity.name.function.vbnet
    - match: '(?i)\b(Boolean|Byte|SByte|Char|Date|Decimal|Double|Integer|UInteger|Long|ULong|Object|Short|UShort|Single|String)\b'
      scope: storage.type.vbnet
    - match: '(?i)\b(True|False|Nothing)\b'
      scope: constant.language.vbnet
    - match: '(?i)\b(AddHandler|AddressOf|And|AndAlso|As|Async|Await|ByRef|ByVal|Call|Case|Catch|Class|Const|Continue|Declare|Default|Delegate|Dim|DirectCast|Do|Each|Else|ElseIf|End|Enum|Erase|Error|Event|Exit|Finally|For|Friend|Function|Get|GetType|Global|GoTo|Handles|If|Implements|Imports|In|Inherits|Interface|Is|IsNot|Iterator|Let|Lib|Like|Loop|Me|Mod|Module|MustInherit|MustOverride|MyBase|MyClass|Namespace|New|Next|Not|NotInheritable|NotOverridable|Of|On|Operator|Option|Optional|Or|OrElse|Out|Overloads|Overridable|Overrides|ParamArray|Partial|Private|Property|Protected|Public|RaiseEvent|ReadOnly|ReDim|RemoveHandler|Resume|Return|Select|Set|Shadows|Shared|Static|Step|Stop|Structure|Sub|SyncLock|Then|Throw|To|Try|TryCast|TypeOf|Using|When|While|With|WithEvents|WriteOnly|Xor|Yield)\b'
      scope: keyword.control.vbnet
    - match: '(?i)\b(?:CType|CBool|CByte|CChar|CDate|CDbl|CDec|CInt|CLng|CObj|CShort|CSng|CStr|CUInt|CULng|CUShort)\b'
      scope: support.function.vbnet
    - match: '(?i)(?:&H[0-9a-f]+|&O[0-7]+|&B[01]+|\b\d+(?:\.\d+)?(?:e[+-]?\d+)?)(?:[USILFDR]+)?\b'
      scope: constant.numeric.vbnet
    - match: '<>|<=|>=|[+*/\\^=&<>-]'
      scope: keyword.operator.vbnet
  string:
    - meta_scope: string.quoted.double.vbnet
    - match: '""'
      scope: constant.character.escape.vbnet
    - match: '"[cC]?'
      scope: punctuation.definition.string.end.vbnet
      pop: true
```.text)

#let body-fonts=((name:"New Computer Modern",covers:"latin-in-cjk"),"Source Han Serif SC")
#let caption-fonts=((name:"New Computer Modern",covers:"latin-in-cjk"),"Source Han Sans SC")
#let code-fonts=("Maple Mono","Source Han Sans SC")
#let blockquote=theme.blockquote
#let colMath(x,color)=text(fill:color)[$#x$]
#let redMath(x)=colMath(x,red)

// 图文布局专用默认值，不影响插图内部的数据表和矩阵网格。
#let comparison-grid=grid.with(align:horizon,gutter:1em)
#let comparison-table=table.with(inset:10pt,align:horizon)

// width 以当前正文/单元格为基准；只测量校正一次，避免反复重绘。
#let fig(draw-fn, width: 100%, units: 8) = layout(size => {
  let target = size.width * width
  let unit = target / units
  let drawing = draw-fn(length: unit)
  let actual = measure(drawing).width
  if calc.abs(actual - target) >= 0.01pt {
    drawing = draw-fn(length: unit * (target / actual))
  }
  align(center, scale(x: target, y: auto, reflow: true, drawing))
})

#let body-style(body)={
  set math.equation(numbering:none)
  show math.equation.where(block:true): it=>align(left,pad(it,left:2em))
  show list: it=>align(left,pad(it,left:2em))
  set math.mat(delim:"[")
  set grid.hline(stroke:0.15pt)
  show raw.line: set text(font:code-fonts,weight:300)
  body
}

#let book(body,..metadata)={
  set text(font:body-fonts,lang:"zh",region:"cn")
  show figure: set text(font:caption-fonts,size:10pt)
  // 位图和 SVG 默认在所在容器居中，正文无需逐一包装 align。
  show image: it=>align(center,it)
  show: codly-init.with()
  codly(languages:codly-languages)
  set raw(syntaxes:vb-syntax)
  theme.ilm(
    paper-size:"a5",
    date:none,
    external-link-circle:false,
    raw-text:(font:code-fonts,size:9pt),
    table-of-contents:(outline(depth:2)),
    ..metadata,
    body-style(body),
  )
}

// 统一配色（取自原图）
#let diagram-red = rgb("#960000")
#let diagram-green = rgb("#009600")

#let palette = (
  grid: rgb("#dddddd"), // 网格
  gray: rgb("#bebebe"), // 坐标轴与辅助线
  red: diagram-red,
  green: diagram-green,
  red3d: rgb("#c80000"), // 三维图向量（红）
  green3d: rgb("#007f00"), // 三维图向量（绿）
  text: rgb("#000000"), // 标注文字
  // 语义别名
  x-axis: diagram-red,
  y-axis: diagram-green,
  vector: diagram-green,
  point: diagram-red,
)

// 插图通用视觉参数。数值尺寸为画布单位；带 cm/pt 的尺寸为物理尺寸。
#let diagram-style=(
  unit:0.72cm,
  cross:(half-size:0.075cm,thickness:1.6pt),
  control-point:(radius:0.045,color:black,fill:white,thickness:0.65pt),
  node:(half-size:0.04,color:black,fill:white,thickness:0.4pt),
  sample-point:(radius:0.025,tiny-radius:0.022,fill:white,thickness:0.4pt),
  interpolation-point:(radius:0.035,fill:white,thickness:0.6pt),
  label:(size:7pt,padding:2pt),
  curve-thickness:1pt,
  guide-color:rgb("#999999"),
  control-polygon:(paint:black,thickness:0.4pt,dash:"dotted"),
  arrow:(thickness:0.8pt,head-length:0.1cm,aspect-ratio:2,scale:1.7),
)
#let arrow-mark(color,thickness:diagram-style.arrow.thickness)=(
  end:">",
  scale:diagram-style.arrow.scale,
  length:diagram-style.arrow.head-length,
  width:diagram-style.arrow.head-length/diagram-style.arrow.aspect-ratio,
  stroke:(paint:color,thickness:thickness,join:"miter",miter-limit:10),
  fill:color,
)

// 插图中的矩阵与数据面板，与正文对照表分别配置。
#let matrix-style=(fill:rgb("#e5e5e5"),stroke:(paint:rgb("#666666"),thickness:0.5pt),inset:(x:4pt,y:5pt))
#let data-table-style=(
  header-fill:rgb("#e6e6e6"),body-fill:white,
  stroke:(paint:rgb("#888888"),thickness:0.4pt),inset:(x:3pt,y:1.5pt),
  header-font:"Arial",body-font:"New Computer Modern",size:7.5pt,
)
