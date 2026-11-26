#pragma once
#define NOMINMAX
#include <windows.h>
#include <gdiplus.h>
#include <memory>
#include "core.hpp"

namespace snow {
using Gdiplus::REAL;
struct Painter {
 Gdiplus::Graphics&g;
 static std::map<uint32_t,std::unique_ptr<Gdiplus::Bitmap>>&haloCache(){static std::map<uint32_t,std::unique_ptr<Gdiplus::Bitmap>> cache;return cache;}
 static void clearCache(){haloCache().clear();artCache().clear();}
 explicit Painter(Gdiplus::Graphics&graphics):g(graphics){g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);g.SetCompositingQuality(Gdiplus::CompositingQualityHighSpeed);}
 static Gdiplus::Color color(uint32_t rgb,double a=1){return Gdiplus::Color(BYTE(clamp(a,0,1)*255),BYTE(rgb>>16),BYTE(rgb>>8),BYTE(rgb));}
 static Gdiplus::PointF point(V v){return{REAL(v.x),REAL(v.y)};}
 void circle(V p,double r,uint32_t c,double alpha=1,uint32_t outline=0,double line=0){Gdiplus::SolidBrush b(color(c,alpha));g.FillEllipse(&b,REAL(p.x-r),REAL(p.y-r),REAL(r*2),REAL(r*2));if(line){Gdiplus::Pen pen(color(outline,alpha),REAL(line));g.DrawEllipse(&pen,REAL(p.x-r),REAL(p.y-r),REAL(r*2),REAL(r*2));}}
 void ellipse(V p,double rx,double ry,uint32_t c,double alpha=1){Gdiplus::SolidBrush b(color(c,alpha));g.FillEllipse(&b,REAL(p.x-rx),REAL(p.y-ry),REAL(2*rx),REAL(2*ry));}
 void rect(double x,double y,double w,double h,uint32_t c,double alpha=1){Gdiplus::SolidBrush b(color(c,alpha));g.FillRectangle(&b,REAL(x),REAL(y),REAL(w),REAL(h));}
 void path(Gdiplus::GraphicsPath&p,uint32_t c,uint32_t stroke=0,double width=0,double alpha=1){Gdiplus::SolidBrush b(color(c,alpha));g.FillPath(&b,&p);if(width){Gdiplus::Pen pen(color(stroke,alpha),REAL(width));pen.SetLineJoin(Gdiplus::LineJoinRound);g.DrawPath(&pen,&p);}}
 void polygon(std::initializer_list<V> points,uint32_t c,uint32_t outline=0,double width=0,double alpha=1){Gdiplus::GraphicsPath p;std::vector<Gdiplus::PointF> a;for(auto v:points)a.push_back(point(v));p.AddPolygon(a.data(),int(a.size()));path(p,c,outline,width,alpha);}
 void line(const std::vector<V>&a,uint32_t c,double width=1,double alpha=1){if(a.size()<2)return;Gdiplus::Pen pen(color(c,alpha),REAL(width));pen.SetStartCap(Gdiplus::LineCapRound);pen.SetEndCap(Gdiplus::LineCapRound);pen.SetLineJoin(Gdiplus::LineJoinRound);std::vector<Gdiplus::PointF>b;for(auto v:a)b.push_back(point(v));g.DrawLines(&pen,b.data(),int(b.size()));}
 void image(Gdiplus::Image&image,double x,double y,double w,double h,double alpha=1){
  auto state=g.Save();g.TranslateTransform(REAL(x),REAL(y+h));g.ScaleTransform(1,-1);
  Gdiplus::ImageAttributes attr;Gdiplus::ColorMatrix matrix={{{1,0,0,0,0},{0,1,0,0,0},{0,0,1,0,0},{0,0,0,REAL(alpha),0},{0,0,0,0,1}}};attr.SetColorMatrix(&matrix);
  g.DrawImage(&image,Gdiplus::RectF(0,0,REAL(w),REAL(h)),0,0,REAL(image.GetWidth()),REAL(image.GetHeight()),Gdiplus::UnitPixel,&attr);g.Restore(state);
 }
 void halo(V p,double r,uint32_t c,double alpha=1){
  auto&cache=haloCache();
  auto&bmp=cache[c];if(!bmp){bmp=std::make_unique<Gdiplus::Bitmap>(64,64,PixelFormat32bppPARGB);Gdiplus::BitmapData data;Gdiplus::Rect rc(0,0,64,64);bmp->LockBits(&rc,Gdiplus::ImageLockModeWrite,PixelFormat32bppPARGB,&data);for(int y=0;y<64;y++)for(int x=0;x<64;x++){double d=std::hypot(x-31.5,y-31.5)/32,a=std::exp(-d*d*6)*std::max(0.,1-d)*.85;BYTE*pixel=(BYTE*)data.Scan0+y*data.Stride+x*4;pixel[0]=BYTE((c&255)*a);pixel[1]=BYTE(((c>>8)&255)*a);pixel[2]=BYTE(((c>>16)&255)*a);pixel[3]=BYTE(a*255);}bmp->UnlockBits(&data);}
  image(*bmp,p.x-r,p.y-r,r*2,r*2,alpha);
 }
 void star(V center,double radius,uint32_t c,double alpha=1){std::vector<Gdiplus::PointF>a;for(int i=0;i<10;i++){double angle=pi/2+i*pi/5,r=radius*(i%2?.45:1);a.push_back(point({center.x+std::cos(angle)*r,center.y+std::sin(angle)*r}));}Gdiplus::GraphicsPath p;p.AddPolygon(a.data(),10);path(p,c,0,0,alpha);}
 #include "tree-vector.inc"
 #include "effects-drawing.inc"
 void wheel(V center,double radius,bool retro,double distance,bool reduce){auto state=g.Save();g.TranslateTransform(REAL(center.x),REAL(center.y));if(!reduce)g.RotateTransform(REAL(-distance/radius*180/pi));uint32_t dark=retro?0x202634:0x29495D;circle({},radius,retro?0x8991B5:0x2D4F64,1,dark,retro?3:1);int n=retro?10:22;
  for(int i=0;i<n;i++){double angle=i*2*pi/n;auto st=g.Save();g.TranslateTransform(REAL(std::cos(angle)*(radius-1.6)),REAL(std::sin(angle)*(radius-1.6)));g.RotateTransform(REAL(angle*180/pi));rect(-2.6,-1.5,retro?6:4.7,3,retro?dark:0x3B6075);g.Restore(st);}
  circle({},radius*.58,retro?0x717B9E:0xE0E8EB,1,dark,retro?2.8:.7);for(int i=0;i<4;i++){double a=i*pi/2+.3;circle({std::cos(a)*radius*.39,std::sin(a)*radius*.39},std::max(1.,radius*.055),i==0?0xE8B46B:retro?0xCFD4E7:0x9AAFB9);}circle({},radius*.22,retro?0xE9E8EE:dark,1,dark,retro?2.4:0);g.Restore(state);
 }
 void tractor(const Cleaner&m,bool reduce,Gdiplus::Image*badge){if(!m.active)return;auto state=g.Save();g.TranslateTransform(REAL(m.x),0);bool retro=m.character==1;uint32_t paint=retro?0xEF627B:0xE96756,dark=retro?0x202634:0x2C4757;double border=retro?2.7:0;
  rect(21,57,5,25,dark);if(retro){line({{22,57},{22,85},{25,92},{37,100}},dark,8);line({{22,57},{22,85},{25,92},{37,100}},0xB8BDD0,3.8);rect(17.5,59,9,22,0x7E89AB);}else rect(18,79,11,5,0x3C5D70);
  polygon({{-48,15},{53,15},{55,34},{7,40},{-44,38}},dark);
  Gdiplus::GraphicsPath hood;hood.AddLine(-4,24,-4,58);hood.AddBezier(-4,58,21,61,45,58,52,47);hood.AddBezier(52,47,57,44,56,32,56,25);hood.AddLine(56,25,37,17);hood.CloseFigure();path(hood,paint,dark,border);
  polygon({{-35,43},{-31,91},{-4,91},{6,42}},retro?0xC4DCE6:0x3B5C70,retro?dark:0xF8D16A,retro?3:2.7);
  if(retro){line({{-18,43},{-18,90}},dark,4);line({{-18,44},{-18,90}},paint,2);line({{-29,54},{-7,80}},0xFFFFFF,1.6,.5);for(double x:{14.,25.})line({{x,44},{x+2.2,39}},dark,2.7);}else polygon({{-28,86},{-20,86},{-24,46},{-31,46}},0xFFFFFF,0,0,.12);
  Gdiplus::GraphicsPath roof;roof.AddBezier(-38,91,-39,98,-28,99,-14,99);roof.AddBezier(-14,99,1,99,5,98,6,91);roof.CloseFigure();path(roof,retro?0xE5E6F0:paint,dark,border);
  if(!retro)polygon({{41,46},{51,42},{51,27},{41,29}},0x3C5D70);
  line({{8,24},{53,39},{72,17}},dark,5);line({{26,26},{61,22}},0xD3DCE0,2.4);for(V p:{V{11,25},V{53,39},V{70,18}})circle(p,2.6,0xE2BC69);
  wheel({-29,26},26,retro,m.distance,reduce);wheel({40,17},17,retro,m.distance,reduce);
  Gdiplus::GraphicsPath fender;fender.AddBezier(-56,40,-44,65,-11,63,-2,29);if(retro){Gdiplus::Pen pen(color(dark),9);pen.SetStartCap(Gdiplus::LineCapRound);pen.SetEndCap(Gdiplus::LineCapRound);g.DrawPath(&pen,&fender);}Gdiplus::Pen pen(color(paint),REAL(retro?4.5:6));pen.SetStartCap(Gdiplus::LineCapRound);pen.SetEndCap(Gdiplus::LineCapRound);g.DrawPath(&pen,&fender);
  polygon({{59,11},{65,1},{90,1},{98,30},{90,32},{80,12}},retro?0xB0B5CA:0xB2C8D1,dark,retro?2.7:1.2);line({{66,4},{88,4},{95,29}},0xE9F0F2,1.7);
  if(badge)image(*badge,70,3,14,9);
  if(m.load()>0){auto st=g.Save();g.TranslateTransform(76,12);g.ScaleTransform(1,REAL(.25+m.load()*.75));Gdiplus::GraphicsPath load;load.AddBezier(-12,0,-10,16,6,18,12,1);load.CloseFigure();path(load,0xF1F7F9);g.Restore(st);}g.Restore(state);
 }
 static std::vector<uint32_t> palette(int p){if(p==0)return{0xFFD15E,0xFFAA55,0xFFECAE,0xFFF1CE,0xF6C06A};if(p==2)return{0x658EFF,0x68E8F0,0xE9FAFF,0x8EC9FF,0xB2B4FA};return{0xFF493A,0x89EE36,0xFFD23D,0x55DFFF,0xCE6DFF};}
 void garland(const Simulation&sim,const Settings&s,bool reduce){if(!s.garland)return;auto colors=palette(s.palette);double w=sim.size.x,h=sim.size.y;
  if(s.style==1){int spans=std::max(1,int(std::round(w/280)));for(int k=0;k<spans;k++){double left=w*k/spans,right=w*(k+1)/spans;std::vector<V>wire;for(int i=0;i<=40;i++){double t=i/40.;wire.push_back({left+(right-left)*t,h-12-35*std::sin(pi*t)});}line(wire,0xEEEEEE,1,.9);for(int i=0;i<=6;i++){double t=i/6.;V q={left+(right-left)*t,h-12-35*std::sin(pi*t)};bool large=i==0||i==6;q.y-=large?0:10;uint32_t c=colors[(k+i)%colors.size()];double a=light(sim.time,k*7+i,s,reduce);halo(q,large?28:15,c,a);star(q,large?16:8,c,a);}}return;}
  int wires=s.style==0?3:2;for(int row=0;row<wires;row++){auto at=[&](double t){double sag=s.style==0?(22+12*std::sin(t*pi*6+row*2.1)):(30+8*std::sin(t*pi*4+row*2));return V{w*t,h-2-std::sin(pi*t)*sag};};std::vector<V>a;for(int i=0;i<=160;i++)a.push_back(at(i/160.));line(a,s.style==0?0x4F9984:0xEEEEEE,s.style==0?1.5:1,.9);int n=std::min(170,std::max(2,int(w/(s.style==0?68:80))));for(int i=0;i<n;i++){V q=at((i+.5)/n);bool up=(i+row)%2==0;q.y+=up?7:-9;uint32_t c=colors[(i+row*2)%colors.size()];double alpha=light(sim.time,row*n+i,s,reduce);halo(q,s.style==0?14:27,c,alpha);ellipse(q,s.style==0?2.7:2.2,s.style==0?7:5.5,c,alpha);ellipse(q+V{-.2,.2},.8,4,0xFFFFFF,alpha*.85);}}
 }
 void draw(const Simulation&sim,const Settings&s,bool reduce,Gdiplus::Image*badge=nullptr){flakes(sim,s,reduce);tree(sim,s,reduce);terrain(sim,s);balls(sim,s);tractor(sim.cleaner,reduce,nullptr);garland(sim,s,reduce);glass(sim,s);(void)badge;}
};
} // namespace snow
