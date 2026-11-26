// Snowman artwork adapted from SnowApp/SnowmanArt.swift in the macOS port.
void snowmanBezier(Gdiplus::GraphicsPath& shape,V a,V control,V b){
 shape.AddBezier(point(a),point(a+(control-a)*(2./3)),point(b+(control-b)*(2./3)),point(b));
}
void snowmanStroke(Gdiplus::GraphicsPath& shape,uint32_t rgb,double width){
 Gdiplus::Pen pen(color(rgb),REAL(width));
 pen.SetStartCap(Gdiplus::LineCapRound);
 pen.SetEndCap(Gdiplus::LineCapRound);
 g.DrawPath(&pen,&shape);
}
void snowmanHat(double r,SnowmanVariant variant){
 auto state=g.Save();
 if(variant==SnowmanVariant::classicBucket){
  g.TranslateTransform(0,REAL(r*.78));
  g.RotateTransform(-5.7f);
  Gdiplus::GraphicsPath handle;
  handle.AddBezier(point({-r*.50,r*.76}),point({-r*1.03,r*1.05}),point({-r*1.08,r*.08}),point({-r*.62,r*.10}));
  snowmanStroke(handle,0x5C7586,1);
  polygon({{-r*.82,0},{r*.82,0},{r*.58,r*.95},{-r*.58,r*.95}},0x8B9CA7,0x5C7586,.7);
  polygon({{r*.38,r*.03},{r*.82,0},{r*.58,r*.95},{r*.31,r*.95}},0x6B8291);
  polygon({{-r*.62,r*.12},{-r*.32,r*.12},{-r*.27,r*.82},{-r*.45,r*.82}},0xCEDDE4);
  rect(-r*.90,-r*.04,r*1.8,std::max(2.,r*.13),0xB9CEDA);
 }else{
  const bool knitted=variant==SnowmanVariant::winterBroom, waving=variant==SnowmanVariant::waving;
  g.RotateTransform(knitted?0.f:waving?4.6f:-3.4f);
  g.ScaleTransform(REAL(r),REAL(r));
  Gdiplus::GraphicsPath hat;
  V pom;
  if(knitted){
   hat.AddBezier(-.82f,1.01f,-.75f,1.60f,-.43f,1.91f,0.f,1.90f);
   hat.AddBezier(0.f,1.90f,.51f,1.91f,.75f,1.57f,.84f,1.01f);
   hat.CloseFigure();
   path(hat,0x559AB6);
   line({{-.70,1.38},{.70,1.38}},0xD85750,.055);
   for(int i=0;i<6;i++){
    double x=-.70+i*.235;
    line({{x,1.40},{x+.115,1.60},{x+.23,1.40}},0xD85750,.035);
   }
   pom={0,1.99};
  }else{
   if(waving){
    hat.AddBezier(-.76f,1.02f,-.91f,1.56f,-.74f,2.02f,-.20f,1.99f);
    snowmanBezier(hat,{-.20,1.99},{.42,2.04},{.65,1.64});
    snowmanBezier(hat,{.65,1.64},{.86,1.30},{.81,1.02});
   }else{
    hat.AddBezier(-.76f,1.02f,-.24f,1.74f,.36f,2.11f,.55f,2.11f);
    snowmanBezier(hat,{.55,2.11},{.75,1.93},{.86,1.35});
    snowmanBezier(hat,{.86,1.35},{.87,1.13},{.69,1.02});
   }
   hat.CloseFigure();
   path(hat,0xD85D52);
   Gdiplus::GraphicsPath shade;
   V peak{.55,waving?1.88:2.05};
   snowmanBezier(shade,{.36,1.11},{.57,1.57},peak);
   snowmanBezier(shade,peak,{.91,1.49},{.81,1.02});
   shade.CloseFigure();
   path(shade,0xB94743);
   pom=waving?V{-.23,2.02}:V{.55,2.12};
  }
  circle(pom,.25,0xC5D9E4);
  circle(pom+V{-.04,.04},.23,0xF5FAFC);
  Gdiplus::GraphicsPath fur,seam;
  snowmanBezier(fur,{-.88,.72},{-1,.98},{-.78,1.12});
  snowmanBezier(fur,{-.78,1.12},{0,1.31},{.80,1.12});
  snowmanBezier(fur,{.80,1.12},{1.02,.98},{.89,.73});
  snowmanBezier(fur,{.89,.73},{0,.94},{-.88,.72});
  fur.CloseFigure();
  path(fur,0xF3F9FB,0xBACFDD,.6/r);
  snowmanBezier(seam,{-.75,.76},{0,1.00},{.76,.77});
  snowmanStroke(seam,0xD5E4EC,.065);
 }
 g.Restore(state);
}
void snowmanScarf(double r,SnowmanVariant variant){
 const bool festive=variant==SnowmanVariant::festive, waving=variant==SnowmanVariant::waving;
 const bool bucket=variant==SnowmanVariant::classicBucket, blue=!festive&&!waving;
 const uint32_t main=blue?0x559AB6:0xD85D52, shade=blue?0x397B99:0xB94743;
 auto state=g.Save();
 g.ScaleTransform(REAL(r),REAL(r));
 const double tailX=blue?-.30:.52;
 auto tail=g.Save();
 g.TranslateTransform(REAL(tailX),-.91f);
 Gdiplus::GraphicsPath shape;
 if(festive){
  snowmanBezier(shape,{-.12,.10},{1.1,.47},{2.25,.35});
  snowmanBezier(shape,{2.25,.35},{2.16,-.05},{2.37,-.47});
  snowmanBezier(shape,{2.37,-.47},{1.15,-.70},{-.15,-.36});
 }else if(waving){
  shape.AddLine(-.18f,.10f,.34f,.05f);
  shape.AddBezier(.34f,.05f,.48f,-.97f,.90f,-2.30f,.59f,-2.84f);
  snowmanBezier(shape,{.59,-2.84},{.13,-3.00},{-.17,-2.96});
  snowmanBezier(shape,{-.17,-2.96},{-.48,-1.55},{-.18,.10});
 }else{
  shape.AddLine(-.22f,.10f,.23f,.10f);
  snowmanBezier(shape,{.23,.10},{.12,-1.60},{.22,-3.02});
  shape.AddLine(.22f,-3.02f,-.25f,-3.02f);
  snowmanBezier(shape,{-.25,-3.02},{-.30,-1.60},{-.22,.10});
 }
 shape.CloseFigure();
 path(shape,main);
 if(festive){
  for(V dot: {V{.47,-.03},V{.97,.09},V{1.40,-.27},V{1.90,.12},V{2.08,-.26}})
   circle(dot,.065,0xF5E7DF);
 }else if(blue){
  for(double y:{-2.45,-2.65})rect(-.22,y,.45,.065,bucket?0x83C0D2:0xD65B51);
  for(int i=0;i<6;i++){
   double x=-.22+i*.085;
   line({{x,-3},{x,-3.22}},bucket?shade:0xCE514A,.045);
  }
 }
 g.Restore(tail);
 if(bucket){
  rect(.28,-3.20,.38,2.30,main);
  for(double y:{-2.75,-2.95})rect(.28,y,.38,.06,0x83C0D2);
 }
 Gdiplus::GraphicsPath collar;
 collar.AddBezier(-.78f,-.72f,-.30f,-.84f,.30f,-.84f,.78f,-.72f);
 collar.AddBezier(.78f,-.72f,.90f,-.77f,.86f,-.93f,.72f,-.96f);
 collar.AddBezier(.72f,-.96f,.25f,-1.08f,-.25f,-1.08f,-.72f,-.96f);
 collar.AddBezier(-.72f,-.96f,-.86f,-.93f,-.90f,-.77f,-.78f,-.72f);
 collar.CloseFigure();
 path(collar,shade);
 circle({tailX,-.90},.15,main);
 g.Restore(state);
}
void snowmanMitten(V hand,double r,double angle){
 auto state=g.Save();
 g.TranslateTransform(REAL(hand.x),REAL(hand.y));
 g.RotateTransform(REAL(angle));
 g.ScaleTransform(REAL(r),REAL(r));
 Gdiplus::GraphicsPath mitten;
 mitten.AddLine(-.24f,-.20f,.22f,-.20f);
 mitten.AddBezier(.22f,-.20f,.47f,.06f,.48f,.53f,.29f,.68f);
 mitten.AddBezier(.29f,.68f,.12f,.90f,-.25f,.78f,-.20f,.48f);
 snowmanBezier(mitten,{-.20,.48},{-.37,.68},{-.46,.35});
 snowmanBezier(mitten,{-.46,.35},{-.65,.12},{-.24,-.20});
 mitten.CloseFigure();
 path(mitten,0xD85D52);
 rect(-.27,-.28,.53,.20,0xB94743);
 ellipse({.055,.43},.115,.18,0xED8B77);
 g.Restore(state);
}
void snowmanBroom(V grip,double bottom,double r){
 auto state=g.Save();
 g.TranslateTransform(REAL(grip.x),REAL(grip.y));
 g.ScaleTransform(REAL(r),REAL(r));
 line({{.36,(bottom-grip.y)/r},{-.22,3.1}},0x505558,.13);
 Gdiplus::GraphicsPath brush;
 brush.AddLine(-.54f,2.84f,.16f,2.84f);
 snowmanBezier(brush,{.16,2.84},{.58,3.78},{.62,4.68});
 snowmanBezier(brush,{.62,4.68},{-.13,4.89},{-1.13,4.62});
 snowmanBezier(brush,{-1.13,4.62},{-.95,3.62},{-.54,2.84});
 brush.CloseFigure();
 path(brush,0x929A9F);
 for(int i=0;i<9;i++){
  double x=-1.03+i*.20;
  Gdiplus::GraphicsPath straw;
  snowmanBezier(straw,{x+.02,4.58+(i%3)*.07},{x,3.78},{-.50+i*.07,2.89});
  snowmanStroke(straw,i%2?0xC7CFD1:0x56626B,.048);
 }
 for(double y:{2.94,3.04,3.14})line({{-.58,y},{.21,y+.05}},0xD7AE56,.055);
 g.Restore(state);
}
void snowman(const Ball& base,const Ball& middle,const Ball& head,bool textured){
 const auto variant=static_cast<SnowmanVariant>(head.snowmanLook);
 const bool waving=variant==SnowmanVariant::waving, broom=variant==SnowmanVariant::winterBroom;
 const bool bucket=variant==SnowmanVariant::classicBucket;
 const double r=head.radius, m=middle.radius, b=base.radius;
 const V center=middle.p-head.p, bottom=base.p-head.p;
 const V left={bottom.x-b*(broom?1.28:1.16),center.y+m*(broom?1.28:bucket?-.47:-.65)};
 const V right={bottom.x+b*(bucket?1.19:1.15),waving?r*.30:center.y+m*(broom?.48:bucket?.55:-.57)};
 auto state=g.Save();
 g.TranslateTransform(REAL(head.p.x),REAL(head.p.y));
 if(broom)snowmanBroom(right,bottom.y-b+2,r);
 for(int side:{-1,1}){
  V start=center+V{side*m*.88,m*.20}, end=side<0?left:right;
  Gdiplus::GraphicsPath arm;
  snowmanBezier(arm,start,{end.x*.75+start.x*.25,start.y+(end.y-start.y)*.28},end);
  snowmanStroke(arm,0x454F56,std::max(1.15,r*.085));
  if(!waving)for(double dy:{-.20,.20})
   line({{end.x-side*r*.18,end.y+(end.y<start.y?r*.18:-r*.18)},
         {end.x+side*r*.24,end.y+r*dy}},0x454F56,std::max(.8,r*.045));
 }
 sphere(bottom,b,textured);
 sphere(center,m,textured);
 sphere({},r,textured);
 if(!broom)for(int side:{-1,1}){
  auto foot=g.Save();
  g.TranslateTransform(REAL(bottom.x+side*b*.56),REAL(bottom.y-b+2.5));
  g.RotateTransform(side*5.7f);
  ellipse({0,.015*b},.39*b,.135*b,0xA5C0D0);
  ellipse({0,.035*b},.37*b,.112*b,0xDCEBF2);
  ellipse({-.045*b,.060*b},.265*b,.08*b,0xF3F9FB);
  g.Restore(foot);
 }
 for(auto* ball:{&middle,&base})for(double y:{.20,-.30}){
  V at=ball->p-head.p+V{waving?-ball->radius*.09:0,y*ball->radius};
  circle(at,std::max(1.3,ball->radius*.072),0x293F4A);
  circle(at+V{-.4,.5},std::max(.35,ball->radius*.018),0x8CA3B0);
 }
 if(waving){
  snowmanMitten(left,r,-37);
  snowmanMitten(right,r,9);
 }else if(!broom){
  sphere(right+V{0,r*(bucket?.40:.30)},r*(bucket?.55:.52),textured);
 }
 snowmanHat(r,variant);
 snowmanScarf(r,variant);
 for(double side:{-1.,1.}){
  circle({side*r*.57,-r*.09},r*.145,0xE5A7B1,.64);
  V eye{side*r*.28,r*.25};
  circle(eye,std::max(1.3,r*.08),0x293F4A);
  circle(eye+V{-r*.035,r*.035},r*.014,0xEAF4F7);
 }
 Gdiplus::GraphicsPath smile;
 snowmanBezier(smile,{-r*.35,-r*.25},{0,-r*.63},{r*.35,-r*.25});
 snowmanStroke(smile,0x293F4A,std::max(1.4,r*.075));
 const V nose=variant==SnowmanVariant::festive?V{r*.38,-r*.34}:V{r*.82,-r*.04};
 polygon({{-r*.06,r*.06},nose,{-r*.06,-r*.23}},0xDF8B43);
 g.Restore(state);
}

void balls(const Simulation& sim,const Settings& settings){
 const bool textured=settings.appearance==1;
 std::set<uint64_t> decorated;
 for(const auto& group:sim.game.snowmen()){
  const auto& base=*sim.game.find(group[0]);
  const auto& middle=*sim.game.find(group[1]);
  const auto& head=*sim.game.find(group[2]);
  if(head.snowmanLook<0)continue;
  decorated.insert(group.begin(),group.end());
  auto state=g.Save();
  if(const auto* surface=Game::surface(head.surface,sim.surfaces)){
   // Occluded window segments clip all of the artwork, including the accessories.
   Gdiplus::Region visible;
   visible.MakeEmpty();
   double left=surface->left, right=left+surface->width;
   for(auto span:surface->visible){
    double start=span.lo<=0?0:left+span.lo;
    double end=span.hi>=surface->width?sim.size.x:left+span.hi;
    start=std::max(0.,start);
    end=std::min(sim.size.x,end);
    if(end>start)visible.Union(Gdiplus::RectF(REAL(start),0,REAL(end-start),REAL(sim.size.y)));
   }
   if(right>0&&left<sim.size.x)g.SetClip(&visible,Gdiplus::CombineModeIntersect);
  }
  snowman(base,middle,head,textured);
  g.Restore(state);
 }
 for(const auto& ball:sim.game.balls)
  if(!decorated.count(ball.id)&&sim.game.visible(ball,sim.surfaces))sphere(ball.p,ball.radius,textured);
}
