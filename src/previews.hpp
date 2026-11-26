#pragma once
namespace snow {
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
   for(int i=0;i<48;i++)sim.particles.push_back({{24+std::fmod(i*147.7,1230.),190+std::fmod(i*47.2,260.)},55,0,1.4+(i%4)*.4,.7,120,false,0,0,uint64_t(i+1)});
   sim.cleaner.start(1);sim.cleaner.x=850;sim.cleaner.distance=80;sim.cleaner.collected=700;sim.game.marks.push_back({{760,365},30,0,3});p.draw(sim,settings,false);
  }ok=savePNG(bitmap,folder+(appearance?L"\\overview-textured.png":L"\\overview-simple.png"))&&ok;
 }
 {Gdiplus::Bitmap bitmap(384,580,PixelFormat32bppPARGB);{Gdiplus::Graphics g(&bitmap);g.Clear(Gdiplus::Color(0,0,0,0));g.TranslateTransform(0,580);g.ScaleTransform(1,-1);Painter p(g);for(int layer=0;layer<5;layer++)p.image(p.treeLayer(layer),0,0,384,580);}ok=savePNG(bitmap,folder+L"\\tree-vector.png")&&ok;}
 {Gdiplus::Bitmap bitmap(1024,160,PixelFormat32bppPARGB);{Gdiplus::Graphics g(&bitmap);g.Clear(Painter::color(0x183344));g.TranslateTransform(0,160);g.ScaleTransform(1,-1);Painter p(g);for(int i=0;i<8;i++)p.image(p.flake(i),i*128+16,32,96,96);}ok=savePNG(bitmap,folder+L"\\snowflakes.png")&&ok;}
 {Gdiplus::Bitmap bitmap(720,720,PixelFormat32bppPARGB);{Gdiplus::Graphics g(&bitmap);g.Clear(Painter::color(0x71818D));g.TranslateTransform(0,720);g.ScaleTransform(1,-1);Painter p(g);for(int i=0;i<9;i++)p.image(p.glassMark(i),(i%3)*240+24,(i/3)*240+24,192,192);}ok=savePNG(bitmap,folder+L"\\glass-impacts.png")&&ok;}
 return ok;
}
} // namespace snow
