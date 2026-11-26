#pragma once
#include "flake-renderer.hpp"
namespace snow {
inline void previewSnowmen(Painter& painter,double width,double height,bool textured){
 double unit=std::min(width/365.,height/136.);
 for(int i=0;i<4;i++){
  const double x=width*(i+.5)/4, floor=height*.08;
  Ball base,middle,head;
  base.radius=19*unit;middle.radius=14*unit;head.radius=9*unit;
  base.p={x,floor+base.radius};
  middle.p={x,base.p.y+base.radius+middle.radius};
  head.p={x,middle.p.y+middle.radius+head.radius};
  head.snowmanLook=i;
  painter.snowman(base,middle,head,textured);
 }
}
inline std::unique_ptr<Gdiplus::Bitmap> makeSettingsPreview(int width,int height,int section,const Settings& settings){
 auto bitmap=std::make_unique<Gdiplus::Bitmap>(width,height,PixelFormat32bppPARGB);
 Gdiplus::Graphics graphics(bitmap.get());
 Gdiplus::LinearGradientBrush sky(Gdiplus::Point(0,0),Gdiplus::Point(0,height),
   Painter::color(0x14202F),Painter::color(0x34485C));
 graphics.FillRectangle(&sky,0,0,width,height);
 graphics.TranslateTransform(0,REAL(height));
 graphics.ScaleTransform(1,-1);
 Painter painter(graphics);
 Simulation scene({double(width),double(height)},2026);
 if(section==3){
  previewSnowmen(painter,width,height,settings.appearance==1);
 }else if(section==4){
  auto state=graphics.Save();
  graphics.TranslateTransform(REAL(width*.5),REAL(height*.04));
  float scale=REAL(std::min(width/183.,height/110.));
  graphics.ScaleTransform(scale,scale);
  scene.cleaner.start(settings.cleaner);
  painter.tractor(scene.cleaner,true,nullptr);
  graphics.Restore(state);
 }else if(section==5){
  scene.time=2.1;
  painter.garland(scene,settings,false);
 }else if(section==2){
  Surface sample{44,width*.13,height*.46,width*.74,0,false,{{0,width*.74}},10};
  scene.sync(settings.windows?std::vector<Surface>{sample}:std::vector<Surface>{},settings,{44});
  for(auto& entry:scene.profiles)for(double x=0;x<=entry.second.width;x+=5)
   entry.second.deposit(x,35);
  painter.rect(width*.13,0,width*.74,height*.46,0x253545);
  painter.terrain(scene,settings);
 }else{
  int count=section==1?42:settings.weather==0?24:settings.weather==1?43:65;
  for(int i=0;i<count;i++){
   double y=std::fmod(i*.2479+.12,1.)*height;
   double fraction=std::fmod(i*.61803+.11+settings.wind/100.*(.5-y/height)+1,1.);
   V at{fraction*width,y};
   if(section==1&&settings.wind)
    painter.line({at+V{-settings.wind*.115,8},at},0xBACFDC,.8,.45);
   scene.particles.push_back({at,55,0,1.2+(i%4)*.42,.58+(i%3)*.13,120,false,0,0,uint64_t(i+1)});
  }
  painter.flakes(scene,settings,false,false);
 }
 return bitmap;
}
inline void previewDrift(Painter& painter,double x,double y,double width,double height,bool textured,int seed){
 if(height<=0)return;
 Gdiplus::GraphicsPath drift;
 const auto p=[&](double at,double rise){return Painter::point({x+at*width,y+rise*height});};
 drift.AddLine(p(0,0),p(0,.84));
 drift.AddBezier(p(0,.84),p(.38,.23),p(.42,1.35),p(.65,.88));
 drift.AddBezier(p(.65,.88),p(.80,.44),p(.91,.55),p(1,.84));
 drift.AddLine(p(1,.84),p(1,0));drift.CloseFigure();
 painter.path(drift,textured?0xE4E6EE:0xF4F4F7,0xF4F5FA,.9);
 if(!textured)return;
 auto state=painter.g.Save();
 painter.g.SetClip(&drift,Gdiplus::CombineModeIntersect);
 for(int i=0;i<220;i++){
  double px=x+std::fmod((i+seed)*41.731,width),py=y+std::fmod((i+seed)*7.919,height);
  painter.circle({px,py},i%4==0?.65:.45,0xFFFFFF,.24+(i%5)*.08);
 }
 painter.g.Restore(state);
}
inline std::unique_ptr<Gdiplus::Bitmap> makeGraphitePreview(int width,int height,int section,
 const Settings& settings,bool compact,bool trees,size_t displayCount){
 auto canvas=std::make_unique<Gdiplus::Bitmap>(width,height,PixelFormat32bppPARGB);
 Gdiplus::Graphics g(canvas.get());
 g.Clear(Painter::color(0x26272C));
 constexpr double w=280;
 const double h=compact?80:350;
 g.TranslateTransform(0,REAL(height));g.ScaleTransform(REAL(width/w),REAL(-height/h));
 Painter paint(g);
 for(int x=8;x<w;x+=14)for(int y=8;y<h;y+=14)paint.circle({double(x),double(y)},.9,0x54565D,.54);
 const bool textured=settings.appearance==1;
 const double floor=settings.bottom?compact?7:std::min(30.,settings.bottomHeight*.42):0;
 Simulation scene({w,h},2026);
 if(!compact&&section!=3&&section!=4&&section!=7){
  Gdiplus::GraphicsPath window;
  settingsTheme::roundedPath(window,{42,115,196,119},settingsTheme::overlayRadius);
  paint.path(window,0x292B33,0x737681,1);
  paint.rect(43,210,194,.6,0x636570,.7);
  for(int i=0;i<3;i++)paint.circle({56.+12*i,222},3.5,0xA5A8B5);
  if(settings.windows)previewDrift(paint,42,233,196,settings.windowHeight*.52,textured,4);
  if(section==2&&settings.taskbar){
   Gdiplus::GraphicsPath taskbar;
   settingsTheme::roundedPath(taskbar,{67,8,146,28},settingsTheme::overlayRadius);
   paint.path(taskbar,0x484B57,0x8A8D98,.7);
   for(int i=0;i<4;i++){
    Gdiplus::GraphicsPath app;
    settingsTheme::roundedPath(app,{79.f+i*33,14,23,19},settingsTheme::controlRadius);
    paint.path(app,0x747986);
   }
  }
 }
 if(!compact&&section==7){
  int enabled=settings.allDisplays?int(displayCount):int(settings.displays.size());
  int count=std::clamp<int>(int(displayCount),1,2);
  for(int i=0;i<count;i++){
   double x=count==1?140:i==0?83:188,y=count==1?168:i==0?125:194;
   auto tint=i<enabled?0xAFB3C0u:0x656876u;
   Gdiplus::GraphicsPath monitor;
   settingsTheme::roundedPath(monitor,{REAL(x-50),REAL(y-29),100,61},settingsTheme::controlRadius);
   paint.path(monitor,0x51535D,tint,6);
   paint.rect(x-12,y-42,24,11,tint);
   paint.line({{x-15,y-43},{x+15,y-43}},tint,6);
  }
 }
 int count=compact?9:settings.weather==0?24:settings.weather==1?42:72;
 for(int i=0;i<count;i++){
  double x=(i*83+31)%271+4,y=(i*59+21)%int(h-15)+15,alpha=i%3==0?.95:.55;
  if(section==1&&std::abs(settings.wind)>5)
   paint.line({{x,y},{x-settings.wind*.12,y+8}},0xFFFFFF,.7,.13);
  if(settings.snowflakeStyle==1&&i%5==0){
   double d=14*settings.snowflakeSize;
   auto state=g.Save();
   g.TranslateTransform(REAL(x),REAL(y));
   paint.flakeArtwork(i%8,std::max(6.,d),alpha);
   g.Restore(state);
  }else paint.circle({x,y},(i%4==0?1.75:1)*settings.snowflakeSize,0xF7F9FD,alpha);
 }
 if(section==5){
  scene.time=1.5;
  paint.garland(scene,settings,false);
 }
 previewDrift(paint,0,0,w,floor,textured,13);
 if(!compact&&trees){
  scene.growTree(true);
  scene.time=1.5;
  auto state=g.Save();g.TranslateTransform(0,REAL(floor*.3));g.ScaleTransform(1,.61f);
  paint.tree(scene,settings,true);g.Restore(state);
 }
 if(!compact&&section==3){
  const auto ball=[](double y,double radius){Ball b;b.p={140,y};b.radius=radius;return b;};
  auto base=ball(floor+27,30),middle=ball(floor+72,22),head=ball(floor+106,15);
  head.snowmanLook=int(SnowmanVariant::classicBucket);
  paint.snowman(base,middle,head,textured);
 }
 if(!compact&&section==4){
  auto state=g.Save();
  g.TranslateTransform(139.f,REAL(std::max(6.,floor-3)));
  g.ScaleTransform(1.45f,1.1f);
  scene.cleaner.start(settings.cleaner);
  scene.cleaner.x=0;
  paint.tractor(scene.cleaner,true,nullptr);
  g.Restore(state);
 }
 return canvas;
}
inline std::unique_ptr<Gdiplus::Bitmap> makeGarlandSwatch(int width,int height,int style,int palette){
 auto canvas=std::make_unique<Gdiplus::Bitmap>(width,height,PixelFormat32bppPARGB);
 Gdiplus::Graphics g(canvas.get());
 g.Clear(Painter::color(0x111C26));
 g.TranslateTransform(0,REAL(height));g.ScaleTransform(REAL(width/290.),REAL(-height/105.));
 Settings settings;
 settings.garland=1;settings.style=style;settings.palette=palette;
 Simulation simulation({290,65});
 Painter paint(g);paint.garland(simulation,settings,false);
 return canvas;
}
inline bool savePNG(Gdiplus::Bitmap&bitmap,const std::wstring&path){
 UINT count=0,bytes=0;Gdiplus::GetImageEncodersSize(&count,&bytes);std::vector<BYTE>data(bytes);auto*encoders=reinterpret_cast<Gdiplus::ImageCodecInfo*>(data.data());
 if(Gdiplus::GetImageEncoders(count,bytes,encoders)!=Gdiplus::Ok)return false;
 for(UINT i=0;i<count;i++)if(std::wstring(encoders[i].MimeType)==L"image/png")return bitmap.Save(path.c_str(),&encoders[i].Clsid,nullptr)==Gdiplus::Ok;return false;
}
inline bool renderPreviews(const std::wstring&folder){
 CreateDirectoryW(folder.c_str(),nullptr);bool ok=true;
 for(int appearance=0;appearance<2;appearance++){
  Gdiplus::Bitmap bitmap(1280,480,PixelFormat32bppPARGB);
  {Gdiplus::Graphics graphics(&bitmap);graphics.Clear(Painter::color(0x183344));graphics.TranslateTransform(0,480);graphics.ScaleTransform(1,-1);Painter p(graphics);
   Settings settings;settings.appearance=appearance;settings.snowflakeStyle=1;settings.snowflakeSize=1.5;settings.garland=2;settings.style=2;
   Simulation sim({1280,480},2026);Surface window{44,100,260,1080,0,false,{{0,1080}},12};sim.sync({window},settings,{44});
   for(auto&entry:sim.profiles)for(double x=0;x<=entry.second.width;x+=4)entry.second.deposit(x,200);
   sim.growTree(true);sim.time=1;double x=400,h=sim.profiles.at(bottomID).height(x);
   sim.game.balls={{1,bottomID,0,33,x,h+33,{x,h+33},{}},{2,bottomID,1,24,x,h+90,{x,h+90},{}},{3,bottomID,2,17,x,h+131,{x,h+131},{}}};
   SnowmanCycle previewCycle(0);sim.game.updateSnowmen(previewCycle);
   for(int i=0;i<48;i++)sim.particles.push_back({{24+std::fmod(i*147.7,1230.),190+std::fmod(i*47.2,260.)},55,0,1.4+(i%4)*.4,.7,120,false,0,0,uint64_t(i+1)});
   sim.cleaner.start(1);sim.cleaner.x=850;sim.cleaner.distance=80;sim.cleaner.collected=700;sim.game.marks.push_back({{760,365},30,0,3});p.draw(sim,settings,false);
  }ok=savePNG(bitmap,folder+(appearance?L"\\overview-textured.png":L"\\overview-simple.png"))&&ok;
 }
 {Gdiplus::Bitmap bitmap(384,580,PixelFormat32bppPARGB);{Gdiplus::Graphics g(&bitmap);g.Clear(Gdiplus::Color(0,0,0,0));g.TranslateTransform(0,580);g.ScaleTransform(1,-1);Painter p(g);for(int layer=0;layer<5;layer++)p.image(p.treeLayer(layer),0,0,384,580);}ok=savePNG(bitmap,folder+L"\\tree-vector.png")&&ok;}
 {Gdiplus::Bitmap bitmap(1024,160,PixelFormat32bppPARGB);{Gdiplus::Graphics g(&bitmap);g.Clear(Painter::color(0x183344));g.TranslateTransform(0,160);g.ScaleTransform(1,-1);Painter p(g);for(int i=0;i<8;i++){auto state=g.Save();g.TranslateTransform(REAL(i*128+64),80.f);p.flakeArtwork(i,96);g.Restore(state);}}ok=savePNG(bitmap,folder+L"\\snowflakes.png")&&ok;}
 {
  constexpr int cell=68,width=cell*8,height=cell*3;
  std::vector<uint32_t> pixels(size_t(width)*height,0xff1b2531u);
  PatternedFlakes patterns;
  for(int row=0;row<3;row++){
   Settings settings;
   settings.snowflakeSize=std::array<double,3>{.5,1,3}[row];
   Simulation sim({width,height});
   for(int i=0;i<8;i++)
    sim.particles.push_back({{(i+.5)*cell,height-(row+.5)*cell},55,0,2,.90,120,false,0,0,uint64_t(i)});
   patterns.draw(pixels.data(),width,height,1,sim,settings,true);
  }
  Gdiplus::Bitmap bitmap(width,height,width*4,PixelFormat32bppPARGB,reinterpret_cast<BYTE*>(pixels.data()));
  ok=savePNG(bitmap,folder+L"\\snowflakes-native.png")&&ok;
 }
 {Gdiplus::Bitmap bitmap(720,720,PixelFormat32bppPARGB);{Gdiplus::Graphics g(&bitmap);g.Clear(Painter::color(0x71818D));g.TranslateTransform(0,720);g.ScaleTransform(1,-1);Painter p(g);for(int i=0;i<9;i++)p.image(p.glassMark(i),(i%3)*240+24,(i/3)*240+24,192,192);}ok=savePNG(bitmap,folder+L"\\glass-impacts.png")&&ok;}
 for(int material=0;material<2;material++){
  Settings settings;settings.appearance=material;
  auto bitmap=makeSettingsPreview(960,330,3,settings);
  ok=savePNG(*bitmap,folder+(material?L"\\snowmen-textured.png":L"\\snowmen-simple.png"))&&ok;
 }
 return ok;
}
} // namespace snow
