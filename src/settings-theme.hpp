#pragma once

namespace snow::settingsTheme {
inline constexpr COLORREF background=RGB(18,18,20), sidebar=RGB(23,23,25);
inline constexpr COLORREF foreground=RGB(248,248,250), secondary=RGB(180,183,193);
inline constexpr COLORREF muted=RGB(106,108,117), line=RGB(57,57,60), ink=RGB(26,27,30);
inline constexpr int controlRadius=4, overlayRadius=8;
inline constexpr int switchWidth=40,switchHeight=20,switchThumb=12;
inline constexpr int sliderTrack=4,sliderHandle=18;
enum Corner : unsigned {
 topLeft=1,topRight=2,bottomRight=4,bottomLeft=8,
 allCorners=topLeft|topRight|bottomRight|bottomLeft
};

class ControlBuffer {
 HDC target, memory=nullptr;
 HBITMAP bitmap=nullptr;
 HGDIOBJ previous=nullptr;
 RECT bounds;
public:
 ControlBuffer(HDC dc,RECT rect):target(dc),bounds(rect){
  if(rect.right<=rect.left||rect.bottom<=rect.top)return;
  memory=CreateCompatibleDC(target);
  if(!memory)return;
  bitmap=CreateCompatibleBitmap(target,rect.right-rect.left,rect.bottom-rect.top);
  if(!bitmap)return;
  previous=SelectObject(memory,bitmap);
 }
 ControlBuffer(const ControlBuffer&)=delete;
 ControlBuffer& operator=(const ControlBuffer&)=delete;
 HDC dc()const{return bitmap?memory:target;}
 ~ControlBuffer(){
  if(bitmap){
   BitBlt(target,bounds.left,bounds.top,bounds.right-bounds.left,bounds.bottom-bounds.top,
          memory,0,0,SRCCOPY);
   SelectObject(memory,previous);
   DeleteObject(bitmap);
  }
  if(memory)DeleteDC(memory);
 }
};

inline Gdiplus::Color color(COLORREF value){
 return Gdiplus::Color(255,GetRValue(value),GetGValue(value),GetBValue(value));
}

inline Gdiplus::RectF frame(RECT rect,float inset=.5f){
 return {rect.left+inset,rect.top+inset,rect.right-rect.left-2*inset,rect.bottom-rect.top-2*inset};
}

inline void roundedPath(Gdiplus::GraphicsPath& path,Gdiplus::RectF rect,float radius,unsigned corners=allCorners){
 if(rect.Width<=0||rect.Height<=0)return;
 const float r=std::min({radius,rect.Width*.5f,rect.Height*.5f});
 if(r<=0||!corners){path.AddRectangle(rect);return;}
 const float x=rect.X,y=rect.Y,right=rect.GetRight(),bottom=rect.GetBottom(),d=r*2;
 const float tl=(corners&topLeft)?r:0,tr=(corners&topRight)?r:0;
 const float bl=(corners&bottomLeft)?r:0,br=(corners&bottomRight)?r:0;
 path.StartFigure();
 path.AddLine(x+tl,y,right-tr,y);
 if(tr)path.AddArc(right-d,y,d,d,270.f,90.f);
 path.AddLine(right,y+tr,right,bottom-br);
 if(br)path.AddArc(right-d,bottom-d,d,d,0.f,90.f);
 path.AddLine(right-br,bottom,x+bl,bottom);
 if(bl)path.AddArc(x,bottom-d,d,d,90.f,90.f);
 path.AddLine(x,bottom-bl,x,y+tl);
 if(tl)path.AddArc(x,y,d,d,180.f,90.f);
 path.CloseFigure();
}

inline void solidSurface(Gdiplus::Graphics& g,Gdiplus::RectF rect,float radius,uint32_t fill,
                         uint32_t border=0,unsigned corners=allCorners){
 Gdiplus::GraphicsPath path;
 roundedPath(path,rect,radius,corners);
 Gdiplus::SolidBrush brush(Painter::color(fill));
 g.FillPath(&brush,&path);
 if(border){
  Gdiplus::Pen pen(Painter::color(border),1.f);
  g.DrawPath(&pen,&path);
 }
}

inline void surface(Gdiplus::Graphics& graphics,Gdiplus::RectF frame,float radius,
                    bool selected=false,bool disabled=false,bool pressed=false,bool stroke=true,unsigned corners=allCorners){
 if(frame.Width<=0||frame.Height<=0)return;
 Gdiplus::GraphicsPath path;
 roundedPath(path,frame,radius,corners);
 auto top=Painter::color(disabled?0x29292C:selected?(pressed?0xB0B5C5:0xC1C5D2):pressed?0x45464A:0x393939);
 auto bottom=Painter::color(disabled?0x232326:selected?(pressed?0x797F91:0x858B9D):pressed?0x323337:0x282828);
 Gdiplus::LinearGradientBrush brush(frame,top,bottom,selected?18.f:90.f);
 graphics.FillPath(&brush,&path);
 if(stroke){
  Gdiplus::Pen border(Painter::color(disabled?0x404045:selected?0xC6C9D4:0x606060),.9f);
  graphics.DrawPath(&border,&path);
 }
}

inline void surface(HDC dc,RECT r,float radius,bool selected=false,bool disabled=false,bool pressed=false){
 Gdiplus::Graphics graphics(dc);
 graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
 surface(graphics,frame(r),radius,selected,disabled,pressed);
}

inline void toggle(Gdiplus::Graphics& g,Gdiplus::RectF track,float thumb,bool on,bool disabled,bool focused){
 solidSurface(g,track,track.Height*.5f,on?(disabled?0x575962:focused?0xD3D7E4:0xB8BECE):0x29292E,
              on?0u:disabled?0x4D4E55:focused?0xAAAAAF:0x888A93);
 const float gap=(track.Height-thumb)*.5f;
 const float x=on?track.GetRight()-gap-thumb:track.X+gap;
 Gdiplus::SolidBrush color(Painter::color(on?disabled?0x393A42:0x24252A:disabled?0x737580:0xD2D3DB));
 g.FillEllipse(&color,x,track.Y+gap,thumb,thumb);
}

inline void sliderThumb(Gdiplus::Graphics& g,float x,float y,float size,bool disabled,bool focused){
 if(size<=0)return;
 Gdiplus::SolidBrush surround(Painter::color(disabled?0x42434A:0x2F3036));
 Gdiplus::SolidBrush fill(Painter::color(disabled?0x70717A:focused?0xE0E3F0:0xBFC5D6));
 Gdiplus::Pen edge(Painter::color(disabled?0x555760:0x777A86),1.f);
 Gdiplus::RectF outer{x+.5f,y+.5f,size-1,size-1};
 g.FillEllipse(&surround,outer);
 g.DrawEllipse(&edge,outer);
 const float gap=size*(focused?.17f:.22f);
 g.FillEllipse(&fill,x+gap,y+gap,size-2*gap,size-2*gap);
}

inline void roundedImage(HDC dc,Gdiplus::Bitmap& image,RECT rect,float radius,uint32_t border=0){
 Gdiplus::Graphics g(dc);
 g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
 Gdiplus::GraphicsPath path;
 roundedPath(path,frame(rect,border?.5f:0.f),radius);
 Gdiplus::TextureBrush brush(&image,Gdiplus::WrapModeClamp);
 brush.TranslateTransform(float(rect.left),float(rect.top));
 g.FillPath(&brush,&path);
 if(border){
  Gdiplus::Pen edge(Painter::color(border),1.f);
  g.DrawPath(&edge,&path);
 }
}

enum class Icon { flake, wind, layers, mitten, broom, bulb, monitor, quality, gear,
 snowball, sun, globe, play, pause, more, next, down, external };

// Windows system icons cover shell conventions. The Snow shapes are drawn
// from the same normalized paths used by the macOS product.
inline void icon(HDC dc,Icon kind,RECT rect,COLORREF tint){
 auto glyph=[&](wchar_t letter){
  auto font=CreateFontW(-std::min(rect.right-rect.left,rect.bottom-rect.top),0,0,0,FW_NORMAL,
   FALSE,FALSE,FALSE,DEFAULT_CHARSET,0,0,ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Segoe MDL2 Assets");
  auto old=SelectObject(dc,font);
  SetBkMode(dc,TRANSPARENT);SetTextColor(dc,tint);
  DrawTextW(dc,&letter,1,&rect,DT_CENTER|DT_VCENTER|DT_SINGLELINE|DT_NOPREFIX);
  SelectObject(dc,old);DeleteObject(font);
 };
 switch(kind){
  case Icon::gear:glyph(L'\uE713');return;
  case Icon::globe:glyph(L'\uE774');return;
  case Icon::bulb:glyph(L'\uEA80');return;
  case Icon::external:glyph(L'\uE8A7');return;
  default:break;
 }
 Gdiplus::Graphics g(dc);
 g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
 int side=std::min(rect.right-rect.left,rect.bottom-rect.top);
 g.TranslateTransform((rect.left+rect.right-side)*.5f,(rect.top+rect.bottom-side)*.5f);
 g.ScaleTransform(side/24.f,side/24.f);
 Gdiplus::Pen pen(color(tint),1.45f);
 pen.SetLineJoin(Gdiplus::LineJoinRound);
 pen.SetStartCap(Gdiplus::LineCapRound);pen.SetEndCap(Gdiplus::LineCapRound);
 Gdiplus::SolidBrush fill(color(tint));
 auto draw=[&](std::initializer_list<Gdiplus::PointF> points){g.DrawLines(&pen,points.begin(),int(points.size()));};
 switch(kind){
  case Icon::flake:
   for(int i=0;i<6;i++){
    draw({{12,12},{12,2}});
    draw({{8.8f,4.8f},{12,6.9f},{15.2f,4.8f}});
    Gdiplus::Matrix rotation;
    rotation.RotateAt(60.f,{12.f,12.f});
    g.MultiplyTransform(&rotation);
   }
   break;
  case Icon::wind:{
   Gdiplus::GraphicsPath path;
   path.AddBezier(2.f,8.f,7.f,6.f,11.f,9.f,14.f,7.f);
   path.AddBezier(14.f,7.f,18.f,4.f,12.f,0.f,11.f,5.f);
   path.StartFigure();
   path.AddBezier(2.f,12.f,8.f,9.f,16.f,15.f,20.f,11.f);
   path.AddBezier(20.f,11.f,23.f,7.f,17.f,5.f,17.f,9.f);
   path.StartFigure();
   path.AddBezier(2.f,16.f,8.f,14.f,14.f,15.f,15.f,18.f);
   path.AddBezier(15.f,18.f,15.f,22.f,9.f,20.f,10.f,18.f);
   g.DrawPath(&pen,&path);
   break;
  }
  case Icon::layers:
   draw({{2.f,7.f},{12.f,1.5f},{22.f,7.f},{12.f,12.5f},{2.f,7.f}});
   draw({{2.f,12.f},{12.f,17.5f},{22.f,12.f}});
   draw({{2.f,17.f},{12.f,22.5f},{22.f,17.f}});
   break;
  case Icon::mitten:{
   Gdiplus::GraphicsPath path;
   path.AddLine(6.f,19.68f,6.f,17.28f);
   path.AddBezier(6.f,17.28f,3.12f,13.92f,4.32f,10.08f,4.32f,6.96f);
   path.AddBezier(4.32f,6.96f,4.32f,.48f,14.64f,.48f,14.64f,6.96f);
   path.AddLine(14.64f,6.96f,14.64f,10.8f);
   path.AddBezier(14.64f,10.8f,18.24f,6.24f,22.08f,7.44f,20.64f,10.08f);
   path.AddBezier(20.64f,10.08f,21.6f,12.96f,16.8f,16.56f,15.36f,18.24f);
   path.AddLine(15.36f,18.24f,15.36f,19.68f);path.CloseFigure();
   roundedPath(path,{5.52f,19.68f,10.32f,2.88f},1);
   g.DrawPath(&pen,&path);break;
  }
  case Icon::broom:{
   Gdiplus::GraphicsPath path;
   path.AddLine(11.52f,11.04f,20.4f,1.92f);path.StartFigure();
   path.AddLine(8.16f,11.52f,11.04f,8.88f);path.AddLine(11.04f,8.88f,14.88f,12.72f);
   path.AddLine(14.88f,12.72f,12.f,15.6f);path.CloseFigure();
   path.StartFigure();path.AddBezier(8.16f,11.52f,5.92f,11.68f,3.84f,13.04f,1.92f,15.36f);
   path.AddBezier(1.92f,15.36f,3.52f,18.56f,6.08f,20.96f,9.6f,22.56f);
   path.AddBezier(9.6f,22.56f,10.88f,20.16f,11.68f,17.84f,12.f,15.6f);
   path.CloseFigure();g.DrawPath(&pen,&path);
   draw({{4.32f,17.04f},{8.88f,14.16f}});draw({{6.96f,19.68f},{10.08f,15.36f}});
   break;
  }
  case Icon::snowball:{
   g.DrawEllipse(&pen,2.4f,2.4f,19.2f,19.2f);
   Gdiplus::GraphicsPath path;
   path.AddBezier(9.36f,17.28f,15.28f,17.76f,18.08f,15.12f,17.76f,9.36f);
   g.DrawPath(&pen,&path);break;
  }
  case Icon::monitor:{
   Gdiplus::GraphicsPath path;roundedPath(path,{1.2f,3.f,21.6f,14.6f},1.2f);
   Gdiplus::SolidBrush screen(Painter::color(0xAEAFB5,.33));
   g.FillPath(&screen,&path);g.DrawPath(&pen,&path);
   g.FillRectangle(&fill,9.f,17.6f,6.f,3.f);draw({{8.6f,20.6f},{15.4f,20.6f}});break;
  }
  case Icon::quality:
   g.DrawEllipse(&pen,2.5f,2.5f,19.f,19.f);
   draw({{12.f,12.f},{17.f,7.f}});
   for(auto p:{Gdiplus::PointF{6,12},{8,8},{12,6},{18,12},{12,18}})g.FillEllipse(&fill,p.X-.75f,p.Y-.75f,1.5f,1.5f);
   break;
  case Icon::sun:
   g.DrawEllipse(&pen,7.f,7.f,10.f,10.f);
   for(int i=0;i<8;i++){
    float dx=float(std::cos(i*pi/4)),dy=float(std::sin(i*pi/4));
    draw({{12+8*dx,12+8*dy},{12+11*dx,12+11*dy}});
   }
   break;
  case Icon::pause:
   g.FillRectangle(&fill,6.f,4.f,4.f,16.f);g.FillRectangle(&fill,14.f,4.f,4.f,16.f);break;
  case Icon::play:{
   const Gdiplus::PointF triangle[]={{7.f,4.f},{20.f,12.f},{7.f,20.f}};
   g.FillPolygon(&fill,triangle,3);break;
  }
  case Icon::more:
   for(float x:{5.f,12.f,19.f})g.FillEllipse(&fill,x-1.25f,10.75f,2.5f,2.5f);
   break;
  case Icon::next:draw({{10.f,6.f},{16.f,12.f},{10.f,18.f}});break;
  case Icon::down:draw({{6.f,9.f},{12.f,15.f},{18.f,9.f}});break;
  default:break;
 }
}
}
