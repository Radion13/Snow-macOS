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
void balls(const Simulation&sim,const Settings&s){
 std::set<uint64_t>heads;for(auto ids:sim.game.snowmen())heads.insert(ids.back());
 for(auto&b:sim.game.balls)if(sim.game.visible(b,sim.surfaces))sphere(b.p,b.radius,s.appearance==1);
 for(auto&b:sim.game.balls)if(heads.count(b.id)&&sim.game.visible(b,sim.surfaces)){
  double r=b.radius;auto state=g.Save();g.TranslateTransform(REAL(b.p.x),REAL(b.p.y));
  if(s.appearance==1){line({{-r*.72,-r*.88},{r*.72,-r*.88}},0xBD343B,r*.27);rect(-r*.36,-r*1.65,r*.28,r*.82,0xD43F46);rect(-r*.36,-r*1.43,r*.28,r*.06,0xF3D7C8);rect(-r*.36,-r*1.57,r*.28,r*.06,0xF3D7C8);}
  for(double x:{-.28,.28})circle({x*r,.25*r},std::max(1.4,r*.08),0x293F4A);
  polygon({{-r*.06,r*.06},{r*.82,-r*.04},{-r*.06,-r*.23}},0xDA833C);
  for(double x:{-.32,-.16,0.,.16,.32})circle({x*r,r*(-.44+std::abs(x)*.3125)},std::max(.8,r*.055),0x293F4A);
  g.TranslateTransform(0,REAL(r*.78));g.RotateTransform(-5.7f);
  Gdiplus::GraphicsPath handle;handle.AddBezier(point({-r*.50,r*.76}),point({-r*1.03,r*1.05}),point({-r*1.08,r*.08}),point({-r*.62,r*.10}));Gdiplus::Pen pen(color(0x405B6B),1);g.DrawPath(&pen,&handle);
  polygon({{-r*.82,0},{r*.82,0},{r*.58,r*.95},{-r*.58,r*.95}},0x809EAE,0x405B6B,.8);
  polygon({{-r*.62,r*.12},{-r*.32,r*.12},{-r*.27,r*.82},{-r*.45,r*.82}},0xCEE0E6);rect(-r*.9,-r*.04,r*1.8,std::max(2.,r*.13),0xB3CAD4);g.Restore(state);
 }
}
Gdiplus::Bitmap&treeLayer(int layer){return cached(layer,384,580,[&](Painter&p){p.g.TranslateTransform(192,568);p.g.ScaleTransform(2,-2);p.treeArtwork(layer);});}
void tree(const Simulation&sim,const Settings&s,bool reduce){
 int index=0;for(auto pose:sim.treePoses()){
  for(int layer=0;layer<5;layer++){double alpha=pose.opacity;if(layer>0)alpha*=pose.lights*light(sim.time,layer==4?29+index*11:index*7+(layer-1)*3,s,reduce,true);image(treeLayer(layer),pose.p.x-96*pose.sx,pose.p.y-6*pose.sy,192*pose.sx,290*pose.sy,alpha);}index++;
 }
}
Gdiplus::Bitmap&flake(int variant){return cached(10+variant,192,192,[&](Painter&p){
 p.g.TranslateTransform(96,96);auto ray=[&](double a,double r){return V{std::cos(a)*r,std::sin(a)*r};};
 if(variant==5){for(int i=0;i<4;i++)p.polygon({{},ray(i*pi/2-.10,18),ray(i*pi/2,83),ray(i*pi/2+.10,18)},0xF5FBFF,.0,0,.96);return;}
 if(variant==2||variant==6){for(double radius:{75.,51.,27.}){std::vector<V>v;for(int i=0;i<=6;i++)v.push_back(ray(pi/6+i*pi/3,radius));p.line(v,0xF2FAFF,2,.85);}if(variant==2){p.circle({},4,0xFFFFFF);return;}}
 if(variant==1){std::vector<Gdiplus::PointF>points;for(int i=0;i<12;i++)points.push_back(point(ray(pi/2+i*pi/6,i%2?27:78)));Gdiplus::GraphicsPath shape;shape.AddPolygon(points.data(),int(points.size()));p.path(shape,0xEAF6FF,0xFFFFFF,2,.62);}
 for(int i=0;i<6;i++){
  double angle=pi/2+i*pi/3;V end=ray(angle,77);p.line({{},end},0xF3FAFF,variant==3?1.5:2.4,.95);
  if(variant==4){auto state=p.g.Save();p.g.TranslateTransform(REAL(end.x*.8),REAL(end.y*.8));p.g.RotateTransform(REAL(angle*180/pi));p.polygon({{12,0},{0,7},{-12,0},{0,-7}},0xE7F5FF,0xFFFFFF,1,.8);p.g.Restore(state);}
  else if(variant!=1&&variant!=6){for(double t:{.36,.60,.78}){V at=end*t;double branch=(variant==7?14:18)*(1-t*.4);p.line({at+ray(angle+pi*.73,branch),at,at+ray(angle-pi*.73,branch)},0xF3FAFF,variant==3?1.4:2,.9);}}
 }p.circle({},3.5,0xFFFFFF);
});}
void flakes(const Simulation&sim,const Settings&s,bool reduce){for(auto&p:sim.particles){
 if(p.scattered||s.snowflakeStyle==0){double r=p.r*(p.scattered?1:s.snowflakeSize);circle(p.p,r*1.25,0xFFFFFF,p.alpha*.65);circle(p.p,r*.65,0xFFFFFF,p.alpha);}
 else{double side=p.r*4.4*s.snowflakeSize;auto state=g.Save();g.TranslateTransform(REAL(p.p.x),REAL(p.p.y));g.RotateTransform(REAL((p.id*2.399963+(reduce?0:sim.time*.13))*180/pi));image(flake(int(p.id%8)),-side/2,-side/2,side,side,p.alpha);g.Restore(state);}
}}
Gdiplus::Bitmap&glassMark(int variant){return cached(30+variant,192,192,[&](Painter&p){
 p.g.TranslateTransform(96,96);std::vector<Gdiplus::PointF>points;for(int i=0;i<48;i++){double angle=i*2*pi/48,r=43+grain(i,variant,92)*13;if((i+variant*3)%9==0)r+=25;points.push_back(point({std::cos(angle)*r,std::sin(angle)*r}));}
 Gdiplus::GraphicsPath path;path.AddPolygon(points.data(),int(points.size()));Gdiplus::PathGradientBrush snow(&path);Gdiplus::Color white=color(0xFFFFFF),edge=color(0xD6E5E9,.96);snow.SetCenterColor(white);int count=1;snow.SetSurroundColors(&edge,&count);snow.SetCenterPoint(Gdiplus::PointF(-12,14));p.g.FillPath(&snow,&path);
 for(int i=0;i<7;i++){double angle=(i+.3)*2*pi/7+variant*.47,r=75+grain(i,variant)*10;p.ellipse({std::cos(angle)*r,std::sin(angle)*r},2+grain(i,3)*3,3+grain(i,4)*4,0xF6FCFE,.95);}
});}
void glass(const Simulation&sim,const Settings&s){
 for(auto&f:sim.game.flights){double t=clamp(f.age/.24,0,1),ease=1-std::pow(1-t,2);V p=f.start+(f.target-f.start)*ease;sphere(p,f.radius*(1+t*1.2),s.appearance==1);}
 for(auto&m:sim.game.marks){double fade=clamp((5-m.age)/1.5,0,1),size=m.radius*2.8;image(glassMark(m.variant),m.p.x-size/2,m.p.y-size/2,size,size,fade);}
}
