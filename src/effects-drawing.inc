// Shared raster caches are created from original vector/procedural artwork once.
static std::map<int,std::unique_ptr<Gdiplus::Bitmap>>&artCache(){static std::map<int,std::unique_ptr<Gdiplus::Bitmap>> value;return value;}
template<class Draw> Gdiplus::Bitmap&cached(int key,int w,int h,Draw draw){
 auto&item=artCache()[key];if(!item){item=std::make_unique<Gdiplus::Bitmap>(w,h,PixelFormat32bppPARGB);Gdiplus::Graphics graphics(item.get());graphics.Clear(Gdiplus::Color(0,0,0,0));Painter painter(graphics);draw(painter);}return *item;
}
static double grain(int x,int y,uint32_t salt=0){uint32_t v=uint32_t(x)*374761393u+uint32_t(y)*668265263u+salt;v=(v^(v>>13))*1274126177u;return double(v^(v>>16))/double(UINT32_MAX);}
Gdiplus::Bitmap&material(bool sphere){
 int key=sphere?21:20;auto&bitmap=artCache()[key];if(bitmap)return *bitmap;
 bitmap=std::make_unique<Gdiplus::Bitmap>(128,128,PixelFormat32bppPARGB);
 Gdiplus::BitmapData bits{};Gdiplus::Rect rectangle(0,0,128,128);
 if(bitmap->LockBits(&rectangle,Gdiplus::ImageLockModeWrite,PixelFormat32bppPARGB,&bits)!=Gdiplus::Ok)return *bitmap;
 for(int y=0;y<128;y++)for(int x=0;x<128;x++){
  double nx=(x-63.5)/63,ny=(y-63.5)/63,d=std::hypot(nx,ny),alpha=sphere?clamp((1-d)*64,0,1):1;
  double n=grain(x,y,17),shade=sphere?clamp(.98-.13*(nx+ny)*.5-.08*d,.74,1):.95;
  double value=clamp(shade+(n-.5)*.12,0,1);BYTE*pixel=(BYTE*)bits.Scan0+y*bits.Stride+x*4;
  pixel[0]=BYTE(clamp(value+.035,0,1)*255*alpha);pixel[1]=BYTE(clamp(value+.015,0,1)*255*alpha);pixel[2]=BYTE(value*255*alpha);pixel[3]=BYTE(alpha*255);
 }bitmap->UnlockBits(&bits);return *bitmap;
}
void sphere(V p,double radius,bool textured){if(textured)image(material(true),p.x-radius,p.y-radius,radius*2,radius*2);else{circle(p,radius,0xEDF5F7,1,0xA1BDCC,.6);circle(p+V{-radius*.25,radius*.22},radius*.65,0xFFFFFF,.6);}}
void contour(const Surface&s,const Profile&p,Span span,bool textured){
 int n=std::min(480,std::max(1,int(std::ceil((span.hi-span.lo)/4))));std::vector<double>distances;
 for(int i=0;i<=n;i++)distances.push_back(span.lo+(span.hi-span.lo)*i/n);
 if(s.corner>0)for(double t:{0.,.02,.04,.08,.16,.32,.5,.7,.85,1.})for(double x:{s.corner*t,s.width-s.corner*t})if(x>=span.lo&&x<=span.hi)distances.push_back(x);
 std::sort(distances.begin(),distances.end());distances.erase(std::unique(distances.begin(),distances.end()),distances.end());
 std::vector<V>top,base;bool snow=false;for(double x:distances){double h=p.height(x);snow|=h>.00001;top.push_back(s.point(x,h));base.push_back(s.point(x));}if(!snow)return;
 Gdiplus::GraphicsPath path;V current=top.front();bool left=s.corner>0&&span.lo<.001,right=s.corner>0&&span.hi>s.width-.001;
 auto trace=[&](const std::vector<V>&a,bool roundStart,bool roundEnd){
  for(size_t i=1;i<a.size();i++){V previous=a[i-1],end=a[i],middle=(previous+end)*.5;
   if(i==1&&roundStart){V control=previous+(end-previous)*(1./6);path.AddBezier(point(current),point({previous.x,control.y}),point(control),point(middle));}
   else path.AddBezier(point(current),point(current+(previous-current)*(2./3)),point(middle+(previous-middle)*(2./3)),point(middle));current=middle;
  }
  V last=a.back(),previous=a[a.size()-2];if(roundEnd){V control=last-(last-previous)*(1./6);path.AddBezier(point(current),point(control),point({last.x,control.y}),point(last));}
  else path.AddBezier(point(current),point(current+(last-current)*(2./3)),point(last),point(last));current=last;
 };
 trace(top,left,right);path.AddLine(point(current),point(base.back()));current=base.back();
 if(s.corner>0){std::reverse(base.begin(),base.end());trace(base,right,left);}else path.AddLine(point(current),point(base.front()));path.CloseFigure();
 if(textured){Gdiplus::TextureBrush snowBrush(&material(false),Gdiplus::WrapModeTile);g.FillPath(&snowBrush,&path);if(!s.side){Gdiplus::LinearGradientBrush shadow(point({s.left,s.base}),point({s.left,s.base+p.maximum}),color(0x91A7B8,.28),color(0xFFFFFF,0));g.FillPath(&shadow,&path);}}
 else this->path(path,0xFAFAFC,0,0,.97);
}
void terrain(const Simulation&sim,const Settings&s){for(auto&sf:sim.surfaces){auto it=sim.profiles.find(sf.id);if(it!=sim.profiles.end())for(auto span:sf.visible)if(span.hi>span.lo)contour(sf,it->second,span,s.appearance==1);}}
Gdiplus::Bitmap&treeLayer(int layer){return cached(layer,384,580,[&](Painter&p){p.g.TranslateTransform(192,568);p.g.ScaleTransform(2,-2);p.treeArtwork(layer);});}
void tree(const Simulation&sim,const Settings&s,bool reduce,double floorInset=0){
 if(!sim.tree)return;
 const auto saved=floorInset>0?g.Save():0;
 if(floorInset>0)g.SetClip(Gdiplus::RectF(0,REAL(floorInset),REAL(sim.size.x),REAL(sim.size.y-floorInset)),Gdiplus::CombineModeIntersect);
 int index=0;for(auto pose:sim.treePoses(floorInset)){
  for(int layer=0;layer<5;layer++){double alpha=pose.opacity;if(layer>0)alpha*=pose.lights*light(sim.time,layer==4?29+index*11:index*7+(layer-1)*3,s,reduce,true);image(treeLayer(layer),pose.p.x-96*pose.sx,pose.p.y-6*pose.sy,192*pose.sx,290*pose.sy,alpha);}index++;
 }
 if(floorInset>0)g.Restore(saved);
}
static double flakeDiameter(const Particle& particle,const Settings& settings){
 return particle.r*6.6*settings.snowflakeSize;
}
static double flakeAngle(uint64_t id,double time,bool reduce){
 const uint32_t seed=uint32_t(id)*2654435761u;
 const double phase=(seed&65535)*(2*pi/65536.);
 const double speed=(.07+(seed>>24)*(.10/255.))*((seed&1)?-1:1);
 return phase+(reduce?0:time*speed);
}
// The same Windows crystal paths supply the desktop masks and settings previews.
// At small sizes retain one clear silhouette instead of shrinking a detailed image.
void flakeArtwork(int variant,double diameter,double opacity=1){
 const double radius=diameter*.43;
 const double stroke=std::max(1.05,diameter*.048);
 const bool small=diameter<15;
 constexpr uint32_t white=0xFFFFFF;
 auto vertex=[](double angle,double r){return V{std::cos(angle)*r,std::sin(angle)*r};};
 auto ring=[&](double r,double weight){
  std::vector<V> hex;
  for(int i=0;i<=6;i++)hex.push_back(vertex(pi/6+i*pi/3,r));
  line(hex,white,stroke*weight,opacity);
 };
 if(variant==1||variant==5){
  const int tips=variant==1?6:4;
  std::vector<Gdiplus::PointF> points;
  for(int i=0;i<tips*2;i++)
   points.push_back(point(vertex(pi/2+i*pi/tips,radius*(i%2?(variant==1?.37:.21):1))));
  Gdiplus::GraphicsPath shape;
  shape.AddPolygon(points.data(),int(points.size()));
  path(shape,white,white,stroke*.66,opacity*(variant==1?.76:.98));
  return;
 }
 if(variant==2||variant==6){
  ring(radius,1);
  if(variant==6&&!small){
   for(int shift=0;shift<2;shift++){
    const double a=pi/6+shift*pi/3;
    line({vertex(a,radius),vertex(a+2*pi/3,radius),vertex(a+4*pi/3,radius),vertex(a,radius)},
         white,stroke*.72,opacity*.75);
   }
  }else if(!small)ring(radius*.58,.72);
  if(variant==2||small)circle({},stroke*.62,white,opacity*.96);
  return;
 }
 for(int arm=0;arm<6;arm++){
  const double angle=pi/2+arm*pi/3;
  if(variant==4){
   line({{},vertex(angle,radius*.75)},white,stroke,opacity);
   const V center=vertex(angle,radius*.79),side=vertex(angle+pi/2,radius*(small?.20:.15));
   polygon({vertex(angle,radius),center+side,vertex(angle,radius*.56),center-side},white,0,0,opacity*.97);
   continue;
  }
  line({{},vertex(angle,radius)},white,variant==3?stroke*.84:stroke,opacity);
  const int branches=small?1:variant==3?2:3;
  for(int joint=0;joint<branches;joint++){
   const double along=small?.57:.38+joint*.19;
   const double reach=radius*(variant==3?.20:.34)*(1-along*.28);
   const V at=vertex(angle,radius*along);
   line({at+vertex(angle+pi*.32,reach),at,at+vertex(angle-pi*.32,reach)},white,stroke*.82,opacity);
  }
  if(variant==7&&!small)line({{},vertex(angle+pi/6,radius*.53)},white,stroke*.73,opacity*.78);
 }
 circle({},stroke*.58,white,opacity);
}
void flakes(const Simulation& sim,const Settings& settings,bool reduce,bool patternsAlreadyDrawn){
 for(const auto& particle:sim.particles){
  if(particle.scattered||settings.snowflakeStyle==0){
   const double radius=particle.r*(particle.scattered?1:settings.snowflakeSize);
   circle(particle.p,radius*1.25,0xFFFFFF,particle.alpha*.65);
   circle(particle.p,radius*.65,0xFFFFFF,particle.alpha);
  }else if(!patternsAlreadyDrawn){
   auto state=g.Save();
   g.TranslateTransform(REAL(particle.p.x),REAL(particle.p.y));
   g.RotateTransform(REAL(flakeAngle(particle.id,sim.time,reduce)*180/pi));
   flakeArtwork(int(particle.id%8),std::max(6.,flakeDiameter(particle,settings)),particle.alpha);
   g.Restore(state);
  }
 }
}
Gdiplus::Bitmap&glassMark(int variant){return cached(30+variant,192,192,[&](Painter&p){
 p.g.TranslateTransform(96,96);std::vector<Gdiplus::PointF>points;for(int i=0;i<48;i++){double angle=i*2*pi/48,r=43+grain(i,variant,92)*13;if((i+variant*3)%9==0)r+=25;points.push_back(point({std::cos(angle)*r,std::sin(angle)*r}));}
 Gdiplus::GraphicsPath path;path.AddPolygon(points.data(),int(points.size()));Gdiplus::PathGradientBrush snow(&path);Gdiplus::Color white=color(0xFFFFFF),edge=color(0xD6E5E9,.96);snow.SetCenterColor(white);int count=1;snow.SetSurroundColors(&edge,&count);snow.SetCenterPoint(Gdiplus::PointF(-12,14));p.g.FillPath(&snow,&path);
 for(int i=0;i<7;i++){double angle=(i+.3)*2*pi/7+variant*.47,r=75+grain(i,variant)*10;p.ellipse({std::cos(angle)*r,std::sin(angle)*r},2+grain(i,3)*3,3+grain(i,4)*4,0xF6FCFE,.95);}
});}
void glass(const Simulation&sim,const Settings&s){
 for(auto&f:sim.game.flights){double t=clamp(f.age/.24,0,1),ease=1-std::pow(1-t,2);V p=f.start+(f.target-f.start)*ease;sphere(p,f.radius*(1+t*1.2),s.appearance==1);}
 for(auto&m:sim.game.marks){double fade=clamp((5-m.age)/1.5,0,1),size=m.radius*2.8;image(glassMark(m.variant),m.p.x-size/2,m.p.y-size/2,size,size,fade);}
}
