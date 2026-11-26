#ifndef UNICODE
#define UNICODE 1
#endif
#ifndef _UNICODE
#define _UNICODE 1
#endif
#define NOMINMAX
#include <windows.h>
#include <windowsx.h>
#include <commctrl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <commdlg.h>
#include <dwmapi.h>
#include <wtsapi32.h>
#include <wincodec.h>
#include <objbase.h>
#include <gdiplus.h>
#include <chrono>
#include <array>
#include <fstream>
#include <sstream>
#include <memory>
#include "drawing.hpp"
#include "flake-renderer.hpp"
#include "settings-theme.hpp"
#include "previews.hpp"
#include "localization.hpp"

using namespace snow;
constexpr wchar_t APPCLASS[]=L"SnowDesktop.Tray",OVERLAYCLASS[]=L"SnowDesktop.Overlay",SETTINGCLASS[]=L"SnowDesktop.Settings",PANECLASS[]=L"SnowDesktop.Pane",BACKGROUNDCLASS[]=L"SnowDesktop.Background";
constexpr UINT TRAY_MESSAGE=WM_APP+1,FRAME_MESSAGE=WM_APP+2;
constexpr wchar_t DIAGNOSTICCLASS[]=L"SnowDesktop.Diagnostic";
constexpr int SIDEBAR=100, WEATHER=1100,SWEEP=1101,TREE=1102,WIND=1200,WINDRESET=1201,ACCWINDOWS=1300,ACCBOTTOM=1301,WINDOWHEIGHT=1302,BOTTOMHEIGHT=1303,TASKBAR=1304,VERTICAL=1305,TOOL=1400,PLAY=1401,CLEAR=1402,CLEANER=1500,RUNCLEANER=1501,AUTOCLEANER=1502,BLADE=1503,IMPORT=1504,STYLE=1600,MODE=1601,PALETTE=1602,BRIGHTNESS=1603,INTENSITY=1604,SCENEMONITOR=1700,SCENEKIND=1701,ALLMONITORS=1800,QUALITY=1900,REDUCEMOTION=1901,LOGIN=2000,RESET=2001;
constexpr int APPEARANCE=1103,FLAKESTYLE=1104,FLAKESIZE=1105;
constexpr int visiblePanes[]={0,1,2,3,4,5,7,8,9};
constexpr const wchar_t* paneNames[]={L"Снег",L"Ветер",L"Накопление",L"Поиграть со снегом",L"Уборка снега",L"Гирлянды",L"Зимние сцены",L"Экраны",L"Качество",L"Общие"};
constexpr bool showBladeImage=false,showWinterScenes=false,showShovel=false,showDeleteTool=false;
constexpr wchar_t QUICKCLASS[]=L"SnowDesktop.Quick";
constexpr int MITTEN=1410,SNOWBALL=1411,SHOVEL=1412,DELETE_TOOL=1413,AUTHOR=2002,LANGUAGE=2003;
constexpr int QUICK_PAUSE=2100,QUICK_MORE=2101,QUICK_OPEN=2102,QUICK_LIGHT=2110,QUICK_PREVIEW=2120,FULL_PREVIEW=2121;
constexpr int SEG_WEATHER=2300,SEG_MATERIAL=2310,SEG_FLAKES=2320,SEG_CLEANER=2330,STYLE_CARDS=2340,QUALITY_CARDS=2350;
constexpr int SETTINGS_RULE=2180,SETTINGS_BRAND_ICON=2182,PRIVACY_ICON=2183,ESC_KEY=2184;
constexpr int FULL_PAUSE=2200,SIDEBAR_LANGUAGE=2201,DISPLAY_MENU=2202,STARTUP_SETTINGS=2203,HELP_TEXT=2204,STATUS_LABEL=2205;
struct App;
struct WindowInfo{HWND handle=nullptr;RECT frame{};bool eligible=false;};
struct MonitorInfo{HMONITOR handle=nullptr;RECT frame{};std::wstring device;};
struct Overlay{
 MonitorInfo monitor;HWND window=nullptr,background=nullptr;double dpi=1;bool fullscreen=false,shown=false,rendered=false;
 double treeFloorInset=0;
 HDC dc=nullptr;HBITMAP dib=nullptr,old=nullptr;void*bits=nullptr;std::unique_ptr<Gdiplus::Bitmap>canvas;std::unique_ptr<Simulation>sim;
 ~Overlay(){destroyCanvas();if(background)DestroyWindow(background);if(window)DestroyWindow(window);}
 void destroyCanvas(){canvas.reset();if(dc){SelectObject(dc,old);DeleteObject(dib);DeleteDC(dc);}dc=nullptr;dib=old=nullptr;bits=nullptr;}
 void allocate(){destroyCanvas();int w=monitor.frame.right-monitor.frame.left,h=monitor.frame.bottom-monitor.frame.top;BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=w;info.bmiHeader.biHeight=-h;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;HDC screen=GetDC(nullptr);dc=CreateCompatibleDC(screen);dib=CreateDIBSection(screen,&info,DIB_RGB_COLORS,&bits,nullptr,0);ReleaseDC(nullptr,screen);old=(HBITMAP)SelectObject(dc,dib);if(bits)canvas=std::make_unique<Gdiplus::Bitmap>(w,h,w*4,PixelFormat32bppPARGB,(BYTE*)bits);}
 V mouse(LPARAM l)const{return{GET_X_LPARAM(l)/dpi,sim->size.y-GET_Y_LPARAM(l)/dpi};}
};
static App*app=nullptr;
static LRESULT CALLBACK trayProc(HWND,UINT,WPARAM,LPARAM);
static LRESULT CALLBACK overlayProc(HWND,UINT,WPARAM,LPARAM);
static LRESULT CALLBACK settingProc(HWND,UINT,WPARAM,LPARAM);
static LRESULT CALLBACK paneProc(HWND,UINT,WPARAM,LPARAM);
static LRESULT CALLBACK quickProc(HWND,UINT,WPARAM,LPARAM);
static LRESULT CALLBACK backgroundProc(HWND,UINT,WPARAM,LPARAM);
static std::wstring executable(){wchar_t p[32768];GetModuleFileNameW(nullptr,p,32768);return p;}
static std::wstring directory(std::wstring p){return p.substr(0,p.find_last_of(L"\\/"));}
static double now(){
 using Seconds=std::chrono::duration<double>;
 return Seconds(std::chrono::steady_clock::now().time_since_epoch()).count();
}
static bool intersects(RECT a,RECT b){RECT r;return IntersectRect(&r,&a,&b);}
static LONG bottomTaskbarInset(const RECT& monitor,const RECT& work,const std::vector<RECT>& taskbars){
 // An auto-hidden bar can be visible temporarily without reserving work area.
 if(work.bottom>=monitor.bottom)return 0;
 for(const auto& bar:taskbars){
  if(bar.right-bar.left>bar.bottom-bar.top&&bar.top>monitor.top&&bar.top<monitor.bottom&&bar.bottom>=monitor.bottom&&
     bar.left<=work.left&&bar.right>=work.right&&std::abs(bar.top-work.bottom)<=2)
   return monitor.bottom-bar.top;
 }
 return 0;
}
static std::wstring className(HWND h){wchar_t b[160]{};GetClassNameW(h,b,160);return b;}
static bool shellClass(const std::wstring&c){return c==L"Progman"||c==L"WorkerW"||c==L"Shell_TrayWnd"||c==L"Shell_SecondaryTrayWnd"||c==L"NotifyIconOverflowWindow"||c==L"tooltips_class32";}
static void subtract(std::vector<Span>&a,Span cut){std::vector<Span>r;for(auto s:a){if(cut.hi<=s.lo||cut.lo>=s.hi)r.push_back(s);else{if(cut.lo>s.lo)r.push_back({s.lo,std::min(s.hi,cut.lo)});if(cut.hi<s.hi)r.push_back({std::max(s.lo,cut.hi),s.hi});}}a=std::move(r);}

struct App {
 HINSTANCE instance;HWND tray=nullptr,settingsWindow=nullptr,sidebar=nullptr,pane=nullptr,status=nullptr;HFONT font=nullptr,titleFont=nullptr;HICON icon=nullptr;NOTIFYICONDATAW nid{};
 Settings settings;std::wstring home,assets,ini;std::vector<std::unique_ptr<Overlay>>overlays;std::vector<MonitorInfo>monitors;std::vector<WindowInfo>windows;std::vector<RECT>taskbars;std::set<uint64_t> liveWindows;
 std::unique_ptr<Gdiplus::Bitmap>badge,cabin,porch;std::map<int,HWND>controls;int selectedPane=0,sceneMonitor=0,scroll=0,contentHeight=600;double uiScale=1,lastTick=0,lastGeometry=0;bool paused=false,hidden=false,sleeping=false,locked=false,diagnostic=false,firstRun=false,transition=false;Overlay*interactive=nullptr;HWND previousFocus=nullptr;std::wstring lastStatus;
 HWND quickWindow=nullptr,quickPane=nullptr,quickStatus=nullptr,quickScroll=nullptr;
 HFONT quickFont=nullptr,quickTitleFont=nullptr;
 std::map<int,HWND> quickControls;
 double quickScale=1;
 HBRUSH graphite=nullptr,navBrush=nullptr;
 HWND brandIcon=nullptr,brandTitle=nullptr,languageButton=nullptr,pageTitle=nullptr,pageSubtitle=nullptr,pagePause=nullptr,pageFooter=nullptr,settingsScroll=nullptr;
 HFONT brandFont=nullptr,smallFont=nullptr,strongFont=nullptr;
 int fieldWidth=1,sidebarWidth=230;
 RECT quickAnchor{};
 std::array<int,8> quickValues{};
 int lastActiveTool=-1;
 bool reviewWindow=false;
 int measuredStyle=-1,measuredSize=100;
 double measurementStart=0,lastPresentation=0;
 std::vector<double> presentationIntervals,frameCosts;
 int timerMs=0;bool diagnosticFailed=false;
 HANDLE frameTimer=nullptr,frameWait=nullptr;
 bool preciseFrames=false;
 double frameDeadline=0;
 PatternedFlakes patternedFlakes;
 explicit App(HINSTANCE h):instance(h){}
 int px(double v)const{return int(std::round(v*uiScale));}
 std::wstring read(const wchar_t*key,const wchar_t*value=L"")const{wchar_t b[4096]{};GetPrivateProfileStringW(L"Snow",key,value,b,4096,ini.c_str());return b;}
 int integer(const wchar_t*k,int d)const{return GetPrivateProfileIntW(L"Snow",k,d,ini.c_str());}
 void put(const wchar_t*k,std::wstring v){WritePrivateProfileStringW(L"Snow",k,v.c_str(),ini.c_str());}
 void load(){wchar_t path[MAX_PATH]{};SHGetFolderPathW(nullptr,CSIDL_LOCAL_APPDATA,nullptr,SHGFP_TYPE_CURRENT,path);home=std::wstring(path)+L"\\Snow";CreateDirectoryW(home.c_str(),nullptr);ini=home+L"\\settings.ini";if(diagnostic){wchar_t temp[MAX_PATH]{};GetTempPathW(MAX_PATH,temp);ini=std::wstring(temp)+L"SnowDiagnostics-"+std::to_wstring(GetCurrentProcessId())+L".ini";}appLanguage=integer(L"language",0)==1?Language::russian:Language::english;assets=directory(executable())+L"\\assets";firstRun=GetFileAttributesW(ini.c_str())==INVALID_FILE_ATTRIBUTES;
  settings.weather=integer(L"weather",1);settings.quality=integer(L"quality",0);settings.wind=integer(L"wind",0);settings.windowHeight=integer(L"windowHeight",18);settings.bottomHeight=integer(L"bottomHeight",48);settings.windows=integer(L"windows",1);settings.bottom=integer(L"bottom",1);settings.sweep=integer(L"sweep",1);settings.reduceMotion=integer(L"reduceMotion",1);settings.taskbar=integer(L"taskbar",0);settings.verticalTaskbar=integer(L"verticalTaskbar",0);settings.cleaner=integer(L"cleaner",0);settings.automaticCleaner=integer(L"automaticCleaner",0);settings.bladeImage=integer(L"bladeImage",0);settings.garland=integer(L"garland",0);settings.style=integer(L"style",0);settings.palette=integer(L"palette",1);settings.brightness=integer(L"brightness",75)/100.;settings.intensity=integer(L"intensity",70)/100.;settings.allDisplays=integer(L"allDisplays",1);settings.appearance=integer(L"appearance",0);settings.snowflakeStyle=integer(L"snowflakeStyle",0);settings.snowflakeSize=integer(L"snowflakeSize",100)/100.;
  std::wistringstream stream(read(L"displays"));std::wstring item;while(std::getline(stream,item,L'|'))if(!item.empty())settings.displays.insert(item);settings.sanitize();
  if(showBladeImage){badge=std::make_unique<Gdiplus::Bitmap>((home+L"\\blade.png").c_str());if(badge->GetLastStatus()!=Gdiplus::Ok)badge.reset();}if(showWinterScenes){cabin=std::make_unique<Gdiplus::Bitmap>((assets+L"\\cabin.png").c_str());porch=std::make_unique<Gdiplus::Bitmap>((assets+L"\\porch.png").c_str());}
 }
 void save(){if(diagnostic)return;settings.sanitize();auto w=[&](const wchar_t*k,int v){put(k,std::to_wstring(v));};w(L"language",appLanguage==Language::russian);w(L"weather",settings.weather);w(L"appearance",settings.appearance);w(L"snowflakeStyle",settings.snowflakeStyle);w(L"snowflakeSize",int(std::round(settings.snowflakeSize*100)));w(L"quality",settings.quality);w(L"wind",int(settings.wind));w(L"windowHeight",int(settings.windowHeight));w(L"bottomHeight",int(settings.bottomHeight));w(L"windows",settings.windows);w(L"bottom",settings.bottom);w(L"sweep",settings.sweep);w(L"reduceMotion",settings.reduceMotion);w(L"taskbar",settings.taskbar);w(L"verticalTaskbar",settings.verticalTaskbar);w(L"cleaner",settings.cleaner);w(L"automaticCleaner",settings.automaticCleaner);w(L"bladeImage",settings.bladeImage);w(L"garland",settings.garland);w(L"style",settings.style);w(L"palette",settings.palette);w(L"brightness",int(std::round(settings.brightness*100)));w(L"intensity",int(std::round(settings.intensity*100)));w(L"allDisplays",settings.allDisplays);std::wstring list;for(auto&d:settings.displays)list+=d+L"|";put(L"displays",list);for(auto&s:settings.scenes)put((L"scene:"+s.first).c_str(),std::to_wstring(s.second));}
 bool reduced()const{BOOL animations=TRUE;SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION,0,&animations,0);return settings.reduceMotion&&!animations;}
 bool anyTree()const{for(auto&o:overlays)if(o->sim->tree)return true;return false;}
 bool stopped()const{return paused||hidden||sleeping||locked;}
 bool isSnowUi(HWND window) const {
  return window&&(window==tray||window==quickWindow||window==settingsWindow||
   (quickWindow&&IsChild(quickWindow,window))||(settingsWindow&&IsChild(settingsWindow,window)));
 }
 bool gameAvailable() const {
  return !stopped()&&std::any_of(overlays.begin(),overlays.end(),[](const auto& overlay){return !overlay->fullscreen;});
 }
 void play(int tool){
  if(!gameAvailable())return;
  if(interactive&&settings.tool==tool){exitGame();return;}
  enterGame(tool);
 }
 bool loginEnabled()const{HKEY key;bool value=false;if(RegOpenKeyExW(HKEY_CURRENT_USER,L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",0,KEY_READ,&key)==ERROR_SUCCESS){wchar_t b[32768]{};DWORD bytes=sizeof(b);if(RegQueryValueExW(key,L"SnowDesktop",nullptr,nullptr,(BYTE*)b,&bytes)==ERROR_SUCCESS)value=std::wstring(b).find(executable())!=std::wstring::npos;RegCloseKey(key);}return value;}
 void setLogin(bool on){HKEY key;if(RegCreateKeyExW(HKEY_CURRENT_USER,L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",0,nullptr,0,KEY_SET_VALUE,nullptr,&key,nullptr)!=ERROR_SUCCESS){MessageBoxW(settingsWindow,tr(L"Не удалось изменить автозапуск."),tr(L"Снег"),MB_ICONERROR);return;}if(on){auto path=L"\""+executable()+L"\"";RegSetValueExW(key,L"SnowDesktop",0,REG_SZ,(BYTE*)path.c_str(),DWORD((path.size()+1)*sizeof(wchar_t)));}else RegDeleteValueW(key,L"SnowDesktop");RegCloseKey(key);}
 void registerClasses(){WNDCLASSEXW c{sizeof(c)};c.hInstance=instance;c.hCursor=LoadCursorW(nullptr,IDC_ARROW);c.hIcon=icon;c.hIconSm=icon;c.lpszClassName=diagnostic?DIAGNOSTICCLASS:APPCLASS;c.lpfnWndProc=trayProc;RegisterClassExW(&c);c.lpszClassName=OVERLAYCLASS;c.lpfnWndProc=overlayProc;RegisterClassExW(&c);graphite=CreateSolidBrush(settingsTheme::background);navBrush=CreateSolidBrush(settingsTheme::sidebar);c.lpszClassName=SETTINGCLASS;c.lpfnWndProc=settingProc;c.hbrBackground=graphite;RegisterClassExW(&c);c.lpszClassName=PANECLASS;c.lpfnWndProc=paneProc;RegisterClassExW(&c);c.lpszClassName=QUICKCLASS;c.lpfnWndProc=quickProc;RegisterClassExW(&c);c.lpszClassName=BACKGROUNDCLASS;c.lpfnWndProc=backgroundProc;c.hbrBackground=(HBRUSH)GetStockObject(BLACK_BRUSH);RegisterClassExW(&c);}
 bool start(){load();icon=(HICON)LoadImageW(instance,MAKEINTRESOURCEW(1),IMAGE_ICON,32,32,LR_DEFAULTCOLOR);if(!icon)icon=(HICON)LoadImageW(nullptr,(assets+L"\\snow.ico").c_str(),IMAGE_ICON,32,32,LR_LOADFROMFILE);if(!icon)icon=LoadIconW(nullptr,IDI_APPLICATION);registerClasses();tray=CreateWindowExW(0,diagnostic?DIAGNOSTICCLASS:APPCLASS,tr(L"Снег"),0,0,0,0,0,nullptr,nullptr,instance,nullptr);if(!tray)return false;nid.cbSize=sizeof(nid);nid.hWnd=tray;nid.uID=1;nid.uFlags=NIF_MESSAGE|NIF_ICON|NIF_TIP|NIF_SHOWTIP;nid.uCallbackMessage=TRAY_MESSAGE;nid.hIcon=icon;lstrcpynW(nid.szTip,tr(L"Снег"),128);if(!diagnostic){Shell_NotifyIconW(NIM_ADD,&nid);nid.uVersion=NOTIFYICON_VERSION_4;Shell_NotifyIconW(NIM_SETVERSION,&nid);}WTSRegisterSessionNotification(tray,NOTIFY_FOR_THIS_SESSION);rebuild();lastTick=now();updateTimer();if(firstRun&&!diagnostic){save();showSettings();}return true;}
 void shutdown(){stopFrameTimer();exitGame(false);save();KillTimer(tray,1);KillTimer(tray,2);WTSUnRegisterSessionNotification(tray);Shell_NotifyIconW(NIM_DELETE,&nid);overlays.clear();if(settingsWindow)DestroyWindow(settingsWindow);if(quickWindow)DestroyWindow(quickWindow);if(font)DeleteObject(font);if(titleFont)DeleteObject(titleFont);if(quickFont)DeleteObject(quickFont);if(quickTitleFont)DeleteObject(quickTitleFont);if(graphite)DeleteObject(graphite);if(navBrush)DeleteObject(navBrush);for(auto face:{brandFont,smallFont,strongFont})if(face)DeleteObject(face);}
 static VOID CALLBACK frameReady(void* window,BOOLEAN){
  PostMessageW(static_cast<HWND>(window),FRAME_MESSAGE,0,0);
 }
 void stopFrameTimer(){
  preciseFrames=false;
  if(frameTimer)CancelWaitableTimer(frameTimer);
  if(frameWait)UnregisterWaitEx(frameWait,INVALID_HANDLE_VALUE);
  if(frameTimer)CloseHandle(frameTimer);
  frameWait=nullptr;frameTimer=nullptr;
 }
 bool armFrame(double deadline){
  frameDeadline=deadline;
  LARGE_INTEGER due{};
  due.QuadPart=-std::max<LONGLONG>(1,LONGLONG(std::ceil((deadline-now())*10000000)));
  return SetWaitableTimer(frameTimer,&due,0,nullptr,nullptr,FALSE)!=FALSE;
 }
 void updateTimer(){
  SYSTEM_POWER_STATUS power{};
  GetSystemPowerStatus(&power);
  const int ms=(hidden||sleeping||locked)?0:paused?100:settings.quality==2&&!power.SystemStatusFlag?16:33;
  if(ms==timerMs)return;
  KillTimer(tray,1);
  timerMs=ms;
  lastTick=now();
  preciseFrames=false;
  if(frameTimer)CancelWaitableTimer(frameTimer);
  if(ms==16){
   if(!frameTimer){
    frameTimer=CreateWaitableTimerExW(nullptr,nullptr,CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,TIMER_MODIFY_STATE|SYNCHRONIZE);
    if(frameTimer&&!RegisterWaitForSingleObject(&frameWait,frameTimer,frameReady,tray,INFINITE,WT_EXECUTEDEFAULT))
     stopFrameTimer();
   }
   if(frameTimer)preciseFrames=armFrame(lastTick+1./60);
  }
  if(ms&&!preciseFrames)SetTimer(tray,1,ms,nullptr);
 }
 void precisionFrame(){
  if(!preciseFrames)return;
  const double deadline=frameDeadline;
  if(now()+.0002>=deadline){
   tick();
   if(!preciseFrames||frameDeadline!=deadline)return;
  }
  // Keep the original cadence after a slow frame, without queuing catch-up work.
  constexpr double period=1./60;
  const double latest=now();
  const double next=latest<deadline?deadline:deadline+(std::floor((latest-deadline)/period)+1)*period;
  if(!armFrame(next)){
   preciseFrames=false;
   SetTimer(tray,1,timerMs,nullptr);
  }
 }
 void rebuild(){exitGame(false);monitors.clear();EnumDisplayMonitors(nullptr,nullptr,[](HMONITOR m,HDC,LPRECT,LPARAM data)->BOOL{auto*self=(App*)data;MONITORINFOEXW info{};info.cbSize=sizeof(info);GetMonitorInfoW(m,&info);self->monitors.push_back({m,info.rcMonitor,info.szDevice});return TRUE;},(LPARAM)this);
  auto old=std::move(overlays);for(auto&m:monitors){if(!settings.allDisplays&&!settings.displays.count(m.device))continue;std::unique_ptr<Overlay> o;for(auto&i:old)if(i&&i->monitor.device==m.device){o=std::move(i);break;}if(!o){o=std::make_unique<Overlay>();o->monitor=m;o->window=CreateWindowExW(WS_EX_LAYERED|WS_EX_TRANSPARENT|WS_EX_NOACTIVATE|WS_EX_TOOLWINDOW|WS_EX_TOPMOST,OVERLAYCLASS,L"",WS_POPUP,m.frame.left,m.frame.top,m.frame.right-m.frame.left,m.frame.bottom-m.frame.top,nullptr,nullptr,instance,o.get());o->dpi=GetDpiForWindow(o->window)/96.;o->sim=std::make_unique<Simulation>(V{(m.frame.right-m.frame.left)/o->dpi,(m.frame.bottom-m.frame.top)/o->dpi},uint64_t((uintptr_t)m.handle));}else{o->monitor=m;o->dpi=GetDpiForWindow(o->window)/96.;o->sim->size={(m.frame.right-m.frame.left)/o->dpi,(m.frame.bottom-m.frame.top)/o->dpi};SetWindowPos(o->window,HWND_TOPMOST,m.frame.left,m.frame.top,m.frame.right-m.frame.left,m.frame.bottom-m.frame.top,SWP_NOACTIVATE);}
   o->allocate();settings.scenes[m.device]=integer((L"scene:"+m.device).c_str(),0);overlays.push_back(std::move(o));}
  readGeometry();for(auto&o:overlays)configureBackground(*o);renderAll();if(settingsWindow)buildPane();updateTimer();
 }
 void readGeometry(){windows.clear();taskbars.clear();liveWindows.clear();EnumWindows([](HWND h,LPARAM data)->BOOL{auto*self=(App*)data;auto name=className(h);if(name==OVERLAYCLASS||name==APPCLASS||name==BACKGROUNDCLASS)return TRUE;self->liveWindows.insert(uint64_t((uintptr_t)h));if(!IsWindowVisible(h)||IsIconic(h))return TRUE;RECT r{};if(!GetWindowRect(h,&r)||r.right-r.left<20||r.bottom-r.top<15)return TRUE;if(name==L"Shell_TrayWnd"||name==L"Shell_SecondaryTrayWnd"){self->taskbars.push_back(r);return TRUE;}if(shellClass(name))return TRUE;DWORD cloaked=0;DwmGetWindowAttribute(h,DWMWA_CLOAKED,&cloaked,sizeof(cloaked));if(cloaked)return TRUE;RECT frame;if(SUCCEEDED(DwmGetWindowAttribute(h,DWMWA_EXTENDED_FRAME_BOUNDS,&frame,sizeof(frame))))r=frame;LONG_PTR style=GetWindowLongPtrW(h,GWL_STYLE),ex=GetWindowLongPtrW(h,GWL_EXSTYLE);DWORD pid=0;GetWindowThreadProcessId(h,&pid);bool eligible=pid!=GetCurrentProcessId()&&!(ex&WS_EX_TOOLWINDOW)&&!(ex&WS_EX_TRANSPARENT)&&(style&(WS_CAPTION|WS_THICKFRAME))&&(r.right-r.left)>=120&&(r.bottom-r.top)>=60;self->windows.push_back({h,r,eligible});return TRUE;},(LPARAM)this);
  const auto&live=liveWindows;HWND foreground=GetForegroundWindow();RECT front{};GetWindowRect(foreground,&front);DWORD pid=0;GetWindowThreadProcessId(foreground,&pid);
  for(auto&o:overlays){auto&m=o->monitor.frame;o->fullscreen=pid!=GetCurrentProcessId()&&foreground&&!(GetWindowLongPtrW(foreground,GWL_STYLE)&(WS_CAPTION|WS_THICKFRAME))&&front.left<=m.left+1&&front.top<=m.top+1&&front.right>=m.right-1&&front.bottom>=m.bottom-1&&!shellClass(className(foreground));std::vector<Surface> surfaces;
   if(settings.windows)for(size_t index=0;index<windows.size()&&surfaces.size()<96;index++){auto&w=windows[index];if(!w.eligible||!intersects(w.frame,m))continue;double d=o->dpi,left=(w.frame.left-m.left)/d,base=(m.bottom-w.frame.top)/d,width=(w.frame.right-w.frame.left)/d;Surface sf{uint64_t((uintptr_t)w.handle),left,base,width,0,false,{{std::max(0.,-left),std::min(width,o->sim->size.x-left)}}};DWORD preference=1;if(SUCCEEDED(DwmGetWindowAttribute(w.handle,static_cast<DWMWINDOWATTRIBUTE>(33),&preference,sizeof(preference)))&&preference!=1)sf.corner=preference==3?4:8;if(sf.visible[0].hi<=sf.visible[0].lo||base<0||base>o->sim->size.y+settings.windowHeight)continue;
    for(size_t j=0;j<index;j++){auto&r=windows[j].frame;if(r.top<=w.frame.top&&r.bottom>w.frame.top-settings.windowHeight*d)subtract(sf.visible,{(r.left-w.frame.left)/d,(r.right-w.frame.left)/d});}surfaces.push_back(std::move(sf));}
   if(settings.taskbar)for(auto&r:taskbars)if(intersects(r,m)){double d=o->dpi;if(r.right-r.left>r.bottom-r.top){Surface sf{taskbarID,(r.left-m.left)/d,(m.bottom-r.top)/d,(r.right-r.left)/d,0,false,{{0,(r.right-r.left)/d}}};surfaces.push_back(sf);}else if(settings.verticalTaskbar&&settings.wind!=0){bool left=r.left<=m.left+4;bool toward=left?settings.wind<0:settings.wind>0;if(toward)surfaces.push_back({taskbarID,((left?r.right:r.left)-m.left)/d,(m.bottom-r.bottom)/d,(r.bottom-r.top)/d,left?1:-1,false,{{0,(r.bottom-r.top)/d}}});}break;}
   MONITORINFO info{sizeof(info)};
   o->treeFloorInset=GetMonitorInfoW(o->monitor.handle,&info)?bottomTaskbarInset(m,info.rcWork,taskbars)/o->dpi:0;
   o->sim->sync(std::move(surfaces),settings,live);
  }
  // Keep anchored decorations together when their supporting window moves to another display.
  for(auto& source:overlays)for(auto& target:overlays)if(source!=target){
   auto& from=*source->sim;
   auto& to=*target->sim;
   double ratio=source->dpi/target->dpi;
   for(auto& sf:to.surfaces){
    if(sf.id==bottomID||sf.id==taskbarID)continue;
    auto saved=from.profiles.find(sf.id);
    if(saved==from.profiles.end())continue;
    auto* oldSurface=Game::surface(sf.id,from.surfaces);
    auto& profile=to.profiles.at(sf.id);
    for(size_t k=0;k<profile.h.size();k++){
     double x=profile.sampleX(k), sourceX=x/ratio;
     if((oldSurface&&oldSurface->contains(sourceX))||(!oldSurface&&profile.h[k]==0))
      profile.h[k]=std::min(profile.cap(x),saved->second.height(sourceX));
    }
   }
   std::vector<uint64_t> roots;
   for(const auto& ball:from.game.balls)
    if(ball.surface&&ball.surface!=bottomID&&ball.surface!=taskbarID&&!ball.support&&ball.id!=from.game.dragged)
     roots.push_back(ball.id);
   for(uint64_t id:roots){
    const auto& ball=*from.game.find(id);
    const auto* sf=Game::surface(ball.surface,to.surfaces);
    if(!sf)continue;
    double x=ball.localX*ratio;
    V point=sf->point(x,ball.anchor);
    if(point.x>=0&&point.x<to.size.x&&point.y>=0&&point.y<to.size.y)
     from.game.transferStack(id,to.game,*sf,x);
   }
  }
  if(interactive&&interactive->fullscreen)exitGame(false);
 }
 void tick(){double t=now(),dt=clamp(t-lastTick,0,1./15);lastTick=t;if(t-lastGeometry>=.1){readGeometry();lastGeometry=t;}if(interactive&&GetForegroundWindow()!=interactive->window&&!isSnowUi(GetForegroundWindow()))exitGame(false);bool rm=reduced();POINT pointer{};GetCursorPos(&pointer);
  for(auto&o:overlays){if(!stopped()&&!o->fullscreen){o->sim->step(dt,settings,rm);V cursor{(pointer.x-o->monitor.frame.left)/o->dpi,(o->monitor.frame.bottom-pointer.y)/o->dpi};if((settings.sweep&&!interactive)||(interactive==o.get()&&settings.tool==1)){static std::map<std::wstring,V>previous;auto it=previous.find(o->monitor.device);if(it!=previous.end()&&cursor.x>=0&&cursor.y>=0&&cursor.x<=o->sim->size.x&&cursor.y<=o->sim->size.y&&length(cursor-it->second)>1)if(!o->sim->game.dragged)o->sim->sweep(cursor,1,settings.limit(),it->second);previous[o->monitor.device]=cursor;}}render(*o);if(o->background)InvalidateRect(o->background,nullptr,FALSE);}updateStatus();if(measuredStyle>=0)measureFrame(t);}
 void beginMeasurement(){
  settings.weather=2;
  settings.quality=2;
  settings.snowflakeStyle=measuredStyle;
  settings.snowflakeSize=measuredSize/100.;
  settings.reduceMotion=false;
  settings.sweep=false;
  updateTimer();
  for(auto& overlay:overlays){
   overlay->sim->random.seed(42);
   for(int frame=0;frame<360;frame++)overlay->sim->step(1./60,settings,false);
  }
  measurementStart=now();
  lastTick=now();
 }
 void measureFrame(double started){
  const double finished=now();
  if(finished-measurementStart<1.25)return;
  size_t presented=0,particles=0;
  long width=0,height=0;
  for(const auto& overlay:overlays){
   if(!overlay->shown||!overlay->rendered)continue;
   presented++;
   particles+=overlay->sim->particles.size();
   width=std::max(width,overlay->monitor.frame.right-overlay->monitor.frame.left);
   height=std::max(height,overlay->monitor.frame.bottom-overlay->monitor.frame.top);
  }
  if(presented){
   if(lastPresentation){
    presentationIntervals.push_back((finished-lastPresentation)*1000);
    frameCosts.push_back((finished-started)*1000);
   }
   lastPresentation=finished;
  }
  if(finished-measurementStart<6.25)return;
  auto percentile=[](std::vector<double> values,double fraction){
   if(values.empty())return 0.;
   std::sort(values.begin(),values.end());
   return values[size_t(std::ceil(values.size()*fraction))-1];
  };
  double elapsed=0;
  for(double sample:presentationIntervals)elapsed+=sample;
  std::ostringstream out;
  out<<"{\"style\":"<<measuredStyle<<",\"sizePercent\":"<<measuredSize<<",\"width\":"<<width<<",\"height\":"<<height
     <<",\"displays\":"<<presented<<",\"particles\":"<<particles<<",\"intervals\":"<<presentationIntervals.size()
     <<",\"fps\":"<<(elapsed?1000*presentationIntervals.size()/elapsed:0)
     <<",\"frameMsP50\":"<<percentile(presentationIntervals,.5)<<",\"frameMsP95\":"<<percentile(presentationIntervals,.95)
     <<",\"workMsP95\":"<<percentile(frameCosts,.95)<<"}\n";
  const std::string report=out.str();
  DWORD written=0;
  WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),report.data(),DWORD(report.size()),&written,nullptr);
  diagnosticFailed=presentationIntervals.empty();
  DestroyWindow(tray);
 }
 void render(Overlay& o){
  const bool visible=!hidden&&!sleeping&&!locked&&!o.fullscreen;
  if(!visible){
   ShowWindow(o.window,SW_HIDE);
   if(o.background)ShowWindow(o.background,SW_HIDE);
   o.shown=false;
   return;
  }
  if(!o.canvas)return;
  const int width=int(o.canvas->GetWidth()),height=int(o.canvas->GetHeight());
  std::array<RECT,2> exclusions{};
  size_t excluded=0;
  for(HWND window:{settingsWindow,quickWindow})if(window&&IsWindowVisible(window)&&!IsIconic(window)){
   RECT bounds{};
   if(GetWindowRect(window,&bounds)){
    OffsetRect(&bounds,-o.monitor.frame.left,-o.monitor.frame.top);
    exclusions[excluded++]=bounds;
   }
  }
  const bool patterns=settings.snowflakeStyle==1;
  const bool reduce=reduced();
  auto* pixels=static_cast<uint32_t*>(o.bits);
  std::fill_n(pixels,size_t(width)*height,interactive==&o?0x01000000u:0u);
  if(patterns)patternedFlakes.draw(pixels,width,height,o.dpi,*o.sim,settings,reduce,exclusions.data(),excluded);
  Gdiplus::Graphics g(o.canvas.get());
  for(size_t i=0;i<excluded;i++){
   const auto& rect=exclusions[i];
   g.ExcludeClip(Gdiplus::Rect(rect.left,rect.top,rect.right-rect.left,rect.bottom-rect.top));
  }
  g.TranslateTransform(0,REAL(height));
  g.ScaleTransform(REAL(o.dpi),REAL(-o.dpi));
  Painter paint(g);
  paint.draw(*o.sim,settings,reduce,badge.get(),patterns,o.treeFloorInset);
  if(interactive==&o){g.ResetTransform();g.ScaleTransform(REAL(o.dpi),REAL(o.dpi));Gdiplus::SolidBrush bg(Gdiplus::Color(220,0,0,0)),white(Gdiplus::Color::White);Gdiplus::RectF box(REAL(std::max(8.,o.sim->size.x/2-235)),18,470,66);Gdiplus::GraphicsPath panel;settingsTheme::roundedPath(panel,box,settingsTheme::overlayRadius);g.FillPath(&bg,&panel);Gdiplus::Font font(L"Segoe UI",13);std::wstring hint=settings.tool==0?tr(L"Снежок: нажмите на снег, поднимите и бросьте в стекло"):settings.tool==1?tr(L"Варежка: поднимите горсть или столкните снег с края"):settings.tool==2?tr(L"Лопата: нажмите на сугроб"):tr(L"Удаление: нажмите на шар");hint+=tr(L"\nEsc — вернуть обычные клики");g.DrawString(hint.c_str(),-1,&font,Gdiplus::PointF(box.X+12,25),&white);if(!o.sim->game.message.empty()){std::wstring note=o.sim->game.message=="limit"?tr(L"Достигнут лимит шаров или снеговиков"):o.sim->game.message=="empty"?tr(L"Здесь недостаточно снега"):tr(L"Начните на сугробе или возьмите готовый шар");g.DrawString(note.c_str(),-1,&font,Gdiplus::PointF(box.X+12,92),&white);}}
  g.Flush(Gdiplus::FlushIntentionSync);SIZE sz{LONG(o.canvas->GetWidth()),LONG(o.canvas->GetHeight())};POINT dst{o.monitor.frame.left,o.monitor.frame.top},src{};BLENDFUNCTION blend{AC_SRC_OVER,0,255,AC_SRC_ALPHA};o.rendered=UpdateLayeredWindow(o.window,nullptr,&dst,&sz,o.dc,&src,0,&blend,ULW_ALPHA)!=FALSE;if(!o.shown&&o.rendered){ShowWindow(o.window,SW_SHOWNOACTIVATE);o.shown=true;}if(o.background)ShowWindow(o.background,SW_SHOWNOACTIVATE);
 }
 void renderAll(){for(auto&o:overlays)render(*o);updateStatus();}
 void updateStatus(){
  std::wstring current=tr(hidden?tr(L"Эффекты скрыты"):paused?tr(L"На паузе"):interactive?tr(L"Игра со снегом"):overlays.empty()?tr(L"Выберите экран"):tr(L"Идёт снег"));
  if(current!=lastStatus){
   lastStatus=current;
   if(status)SetWindowTextW(status,current.c_str());
   if(quickStatus)SetWindowTextW(quickStatus,current.c_str());
  }
  setControlChecked(findControl(controls,TREE),anyTree());
  dependencies();
  setControlText(pagePause,tr(paused?L"Продолжить":L"Пауза"));
  const int nextTool=interactive?settings.tool:-1;
  if(nextTool!=lastActiveTool){
   lastActiveTool=nextTool;
   for(int id:{MITTEN,SNOWBALL,SHOVEL,DELETE_TOOL})
    if(HWND child=findControl(controls,id))InvalidateRect(child,nullptr,FALSE);
  }
  syncQuick();
 }
 void growTree(bool on){if(!on){for(auto&o:overlays)o->sim->removeTree();}else if(!stopped()){POINT p;GetCursorPos(&p);Overlay*target=nullptr;for(auto&o:overlays)if(!o->fullscreen){if(!target)target=o.get();if(PtInRect(&o->monitor.frame,p)){target=o.get();break;}}if(target){for(auto&o:overlays)o->sim->removeTree();target->sim->growTree(reduced());}}renderAll();refreshSettingsControls();}
 void runCleaner(){if(stopped())return;for(auto&o:overlays)if(!o->fullscreen)o->sim->cleaner.start(settings.cleaner);}
 void enterGame(int tool=-1){
  if(!gameAvailable())return;
  const HWND focus=GetForegroundWindow();
  POINT cursor{};GetCursorPos(&cursor);
  Overlay* target=interactive;
  if(!target)for(auto& overlay:overlays){
   if(overlay->fullscreen)continue;
   if(!target)target=overlay.get();
   if(PtInRect(&overlay->monitor.frame,cursor)){target=overlay.get();break;}
  }
  HWND restore=interactive&&focus==interactive->window?previousFocus:focus;
  exitGame(false);
  if(tool>=0)settings.tool=tool;
  interactive=target;
  previousFocus=restore;
  auto ex=GetWindowLongPtrW(target->window,GWL_EXSTYLE);
  SetWindowLongPtrW(target->window,GWL_EXSTYLE,ex&~(WS_EX_TRANSPARENT|WS_EX_NOACTIVATE));
  HRGN area=CreateRectRgn(0,0,target->monitor.frame.right-target->monitor.frame.left,target->monitor.frame.bottom-target->monitor.frame.top);
  for(auto& r:taskbars)if(intersects(r,target->monitor.frame)){
   HRGN cut=CreateRectRgn(r.left-target->monitor.frame.left,r.top-target->monitor.frame.top,
     r.right-target->monitor.frame.left,r.bottom-target->monitor.frame.top);
   CombineRgn(area,area,cut,RGN_DIFF);DeleteObject(cut);
  }
  if(!SetWindowRgn(target->window,area,FALSE))DeleteObject(area);
  render(*target);
  if(focus==settingsWindow||focus==quickWindow){
   SetWindowPos(focus,HWND_TOPMOST,0,0,0,0,SWP_NOSIZE|SWP_NOMOVE|SWP_NOACTIVATE);
  }else{
   SetForegroundWindow(target->window);
   SetFocus(target->window);
  }
  if(quickWindow&&IsWindowVisible(quickWindow))
   SetWindowPos(quickWindow,HWND_TOPMOST,0,0,0,0,SWP_NOSIZE|SWP_NOMOVE|SWP_NOACTIVATE);
  updateStatus();
 }
 void exitGame(bool restore=true){if(!interactive)return;auto*o=interactive;o->sim->game.end({},now(),o->sim->surfaces,o->sim->profiles,false);ReleaseCapture();interactive=nullptr;SetWindowRgn(o->window,nullptr,FALSE);SetWindowLongPtrW(o->window,GWL_EXSTYLE,GetWindowLongPtrW(o->window,GWL_EXSTYLE)|WS_EX_TRANSPARENT|WS_EX_NOACTIVATE);if(restore&&IsWindow(previousFocus))SetForegroundWindow(previousFocus);previousFocus=nullptr;if(settingsWindow)SetWindowPos(settingsWindow,HWND_NOTOPMOST,0,0,0,0,SWP_NOSIZE|SWP_NOMOVE|SWP_NOACTIVATE);render(*o);updateStatus();}
 void togglePause(){paused=!paused;exitGame();updateTimer();renderAll();}void toggleHidden(){hidden=!hidden;exitGame();updateTimer();renderAll();}
 void clearSnow(){for(auto&o:overlays)o->sim->clear();renderAll();}
 void changed(bool geometry=false){settings.sanitize();save();if(geometry)readGeometry();updateTimer();renderAll();dependencies();
  refreshSettingsControls();
 }
 #include "settings-ui.inc"
 #include "settings-pages.inc"
 HWND control(const wchar_t* type,const wchar_t* text,DWORD style,int id,double x,double y,double w,double h){
  RECT bounds{};GetClientRect(pane,&bounds);
  double width=std::max(1.,std::min(w,bounds.right/uiScale-x));
  HWND child=CreateWindowExW(0,type,text,WS_CHILD|WS_VISIBLE|style,px(x),px(y),std::max(1,px(x+width)-px(x)),std::max(1,px(y+h)-px(y)),pane,(HMENU)(INT_PTR)id,instance,nullptr);
  SendMessageW(child,WM_SETFONT,(WPARAM)font,TRUE);
  skinControl(child,type,style);
  if(id&&id!=HELP_TEXT&&id!=SETTINGS_RULE)controls[id]=child;
  return child;
 }
 void check(int id,const wchar_t* title,double y,bool value){
  HWND child=control(L"BUTTON",title,BS_AUTOCHECKBOX|WS_TABSTOP,id,0,y,fieldWidth,28);
  SendMessageW(child,BM_SETCHECK,value?BST_CHECKED:BST_UNCHECKED,0);
 }
 void button(int id,const wchar_t* title,double y,double width){
  control(L"BUTTON",title,BS_OWNERDRAW|WS_TABSTOP,id,0,y,width,38);
 }
 std::wstring sliderValue(int id,int value)const{
  if(id==WIND){
   if(value==0)return tr(L"Штиль");
   return std::to_wstring(std::abs(value))+L" "+tr(value<0?L"Влево":L"Вправо");
  }
  if(id==FLAKESIZE||id==BRIGHTNESS||id==INTENSITY)return std::to_wstring(value)+L"%";
  return std::to_wstring(value)+L" "+tr(L"пт");
 }
 void slider(int id,const wchar_t* title,int y,int lo,int hi,int value,bool percent=false){
  (void)percent;
  int caption=std::min(fieldWidth/3,110);
  heading(title,0,y,fieldWidth-caption);
  control(L"STATIC",sliderValue(id,value).c_str(),SS_RIGHT,id+4000,fieldWidth-caption,y,caption,22);
  HWND child=control(TRACKBAR_CLASSW,title,TBS_HORZ|TBS_NOTICKS|WS_TABSTOP,id,0,y+26,fieldWidth,25);
  SendMessageW(child,TBM_SETRANGE,TRUE,MAKELPARAM(lo,hi));
  SendMessageW(child,TBM_SETPOS,TRUE,value);
 }

 bool checked(int id)const{auto it=controls.find(id);return it!=controls.end()&&SendMessageW(it->second,BM_GETCHECK,0,0)==BST_CHECKED;}
 int selection(int id)const{auto it=controls.find(id);return it==controls.end()?0:int(SendMessageW(it->second,CB_GETCURSEL,0,0));}
 void enable(int id,bool enabled){setControlEnabled(findControl(controls,id),enabled);}
 void dependencies(){enable(WINDOWHEIGHT,settings.windows);enable(BOTTOMHEIGHT,settings.bottom);enable(VERTICAL,settings.taskbar);enable(MITTEN,gameAvailable());enable(SNOWBALL,gameAvailable());enable(SHOVEL,gameAvailable());enable(DELETE_TOOL,gameAvailable());enable(RUNCLEANER,gameAvailable());enable(TREE,!stopped()||anyTree());enable(BLADE,badge!=nullptr);enable(INTENSITY,settings.garland>=2||anyTree());enable(PALETTE,settings.garland!=0);}
 void drawSidebar(DRAWITEMSTRUCT item){
  if(item.itemID>=std::size(visiblePanes))return;
  settingsTheme::ControlBuffer buffer(item.hDC,item.rcItem);
  if(buffer.dc()!=item.hDC)OffsetRect(&item.rcItem,-item.rcItem.left,-item.rcItem.top);
  item.hDC=buffer.dc();
  const bool selected=(item.itemState&ODS_SELECTED)!=0;
  RECT row=item.rcItem;row.bottom-=px(3);
  FillRect(item.hDC,&item.rcItem,navBrush);
  if(selected)settingsTheme::surface(item.hDC,row,float(px(settingsTheme::controlRadius)),true,false,keyboardFocus(sidebar));
  const COLORREF tint=selected?settingsTheme::ink:settingsTheme::foreground;
  const settingsTheme::Icon icons[]={settingsTheme::Icon::flake,settingsTheme::Icon::wind,
   settingsTheme::Icon::layers,settingsTheme::Icon::mitten,settingsTheme::Icon::broom,
   settingsTheme::Icon::bulb,settingsTheme::Icon::monitor,settingsTheme::Icon::quality,settingsTheme::Icon::gear};
  settingsTheme::icon(item.hDC,icons[item.itemID],
   {row.left+px(13),row.top+px(7),row.left+px(35),row.top+px(33)},tint);
  auto old=SelectObject(item.hDC,font);
  RECT label=row;
  label.left+=px(47);label.right-=px(6);
  SetBkMode(item.hDC,TRANSPARENT);SetTextColor(item.hDC,tint);
  DrawTextW(item.hDC,tr(paneNames[visiblePanes[item.itemID]]),-1,&label,DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS|DT_NOPREFIX);
  SelectObject(item.hDC,old);
 }
 HFONT settingsFont(int size,int weight=FW_NORMAL){
  return CreateFontW(-px(size),0,0,0,weight,FALSE,FALSE,FALSE,DEFAULT_CHARSET,0,0,
                    CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");
 }
 void makeFonts(){
  const HFONT old[]={font,titleFont,brandFont,smallFont,strongFont};
  font=settingsFont(14);
  titleFont=settingsFont(24,FW_SEMIBOLD);
  brandFont=settingsFont(19,FW_SEMIBOLD);
  smallFont=settingsFont(13);
  strongFont=settingsFont(15,FW_SEMIBOLD);
  applySettingsFonts();
  for(auto face:old)if(face)DeleteObject(face);
 }
 void showSettings(){
  if(quickWindow)ShowWindow(quickWindow,SW_HIDE);
  if(!settingsWindow){
   POINT cursor{};GetCursorPos(&cursor);
   MONITORINFO info{sizeof(info)};
   HMONITOR monitor=MonitorFromPoint(cursor,MONITOR_DEFAULTTONEAREST);
   if(!GetMonitorInfoW(monitor,&info))return;
   RECT work=info.rcWork;
   const DWORD style=WS_OVERLAPPEDWINDOW|WS_CLIPCHILDREN, ex=WS_EX_CONTROLPARENT;
   settingsWindow=CreateWindowExW(ex,SETTINGCLASS,tr(L"Настройки Снега"),style,work.left,work.top,
                                  1,1,nullptr,nullptr,instance,nullptr);
   if(!settingsWindow)return;
   UINT dpi=GetDpiForWindow(settingsWindow);
   uiScale=dpi?dpi/96.:1.;
   makeFonts();
   createSettingsShell();
   RECT frame{0,0,px(1040),px(660)};
   AdjustWindowRectExForDpi(&frame,style,FALSE,ex,dpi?dpi:96);
   int w=std::min(work.right-work.left,frame.right-frame.left),h=std::min(work.bottom-work.top,frame.bottom-frame.top);
   SetWindowPos(settingsWindow,nullptr,work.left+(work.right-work.left-w)/2,work.top+(work.bottom-work.top-h)/2,w,h,
                SWP_NOZORDER|SWP_NOACTIVATE);
   darkFrame(settingsWindow);
   layoutSettings();
  }
  ShowWindow(settingsWindow,SW_SHOW);
  if(interactive)SetWindowPos(settingsWindow,HWND_TOPMOST,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE);
  SetForegroundWindow(settingsWindow);
 }
 void layout(){layoutSettings();}
 void buildPane(){buildSettingsPage();}

 void onScroll(HWND source){
  if(!source)return;
  int id=GetDlgCtrlID(source),value=int(SendMessageW(source,TBM_GETPOS,0,0));
  const bool quick=GetParent(source)==quickPane;
  const auto& group=quick?quickControls:controls;
  double* setting=nullptr;
  double divisor=1;
  switch(id){
   case FLAKESIZE:
    setting=&settings.snowflakeSize;
    divisor=100;
    value=int(std::lround(value/10.))*10;
    syncSlider(group,id,value);
    break;
   case WIND:setting=&settings.wind;break;
   case WINDOWHEIGHT:setting=&settings.windowHeight;break;
   case BOTTOMHEIGHT:setting=&settings.bottomHeight;break;
   case BRIGHTNESS:setting=&settings.brightness;divisor=100;break;
   case INTENSITY:setting=&settings.intensity;divisor=100;break;
   default:return;
  }
  if(*setting==value/divisor)return;
  *setting=value/divisor;
  if(!quick)setControlText(findControl(group,id+4000),sliderValue(id,value).c_str());
  changed(id==WINDOWHEIGHT||id==BOTTOMHEIGHT);
  if(quick)syncFull();
 }
 void command(int id,int notification){if(id==SIDEBAR&&notification==LBN_SELCHANGE){int row=int(SendMessageW(sidebar,LB_GETCURSEL,0,0));if(row<0||row>=9)return;selectedPane=visiblePanes[row];buildPane();return;}if(notification==CBN_SELCHANGE){switch(id){case WEATHER:settings.weather=selection(id);break;case LANGUAGE:selectLanguage(static_cast<Language>(selection(id)));return;case APPEARANCE:settings.appearance=selection(id);break;case FLAKESTYLE:settings.snowflakeStyle=selection(id);break;case CLEANER:settings.cleaner=selection(id);break;case STYLE:settings.style=selection(id);break;case MODE:settings.garland=selection(id);break;case PALETTE:settings.palette=selection(id);break;case QUALITY:settings.quality=selection(id);break;case SCENEMONITOR:sceneMonitor=selection(id);buildPane();return;case SCENEKIND:{if(sceneMonitor>=0&&sceneMonitor<int(monitors.size())){auto device=monitors[sceneMonitor].device;settings.scenes[device]=selection(id);for(auto&o:overlays)if(o->monitor.device==device)configureBackground(*o);}break;}default:return;}changed();return;}
  if(notification!=BN_CLICKED)return;
  if(selectSettingsCard(id))return;
  switch(id){case SIDEBAR_LANGUAGE:languageMenu();return;case FULL_PAUSE:togglePause();return;
   case DISPLAY_MENU:displayMenu(findControl(controls,DISPLAY_MENU));return;
   case STARTUP_SETTINGS:ShellExecuteW(settingsWindow,L"open",L"ms-settings:startupapps",nullptr,nullptr,SW_SHOWNORMAL);return;
   case SWEEP:settings.sweep=checked(id);break;case TREE:growTree(checked(id));break;case WINDRESET:settings.wind=0;buildPane();break;case ACCWINDOWS:settings.windows=checked(id);break;case ACCBOTTOM:settings.bottom=checked(id);break;case TASKBAR:settings.taskbar=checked(id);break;case VERTICAL:settings.verticalTaskbar=checked(id);break;case MITTEN:play(1);return;case SNOWBALL:play(0);return;case SHOVEL:if(showShovel)play(2);return;case DELETE_TOOL:if(showDeleteTool)play(3);return;case AUTHOR:ShellExecuteW(settingsWindow,L"open",L"https://t.me/Radion013",nullptr,nullptr,SW_SHOWNORMAL);return;case CLEAR:clearSnow();return;case RUNCLEANER:runCleaner();return;case AUTOCLEANER:settings.automaticCleaner=checked(id);break;case BLADE:settings.bladeImage=checked(id);break;case IMPORT:importImage();return;case ALLMONITORS:settings.allDisplays=checked(id);save();rebuild();return;case REDUCEMOTION:settings.reduceMotion=checked(id);break;case LOGIN:setLogin(checked(id));return;case RESET:if(MessageBoxW(settingsWindow,tr(L"Вернуть настройки по умолчанию? Язык, импортированная картинка и автозапуск сохранятся."),tr(L"Сбросить настройки"),MB_YESNO|MB_ICONQUESTION)==IDYES){settings=Settings{};save();rebuild();syncFull();}return;default:if(id>=1801&&id<1817){int i=id-1801;if(i<int(monitors.size())){if(checked(id))settings.displays.insert(monitors[i].device);else settings.displays.erase(monitors[i].device);save();rebuild();}}return;}changed(id==ACCWINDOWS||id==ACCBOTTOM||id==TASKBAR||id==VERTICAL);}
 void importImage(){wchar_t file[32768]{};OPENFILENAMEW open{sizeof(open)};open.hwndOwner=settingsWindow;open.lpstrFile=file;open.nMaxFile=32768;open.lpstrFilter=appLanguage==Language::russian?L"Изображения\0*.png;*.jpg;*.jpeg;*.heic;*.heif\0Все файлы\0*.*\0":L"Images\0*.png;*.jpg;*.jpeg;*.heic;*.heif\0All Files\0*.*\0";open.Flags=OFN_FILEMUSTEXIST|OFN_PATHMUSTEXIST;if(!GetOpenFileNameW(&open))return;
  WIN32_FILE_ATTRIBUTE_DATA data{};GetFileAttributesExW(file,GetFileExInfoStandard,&data);uint64_t bytes=(uint64_t(data.nFileSizeHigh)<<32)|data.nFileSizeLow;HRESULT hr=bytes&&bytes<=20*1024*1024?S_OK:E_FAIL;
  IWICImagingFactory*f=nullptr;IWICBitmapDecoder*d=nullptr;IWICBitmapFrameDecode*frame=nullptr;IWICBitmapScaler*scaler=nullptr;IWICBitmapEncoder*encoder=nullptr;IWICStream*stream=nullptr;IWICBitmapFrameEncode*out=nullptr;
  std::wstring target=home+L"\\blade.new.png";
  if(SUCCEEDED(hr))hr=CoCreateInstance(CLSID_WICImagingFactory,nullptr,CLSCTX_INPROC_SERVER,IID_IWICImagingFactory,(void**)&f);
  if(SUCCEEDED(hr))hr=f->CreateDecoderFromFilename(file,nullptr,GENERIC_READ,WICDecodeMetadataCacheOnDemand,&d);if(SUCCEEDED(hr))hr=d->GetFrame(0,&frame);UINT w=0,h=0;if(SUCCEEDED(hr))hr=frame->GetSize(&w,&h);if(!w||!h||w>20000||h>20000||uint64_t(w)*h>80000000)hr=E_FAIL;
  if(SUCCEEDED(hr))hr=f->CreateBitmapScaler(&scaler);double scale=std::min(1.,1024./std::max(w,h));if(SUCCEEDED(hr))hr=scaler->Initialize(frame,std::max(1u,UINT(w*scale)),std::max(1u,UINT(h*scale)),WICBitmapInterpolationModeFant);
  if(SUCCEEDED(hr))hr=f->CreateStream(&stream);if(SUCCEEDED(hr))hr=stream->InitializeFromFilename(target.c_str(),GENERIC_WRITE);if(SUCCEEDED(hr))hr=f->CreateEncoder(GUID_ContainerFormatPng,nullptr,&encoder);if(SUCCEEDED(hr))hr=encoder->Initialize(stream,WICBitmapEncoderNoCache);if(SUCCEEDED(hr))hr=encoder->CreateNewFrame(&out,nullptr);if(SUCCEEDED(hr))hr=out->Initialize(nullptr);if(SUCCEEDED(hr))hr=out->WriteSource(scaler,nullptr);if(SUCCEEDED(hr))hr=out->Commit();if(SUCCEEDED(hr))hr=encoder->Commit();
  if(out)out->Release();if(encoder)encoder->Release();if(stream)stream->Release();if(scaler)scaler->Release();if(frame)frame->Release();if(d)d->Release();if(f)f->Release();
  if(SUCCEEDED(hr)){badge.reset();bool replaced=MoveFileExW(target.c_str(),(home+L"\\blade.png").c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)!=FALSE;badge=std::make_unique<Gdiplus::Bitmap>((home+L"\\blade.png").c_str());if(badge->GetLastStatus()!=Gdiplus::Ok)badge.reset();if(replaced&&badge){settings.bladeImage=true;changed();buildPane();return;}}DeleteFileW(target.c_str());MessageBoxW(settingsWindow,tr(L"Не удалось импортировать изображение. Подойдут PNG/JPEG до 20 МБ и 80 Мп. Для HEIC нужен системный кодек. Предыдущая картинка сохранена."),tr(L"Снег"),MB_ICONERROR);
 }
 void configureBackground(Overlay&o){if(o.background){DestroyWindow(o.background);o.background=nullptr;}if(!showWinterScenes)return;int kind=settings.scenes[o.monitor.device];if(!kind)return;HWND progman=FindWindowW(L"Progman",nullptr);DWORD_PTR result=0;if(progman)SendMessageTimeoutW(progman,0x052C,0,0,SMTO_ABORTIFHUNG,1000,&result);HWND worker=nullptr;EnumWindows([](HWND h,LPARAM p)->BOOL{if(FindWindowExW(h,nullptr,L"SHELLDLL_DefView",nullptr)){*(HWND*)p=FindWindowExW(nullptr,h,L"WorkerW",nullptr);if(*(HWND*)p)return FALSE;}return TRUE;},(LPARAM)&worker);if(!worker)return;POINT p{o.monitor.frame.left,o.monitor.frame.top};ScreenToClient(worker,&p);o.background=CreateWindowExW(WS_EX_TRANSPARENT|WS_EX_NOACTIVATE|WS_EX_TOOLWINDOW,BACKGROUNDCLASS,L"",WS_CHILD|WS_VISIBLE,p.x,p.y,o.monitor.frame.right-o.monitor.frame.left,o.monitor.frame.bottom-o.monitor.frame.top,worker,nullptr,instance,&o);SetWindowPos(o.background,HWND_BOTTOM,p.x,p.y,o.monitor.frame.right-o.monitor.frame.left,o.monitor.frame.bottom-o.monitor.frame.top,SWP_NOACTIVATE);}
 void diagnostics(){
  KillTimer(tray,2);std::map<std::string,bool>checks;
  {
   const RECT display{-1920,-160,0,920},work{-1920,-160,0,872},bar{-1920,872,0,920};
   const RECT otherBar{0,872,1920,920},sideBar{-1920,-160,-1872,920},topBar{-1920,-160,0,-112};
   checks["treesFollowFixedBottomTaskbarOnTheirMonitor"]=
    bottomTaskbarInset(display,work,{otherBar,bar})==48&&bottomTaskbarInset(display,work,{otherBar})==0;
   checks["treesUseScreenEdgeWithoutFixedBottomTaskbar"]=
    bottomTaskbarInset(display,display,{bar})==0&&bottomTaskbarInset(display,work,{sideBar,topBar})==0&&
    bottomTaskbarInset(display,work,{})==0;
   checks["treesGrowAboveTaskbarAndTouchItsEdge"]=true;
   constexpr int width=960,height=420,edge=372;
   for(double dpi:{1.,1.25}){
    Simulation sample({width/dpi,height/dpi});
    sample.growTree(true);
    const double inset=(height-edge)/dpi;
    Gdiplus::Bitmap canvas(width,height,PixelFormat32bppPARGB);
    for(double growth:{.35,1.}){
     sample.treeGrowth=growth;
     {
      Gdiplus::Graphics graphics(&canvas);
      graphics.Clear(Gdiplus::Color(0,0,0,0));
      graphics.TranslateTransform(0,height);
      graphics.ScaleTransform(REAL(dpi),REAL(-dpi));
      Painter(graphics).tree(sample,settings,true,inset);
     }
     Gdiplus::Color pixel;
     bool clear=true;
     for(int y=edge;y<height&&clear;y++)for(int x=0;x<width&&clear;x++)
      clear=canvas.GetPixel(x,y,&pixel)==Gdiplus::Ok&&pixel.GetA()==0;
     checks["treesGrowAboveTaskbarAndTouchItsEdge"]&=clear;
     if(growth==1.)for(const auto& pose:sample.treePoses(inset)){
      canvas.GetPixel(int(pose.p.x*dpi),edge-1,&pixel);
      checks["treesGrowAboveTaskbarAndTouchItsEdge"]&=pixel.GetA()>64;
     }
    }
   }
  }
  {
   constexpr int cell=24,width=cell*8,height=32;
   Settings sample;
   sample.snowflakeStyle=1;
   sample.snowflakeSize=.5;
   const double dpi=1;
   Simulation crystals({width,height});
   for(int i=0;i<8;i++)
    crystals.particles.push_back({{(i+.5)*cell,16.25},55,0,1.6,.85,120,false,0,0,uint64_t(i)});
   auto capture=[&](bool reduce,const RECT* clip=nullptr){
    std::vector<uint32_t> pixels(size_t(width)*height);
    patternedFlakes.draw(pixels.data(),width,height,dpi,crystals,sample,reduce,clip,clip?1:0);
    return pixels;
   };
   const auto first=capture(true);
   checks["allEightSmallPatternsHaveVisibleCoverage"]=true;
   for(int i=0;i<8;i++){
    int solid=0;
    for(int y=0;y<height;y++)for(int x=i*cell;x<(i+1)*cell;x++)
     if((first[size_t(y)*width+x]>>24)>64)solid++;
    checks["allEightSmallPatternsHaveVisibleCoverage"]&=solid>=5;
   }
   crystals.time=2.7;
   checks["reducedMotionFreezesPatternRotation"]=first==capture(true)&&first!=capture(false);
   for(auto& particle:crystals.particles)particle.p.x+=.35;
   checks["patternedFlakesMoveAtSubpixelPositions"]=first!=capture(true);
   RECT clip{cell/2,0,width/2,height};
   const auto cropped=capture(true,&clip);
   bool clipped=true,visible=false;
   for(int y=0;y<height;y++)for(int x=0;x<width;x++){
    if(x>=clip.left&&x<clip.right)clipped&=cropped[size_t(y)*width+x]==0;
    else visible|=cropped[size_t(y)*width+x]!=0;
   }
   checks["patternsStayOutsideSettingsWindows"]=clipped&&visible;
  }
  Settings previous=settings;settings.bottom=true;readGeometry();showSettings();
  checks["nineVisibleSectionsWithoutWinterScenes"]=SendMessageW(sidebar,LB_GETCOUNT,0,0)==9;
  selectedPane=0;buildPane();checks["snowMaterialAndFlakeControls"]=controls.count(SEG_MATERIAL+1)&&controls.count(SEG_FLAKES+1)&&controls.count(FLAKESIZE);
  checks["macSettingsShellAndPreview"]=brandIcon&&status&&languageButton&&pageTitle&&pageSubtitle&&pagePause&&pageFooter&&
   controls.count(FULL_PREVIEW)&&controls.count(DISPLAY_MENU);
  auto nativeClick=[&](int id){
   HWND item=findControl(controls,id);
   SendMessageW(pane,WM_COMMAND,MAKEWPARAM(id,BN_CLICKED),(LPARAM)item);
  };
  nativeClick(SEG_MATERIAL+1);nativeClick(SEG_FLAKES+1);
  SendMessageW(controls[FLAKESIZE],TBM_SETPOS,TRUE,170);
  SendMessageW(pane,WM_HSCROLL,0,(LPARAM)controls[FLAKESIZE]);
  checks["graphiteSegmentsAndNativeSliderApply"]=settings.appearance==1&&settings.snowflakeStyle==1&&
   std::abs(settings.snowflakeSize-1.7)<.001;
  HWND sliderControl=controls[FLAKESIZE];
  RECT sliderRect{};GetClientRect(sliderControl,&sliderRect);
  int thumb=sliderThumbSize(sliderControl),range=sliderRect.right-thumb,y=sliderRect.bottom/2;
  int from=thumb/2+MulDiv(range,120,250),to=thumb/2+MulDiv(range,100,250);
  SendMessageW(sliderControl,WM_LBUTTONDOWN,MK_LBUTTON,MAKELPARAM(from,y));
  SendMessageW(sliderControl,WM_MOUSEMOVE,MK_LBUTTON,MAKELPARAM(to,y));
  SendMessageW(sliderControl,WM_LBUTTONUP,0,MAKELPARAM(to,y));
  checks["skinnedSliderDragTracksDrawnThumb"]=std::abs(settings.snowflakeSize-1.5)<.001&&
   SendMessageW(sliderControl,TBM_GETPOS,0,0)==150&&GetCapture()!=sliderControl;
  HWND weatherFirst=controls[SEG_WEATHER];
  nativeClick(SEG_WEATHER);
  RedrawWindow(weatherFirst,nullptr,nullptr,RDW_INVALIDATE|RDW_UPDATENOW);
  auto group=segmentStrips.find(SEG_WEATHER);
  checks["segmentGroupHasRoundedOuterCornersAndStraightJoins"]=false;
  if(group!=segmentStrips.end()&&group->second.pixels){
   auto& strip=*group->second.pixels;
   auto seam=group->second.geometry[2];
   Gdiplus::Color corner,edge,selected,nearLeft,nearRight;
   strip.GetPixel(0,0,&corner);
   strip.GetPixel(px(6),1,&edge);
   strip.GetPixel(seam/2,strip.GetHeight()/2,&selected);
   strip.GetPixel(seam-1,0,&nearLeft);
   strip.GetPixel(seam,0,&nearRight);
   checks["segmentGroupHasRoundedOuterCornersAndStraightJoins"]=
    corner.GetR()==GetRValue(settingsTheme::background)&&edge.GetR()>60&&selected.GetR()>128&&
    nearLeft.GetR()>45&&std::abs(int(nearLeft.GetR())-int(nearRight.GetR()))<=3;
  }
  checks["fluentCornersAndSwitchesAt100125150200Percent"]=true;
  for(int dpi:{96,120,144,192}){
   auto scaled=[&](int units){return MulDiv(units,dpi,96);};
   const int width=scaled(settingsTheme::switchWidth),height=scaled(settingsTheme::switchHeight);
   const int thumb=scaled(settingsTheme::switchThumb);
   Gdiplus::Bitmap samples(width,height*4,PixelFormat32bppPARGB);
   {
    Gdiplus::Graphics g(&samples);
    g.Clear(settingsTheme::color(settingsTheme::background));
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    settingsTheme::solidSurface(g,settingsTheme::frame({0,0,width,height}),float(scaled(settingsTheme::controlRadius)),0xDADAE2);
    settingsTheme::solidSurface(g,settingsTheme::frame({0,height,width,height*2}),float(scaled(settingsTheme::overlayRadius)),0xDADAE2);
    settingsTheme::toggle(g,settingsTheme::frame({0,height*2,width,height*3}),float(thumb),false,false,false);
    settingsTheme::toggle(g,settingsTheme::frame({0,height*3,width,height*4}),float(thumb),true,false,false);
   }
   Gdiplus::Color controlCorner,overlayCorner,offThumb,offTrack,onThumb,onTrack;
   samples.GetPixel(scaled(3),scaled(1),&controlCorner);
   samples.GetPixel(scaled(3),height+scaled(1),&overlayCorner);
   samples.GetPixel(scaled(10),height*2+height/2,&offThumb);
   samples.GetPixel(scaled(30),height*2+height/2,&offTrack);
   samples.GetPixel(scaled(30),height*3+height/2,&onThumb);
   samples.GetPixel(scaled(10),height*3+height/2,&onTrack);
   const bool geometryMatches=
    controlCorner.GetR()>overlayCorner.GetR()+64&&overlayCorner.GetR()<72&&offThumb.GetR()>160&&offTrack.GetR()<80&&
    onThumb.GetR()<80&&onTrack.GetR()>150;
   checks["fluentCornersAndSwitchesAt100125150200Percent"]&=geometryMatches;
   if(!geometryMatches){
    std::ostringstream detail;
    detail<<"Corner and switch samples at DPI "<<dpi<<": "
          <<int(controlCorner.GetR())<<' '<<int(overlayCorner.GetR())<<' '
          <<int(offThumb.GetR())<<' '<<int(offTrack.GetR())<<' '
          <<int(onThumb.GetR())<<' '<<int(onTrack.GetR())<<'\n';
    const auto line=detail.str();
    DWORD written=0;
    WriteFile(GetStdHandle(STD_ERROR_HANDLE),line.data(),DWORD(line.size()),&written,nullptr);
   }
  }
  HWND treeControl=controls[TREE];
  ValidateRect(treeControl,nullptr);
  updateStatus();
  checks["unchangedTreeToggleStaysIdle"]=!GetUpdateRect(treeControl,nullptr,FALSE);
  selectedPane=5;buildPane();
  nativeClick(STYLE_CARDS+2);
  bool lights=settings.style==2&&settings.garland==1&&IsWindowEnabled(controls[PALETTE]);
  SendMessageW(controls[MODE],CB_SETCURSEL,2,0);
  SendMessageW(pane,WM_COMMAND,MAKEWPARAM(MODE,CBN_SELCHANGE),(LPARAM)controls[MODE]);
  SendMessageW(controls[PALETTE],CB_SETCURSEL,0,0);
  SendMessageW(pane,WM_COMMAND,MAKEWPARAM(PALETTE,CBN_SELCHANGE),(LPARAM)controls[PALETTE]);
  checks["garlandCardsAndNativePopupsApply"]=lights&&settings.garland==2&&settings.palette==0;
  selectedPane=8;buildPane();
  nativeClick(QUALITY_CARDS+1);
  RedrawWindow(controls[QUALITY_CARDS+1],nullptr,nullptr,RDW_INVALIDATE|RDW_UPDATENOW);
  checks["qualityRowsShareOneRoundedFrame"]=false;
  auto qualityStrip=segmentStrips.find(QUALITY_CARDS);
  if(qualityStrip!=segmentStrips.end()&&qualityStrip->second.pixels){
   auto& pixels=*qualityStrip->second.pixels;
   int x=int(pixels.GetWidth()/2),boundary=qualityStrip->second.geometry[2];
   Gdiplus::Color corner,topRow,middleRow,divider;
   pixels.GetPixel(0,0,&corner);
   pixels.GetPixel(x,boundary/2,&topRow);
   pixels.GetPixel(x,boundary+boundary/2,&middleRow);
   pixels.GetPixel(x,boundary,&divider);
   checks["qualityRowsShareOneRoundedFrame"]=corner.GetR()==GetRValue(settingsTheme::background)&&
    middleRow.GetR()>topRow.GetR()&&divider.GetR()>middleRow.GetR();
  }
  settings.quality=previous.quality;
  selectedPane=4;buildPane();wchar_t buttonText[80]{};GetWindowTextW(controls[RUNCLEANER],buttonText,80);
  checks["cleanerButtonAndHiddenBladeImport"]=std::wstring(buttonText)==L"Run Snow Cleaner"&&controls.count(CLEAR)&&!controls.count(BLADE)&&!controls.count(IMPORT);
  checks["defaultEnglish"]=appLanguage==Language::english&&std::wstring(tr(L"Снег"))==L"Snow";
  int weather=settings.weather;
  showQuick(false);
  checks["quickControlsAndHiddenFeatures"]=quickWindow&&quickControls.count(QUICK_OPEN)&&
   quickControls.count(QUICK_PREVIEW)&&quickControls.count(WIND)&&quickControls.count(FLAKESTYLE)&&
   quickControls.count(TREE)&&quickControls.count(CLEAR)&&quickControls.count(RUNCLEANER)&&
   quickControls.count(MITTEN)&&quickControls.count(SNOWBALL)&&!quickControls.count(SHOVEL)&&
   !quickControls.count(DELETE_TOOL)&&!quickControls.count(ALLMONITORS);
  RECT quickBounds{};GetWindowRect(quickWindow,&quickBounds);
  MONITORINFO quickMonitor{sizeof(quickMonitor)};
  GetMonitorInfoW(MonitorFromWindow(quickWindow,MONITOR_DEFAULTTONEAREST),&quickMonitor);
  checks["quickPanelFitsWorkArea"]=quickBounds.left>=quickMonitor.rcWork.left&&quickBounds.top>=quickMonitor.rcWork.top&&
   quickBounds.right<=quickMonitor.rcWork.right&&quickBounds.bottom<=quickMonitor.rcWork.bottom;
  RECT quickClient{};GetClientRect(quickWindow,&quickClient);
  MoveWindow(quickPane,0,0,quickClient.right,qp(350),FALSE);
  buildQuick();
  scrollPane(quickPane,qp(673));
  RECT bottomCommand{},shortPane{};
  GetWindowRect(findControl(quickControls,QUICK_OPEN),&bottomCommand);
  GetWindowRect(quickPane,&shortPane);
  checks["shortQuickPanelScrollsToAllSettings"]=bottomCommand.bottom<=shortPane.bottom&&
   bottomCommand.top>shortPane.top;
  MoveWindow(quickPane,0,0,quickClient.right,quickClient.bottom,TRUE);
  buildQuick();
  SendMessageW(findControl(quickControls,QUICK_LIGHT+2),BM_CLICK,0,0);
  selectLanguage(Language::russian);
  GetWindowTextW(findControl(quickControls,QUICK_LIGHT+2),buttonText,80);
  checks["liveLanguageKeepsPaneAndSettings"]=selectedPane==4&&settings.weather==2&&std::wstring(buttonText)==L"Метель";
  selectLanguage(Language::english);
  settings.weather=weather;
  HWND snowball=findControl(quickControls,SNOWBALL);
  const auto click=[&](HWND control){
   SendMessageW(quickPane,WM_COMMAND,MAKEWPARAM(GetDlgCtrlID(control),BN_CLICKED),(LPARAM)control);
  };
  click(snowball);
  bool started=interactive&&settings.tool==0;
  click(snowball);
  bool toggledOff=!interactive&&IsWindowVisible(quickWindow);
  click(snowball);
  if(interactive)SendMessageW(interactive->window,WM_KEYDOWN,VK_ESCAPE,0);
  checks["quickToolTogglesAndEscapeRestoresInput"]=started&&toggledOff&&!interactive;
  togglePause();
  checks["pauseDisablesCleanerButKeepsMelt"]=!IsWindowEnabled(findControl(quickControls,RUNCLEANER))&&IsWindowEnabled(findControl(quickControls,CLEAR));
  togglePause();
  ShowWindow(quickWindow,SW_HIDE);
  ShowWindow(settingsWindow,SW_HIDE);
  settings.appearance=1;settings.snowflakeStyle=1;settings.snowflakeSize=3;renderAll();
  checks["monitorsCreated"]=!overlays.empty();checks["trayCreated"]=tray!=nullptr;
  checks["clickThrough"]=checks["layered"]=checks["framePresented"]=!overlays.empty();
  for(auto&o:overlays){checks["clickThrough"]&=(GetWindowLongPtrW(o->window,GWL_EXSTYLE)&WS_EX_TRANSPARENT)!=0;checks["layered"]&=(GetWindowLongPtrW(o->window,GWL_EXSTYLE)&WS_EX_LAYERED)!=0;checks["framePresented"]&=o->rendered;}
  growTree(true);checks["treeDoesNotCaptureInput"]=anyTree()&&interactive==nullptr;
  checks["fiveEnlargedTreesFromFinalMac"]=false;for(auto&o:overlays)if(o->sim->tree){auto poses=o->sim->treePoses();checks["fiveEnlargedTreesFromFinalMac"]=poses.size()==5&&std::all_of(poses.begin(),poses.end(),[](auto&p){return p.sy*270<=125.001;});}
  checks["treeUsesFiveSharedRasterLayers"]=true;for(int i=0;i<5;i++)checks["treeUsesFiveSharedRasterLayers"]&=Painter::artCache().count(i)>0;
  {Gdiplus::Bitmap probe(64,64,PixelFormat32bppPARGB);{Gdiplus::Graphics g(&probe);g.Clear(Gdiplus::Color(0,0,0,0));Painter painter(g);painter.sphere({32,32},24,true);}Gdiplus::Color pixel;checks["texturedSnowRasterCreated"]=probe.GetPixel(32,32,&pixel)==Gdiplus::Ok&&pixel.GetA()>240&&pixel.GetR()>150;}
  checks["fourSnowmenDrawInBothMaterials"]=true;
  for(int material=0;material<2;material++){
   Settings sample;sample.appearance=material;
   auto preview=makeSettingsPreview(960,330,3,sample);
   for(int i=0;i<4;i++){
    int x=120+i*240;
    Gdiplus::Color eye,nose;
    preview->GetPixel(x-6,117,&eye);
    preview->GetPixel(x+2,125,&nose);
    checks["fourSnowmenDrawInBothMaterials"]&=eye.GetR()<160&&nose.GetR()>160&&nose.GetB()<120;
   }
  }
  settings.tool=0;enterGame();checks["gameReceivesInputAtTransparentPixels"]=interactive&&SendMessageW(interactive->window,WM_NCHITTEST,0,0)==HTCLIENT;
  if(interactive){auto*o=interactive;auto&profile=o->sim->profiles.at(bottomID);for(double x=0;x<=profile.width;x+=4)profile.deposit(x,200);
   auto position=[&](V p){return MAKELPARAM(int(p.x*o->dpi),int((o->sim->size.y-p.y)*o->dpi));};
   SendMessageW(o->window,WM_LBUTTONDOWN,MK_LBUTTON,position({100,5}));checks["mousePressImmediatelyCreatesBall"]=o->sim->game.dragged!=0&&o->sim->game.balls.size()==1;
   Sleep(20);SendMessageW(o->window,WM_MOUSEMOVE,MK_LBUTTON,position({240,200}));SendMessageW(o->window,WM_LBUTTONUP,0,position({240,200}));checks["mouseFlickLaunchesGlassSnowball"]=o->sim->game.flights.size()==1;
   o->sim->game.clear();settings.tool=1;SendMessageW(o->window,WM_LBUTTONDOWN,MK_LBUTTON,position({350,5}));checks["mouseMittenLiftsLooseSnow"]=o->sim->game.balls.size()==1&&o->sim->game.balls[0].loose;SendMessageW(o->window,WM_LBUTTONUP,0,position({350,5}));
  }else{checks["mousePressImmediatelyCreatesBall"]=checks["mouseFlickLaunchesGlassSnowball"]=checks["mouseMittenLiftsLooseSnow"]=false;}
  exitGame(false);checks["leavingGameRestoresClickThrough"]=std::all_of(overlays.begin(),overlays.end(),[](auto&o){return(GetWindowLongPtrW(o->window,GWL_EXSTYLE)&WS_EX_TRANSPARENT)!=0;});
  growTree(false);checks["treeRemoves"]=!anyTree();
  for(auto&o:overlays)if(!o->fullscreen)o->sim->cleaner.start(0);
  checks["cleanerStarts"]=std::any_of(overlays.begin(),overlays.end(),[](auto&o){return o->sim->cleaner.active;});
  clearSnow();checks["clearRemovesBalls"]=std::all_of(overlays.begin(),overlays.end(),[](auto&o){return o->sim->game.balls.empty();});
  hidden=true;renderAll();checks["hideClosesOverlays"]=std::all_of(overlays.begin(),overlays.end(),[](auto&o){return !IsWindowVisible(o->window);});hidden=false;renderAll();
  std::ostringstream out;out<<"{\n";bool first=true;
  for(auto&c:checks){diagnosticFailed|=!c.second;if(!first)out<<",\n";first=false;out<<"  \""<<c.first<<"\": "<<(c.second?"true":"false");}
  out<<"\n}\n";std::string text=out.str();DWORD written=0;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),text.data(),DWORD(text.size()),&written,nullptr);settings=previous;DestroyWindow(tray);
 }
};

static LRESULT CALLBACK trayProc(HWND h,UINT m,WPARAM w,LPARAM l){if(!app)return DefWindowProcW(h,m,w,l);switch(m){case WM_TIMER:if(w==1&&!app->preciseFrames)app->tick();else if(w==2)app->diagnostics();return 0;case FRAME_MESSAGE:app->precisionFrame();return 0;case TRAY_MESSAGE:if(LOWORD(l)==WM_RBUTTONUP||LOWORD(l)==WM_CONTEXTMENU)app->menu();else if(LOWORD(l)==WM_LBUTTONUP||LOWORD(l)==NIN_SELECT||LOWORD(l)==NIN_KEYSELECT)app->showQuick();return 0;case WM_DISPLAYCHANGE:app->rebuild();if(app->quickWindow&&IsWindowVisible(app->quickWindow))app->showQuick(false);return 0;case WM_POWERBROADCAST:if(w==PBT_APMSUSPEND){app->sleeping=true;app->exitGame(false);app->updateTimer();app->renderAll();}else if(w==PBT_APMRESUMEAUTOMATIC||w==PBT_APMRESUMESUSPEND){app->sleeping=false;app->updateTimer();app->readGeometry();app->renderAll();}return TRUE;case WM_WTSSESSION_CHANGE:if(w==WTS_SESSION_LOCK||w==WTS_SESSION_LOGOFF){app->locked=true;app->exitGame(false);}else if(w==WTS_SESSION_UNLOCK||w==WTS_SESSION_LOGON)app->locked=false;app->updateTimer();app->renderAll();return 0;case WM_SETTINGCHANGE:app->updateTimer();return 0;case WM_CLOSE:DestroyWindow(h);return 0;case WM_QUERYENDSESSION:app->save();return TRUE;case WM_DESTROY:app->shutdown();PostQuitMessage(0);return 0;default:break;}static UINT taskbarCreated=RegisterWindowMessageW(L"TaskbarCreated");if(m==taskbarCreated&&!app->diagnostic){Shell_NotifyIconW(NIM_ADD,&app->nid);Shell_NotifyIconW(NIM_SETVERSION,&app->nid);}if(m==WM_APP+10){app->showSettings();return 0;}return DefWindowProcW(h,m,w,l);}
static LRESULT CALLBACK overlayProc(HWND h,UINT m,WPARAM w,LPARAM l){auto*o=(Overlay*)GetWindowLongPtrW(h,GWLP_USERDATA);if(m==WM_NCCREATE){o=(Overlay*)((CREATESTRUCTW*)l)->lpCreateParams;SetWindowLongPtrW(h,GWLP_USERDATA,(LONG_PTR)o);}if(!app||!o)return DefWindowProcW(h,m,w,l);switch(m){case WM_NCHITTEST:return app->interactive==o?HTCLIENT:HTTRANSPARENT;case WM_MOUSEACTIVATE:return app->interactive==o?MA_ACTIVATE:MA_NOACTIVATE;case WM_KEYDOWN:if(w==VK_ESCAPE){app->exitGame();return 0;}break;case WM_KILLFOCUS:if(app->interactive==o&&!app->isSnowUi((HWND)w))app->exitGame(false);return 0;case WM_LBUTTONDOWN:if(app->interactive!=o)return 0;SetCapture(h);if(app->settings.tool==0||app->settings.tool==1)o->sim->game.begin(o->mouse(l),now(),o->sim->surfaces,o->sim->profiles,app->settings.tool==1);else if(app->settings.tool==3)o->sim->game.remove(o->mouse(l),o->sim->surfaces);else o->sim->sweep(o->mouse(l),app->settings.tool,app->settings.limit());app->render(*o);return 0;case WM_MOUSEMOVE:if(app->interactive==o&&(w&MK_LBUTTON)){if(app->settings.tool==0||app->settings.tool==1)o->sim->game.drag(o->mouse(l),now(),o->sim->surfaces,o->sim->profiles);else if(app->settings.tool!=3)o->sim->sweep(o->mouse(l),app->settings.tool,app->settings.limit());}return 0;case WM_LBUTTONUP:if(app->interactive==o){o->sim->game.end(o->mouse(l),now(),o->sim->surfaces,o->sim->profiles,app->settings.tool==0);ReleaseCapture();app->render(*o);}return 0;case WM_RBUTTONDOWN:if(showDeleteTool&&app->interactive==o)o->sim->game.remove(o->mouse(l),o->sim->surfaces);return 0;case WM_ERASEBKGND:return 1;case WM_PAINT:ValidateRect(h,nullptr);return 0;case WM_DPICHANGED:PostMessageW(app->tray,WM_DISPLAYCHANGE,0,0);return 0;}return DefWindowProcW(h,m,w,l);}
static LRESULT CALLBACK settingProc(HWND h,UINT m,WPARAM w,LPARAM l){
 if(!app)return DefWindowProcW(h,m,w,l);
 switch(m){
  case WM_MEASUREITEM:if(w==SIDEBAR){((MEASUREITEMSTRUCT*)l)->itemHeight=app->px(42);return TRUE;}break;
  case WM_ERASEBKGND:app->paintSettingsShell((HDC)w);return TRUE;
  case WM_VSCROLL:if((HWND)l==app->settingsScroll){app->requestScroll(app->pane,LOWORD(w));return 0;}break;
  case WM_GETMINMAXINFO:{
   auto* size=(MINMAXINFO*)l;
   MONITORINFO info{sizeof(info)};
   if(GetMonitorInfoW(MonitorFromWindow(h,MONITOR_DEFAULTTONEAREST),&info)){
    size->ptMinTrackSize.x=std::min<int>(app->px(640),info.rcWork.right-info.rcWork.left);
    size->ptMinTrackSize.y=std::min<int>(app->px(420),info.rcWork.bottom-info.rcWork.top);
   }
   return 0;
  }
  case WM_DRAWITEM:if(w==SIDEBAR)app->drawSidebar(*(DRAWITEMSTRUCT*)l);else app->drawSettingsControl(*(DRAWITEMSTRUCT*)l,false);return TRUE;
  case WM_CTLCOLORSTATIC:case WM_CTLCOLORLISTBOX:return app->controlColors(m,(HDC)w,(HWND)l);
  case WM_COMMAND:app->command(LOWORD(w),HIWORD(w));return 0;
  case WM_SIZE:app->layout();return 0;
  case WM_CLOSE:ShowWindow(h,SW_HIDE);return 0;
  case WM_DPICHANGED:{
   auto* r=(RECT*)l;
   app->uiScale=HIWORD(w)/96.;
   app->makeFonts();
   if(app->sidebar)SendMessageW(app->sidebar,LB_SETITEMHEIGHT,0,app->px(42));
   SetWindowPos(h,nullptr,r->left,r->top,r->right-r->left,r->bottom-r->top,SWP_NOZORDER|SWP_NOACTIVATE);
   app->layout();
   return 0;
  }
 }
 return DefWindowProcW(h,m,w,l);
}
static LRESULT CALLBACK quickProc(HWND h,UINT m,WPARAM w,LPARAM l){
 if(m==WM_VSCROLL&&app&&(HWND)l==app->quickScroll){app->requestScroll(app->quickPane,LOWORD(w));return 0;}
 if(m==WM_CLOSE){ShowWindow(h,SW_HIDE);return 0;}
 if(m==WM_ACTIVATE&&LOWORD(w)==WA_INACTIVE&&app&&!app->isSnowUi((HWND)l)&&
    (!app->interactive||app->interactive->window!=(HWND)l)&&app->quickWindow&&IsWindowVisible(h))ShowWindow(h,SW_HIDE);
 return DefWindowProcW(h,m,w,l);
}
static LRESULT CALLBACK paneProc(HWND h,UINT m,WPARAM w,LPARAM l){
 if(!app)return DefWindowProcW(h,m,w,l);
 const bool quick=h==app->quickPane;
 switch(m){
  case WM_COMMAND:
   if(HIWORD(w)==CBN_DROPDOWN){
    COMBOBOXINFO combo{sizeof(combo)};
    if(GetComboBoxInfo((HWND)l,&combo))App::preferRoundedWindow(combo.hwndList);
    return 0;
   }
   if(quick)app->quickCommand(LOWORD(w),HIWORD(w),(HWND)l);
   else app->command(LOWORD(w),HIWORD(w));
   return 0;
  case WM_MEASUREITEM:
   if(((MEASUREITEMSTRUCT*)l)->CtlType==ODT_COMBOBOX){
    ((MEASUREITEMSTRUCT*)l)->itemHeight=quick?app->qp(23):app->px(25);
    return TRUE;
   }
   break;
  case WM_DRAWITEM:app->drawSettingsControl(*(DRAWITEMSTRUCT*)l,quick);return TRUE;
  case WM_CTLCOLORSTATIC:case WM_CTLCOLORBTN:case WM_CTLCOLORLISTBOX:return app->controlColors(m,(HDC)w,(HWND)l);
  case WM_NOTIFY:{
   auto* notification=(NMHDR*)l;
   if(notification&&notification->code==NM_CUSTOMDRAW&&className(notification->hwndFrom)==TRACKBAR_CLASSW)
    return CDRF_SKIPDEFAULT;
   break;
  }
  case WM_HSCROLL:app->onScroll((HWND)l);return 0;
  case WM_MOUSEWHEEL:app->requestScroll(h,GET_WHEEL_DELTA_WPARAM(w)>0?SB_LINEUP:SB_LINEDOWN);return 0;
  case WM_VSCROLL:app->requestScroll(h,LOWORD(w));return 0;
 }
 return DefWindowProcW(h,m,w,l);
}
static LRESULT CALLBACK backgroundProc(HWND h,UINT m,WPARAM w,LPARAM l){auto*o=(Overlay*)GetWindowLongPtrW(h,GWLP_USERDATA);if(m==WM_NCCREATE){o=(Overlay*)((CREATESTRUCTW*)l)->lpCreateParams;SetWindowLongPtrW(h,GWLP_USERDATA,(LONG_PTR)o);}if(m==WM_NCHITTEST)return HTTRANSPARENT;if(m==WM_MOUSEACTIVATE)return MA_NOACTIVATE;if(m==WM_PAINT&&app&&o){PAINTSTRUCT ps;HDC dc=BeginPaint(h,&ps);Gdiplus::Graphics g(dc);RECT r;GetClientRect(h,&r);auto*image=app->settings.scenes[o->monitor.device]==1?app->cabin.get():app->porch.get();if(image&&image->GetLastStatus()==Gdiplus::Ok)g.DrawImage(image,0,0,r.right,r.bottom);EndPaint(h,&ps);return 0;}return DefWindowProcW(h,m,w,l);}

int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,LPWSTR,int){
 SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
 int argumentCount=0;
 LPWSTR* arguments=CommandLineToArgvW(GetCommandLineW(),&argumentCount);
 bool smoke=false,review=false,openSettings=false,openQuick=false;
 int measureStyle=-1,measureSize=100;
 std::wstring previewFolder;
 if(arguments){
  if(argumentCount==3&&std::wstring_view(arguments[1])==L"--render-previews")previewFolder=arguments[2];
  for(int i=1;i<argumentCount;i++){
   std::wstring_view flag(arguments[i]);
   smoke|=flag==L"--smoke-test";
   review|=flag==L"--review-ui";
   openSettings|=flag==L"--settings";
   openQuick|=flag==L"--quick-settings";
   if(flag==L"--measure-snow"&&i+1<argumentCount){
    const std::wstring_view style(arguments[++i]);
    if(style==L"simple")measureStyle=0;
    if(style==L"patterned")measureStyle=1;
    if(i+1<argumentCount&&arguments[i+1][0]!=L'-')measureSize=std::clamp(_wtoi(arguments[++i]),50,300);
   }
  }
  LocalFree(arguments);
 }
 HANDLE mutex=nullptr;
 if(!smoke&&!review&&measureStyle<0&&previewFolder.empty()){
  mutex=CreateMutexW(nullptr,TRUE,L"Local\\SnowDesktop.SingleInstance");
  if(GetLastError()==ERROR_ALREADY_EXISTS){
   HWND existing=FindWindowW(APPCLASS,nullptr);
   if(existing)PostMessageW(existing,WM_APP+10,0,0);
   if(mutex)CloseHandle(mutex);
   return 0;
  }
 }
 CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
 Gdiplus::GdiplusStartupInput input;
 ULONG_PTR token=0;
 if(Gdiplus::GdiplusStartup(&token,&input,nullptr)!=Gdiplus::Ok){
  CoUninitialize();
  if(mutex)CloseHandle(mutex);
  return 1;
 }
 if(!previewFolder.empty()){
  bool ok=renderPreviews(previewFolder);
  Painter::clearCache();Gdiplus::GdiplusShutdown(token);CoUninitialize();
  return ok?0:4;
 }
 INITCOMMONCONTROLSEX common{sizeof(common),ICC_WIN95_CLASSES|ICC_BAR_CLASSES};
 InitCommonControlsEx(&common);
 int exit=0;
 {App application(instance);app=&application;application.diagnostic=smoke||review||measureStyle>=0;application.reviewWindow=review;
  application.measuredStyle=measureStyle;application.measuredSize=measureSize;
  if(!application.start())exit=2;else{
   if(measureStyle>=0)application.beginMeasurement();
   else if(smoke)SetTimer(application.tray,2,1500,nullptr);
   else if(openQuick)application.showQuick(false);
   else if(openSettings||review)application.showSettings();
   MSG message;while(GetMessageW(&message,nullptr,0,0)>0){
    if(message.message==WM_KEYDOWN&&message.wParam==VK_ESCAPE&&application.interactive){
     HWND focus=GetFocus();
     if(!focus||className(focus)!=WC_COMBOBOXW||!SendMessageW(focus,CB_GETDROPPEDSTATE,0,0)){
      application.exitGame();
      continue;
     }
    }
    if(application.handleUiMessage(message))continue;
    TranslateMessage(&message);DispatchMessageW(&message);
   }if(application.diagnosticFailed)exit=3;
  }app=nullptr;
 }
 Painter::clearCache();Gdiplus::GdiplusShutdown(token);CoUninitialize();if(mutex){ReleaseMutex(mutex);CloseHandle(mutex);}return exit;
}
