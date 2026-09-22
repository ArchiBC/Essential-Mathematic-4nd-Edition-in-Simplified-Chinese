#import "@preview/cetz:0.5.2": canvas, draw

// 统一配色（取自原图）
#let red = rgb("#960000")
#let green = rgb("#009600")

#let palette = (
  grid: rgb("#ebebeb"), // 网格
  gray: rgb("#bebebe"), // 三维坐标轴
  red: red,
  green: green,
  red3d: rgb("#c80000"), // 三维图向量（红）
  green3d: rgb("#007f00"), // 三维图向量（绿）
  text: rgb("#000000"), // 标注文字
  // 语义别名
  x-axis: red,
  y-axis: green,
  vector: green,
  point: red,
)

// 点标记：红色叉（可换色）
// unit 为每格长度；size 为绝对尺寸(cm)，因此缩放画布不会改变点的大小
#let point-mark(
  pos,
  unit,
  size: 0.075cm,
  color: palette.point,
  thickness: 1.6pt,
) = {
  import draw: *
  let s = size / unit
  line(
    (pos.at(0) - s, pos.at(1) - s),
    (pos.at(0) + s, pos.at(1) + s),
    stroke: (paint: color, thickness: thickness),
  )
  line(
    (pos.at(0) - s, pos.at(1) + s),
    (pos.at(0) + s, pos.at(1) - s),
    stroke: (paint: color, thickness: thickness),
  )
}

// 向量箭头（线宽与箭头尺寸均为绝对值，不随画布缩放）
#let vector-arrow(
  start,
  vec,
  color: palette.vector,
  thickness: 0.8pt,
) = {
  import draw: *
  line(
    start,
    (start.at(0) + vec.at(0), start.at(1) + vec.at(1)),
    stroke: (paint: color, thickness: thickness),
    mark: (
      end: ">",
      scale: 1.7,
      length: 0.1cm,
      width: 0.05cm,
      stroke: (paint: color, thickness: thickness),
      fill: color,
    ),
  )
}

// 网格（不含最外圈边框）
#let grid-lines(x1, y1) = {
  import draw: *
  for x in range(1, x1) {
    line((x, 0), (x, y1), stroke: (paint: palette.grid, thickness: 0.4pt))
  }
  for y in range(1, y1) {
    line((0, y), (x1, y), stroke: (paint: palette.grid, thickness: 0.4pt))
  }
}

// 三维坐标轴（灰，带箭头）：Z 上、X 右、Y 左下 45°
#let space-axes(o, factor: 1) = {
  import draw: *
  let a-stroke = (paint: palette.gray, thickness: 1pt)
  let a-mark = (
    end: ">",
    scale: 1.7,
    length: 0.1cm,
    width: 0.05cm,
    stroke: a-stroke,
    fill: palette.gray,
  )
  let ox = o.at(0)
  let oy = o.at(1)
  line((ox, oy), (ox, oy + 3 * factor), stroke: a-stroke, mark: a-mark)
  line((ox, oy), (ox + 5 * factor, oy), stroke: a-stroke, mark: a-mark)
  line((ox, oy), (ox - 1 * factor, oy - 1 * factor), stroke: a-stroke, mark: a-mark)
}

// 图 1：同一向量的等价表示（起点不同，方向与长度相同）
#let vector-equivalent(length: 0.72cm) = canvas(length: length, {
  import draw: *
  grid-lines(8, 4)
  // 坐标轴（正方向，无箭头）
  line((3, 2), (8, 2), stroke: (paint: palette.x-axis, thickness: 0.4pt))
  line((3, 2), (3, 4), stroke: (paint: palette.y-axis, thickness: 0.4pt))

  // 等价向量：起点与端点都落在格点上
  let v = (1, 1)
  let starts = ((1, 3), (5, 3), (6, 1), (1, 0), (4, 0))
  for s in starts {
    vector-arrow(s, v)
    point-mark(s, length)
  }
})

// 图 2：向量、起点 A、终点 B 的关系（B = A + v）
#let vector-point-relation(length: 0.72cm) = canvas(length: length, {
  import draw: *
  grid-lines(8, 4)
  // 坐标轴（正方向，无箭头）
  line((1, 1), (8, 1), stroke: (paint: palette.x-axis, thickness: 0.4pt))
  line((1, 1), (1, 4), stroke: (paint: palette.y-axis, thickness: 0.4pt))

  // 起点 A（红）、终点 B（绿）
  let a = (2, 2)
  let b = (6, 3)
  vector-arrow(a, (b.at(0) - a.at(0), b.at(1) - a.at(1)), color: palette.red)
  point-mark(a, length)
  point-mark(b, length, color: palette.green)

  // 标注
  content((a.at(0) - 0.15, a.at(1) + 0.1), $A$, anchor: "south-east")
  content((b.at(0) + 0.15, b.at(1) + 0.1), $B = A + bold(arrow(v))$, anchor: "south-west")
  content((4.4, 1.9), $bold(arrow(v)) = chevron.l a_1, a_2, a_3 chevron.r$, anchor: "north")
})

// 图 3：位置向量（原点到点 (a1,a2,a3) 的向量）
#let position-vector(length: 0.72cm) = canvas(length: length, {
  import draw: *
  grid-lines(8, 4)
  // 坐标轴（正方向，无箭头）
  line((1, 1), (8, 1), stroke: (paint: palette.x-axis, thickness: 0.4pt))
  line((1, 1), (1, 4), stroke: (paint: palette.y-axis, thickness: 0.4pt))

  // 原点（红）到点 (a1,a2,a3)（绿）
  let o = (1, 1)
  let p = (6, 3)
  vector-arrow(o, (p.at(0) - o.at(0), p.at(1) - o.at(1)), color: palette.red)
  point-mark(o, length)
  point-mark(p, length, color: palette.green)

  // 标注
  content((o.at(0) + 0.12, o.at(1) - 0.1), $(0, 0, 0)$, anchor: "north-west")
  content((p.at(0) + 0.15, p.at(1) + 0.1), $(a_1, a_2, a_3)$, anchor: "south-west")
  content((4.4, 1.7), $bold(arrow(v)) = chevron.l a_1, a_2, a_3 chevron.r$, anchor: "north")
})

// 图 4：向量定义方向和长度，点定义位置
#let vector-and-point(length: 0.72cm) = canvas(length: length, {
  import draw: *
  grid-lines(8, 4)
  // 坐标轴（正方向，无箭头）
  line((1, 1), (8, 1), stroke: (paint: palette.x-axis, thickness: 0.4pt))
  line((1, 1), (1, 4), stroke: (paint: palette.y-axis, thickness: 0.4pt))

  let v = (3, 1)
  // 位置向量：原点到点 P
  let o = (1, 1)
  let p = (4, 2)
  vector-arrow(o, v, color: palette.red)
  point-mark(p, length, color: palette.green)
  content((p.at(0) + 0.12, p.at(1) + 0.02), text(fill: palette.green, $P$), anchor: "south-west")

  // 与 v 同方向、同长度的其它向量
  let starts = ((1, 3), (4, 3), (5, 2))
  for s in starts {
    vector-arrow(s, v, color: palette.red)
  }
  content((2.2, 3.72), $bold(arrow(v))$, anchor: "south")
  content((5.2, 3.72), $bold(arrow(v))$, anchor: "south")
  content((6.2, 2.72), $bold(arrow(v))$, anchor: "south")

  // 位置向量标注
  // 位置向量的 v 标注 + 原点下方的 position
  content((2.2, 1.72), $bold(arrow(v))$, anchor: "south")
  content((1, 0.9), $bold("position")$, anchor: "north")
})

// 图 5：向量长度（等轴测三维坐标轴 + 向量 a）
#let vector-length(length: 0.72cm) = canvas(length: length, {
  import draw: *
  let o = (3, 2)
  space-axes(o)
  // 向量 a
  vector-arrow(o, (3.5, 2.2), color: palette.green3d, thickness: 0.8pt)
  content((4.6, 3.35), text(fill: palette.green3d, $bold(arrow(a))$), anchor: "south")
})

// 图 6：单位向量
#let unit-vector(length: 0.72cm) = canvas(length: length, {
  import draw: *
  let o = (3, 2)
  space-axes(o)
  // 向量 a（红）
  vector-arrow(o, (3.5, 2.2), color: palette.red3d, thickness: 0.8pt)
  content((4.7, 3.35), text(fill: palette.red3d, $bold(a)$), anchor: "south")
  // 单位向量（绿，较粗）
  vector-arrow(o, (1.15, 0.72), color: palette.green3d, thickness: 1.4pt)
  content((2.55, 2.5), text(fill: palette.green3d, weight: "bold")[unit $bold(arrow(a))$], anchor: "east")
})

// 图 7：向量标量运算（a 与 2a）
#let scalar-multiplication(length: 0.72cm) = canvas(length: length, padding: 0.2cm, {
  import draw: *
  let s = 0.5
  let v = (3.5 * s, 2.2 * s)
  // 左：a
  let o1 = (2, 2)
  space-axes(o1, factor: s)
  vector-arrow(o1, v, color: palette.green3d, thickness: 0.8pt)
  content(
    (o1.at(0) + v.at(0) / 2, o1.at(1) + v.at(1) / 2 + 0.35),
    text(fill: palette.green3d, $bold(arrow(a))$),
    anchor: "south",
  )
  // 右：2a
  let o2 = (9, 2)
  space-axes(o2, factor: s)
  vector-arrow(o2, (2 * v.at(0), 2 * v.at(1)), color: palette.green3d, thickness: 0.8pt)
  content(
    (o2.at(0) + 1.6 * v.at(0), o2.at(1) + 1.6 * v.at(1) + 0.15),
    text(fill: palette.green3d, $2 * bold(arrow(a))$),
    anchor: "south-east",
  )
})
