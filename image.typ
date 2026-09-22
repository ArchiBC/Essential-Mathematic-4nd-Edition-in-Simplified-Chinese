#import "@preview/cetz:0.5.2": canvas, draw

// 统一配色（取自原图）
#let red = rgb("#960000")
#let green = rgb("#009600")

#let palette = (
  grid: rgb("#dddddd"), // 网格
  gray: rgb("#bebebe"), // 坐标轴与辅助线
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
      stroke: (paint: color, thickness: thickness, join: "miter", miter-limit: 10),
      fill: color,
    ),
  )
}

// 背景统一绘制网格与二维坐标轴；网格以原点为基准，坐标轴就是加深的格线。
// 固定物理间距，无外框；offset 指定背景区域左下角。
#let grid-lines(x1, y1, length: 0.72cm, offset: (0, 0), origin: (1, 1)) = {
  import draw: *
  let step = 0.72cm / length
  let grid-stroke = (paint: palette.grid, thickness: 0.4pt)
  let negative-stroke = (paint: rgb("#666666"), thickness: 0.4pt)
  let (left, bottom) = offset
  let right = left + x1
  let top = bottom + y1
  let (ox, oy) = origin
  for i in range(calc.floor((left - ox) / step) + 1, calc.ceil((right - ox) / step)) {
    if i != 0 {
      let x = ox + i * step
      line((x, bottom), (x, top), stroke: grid-stroke)
    }
  }
  for i in range(calc.floor((bottom - oy) / step) + 1, calc.ceil((top - oy) / step)) {
    if i != 0 {
      let y = oy + i * step
      line((left, y), (right, y), stroke: grid-stroke)
    }
  }
  line((ox, bottom), (ox, oy), stroke: negative-stroke)
  line((ox, oy), (ox, top), stroke: (paint: palette.y-axis, thickness: 0.4pt))
  line((left, oy), (ox, oy), stroke: negative-stroke)
  line((ox, oy), (right, oy), stroke: (paint: palette.x-axis, thickness: 0.4pt))
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
    stroke: (paint: palette.gray, thickness: 1pt, join: "miter", miter-limit: 10),
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
  grid-lines(8, 4, length: length, origin: (3, 2))

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
  grid-lines(8, 4, length: length)

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
  grid-lines(8, 4, length: length)

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
  grid-lines(8, 4, length: length)

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
  content((4.7, 3.35), text(fill: palette.red3d, $bold(arrow(a))$), anchor: "south")
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

// 图 8：首尾相接的向量加法
#let vector-addition(length: 0.72cm) = canvas(length: length, {
  import draw: *
  grid-lines(8, 4, length: length, origin: (1, 0.5))
  let o = (1, 0.5)
  vector-arrow(o, (1, 2), color: palette.red)
  vector-arrow((2, 2.5), (4, 1), color: palette.red)
  vector-arrow(o, (5, 3))
  content((1.45, 1.8), text(fill: palette.red, $bold(arrow(a)) chevron.l 1, 2, 0 chevron.r$), anchor: "east")
  content((3.8, 3.35), text(fill: palette.red, $bold(arrow(b)) chevron.l 4, 1, 3 chevron.r$), anchor: "south")
  content((4.2, 1.5), text(fill: palette.green, $bold(arrow(a)) + bold(arrow(b)) chevron.l 5, 3, 3 chevron.r$), anchor: "north")
})

// 图 9：不同长度与单位长度向量的合成；右侧逐一归一化后再求和
#let average-direction(length: 0.72cm) = canvas(length: length, {
  import draw: *
  let vectors = ((-1, 2), (1.75, 0.5), (0.7, -1.5), (-0.75, 0.25))
  for (offset, normalize) in ((0, false), (5, true)) {
    let o = (offset + 1.6, 2)
    grid-lines(4, 4.2, length: length, offset: (offset, 0), origin: o)
    let sum = (0, 0)
    for v in vectors {
      let scale = if normalize { 1 / calc.sqrt(v.at(0) * v.at(0) + v.at(1) * v.at(1)) } else { 1 }
      let w = (v.at(0) * scale, v.at(1) * scale)
      vector-arrow(o, w, color: palette.red)
      sum = (sum.at(0) + w.at(0), sum.at(1) + w.at(1))
    }
    vector-arrow(o, sum, thickness: 1.2pt)
  }
})

// 图 10：两种相反次序的向量差
#let vector-subtraction(length: 0.72cm) = canvas(length: length, {
  import draw: *
  grid-lines(8, 4, length: length, origin: (3.5, 1.3))
  let o = (3.5, 1.3)
  vector-arrow(o, (1, 2), color: palette.text)
  vector-arrow(o, (4, 1), color: palette.text)
  vector-arrow(o, (-3, 1))
  vector-arrow(o, (3, -1), color: palette.red)
  content((3.9, 2.5), $bold(arrow(a))$, anchor: "east")
  content((5.4, 2), $bold(arrow(b))$, anchor: "south")
  content((1.7, 1.65), text(fill: palette.green, $bold(arrow(a)) - bold(arrow(b))$), anchor: "north")
  content((5.5, 1.05), text(fill: palette.red, $bold(arrow(b)) - bold(arrow(a))$), anchor: "south")
})

// 图 11：从 B 指向 A 的向量为 a - b
#let point-difference(length: 0.72cm) = canvas(length: length, {
  import draw: *
  grid-lines(6, 4, length: length, origin: (0.5, 0.5))
  let o = (0.5, 0.5)
  let a = (1.5, 2.5)
  let b = (4.5, 1.5)
  vector-arrow(o, (1, 2), color: palette.red)
  vector-arrow(o, (4, 1), color: palette.red)
  vector-arrow(b, (-3, 1))
  point-mark(a, length)
  point-mark(b, length)
  content((1.5, 2.65), $A$, anchor: "south")
  content((4.5, 1.65), $B$, anchor: "south")
  content((0.85, 1.5), text(fill: palette.red, $bold(arrow(a))$), anchor: "east")
  content((2.7, 0.75), text(fill: palette.red, $bold(arrow(b))$), anchor: "north")
  content((3, 2.2), text(fill: palette.green, $bold(arrow(a)) - bold(arrow(b))$), anchor: "south")
})

// 图 12：锐角的点积为正，钝角的点积为负
#let dot-product-sign(length: 0.72cm) = canvas(length: length, {
  import draw: *
  for (ox, angle, label) in ((1, 63deg, $bold(arrow(b))$), (7, 133deg, $bold(arrow(c))$)) {
    let o = (ox, 1)
    space-axes(o, factor: 0.65)
    vector-arrow(o, (2.8, 1))
    vector-arrow(o, (2.6 * calc.cos(angle), 2.6 * calc.sin(angle)))
    // 圆弧从 a 的方向开始，止于另一个向量的方向
    let start = calc.atan2(2.8, 1)
    let points = range(25).map(i => {
      let t = start + (angle - start) * i / 24
      (ox + 0.6 * calc.cos(t), 1 + 0.6 * calc.sin(t))
    })
    line(..points, stroke: palette.text + 0.6pt)
    content((ox + 1.5, 1.75), text(fill: palette.green, $bold(arrow(a))$), anchor: "south")
    content((ox + 1.4 * calc.cos(angle) - 0.15, 1 + 1.4 * calc.sin(angle)), text(fill: palette.green, label), anchor: "east")
  }
})

// 图 13：a 在 b 方向上的投影长度
#let vector-projection(length: 0.72cm) = canvas(length: length, {
  import draw: *
  grid-lines(10, 4, length: length, origin: (0.8, 0.8))
  let o = (0.8, 0.8)
  vector-arrow(o, (5, 2))
  vector-arrow(o, (9, 0))
  point-mark(o, length, color: palette.green)
  line((5.8, 0.8), (5.8, 2.8), stroke: palette.gray + 0.6pt)
  line((5.55, 0.8), (5.55, 1.05), (5.8, 1.05), stroke: palette.gray + 0.6pt)
  let angle = calc.atan2(5, 2)
  let points = range(21).map(i => (0.8 + calc.cos(angle * i / 20), 0.8 + calc.sin(angle * i / 20)))
  line(..points, stroke: palette.text + 0.6pt)
  content((2, 1.02), $theta$, anchor: "west")
  content((3.25, 1.95), text(fill: palette.green, $bold(arrow(a))$), anchor: "south")
  content((7.3, 0.95), text(fill: palette.green, $bold(arrow(b))$), anchor: "south")
  line((0.8, 0.15), (5.8, 0.15), stroke: palette.gray + 0.6pt)
  for x in (0.8, 5.8) {
    line((x, -0.1), (x, 0.55), stroke: palette.gray + 0.6pt)
    line((x - 0.12, 0.03), (x + 0.12, 0.27), stroke: palette.gray + 0.6pt)
  }
  content((3.3, -0.15), text(fill: palette.text)[projection length], anchor: "north")
})

// 图 14：三维叉积。先绕 Z 轴旋转，再绕 X 轴倾斜，正交投影到画布。
// 按原图构图：b 沿平面坐标轴，a 位于平面内；不套用后文的数值例题。
#let cross-product(length: 0.72cm) = canvas(length: length, padding: 0.15cm, {
  import draw: *
  let project(p) = {
    let (x, y, z) = p
    let azimuth = -67deg
    let tilt = 45deg
    let u = x * calc.cos(azimuth) - y * calc.sin(azimuth)
    let v = x * calc.sin(azimuth) + y * calc.cos(azimuth)
    let w = v * calc.cos(tilt) + z * calc.sin(tilt)
    let roll = 12deg
    (u * calc.cos(roll) - w * calc.sin(roll), u * calc.sin(roll) + w * calc.cos(roll))
  }
  // 原图：a 沿右下格线走 2 格、右上格线走 1 格；b 沿右上格线走 2 格。
  let a = (2, 1, 0)
  let b = (0, 2, 0)
  let cross = (
    a.at(1) * b.at(2) - a.at(2) * b.at(1),
    a.at(2) * b.at(0) - a.at(0) * b.at(2),
    a.at(0) * b.at(1) - a.at(1) * b.at(0),
  )
  // XY 平面的格线与坐标轴共用三维坐标，原点严格落在格点上。
  for x in range(0, 4) {
    if x != 0 {
      line(project((x, -1, 0)), project((x, 3, 0)), stroke: palette.grid + 0.4pt)
    }
  }
  for y in range(0, 3) {
    if y != 0 {
      line(project((-1, y, 0)), project((4, y, 0)), stroke: palette.grid + 0.4pt)
    }
  }
  let o = project((0, 0, 0))
  line(project((-1, 0, 0)), o, stroke: rgb("#666666") + 0.4pt)
  line(project((0, -1, 0)), o, stroke: rgb("#666666") + 0.4pt)
  line(o, project((4, 0, 0)), stroke: palette.x-axis + 0.4pt)
  line(o, project((0, 3, 0)), stroke: palette.y-axis + 0.4pt)
  vector-arrow(o, project(a), color: palette.red)
  vector-arrow(o, project(b), color: palette.red)
  vector-arrow(o, project(cross), color: palette.green)
  // 两个直角标记分别位于 a/Z 与 b/Z 平面，随三维视角一起投影。
  for v in (a, b) {
    let norm = calc.sqrt(v.at(0) * v.at(0) + v.at(1) * v.at(1))
    let dx = 0.3 * v.at(0) / norm
    let dy = 0.3 * v.at(1) / norm
    line(project((dx, dy, 0)), project((dx, dy, 0.3)), project((0, 0, 0.3)), stroke: palette.gray + 0.5pt)
  }
  let pa = project(a)
  let pb = project(b)
  content((pa.at(0) * 0.72, pa.at(1) * 0.72 - 0.15), text(fill: palette.red, $bold(arrow(a))$), anchor: "north")
  content((pb.at(0) * 0.7, pb.at(1) * 0.7 + 0.15), text(fill: palette.red, $bold(arrow(b))$), anchor: "south")
  let pc = project(cross)
  content((pc.at(0) * 0.66 + 0.15, pc.at(1) * 0.66), text(fill: palette.green, $bold(arrow(a)) times bold(arrow(b))$), anchor: "west")
})

// 图 15：相同向量长度、不同夹角；两组叉积的模分别为 2 和 4。
#let cross-product-angle(length: 0.72cm) = canvas(length: length, padding: 0.15cm, {
  import draw: *
  // 两组共用相机；Z 轴向右倾斜，与原图一致。
  let project(p) = {
    let (x, y, z) = p
    let azimuth = -25deg
    let tilt = 45deg
    let roll = -12deg
    let u = x * calc.cos(azimuth) - y * calc.sin(azimuth)
    let v = (x * calc.sin(azimuth) + y * calc.cos(azimuth)) * calc.cos(tilt) + z * calc.sin(tilt)
    (u * calc.cos(roll) - v * calc.sin(roll), u * calc.sin(roll) + v * calc.cos(roll))
  }
  let b = (-1, -2, 0)
  for (offset, a) in ((0, (-1.6, -1.2, 0)), (4.2, (-2, 0, 0))) {
    let pos(p) = {
      let q = project(p)
      (q.at(0) + offset, q.at(1))
    }
    let o = pos((0, 0, 0))
    // 原图格点：右侧 a 沿负 X 方向 2 格，b 为负 X 1 格、负 Y 2 格。
    // 左侧仅旋转 a，保持 |a| = 2、|b| = sqrt(5)。
    for x in range(-2, 1) {
      if x != 0 {
        line(pos((x, -2.5, 0)), pos((x, 1, 0)), stroke: palette.grid + 0.4pt)
      }
    }
    for y in range(-2, 1) {
      if y != 0 {
        line(pos((-2.5, y, 0)), pos((0.8, y, 0)), stroke: palette.grid + 0.4pt)
      }
    }
    line(pos((-2.5, 0, 0)), o, stroke: rgb("#666666") + 0.4pt)
    line(pos((0, -2.5, 0)), o, stroke: rgb("#666666") + 0.4pt)
    line(o, pos((0.8, 0, 0)), stroke: palette.x-axis + 0.4pt)
    line(o, pos((0, 1, 0)), stroke: palette.y-axis + 0.4pt)
    let cross = (0, 0, a.at(0) * b.at(1) - a.at(1) * b.at(0))
    vector-arrow(o, project(a), color: palette.red)
    vector-arrow(o, project(b), color: palette.red)
    vector-arrow(o, project(cross), color: palette.green)
    // 夹角弧在 XY 平面内绘制，再随相机一起投影。
    let start = calc.atan2(a.at(0), a.at(1))
    let end = calc.atan2(b.at(0), b.at(1))
    if end < start { end += 360deg }
    let points = range(25).map(i => {
      let t = start + (end - start) * i / 24
      pos((0.4 * calc.cos(t), 0.4 * calc.sin(t), 0))
    })
    line(..points, stroke: palette.text + 0.5pt)
    point-mark(o, length, color: palette.green)
    let pa = project(a)
    let pb = project(b)
    let pc = project(cross)
    content((offset + pa.at(0) * 0.62, pa.at(1) * 0.62 + 0.15), text(fill: palette.red, $bold(arrow(a))$), anchor: "south")
    content((offset + pb.at(0) * 0.62, pb.at(1) * 0.62 - 0.12), text(fill: palette.red, $bold(arrow(b))$), anchor: "north")
    content((offset + pc.at(0) * 0.8 - 0.12, pc.at(1) * 0.8), text(fill: palette.green, $bold(arrow(a)) times bold(arrow(b))$), anchor: "east")
  }
})

// 图 16、17：共用相同的直线、位置向量和点坐标。
#let line-vector-diagram(length: 0.72cm, midpoint: false) = canvas(length: length, padding: 0.15cm, {
  import draw: *
  let o = (1, 1)
  let q = (2, 2.9)
  let p = (5.2, 3.8)
  let a = (p.at(0) - q.at(0), p.at(1) - q.at(1))
  space-axes(o)
  // L 穿过 Q、P；向两端延长。
  line((0, q.at(1) - 2 * a.at(1) / a.at(0)), (6.2, p.at(1) + a.at(1) / a.at(0)), stroke: palette.red + 0.4pt)
  vector-arrow(o, (q.at(0) - o.at(0), q.at(1) - o.at(1)))
  vector-arrow(o, (p.at(0) - o.at(0), p.at(1) - o.at(1)))
  vector-arrow(q, a, color: palette.text, thickness: 1.2pt)
  content((0.25, 2.7), text(fill: palette.red, $L$), anchor: "south")
  content((1.35, 2.05), text(fill: palette.green, $bold(arrow(q))$), anchor: "east")
  content((3, 2.05), text(fill: palette.green, $bold(arrow(p))$), anchor: "north-west")
  if midpoint {
    let m = ((q.at(0) + p.at(0)) / 2, (q.at(1) + p.at(1)) / 2)
    line((m.at(0), m.at(1) - 0.13), (m.at(0), m.at(1) + 0.13), stroke: palette.text + 1.2pt)
    content((m.at(0), m.at(1) + 0.25), $M$, anchor: "south")
    content((3.15, 3.05), $bold(arrow(a))$, anchor: "north")
  } else {
    // v 与 QP 平行且为单位向量。
    let norm = calc.sqrt(a.at(0) * a.at(0) + a.at(1) * a.at(1))
    let v = (a.at(0) / norm, a.at(1) / norm)
    vector-arrow(o, v)
    content((o.at(0) + v.at(0) + 0.15, o.at(1) + v.at(1)), text(fill: palette.green, $bold(arrow(v))$), anchor: "west")
    content((3.35, 3.5), $bold(arrow(a))$, anchor: "south")
  }
  // 原图的空心方形点标记，尺寸不随画布缩放。
  let r = 0.065cm / length
  for (pos, label) in ((q, $Q$), (p, $P$)) {
    rect((pos.at(0) - r, pos.at(1) - r), (pos.at(0) + r, pos.at(1) + r), fill: white, stroke: palette.text + 0.8pt)
    content((pos.at(0), pos.at(1) + 0.2), label, anchor: "south")
  }
})
#let line-vector-equation(length: 0.72cm) = line-vector-diagram(length: length)
#let line-midpoint(length: 0.72cm) = line-vector-diagram(length: length, midpoint: true)

// 图 18：位置向量和由 A 出发的两条平面内向量；法向量从 A 向上。
#let plane-vectors(length: 0.72cm) = canvas(length: length, padding: 0.15cm, {
  import draw: *
  let o = (1, 1.3)
  let a = (5, 2.3)
  let b = (1.6, 0.25)
  let c = (2, 2.3)
  space-axes(o, factor: 0.85)
  for (p, label, label-pos) in (
    (a, $bold(arrow(a))$, (2.65, 1.75)),
    (b, $bold(arrow(b))$, (1.05, 0.7)),
    (c, $bold(arrow(c))$, (1.3, 2.05)),
  ) {
    vector-arrow(o, (p.at(0) - o.at(0), p.at(1) - o.at(1)))
    content(label-pos, text(fill: palette.green, label), anchor: "south")
  }
  vector-arrow(a, (b.at(0) - a.at(0), b.at(1) - a.at(1)), color: palette.text, thickness: 1.2pt)
  vector-arrow(a, (c.at(0) - a.at(0), c.at(1) - a.at(1)), color: palette.text, thickness: 1.2pt)
  vector-arrow(a, (0, 1.6), color: palette.red, thickness: 1.2pt)
  content((4.8, 3.05), text(fill: palette.red, $bold(arrow(n))$), anchor: "east")
  let r = 0.065cm / length
  for p in (a, b, c) {
    rect((p.at(0) - r, p.at(1) - r), (p.at(0) + r, p.at(1) + r), fill: white, stroke: palette.text + 0.8pt)
  }
  content((a.at(0) + 0.2, a.at(1)), $A$, anchor: "west")
  content((b.at(0), b.at(1) - 0.2), $B$, anchor: "north")
  content((c.at(0), c.at(1) + 0.2), $C$, anchor: "south")
})

// 单位矩阵示意：使用原生表格，数值与边框均为矢量内容。
#let matrix-cells(values, columns: 4, fill: rgb("#e5e5e5")) = table(
  columns: (1fr,) * columns,
  align: center + horizon,
  stroke: (paint: rgb("#666666"), thickness: 0.5pt),
  fill: fill,
  inset: (x: 4pt, y: 5pt),
  ..values,
)
#let identity-values = (
  $1.0$, $0.0$, $0.0$, $0.0$,
  $0.0$, $1.0$, $0.0$, $0.0$,
  $0.0$, $0.0$, $1.0$, $0.0$,
  $0.0$, $0.0$, $0.0$, $1.0$,
)
#let identity-matrix() = matrix-cells(identity-values)
#let identity-multiplication() = layout(size => {
  set text(size: calc.min(9pt, size.width / 48))
  let point = ($2.0$, $3.0$, $1.0$, $1.0$)
  grid(
    columns: (4fr, auto, 1fr, auto, 7fr, auto, 1fr),
    column-gutter: 5pt,
    align: center + horizon,
    identity-matrix(), $times$,
    matrix-cells(point, columns: 1), $=$,
    matrix-cells((
      $1.0 times 2.0 + 0.0 times 3.0 + 0.0 times 1.0 + 0.0 times 1.0$,
      $0.0 times 2.0 + 1.0 times 3.0 + 0.0 times 1.0 + 0.0 times 1.0$,
      $0.0 times 2.0 + 0.0 times 3.0 + 1.0 times 1.0 + 0.0 times 1.0$,
      $0.0 times 2.0 + 0.0 times 3.0 + 0.0 times 1.0 + 1.0 times 1.0$,
    ), columns: 1, fill: white), $=$,
    matrix-cells(point, columns: 1),
  )
})
