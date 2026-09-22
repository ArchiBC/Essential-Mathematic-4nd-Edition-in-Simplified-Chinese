#import "@preview/cetz:0.5.2": canvas, draw
#import "image.typ": palette, vector-arrow, point-mark, matrix-cells

// 本节统一相机：X 右下、Y 右上、Z 向上。
#let project(p) = (0.85 * p.at(0) + 0.65 * p.at(1), -0.3 * p.at(0) + 0.38 * p.at(1) + p.at(2))
#let add(a, b) = a.zip(b).map(((x, y)) => x + y)
#let mul(p, s) = p.map(v => v * s)
#let cube(origin, size) = ((0,0,0), (1,0,0), (1,1,0), (0,1,0), (0,0,1), (1,0,1), (1,1,1), (0,1,1)).map(p => add(origin, p.zip(size).map(((a,b)) => a*b)))
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

#let translation-vector(length: 0.72cm) = canvas(length: length, {
  import draw: *
  let displacement = (5,1,0)
  let p = (1.4,0,0)
  let q = add(p, displacement)
  solid(cube((0,0,0), (1.4,1.4,2.7)), palette.red)
  solid(cube(displacement, (1.4,1.4,2.7)), palette.green)
  arrow3(p,q)
  point-mark(project(p), length, color: palette.green)
  point-mark(project(q), length)
  content(add(project(p),(0,-0.25)), $P(x,y,z)$, anchor: "north")
  content(add(project(q),(0,-0.25)), $P'$, anchor: "north")
  let label-pos = add(project(mul(add(p,q),0.5)), (0,0.2))
  content(label-pos, $bold(arrow(v)) chevron.l a,b,c chevron.r$, anchor: "south")
})
#let translation-cube(length: 0.72cm) = canvas(length: length, {
  import draw: *
  let cam(p) = mul(project(p), 0.62)
  ground(7,8,camera: cam)
  let points = cube((0,0,0),(2,2,2))
  solid(points, palette.red, camera: cam)
  solid(points.map(p => add(p,(4,5,3))), palette.green, camera: cam)
  for (a,b,label,color,shift) in (
    ((0,0,0),(4,0,0),$4$,palette.red,(0,-0.25)),
    ((4,0,0),(4,5,0),$5$,palette.green,(0,-0.25)),
    ((4,5,0),(4,5,3),$3$,rgb("#2455cc"),(0.2,0)),
  ) {
    arrow3(a,b,color: color,camera: cam)
    content(add(cam(mul(add(a,b),0.5)),shift), text(fill: color,label))
  }
})
#let rotation-point(length: 0.72cm) = canvas(length: length, {
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
  content(add(p,(0.2,0)), $P(x,y)$,anchor: "west")
  content(add(q,(0.2,0)), $P'(x',y')$,anchor: "west")
  content((1.15,2.55),$d$,anchor: "east")
  content((5.5,0),$x$,anchor: "west")
  content((0,5),$y$,anchor: "south")
})
#let rotate-z(p, angle) = (p.at(0)*calc.cos(angle)-p.at(1)*calc.sin(angle), p.at(0)*calc.sin(angle)+p.at(1)*calc.cos(angle),p.at(2))
#let rotation-cube(length: 0.72cm) = canvas(length: length, {
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
#let scaling-cube(length: 0.72cm) = canvas(length: length, {
  ground(6,5)
  let points = cube((2,2,0),(2,2,2))
  solid(points,palette.red)
  solid(points.map(p=>mul(p,0.25)),palette.green)
  point-mark(project((0,0,0)),length,color: palette.green)
})
#let scaling-matrix() = matrix-cells(($0.25$,$0$,$0$,$0$,$0$,$0.25$,$0$,$0$,$0$,$0$,$0.25$,$0$,$0$,$0$,$0$,$1$))

#let shear-cube(target, source, length: 0.72cm) = canvas(length: length, {
  let cam(p) = mul((0.9*p.at(0)+0.7*p.at(1),-0.25*p.at(0)+0.6*p.at(1)+p.at(2)),2)
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
#let shear-xy(length: 0.72cm) = shear-cube(0,1,length: length)
#let shear-zy(length: 0.72cm) = shear-cube(2,1,length: length)
#let shear-yx(length: 0.72cm) = shear-cube(1,0,length: length)
#let shear-zx(length: 0.72cm) = shear-cube(2,0,length: length)
#let shear-xz(length: 0.72cm) = shear-cube(0,2,length: length)
#let shear-yz(length: 0.72cm) = shear-cube(1,2,length: length)

#let reflection-cube(length: 0.72cm) = canvas(length: length, {
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

// 同一条四次 Bezier 曲线的三个投影，直接投影控制点，保持参数与形状关系。
#let projection-curve(axis, length: 0.72cm) = canvas(length: length, {
  import draw: *
  let controls=((0,0,0),(2,1,2.7),(4,2,0.5),(2,4,3),(0,4,3))
  let flatten(p) = { let q=p; q.at(axis)=0; q }
  let evaluate(points,t) = {
    let level=points
    while level.len()>1 {
      level=range(level.len()-1).map(i=>add(mul(level.at(i),1-t),mul(level.at(i+1),t)))
    }
    level.first()
  }
  arrow3((0,0,0),(5,0,0),color: palette.red)
  arrow3((0,0,0),(0,5,0),color: palette.green)
  content(add(project((5,0,0)),(0.15,0)),$x$,anchor: "west")
  content(add(project((0,5,0)),(0.15,0)),$y$,anchor: "west")
  line(..controls.map(project),stroke: (paint: rgb("#666666"),thickness: 0.5pt,dash: "dotted"))
  let projected=controls.map(flatten)
  line(..range(101).map(i=>project(evaluate(controls,i/100))),stroke: palette.red + 0.7pt)
  line(..range(101).map(i=>project(evaluate(projected,i/100))),stroke: palette.green + 0.7pt)
  for p in controls { point-mark(project(p),length,size: 0.055cm,thickness: 1pt) }
})
#let projection-xy(length: 0.72cm) = projection-curve(2,length: length)
#let projection-xz(length: 0.72cm) = projection-curve(1,length: length)
#let projection-yz(length: 0.72cm) = projection-curve(0,length: length)
