#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <map>
#include <random>
#include <set>
#include <string>
#include <vector>

namespace snow {
constexpr double pi=3.14159265358979323846;
constexpr uint64_t bottomID=~uint64_t(0), taskbarID=bottomID-1;
inline double clamp(double v,double a,double b){return std::clamp(std::isfinite(v)?v:a,a,b);}
struct V {double x=0,y=0;V operator+(V q)const{return{x+q.x,y+q.y};}V operator-(V q)const{return{x-q.x,y-q.y};}V operator*(double f)const{return{x*f,y*f};}};
inline double length(V p){return std::hypot(p.x,p.y);}
struct Span{double lo=0,hi=0;bool contains(double x)const{return x>=lo&&x<=hi;}};
struct Settings {
 int weather=1,quality=0,garland=0,style=0,palette=1,cleaner=0,tool=0,appearance=0,snowflakeStyle=0;
 double wind=0,windowHeight=18,bottomHeight=48,brightness=.75,intensity=.7,snowflakeSize=1;
 bool windows=true,bottom=true,sweep=true,reduceMotion=true,taskbar=false,verticalTaskbar=false,automaticCleaner=false,bladeImage=false,allDisplays=true;
 std::set<std::wstring> displays;std::map<std::wstring,int> scenes;
 void sanitize(){weather=int(clamp(weather,0,2));quality=int(clamp(quality,0,2));garland=int(clamp(garland,0,3));style=int(clamp(style,0,2));palette=int(clamp(palette,0,2));cleaner=int(clamp(cleaner,0,1));tool=int(clamp(tool,0,3));appearance=int(clamp(appearance,0,1));snowflakeStyle=int(clamp(snowflakeStyle,0,1));snowflakeSize=clamp(snowflakeSize,.5,3);wind=clamp(wind,-100,100);windowHeight=clamp(windowHeight,4,36);bottomHeight=clamp(bottomHeight,8,96);brightness=clamp(brightness,0,1);intensity=clamp(intensity,0,1);}
 int limit()const{return quality==2?1100:360;}
};
inline double light(double time,int index,const Settings&s,bool reduce,bool tree=false){
 if(!tree&&s.garland==0)return 0;int mode=tree?2:s.garland;
 if(reduce||mode==1)return s.brightness;
 double phase=index*(mode==3?.3:1.73),speed=(mode==3?1.8:1.2)*(.3+s.intensity);
 return s.brightness*(1-s.intensity*.5*(1-std::sin(time*speed-phase)));
}
struct Surface {
 uint64_t id=0;double left=0,base=0,width=0;int side=0;bool bottom=false;
 std::vector<Span> visible;
 double corner=0;
 double supportHeight(double x)const{if(bottom||side||corner<=0)return 0;double r=std::min(corner,width/2),d=std::min(x,width-x);if(d>=r)return 0;d=clamp(d,0,r);return std::sqrt(std::max(0.,r*r-(r-d)*(r-d)))-r;}
 V point(double x,double h=0)const{return side==0?V{left+x,base+supportHeight(x)+h}:V{left+side*h,base+x};}
 V local(V p)const{return side==0?V{p.x-left,p.y-base-supportHeight(p.x-left)}:V{p.y-base,(p.x-left)*side};}
 bool contains(double x)const{for(auto a:visible)if(a.contains(x))return true;return false;}
};
struct Profile {
 double width=1,maximum=48;uint64_t seed=0;bool rounded=false;std::vector<double> h;
 Profile()=default;
 Profile(double w,double m,uint64_t s,bool r):width(std::max(1.,w)),maximum(m),seed(s),rounded(r){h.resize(count(width));}
 static size_t count(double w){return std::min<size_t>(2048,std::max<size_t>(2,size_t(std::ceil(std::max(1.,w)/8))+1));}
 double step()const{return width/(h.size()-1);}
 double sampleX(size_t i)const{return i*step();}
 double noise(double x,uint64_t salt)const{
  auto value=[&](uint64_t i){uint64_t v=(i+seed+salt)*0x9E3779B97F4A7C15ull;v=(v^(v>>30))*0xBF58476D1CE4E5B9ull;v=(v^(v>>27))*0x94D049BB133111EBull;return double(v^(v>>31))/double(UINT64_MAX);};
  double f=std::floor(x),t=x-f,b=t*t*(3-2*t);return value(uint64_t(f))+(value(uint64_t(f)+1)-value(uint64_t(f)))*b;
 }
 double inset()const{return rounded?std::min(width/3,std::max(16.,maximum*1.2)):0;}
 double cap(double x)const{
  double phase=x/22+noise(x/160,19)*3+double(seed%127),mound=.5+.5*std::cos(phase);
  double v=maximum*(.6+.4*(mound*.85+noise(x/173,71)*.15));
  if(rounded){double t=clamp(std::min(x,width-x)/inset(),0,1);v*=std::sqrt(std::max(0.,1-(1-t)*(1-t)));}return v;
 }
 double height(double x)const{if(h.empty())return 0;double p=clamp(x/width*(h.size()-1),0,double(h.size()-1));size_t i=size_t(p),j=std::min(i+1,h.size()-1);return h[i]+(h[j]-h[i])*(p-i);}
 void resize(double w,double m){Profile old=*this;width=std::max(1.,w);maximum=m;h.resize(count(width));for(size_t i=0;i<h.size();i++){double x=sampleX(i);h[i]=x<=old.width?std::min(maximum,old.height(x)):0;}}
 double deposit(double x,double amount){if(x<0||x>width)return 0;double overflow=0;int a=std::max(0,int(std::floor((x-18)/step()))),b=std::min(int(h.size()-1),int(std::ceil((x+18)/step())));for(int i=a;i<=b;i++){double wanted=h[i]+amount*std::max(0.,1-std::abs(sampleX(i)-x)/18),v=std::min(std::max(h[i],cap(sampleX(i))),wanted);overflow+=std::max(0.,wanted-v)*step();h[i]=v;}return overflow;}
 double addArea(double x,double radius,double area){
  for(int pass=0;pass<4&&area>.00001;pass++){double capacity=0;for(size_t i=0;i<h.size();i++)if(std::abs(sampleX(i)-x)<=radius)capacity+=std::max(0.,maximum-h[i])*step();if(capacity<=.00001)break;double portion=std::min(1.,area/capacity),added=0;for(size_t i=0;i<h.size();i++)if(std::abs(sampleX(i)-x)<=radius){double a=std::max(0.,maximum-h[i])*step()*portion;h[i]+=a/step();added+=a;}area=std::max(0.,area-added);}return area;
 }
 double clear(double a,double b){double area=0;for(size_t i=0;i<h.size();i++)if(sampleX(i)>=a&&sampleX(i)<=b){area+=h[i]*step();h[i]=0;}return area;}
 void clear(){std::fill(h.begin(),h.end(),0);}
 double take(double x,double radius,double requested){double area=0;std::vector<size_t>indices;for(size_t i=0;i<h.size();i++)if(std::abs(sampleX(i)-x)<=radius)indices.push_back(i);std::sort(indices.begin(),indices.end(),[&](size_t a,size_t b){return std::abs(sampleX(a)-x)<std::abs(sampleX(b)-x);});for(auto i:indices){if(area>=requested)break;double part=std::min(h[i]*step(),requested-area);area+=part;h[i]-=part/step();}return area;}
 double available(double x,double r)const{double v=0;for(size_t i=0;i<h.size();i++)if(std::abs(sampleX(i)-x)<=r)v+=h[i]*step();return v;}
 double filled()const{if(h.empty())return 0;return double(std::count_if(h.begin(),h.end(),[&](double v){return v>=maximum*.7;}))/h.size();}
};
struct Cleaner {
 bool active=false;int character=0;double x=-120,distance=0,collected=0,time=0,lastAuto=-1e10;
 bool start(int c,bool automatic=false){if(active||(automatic&&time-lastAuto<60))return false;active=true;character=c;x=-120;distance=collected=0;if(automatic)lastAuto=time;return true;}
 void clear(){active=false;distance=collected=0;}
 void step(double dt,double width,const Settings&s,Profile*profile){time+=dt;if(s.automaticCleaner&&s.bottom&&profile&&profile->filled()>=.6)start(s.cleaner,true);if(!active)return;double next=x+160*dt;if(profile)collected=std::min(1400.,collected+profile->clear(x+90,next+98));distance+=next-x;x=next;if(x>width+120)active=false;}
 double load()const{return std::min(1.,collected/1400);}
};
enum class SnowmanVariant { festive, winterBroom, classicBucket, waving };
class SnowmanCycle {
 int index;
public:
 explicit SnowmanCycle(int start):index((start%4+4)%4){}
 SnowmanVariant next(){
  auto variant=static_cast<SnowmanVariant>(index);
  index=(index+1)%4;
  return variant;
 }
};
inline SnowmanCycle& sessionSnowmanCycle(){
 static SnowmanCycle cycle(int(std::random_device{}()%4));
 return cycle;
}
struct Ball {
 uint64_t id=0,surface=0,support=0;
 double radius=6,localX=0,anchor=0;
 V p,velocity;
 bool loose=false;
 int snowmanLook=-1;
};
struct GlassFlight {V start,target;double radius=6,age=0;int variant=0;};
struct GlassMark {V p;double radius=20,age=0;int variant=0;};
struct TreePose {V p;double sx=0,sy=0,opacity=0,lights=0;};
struct HolidayTrees {
 int layout=-1;uint64_t state=42;
 struct Place{double x,h,delay;};
 inline static constexpr Place layouts[6][5]={
  {{.06,100,0},{.26,74,.16},{.48,90,.06},{.72,64,.25},{.92,82,.12}},
  {{.12,72,.10},{.34,96,0},{.55,62,.24},{.76,100,.08},{.94,84,.18}},
  {{.05,82,.22},{.22,100,.04},{.43,70,.14},{.65,94,0},{.86,62,.28}},
  {{.15,98,0},{.38,76,.24},{.57,100,.09},{.78,66,.18},{.96,86,.04}},
  {{.04,68,.16},{.29,88,0},{.51,100,.24},{.70,76,.08},{.90,94,.18}},
  {{.09,90,.26},{.31,64,.10},{.46,82,0},{.68,100,.18},{.89,74,.06}}};
 void choose(){state=state*6364136223846793005ull+1442695040888963407ull;if(layout<0)layout=int((state>>32)%6);else{int n=int((state>>32)%5);layout=n>=layout?n+1:n;}}
 std::vector<TreePose> poses(V size,double growth,const Profile*ground,double groundLeft=0)const{
  std::vector<TreePose> result;if(size.x<=0||size.y<=16)return result;double inset=std::min(24.,size.x*.04),f=std::min({1.,std::max(0.,(size.x-inset*2)/640),std::max(0.,(size.y-16)/140)});
  for(auto a:layouts[layout<0?0:layout]){double scale=a.h/270*f*1.25,half=96*scale*.9,x=std::max(half+f,std::min(size.x-half-f,inset+a.x*(size.x-2*inset)));double p=clamp((growth*1.25-a.delay)/.9,0,1),ease=1-std::pow(1-p,3);double snow=std::min(ground?ground->height(x-groundLeft):0,std::max(0.,size.y-290*scale)),settled=std::max(-6*scale,snow-48*scale),y=settled-(1-ease)*(std::max(0.,settled)+290*scale);result.push_back({{x,y},scale*.9*(.93+.07*ease),scale*(.94+.06*ease),std::min(1.,p*6),clamp((p-.65)/.35,0,1)});}return result;
 }
};
struct Game {
 inline static uint64_t nextID=1;
 std::vector<Ball> balls;std::vector<GlassFlight> flights;std::vector<GlassMark> marks;uint64_t dragged=0,source=0;V beginPoint,previous,offset,lastPointer,motion;double lastTime=0,motionTime=-1e9;bool gesture=false,looseGesture=false;std::string message;
 Ball*find(uint64_t id){for(auto&b:balls)if(b.id==id)return &b;return nullptr;}
 const Ball*find(uint64_t id)const{for(auto&b:balls)if(b.id==id)return &b;return nullptr;}
 static const Surface*surface(uint64_t id,const std::vector<Surface>&surfaces){for(auto&s:surfaces)if(s.id==id)return &s;return nullptr;}
 bool visible(const Ball&b,const std::vector<Surface>&surfaces)const{auto*s=surface(b.surface,surfaces);return !b.surface||(s&&s->contains(b.localX));}
 uint64_t hit(V p,const std::vector<Surface>&s)const{for(auto i=balls.rbegin();i!=balls.rend();++i)if(visible(*i,s)&&length(i->p-p)<=i->radius+8)return i->id;return 0;}
 std::vector<std::vector<uint64_t>> snowmen()const{std::vector<std::vector<uint64_t>> out;for(auto&b:balls)if(!b.support&&b.id!=dragged){for(auto&m:balls)if(m.support==b.id&&m.radius<b.radius)for(auto&h:balls)if(h.support==m.id&&h.radius<m.radius)out.push_back({b.id,m.id,h.id});}return out;}
 void updateSnowmen(SnowmanCycle& cycle=sessionSnowmanCycle()){
  std::set<uint64_t> heads;
  for(const auto& group:snowmen()){
   auto* head=find(group.back());
   heads.insert(head->id);
   if(head->snowmanLook<0)head->snowmanLook=static_cast<int>(cycle.next());
  }
  for(auto& ball:balls)if(!heads.count(ball.id))ball.snowmanLook=-1;
 }
 void invalidateSnowman(uint64_t id){
  for(const auto& group:snowmen()){
   if(std::find(group.begin(),group.end(),id)!=group.end())find(group.back())->snowmanLook=-1;
  }
 }
 void sample(V p,double t){if(t>lastTime&&length(p-lastPointer)>.5){motion=(p-lastPointer)*(1/clamp(t-lastTime,.008,.14));motionTime=t;}lastPointer=p;lastTime=t;}
 std::set<uint64_t> descendants(uint64_t id)const{std::set<uint64_t> ids{id};for(int i=0;i<2;i++)for(auto&b:balls)if(ids.count(b.support))ids.insert(b.id);return ids;}
 bool transferStack(uint64_t root,Game& target,const Surface& surface,double x){
  auto ids=descendants(root);
  if(ids.count(dragged)||target.balls.size()+ids.size()>30)return false;
  size_t groups=0;
  for(const auto& group:snowmen())if(ids.count(group.back()))groups++;
  if(groups&&target.snowmen().size()+groups>5)return false;
  for(auto ball:balls)if(ids.count(ball.id)){
   ball.localX=x;
   ball.p=surface.point(x,ball.anchor);
   target.balls.push_back(ball);
  }
  balls.erase(std::remove_if(balls.begin(),balls.end(),[&](const Ball& ball){return ids.count(ball.id)>0;}),balls.end());
  return true;
 }
 void detach(uint64_t id){invalidateSnowman(id);auto ids=descendants(id);for(auto&b:balls)if(b.id!=id&&ids.count(b.id)){b.surface=b.support=0;b.velocity={};}}
 void begin(V p,double time,const std::vector<Surface>&s,std::map<uint64_t,Profile>&profiles,bool loose=false){
  dragged=source=0;gesture=true;looseGesture=loose;beginPoint=previous=lastPointer=p;lastTime=time;motionTime=-1e9;offset={};message.clear();
  if(!loose)if(uint64_t id=hit(p,s)){detach(id);auto*b=find(id);dragged=id;offset=p-b->p;b->surface=b->support=0;b->velocity={};return;}
  for(auto&sf:s){auto it=profiles.find(sf.id);if(sf.side||it==profiles.end())continue;V q=sf.local(p);if(sf.contains(q.x)&&q.y>=-2&&q.y<=it->second.height(q.x)+14){source=sf.id;if(balls.size()>=30||snowmen().size()>=5){message="limit";return;}double radius=loose?9:6,area=pi*radius*radius;if(it->second.available(q.x,26)<area){message="empty";return;}it->second.take(q.x,26,area);Ball b;b.id=nextID++;b.radius=radius;b.p={p.x,std::max(p.y,sf.point(q.x,it->second.height(q.x)+radius).y)};b.loose=loose;balls.push_back(b);dragged=b.id;offset=p-b.p;return;}}message="start";
 }
 void drag(V p,double time,const std::vector<Surface>&s,std::map<uint64_t,Profile>&profiles){
  if(!gesture)return;sample(p,time);double distance=length(p-previous);previous=p;
  if(!dragged)return;
  Ball*b=find(dragged);if(!b)return;b->p=p-offset;
  if(!b->loose)for(auto&sf:s){auto it=profiles.find(sf.id);if(sf.side||it==profiles.end())continue;V q=sf.local(p);if(sf.contains(q.x)&&q.y>=-2&&q.y<=it->second.height(q.x)+45){double area=it->second.take(q.x,std::max(26.,b->radius),std::min(pi*(1600-b->radius*b->radius),distance*18));b->radius=std::min(40.,std::sqrt(b->radius*b->radius+area/pi));b->p.y=std::max(b->p.y,sf.point(q.x,it->second.height(q.x)+b->radius).y);break;}}
 }
 int depth(const Ball&b)const{int d=0;auto*p=&b;while(p->support&&d<3){p=find(p->support);if(!p)break;d++;}return d;}
 void end(V p,double time,const std::vector<Surface>&s,const std::map<uint64_t,Profile>&profiles,bool throwing=true){
  sample(p,time);auto*b=find(dragged);if(b){
   Ball*support=nullptr;for(auto&a:balls)if(!b->loose&&!a.loose&&a.id!=b->id&&a.surface&&depth(a)<2&&a.radius>7&&visible(a,s)&&a.p.y<b->p.y&&std::abs(a.p.x-b->p.x)<=std::max(12.,a.radius*.5)&&std::abs(b->p.y-b->radius-a.p.y-a.radius)<=std::max(24.,b->radius)){
    bool free=true;for(auto&child:balls)if(child.support==a.id)free=false;if(free&&(!a.support||snowmen().size()<5))support=&a;
   }
   if(support){auto*sf=surface(support->surface,s);b->radius=std::min(b->radius,std::max(6.,support->radius*.72));b->p={support->p.x,support->p.y+support->radius+b->radius};b->surface=support->surface;b->support=support->id;b->localX=support->localX;b->anchor=sf->local(b->p).y;b->velocity={};}
   else{
    if(throwing&&!b->loose&&time-motionTime<=.14&&length(motion)>=210){if(flights.size()>=12)flights.erase(flights.begin());flights.push_back({b->p,b->p+motion*.075,b->radius,0,int(b->id%9)});auto id=b->id;balls.erase(std::remove_if(balls.begin(),balls.end(),[&](auto&a){return a.id==id;}),balls.end());dragged=source=0;gesture=false;return;}
    for(auto&sf:s){auto it=profiles.find(sf.id);if(sf.side||it==profiles.end())continue;V q=sf.local(b->p);double h=it->second.height(q.x);if(sf.contains(q.x)&&q.y>=0&&q.y-b->radius<=h+1&&q.y<=h+b->radius+1){b->p.y=sf.point(q.x,h+b->radius).y;b->surface=sf.id;b->localX=q.x;b->anchor=h+b->radius;b->velocity={};}}
   }
  }dragged=source=0;gesture=false;
  updateSnowmen();
 }
 void remove(V p,const std::vector<Surface>&s){auto id=hit(p,s);if(!id){marks.erase(std::remove_if(marks.begin(),marks.end(),[&](auto&m){return length(m.p-p)<=m.radius;}),marks.end());return;}auto ids=descendants(id);balls.erase(std::remove_if(balls.begin(),balls.end(),[&](auto&b){return ids.count(b.id);}),balls.end());if(ids.count(dragged)){dragged=0;gesture=false;}}
 void clear(){balls.clear();flights.clear();marks.clear();dragged=source=0;gesture=false;message.clear();}
 void step(double dt,const std::vector<Surface>&s,const std::map<uint64_t,Profile>&profiles,V size){
  for(auto&f:flights){f.age+=dt;f.target.x=clamp(f.target.x,8,std::max(8.,size.x-8));f.target.y=clamp(f.target.y,8,std::max(8.,size.y-8));if(f.age>=.24){if(marks.size()>=16)marks.erase(marks.begin());marks.push_back({f.target,std::min(110.,f.radius*2.2),0,f.variant});}}
  flights.erase(std::remove_if(flights.begin(),flights.end(),[](auto&f){return f.age>=.24;}),flights.end());for(auto&m:marks)m.age+=dt;marks.erase(std::remove_if(marks.begin(),marks.end(),[](auto&m){return m.age>=5;}),marks.end());
  for(auto&b:balls)if(auto*sf=surface(b.surface,s)){b.localX=clamp(b.localX,b.radius,std::max(b.radius,sf->width-b.radius));b.p=sf->point(b.localX,b.anchor);}
  for(auto&b:balls)if(b.surface&&!b.support&&b.id!=dragged){auto*sf=surface(b.surface,s);auto it=profiles.find(b.surface);if(sf&&sf->contains(b.localX)&&it!=profiles.end()&&b.anchor-b.radius>it->second.height(b.localX)+.5){auto ids=descendants(b.id);for(auto&c:balls)if(ids.count(c.id)){c.surface=0;c.velocity={};}}}
  for(auto&b:balls)if(!b.surface&&!b.support&&b.id!=dragged){V old=b.p;b.velocity.y=std::max(-1800.,b.velocity.y-360*dt);b.p=b.p+b.velocity*dt;
   if(b.p.x<b.radius){b.p.x=b.radius;b.velocity.x=std::abs(b.velocity.x)*.6;}if(b.p.x>size.x-b.radius){b.p.x=std::max(b.radius,size.x-b.radius);b.velocity.x=-std::abs(b.velocity.x)*.6;}if(b.p.y>size.y-b.radius){b.p.y=size.y-b.radius;b.velocity.y=-std::abs(b.velocity.y)*.55;}
   const Surface*landing=nullptr;double top=-1e30;uint64_t support=0;
   if(b.velocity.y<=0){for(auto&sf:s){auto it=profiles.find(sf.id);if(sf.side||it==profiles.end())continue;double x=sf.local(b.p).x,h=sf.point(x,it->second.height(x)).y;if(sf.contains(x)&&b.p.y-b.radius<=h&&(old.y-b.radius>=h-1||(old.y>=sf.point(x).y&&old.y-b.radius<h))&&h>top){landing=&sf;top=h;support=0;}}
    bool hasChildren=false;for(auto&c:balls)if(c.support==b.id)hasChildren=true;
    if(!hasChildren&&!b.loose)for(auto&a:balls)if(!a.loose&&a.id!=b.id&&a.surface&&a.radius>b.radius&&depth(a)<2&&std::abs(b.p.x-a.p.x)<=a.radius*.5){auto*sf=surface(a.surface,s);double h=a.p.y+a.radius;if(sf&&sf->contains(a.localX)&&old.y-b.radius>=h-1&&b.p.y-b.radius<=h&&h>top&&(!a.support||snowmen().size()<5)){landing=sf;top=h;support=a.id;b.p.x=a.p.x;}}
   }
   if(landing){b.surface=landing->id;b.support=support;b.p.y=top+b.radius;b.localX=landing->local(b.p).x;b.anchor=landing->local(b.p).y;b.velocity={};}
  }
  for(int k=0;k<2;k++)for(auto&b:balls)if(auto*a=find(b.support)){b.p={a->p.x,a->p.y+a->radius+b.radius};b.surface=a->surface;b.localX=a->localX;b.anchor=a->anchor+a->radius+b.radius;b.velocity=a->velocity;}
  std::set<uint64_t> gone;for(auto&b:balls)if(!b.support&&b.p.y< -300){auto ids=descendants(b.id);gone.insert(ids.begin(),ids.end());}balls.erase(std::remove_if(balls.begin(),balls.end(),[&](auto&b){return gone.count(b.id);}),balls.end());
  if(balls.size()>=3)updateSnowmen();
 }
};
struct Particle {
 V p;double speed=55,drift=0,r=2,alpha=.8,life=120;bool scattered=false;
 double area=0;uint64_t source=0,id=0;
};
struct Simulation {
 V size;std::vector<Surface> surfaces;std::map<uint64_t,Profile> profiles;std::vector<Particle> particles;Game game;Cleaner cleaner;
 std::mt19937_64 random;double birth=0,wind=0,time=0,treeGrowth=0;bool tree=false;HolidayTrees trees;uint64_t nextParticle=1;
 explicit Simulation(V dimensions,uint64_t seed=42):size(dimensions),random(seed){trees.state=seed^0xABCDEF9912ull;}
 double unit(){return std::generate_canonical<double,53>(random);}
 void sync(std::vector<Surface> next,const Settings&s,const std::set<uint64_t>&live){
  if(s.bottom)next.push_back({bottomID,0,0,size.x,0,true,{{0,size.x}}});surfaces=std::move(next);
  for(auto&sf:surfaces){double m=sf.bottom?s.bottomHeight:s.windowHeight;auto it=profiles.find(sf.id);if(it==profiles.end())profiles.emplace(sf.id,Profile(sf.width,m,sf.id,!sf.bottom&&sf.side==0));else if(it->second.width!=sf.width||it->second.maximum!=m)it->second.resize(sf.width,m);}
  for(auto it=profiles.begin();it!=profiles.end();)if(it->first!=bottomID&&it->first!=taskbarID&&!live.count(it->first))it=profiles.erase(it);else ++it;
  while(profiles.size()>128){auto it=profiles.begin();while(it!=profiles.end()&&std::any_of(surfaces.begin(),surfaces.end(),[&](auto&v){return v.id==it->first;}))++it;if(it==profiles.end())break;profiles.erase(it);}
  game.balls.erase(std::remove_if(game.balls.begin(),game.balls.end(),[&](auto&b){return b.surface&&b.surface!=bottomID&&b.surface!=taskbarID&&!live.count(b.surface);}),game.balls.end());
  game.step(0,surfaces,profiles,size);
 }
 void growTree(bool reduce){trees.choose();tree=true;treeGrowth=reduce?1:0;}
 void removeTree(){tree=false;treeGrowth=0;}
 std::vector<TreePose> treePoses(double floorInset=0)const{
  if(!tree)return {};
  const Surface* taskbar=floorInset>0?Game::surface(taskbarID,surfaces):nullptr;
  if(taskbar&&(taskbar->side||std::abs(taskbar->base-floorInset)>.001))taskbar=nullptr;
  const auto profile=profiles.find(taskbar?taskbarID:bottomID);
  const bool hasGroundSnow=(floorInset==0||taskbar)&&profile!=profiles.end();
  auto poses=trees.poses({size.x,size.y-floorInset},treeGrowth,hasGroundSnow?&profile->second:nullptr,
                        taskbar?taskbar->left:0);
  for(auto& pose:poses)pose.p.y+=floorInset;
  return poses;
 }
 void clear(){for(auto&v:profiles)v.second.clear();particles.erase(std::remove_if(particles.begin(),particles.end(),[](auto&p){return p.scattered;}),particles.end());game.clear();cleaner.clear();}
 bool emitArea(V p,double area,double direction,uint64_t source,int limit){
  if(area<=0||limit<=0)return false;
  Particle part{p,40,direction*24,2,.88,30+size.y/50,true,area,source,nextParticle++};
  if(int(particles.size())<limit){particles.push_back(part);return true;}
  auto it=std::find_if(particles.begin(),particles.end(),[](auto&q){return q.area==0;});
  if(it==particles.end())return false;*it=part;return true;
 }
 void sweep(V p,int tool,int limit){sweep(p,tool,limit,p-V{1,0});}
 void sweep(V p,int tool,int limit,V from){
  for(auto&sf:surfaces){
   auto it=profiles.find(sf.id);if(it==profiles.end())continue;auto q=sf.local(p);double x=clamp(q.x,0,sf.width);
   if(q.x< -30||q.x>sf.width+30||!sf.contains(x)||std::abs(q.y-it->second.height(x))>40)continue;
   if(tool==2){it->second.clear();continue;}
   double delta=sf.side?p.y-from.y:p.x-from.x;if(std::abs(delta)<.1)continue;double dir=delta<0?-1:1;
   bool edge=!sf.bottom&&!sf.side&&(dir<0?x<34:x>sf.width-34);
   double removed=it->second.take(x,24,std::min(600.,std::max(20.,length(p-from)*12)));if(removed<=0)continue;
   if(edge){
    double edgeX=dir<0?0:sf.width;V start=sf.point(edgeX);start.x+=dir*4;start.y-=3;
    if(!emitArea(start,removed,dir,sf.id,limit))it->second.addArea(x,24,removed);
   }else{
    double destination=clamp(x+dir*35,0,sf.width),rest=it->second.addArea(destination,24,removed);
    if(rest>0)it->second.addArea(x,24,rest);
   }
  }
 }
 void trim(size_t limit){
  while(particles.size()>limit){
   auto it=std::find_if(particles.begin(),particles.end(),[](auto&p){return p.area==0;});
   if(it!=particles.end())particles.erase(it);
   else{particles.front().area+=particles.back().area;particles.pop_back();}
  }
 }
 void step(double seconds,const Settings&s,bool reduce){
  double dt=clamp(seconds,0,1./15);time+=dt;if(tree)treeGrowth=reduce?1:std::min(1.,treeGrowth+dt/1.25);
  int limit=std::max(30,s.limit());trim(size_t(limit));
  wind+=(s.wind*1.6-wind)*std::min(1.,dt*2);double rate=s.weather==0?24:s.weather==1?65:145;
  int naturalLimit=std::max(30,int(limit*(s.weather==0?.35:s.weather==1?.65:1)));
  birth=std::min(200.,birth+rate*(s.quality==2?1:.6)*(reduce?.35:1)*dt);
  int n=std::max(0,std::min(int(birth),naturalLimit-int(particles.size())));birth-=int(birth);
  for(int i=0;i<n;i++)particles.push_back({{unit()*size.x,size.y+6},(s.weather==0?32:s.weather==1?55:95)*(.65+unit()*.7),unit()*20-10,1+unit()*2.5,.4+unit()*.5,120,false,0,0,nextParticle++});
  std::vector<Particle> alive;alive.reserve(particles.size());
  for(auto p:particles){
   V old=p.p;p.life-=dt;p.p.x+=((p.scattered?0:wind)+p.drift)*dt;p.p.y-=p.speed*dt;
   if(p.scattered){p.speed=std::min(900.,p.speed+240*dt);p.p.x=clamp(p.p.x,0,size.x);if(p.area==0)p.alpha*=std::pow(.18,dt);}
   else{if(p.p.x< -8)p.p.x=size.x+6;if(p.p.x>size.x+8)p.p.x=-6;}
   const Surface*hit=nullptr;double highest=-1e30;
   for(auto&sf:surfaces){
    if(p.scattered&&sf.id==p.source)continue;auto it=profiles.find(sf.id);if(it==profiles.end())continue;
    auto q=sf.local(p.p),before=sf.local(old);double h=it->second.height(q.x),top=sf.point(q.x,h).y;
    if(sf.contains(q.x)&&before.y>=h-.001&&q.y<=h&&top>highest){highest=top;hit=&sf;}
   }
   if(hit){
    auto&profile=profiles[hit->id];double x=hit->local(p.p).x;
    if(p.area>0){
     p.area=profile.addArea(x,20,p.area);
     if(p.area>.00001){
      if(hit->bottom){p.p={clamp(p.p.x,0,size.x),hit->point(x,profile.height(x)).y+.1};p.speed=0;p.life=30;}
      else{bool left=x<profile.width/2;p.p=hit->point(left?0:hit->width);p.p.x+=left?-4:4;p.p.y-=3;p.source=hit->id;}
      alive.push_back(p);
     }
    }else{
     double overflow=profile.deposit(x,p.r*.42);
     if(profile.rounded&&overflow>.01&&(x<profile.inset()||x>profile.width-profile.inset())){
      bool left=x<profile.width/2;p.p=hit->point(left?0:hit->width);p.p.x+=left?-3:3;p.p.y-=2;p.speed=40;p.drift=left?-24:24;p.scattered=true;p.life=30+size.y/50;p.alpha=.85;p.area=overflow;p.source=hit->id;alive.push_back(p);
     }
    }
   }else if(p.p.y> -10&&p.life>0&&p.alpha>.03)alive.push_back(p);
  }
  particles=std::move(alive);auto it=profiles.find(bottomID);cleaner.step(dt,size.x,s,it==profiles.end()?nullptr:&it->second);game.step(dt,surfaces,profiles,size);
 }
};
} // namespace snow
