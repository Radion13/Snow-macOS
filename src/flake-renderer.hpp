#pragma once
#include "drawing.hpp"
#include <array>

namespace snow {
// Windows' layered window already owns a premultiplied BGRA surface. Sampling
// cached supersampled coverage into that surface avoids a GDI+ image transform
// for every flake and preserves fractional positions and continuous rotation.
class PatternedFlakes {
 static constexpr int maxMaskDiameter=96,oversampling=2,unit=256;
 struct Mask {
  int width=0;
  std::vector<BYTE> alpha;
 };
 std::array<std::array<Mask,maxMaskDiameter+1>,8> masks;

 const Mask& mask(int variant,int diameter){
  auto& entry=masks[variant][diameter];
  if(entry.width)return entry;
  const int width=(diameter+4)*oversampling;
  Gdiplus::Bitmap bitmap(width,width,PixelFormat32bppPARGB);
  {
   Gdiplus::Graphics graphics(&bitmap);
   graphics.Clear(Gdiplus::Color(0,0,0,0));
   graphics.TranslateTransform(REAL(width)*.5f,REAL(width)*.5f);
   graphics.ScaleTransform(REAL(oversampling),-REAL(oversampling));
   Painter paint(graphics);
   paint.flakeArtwork(variant,diameter);
  }
  Gdiplus::Rect area(0,0,width,width);
  Gdiplus::BitmapData pixels{};
  if(bitmap.LockBits(&area,Gdiplus::ImageLockModeRead,PixelFormat32bppPARGB,&pixels)!=Gdiplus::Ok)return entry;
  entry.alpha.resize(size_t(width)*width);
  const auto* data=static_cast<const BYTE*>(pixels.Scan0);
  for(int y=0;y<width;y++)for(int x=0;x<width;x++)
   entry.alpha[size_t(y)*width+x]=data[y*pixels.Stride+x*4+3];
  bitmap.UnlockBits(&pixels);
  entry.width=width;
  return entry;
 }

 static uint32_t blend(uint32_t previous,unsigned alpha){
  if(!previous)return alpha*0x01010101u;
  const unsigned inverse=255-alpha;
  uint32_t result=0;
  for(unsigned shift=0;shift<32;shift+=8){
   const unsigned channel=(previous>>shift)&255;
   result|=(alpha+(channel*inverse+127)/255)<<shift;
  }
  return result;
 }

 void drawFlake(uint32_t* pixels,int width,int height,V center,double diameter,double angle,
                double opacity,int variant,const RECT* exclusions,size_t exclusionCount){
  const double extent=diameter*.5+1;
  const int left=std::max(0,int(std::floor(center.x-extent)));
  const int right=std::min(width,int(std::ceil(center.x+extent)));
  const int top=std::max(0,int(std::floor(center.y-extent)));
  const int bottom=std::min(height,int(std::ceil(center.y+extent)));
  if(left>=right||top>=bottom)return;

  std::array<const RECT*,2> clips{};
  size_t intersections=0;
  for(size_t i=0;i<exclusionCount;i++){
   const auto& rect=exclusions[i];
   if(right<=rect.left||left>=rect.right||bottom<=rect.top||top>=rect.bottom)continue;
   if(left>=rect.left&&right<=rect.right&&top>=rect.top&&bottom<=rect.bottom)return;
   clips[intersections++]=&rect;
  }
  const int nativeSize=std::min(maxMaskDiameter,2*int(std::lround(diameter*.5)));
  const auto& source=mask(variant,nativeSize);
  if(!source.width)return;
  const int stride=source.width,limit=(stride-1)*unit;
  const int alpha=int(std::lround(clamp(opacity,0,1)*255));
  const double scale=oversampling*nativeSize/diameter*unit;
  const double cosine=std::cos(angle)*scale,sine=std::sin(angle)*scale;
  const int du=int(std::lround(cosine)),dv=int(std::lround(sine));
  const double cx=left+.5-center.x,cy=top+.5-center.y,origin=(stride-1)*unit*.5;
  int rowU=int(std::lround(origin+cx*cosine-cy*sine));
  int rowV=int(std::lround(origin+cx*sine+cy*cosine));
  for(int y=top;y<bottom;y++,rowU-=dv,rowV+=du){
   auto* row=pixels+size_t(y)*width;
   int u=rowU,v=rowV;
   for(int x=left;x<right;x++,u+=du,v+=dv){
    if(u<0||v<0||u>=limit||v>=limit)continue;
    const int duFraction=u&(unit-1),dvFraction=v&(unit-1);
    const BYTE* sample=source.alpha.data()+size_t(v/unit)*stride+u/unit;
    const int upper=sample[0]*(unit-duFraction)+sample[1]*duFraction;
    const int lower=sample[stride]*(unit-duFraction)+sample[stride+1]*duFraction;
    const int coverage=(upper*(unit-dvFraction)+lower*dvFraction+unit*unit/2)/(unit*unit);
    const unsigned amount=unsigned((coverage*alpha+127)/255);
    if(!amount)continue;
    if(intersections&&std::any_of(clips.begin(),clips.begin()+intersections,[&](const RECT* rect){
     return x>=rect->left&&x<rect->right&&y>=rect->top&&y<rect->bottom;
    }))continue;
    row[x]=blend(row[x],amount);
   }
  }
 }

public:
 void draw(uint32_t* pixels,int width,int height,double dpi,const Simulation& sim,
           const Settings& settings,bool reduced,const RECT* exclusions=nullptr,size_t exclusionCount=0){
  for(const auto& particle:sim.particles){
   if(particle.scattered)continue;
   drawFlake(pixels,width,height,{particle.p.x*dpi,height-particle.p.y*dpi},
             std::max(6.,Painter::flakeDiameter(particle,settings)*dpi),
             Painter::flakeAngle(particle.id,sim.time,reduced),particle.alpha,
             int(particle.id%masks.size()),exclusions,exclusionCount);
  }
 }
};
}
