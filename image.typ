#import "@preview/cetz:0.5.2": canvas, draw

// 统一配色（取自原图）
#let palette = (
  grid: rgb("#ebebeb"), // 网格
  x-axis: rgb("#960000"), // X 轴（红）
  y-axis: rgb("#009600"), // Y 轴（绿）
  vector: rgb("#009600"), // 向量（绿）
  point: rgb("#960000"), // 起点（红）
)

// 点标记：红色叉
#let point-mark(
  pos,
  size: 0.14,
  color: palette.point,
  thickness: 2pt,
) = {
  import draw: *
  line(
    (pos.at(0) - size, pos.at(1) - size),
    (pos.at(0) + size, pos.at(1) + size),
    stroke: (paint: color, thickness: thickness),
  )
  line(
    (pos.at(0) - size, pos.at(1) + size),
    (pos.at(0) + size, pos.at(1) - size),
    stroke: (paint: color, thickness: thickness),
  )
}

// 向量箭头
#let vector-arrow(
  start,
  vec,
  color: palette.vector,
  thickness: 1pt,
) = {
  import draw: *
  line(
    start,
    (start.at(0) + vec.at(0), start.at(1) + vec.at(1)),
    stroke: (paint: color, thickness: thickness),
    mark: (end: ">", stroke: (paint: color, thickness: thickness), fill: color),
  )
}

// 图 1：同一向量的等价表示（起点不同，方向与长度相同）
#let vector-equivalent(length: 0.72cm) = canvas(length: length, {
  import draw: *

  // 网格（不含最外圈边框）
  for x in range(1, 8) {
    line((x, 0), (x, 4), stroke: (paint: palette.grid, thickness: 0.4pt))
  }
  for y in range(1, 4) {
    line((0, y), (8, y), stroke: (paint: palette.grid, thickness: 0.4pt))
  }
  // 坐标轴：只画正方向，无箭头（对齐网格）
  let origin = (3, 2)
  let axis-thickness = 1pt
  line(origin, (8, 2), stroke: (paint: palette.x-axis, thickness: axis-thickness))
  line(origin, (3, 4), stroke: (paint: palette.y-axis, thickness: axis-thickness))

  // 等价向量：同方向、同长度，起点与端点都落在格点上
  let v = (1, 1)
  let starts = ((1, 3), (5, 3), (6, 1), (1, 0), (4, 0))
  for s in starts {
    vector-arrow(s, v)
    point-mark(s)
  }
})
