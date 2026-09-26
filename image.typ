#import "@preview/cetz:0.5.2": canvas, draw
#import "@preview/scenery:0.1.0" as scenery
#import "config.typ": palette, diagram-style, matrix-style, data-table-style, arrow-mark, diagram-red as red, diagram-green as green

// 共享几何数据与向量运算。
// Geometry shared by curve drawings and their parameter/derivative annotations.
// Rendering uses the local cetz-nurbs WASM. Points and analytic derivatives
// use the library evaluation API in the original parameter parameter-domain.
#import "@local/cetz-nurbs:0.1.0": nurbs, native-cubics, from-control-points, interpolate-at-parameters
#let vector-add(a,b)=a.zip(b).map(((x,y))=>x+y)
#let vector-scale(a,s)=a.map(x=>x*s)
#let vector-subtract(a,b)=vector-add(a,vector-scale(b,-1))
#let interpolate-points(a,b,t)=vector-add(vector-scale(a,1-t),vector-scale(b,t))
#let vector-norm(a)=calc.sqrt(a.map(x=>x*x).sum())
#let curve-spec(points, degree:3, knots:none, weights:none)={
  let result=if knots==none {from-control-points(points,degree:degree)} else {
    (control_points:points,knots:knots,weights:points.map(_=>1))
  }
  if weights!=none {result.weights=weights}
  result.insert("tolerance",0.0001)
  result
}
#import "@local/cetz-nurbs:0.1.0": curve-degree as spline-degree, curve-domain as parameter-domain, evaluate-point, evaluate-derivatives
#let curve-at(s,t)={let (a,b)=parameter-domain(s); evaluate-point(s,a+(b - a)*t)}
#let curve-curvature-data(s,u)={
  let j=evaluate-derivatives(s,u);let (dx,dy)=j.first;let (ddx,ddy)=j.second
  let speed=vector-norm(j.first)
  (point:j.point,normal:(-dy/speed,dx/speed),k:(dx*ddy - dy*ddx)/calc.pow(speed,3))
}
#let shifted-curve(s,offset)={let q=s; q.control_points=s.control_points.map(p=>vector-add(p,offset)); q}
#let circle-data(center:(0,0),r:1,ry:none)={
  let ry=if ry==none {r} else {ry}
  curve-spec(((1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1),(1,0)).map(p=>vector-add(center,(r*p.at(0),ry*p.at(1)))),
    degree:2,knots:(0,0,0,1,1,2,2,3,3,4,4,4),
    weights:(1,calc.sqrt(0.5),1,calc.sqrt(0.5),1,calc.sqrt(0.5),1,calc.sqrt(0.5),1))
}
#let wave-data=curve-spec(((0,2),(0.1,4.3),(1.8,4.3),(3,1.3),(4,-0.4),(5.2,3),(7,0.5)))


// 点标记：红色叉（可换色）
// unit 为每格长度；size 为绝对尺寸(cm)，因此缩放画布不会改变点的大小
#let point-mark(
  pos,
  unit,
  size: diagram-style.cross.half-size,
  color: palette.point,
  thickness: diagram-style.cross.thickness,
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
  thickness: diagram-style.arrow.thickness,
) = {
  import draw: *
  line(
    start,
    (start.at(0) + vec.at(0), start.at(1) + vec.at(1)),
    stroke: (paint: color, thickness: thickness),
    mark: arrow-mark(color,thickness:thickness),
  )
}

// 背景统一绘制网格与二维坐标轴；网格以原点为基准，坐标轴就是加深的格线。
// 固定物理间距，无外框；offset 指定背景区域左下角。
#let grid-lines(x1, y1, length: diagram-style.unit, offset: (0, 0), origin: (1, 1)) = {
  import draw: *
  let step = diagram-style.unit / length
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
  let a-mark = arrow-mark(palette.gray,thickness:1pt)
  let ox = o.at(0)
  let oy = o.at(1)
  line((ox, oy), (ox, oy + 3 * factor), stroke: a-stroke, mark: a-mark)
  line((ox, oy), (ox + 5 * factor, oy), stroke: a-stroke, mark: a-mark)
  line((ox, oy), (ox - 1 * factor, oy - 1 * factor), stroke: a-stroke, mark: a-mark)
}

// 图 1：同一向量的等价表示（起点不同，方向与长度相同）
#let vector-equivalent(length: diagram-style.unit) = canvas(length: length, {
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
#let vector-point-relation(length: diagram-style.unit) = canvas(length: length, {
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
#let position-vector(length: diagram-style.unit) = canvas(length: length, {
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
#let vector-and-point(length: diagram-style.unit) = canvas(length: length, {
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
#let vector-length(length: diagram-style.unit) = canvas(length: length, {
  import draw: *
  let o = (3, 2)
  space-axes(o)
  // 向量 a
  vector-arrow(o, (3.5, 2.2), color: palette.green3d, thickness: 0.8pt)
  content((4.6, 3.35), text(fill: palette.green3d, $bold(arrow(a))$), anchor: "south")
})

// 图 6：单位向量
#let unit-vector(length: diagram-style.unit) = canvas(length: length, {
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
#let scalar-multiplication(length: diagram-style.unit) = canvas(length: length, padding: 0.2cm, {
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
    text(fill: palette.green3d, $ 2 dot bold(arrow(a)) $),
    anchor: "south-east",
  )
})

// 图 8：首尾相接的向量加法
#let vector-addition(length: diagram-style.unit) = canvas(length: length, {
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
#let average-direction(length: diagram-style.unit) = canvas(length: length, {
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
#let vector-subtraction(length: diagram-style.unit) = canvas(length: length, {
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
#let point-difference(length: diagram-style.unit) = canvas(length: length, {
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
#let dot-product-sign(length: diagram-style.unit) = canvas(length: length, {
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
#let vector-projection(length: diagram-style.unit) = canvas(length: length, {
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
#let cross-product(length: diagram-style.unit) = canvas(length: length, padding: 0.15cm, {
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
#let cross-product-angle(length: diagram-style.unit) = canvas(length: length, padding: 0.15cm, {
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
#let line-vector-diagram(length: diagram-style.unit, midpoint: false) = canvas(length: length, padding: 0.15cm, {
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
#let line-vector-equation(length: diagram-style.unit) = line-vector-diagram(length: length)
#let line-midpoint(length: diagram-style.unit) = line-vector-diagram(length: length, midpoint: true)

// 图 18：位置向量和由 A 出发的两条平面内向量；法向量从 A 向上。
#let plane-vectors(length: diagram-style.unit) = canvas(length: length, padding: 0.15cm, {
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
#let matrix-cells(values, columns: 4, fill: matrix-style.fill) = table(
  columns: (1fr,) * columns,
  align: center + horizon,
  stroke: matrix-style.stroke,
  fill: fill,
  inset: matrix-style.inset,
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

// NURBS 曲线插图：所有曲线由本地 cetz-nurbs 库生成。
#let curve-example-controls=((0,0),(0,3.3),(2,3.7),(3.6,0),(5,3.2),(7,3.5),(7,0))
#let curve-example=curve-spec(curve-example-controls,knots:(0,0,0,0,1,2,3,4,4,4,4))
// 图 34：按原图的八个控制点重建，左右两幅共用此曲线。
#let control-structure-data=curve-spec(
  ((0,3.42),(0.66,4.34),(2.2,4.02),(2.06,2.1),
   (4.1,0),(4.62,2.96),(7.58,1.38),(8.14,1.74)),
)
#let curve-guide-color=diagram-style.guide-color
#let curve-label(p,body,anchor:"south",color:black)=draw.content(p,text(size:diagram-style.label.size,fill:color,body),anchor:anchor,padding:diagram-style.label.padding)
#let control-point-marker(p,color:diagram-style.control-point.color)=draw.circle(p,
  radius:diagram-style.control-point.radius,fill:diagram-style.control-point.fill,
  stroke:color+diagram-style.control-point.thickness)
#let node-marker(p,color:diagram-style.node.color)={
  let r=diagram-style.node.half-size
  draw.rect(vector-add(p,(-r,-r)),vector-add(p,(r,r)),
    fill:diagram-style.node.fill,stroke:color+diagram-style.node.thickness)
}
#let draw-curve(s,controls:true,color:black,labels:false)={
  nurbs(s,stroke:color+diagram-style.curve-thickness,control-polygon:controls,
    polygon-stroke:diagram-style.control-polygon)
  if controls {for (i,p) in s.control_points.enumerate() {
    control-point-marker(p,color:color)
    if labels {curve-label(p,[$P_#i$],anchor:if calc.rem(i,2)==0 {"north"} else {"south"})}
  }}
}
#let knot-map(s,values:none,y:-1.1,labels:true)={
  let (a,b)=parameter-domain(s)
  let values=if values==none {s.knots.dedup().filter(u=>u>=a and u <= b)} else {values}
  draw.line((0,y),(7,y),stroke:palette.red+0.9pt)
  for (i,u) in values.enumerate() {
    let p=evaluate-point(s,u); let q=(7*(u - a)/(b - a),y)
    draw.line(q,p,stroke:curve-guide-color+0.35pt)
    control-point-marker(p);control-point-marker(q,color:palette.red)
    if labels {curve-label(q,str(calc.round(u,digits:2)),anchor:"north",color:palette.red)}
  }
}
#let weight-labels(s)={
  for (i,p) in s.control_points.slice(0,-1).enumerate() {
    let v=s.weights.at(i)
    curve-label(p,if v==1 {[$w=1$]} else {[$w=sqrt(2)/2$]},anchor:if p.at(1) < 0 {"north"} else {"south"},color:palette.green)
  }
}
#let span-elements(deg)={
  let data=curve-spec(((0,1),(0.8,0),(3,0),(5.5,2.4),(6.4,1)),degree:deg)
  let cubics=native-cubics(data)
  draw-curve(data)
  for (i,c) in cubics.enumerate() {
    curve-label(curve-at(curve-spec(c),0.5),str(i+1))
    let off=(0,-3*(i+1))
    draw-curve(shifted-curve(data,off),controls:false,color:palette.gray)
    draw-curve(curve-spec(c.map(p=>vector-add(p,off))),controls:false)
    let active=data.control_points.slice(i,i+deg+1).map(p=>vector-add(p,off))
    draw.line(..active,stroke:curve-guide-color+0.4pt)
    for p in active {control-point-marker(p)}
    curve-label(vector-add(curve-at(curve-spec(c),0.5),off),str(i+1))
  }
}
#let loop-controls=((0,1.5),(1,3.5),(3,3),(5,0),(7,0),(8,2),(7,3),(5,3),(2,-0.5))
#let loop-data(moved:false,periodic:true)={
  let pts=loop-controls
  if moved {pts.at(0)=(2,1.5);pts.at(1)=(-0.5,3.7)}
  from-control-points(pts,degree:3,periodic:periodic,close:true)
}
#let curvature-comb(s,scale:0.6,color:palette.green)={
  let (a,b)=parameter-domain(s)
  let tips=()
  for i in range(31) {
    let c=curve-curvature-data(s,a+(b - a)*i/30)
    let tip=vector-add(c.point,vector-scale(c.normal,c.k*scale))
    draw.line(c.point,tip,stroke:color+0.35pt); tips.push(tip)
  }
  draw.line(..tips,stroke:color+0.5pt)
}
// The endpoint jets prescribe the continuity-elements: G0 changes direction, G1
// changes curvature, G2 shares first and second derivatives at the join.
#let continuity-pair(level)={
  let a=curve-spec(((0,0),(1,0),(1,2),(2,2)))
  let b=curve-spec(if level==0 {((2,2),(3,1.4),(4,1),(4,0))}
    else if level==1 {((2,2),(3,2),(4,1.5),(4,0))}
    else {((2,2),(3,2),(5,0),(5,-1))})
  (a,b)
}
#let continuity-elements(combs:false)={
  for level in range(3) {
    let (a,b)=continuity-pair(level)
    let off=(level*5.6,0)
    a=shifted-curve(a,off);b=shifted-curve(b,off)
    draw-curve(a,controls:false);draw-curve(b,controls:false,color:palette.red)
    // 三组共用比例；梳齿长度低于局部曲率半径，避免向内汇聚后交叉。
    if combs {curvature-comb(a,scale:0.30);curvature-comb(b,scale:0.30,color:palette.red)}
    curve-label((level*5.6+2,-0.5),[$G_#level$],anchor:"north")
  }
}
#let deboor-elements(stage:none)={
  // 从原图控制多边形重建；四幅图共享同一条三阶曲线。
  let s=curve-spec(((109,272),(24,215),(28,84),(130,26),(276,49),(323,184),(239,267)).map(
    p=>(p.at(0)/60,(272 - p.at(1))/60)),
    knots:(0,0,0,0,0.25,0.5,0.75,1,1,1,1))
  let u=0.4; let d=s.control_points.slice(1,5); let stages=(d,)
  for r in range(1,4) {
    for j in range(r,4).rev() {
      let i=1+j; let alpha=(u - s.knots.at(i))/(s.knots.at(i+4 - r)-s.knots.at(i))
      d.at(j)=interpolate-points(d.at(j - 1),d.at(j),alpha)
    }
    stages.push(d.slice(r))
  }
  assert(vector-norm(vector-subtract(stages.last().first(),evaluate-point(s,u))) < 0.0000001)
  let label(p,body,anchor:"south",size:6pt)=draw.content(p,
    text(font:"Arial",size:size,body),anchor:anchor,padding:1pt)
  let names=(("A","B","C"),("D","E"),("F",))
  let formulas=(("0.2P1 + 0.8P2","0.47P2 + 0.53P3","0.8P3 + 0.2P4"),
    ("0.2A + 0.8B","0.7B + 0.3C"),("0.4D + 0.6E",))
  let selected=stage
  for stage in (if selected==none {range(4)} else {(selected,)}) {
    let off=(0,if selected==none {-4.85*stage} else {0})
    let pos(p)=vector-add(p,off)
    nurbs(shifted-curve(s,off),stroke:black+(if stage==0 {1pt} else {0.45pt}))
    draw.line(..s.control_points.map(pos),stroke:(paint:black,thickness:0.35pt,dash:"dotted"))
    if stage<=1 {
      for (i,p) in s.control_points.enumerate() {
        label(pos(p),[P#i],anchor:if i in (0,6) {"north"} else if i in (1,2) {"east"} else {"south-west"})
      }
    }
    if stage==0 {
      for (t,shift) in ((0,(0.15,0.4)),(0.25,(0.6,-0.12)),(0.5,(0,-0.35)),(0.75,(-0.55,-0.18)),(1,(-0.3,0.38))) {
        let p=evaluate-point(s,t)
        let tangent=vector-subtract(evaluate-point(s,calc.min(1,t+0.0001)),evaluate-point(s,calc.max(0,t - 0.0001)))
        let n=(-tangent.at(1),tangent.at(0)); n=vector-scale(n,0.065/vector-norm(n))
        draw.line(pos(vector-subtract(p,n)),pos(vector-add(p,n)),stroke:black+0.75pt)
        label(pos(vector-add(p,shift)),[u=#t],anchor:"center")
      }
    } else {
      // 保留前一轮辅助线，突出本轮线性插值段及其系数。
      for r in range(1,stage+1) {
        let points=stages.at(r).map(pos)
        if points.len()>1 {draw.line(..points,stroke:palette.red+(if r==stage {0.9pt} else {0.35pt}))}
      }
      let previous=stages.at(stage - 1)
      if stage>1 {
        for (i,p) in previous.enumerate() {label(pos(p),names.at(stage - 2).at(i))}
      }
      for (i,p) in stages.at(stage).enumerate() {
        let q=pos(p)
        draw.circle(q,radius:diagram-style.interpolation-point.radius,fill:diagram-style.interpolation-point.fill,stroke:black+diagram-style.interpolation-point.thickness)
        label(vector-add(q,(0.06,-0.09)),names.at(stage - 1).at(i),anchor:"north-west")
        label(vector-add(q,(0.23,-0.28)),formulas.at(stage - 1).at(i),anchor:"north-west",size:5pt)
      }
    }
  }
}
// 三幅投影共用控制点、节点、权重和相机。原图未提供模型数据；
// 按原图的控制多边形重建此教学曲线，不把屏幕轮廓另行拟合成三条曲线。
#let projection-curve-data = curve-spec(
  ((0, 0, 0), (2.5, 0.75, 2.1), (5, 1, 1.2), (1.25, 4, 1.65), (0, 4, 1.55)),
  knots: (0, 0, 0, 0, 1, 2, 2, 2, 2),
)
// 正交相机的两个单位基向量互相垂直：X 右下、Y 右上、Z 向上。
#let projection-camera(p) = (
  (p.at(0) + p.at(1)) * calc.cos(45deg),
  (p.at(1) - p.at(0)) * calc.sin(15deg) * calc.cos(45deg) + p.at(2) * calc.cos(15deg),
)
#let projected-curve-data(axis) = {
  assert(axis in (0, 1, 2))
  let s = projection-curve-data
  s.control_points = s.control_points.map(p => {
    let q = p
    q.at(axis) = 0
    q
  })
  s
}
#let projection-elements(axis) = {
  let source = projection-curve-data
  let flat = projected-curve-data(axis)
  // 先作世界坐标平面投影，再将两条曲线用同一个相机投到纸面。
  let screen(s) = {
    let result = s
    result.control_points = s.control_points.map(projection-camera)
    result
  }
  let original = screen(source)
  let projected = screen(flat)
  draw.line(..original.control_points,
    stroke: (paint:black, thickness: 0.45pt, dash: "dotted"))
  nurbs(original, stroke: (if axis == 1 { black } else { palette.red }) + 0.8pt)
  nurbs(projected, stroke: palette.green + 0.8pt)
  for p in original.control_points {
    draw.line(vector-add(p, (-0.035, -0.035)), vector-add(p, (0.035, 0.035)), stroke: palette.red + 1pt)
    draw.line(vector-add(p, (-0.035, 0.035)), vector-add(p, (0.035, -0.035)), stroke: palette.red + 1pt)
  }
  for (p, name, color) in (((4.2, 0, 0), $x$, palette.red), ((0, 6.2, 0), $y$, palette.green)) {
    let end = projection-camera(p)
    vector-arrow((0, 0), end, color: color, thickness: 0.65pt)
    draw.content(vector-add(end, (0.09, 0)), text(size: 9pt, fill: color, name), anchor: "west")
  }
}
// 曲线特性表：按六张原图的控制结构重建，统一略压低纵向比例。
#let property-curve-data(kind)={
  let point(p)=(p.at(0)/50,-p.at(1)*0.85/50)
  if kind in ("open-polyline","open-cubic") {
    let points=if kind=="open-polyline" {
      ((14,68),(19,14),(71,8),(116,41),(170,30),(223,20),(245,68))
    } else {((19,93),(6,29),(73,10),(133,93),(179,40),(251,34),(250,92))}
    curve-spec(points.map(point),degree:if kind=="open-polyline" {1} else {3})
  } else if kind in ("periodic-curve","periodic-edit") {
    let points=((8,66),(55,11),(145,21),(241,121),(302,53),(218,22),(94,130))
    if kind=="periodic-edit" {points.at(0)=(138,53)}
    from-control-points(points.map(point),degree:3,periodic:true)
  } else {
    let points=((13,57),(7,39),(35,6),(118,15),(205,106),(241,64),
      (238,49),(235,34),(184,15),(71,114),(19,75),(13,57))
    if kind=="closed-edit" {points.at(0)=(59,51);points.at(11)=(59,51);points.at(6)=(200,54)}
    // 夹紧闭合接缝与中部三重节点直接经过对应控制点。
    curve-spec(points.map(point),knots:(0,0,0,0,1,2,3,4,4,4,5,6,7,7,7,7))
  }
}
#let property-curve-elements(kind)={
  import draw: *
  let data=property-curve-data(kind)
  if kind!="open-polyline" {
    line(..data.control_points,stroke:(paint:black,thickness:0.3pt,dash:"dotted"))
  }
  nurbs(data,stroke:black+0.9pt)
  for p in data.control_points.dedup() {
    rect(vector-add(p,(-0.027,-0.027)),vector-add(p,(0.027,0.027)),fill:white,stroke:black+0.4pt)
  }
}
#let curve-elements(id)={
  if id=="control-structure" {
    draw-curve(control-structure-data,controls:false,color:palette.red)
    let right=shifted-curve(control-structure-data,(7.5,0.1))
    nurbs(right,stroke:black+1pt,control-polygon:true,
      polygon-stroke:diagram-style.control-polygon)
    for p in right.control_points {
      draw.rect(vector-add(p,(-0.035,-0.035)),vector-add(p,(0.035,0.035)),
        fill:white,stroke:black+0.4pt)
    }
  } else if id in ("linear-spans","quadratic-spans","cubic-spans") {span-elements(("linear-spans":1,"quadratic-spans":2,"cubic-spans":3).at(id))
  } else if id=="weight-comparison" {
    let c=circle-data(r:2); let unit=c;unit.weights=c.weights.map(_=>1)
    draw-curve(unit);weight-labels(unit);c=shifted-curve(c,(6,0));draw-curve(c);weight-labels(c)
  } else if id in ("knot-domain","normalized-knots","simple-knots","repeated-knots","clamped-knots","parameter-evaluation") {
    let s=curve-example
    let compact=id in ("knot-domain","normalized-knots","clamped-knots")
    if compact {
      s.control_points=s.control_points.map(p=>(p.at(0),p.at(1)*0.45))
    }
    if id=="repeated-knots" {s.knots=(0,0,0,0,1,1,1,4,4,4,4)}
    if id=="normalized-knots" {s.knots=s.knots.map(u=>u/4)}
    draw-curve(s)
    if id not in ("simple-knots","repeated-knots") {
      knot-map(s,y:if compact {-0.7} else {-1.1},
        values:if id=="parameter-evaluation" {range(9).map(i=>i/2)} else {none})
      curve-label((3.5,if compact {-1.2} else {-2}),[节点（Rhino）：#s.knots.slice(1,-1).map(str).join(", ")],anchor:"north")
    }
  } else if id=="uniform-knots" {
    let periodic=from-control-points(((0,0),(0,3),(7,3),(7,0)),periodic:true)
    draw-curve(periodic);knot-map(periodic)
    curve-label((3.5,-2),[周期：#periodic.knots.slice(1,-1).map(str).join(", ")],anchor:"north")
    draw.group({draw.translate((9,0));draw-curve(curve-example);knot-map(curve-example)
      curve-label((3.5,-2),[夹紧：#curve-example.knots.slice(1,-1).map(str).join(", ")],anchor:"north")})
  } else if id=="nonuniform-knots" {
    let pts=((0,0),(0.2,0.8),(0.6,0.8),(4,-1),(6,0),(6.5,0.7),(7,0))
    for uniform in (false,true) {
      let s=curve-spec(pts,knots:if uniform {(0,0,0,0,25,50,75,100,100,100,100)} else {(0,0,0,0,13.5,78,93,100,100,100,100)})
      draw.group({
        if uniform {draw.translate((9,0))}
        draw-curve(s);knot-map(s)
        curvature-comb(shifted-curve(s,(0,3)),scale:0.12)
        draw-curve(shifted-curve(s,(0,3)),controls:false)
        curve-label((3.5,-2),if uniform {[均匀节点]} else {[非均匀节点]},anchor:"north")
      })
    }
  } else if id=="rational-circle" {
    let c=circle-data(center:(3.5,3),r:2)
    draw-curve(c);weight-labels(shifted-curve(circle-data(r:2),(3.5,3)))
    knot-map(c)
    curve-label((3.5,-2),[节点（Rhino）：0, 0, 1, 1, 2, 2, 3, 3, 4, 4],anchor:"north")
  } else if id in ("open-polyline","open-cubic","periodic-curve","periodic-edit","closed-curve","closed-edit") {
    property-curve-elements(id)
  } else if id=="deboor" {deboor-elements()
  } else if id in ("continuity-combs","continuity") {continuity-elements(combs:id=="continuity-combs")
  } else if id=="curvature-circles" {
    let s=wave-data
    draw-curve(s,controls:false)
    for t in (0.1,0.25,0.6,0.7,0.9) {
      let (a,b)=parameter-domain(s)
      let c=curve-curvature-data(s,a+(b - a)*t)
      let center=vector-add(c.point,vector-scale(c.normal,1/c.k))
      draw-curve(circle-data(center:center,r:calc.abs(1/c.k)),controls:false,color:palette.green)
      control-point-marker(c.point,color:palette.green)
    }
  } else if id=="continuity-vectors" {
    let (a,b)=continuity-pair(2); b=shifted-curve(b,(2,0))
    draw-curve(a,controls:false);draw-curve(b,controls:false,color:palette.red)
    for (s,u,n) in ((a,1,1),(b,0,2)) {
      let j=evaluate-derivatives(s,u);let c=curve-curvature-data(s,u)
      control-point-marker(j.point);curve-label(j.point,[$P_#n$],anchor:"east")
      let tangent=vector-scale(j.first,1.4/vector-norm(j.first))
      vector-arrow(j.point,tangent,color:palette.green)
      curve-label(vector-add(j.point,tangent),[$T_#n$],color:palette.green)
      let normal=vector-scale(c.normal,c.k*1.2)
      vector-arrow(j.point,normal,color:curve-guide-color);curve-label(vector-add(j.point,normal),[$C_#n$],anchor:"west")
    }
  } else if id in ("projection-xy","projection-xz","projection-yz") {projection-elements(("projection-xy":2,"projection-xz":1,"projection-yz":0).at(id))
  } else {panic("Unknown NURBS illustration: "+id)}
}

// 与本文件其它插图一致：具名函数，length 为画布单位，正文通过 fig(...) 调整宽度。
#let curve-diagram(kind, length: diagram-style.unit) = context {
  let measured = measure(canvas(length: 1cm, { curve-elements(kind) })).width
  let unit = 1cm * (8 * length / measured)
  canvas(length: unit, { curve-elements(kind) })
}
#let control-structure(length: diagram-style.unit) = curve-diagram("control-structure", length: length)
#let linear-spans(length: diagram-style.unit) = curve-diagram("linear-spans", length: length)
#let quadratic-spans(length: diagram-style.unit) = curve-diagram("quadratic-spans", length: length)
#let cubic-spans(length: diagram-style.unit) = curve-diagram("cubic-spans", length: length)
#let weight-comparison(length: diagram-style.unit) = curve-diagram("weight-comparison", length: length)
// 统一的模型/参数空间分区：文字距分割线固定为 1.2mm，不随绘图单位缩放。
#let space-panel(left,right,top,bottom,unit)={
  import draw: *
  let orange=rgb("#ff7900")
  let height=top - bottom
  rect((left,bottom),(right,top),fill:rgb("#fffaf4"),stroke:none)
  for i in range(int(calc.ceil((right - left+height)/0.06))+1) {
    let x=left - height+i*0.06
    let lo=calc.max(0,left - x);let hi=calc.min(height,right - x)
    if hi>lo {line((x+lo,bottom+lo),(x+hi,bottom+hi),stroke:rgb("#ffd9b3")+0.2pt)}
  }
  line((left,top),(right,top),stroke:orange+0.35pt)
  let x=(left+right)/2
  let gap=1.2mm/unit
  content((x,top+gap),text(font:"Arial",size:8pt,fill:gray)[3D Space],anchor:"south",padding:0pt)
  content((x,top - gap),text(font:"Arial",size:8pt,fill:orange)[Parameter Space],anchor:"north",padding:0pt)
}
// 原图 figure-38a / figure38A：同一曲线，参数轴按数值比例归一化。
#let knot-space-diagram(length:diagram-style.unit,normalized:false)=canvas(length:length,{
  import draw: *
  let data=curve-spec(((0,0),(-0.367,1.8),(1.767,1.44),(2.86,0.08),
    (3.867,1.533),(8.153,2.053),(8.107,0.02)),knots:(0,0,0,0,1,2,3,4,4,4,4))
  space-panel(-0.8,8.65,-0.42,-1.58,length)
  line(..data.control_points,stroke:(paint:black,thickness:0.35pt,dash:"dotted"))
  nurbs(data,stroke:black+1pt)
  for p in data.control_points {circle(p,radius:diagram-style.sample-point.tiny-radius,fill:diagram-style.sample-point.fill,stroke:black+diagram-style.sample-point.thickness)}
  content((6.35,1.35),text(font:"Arial",style:"normal",size:9pt,fill:gray)[Curve degree = 3])
  let span=if normalized {1.74 * 1.5} else {6.96}
  let start=4.1 - span/2
  let y=-0.98
  line((start,y),(start+span,y),stroke:rgb("#ff5555")+1pt)
  for i in range(5) {
    let p=evaluate-point(data,i)
    let q=(start+span*i/4,y)
    let end=interpolate-points(q,p,0.91)
    vector-arrow(q,vector-subtract(end,q),color:rgb("#cccccc"),thickness:0.45pt)
    rect(vector-add(p,(-0.03,-0.03)),vector-add(p,(0.03,0.03)),fill:white,stroke:black+0.4pt)
    content(vector-add(p,(0.06,0.11)),text(font:"Arial",style:"normal",size:10pt,("A","B","C","D","E").at(i)),anchor:"south-west")
    rect(vector-add(q,(-0.032,-0.032)),vector-add(q,(0.032,0.032)),fill:white,stroke:rgb("#ff5555")+0.4pt)
    content(vector-add(q,(0,-0.09)),text(font:"Arial",style:"normal",size:8pt,fill:rgb("#ff5555"),str(if normalized {i/4} else {i})),anchor:"north")
  }
  let values=if normalized {(0,0,0,0.25,0.5,0.75,1,1,1)} else {(0,0,0,1,2,3,4,4,4)}
  content((4,-1.46),text(font:"Arial",style:"normal",size:9pt,fill:red)[knots = <#values.map(str).join(",")>])
})
#let clamped-example-data()={
  let cp=((0.00000000,1.72000000),(0.04000000,1.88000000),(0.91893162,2.18330769),(1.40373932,2.49842308),(2.04611111,2.04300000),(2.77181624,1.86957692),(2.52662393,1.45869231),(8.77666667,0.63000000),(8.87000000,0.79000000))
  curve-spec(cp,knots:(0,0,0,0,1,2,3,4,5,6,6,6,6))
}
#let clamped-knot-diagram(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  let points=((0,1.72),(0.78,2.16),(1.43,2.37),(2.06,2.09),(2.61,1.83),(4.13,1.32),(8.87,0.79))
  // 七个节点处插值，端点切向约束；内部节点均为单一节点。
  let data=clamped-example-data()
  nurbs(data,stroke:rgb("#008800")+1pt)
  // 端点处三重节点：三个错开的方形标记，按原图强调重合。
  for (point,offsets) in ((points.first(),((-0.1,0),(0,0.16))),
    (points.last(),((-0.1,-0.16),(0.1,-0.16)))) {
    for offset in offsets {
      let p=vector-add(point,offset)
      rect(vector-add(p,(-0.055,-0.055)),vector-add(p,(0.055,0.055)),fill:white,stroke:black+0.65pt)
    }
  }
  line((-0.6,0.32),(9.15,0.32),stroke:black+0.4pt)
  line((0.65,-0.3),(7.8,-0.3),stroke:black+1pt)
  for (i,p) in points.enumerate() {
    let label=("a","b","c","d","e","f","g").at(i)
    let q=(0.65+7.15*i/6,-0.3)
    for pos in (p,q) {rect(vector-add(pos,(-0.055,-0.055)),vector-add(pos,(0.055,0.055)),fill:white,stroke:black+0.65pt)}
    content(vector-add(p,(0,-0.12)),text(font:"Arial",style:"normal",size:8pt,fill:red,label),anchor:"north")
    content(vector-add(q,(0,0.18)),text(font:"Arial",style:"normal",size:8pt,fill:red)[#label'],anchor:"south")
    let label=if i==0 {[0.0\ 0.0\ 0.0]} else if i==6 {[6.0\ 6.0\ 6.0]} else {[#i.0]}
    content(vector-add(q,(0,-0.15)),text(font:"Arial",style:"normal",size:6.5pt,weight:"bold",label),anchor:"north")
  }
  content((-0.48,-0.64),text(font:"Arial",style:"normal",size:7pt,weight:"bold")[knots:],anchor:"west")
})
#let knot-domain(length: diagram-style.unit) = knot-space-diagram(length:length)
#let normalized-knots(length: diagram-style.unit) = knot-space-diagram(length:length,normalized:true)
#let simple-knots(length: diagram-style.unit) = curve-diagram("simple-knots", length: length)
#let repeated-knots(length: diagram-style.unit) = curve-diagram("repeated-knots", length: length)
#let clamped-knots(length: diagram-style.unit) = clamped-knot-diagram(length:length)
// 图 39：原图的四点周期曲线与六点夹紧曲线，分别展示完整 Rhino 节点列表。
#let uniform-knots(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  let xy(p)=(p.at(0)/100,(443-p.at(1))/100)
  let periodic-cp=((464,261),(432,422),(52,295),(334,11)).map(xy)
  let periodic=curve-spec(periodic-cp+periodic-cp.slice(0,3),knots:range(-3,8))
  let clamped=curve-spec(((756,342),(680,244),(841,82),(940,281),(1124,217),(1163,330)).map(xy),
    knots:(0,0,0,0,1,2,3,3,3,3))
  space-panel(0,11.79,0,-1.53,length)
  for (data,polygon) in ((periodic,periodic-cp+(periodic-cp.first(),)),(clamped,clamped.control_points)) {
    line(..polygon,stroke:(paint:black,thickness:0.4pt,dash:"dotted"))
    nurbs(data,stroke:black+1pt)
    for p in polygon {circle(p,radius:diagram-style.sample-point.radius,fill:diagram-style.sample-point.fill,stroke:black+diagram-style.sample-point.thickness)}
    let start=evaluate-point(data,0)
    rect(vector-add(start,(-0.04,-0.04)),vector-add(start,(0.04,0.04)),fill:none,stroke:black+0.5pt)
    content(vector-add(start,(0.12,-0.08)),text(font:"Arial",size:8pt)[start],anchor:"west")
  }
  for p in ((295,245),(1030,165)) {content(xy(p),text(font:"Arial",size:8pt,fill:gray)[Degree=3])}
  for (data,lo,hi,x0,step,caption) in (
    (periodic,-2,6,0.38,0.733,[Periodic curve with uniform knots spacing]),
    (clamped,0,3,8.02,0.98,[Clamped curve with uniform knots spacing]),
  ) {
    let y=-0.66
    let (domain-start,domain-end)=parameter-domain(data)
    for i in range(lo,hi) {
      let color=if i < domain-start or i >= domain-end {gray} else {rgb("#ff5555")}
      line((x0+step*(i - lo),y),(x0+step*(i+1 - lo),y),stroke:color+1pt)
    }
    for i in range(lo,hi+1) {
      let p=(x0+step*(i - lo),y)
      let color=if i < domain-start or i > domain-end {gray} else {red}
      node-marker(p,color:color)
      content(vector-add(p,(0,0.12)),text(font:"Arial",size:7pt,fill:color,str(i)),anchor:"south")
    }
    let start=evaluate-point(data,0)
    let from=(x0+step*(if lo < 0 {0 - lo} else {0}),y)
    let tip=interpolate-points(from,start,0.91)
    vector-arrow(from,vector-subtract(tip,from),color:rgb("#cccccc"),thickness:0.5pt)
    let center=x0+step*(hi - lo)/2
    content((center,-1.04),text(font:"Arial",size:7pt,fill:red)[knots = <#data.knots.slice(1,-1).map(str).join(",")>])
    content((center,-1.3),text(font:"Arial",size:6pt,fill:red,caption))
  }
})
// 从原图的五个节点位置和轮廓重建；切向量为 dC/du，参数单位为 0–100。
#let knot-comparison-reference(uniform:false)={
  let points=((0,0.5),(0.5,0.91),(3.48,0.16),(4.04,0.57),(4.28,0.33))
  let parameters=if uniform {(0,25,50,75,100)} else {(0,13.5,78,93,100)}
  let knots=(0,0,0)+parameters+(100,100,100)
  let start=if uniform {(0.018664000000,0.019048000000)} else {(0.034814814815,0.036044444444)}
  let end=if uniform {(0.009600000000,-0.009600000000)} else {(0.035571428571,-0.035571428571)}
  interpolate-at-parameters(points,parameters,knots:knots,start-derivative:start,end-derivative:end)
}
// 显示示例缓和均匀曲线的急弯，避免局部近退化导致曲率峰值支配版面。
#let knot-comparison-data(uniform:false)={
  let data=knot-comparison-reference(uniform:uniform)
  if uniform {
    let smooth=knot-comparison-reference()
    data.control_points=data.control_points.zip(smooth.control_points).map(((a,b))=>interpolate-points(a,b,0.5))
  }
  data
}
// 与画布单位无关的数据只计算一次，fig 的尺寸测量与重绘共享这些结果。
#let knot-comparison-plots=(false,true).map(uniform=>{
  let data=knot-comparison-data(uniform:uniform)
  let upper=shifted-curve(data,(0,1.2))
  let tips=()
  let teeth=()
  let last-tip=none
  // 同一显示倍率；通过曲线形状缓和急弯，不裁剪曲率峰值。
  let comb-scale=0.05
  for i in range(4001) {
    let c=curve-curvature-data(upper,100*i/4000)
    let tip=vector-subtract(c.point,vector-scale(c.normal,c.k*comb-scale))
    tips.push(tip)
    if calc.rem(i,200)==0 or last-tip==none or vector-norm(vector-subtract(tip,last-tip))>0.12 {
      teeth.push((c.point,tip))
      last-tip=tip
    }
  }
  (uniform:uniform,data:data,upper:upper,tips:tips,teeth:teeth,
    nodes:data.knots.dedup().map(u=>(u,evaluate-point(data,u))))
})
#let nonuniform-knots(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  for plot in knot-comparison-plots {
    group({
      let uniform=plot.uniform
      if uniform {translate((5.7,0))}
      let data=plot.data
      let knots=data.knots
      let upper=plot.upper
      for (point,tip) in plot.teeth {
        line(point,tip,stroke:rgb("#008800")+0.35pt)
      }
      line(..plot.tips,stroke:rgb("#008800")+0.55pt)
      nurbs(upper,stroke:black+0.9pt)
      nurbs(data,stroke:black+0.9pt)
      content((1.3,2.6),text(font:"Arial",size:8pt,fill:rgb("#008800"))[Curvature graph])
      space-panel(-0.4,4.7,-0.5,-1.7,length)
      line((0,-1.13),(4.28,-1.13),stroke:rgb("#ff5555")+1pt)
      for (u,point) in plot.nodes {
        let q=(4.28*u/100,-1.13)
        vector-arrow(q,vector-subtract(interpolate-points(q,point,0.91),q),color:rgb("#cccccc"),thickness:0.45pt)
        for (p,color) in ((point,black),(q,red)) {
          node-marker(p,color:color)
        }
        content(vector-add(q,(0,-0.12)),text(font:"Arial",size:7pt,fill:red,str(u)),anchor:if not uniform and u==93 {"north-east"} else if not uniform and u==100 {"north-west"} else {"north"})
      }
      content((2.14,-1.55),text(font:"Arial",size:6pt,fill:red)[knots = <#knots.slice(1,-1).map(str).join(",")>])
    })
  }
})
#let rational-circle(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  let data=circle-data(r:0.96)
  data.control_points=data.control_points.map(p=>(3.46-p.at(0),2.30-p.at(1)))
  line(..data.control_points,stroke:(paint:black,thickness:0.35pt,dash:"dotted"))
  nurbs(data,stroke:black+1pt)
  content((5.85,2.7),text(font:"Arial",size:9pt,fill:gray)[Curve Degree = 2])
  for (i,p) in data.control_points.slice(0,-1).enumerate() {
    circle(p,radius:diagram-style.sample-point.radius,fill:diagram-style.sample-point.fill,stroke:black+diagram-style.sample-point.thickness)
    let corner=calc.rem(i,2)==1
    let offset=if corner {(if p.at(0) < 3.46 {-0.18} else {0.18},0)} else {
      (if i==0 {0.22} else if i==4 {-0.22} else {0},if i==2 {0.18} else if i==6 {-0.18} else {0})
    }
    let anchor=if corner {if p.at(0) < 3.46 {"east"} else {"west"}} else {
      if i==0 {"west"} else if i==4 {"east"} else {"center"}
    }
    content(vector-add(p,offset),text(font:"Arial",size:8pt,fill:rgb("#008800"),if corner {[w=#math.frac(math.sqrt([2]),[2])]} else {[w=1]}),anchor:anchor)
  }
  space-panel(0,7.78,0.95,-0.33,length)
  line((0.55,0.3),(7.2,0.3),stroke:rgb("#ff5555")+1pt)
  for i in range(5) {
    let p=evaluate-point(data,i);let q=(0.55+6.65*i/4,0.3)
    vector-arrow(q,vector-subtract(interpolate-points(q,p,0.92),q),color:rgb("#cccccc"),thickness:0.45pt)
    for (pos,color) in ((p,black),(q,red)) {node-marker(pos,color:color)}
    content(vector-add(q,(0,0.16)),text(font:"Arial",size:8pt,fill:red,str(i)),anchor:"south")
  }
  content((3.89,0.12),text(font:"Arial",size:8pt,fill:red)[knots = #("<0,0,1,1,2,2,3,3,4,4>")])
  content((3.89,-0.13),text(font:"Arial",size:8pt,fill:red)[knots spacing = [0,1,0,1,0,1,0,1,0]])
})
#let parameter-evaluation(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  let data=clamped-example-data()
  nurbs(data,stroke:rgb("#008800")+1pt)
  line((-0.75,-0.1),(9.7,-0.1),stroke:black+0.4pt)
  line((0,-0.85),(8.87,-0.85),stroke:black+1pt)
  for i in range(8) {
    let q=(8.87*i/7,-0.85);let p=evaluate-point(data,6*i/7)
    vector-arrow(q,vector-subtract(interpolate-points(q,p,0.91),q),color:rgb("#bbbbbb"),thickness:0.4pt)
    rect(vector-add(q,(-0.05,-0.05)),vector-add(q,(0.05,0.05)),fill:white,stroke:black+0.5pt)
    content(vector-add(q,(0,-0.16)),text(font:"Arial",size:8pt,fill:red)[#("a","b","c","d","e","f","g","h").at(i)'],anchor:"north")
  }
  for i in range(7) {
    let p=evaluate-point(data,i)
    rect(vector-add(p,(-0.05,-0.05)),vector-add(p,(0.05,0.05)),fill:white,stroke:black+0.5pt)
    content(vector-add(p,(0,0.17)),text(font:"Arial",size:8pt,fill:red,("a","b","c","d","e","f","g").at(i)),anchor:"south")
  }
  for (u,label,anchor,dx) in ((0,[start],"east",-0.17),(6,[end],"west",0.17)) {
    content(vector-add(evaluate-point(data,u),(dx,0)),text(font:"Arial",size:8pt,weight:"bold",label),anchor:anchor)
    content((if u==0 {-0.17} else {9.04},-0.85),text(font:"Arial",size:8pt,weight:"bold",if u==0 {[t0]} else {[t1]}),anchor:anchor)
  }
})
#let open-polyline(length: diagram-style.unit) = curve-diagram("open-polyline", length: length)
#let open-cubic(length: diagram-style.unit) = curve-diagram("open-cubic", length: length)
#let periodic-curve(length: diagram-style.unit) = curve-diagram("periodic-curve", length: length)
#let periodic-edit(length: diagram-style.unit) = curve-diagram("periodic-edit", length: length)
#let closed-curve(length: diagram-style.unit) = curve-diagram("closed-curve", length: length)
#let closed-edit(length: diagram-style.unit) = curve-diagram("closed-edit", length: length)
#let deboor(length: diagram-style.unit, stage: none) = context {
  let measured=measure(canvas(length:1cm,{deboor-elements(stage:stage)})).width
  canvas(length:1cm*(8*length/measured),{deboor-elements(stage:stage)})
}
#let continuity-combs(length: diagram-style.unit) = curve-diagram("continuity-combs", length: length)
#let curvature-circles(length: diagram-style.unit) = curve-diagram("curvature-circles", length: length)
#let continuity(length: diagram-style.unit) = curve-diagram("continuity", length: length)
#let continuity-vectors(length: diagram-style.unit) = curve-diagram("continuity-vectors", length: length)
#let projection-xy(length: diagram-style.unit) = curve-diagram("projection-xy", length: length)
#let projection-xz(length: diagram-style.unit) = curve-diagram("projection-xz", length: length)
#let projection-yz(length: diagram-style.unit) = curve-diagram("projection-yz", length: length)

// 图 43–48：曲线和数据面板共用同一份数据，避免图形、次数、权重不一致。
#let curve-analysis-data(kind)={
  let periodic=kind in ("cubic-periodic","quadratic-periodic","weighted-periodic")
  let degree=if kind in ("cubic-open","cubic-periodic","weighted-open") {3} else {2}
  let points=if periodic {((36,0,0),(48,0,0),(48,12,0),(36,12,0))} else {((0,0,0),(10,0,0),(10,10,0),(0,10,0))}
  let data=from-control-points(points,degree:degree,periodic:periodic)
  if kind in ("weighted-open","weighted-periodic") {
    let weights=(0.2,0.3,1.5,1)
    data.weights=if periodic {weights+weights.slice(0,degree)} else {weights}
  }
  data
}
#let curve-analysis(kind,length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  let data=curve-analysis-data(kind)
  let periodic=kind in ("cubic-periodic","quadratic-periodic","weighted-periodic")
  let extent=if periodic {12} else {10}
  let origin=if periodic {36} else {0}
  let size=3.2
  for i in range(11) {
    let v=size*i/10
    line((v,0),(v,size),stroke:rgb("#e0e0e0")+0.25pt)
    line((0,v),(size,v),stroke:rgb("#e0e0e0")+0.25pt)
  }
  let drawing=data
  drawing.control_points=data.control_points.map(p=>((p.at(0)-origin)*size/extent,p.at(1)*size/extent))
  let corners=drawing.control_points.slice(0,4)
  line(..(corners+(corners.first(),)),stroke:palette.red+0.45pt)
  nurbs(drawing,stroke:rgb("#008800")+0.9pt)
  for p in corners {point-mark(p,length,size:0.045cm,thickness:1pt)}
  let number(v)=str(calc.round(v,digits:3))
  let card(title,values,width)=block(width:width*length,
    table(columns:(1fr,),inset:data-table-style.inset,stroke:data-table-style.stroke,
      fill:(x,y)=>if y==0 {data-table-style.header-fill} else {data-table-style.body-fill},
      text(font:data-table-style.header-font,size:data-table-style.size,weight:"bold",title),
      ..values.map(v=>text(font:data-table-style.body-font,size:data-table-style.size,v))))
  content((3.6,size/2),card([Control points],data.control_points.map(p=>"("+p.map(number).join(", ")+")"),2.75),anchor:"west",padding:0pt)
  content((6.6,size/2),card([Knots],data.knots.slice(1,-1).map(number),1.9),anchor:"west",padding:0pt)
  content((8.75,size/2),card([Weights],data.weights.map(number),1.35),anchor:"west",padding:0pt)
})
#let cubic-open-analysis(length:diagram-style.unit)=curve-analysis("cubic-open",length:length)
#let cubic-periodic-analysis(length:diagram-style.unit)=curve-analysis("cubic-periodic",length:length)
#let quadratic-open-analysis(length:diagram-style.unit)=curve-analysis("quadratic-open",length:length)
#let quadratic-periodic-analysis(length:diagram-style.unit)=curve-analysis("quadratic-periodic",length:length)
#let weighted-open-analysis(length:diagram-style.unit)=curve-analysis("weighted-open",length:length)
#let weighted-periodic-analysis(length:diagram-style.unit)=curve-analysis("weighted-periodic",length:length)

// 仿射变换插图。

// 本节统一相机：X 右下、Y 右上、Z 向上。
#let project(p) = (0.85 * p.at(0) + 0.65 * p.at(1), -0.3 * p.at(0) + 0.38 * p.at(1) + p.at(2))
#let cube(origin, size) = ((0,0,0), (1,0,0), (1,1,0), (0,1,0), (0,0,1), (1,0,1), (1,1,1), (0,1,1)).map(p => vector-add(origin, p.zip(size).map(((a,b)) => a*b)))
#let solid(points, color, camera: project, opaque: false) = {
  import draw: *
  // 半透明表面配合全部十二条棱，保持原图的线框可读性。
  let faces = if opaque {
    ((0,1,2,3), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7), (4,5,6,7))
  } else {
    ((0,1,5,4), (1,2,6,5), (4,5,6,7))
  }
  for face in faces {
    line(..face.map(i => camera(points.at(i))), close: true, fill: if opaque { color.lighten(78%) } else { color.transparentize(78%) }, stroke: none)
  }
  for (a,b) in ((0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)) {
    line(camera(points.at(a)), camera(points.at(b)), stroke: color + 0.6pt)
  }
}
#let ground(xmax, ymax, camera: project) = {
  import draw: *
  for x in range(-1, xmax) {
    if x != 0 { line(camera((x,-1,0)), camera((x,ymax,0)), stroke: palette.grid + 0.4pt) }
  }
  for y in range(-1, ymax) {
    if y != 0 { line(camera((-1,y,0)), camera((xmax,y,0)), stroke: palette.grid + 0.4pt) }
  }
  line(camera((-1,0,0)), camera((0,0,0)), stroke: rgb("#666666") + 0.4pt)
  line(camera((0,-1,0)), camera((0,0,0)), stroke: rgb("#666666") + 0.4pt)
  line(camera((0,0,0)), camera((xmax,0,0)), stroke: palette.red + 0.4pt)
  line(camera((0,0,0)), camera((0,ymax,0)), stroke: palette.green + 0.4pt)
}
#let arrow3(a, b, color: palette.green, camera: project) = {
  let p = camera(a)
  let q = camera(b)
  vector-arrow(p, (q.at(0)-p.at(0), q.at(1)-p.at(1)), color: color)
}

#let translation-vector(length: diagram-style.unit) = canvas(length: length, {
  import draw: *
  let displacement = (5,1,0)
  let p = (1.4,0,0)
  let q = vector-add(p, displacement)
  solid(cube((0,0,0), (1.4,1.4,2.7)), palette.red)
  solid(cube(displacement, (1.4,1.4,2.7)), palette.green)
  arrow3(p,q)
  point-mark(project(p), length, color: palette.green)
  point-mark(project(q), length)
  content(vector-add(project(p),(0,-0.25)), $P(x,y,z)$, anchor: "north")
  content(vector-add(project(q),(0,-0.25)), $P'$, anchor: "north")
  let label-pos = vector-add(project(vector-scale(vector-add(p,q),0.5)), (0,0.2))
  content(label-pos, $bold(arrow(v)) chevron.l a,b,c chevron.r$, anchor: "south")
})
#let translation-cube(length: diagram-style.unit) = canvas(length: length, {
  import draw: *
  let cam(p) = vector-scale(project(p), 0.62)
  ground(7,8,camera: cam)
  let points = cube((0,0,0),(2,2,2))
  solid(points, palette.red, camera: cam)
  solid(points.map(p => vector-add(p,(4,5,3))), palette.green, camera: cam)
  for (a,b,label,color,shift) in (
    ((0,0,0),(4,0,0),$4$,palette.red,(0,-0.25)),
    ((4,0,0),(4,5,0),$5$,palette.green,(0,-0.25)),
    ((4,5,0),(4,5,3),$3$,rgb("#2455cc"),(0.2,0)),
  ) {
    arrow3(a,b,color: color,camera: cam)
    content(vector-add(cam(vector-scale(vector-add(a,b),0.5)),shift), text(fill: color,label))
  }
})
#let rotation-point(length: diagram-style.unit) = canvas(length: length, {
  import draw: *
  let o = (0,0)
  let p = (4.5*calc.cos(16deg),4.5*calc.sin(16deg))
  let q = (4.5*calc.cos(56deg),4.5*calc.sin(56deg))
  vector-arrow(o,(5.4,0),color: palette.red)
  vector-arrow(o,(0,4.9),color: palette.green)
  line((-0.8,-0.8),o,stroke: rgb("#666666") + 0.4pt)
  line(o,p,stroke: palette.text + 1pt)
  line(o,q,stroke: palette.text + 1pt)
  for (r,start,end,label) in ((1.5,0deg,16deg,$a$),(1.25,16deg,56deg,$b$)) {
    line(..range(25).map(i => { let t=start+(end - start)*i/24; (r*calc.cos(t),r*calc.sin(t)) }),stroke: palette.text + 0.5pt)
    let t=(start+end)/2
    content(((r+0.3)*calc.cos(t),(r+0.3)*calc.sin(t)),label)
  }
  for v in (p,q) { circle(v,radius: 0.07,fill: white,stroke: palette.text + 0.8pt) }
  content(vector-add(p,(0.2,0)), $P(x,y)$,anchor: "west")
  content(vector-add(q,(0.2,0)), $P'(x',y')$,anchor: "west")
  content((1.15,2.55),$d$,anchor: "east")
  content((5.5,0),$x$,anchor: "west")
  content((0,5),$y$,anchor: "south")
})
#let rotate-z(p, angle) = (p.at(0)*calc.cos(angle)-p.at(1)*calc.sin(angle), p.at(0)*calc.sin(angle)+p.at(1)*calc.cos(angle),p.at(2))
#let rotation-cube(length: diagram-style.unit) = canvas(length: length, {
  import draw: *
  let cam(p) = (0.9*p.at(0)-0.65*p.at(1),0.35*p.at(0)+0.5*p.at(1)+p.at(2))
  ground(7,5,camera: cam)
  let points = cube((5,0,0),(1.5,1.5,1.5))
  solid(points,palette.red,camera: cam,opaque: true)
  solid(points.map(p=>rotate-z(p,30deg)),palette.green,camera: cam,opaque: true)
  arrow3((0,0,0),(5,0,0),color: palette.red,camera: cam)
  arrow3((0,0,0),rotate-z((5,0,0),30deg),camera: cam)
  line(..range(25).map(i=>cam((2*calc.cos(i*30deg/24),2*calc.sin(i*30deg/24),0))),stroke: palette.text + 0.5pt)
  content(cam((2.65*calc.cos(15deg),2.65*calc.sin(15deg),0)),$30 degree$,anchor: "south")
})
#let scaling-cube(length: diagram-style.unit) = canvas(length: length, {
  ground(6,5)
  let points = cube((2,2,0),(2,2,2))
  solid(points,palette.red)
  solid(points.map(p=>vector-scale(p,0.25)),palette.green)
  point-mark(project((0,0,0)),length,color: palette.green)
})
#let scaling-matrix() = matrix-cells(($0.25$,$0$,$0$,$0$,$0$,$0.25$,$0$,$0$,$0$,$0$,$0.25$,$0$,$0$,$0$,$0$,$1$))

#let shear-cube(target, source, length: diagram-style.unit) = canvas(length: length, {
  let cam(p) = vector-scale((0.9*p.at(0)+0.7*p.at(1),-0.25*p.at(0)+0.6*p.at(1)+p.at(2)),2)
  let points = cube((0,0,0),(1,1,2))
  ground(2,2,camera: cam)
  solid(points,rgb("#666666"),camera: cam)
  let transformed = points.map(p=>{
    let q=p
    q.at(target) += 0.5*p.at(source)
    q
  })
  solid(transformed,palette.red,camera: cam)
})
#let shear-xy(length: diagram-style.unit) = shear-cube(0,1,length: length)
#let shear-zy(length: diagram-style.unit) = shear-cube(2,1,length: length)
#let shear-yx(length: diagram-style.unit) = shear-cube(1,0,length: length)
#let shear-zx(length: diagram-style.unit) = shear-cube(2,0,length: length)
#let shear-xz(length: diagram-style.unit) = shear-cube(0,2,length: length)
#let shear-yz(length: diagram-style.unit) = shear-cube(1,2,length: length)

#let reflection-cube(length: diagram-style.unit) = canvas(length: length, {
  import draw: *
  // 原图接近正视：压低俯视角，X 近水平，Y 向左后方展开。
  let cam(p) = (0.95*p.at(0)-0.35*p.at(1),0.06*p.at(0)+0.12*p.at(1)+p.at(2))
  let points=cube((1,1,1.2),(1.5,1.5,1.5))
  let reflected=points.map(p=>(p.at(0),p.at(1),-p.at(2)))
  let guide-stroke = (paint: rgb("#666666"),thickness: 0.5pt,dash: "dashed")
  // 将连接线在 z=0 处分段：下半段在平面后，上半段在平面前。
  for p in points.slice(0,4) {
    line(cam((p.at(0),p.at(1),-p.at(2))),cam((p.at(0),p.at(1),0)),stroke: guide-stroke)
  }
  // 只画相机可见的三个面，不透出背面的棱线。
  let visible-cube(vertices, color, top) = {
    for face in ((0,3,7,4), (0,1,5,4), top) {
      line(..face.map(i=>cam(vertices.at(i))),close: true,fill: color,stroke: rgb("#444444") + 0.6pt)
    }
  }
  visible-cube(reflected,rgb("#739b80"),(0,1,2,3))
  line(..((-1,-1,0),(4,-1,0),(4,4,0),(-1,4,0)).map(cam),close: true,fill: rgb("#eeeeee"),stroke: palette.grid + 0.4pt)
  for p in points.slice(0,4) {
    line(cam((p.at(0),p.at(1),0)),cam(p),stroke: guide-stroke)
  }
  visible-cube(points,rgb("#bbbbbb"),(4,5,6,7))
})
#let reflection-matrix() = matrix-cells(($1$,$0$,$0$,$0$,$0$,$1$,$0$,$0$,$0$,$0$,$-1$,$0$,$0$,$0$,$0$,$1$))


// 参数曲线与分段多项式插图。
#let spline(points,color:black,thickness:1.2pt)=nurbs(curve-spec(points),stroke:color+thickness)
#let curve(fn,color: black,thickness: 1.2pt)={
  import draw: *
  line(..range(121).map(i=>fn(i/120)),stroke: color+thickness)
}
#let square(p,length,color: black)={
  import draw: *
  let r=0.055cm/length
  rect(vector-add(p,(-r,-r)),vector-add(p,(r,r)),fill:white,stroke:color+0.7pt)
}
#let dot(p,length)={
  import draw: *
  circle(p,radius:0.07cm/length,fill:white,stroke:black+0.7pt)
}
#let guide(a,b)={
  import draw: *
  line(a,b,stroke:(paint:black,thickness:0.5pt,dash:"dotted"))
}
#let wave(u)=curve-at(wave-data,u)
#let parameter-wave(t)=wave(t)

#let journey(length:diagram-style.unit)={
  set text(font: "Arial", weight: "bold", size: 8pt)
  canvas(length:length * 1.25,{
  import draw: *
  let first=((0.6,0.6),(-0.7,4.4),(1.2,5.4),(3.4,4.1))
  let second=((3.4,4.1),(6.2,2.1),(5.6,-0.4),(3.2,0.8))
  spline(first); spline(second)
  for p in (first.first(),first.last(),second.last()) { dot(p,length) }
  content((0.7,1.15),text(fill:palette.green)[$t_0$ =\ start time],anchor:"south-west")
  content((0.6,0.3),[start\ location],anchor:"north")
  content((3.2,0.45),[end\ location],anchor:"north")
  content((3.2,1.1),text(fill:palette.green)[$t_1$ =\ end time],anchor:"south-west")
  content((3.55,4.25),text(fill:palette.green)[$t$],anchor:"south")
  content((2.5,3.4),[location at\ time = $t$],anchor:"north")
})
}
#let parametric-line(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  let a=(0,2.5); let b=(7,0); let p=interpolate-points(a,b,0.25)
  line(a,b,stroke:black+1.2pt)
  dot(a,length); dot(b,length); point-mark(p,length,color:palette.green)
  content(vector-add(a,(0,0.25)),$P'$,anchor:"south")
  content(vector-add(a,(0,-0.2)),text(fill:palette.green)[$t_0$],anchor:"north")
  content(vector-add(b,(0,-0.2)),text(fill:palette.green)[$t_1$],anchor:"north")
  content(vector-add(p,(0,0.25)),$P$,anchor:"south")
  content(vector-add(p,(0,-0.25)),text(fill:palette.green)[$t$],anchor:"north")
  vector-arrow((3.5,2.8),(1.5,-0.536),color:rgb("#777777"))
  content((4.25,3),$bold(arrow(v)) chevron.l a,b,c chevron.r$,anchor:"south")
})
#let parametric-circle(length:diagram-style.unit)={
  set text(size: 10pt)
  canvas(length:length,{
  import draw: *
  let r=2.5; let angle=52deg; let p=(r*calc.cos(angle),r*calc.sin(angle))
  nurbs(circle-data(r:r),stroke:black+1pt)
  vector-arrow((-2.9,0),(6,0),color:palette.red,thickness:0.4pt)
  vector-arrow((0,-2.9),(0,6),color:palette.green,thickness:0.4pt)
  line((0,0),p,stroke:rgb("#777777")+0.6pt)
  line(p,(p.at(0),0),stroke:rgb("#777777")+0.6pt)
  curve(t=>(0.65*calc.cos(t*angle),0.65*calc.sin(t*angle)),thickness:0.5pt)
  dot(p,length)
  content(vector-add(p,(0.15,0.15)),$P$,anchor:"south-west")
  content((0.82,1.2),$r$,anchor:"east")
  content((0.72,0.35),text(fill:palette.green)[$t$],anchor:"west")
  content((0.2,-0.08),$r cos(t)$,anchor:"north-west")
  content((p.at(0)+0.08,p.at(1)/2),box(fill:white,inset:1pt)[$r sin(t)$],anchor:"west")
  content((3.2,0),$x$,anchor:"west"); content((0,3.2),$y$,anchor:"south")
})
}
#let line-domain(length:diagram-style.unit)={
  canvas(length:length,{
    import draw: *
    // 按原图的上下层次布局；参数刻度与上方对应点使用相同的横坐标。
    let a=(0.4,1.25)
    let b=(4.05,2.2)
    let at(t)=interpolate-points(a,b,t)
    let extended=at(1.28)
    line(a,b,stroke:black+1.2pt)
    dot(a,length); dot(b,length)
    line(vector-add(b,(0.3,0.078)),extended,stroke:palette.gray+0.4pt)
    content(vector-add(a,(-0.04,-0.08)), $A$,anchor:"north-east")
    content(vector-add(b,(0.07,0.02)), $B$,anchor:"west")
    for (p,label,above) in ((at(0.3),$R$,true),(extended,$R'$,false)) {
      line(vector-add(p,(0,-0.08)),vector-add(p,(0,0.08)),stroke:palette.green+0.9pt)
      content(vector-add(p,(0,if above {0.13} else {-0.16})),text(fill:palette.green,label),anchor:if above {"south"} else {"north"})
    }
    line((-0.6,0.94),(8.2,0.94),stroke:palette.gray+0.4pt)
    // 横向大括号标示完整参数区间。
    let brace-stroke=rgb("#777777")+0.5pt
    bezier((0.4,0.22),(0.65,0.36),(0.4,0.36),(0.5,0.36),stroke:brace-stroke)
    bezier((0.65,0.36),(2.225,0.53),(1.8,0.36),(2.225,0.3),stroke:brace-stroke)
    bezier((2.225,0.53),(3.8,0.36),(2.225,0.3),(2.65,0.36),stroke:brace-stroke)
    bezier((3.8,0.36),(4.05,0.22),(3.95,0.36),(4.05,0.36),stroke:brace-stroke)
    content((2.225,0.62),[curve domain = 0 to 1],anchor:"south")
    line((0.4,0),(4.05,0),stroke:palette.red+1.4pt)
    line((4.13,0),(extended.at(0),0),stroke:palette.gray+0.4pt)
    for (x,label,green) in ((0.4,$t_0=0$,false),(at(0.3).at(0),$t=0.3$,true),(4.05,$t_1=1$,false),(extended.at(0),$t'=1.2$,true)) {
      if green {line((x,-0.065),(x,0.065),stroke:palette.green+0.9pt)}
      content((x,-0.2),text(fill:palette.red,label),anchor:"north")
    }
    content((5.8,1.4),[curve in 3D\ modeling space],anchor:"west")
    content((5.8,0),[parameter interval],anchor:"west")
  })
}
#let curve-domain-diagram(length:diagram-style.unit,mode:0)=canvas(length:length,{
  import draw: *
  // 区间示意图单独压缩曲线高度，标注和参数轴保持原尺寸。
  let data=wave-data
  data.control_points=data.control_points.map(p=>(p.at(0),p.at(1)*0.65))
  nurbs(data,stroke:black+1.2pt)
  let a=curve-at(data,0); let b=curve-at(data,1); let r=curve-at(data,0.5)
  let left=if mode==1 {-1.5} else {0.7}
  let right=if mode==1 {8.5} else {6.3}
  line((if mode==0 {-1.9} else {-0.3},0),(if mode==0 {9} else {7.4},0),stroke:palette.gray+0.4pt)
  line((left,-0.5),(right,-0.5),stroke:palette.red+1.4pt)
  if mode==0 {
    let connector-stroke=(paint:rgb("#777777"),thickness:0.5pt)
    line(a,(left,-0.5),stroke:connector-stroke)
    line(b,(right,-0.5),stroke:connector-stroke)
  } else {
    guide(a,(left,-0.5)); guide(b,(right,-0.5))
  }
  if mode==0 {
    dot(a,length); dot(b,length)
    content(vector-add(a,(-0.15,0)),[start point],anchor:"east")
    content(vector-add(b,(0.15,0)),[end point],anchor:"west")
    content((left,-0.75),text(fill:palette.red)[$t_0$],anchor:"north")
    content((right,-0.75),text(fill:palette.red)[$t_1$],anchor:"north")
    content((-0.4,0.5),[(1)],anchor:"east"); content((-0.4,-0.5),text(fill:palette.red)[(2)],anchor:"east")
  } else {
    guide(r,((left+right)/2,-0.5))
    content(vector-add(a,(-0.15,0)),$A$,anchor:"east")
    content(vector-add(b,(0.15,0)),$B$,anchor:"west")
    content(vector-add(r,(0.15,0.15)),$R$,anchor:"south-west")
    let labels=if mode==1 {($t_0=2.5$,$t=17.5$,$t_1=32.5$)} else {($t_0=0.0$,$t=0.5$,$t_1=1.0$)}
    for (x,label) in ((left,labels.at(0)),((left+right)/2,labels.at(1)),(right,labels.at(2))) {
      content((x,-0.75),label,anchor:"north")
    }
  }
})
#let curve-domain(length:diagram-style.unit)=curve-domain-diagram(length:length)
#let arbitrary-domain(length:diagram-style.unit)=curve-domain-diagram(length:length,mode:1)
#let normalized-domain(length:diagram-style.unit)=curve-domain-diagram(length:length,mode:2)

#let evaluation-diagram(length:diagram-style.unit,nonuniform:false)=canvas(length:length,{
  import draw: *
  let data=if nonuniform {curve-spec(((0,3),(0.2,0),(1,4),(7,1)))} else {curve-spec(((0,3),(7,1)),degree:1)}
  let fn(t)=curve-at(data,t)
  nurbs(data,stroke:black+1.2pt)
  line((-0.1,0.45),(7.2,0.45),stroke:palette.gray+0.4pt)
  line((0.8,0),(6.2,0),stroke:palette.red+1.4pt)
  for i in range(6) {
    let p=fn(i/5); let q=(0.8+5.4*i/5,0)
    guide(p,q); square(p,length); square(q,length)
    content(vector-add(q,(0,-0.22)),$t=#(i*2)$,anchor:"north")
  }
  content(vector-add(fn(0),(-0.2,0)),$A$,anchor:"east")
  content(vector-add(fn(1),(0.2,0)),$B$,anchor:"west")
})
#let uniform-evaluation(length:diagram-style.unit)=evaluation-diagram(length:length)
#let nonuniform-evaluation(length:diagram-style.unit)=evaluation-diagram(length:length,nonuniform:true)
#let curve-tangents(length:diagram-style.unit)=canvas(length:length,{
  nurbs(wave-data,stroke:black+1.2pt)
  for (t,color) in ((0.27,palette.green),(0.73,palette.red)) {
    let p=wave(t)
    let (a,b)=parameter-domain(wave-data)
    let delta=evaluate-derivatives(wave-data,a+(b - a)*t).first
    let norm=calc.sqrt(delta.at(0)*delta.at(0)+delta.at(1)*delta.at(1))
    vector-arrow(p,vector-scale(delta,1.6/norm),color:color)
    point-mark(p,length,color:color)
  }
})

#let cubic-comparison(length:diagram-style.unit)=canvas(length:length * 0.7,{
  import draw: *
  let points=((0,0),(0.4,3),(3.6,2.7),(4,0))
  for offset in (0,6) {
    let pts=points.map(p=>vector-add(p,(offset,0)))
    spline(pts)
    if offset==0 {
      for (i,p) in pts.enumerate() {square(p,length); content(vector-add(p,(0,-0.2)),$P_#i$,anchor:"north")}
    } else {
      let start=pts.first(); let end=pts.last()
      vector-arrow(start,vector-add(pts.at(1),vector-scale(start,-1)),color:palette.red)
      vector-arrow(pts.at(2),vector-add(end,vector-scale(pts.at(2),-1)),color:palette.red)
      square(start,length); square(end,length)
      content(vector-add(start,(0,-0.2)),$P_0$,anchor:"north");content(vector-add(end,(0,-0.2)),$P_3$,anchor:"north")
      content(vector-add(interpolate-points(start,pts.at(1),0.6),(-0.15,0)),text(fill:palette.red)[$R_0$],anchor:"east")
      content(vector-add(interpolate-points(end,pts.at(2),0.6),(0.15,0)),text(fill:palette.red)[$R_1$],anchor:"west")
    }
  }
})
#let joined-cubics(length:diagram-style.unit,smooth:false)=canvas(length:length * 0.5,{
  import draw: *
  let first=((0,1.5),(0.9,-0.6),(3,-0.4),(3,1.25))
  let second=if smooth {((3,1.25),(3,2.9),(5.1,3.35),(6,1.25))} else {((3,1.25),(3.6,3.1),(5.3,3.1),(6,1.25))}
  // 左侧分开显示定义，右侧显示连接结果。
  let separated=second.map(p=>vector-add(p,(0.75,0)))
  spline(first);spline(separated,color:palette.red)
  if smooth {
    for (pts,color) in ((first,black),(separated,palette.red)) {
      square(pts.first(),length,color:color);square(pts.last(),length,color:color)
      vector-arrow(pts.first(),vector-add(pts.at(1),vector-scale(pts.first(),-1)),color:palette.gray)
      vector-arrow(pts.at(2),vector-add(pts.last(),vector-scale(pts.at(2),-1)),color:palette.gray)
      content(vector-add(pts.first(),(-0.1,0.25)),text(size:8pt,fill:color)[$P_0$],anchor:"south")
      content(vector-add(pts.last(),(0.1,0.25)),text(size:8pt,fill:color)[$P_1$],anchor:"south")
      content(vector-add(interpolate-points(pts.first(),pts.at(1),0.65),(-0.25,0)),text(size:8pt,fill:palette.gray)[$R_0$],anchor:"east")
      content(vector-add(interpolate-points(pts.last(),pts.at(2),0.65),(0.25,0)),text(size:8pt,fill:palette.gray)[$R_1$],anchor:"west")
    }
  } else {
    for (pts,color) in ((first,black),(separated,palette.red)) {
      for (i,p) in pts.enumerate() {square(p,length,color:color);content(vector-add(p,(0,if i==1 {-0.25} else {0.25})),text(size:8pt,fill:color)[$P_#i$],anchor:if i==1 {"north"} else {"south"})}
    }
  }
  circle(interpolate-points(first.last(),separated.first(),0.5),radius:0.85,stroke:palette.gray+0.4pt)
  let off=(9,0)
  spline(first.map(p=>vector-add(p,off)));spline(second.map(p=>vector-add(p,off)),color:palette.red)
  circle(vector-add(second.first(),off),radius:0.45,stroke:palette.gray+0.4pt)
})
#let joined-bezier(length:diagram-style.unit)=joined-cubics(length:length)
#let joined-hermite(length:diagram-style.unit)=joined-cubics(length:length,smooth:true)

// 两段三次 B 样条（权重均为 1 的 NURBS），共享三个控制点。
#let shared-control-spans(length:diagram-style.unit)=canvas(length:length * 0.45,{
  import draw: *
  let cp=((0,1.5),(1.5,-0.5),(3,3),(4.5,3),(6,1.5))
  let knots=(0,0,0,0,0.5,1,1,1,1)
  let data=curve-spec(cp,knots:knots)
  let spans=native-cubics(data)
  for (offset,separated) in ((0,true),(10,false)) {
    let shift=(offset,0)
    let redshift=vector-add(shift,if separated {(1.8,0)} else {(0,0)})
    let left=cp.slice(0,4).map(p=>vector-add(p,shift))
    let right=cp.slice(1,5).map(p=>vector-add(p,redshift))
    line(..left,stroke:palette.gray+0.4pt);line(..right,stroke:palette.gray+0.4pt)
    spline(spans.at(0).map(p=>vector-add(p,shift)))
    spline(spans.at(1).map(p=>vector-add(p,redshift)),color:palette.red)
    if separated {
      // 圈出两段共用的三组控制点：上方两组、下方一组。
      for (center,rx,ry) in (((4.65,3.45),2.2,0.85),((2.4,-0.1),1.45,0.75)) {
        curve(t=>vector-add(center,(rx*calc.cos(t*360deg),ry*calc.sin(t*360deg))),color:palette.gray,thickness:0.4pt)
      }
      for (pts,color) in ((left,black),(right,palette.red)) {
        for (i,p) in pts.enumerate() {square(p,length,color:color);content(vector-add(p,(0,0.2)),text(size:8pt,fill:color)[$"CP"#i$],anchor:if color==black and i==3 {"south-east"} else if color==palette.red and i==1 {"south-west"} else {"south"})}
      }
    } else {for p in cp {square(vector-add(p,shift),length)}}
  }
})
#let casteljau(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  let cp=((0,0),(1.4,4),(5.1,3.7),(5.4,0))
  let t=0.5
  let first=range(3).map(i=>interpolate-points(cp.at(i),cp.at(i+1),t))
  let second=range(2).map(i=>interpolate-points(first.at(i),first.at(i+1),t))
  let r=interpolate-points(second.first(),second.last(),t)
  line(..cp,stroke:(paint:black,thickness:0.7pt,dash:"dotted"))
  line(..first,stroke:(paint:black,thickness:0.7pt,dash:"dotted"))
  line(..second,stroke:palette.red+0.7pt)
  spline(cp,thickness:1.4pt)
  for (points,labels,color) in ((cp,($A$,$B$,$C$,$D$),black),(first,($M$,$N$,$O$),palette.red),(second,($P$,$Q$),palette.red),((r,),($R$,),palette.green)) {
    for (p,label) in points.zip(labels) {
      point-mark(p,length,size:0.055cm,thickness:0.9pt,color:color)
    }
  }
  // 标注向控制多边形外侧避让，不压在控制线或曲线上。
  for (p,label,offset,anchor) in (
    (cp.at(0),$A$,(-0.18,-0.12),"north-east"),
    (cp.at(1),$B$,(-0.12,0.18),"south-east"),
    (cp.at(2),$C$,(0.12,0.18),"south-west"),
    (cp.at(3),$D$,(0.18,-0.12),"north-west"),
    (first.at(0),$M$,(-0.2,0),"east"),
    (first.at(1),$N$,(0,0.2),"south"),
    (first.at(2),$O$,(0.2,0),"west"),
    (second.at(0),$P$,(-0.15,0.2),"south-east"),
    (second.at(1),$Q$,(0.15,0.2),"south-west"),
    (r,$R$,(0,-0.25),"north"),
  ) {
    content(vector-add(p,offset),text(size:8pt,label),anchor:anchor)
  }
})

// 图 51：斜视平面及其二维参数区间，按原图布局重绘。
#let plane-parameters(length:diagram-style.unit)=canvas(length:length,padding:0.1cm,{
  import draw: *
  let pos(x,y)=(x/60,(190 - y)/60)
  let origin=pos(9,125)
  let a=(162/60,-45/60)
  let b=(130/60,106/60)
  let plane(u,v)=vector-add(origin,vector-add(vector-scale(a,u),vector-scale(b,v)))
  line(plane(0,0),plane(1,0),plane(1,1),plane(0,1),close:true,
    fill:rgb("#aaaaaa"),stroke:none)
  for i in range(6) {
    let t=i/5
    line(plane(t,0),plane(t,1),stroke:rgb("#cccccc")+0.35pt)
    line(plane(0,t),plane(1,t),stroke:rgb("#cccccc")+0.35pt)
  }
  rect(pos(347,153),pos(528,40),fill:rgb("#e6e6e6"),stroke:none)
  for x in (347,528) {line(pos(x,169),pos(x,26),stroke:black+0.45pt)}
  for y in (40,153) {line(pos(332,y),pos(543,y),stroke:black+0.45pt)}
  let p=pos(236,94)
  let q=pos(358,122)
  line(p,q,stroke:(paint:black,thickness:0.5pt,dash:"dashed"))
  for point in (pos(125,97),p,q) {
    rect(vector-add(point,(-0.065,-0.065)),vector-add(point,(0.065,0.065)),
      fill:white,stroke:black+0.9pt)
  }
  content(pos(132,97),text(size:9pt)[$P'$],anchor:"west",padding:1pt)
  content(pos(224,94),text(size:9pt)[$P$],anchor:"east",padding:1pt)
  vector-arrow(pos(133,128),(29/60,-8/60),color:palette.red3d,thickness:0.85pt)
  vector-arrow(pos(120,66),(23/60,19/60),color:palette.green3d,thickness:0.85pt)
  content(pos(130,144),text(size:9pt,fill:palette.red3d)[$bold(a)$])
  content(pos(112,53),text(size:9pt,fill:palette.green3d)[$bold(b)$])
  vector-arrow(pos(347,181),(181/60,0),color:palette.red3d,thickness:0.65pt)
  vector-arrow(pos(553,153),(0,110/60),color:palette.green3d,thickness:0.65pt)
  content(pos(437,192),text(size:8pt,fill:palette.red3d)[$u$ 区间],anchor:"north")
  content(pos(568,98),std.rotate(-90deg,text(size:8pt,fill:palette.green3d)[$v$ 区间]))
})

// 图 52：同一空间点、其 XY 投影以及两个球面坐标角。
#let spherical-coordinates(length:diagram-style.unit)=canvas(length:length,padding:0.12cm,{
  import draw: *
  let cam(p)=(-2.2*p.at(0)+1.8*p.at(1)-0.25*p.at(2),
    -p.at(0)-0.8*p.at(1)+2.6*p.at(2))
  let o=cam((0,0,0))
  for i in range(6) {
    let t=i/5
    for (a,b,c) in (((t,0,0),(t,1,0),palette.grid),((0,t,0),(1,t,0),palette.grid),
      ((t,0,0),(t,0,1),rgb("#e5aaaa")),((0,0,t),(1,0,t),rgb("#e5aaaa")),
      ((0,t,0),(0,t,1),rgb("#a5d4a5")),((0,0,t),(0,1,t),rgb("#a5d4a5"))) {
      line(cam(a),cam(b),stroke:c+0.35pt)
    }
  }
  for (end,col,body,anchor) in (((1.15,0,0),palette.red3d,[$x$],"north-east"),
    ((0,1.15,0),palette.green3d,[$y$],"north-west"),((0,0,1.13),black,[$z$],"south")) {
    vector-arrow(o,cam(end),color:col,thickness:0.65pt)
    content(cam(end),text(size:9pt,fill:col,body),anchor:anchor,padding:2pt)
  }
  let azimuth=35deg
  let polar=48deg
  let r=1.55
  let p=(r*calc.sin(polar)*calc.cos(azimuth),r*calc.sin(polar)*calc.sin(azimuth),r*calc.cos(polar))
  let q=(p.at(0),p.at(1),0)
  let dashed=(paint:black,thickness:0.5pt,dash:"dashed")
  line(o,cam(p),stroke:dashed)
  line(cam(p),cam(q),o,stroke:dashed)
  rect(vector-add(cam(p),(-0.035,-0.035)),vector-add(cam(p),(0.035,0.035)),fill:black,stroke:none)
  content(vector-add(cam(p),(-0.2,0.18)),box(fill:white,inset:1pt,text(size:9pt)[$P(r,theta,phi)$]),anchor:"east")
  content(vector-add(cam(vector-scale(p,0.6)),(-0.18,0.02)),box(fill:white,inset:1pt,text(size:9pt)[$r$]))
  line(..range(33).map(i=>cam((0.3*calc.cos(azimuth*i/32),0.3*calc.sin(azimuth*i/32),0))),stroke:black+0.65pt)
  line(..range(33).map(i=>{
    let t=polar*i/32
    cam((0.34*calc.sin(t)*calc.cos(azimuth),0.34*calc.sin(t)*calc.sin(azimuth),0.34*calc.cos(t)))
  }),stroke:black+0.65pt)
  content(cam((0.45*calc.cos(azimuth/2),0.45*calc.sin(azimuth/2),0)),box(fill:white,inset:1pt,text(size:9pt)[$theta$]),anchor:"center")
  content(vector-add(cam((0.46*calc.sin(polar/2)*calc.cos(azimuth),0.46*calc.sin(polar/2)*calc.sin(azimuth),0.46*calc.cos(polar/2))),(-0.09,0.01)),box(fill:white,inset:1pt,text(size:9pt)[$phi$]))
})
// 图 53：按前后半球分组缓存经纬线，一条连续网格线只提交一次绘图。
#let sphere-camera(p)={
  let x=-0.8*p.at(0)+0.6*p.at(1)
  let y=-0.36*p.at(0)-0.48*p.at(1)+0.8*p.at(2)
  (1.55*(x*calc.cos(5deg)-y*calc.sin(5deg)),1.55*(x*calc.sin(5deg)+y*calc.cos(5deg)))
}
#let sphere-point(u,v)=(calc.sin(v)*calc.cos(u),calc.sin(v)*calc.sin(u),calc.cos(v))
#let sphere-grid={
  let paths=()
  let curves=(range(0,180,step:30).map(u=>range(121).map(i=>sphere-point(u*1deg,i*3deg)))+
    range(30,180,step:30).map(v=>range(121).map(i=>sphere-point(i*3deg,v*1deg))))
  for pts in curves {
    let run=();let front=none
    for i in range(pts.len()-1) {
      let p=pts.at(i);let q=pts.at(i+1)
      let visible=0.48*(p.at(0)+q.at(0))+0.64*(p.at(1)+q.at(1))+0.6*(p.at(2)+q.at(2))>=0
      if visible!=front {
        if run.len()>1 {paths.push((front:front,points:run))}
        run=(sphere-camera(p),);front=visible
      }
      run.push(sphere-camera(q))
    }
    if run.len()>1 {paths.push((front:front,points:run))}
  }
  paths
}
#let sphere-parameters(length:diagram-style.unit)=canvas(length:length,padding:0.12cm,{
  import draw: *
  let radius=1.55
  let cam=sphere-camera
  let axes=(((1,0,0),1.6,palette.red3d,[$x$],"north-east"),
    ((0,1,0),1.6,palette.green3d,[$y$],"north-west"),((0,0,1),1.65,black,[$z$],"south-west"))
  circle((0,0),radius:radius,fill:rgb("#ededed"),stroke:none)
  for path in sphere-grid.filter(p=>not p.front) {line(..path.points,stroke:rgb("#bcbcbc")+0.4pt)}
  // 球内轴从球心 O 到真实球面交点，经过前半透明球面自然衰减。
  for (axis,extent,col,body,anchor) in axes {line((0,0),cam(axis),stroke:col+0.65pt)}
  circle((0,0),radius:radius,fill:rgb("#b4b4b4").transparentize(42%),stroke:rgb("#999999")+0.4pt)
  for path in sphere-grid.filter(p=>p.front) {line(..path.points,stroke:white+0.4pt)}
  // 三个正轴朝向观察者，出球面后的部分位于球面前方，保持实线。
  for (axis,extent,col,body,anchor) in axes {
    let surface=cam(axis);let tip=cam(vector-scale(axis,extent))
    vector-arrow(surface,vector-subtract(tip,surface),color:col,thickness:0.65pt)
    content(tip,text(size:9pt,fill:col,body),anchor:anchor,padding:2pt)
  }
  let p=cam(sphere-point(80deg,60deg));let q=(2.92,-0.48)
  rect((2.45,-0.94),(6.55,0.64),fill:rgb("#e6e6e6"),stroke:none)
  for x in (2.45,6.55) {line((x,-1.12),(x,0.85),stroke:black+0.45pt)}
  for y in (-0.94,0.64) {line((2.27,y),(6.75,y),stroke:black+0.45pt)}
  line(p,q,stroke:(paint:black,thickness:0.5pt,dash:"dashed"))
  for point in (p,q) {rect(vector-add(point,(-0.055,-0.055)),vector-add(point,(0.055,0.055)),fill:white,stroke:black+0.9pt)}
  content(vector-add(p,(0,0.1)),text(size:9pt)[$P$],anchor:"south")
  vector-arrow((2.45,-1.33),(4.1,0),color:palette.red3d,thickness:0.65pt)
  vector-arrow((6.9,-0.94),(0,1.58),color:palette.green3d,thickness:0.65pt)
  content((4.5,-1.43),text(size:8pt,fill:palette.red3d)[$u$ 区间：$0$ 到 $2pi$],anchor:"north")
  content((7.15,-0.15),std.rotate(-90deg,text(size:8pt,fill:palette.green3d)[$v$ 区间：$0$ 到 $pi$]))
})

// 实例教程的接合示意独立于图 49 的曲率梳示意。
#let continuity-examples(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  for level in range(3) {
    let x=level*3.3
    let black-points=if level==0 {((0,0),(1.4,0.25),(1.75,1.3),(1.35,2.05))}
      else if level==1 {((0.65,0.2),(1.28,0.55),(0.6,2.05),(1.35,2.05))}
      else {((0.65,0.2),(1.4,0.52),(0.6,2.05),(1.35,2.05))}
    let red-points=if level==2 {((1.35,2.05),(2.1,2.05),(3.2,0.52),(2.9,0))}
      else {((1.35,2.05),(2.45,2.05),(3.2,0.9),(2.9,0))}
    // 教学示意：曲线均由 NURBS 库绘制。
    nurbs(shifted-curve(curve-spec(black-points),(x,0)),stroke:black+1pt)
    nurbs(shifted-curve(curve-spec(red-points),(x,0)),stroke:palette.red+1pt)
    content((x+1.4,2.28),text(font:"Arial",size:9pt,[G#level]))
  }
})
#let surface-parameter-domain(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  for x in range(14) {line((x*0.45,-0.55),(x*0.45,3.4),stroke:palette.grid+0.4pt)}
  for y in range(7) {line((-0.6,y*0.5),(6.4,y*0.5),stroke:palette.grid+0.4pt)}
  rect((0,0),(5.85,3),stroke:black+0.65pt)
  vector-arrow((0.4,-0.9),(4.95,0),color:palette.red3d,thickness:0.9pt)
  vector-arrow((-0.9,0.3),(0,2.35),color:palette.green3d,thickness:0.9pt)
  for (p,body,col) in (((0,-0.9),$u_0$,palette.red3d),((5.85,-0.9),$u_1$,palette.red3d),
    ((-0.9,0),$v_0$,palette.green3d),((-0.9,3),$v_1$,palette.green3d)) {
    content(p,text(size:9pt,fill:col,body))
  }
})
// 图 65、66：同一矩形网格，分别表现边坍缩与曲面修剪。
#let triangle-surface(length:diagram-style.unit,trimmed:false)=canvas(length:length,{
  import draw: *
  let w=2.8;let h=2.05
  let box(x)={
    line((x,0),(x+w,0),(x+w,h),(x,h),close:true,
      stroke:(paint:black,thickness:0.4pt,dash:"dotted"))
    for p in ((x,0),(x+w,0),(x+w,h),(x,h)) {
      rect(vector-add(p,(-0.025,-0.025)),vector-add(p,(0.025,0.025)),fill:white,stroke:black+0.5pt)
    }
  }
  rect((0,0),(w,h),fill:rgb("#e5e5e5"),stroke:none)
  for t in (1/3,2/3) {
    line((0,h*t),(w,h*t),stroke:palette.red3d+0.6pt)
    line((w*t,0),(w*t,h),stroke:palette.green3d+0.6pt)
  }
  box(0)
  if trimmed {line((0,0),(w/2,h),(w,0),close:true,stroke:black+0.7pt)} else {
    for side in (0,w) {
      let arrow=curve-spec(((side,h+0.06),(side*0.65+w*0.175,h+0.5),(w/2+(side - w/2)*0.25,h+0.35),(w/2+(side - w/2)*0.08,h+0.09)))
      nurbs(arrow,stroke:palette.red3d+0.5pt)
      let end=arrow.control_points.last();let prev=arrow.control_points.at(2)
      vector-arrow(interpolate-points(prev,end,0.8),vector-scale(vector-subtract(end,prev),0.2),color:palette.red3d,thickness:0.5pt)
    }
    rect((w/2-0.05,h - 0.05),(w/2+0.05,h+0.05),fill:white,stroke:palette.red3d+0.7pt)
  }
  let x=3.35
  line((x,0),(x+w/2,h),(x+w,0),close:true,fill:rgb("#e5e5e5"),stroke:none)
  for t in (1/3,2/3) {
    line((x+w*t/2,h*t),(x+w*(1-t/2),h*t),stroke:palette.red3d+0.6pt)
    if trimmed {line((x+w*t,0),(x+w*t,h*(1-calc.abs(2*t - 1))),stroke:palette.green3d+0.6pt)}
    else {line((x+w*t,0),(x+w/2,h),stroke:palette.green3d+0.6pt)}
  }
  if trimmed {box(x)} else {
    line((x,0),(x+w/2,h),(x+w,0),close:true,stroke:(paint:black,thickness:0.4pt,dash:"dotted"))
    for p in ((x,0),(x+w/2,h),(x+w,0)) {rect(vector-add(p,(-0.025,-0.025)),vector-add(p,(0.025,0.025)),fill:white,stroke:black+0.5pt)}
  }
  line((6.4,-0.38),(6.4,h+0.3),stroke:black+0.45pt)
  let x=7.2
  for xx in (x,x+w) {line((xx,-0.2),(xx,h+0.25),stroke:black+0.4pt)}
  for y in (0,h) {line((x - 0.25,y),(x+w+0.25,y),stroke:black+0.4pt)}
  if trimmed {line((x,0),(x+w/2,h),(x+w,0),close:true,stroke:black+1pt)}
  else {rect((x,0),(x+w,h),stroke:black+1pt)}
  vector-arrow((x,-0.37),(w,0),color:palette.red3d,thickness:0.7pt)
  vector-arrow((x - 0.45,0),(0,h),color:palette.green3d,thickness:0.7pt)
  content((x - 0.1,-0.37),text(size:8pt,fill:palette.red3d)[$u$],anchor:"east")
  content((x - 0.45,-0.08),text(size:8pt,fill:palette.green3d)[$v$],anchor:"north")
})
#let collapsed-surface(length:diagram-style.unit)=triangle-surface(length:length)
#let trimmed-triangle(length:diagram-style.unit)=triangle-surface(length:length,trimmed:true)
// 图 58、59 共用单位半圆柱：轴向 x，横截面 y²+z²=1，z>=0。
#let cylinder-camera(p,azimuth:35deg,elevation:25deg,roll:0deg)={
  let x=calc.cos(azimuth)*p.at(0)-calc.sin(azimuth)*p.at(1)
  let y=-calc.sin(elevation)*(calc.sin(azimuth)*p.at(0)+calc.cos(azimuth)*p.at(1))+calc.cos(elevation)*p.at(2)
  (x*calc.cos(roll)-y*calc.sin(roll),x*calc.sin(roll)+y*calc.cos(roll))
}
#let normal-camera=cylinder-camera.with(azimuth:40deg,elevation:35deg,roll:20deg)
#let cylinder-depth(p)=calc.cos(25deg)*(calc.sin(35deg)*p.at(0)+calc.cos(35deg)*p.at(1))+calc.sin(25deg)*p.at(2)
#let cylinder-point(x,t)=(x,calc.cos(t),calc.sin(t))
#let cylinder-ring(x,full:false,camera:cylinder-camera)={
  let c=circle-data()
  if not full {
    c.control_points=c.control_points.slice(0,5)
    c.weights=c.weights.slice(0,5)
    c.knots=(0,0,0,1,1,2,2,2)
  }
  c.control_points=c.control_points.map(p=>camera((x,p.at(0),p.at(1))))
  c
}
// 半透明色层由解析射线交点的前后次序生成，已合并为无接缝的矢量区域并内嵌于本文件。
// 半圆柱和截平面交由 scenery 的 BSP 引擎切分、排序，再由 CeTZ 原生绘制。
// 场景不依赖画布尺寸，避免 fig 测量时重复建立模型。
#let cylinder-scene(sections:false)={
  let faces=()
  for i in range(64) {
    let a=180deg*i/64
    let b=180deg*(i+1)/64
    faces.push(scenery.face((cylinder-point(-1.35,a),cylinder-point(1.35,a),
      cylinder-point(1.35,b),cylinder-point(-1.35,b)),
      color:rgb("#b35b5b"),fill-opacity:48%,shade:false,stroke:none))
  }
  if sections {
    faces.push(scenery.face(((0,-1.65,-0.5),(0,1.65,-0.5),(0,1.65,1.5),(0,-1.65,1.5)),
      color:rgb("#50b76a"),fill-opacity:66%,shade:false,stroke:none))
    faces.push(scenery.face(((-1.65,0,-0.5),(1.65,0,-0.5),(1.65,0,1.5),(-1.65,0,1.5)),
      color:rgb("#729a57"),fill-opacity:68%,shade:false,stroke:none))
  }
  scenery.build-scene(..faces)
}
#let cylinder-principal-drawing=scenery.scene-group(cylinder-scene(),
  scenery.camera(azimuth:-35deg,elevation:25deg),engine:"wasm",register-anchors:false)
#let cylinder-normal-drawing=scenery.scene-group(cylinder-scene(sections:true),
  scenery.camera(azimuth:-40deg,elevation:35deg),engine:"wasm",register-anchors:false)

#let cylinder-render(length:diagram-style.unit,sections:false,camera:cylinder-camera)={
  import draw: *
  group({
    if sections { rotate(20deg); cylinder-normal-drawing } else { cylinder-principal-drawing }
  })
  // 后端边缘透过柱面显示为浅色；前端边缘保持清晰。
  for x in (-1.35,1.35) {
    nurbs(cylinder-ring(x,camera:camera),stroke:(if x < 0 {palette.red.lighten(50%)} else {palette.red})+0.5pt)
  }
  for y in (-1,1) {
    line(camera((-1.35,y,0)),camera((1.35,y,0)),
      stroke:(if y < 0 {palette.red.lighten(50%)} else {palette.red})+0.5pt)
  }
}
// 下半圆在柱面投影内的部分以透射后的线色显示，不会被填充完全抹掉。
#let cylinder-lower-section()={
  let model=circle-data()
  let dx=calc.cos(25deg)*calc.sin(35deg)
  let dy=calc.cos(25deg)*calc.cos(35deg)
  let dz=calc.sin(25deg)
  for i in range(100) {
    let uv=evaluate-point(model,2+2*(i+0.5)/100)
    let p=(0,uv.at(0),uv.at(1))
    // 从该圆上点沿视线朝相机求第二个圆柱交点。
    let step=-2*(p.at(1)*dy+p.at(2)*dz)/(dy*dy+dz*dz)
    let hidden=step>0.00001 and calc.abs(step*dx)<=1.35 and p.at(2)+step*dz>=0
    let a=evaluate-point(model,2+2*i/100)
    let b=evaluate-point(model,2+2*(i+1)/100)
    draw.line(cylinder-camera((0,a.at(0),a.at(1))),cylinder-camera((0,b.at(0),b.at(1))),
      stroke:palette.green3d.transparentize(if hidden {48%} else {0%})+0.9pt)
  }
}
#let principal-curvatures(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  cylinder-render(length:length)
  cylinder-lower-section()
  nurbs(cylinder-ring(0),stroke:palette.green3d+1pt)
  let a=cylinder-camera((-1.35,0,1));let b=cylinder-camera((1.35,0,1))
  line(a,b,stroke:palette.green3d+1pt)
  let p=cylinder-camera((0,0,1))
  rect(vector-add(p,(-0.035,-0.035)),vector-add(p,(0.035,0.035)),fill:white,stroke:black+0.7pt)
  let label=vector-add(a,(-0.4,0.45))
  line(label,a,stroke:black+0.4pt)
  content(label,text(size:8pt)[最小曲率 $=0$],anchor:"south",padding:2pt)
  let q=cylinder-camera((0,-0.65,-calc.sqrt(1-0.65*0.65)))
  let label=vector-add(q,(0.65,-0.12))
  line(q,label,stroke:black+0.4pt)
  content(label,text(size:8pt)[最大曲率 $=1/r$],anchor:"west",padding:2pt)
})
#let normal-curvature(length:diagram-style.unit)=canvas(length:length,{
  import draw: *
  cylinder-render(length:length,sections:true,camera:normal-camera)
  for pts in (((0,-1.65,-0.5),(0,1.65,-0.5),(0,1.65,1.5),(0,-1.65,1.5)),
    ((-1.65,0,-0.5),(1.65,0,-0.5),(1.65,0,1.5),(-1.65,0,1.5))) {
    line(..pts.map(normal-camera),close:true,stroke:rgb("#55845c")+0.45pt)
  }
  // P=(0,0,1)，切平面 z=1；法线及两条法截线严格共点。
  let corners=((-0.48,-0.48,1),(0.48,-0.48,1),(0.48,0.48,1),(-0.48,0.48,1))
  line(..corners.map(normal-camera),close:true,fill:rgb("#bac59e").transparentize(60%),stroke:palette.red+0.35pt)
  for i in range(9) {
    let t=-0.48+0.96*i/8
    line(normal-camera((t,-0.48,1)),normal-camera((t,0.48,1)),stroke:palette.red+0.3pt)
    line(normal-camera((-0.48,t,1)),normal-camera((0.48,t,1)),stroke:palette.red+0.3pt)
  }
  nurbs(cylinder-ring(0,camera:normal-camera),stroke:black+0.9pt)
  line(normal-camera((-1.35,0,1)),normal-camera((1.35,0,1)),stroke:black+0.9pt)
  let p=normal-camera((0,0,1));let tip=normal-camera((0,0,1.95))
  vector-arrow(p,vector-subtract(tip,p),color:palette.red3d,thickness:1pt)
  circle(p,radius:0.026,fill:black,stroke:none)
  content(vector-add(tip,(0.1,0)),text(size:8pt)[曲面法线],anchor:"west",padding:2pt)
  for (body,label,target) in (([最小弯曲方向],(-2,1.8),normal-camera((-0.9,0,1))),
    ([切平面],(-2.15,0.8),normal-camera((-0.4,0.4,1))),
    ([最大弯曲方向],(-1.75,-1),normal-camera((0,0.8,0.6)))) {
    line(label,target,stroke:black+0.4pt)
    content(label,text(size:8pt,body),anchor:"east",padding:2pt)
  }
})
