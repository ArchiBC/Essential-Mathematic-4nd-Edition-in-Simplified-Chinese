#import "@preview/cetz:0.5.2": canvas, draw
#import "image.typ": palette, vector-arrow, point-mark
#let plus(a,b)=a.zip(b).map(((x,y))=>x+y)
#let vscale(a,s)=a.map(x=>x*s)
#let lerp(a,b,t)=plus(vscale(a,1-t),vscale(b,t))
#let bez(points,t)={
  let p=points
  while p.len()>1 { p=range(p.len()-1).map(i=>lerp(p.at(i),p.at(i+1),t)) }
  p.first()
}
#let curve(fn,color: black,thickness: 1.2pt)={
  import draw: *
  line(..range(121).map(i=>fn(i/120)),stroke: color+thickness)
}
#let square(p,length,color: black)={
  import draw: *
  let r=0.055cm/length
  rect(plus(p,(-r,-r)),plus(p,(r,r)),fill:white,stroke:color+0.7pt)
}
#let dot(p,length)={
  import draw: *
  circle(p,radius:0.07cm/length,fill:white,stroke:black+0.7pt)
}
#let guide(a,b)={
  import draw: *
  line(a,b,stroke:(paint:rgb("#777777"),thickness:0.5pt,dash:"dotted"))
}
#let wave(u)={
  if u<=0.5 { bez(((0,2),(0.1,4.3),(1.8,4.3),(3,1.3)),u*2) }
  else { bez(((3,1.3),(4,-0.4),(5.2,3),(7,0.5)),(u - 0.5)*2) }
}
#let parameter-wave(t)=wave(calc.pow(t,2.3))

#let journey(length:0.72cm)={
  set text(font: "Arial", weight: "bold", size: 8pt)
  canvas(length:length * 1.25,{
  import draw: *
  let first=((0.6,0.6),(-0.7,4.4),(1.2,5.4),(3.4,4.1))
  let second=((3.4,4.1),(6.2,2.1),(5.6,-0.4),(3.2,0.8))
  curve(t=>bez(first,t)); curve(t=>bez(second,t))
  for p in (first.first(),first.last(),second.last()) { dot(p,length) }
  content((0.7,1.15),text(fill:palette.green)[$t_0$ =\ start time],anchor:"south-west")
  content((0.6,0.3),[start\ location],anchor:"north")
  content((3.2,0.45),[end\ location],anchor:"north")
  content((3.2,1.1),text(fill:palette.green)[$t_1$ =\ end time],anchor:"south-west")
  content((3.55,4.25),text(fill:palette.green)[$t$],anchor:"south")
  content((2.5,3.4),[location at\ time = $t$],anchor:"north")
})
}
#let parametric-line(length:0.72cm)=canvas(length:length,{
  import draw: *
  let a=(0,2.5); let b=(7,0); let p=lerp(a,b,0.25)
  line(a,b,stroke:black+1.2pt)
  dot(a,length); dot(b,length); point-mark(p,length,color:palette.green)
  content(plus(a,(0,0.25)),$P'$,anchor:"south")
  content(plus(a,(0,-0.2)),text(fill:palette.green)[$t_0$],anchor:"north")
  content(plus(b,(0,-0.2)),text(fill:palette.green)[$t_1$],anchor:"north")
  content(plus(p,(0,0.25)),$P$,anchor:"south")
  content(plus(p,(0,-0.25)),text(fill:palette.green)[$t$],anchor:"north")
  vector-arrow((3.5,2.8),(1.5,-0.536),color:rgb("#777777"))
  content((4.25,3),$bold(arrow(v)) chevron.l a,b,c chevron.r$,anchor:"south")
})
#let parametric-circle(length:0.72cm)={
  set text(size: 10pt)
  canvas(length:length,{
  import draw: *
  let r=2.5; let angle=52deg; let p=(r*calc.cos(angle),r*calc.sin(angle))
  circle((0,0),radius:r,stroke:black+1pt)
  vector-arrow((-2.9,0),(6,0),color:palette.red,thickness:0.4pt)
  vector-arrow((0,-2.9),(0,6),color:palette.green,thickness:0.4pt)
  line((0,0),p,stroke:rgb("#777777")+0.6pt)
  line(p,(p.at(0),0),stroke:rgb("#777777")+0.6pt)
  curve(t=>(0.65*calc.cos(t*angle),0.65*calc.sin(t*angle)),thickness:0.5pt)
  dot(p,length)
  content(plus(p,(0.15,0.15)),$P$,anchor:"south-west")
  content((0.82,1.2),$r$,anchor:"east")
  content((0.72,0.35),text(fill:palette.green)[$t$],anchor:"west")
  content((0.2,-0.08),$r cos(t)$,anchor:"north-west")
  content((p.at(0)+0.08,p.at(1)/2),box(fill:white,inset:1pt)[$r sin(t)$],anchor:"west")
  content((3.2,0),$x$,anchor:"west"); content((0,3.2),$y$,anchor:"south")
})
}
#let line-domain(length:0.72cm)={
  canvas(length:length,{
    import draw: *
    // 按原图的上下层次布局；参数刻度与上方对应点使用相同的横坐标。
    let a=(0.4,1.25)
    let b=(4.05,2.2)
    let at(t)=lerp(a,b,t)
    let extended=at(1.28)
    line(a,b,stroke:black+1.2pt)
    dot(a,length); dot(b,length)
    line(plus(b,(0.3,0.078)),extended,stroke:palette.gray+0.4pt)
    content(plus(a,(-0.04,-0.08)), $A$,anchor:"north-east")
    content(plus(b,(0.07,0.02)), $B$,anchor:"west")
    for (p,label,above) in ((at(0.3),$R$,true),(extended,$R'$,false)) {
      line(plus(p,(0,-0.08)),plus(p,(0,0.08)),stroke:palette.green+0.9pt)
      content(plus(p,(0,if above {0.13} else {-0.16})),text(fill:palette.green,label),anchor:if above {"south"} else {"north"})
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
#let curve-domain-diagram(length:0.72cm,mode:0)=canvas(length:length,{
  import draw: *
  curve(wave)
  let a=wave(0); let b=wave(1); let r=parameter-wave(0.5)
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
    content(plus(a,(-0.15,0)),[start point],anchor:"east")
    content(plus(b,(0.15,0)),[end point],anchor:"west")
    content((left,-0.75),text(fill:palette.red)[$t_0$],anchor:"north")
    content((right,-0.75),text(fill:palette.red)[$t_1$],anchor:"north")
    content((-0.4,0.5),[(1)],anchor:"east"); content((-0.4,-0.5),text(fill:palette.red)[(2)],anchor:"east")
  } else {
    guide(r,((left+right)/2,-0.5))
    content(plus(a,(-0.15,0)),$A$,anchor:"east")
    content(plus(b,(0.15,0)),$B$,anchor:"west")
    content(plus(r,(0.15,0.15)),$R$,anchor:"south-west")
    let labels=if mode==1 {($t_0=2.5$,$t=17.5$,$t_1=32.5$)} else {($t_0=0.0$,$t=0.5$,$t_1=1.0$)}
    for (x,label) in ((left,labels.at(0)),((left+right)/2,labels.at(1)),(right,labels.at(2))) {
      content((x,-0.75),label,anchor:"north")
    }
  }
})
#let curve-domain(length:0.72cm)=curve-domain-diagram(length:length)
#let arbitrary-domain(length:0.72cm)=curve-domain-diagram(length:length,mode:1)
#let normalized-domain(length:0.72cm)=curve-domain-diagram(length:length,mode:2)

#let evaluation-diagram(length:0.72cm,nonuniform:false)=canvas(length:length,{
  import draw: *
  let fn(t)=if nonuniform {bez(((0,3),(0.2,0),(1,4),(7,1)),calc.pow(t,1.7))} else {lerp((0,3),(7,1),t)}
  curve(fn)
  line((-0.1,0.45),(7.2,0.45),stroke:palette.gray+0.4pt)
  line((0.8,0),(6.2,0),stroke:palette.red+1.4pt)
  for i in range(6) {
    let p=fn(i/5); let q=(0.8+5.4*i/5,0)
    guide(p,q); square(p,length); square(q,length)
    content(plus(q,(0,-0.22)),$t=#(i*2)$,anchor:"north")
  }
  content(plus(fn(0),(-0.2,0)),$A$,anchor:"east")
  content(plus(fn(1),(0.2,0)),$B$,anchor:"west")
})
#let uniform-evaluation(length:0.72cm)=evaluation-diagram(length:length)
#let nonuniform-evaluation(length:0.72cm)=evaluation-diagram(length:length,nonuniform:true)
#let curve-tangents(length:0.72cm)=canvas(length:length,{
  curve(wave)
  for (t,color) in ((0.27,palette.green),(0.73,palette.red)) {
    let p=wave(t)
    let delta=plus(wave(t+0.0001),vscale(wave(t - 0.0001),-1))
    let norm=calc.sqrt(delta.at(0)*delta.at(0)+delta.at(1)*delta.at(1))
    vector-arrow(p,vscale(delta,1.6/norm),color:color)
    point-mark(p,length,color:color)
  }
})

#let cubic-comparison(length:0.72cm)=canvas(length:length * 0.7,{
  import draw: *
  let points=((0,0),(0.4,3),(3.6,2.7),(4,0))
  for offset in (0,6) {
    let pts=points.map(p=>plus(p,(offset,0)))
    curve(t=>bez(pts,t))
    if offset==0 {
      for (i,p) in pts.enumerate() {square(p,length); content(plus(p,(0,-0.2)),$P_#i$,anchor:"north")}
    } else {
      let start=pts.first(); let end=pts.last()
      vector-arrow(start,plus(pts.at(1),vscale(start,-1)),color:palette.red)
      vector-arrow(pts.at(2),plus(end,vscale(pts.at(2),-1)),color:palette.red)
      square(start,length); square(end,length)
      content(plus(start,(0,-0.2)),$P_0$,anchor:"north");content(plus(end,(0,-0.2)),$P_3$,anchor:"north")
      content(plus(lerp(start,pts.at(1),0.6),(-0.15,0)),text(fill:palette.red)[$R_0$],anchor:"east")
      content(plus(lerp(end,pts.at(2),0.6),(0.15,0)),text(fill:palette.red)[$R_1$],anchor:"west")
    }
  }
})
#let joined-cubics(length:0.72cm,smooth:false)=canvas(length:length * 0.5,{
  import draw: *
  let first=((0,1.5),(0.9,-0.6),(3,-0.4),(3,1.25))
  let second=if smooth {((3,1.25),(3,2.9),(5.1,3.35),(6,1.25))} else {((3,1.25),(3.6,3.1),(5.3,3.1),(6,1.25))}
  // 左侧分开显示定义，右侧显示连接结果。
  let separated=second.map(p=>plus(p,(0.75,0)))
  curve(t=>bez(first,t));curve(t=>bez(separated,t),color:palette.red)
  if smooth {
    for (pts,color) in ((first,black),(separated,palette.red)) {
      square(pts.first(),length,color:color);square(pts.last(),length,color:color)
      vector-arrow(pts.first(),plus(pts.at(1),vscale(pts.first(),-1)),color:palette.gray)
      vector-arrow(pts.at(2),plus(pts.last(),vscale(pts.at(2),-1)),color:palette.gray)
      content(plus(pts.first(),(-0.1,0.25)),text(size:8pt,fill:color)[$P_0$],anchor:"south")
      content(plus(pts.last(),(0.1,0.25)),text(size:8pt,fill:color)[$P_1$],anchor:"south")
      content(plus(lerp(pts.first(),pts.at(1),0.65),(-0.25,0)),text(size:8pt,fill:palette.gray)[$R_0$],anchor:"east")
      content(plus(lerp(pts.last(),pts.at(2),0.65),(0.25,0)),text(size:8pt,fill:palette.gray)[$R_1$],anchor:"west")
    }
  } else {
    for (pts,color) in ((first,black),(separated,palette.red)) {
      for (i,p) in pts.enumerate() {square(p,length,color:color);content(plus(p,(0,if i==1 {-0.25} else {0.25})),text(size:8pt,fill:color)[$P_#i$],anchor:if i==1 {"north"} else {"south"})}
    }
  }
  circle((3.75,1.3),radius:0.85,stroke:palette.gray+0.4pt)
  let off=(9,0)
  curve(t=>plus(bez(first,t),off));curve(t=>plus(bez(second,t),off),color:palette.red)
  circle(plus(second.first(),off),radius:0.45,stroke:palette.gray+0.4pt)
})
#let joined-bezier(length:0.72cm)=joined-cubics(length:length)
#let joined-hermite(length:0.72cm)=joined-cubics(length:length,smooth:true)

// 两段三次 B 样条（权重均为 1 的 NURBS），共享三个控制点。
#let nurbs-spans(length:0.72cm)=canvas(length:length * 0.45,{
  import draw: *
  let cp=((0,1.5),(1.5,-0.5),(3,3),(4.5,3),(6,1.5))
  let knots=(0,0,0,0,0.5,1,1,1,1)
  let evaluate(t)={
    if t==1 {cp.last()} else {
      let k=if t < 0.5 {3} else {4}
      let d=range(4).map(j=>cp.at(k - 3+j))
      for r in range(1,4) {
        for j in range(r,4).rev() {
          let i=k - 3+j
          let alpha=(t - knots.at(i))/(knots.at(i + 4 - r)-knots.at(i))
          d.at(j)=lerp(d.at(j - 1),d.at(j),alpha)
        }
      }
      d.last()
    }
  }
  for (offset,separated) in ((0,true),(10,false)) {
    let shift=(offset,0)
    let redshift=plus(shift,if separated {(1.8,0)} else {(0,0)})
    let left=cp.slice(0,4).map(p=>plus(p,shift))
    let right=cp.slice(1,5).map(p=>plus(p,redshift))
    line(..left,stroke:palette.gray+0.4pt);line(..right,stroke:palette.gray+0.4pt)
    curve(t=>plus(evaluate(t*0.5),shift))
    curve(t=>plus(evaluate(0.5+t*0.5),redshift),color:palette.red)
    if separated {
      // 圈出两段共用的三组控制点：上方两组、下方一组。
      for (center,rx,ry) in (((4.65,3.45),2.2,0.85),((2.4,-0.1),1.45,0.75)) {
        curve(t=>plus(center,(rx*calc.cos(t*360deg),ry*calc.sin(t*360deg))),color:palette.gray,thickness:0.4pt)
      }
      for (pts,color) in ((left,black),(right,palette.red)) {
        for (i,p) in pts.enumerate() {square(p,length,color:color);content(plus(p,(0,0.2)),text(size:8pt,fill:color)[$"CP"#i$],anchor:if color==black and i==3 {"south-east"} else if color==palette.red and i==1 {"south-west"} else {"south"})}
      }
    } else {for p in cp {square(plus(p,shift),length)}}
  }
})
#let casteljau(length:0.72cm)=canvas(length:length,{
  import draw: *
  let cp=((0,0),(1.4,4),(5.1,3.7),(5.4,0))
  let t=0.5
  let first=range(3).map(i=>lerp(cp.at(i),cp.at(i+1),t))
  let second=range(2).map(i=>lerp(first.at(i),first.at(i+1),t))
  let r=lerp(second.first(),second.last(),t)
  line(..cp,stroke:(paint:rgb("#777777"),thickness:0.7pt,dash:"dotted"))
  line(..first,stroke:(paint:rgb("#777777"),thickness:0.7pt,dash:"dotted"))
  line(..second,stroke:palette.red+0.7pt)
  curve(t=>bez(cp,t),thickness:1.4pt)
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
    content(plus(p,offset),text(size:8pt,label),anchor:anchor)
  }
})
